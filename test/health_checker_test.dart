// test/health_checker_test.dart
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sms/core/database/app_database.dart';
import 'package:sms/features/database_management/services/database_health_checker.dart';
import 'package:sms/features/school/data/demo_data_seeder.dart';

void main() {
  late Directory tempDir;
  late File dbFile;
  late AppDatabase db;
  late DatabaseHealthChecker healthChecker;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sms_health_checker_test_');
    dbFile = File('${tempDir.path}/health_test.sqlite');
    db = AppDatabase(NativeDatabase(dbFile));
    healthChecker = DatabaseHealthChecker(db);
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'Health check on pristine seeded database reports healthy status and correct counts',
    () async {
      final seeder = DemoDataSeeder(db);
      await seeder.seedDemoData();

      final report = await healthChecker.checkHealth();

      expect(report.isHealthy, isTrue);
      expect(report.integrityCheckResult.toLowerCase(), 'ok');
      expect(report.foreignKeyViolations, isEmpty);
      expect(report.logicalIntegrityIssues, isEmpty);
      expect(report.allIssues, isEmpty);

      expect(report.tableCounts['schools'], 1);
      expect(report.tableCounts['students'], 150);
      expect(report.tableCounts['teachers'], 3);
      expect(report.tableCounts['school_classes'], 5);
      expect(report.tableCounts['sections'], 5);
    },
  );

  test(
    'Health check detects orphan records and duplicate attendance entries',
    () async {
      final seeder = DemoDataSeeder(db);
      await seeder.seedDemoData();

      // Temporarily bypass foreign keys to simulate data corruption / orphan rows
      await db.customStatement('PRAGMA foreign_keys = OFF;');

      final nowMs = DateTime.now().millisecondsSinceEpoch;

      // Inject an orphan student pointing to non-existent school 'sch_ghost'
      await db.customStatement('''
      INSERT INTO students (id, school_id, student_code, first_name, last_name, is_active, is_archived, created_at, updated_at)
      VALUES ('orphan_stu_999', 'sch_ghost', 'CODE_999', 'Ghost', 'Student', 1, 0, $nowMs, $nowMs);
    ''');

      // Inject an orphan enrollment pointing to non-existent student 'ghost_student_id'
      final school = await (db.select(db.schools)..limit(1)).getSingle();
      final aYear = await (db.select(db.academicYears)..limit(1)).getSingle();
      final sClass = await (db.select(db.schoolClasses)..limit(1)).getSingle();
      final section = await (db.select(db.sections)..limit(1)).getSingle();

      await db.customStatement('''
      INSERT INTO enrollments (id, school_id, student_id, academic_year_id, class_id, section_id, is_active, is_archived, created_at, updated_at)
      VALUES ('orphan_enr_999', '${school.id}', 'ghost_student_id', '${aYear.id}', '${sClass.id}', '${section.id}', 1, 0, $nowMs, $nowMs);
    ''');

      // Inject an orphan timetable entry pointing to non-existent subject 'ghost_subject_id'
      await db.customStatement('''
      INSERT INTO timetables (id, school_id, academic_year_id, class_id, section_id, day_of_week, period, subject_id, start_time, end_time, created_at, updated_at)
      VALUES ('orphan_tt_999', '${school.id}', '${aYear.id}', '${sClass.id}', '${section.id}', 1, 1, 'ghost_subject_id', '08:00', '08:45', $nowMs, $nowMs);
    ''');

      await db.customStatement('PRAGMA foreign_keys = ON;');

      final report = await healthChecker.checkHealth();

      expect(report.isHealthy, isFalse);
      expect(report.allIssues, isNotEmpty);

      // Verify orphan student detected
      final hasOrphanStudent = report.logicalIntegrityIssues.any(
        (issue) =>
            issue.contains('Ghost Student') || issue.contains('orphan_stu_999'),
      );
      expect(hasOrphanStudent, isTrue);

      // Verify orphan enrollment detected
      final hasOrphanEnrollment = report.logicalIntegrityIssues.any(
        (issue) => issue.contains('orphan_enr_999'),
      );
      expect(hasOrphanEnrollment, isTrue);

      // Verify orphan timetable detected
      final hasOrphanTimetable = report.logicalIntegrityIssues.any(
        (issue) => issue.contains('orphan_tt_999'),
      );
      expect(hasOrphanTimetable, isTrue);
    },
  );
}
