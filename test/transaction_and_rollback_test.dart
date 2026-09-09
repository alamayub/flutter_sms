// test/transaction_and_rollback_test.dart
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sms/core/constants/app_constants.dart';
import 'package:sms/core/database/app_database.dart';
import 'package:sms/core/errors/app_exceptions.dart';
import 'package:sms/features/audit/data/audit_repository.dart';
import 'package:sms/features/database_management/services/backup_service.dart';
import 'package:sms/features/school/data/demo_data_seeder.dart';
import 'package:sms/features/school/data/school_repository.dart';
import 'package:sms/features/students/data/students_repository.dart';

void main() {
  late Directory tempDir;
  late File dbFile;
  late AppDatabase db;
  late AuditRepository auditRepo;
  late SchoolRepository schoolRepo;
  late StudentsRepository studentsRepo;
  late BackupService backupService;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sms_tx_test_');
    dbFile = File('${tempDir.path}/tx_test.sqlite');
    db = AppDatabase(NativeDatabase(dbFile));
    auditRepo = AuditRepository(db);
    schoolRepo = SchoolRepository(db, auditRepo);
    studentsRepo = StudentsRepository(db, auditRepo);
    backupService = BackupService(db, auditRepo);
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'Attendance batch transaction rollback ensures zero partial rows on failure',
    () async {
      // Seed demo data
      final seeder = DemoDataSeeder(db);
      await seeder.seedDemoData();

      final school = await schoolRepo.getActiveSchool();
      expect(school, isNotNull);

      final students = await studentsRepo.getStudents(school!.id);
      expect(students.length, greaterThanOrEqualTo(10));

      final today = '2026-09-09';
      final s1 = students[0].id;

      // Simulate an atomic batch with a deliberate exception thrown midway
      bool threw = false;
      try {
        await db.transaction(() async {
          // First record inserted
          await db
              .into(db.attendance)
              .insert(
                AttendanceCompanion.insert(
                  id: 'tx_att_1',
                  schoolId: school.id,
                  academicYearId: 'dummy_ay',
                  date: today,
                  studentId: s1,
                  classId: 'dummy_class',
                  sectionId: 'dummy_sec',
                  status: AttendanceStatus.present,
                  markedBy: 'admin',
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                ),
              );

          // Crash simulated before second record completes
          throw Exception(
            'Device suddenly lost power / battery died mid-batch',
          );
        });
      } catch (_) {
        threw = true;
      }

      expect(threw, isTrue);

      // Verify first record was completely rolled back! Zero rows persisted!
      final rolledBackRecord =
          await (db.select(db.attendance)
            ..where((t) => t.id.equals('tx_att_1'))).getSingleOrNull();
      expect(rolledBackRecord, isNull);
    },
  );

  test(
    'Failed import triggers automatic safety rollback preserving previous database state',
    () async {
      // 1. Establish existing valuable school data
      await schoolRepo.createSchool(
        name: 'Precious Existing High School',
        shortName: 'PEHS',
      );
      final existingSchool = await schoolRepo.getActiveSchool();
      expect(existingSchool!.name, 'Precious Existing High School');

      await studentsRepo.createStudent(
        schoolId: existingSchool.id,
        studentCode: 'PEHS-001',
        firstName: 'Alice',
        lastName: 'Smith',
        gender: 'Female',
      );

      final studentsBefore = await studentsRepo.getStudents(existingSchool.id);
      expect(studentsBefore.length, 1);

      // 2. Prepare an import payload where the data table has a malformed row that causes SQLite / runtime exception
      final malformedData = {
        'schools': [
          // Intentionally invalid school data that causes an error during deserialization/insertion
          {'id': 'sch_corrupt', 'name': null, 'created_at': 'invalid-date'},
        ],
      };
      final serializedData = jsonEncode(malformedData);
      final checksum = sha256.convert(utf8.encode(serializedData)).toString();

      final payload = jsonEncode({
        'format': 'SMS_SDB_V2',
        'appVersion': '1.0.0',
        'schemaVersion': 2,
        'checksum': checksum,
        'data': malformedData,
      });

      // 3. Attempt import, expecting failure
      expect(
        () => backupService.importBackup(payload),
        throwsA(isA<BackupException>()),
      );

      // 4. Verify automatic rollback restored previous database state completely!
      final schoolAfter = await schoolRepo.getActiveSchool();
      expect(schoolAfter, isNotNull);
      expect(schoolAfter!.name, 'Precious Existing High School');

      final studentsAfter = await studentsRepo.getStudents(existingSchool.id);
      expect(studentsAfter.length, 1);
      expect(studentsAfter.first.firstName, 'Alice');
    },
  );
}
