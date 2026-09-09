// test/large_dataset_test.dart
import 'dart:io';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sms/core/constants/app_constants.dart';
import 'package:sms/core/database/app_database.dart';
import 'package:sms/core/database/database_service.dart';
import 'package:sms/core/utils/uuid_generator.dart';
import 'package:sms/features/academic_year/data/academic_year_repository.dart';
import 'package:sms/features/attendance/data/attendance_repository.dart';
import 'package:sms/features/audit/data/audit_repository.dart';
import 'package:sms/features/classes/data/classes_repository.dart';
import 'package:sms/features/database_management/services/backup_service.dart';
import 'package:sms/features/school/data/school_repository.dart';
import 'package:sms/features/students/data/students_repository.dart';

void main() {
  late Directory tempDir;
  late File dbFile;
  late AppDatabase db;
  late AuditRepository auditRepo;
  late SchoolRepository schoolRepo;
  late AcademicYearRepository yearRepo;
  late ClassesRepository classesRepo;
  late StudentsRepository studentsRepo;
  late AttendanceRepository attendanceRepo;
  late BackupService backupService;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sms_large_dataset_test_');
    dbFile = File('${tempDir.path}/large_dataset.sqlite');
    db = AppDatabase(NativeDatabase(dbFile));
    auditRepo = AuditRepository(db);
    schoolRepo = SchoolRepository(db, auditRepo);
    yearRepo = AcademicYearRepository(db, auditRepo);
    classesRepo = ClassesRepository(db, auditRepo);
    studentsRepo = StudentsRepository(db, auditRepo);
    attendanceRepo = AttendanceRepository(db, auditRepo);
    backupService = BackupService(db, auditRepo);
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'Benchmark 1000+ students: Insertion, pagination, search, attendance batching, and export/import',
    () async {
      // 1. Setup School, Academic Year, Class, Section
      final school = await schoolRepo.createSchool(
        name: 'Grand Valley High School',
        shortName: 'GVHS',
      );

      final aYear = await yearRepo.createAcademicYear(
        schoolId: school.id,
        name: '2026/2027',
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2027, 6, 30),
        isCurrent: true,
      );

      final sClass = await classesRepo.createClass(
        schoolId: school.id,
        academicYearId: aYear.id,
        name: 'Senior Grade',
      );

      final section = await classesRepo.createSection(
        classId: sClass.id,
        name: 'Main Section',
        capacity: 1500,
      );

      // 2. Bulk insert 1,000 students in a single transaction
      const studentCount = 1000;
      final insertStopwatch = Stopwatch()..start();
      final studentIds = <String>[];

      await db.transaction(() async {
        final now = DateTime.now();
        for (int i = 1; i <= studentCount; i++) {
          final id = UuidGenerator.v4();
          studentIds.add(id);
          final paddedNum = i.toString().padLeft(4, '0');

          await db
              .into(db.students)
              .insert(
                StudentsCompanion.insert(
                  id: id,
                  schoolId: school.id,
                  studentCode: 'GV-$paddedNum',
                  firstName: 'Student$i',
                  lastName: 'Benchmark',
                  gender: Value(i % 2 == 0 ? 'Female' : 'Male'),
                  isArchived: const Value(false),
                  createdAt: now,
                  updatedAt: now,
                ),
              );

          // Also create enrollment
          await db
              .into(db.enrollments)
              .insert(
                EnrollmentsCompanion.insert(
                  id: UuidGenerator.v4(),
                  schoolId: school.id,
                  studentId: id,
                  academicYearId: aYear.id,
                  classId: sClass.id,
                  sectionId: section.id,
                  rollNumber: Value(i),
                  isArchived: const Value(false),
                  createdAt: now,
                  updatedAt: now,
                ),
              );
        }
      });

      insertStopwatch.stop();
      // Verify all 1,000 students counted efficiently
      final totalCount = await studentsRepo.getTotalStudentCount(school.id);
      expect(totalCount, studentCount);

      // 3. Test pagination: fetch page 1 (50) and page 2 (50)
      final page1Stopwatch = Stopwatch()..start();
      final page1 = await studentsRepo.getStudents(
        school.id,
        limit: 50,
        offset: 0,
      );
      page1Stopwatch.stop();
      expect(page1.length, 50);

      final page2 = await studentsRepo.getStudents(
        school.id,
        limit: 50,
        offset: 50,
      );
      expect(page2.length, 50);

      // Verify non-overlapping
      final page1Ids = page1.map((s) => s.id).toSet();
      final page2Ids = page2.map((s) => s.id).toSet();
      expect(page1Ids.intersection(page2Ids), isEmpty);

      // 4. Test Search with 1,000 records
      final searchStopwatch = Stopwatch()..start();
      final searchResults = await studentsRepo.getStudents(
        school.id,
        searchQuery: 'Student777',
      );
      searchStopwatch.stop();
      expect(searchResults.length, 1);
      expect(searchResults.first.firstName, 'Student777');
      expect(searchResults.first.studentCode, 'GV-0777');

      // 5. Test Attendance Batching:
      // a. 30 students batch
      final batch30Map = {
        for (int i = 0; i < 30; i++) studentIds[i]: AttendanceStatus.present,
      };
      final batch30Stopwatch = Stopwatch()..start();
      await attendanceRepo.saveAttendanceBatch(
        schoolId: school.id,
        academicYearId: aYear.id,
        classId: sClass.id,
        sectionId: section.id,
        date: '2026-09-09',
        studentStatusMap: batch30Map,
        markedByUserId: 'admin_test',
      );
      batch30Stopwatch.stop();

      // Verify attendance summary
      final summary30 = await attendanceRepo.getDailySummary(
        schoolId: school.id,
        date: '2026-09-09',
      );
      expect(summary30.totalCount, 30);
      expect(summary30.presentCount, 30);

      // b. 60 students batch (updating first 30 + adding next 30)
      final batch60Map = {
        for (int i = 0; i < 60; i++)
          studentIds[i]:
              i == 0 ? AttendanceStatus.absent : AttendanceStatus.present,
      };
      final batch60Stopwatch = Stopwatch()..start();
      await attendanceRepo.saveAttendanceBatch(
        schoolId: school.id,
        academicYearId: aYear.id,
        classId: sClass.id,
        sectionId: section.id,
        date: '2026-09-09',
        studentStatusMap: batch60Map,
        markedByUserId: 'admin_test',
      );
      batch60Stopwatch.stop();

      final summary60 = await attendanceRepo.getDailySummary(
        schoolId: school.id,
        date: '2026-09-09',
      );
      expect(summary60.totalCount, 60);
      expect(summary60.absentCount, 1);
      expect(summary60.presentCount, 59);

      // c. 1000 students full school attendance batch
      final batch1000Map = {
        for (int i = 0; i < studentCount; i++)
          studentIds[i]:
              i % 10 == 0 ? AttendanceStatus.absent : AttendanceStatus.present,
      };
      final batch1000Stopwatch = Stopwatch()..start();
      await attendanceRepo.saveAttendanceBatch(
        schoolId: school.id,
        academicYearId: aYear.id,
        classId: sClass.id,
        sectionId: section.id,
        date: '2026-09-10',
        studentStatusMap: batch1000Map,
        markedByUserId: 'admin_test',
      );
      batch1000Stopwatch.stop();

      final summary1000 = await attendanceRepo.getDailySummary(
        schoolId: school.id,
        date: '2026-09-10',
      );
      expect(summary1000.totalCount, 1000);
      expect(summary1000.absentCount, 100);
      expect(summary1000.presentCount, 900);

      // 6. Test Export of 1000 students dataset to .sdb
      final exportStopwatch = Stopwatch()..start();
      final backupSdb = await backupService.exportBackup();
      exportStopwatch.stop();
      expect(backupSdb.contains('SMS_SDB_V2'), isTrue);

      // 7. Wipe database and import backup back
      await DatabaseHelper.clearAllData(db);
      expect(await studentsRepo.getTotalStudentCount(school.id), 0);

      final importStopwatch = Stopwatch()..start();
      await backupService.importBackup(backupSdb);
      importStopwatch.stop();

      // Verify 100% restoration
      final restoredCount = await studentsRepo.getTotalStudentCount(school.id);
      expect(restoredCount, 1000);

      final restoredAttendance = await attendanceRepo.getDailySummary(
        schoolId: school.id,
        date: '2026-09-10',
      );
      expect(restoredAttendance.totalCount, 1000);
      expect(restoredAttendance.absentCount, 100);
    },
  );
}
