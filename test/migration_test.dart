// test/migration_test.dart
import 'dart:io';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sms/core/database/app_database.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  late Directory tempDir;
  late File dbFile;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sms_migration_test_');
    dbFile = File('${tempDir.path}/v1_to_v2.sqlite');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'Database successfully migrates from v1 to v2 preserving data',
    () async {
      // 1. Create a genuine SQLite database at schema v1 using raw sqlite3
      final rawDb = sqlite.sqlite3.open(dbFile.path);
      rawDb.execute('PRAGMA user_version = 1;');

      // Create v1 tables (without is_archived and archived_at)
      rawDb.execute('''
      CREATE TABLE schools (
        id TEXT NOT NULL PRIMARY KEY,
        name TEXT NOT NULL,
        short_name TEXT,
        code TEXT,
        address TEXT,
        phone TEXT,
        email TEXT,
        principal_name TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );

      CREATE TABLE academic_years (
        id TEXT NOT NULL PRIMARY KEY,
        school_id TEXT NOT NULL,
        name TEXT NOT NULL,
        start_date INTEGER NOT NULL,
        end_date INTEGER NOT NULL,
        is_current INTEGER NOT NULL DEFAULT 0,
        is_archived INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );

      CREATE TABLE school_classes (
        id TEXT NOT NULL PRIMARY KEY,
        school_id TEXT NOT NULL,
        academic_year_id TEXT NOT NULL,
        name TEXT NOT NULL,
        display_order INTEGER NOT NULL DEFAULT 0,
        is_archived INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );

      CREATE TABLE sections (
        id TEXT NOT NULL PRIMARY KEY,
        class_id TEXT NOT NULL,
        name TEXT NOT NULL,
        capacity INTEGER NOT NULL DEFAULT 40,
        class_teacher_id TEXT,
        is_archived INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );

      CREATE TABLE subjects (
        id TEXT NOT NULL PRIMARY KEY,
        school_id TEXT NOT NULL,
        name TEXT NOT NULL,
        code TEXT NOT NULL,
        description TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );

      CREATE TABLE teachers (
        id TEXT NOT NULL PRIMARY KEY,
        school_id TEXT NOT NULL,
        user_id TEXT,
        employee_code TEXT NOT NULL,
        name TEXT NOT NULL,
        phone TEXT,
        email TEXT,
        address TEXT,
        joining_date INTEGER,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );

      CREATE TABLE students (
        id TEXT NOT NULL PRIMARY KEY,
        school_id TEXT NOT NULL,
        student_code TEXT NOT NULL,
        first_name TEXT NOT NULL,
        middle_name TEXT,
        last_name TEXT NOT NULL,
        date_of_birth INTEGER,
        gender TEXT NOT NULL DEFAULT 'Other',
        phone TEXT,
        address TEXT,
        guardian_name TEXT,
        guardian_phone TEXT,
        admission_date INTEGER,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );

      CREATE TABLE enrollments (
        id TEXT NOT NULL PRIMARY KEY,
        student_id TEXT NOT NULL,
        academic_year_id TEXT NOT NULL,
        class_id TEXT NOT NULL,
        section_id TEXT NOT NULL,
        roll_number TEXT,
        enrolled_at INTEGER NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );

      CREATE TABLE users (
        id TEXT NOT NULL PRIMARY KEY,
        school_id TEXT,
        username TEXT NOT NULL,
        password_hash TEXT NOT NULL,
        role TEXT NOT NULL,
        name TEXT NOT NULL,
        email TEXT,
        phone TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_by TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );

      CREATE TABLE class_subjects (
        id TEXT NOT NULL PRIMARY KEY,
        class_id TEXT NOT NULL,
        subject_id TEXT NOT NULL,
        teacher_id TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );

      CREATE TABLE timetables (
        id TEXT NOT NULL PRIMARY KEY,
        school_id TEXT NOT NULL,
        academic_year_id TEXT NOT NULL,
        class_id TEXT NOT NULL,
        section_id TEXT NOT NULL,
        day_of_week INTEGER NOT NULL,
        period INTEGER NOT NULL,
        subject_id TEXT NOT NULL,
        teacher_id TEXT,
        start_time TEXT NOT NULL,
        end_time TEXT NOT NULL,
        room TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );

      CREATE TABLE attendance (
        id TEXT NOT NULL PRIMARY KEY,
        school_id TEXT NOT NULL,
        academic_year_id TEXT NOT NULL,
        date TEXT NOT NULL,
        student_id TEXT NOT NULL,
        class_id TEXT NOT NULL,
        section_id TEXT NOT NULL,
        status TEXT NOT NULL,
        remarks TEXT,
        marked_by TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );

      CREATE TABLE audit_logs (
        id TEXT NOT NULL PRIMARY KEY,
        school_id TEXT,
        user_id TEXT,
        action TEXT NOT NULL,
        entity_type TEXT NOT NULL,
        entity_id TEXT,
        metadata TEXT,
        created_at INTEGER NOT NULL
      );

      CREATE TABLE app_settings (
        key TEXT NOT NULL PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      );
    ''');

      final nowMs = DateTime.now().millisecondsSinceEpoch;

      // Insert pre-migration v1 data
      rawDb.execute('''
      INSERT INTO schools (id, name, created_at, updated_at)
      VALUES ('sch_1', 'Legacy Primary School', $nowMs, $nowMs);

      INSERT INTO school_classes (id, school_id, academic_year_id, name, display_order, created_at, updated_at)
      VALUES ('cls_1', 'sch_1', 'ay_1', 'Grade 5', 1, $nowMs, $nowMs);

      INSERT INTO students (id, school_id, student_code, first_name, last_name, is_active, created_at, updated_at)
      VALUES ('stu_1', 'sch_1', 'STU-001', 'Legacy', 'Student', 1, $nowMs, $nowMs);
    ''');

      rawDb.dispose();

      // 2. Open database with AppDatabase (which runs onUpgrade v1 -> v2)
      final appDb = AppDatabase(NativeDatabase(dbFile));

      // Verify migration succeeded
      final school =
          await (appDb.select(appDb.schools)
            ..where((t) => t.id.equals('sch_1'))).getSingle();
      expect(school.name, 'Legacy Primary School');

      final schoolClass =
          await (appDb.select(appDb.schoolClasses)
            ..where((t) => t.id.equals('cls_1'))).getSingle();
      expect(schoolClass.name, 'Grade 5');
      // Verify new v2 columns exist with expected defaults
      expect(schoolClass.isArchived, isFalse);
      expect(schoolClass.archivedAt, isNull);

      final student =
          await (appDb.select(appDb.students)
            ..where((t) => t.id.equals('stu_1'))).getSingle();
      expect(student.firstName, 'Legacy');
      expect(student.lastName, 'Student');
      expect(student.studentCode, 'STU-001');
      expect(student.isArchived, isFalse);
      expect(student.archivedAt, isNull);

      // Verify we can write new rows with isArchived = true
      await (appDb.update(appDb.students)
        ..where((t) => t.id.equals('stu_1'))).write(
        StudentsCompanion(
          isArchived: const Value(true),
          archivedAt: Value(DateTime.now()),
        ),
      );

      final updatedStudent =
          await (appDb.select(appDb.students)
            ..where((t) => t.id.equals('stu_1'))).getSingle();
      expect(updatedStudent.isArchived, isTrue);
      expect(updatedStudent.archivedAt, isNotNull);

      await appDb.close();
    },
  );

  test(
    'Database successfully migrates from v2 to v3 creating sync tables and preserving existing data',
    () async {
      // 1. Create a database at schema v2
      final rawDb = sqlite.sqlite3.open(dbFile.path);
      rawDb.execute('PRAGMA user_version = 2;');
      rawDb.execute('''
      CREATE TABLE schools (
        id TEXT NOT NULL PRIMARY KEY,
        name TEXT NOT NULL,
        short_name TEXT,
        code TEXT,
        address TEXT,
        phone TEXT,
        email TEXT,
        principal_name TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );

      CREATE TABLE attendance (
        id TEXT NOT NULL PRIMARY KEY,
        school_id TEXT NOT NULL,
        academic_year_id TEXT NOT NULL,
        date TEXT NOT NULL,
        student_id TEXT NOT NULL,
        class_id TEXT NOT NULL,
        section_id TEXT NOT NULL,
        status TEXT NOT NULL,
        remarks TEXT,
        marked_by TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );
      ''');

      final nowMs = DateTime.now().millisecondsSinceEpoch;
      rawDb.execute('''
      INSERT INTO schools (id, name, created_at, updated_at)
      VALUES ('sch_v2', 'School V2', $nowMs, $nowMs);
      ''');
      rawDb.dispose();

      // 2. Open with AppDatabase (runs onUpgrade v2 -> v3)
      final appDb = AppDatabase(NativeDatabase(dbFile));

      // 3. Verify existing v2 data preserved
      final school =
          await (appDb.select(appDb.schools)
            ..where((t) => t.id.equals('sch_v2'))).getSingle();
      expect(school.name, 'School V2');

      // 4. Verify new v3 tables exist and are queryable
      final devices = await appDb.select(appDb.syncDevices).get();
      expect(devices, isEmpty);

      final events = await appDb.select(appDb.syncEvents).get();
      expect(events, isEmpty);

      final cursors = await appDb.select(appDb.syncCursors).get();
      expect(cursors, isEmpty);

      final conflicts = await appDb.select(appDb.syncConflicts).get();
      expect(conflicts, isEmpty);

      // Verify insertion into sync_events works
      await appDb
          .into(appDb.syncEvents)
          .insert(
            SyncEventsCompanion.insert(
              eventId: 'evt_test_1',
              schoolId: 'sch_v2',
              deviceId: 'dev_1',
              userId: 'usr_1',
              entityType: 'attendance',
              entityId: 'att_1',
              operation: 'create',
              payload: '{"status":"present"}',
              createdAt: DateTime.now(),
            ),
          );

      final insertedEvents = await appDb.select(appDb.syncEvents).get();
      expect(insertedEvents.length, equals(1));
      expect(insertedEvents.first.eventId, equals('evt_test_1'));

      await appDb.close();
    },
  );
}
