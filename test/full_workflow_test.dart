// test/full_workflow_test.dart
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sms/core/constants/app_constants.dart';
import 'package:sms/core/database/app_database.dart';
import 'package:sms/core/database/database_service.dart';
import 'package:sms/features/academic_year/data/academic_year_repository.dart';
import 'package:sms/features/attendance/data/attendance_repository.dart';
import 'package:sms/features/audit/data/audit_repository.dart';
import 'package:sms/features/auth/data/auth_repository.dart';
import 'package:sms/features/classes/data/classes_repository.dart';
import 'package:sms/features/database_management/services/backup_service.dart';
import 'package:sms/features/school/data/school_repository.dart';
import 'package:sms/features/students/data/students_repository.dart';
import 'package:sms/features/subjects/data/subjects_repository.dart';
import 'package:sms/features/teachers/data/teachers_repository.dart';
import 'package:sms/features/timetable/data/timetable_repository.dart';

void main() {
  late Directory tempDir;
  late File dbFile;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sms_full_workflow_test_');
    dbFile = File('${tempDir.path}/sms_school.sqlite');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('Definition of Done: Complete end-to-end local offline workflow', () async {
    // 1. Install & initialize fresh database
    var db = AppDatabase(NativeDatabase(dbFile));
    var auditRepo = AuditRepository(db);
    var schoolRepo = SchoolRepository(db, auditRepo);
    var authRepo = AuthRepository(db, auditRepo);
    var academicRepo = AcademicYearRepository(db, auditRepo);
    var classesRepo = ClassesRepository(db, auditRepo);
    var subjectsRepo = SubjectsRepository(db, auditRepo);
    var teachersRepo = TeachersRepository(db, auditRepo, authRepo);
    var studentsRepo = StudentsRepository(db, auditRepo);
    var timetableRepo = TimetableRepository(db, auditRepo);
    var attendanceRepo = AttendanceRepository(db, auditRepo);
    var backupService = BackupService(db, auditRepo);

    // 2. Create New School
    final school = await schoolRepo.createSchool(
      name: 'Valley Model Secondary School',
      shortName: 'VMSS',
      address: 'Pokhara, Kaski',
      phone: '+977-61-534567',
      email: 'contact@valleyschool.edu.np',
      principalName: 'Mr. Ananda Joshi',
    );
    expect(school.name, 'Valley Model Secondary School');

    // 3. Create Administrator
    final admin = await authRepo.createAdministrator(
      schoolId: school.id,
      name: 'System Admin',
      username: 'admin',
      password: 'adminPassword123',
    );
    expect(admin.username, 'admin');

    // 4. Login as Admin
    final loggedInAdmin = await authRepo.login(
      usernameOrEmail: 'admin',
      password: 'adminPassword123',
    );
    expect(loggedInAdmin.id, admin.id);

    // 5. Create Academic Year 2026/27
    final academicYear = await academicRepo.createAcademicYear(
      schoolId: school.id,
      name: '2026/27',
      startDate: DateTime(2026, 4, 15),
      endDate: DateTime(2027, 4, 14),
      isCurrent: true,
      currentUserId: loggedInAdmin.id,
    );
    expect(academicYear.name, '2026/27');
    expect(academicYear.isCurrent, isTrue);

    // 6. Create Grade 8
    final grade8 = await classesRepo.createClass(
      schoolId: school.id,
      academicYearId: academicYear.id,
      name: 'Grade 8',
      displayOrder: 8,
      currentUserId: loggedInAdmin.id,
    );
    expect(grade8.name, 'Grade 8');

    // 7. Create Section A
    final sectionA = await classesRepo.createSection(
      classId: grade8.id,
      name: 'Section A',
      capacity: 40,
      currentUserId: loggedInAdmin.id,
    );
    expect(sectionA.name, 'Section A');

    // 8. Create Mathematics
    final mathSubject = await subjectsRepo.createSubject(
      schoolId: school.id,
      name: 'Mathematics',
      code: 'MATH101',
      currentUserId: loggedInAdmin.id,
    );
    expect(mathSubject.name, 'Mathematics');

    // 9. Create Teacher Ram with login account
    final teacherRam = await teachersRepo.createTeacher(
      schoolId: school.id,
      employeeCode: 'EMP-01',
      name: 'Ram Sharma',
      phone: '+977-9841000001',
      createLoginAccount: true,
      username: 'teacher.ram',
      password: 'teacherPassword123',
      currentUserId: loggedInAdmin.id,
    );
    expect(teacherRam.name, 'Ram Sharma');
    expect(teacherRam.userId, isNotNull);

    // Assign teacher to section & subject
    await classesRepo.assignClassTeacher(sectionA.id, teacherRam.id);
    await subjectsRepo.assignSubjectToClass(
      classId: grade8.id,
      subjectId: mathSubject.id,
      teacherId: teacherRam.id,
    );

    // 10. Create 30 Students and Enroll them into Grade 8A
    final studentIds = <String>[];
    for (int i = 1; i <= 30; i++) {
      final code = 'STU08${i.toString().padLeft(2, '0')}';
      final student = await studentsRepo.createStudent(
        schoolId: school.id,
        studentCode: code,
        firstName: 'Student$i',
        lastName: 'Sharma',
        gender: i % 2 == 0 ? 'Male' : 'Female',
        currentUserId: loggedInAdmin.id,
      );
      studentIds.add(student.id);

      await studentsRepo.enrollStudent(
        schoolId: school.id,
        studentId: student.id,
        academicYearId: academicYear.id,
        classId: grade8.id,
        sectionId: sectionA.id,
        rollNumber: i,
        currentUserId: loggedInAdmin.id,
      );
    }
    expect(studentIds.length, 30);

    // 11. Create Timetable for Grade 8A (Mathematics with Teacher Ram on Monday)
    final timetableEntry = await timetableRepo.createEntry(
      schoolId: school.id,
      academicYearId: academicYear.id,
      classId: grade8.id,
      sectionId: sectionA.id,
      dayOfWeek: DayOfWeek.monday,
      period: 1,
      subjectId: mathSubject.id,
      teacherId: teacherRam.id,
      startTime: '09:00',
      endTime: '09:45',
      room: 'Room 8A',
      currentUserId: loggedInAdmin.id,
    );
    expect(timetableEntry.room, 'Room 8A');

    // 12. Login as Teacher Ram
    final loggedInTeacher = await authRepo.login(
      usernameOrEmail: 'teacher.ram',
      password: 'teacherPassword123',
    );
    expect(loggedInTeacher.id, teacherRam.userId);

    // 13. Open Grade 8A & Mark Attendance
    // Mark: 28 Present, 1 Absent, 1 Late
    final attendanceMap = <String, String>{};
    for (int i = 0; i < studentIds.length; i++) {
      if (i == 28) {
        attendanceMap[studentIds[i]] = AttendanceStatus.absent;
      } else if (i == 29) {
        attendanceMap[studentIds[i]] = AttendanceStatus.late;
      } else {
        attendanceMap[studentIds[i]] = AttendanceStatus.present;
      }
    }

    const todayDate = '2026-09-09';
    await attendanceRepo.saveAttendanceBatch(
      schoolId: school.id,
      academicYearId: academicYear.id,
      classId: grade8.id,
      sectionId: sectionA.id,
      date: todayDate,
      studentStatusMap: attendanceMap,
      markedByUserId: loggedInTeacher.id,
    );

    // 14. Close application (simulate app kill / device reboot)
    await db.close();

    // 15. Restart application (reopen brand new database instance on same storage)
    db = AppDatabase(NativeDatabase(dbFile));
    auditRepo = AuditRepository(db);
    schoolRepo = SchoolRepository(db, auditRepo);
    authRepo = AuthRepository(db, auditRepo);
    academicRepo = AcademicYearRepository(db, auditRepo);
    classesRepo = ClassesRepository(db, auditRepo);
    subjectsRepo = SubjectsRepository(db, auditRepo);
    teachersRepo = TeachersRepository(db, auditRepo, authRepo);
    studentsRepo = StudentsRepository(db, auditRepo);
    timetableRepo = TimetableRepository(db, auditRepo);
    attendanceRepo = AttendanceRepository(db, auditRepo);
    backupService = BackupService(db, auditRepo);

    // 16. Login again
    final reloginAdmin = await authRepo.login(
      usernameOrEmail: 'admin',
      password: 'adminPassword123',
    );
    expect(reloginAdmin.username, 'admin');

    // 17. Verify all data and attendance still exists
    final activeSchool = await schoolRepo.getActiveSchool();
    expect(activeSchool, isNotNull);
    expect(activeSchool!.name, 'Valley Model Secondary School');

    final enrolledIn8A = await studentsRepo.getEnrolledStudentsForSection(
      academicYearId: academicYear.id,
      sectionId: sectionA.id,
    );
    expect(enrolledIn8A.length, 30);

    final attendanceSummary = await attendanceRepo.getDailySummary(
      schoolId: school.id,
      date: todayDate,
    );
    expect(attendanceSummary.totalCount, 30);
    expect(attendanceSummary.presentCount, 28);
    expect(attendanceSummary.absentCount, 1);
    expect(attendanceSummary.lateCount, 1);

    // 18. Export database to portable .sdb backup
    final sdbBackup = await backupService.exportBackup(currentUserId: admin.id);
    expect(sdbBackup.contains('SMS_SDB_V2'), isTrue);

    // 19. Reset/reinstall test environment (wipe SQLite file)
    await DatabaseHelper.clearAllData(db);
    final countAfterWipe = await studentsRepo.getTotalStudentCount(school.id);
    expect(countAfterWipe, 0);

    // 20. Import database backup (.sdb)
    await backupService.importBackup(sdbBackup, currentUserId: admin.id);

    // 21. Verify all school data, students, timetable, and attendance restored completely!
    final restoredSchool = await schoolRepo.getActiveSchool();
    expect(restoredSchool!.name, 'Valley Model Secondary School');

    final restoredStudents = await studentsRepo.getTotalStudentCount(
      restoredSchool.id,
    );
    expect(restoredStudents, 30);

    final restoredSummary = await attendanceRepo.getDailySummary(
      schoolId: restoredSchool.id,
      date: todayDate,
    );
    expect(restoredSummary.totalCount, 30);
    expect(restoredSummary.presentCount, 28);
    expect(restoredSummary.absentCount, 1);

    final restoredTimetable = await timetableRepo.getTimetableForSection(
      sectionA.id,
      dayOfWeek: DayOfWeek.monday,
    );
    expect(restoredTimetable.length, 1);
    expect(restoredTimetable.first.subject.name, 'Mathematics');
    expect(restoredTimetable.first.teacher!.name, 'Ram Sharma');

    await db.close();
  });
}
