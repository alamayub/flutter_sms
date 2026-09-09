// test/persistence_test.dart
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sms/core/constants/app_constants.dart';
import 'package:sms/core/database/app_database.dart';
import 'package:sms/features/academic_year/data/academic_year_repository.dart';
import 'package:sms/features/attendance/data/attendance_repository.dart';
import 'package:sms/features/audit/data/audit_repository.dart';
import 'package:sms/features/auth/data/auth_repository.dart';
import 'package:sms/features/classes/data/classes_repository.dart';
import 'package:sms/features/school/data/school_repository.dart';
import 'package:sms/features/students/data/students_repository.dart';
import 'package:sms/features/subjects/data/subjects_repository.dart';
import 'package:sms/features/teachers/data/teachers_repository.dart';
import 'package:sms/features/timetable/data/timetable_repository.dart';

void main() {
  late Directory tempDir;
  late File dbFile;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sms_persistence_test_');
    dbFile = File('${tempDir.path}/test_sms.sqlite');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'Test 1: Create school -> Close DB -> Reopen DB -> School still exists',
    () async {
      // Phase 1: Open database and create school
      var db = AppDatabase(NativeDatabase(dbFile));
      var auditRepo = AuditRepository(db);
      var schoolRepo = SchoolRepository(db, auditRepo);

      final createdSchool = await schoolRepo.createSchool(
        name: 'Everest Model Academy',
        shortName: 'EMA',
        address: 'Kathmandu, Nepal',
        principalName: 'Mr. Sharma',
      );

      expect(createdSchool.name, 'Everest Model Academy');

      // Simulate closing the app / database
      await db.close();

      // Phase 2: Reopen a new database instance pointing to the exact same file
      db = AppDatabase(NativeDatabase(dbFile));
      auditRepo = AuditRepository(db);
      schoolRepo = SchoolRepository(db, auditRepo);

      final loadedSchool = await schoolRepo.getSchoolById(createdSchool.id);
      expect(loadedSchool, isNotNull);
      expect(loadedSchool!.name, 'Everest Model Academy');
      expect(loadedSchool.shortName, 'EMA');
      expect(loadedSchool.principalName, 'Mr. Sharma');

      await db.close();
    },
  );

  test('Test 2: Create student -> Restart -> Student still exists', () async {
    var db = AppDatabase(NativeDatabase(dbFile));
    var auditRepo = AuditRepository(db);
    var schoolRepo = SchoolRepository(db, auditRepo);
    var studentRepo = StudentsRepository(db, auditRepo);

    final school = await schoolRepo.createSchool(name: 'Test School');
    final student = await studentRepo.createStudent(
      schoolId: school.id,
      studentCode: 'STU-001',
      firstName: 'Aarav',
      lastName: 'Sharma',
      gender: 'Male',
      dateOfBirth: DateTime(2012, 5, 10),
    );

    expect(student.studentCode, 'STU-001');
    await db.close();

    // Reopen database
    db = AppDatabase(NativeDatabase(dbFile));
    auditRepo = AuditRepository(db);
    studentRepo = StudentsRepository(db, auditRepo);

    final loadedStudent = await studentRepo.getStudentById(student.id);
    expect(loadedStudent, isNotNull);
    expect(loadedStudent!.studentCode, 'STU-001');
    expect(loadedStudent.firstName, 'Aarav');
    expect(loadedStudent.lastName, 'Sharma');

    await db.close();
  });

  test(
    'Test 3: Mark attendance -> Restart -> Attendance and stats still exist',
    () async {
      var db = AppDatabase(NativeDatabase(dbFile));
      var auditRepo = AuditRepository(db);
      var schoolRepo = SchoolRepository(db, auditRepo);
      var studentRepo = StudentsRepository(db, auditRepo);
      var attendanceRepo = AttendanceRepository(db, auditRepo);
      var academicRepo = AcademicYearRepository(db, auditRepo);
      var classesRepo = ClassesRepository(db, auditRepo);

      final school = await schoolRepo.createSchool(name: 'School A');
      final year = await academicRepo.createAcademicYear(
        schoolId: school.id,
        name: '2026/27',
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 12, 31),
        isCurrent: true,
      );
      final cls = await classesRepo.createClass(
        schoolId: school.id,
        academicYearId: year.id,
        name: 'Grade 8',
      );
      final sec = await classesRepo.createSection(
        classId: cls.id,
        name: 'Section A',
      );
      final student = await studentRepo.createStudent(
        schoolId: school.id,
        studentCode: 'S100',
        firstName: 'Sita',
        lastName: 'Thapa',
      );

      // Mark attendance
      await attendanceRepo.saveAttendanceBatch(
        schoolId: school.id,
        academicYearId: year.id,
        classId: cls.id,
        sectionId: sec.id,
        date: '2026-09-09',
        studentStatusMap: {student.id: AttendanceStatus.present},
        markedByUserId: 'admin-1',
      );

      await db.close();

      // Reopen
      db = AppDatabase(NativeDatabase(dbFile));
      auditRepo = AuditRepository(db);
      attendanceRepo = AttendanceRepository(db, auditRepo);

      final records = await attendanceRepo.getSectionAttendanceForDate(
        academicYearId: year.id,
        sectionId: sec.id,
        date: '2026-09-09',
      );

      expect(records.containsKey(student.id), isTrue);
      expect(records[student.id]!.status, AttendanceStatus.present);

      final summary = await attendanceRepo.getDailySummary(
        schoolId: school.id,
        date: '2026-09-09',
      );
      expect(summary.totalCount, 1);
      expect(summary.presentCount, 1);
      expect(summary.attendancePercentage, 100.0);

      await db.close();
    },
  );

  test(
    'Test 4: Full Multi-Entity Persistence (School, Year, Class, Section, Subject, Teacher, Student, Enrollment, Attendance)',
    () async {
      var db = AppDatabase(NativeDatabase(dbFile));
      var auditRepo = AuditRepository(db);
      var schoolRepo = SchoolRepository(db, auditRepo);
      var authRepo = AuthRepository(db, auditRepo);
      var academicRepo = AcademicYearRepository(db, auditRepo);
      var classesRepo = ClassesRepository(db, auditRepo);
      var subjectsRepo = SubjectsRepository(db, auditRepo);
      var teachersRepo = TeachersRepository(db, auditRepo, authRepo);
      var studentsRepo = StudentsRepository(db, auditRepo);
      var attendanceRepo = AttendanceRepository(db, auditRepo);

      // 1. School
      final school = await schoolRepo.createSchool(
        name: 'Full Test Academy',
        principalName: 'Principal Karki',
      );

      // 2. Admin
      final admin = await authRepo.createAdministrator(
        schoolId: school.id,
        name: 'Admin User',
        username: 'admin',
        password: 'password123',
      );

      // 3. Academic Year
      final year = await academicRepo.createAcademicYear(
        schoolId: school.id,
        name: '2026/27',
        startDate: DateTime(2026, 4, 1),
        endDate: DateTime(2027, 3, 31),
        isCurrent: true,
      );

      // 4. Class & Section
      final cls = await classesRepo.createClass(
        schoolId: school.id,
        academicYearId: year.id,
        name: 'Grade 10',
        displayOrder: 10,
      );
      final sec = await classesRepo.createSection(
        classId: cls.id,
        name: 'Section A',
        capacity: 35,
      );

      // 5. Subject
      await subjectsRepo.createSubject(
        schoolId: school.id,
        name: 'Science',
        code: 'SCI10',
      );

      // 6. Teacher
      await teachersRepo.createTeacher(
        schoolId: school.id,
        employeeCode: 'TEA01',
        name: 'Ram Sharma',
      );

      // 7. Student & Enrollment
      final student = await studentsRepo.createStudent(
        schoolId: school.id,
        studentCode: 'G1001',
        firstName: 'Bikash',
        lastName: 'Rai',
      );
      await studentsRepo.enrollStudent(
        schoolId: school.id,
        studentId: student.id,
        academicYearId: year.id,
        classId: cls.id,
        sectionId: sec.id,
        rollNumber: 1,
      );

      // 8. Attendance
      await attendanceRepo.saveAttendanceBatch(
        schoolId: school.id,
        academicYearId: year.id,
        classId: cls.id,
        sectionId: sec.id,
        date: '2026-09-09',
        studentStatusMap: {student.id: AttendanceStatus.late},
        markedByUserId: admin.id,
      );

      // 9. Timetable
      var timetableRepo = TimetableRepository(db, auditRepo);
      final subject = (await subjectsRepo.getSubjects(school.id)).first;
      await timetableRepo.createEntry(
        schoolId: school.id,
        academicYearId: year.id,
        classId: cls.id,
        sectionId: sec.id,
        dayOfWeek: 1,
        period: 1,
        subjectId: subject.id,
        startTime: '09:00',
        endTime: '09:45',
        room: '101',
      );

      // Close Database
      await db.close();

      // Reopen brand new instance
      db = AppDatabase(NativeDatabase(dbFile));
      auditRepo = AuditRepository(db);
      schoolRepo = SchoolRepository(db, auditRepo);
      authRepo = AuthRepository(db, auditRepo);
      academicRepo = AcademicYearRepository(db, auditRepo);
      classesRepo = ClassesRepository(db, auditRepo);
      subjectsRepo = SubjectsRepository(db, auditRepo);
      teachersRepo = TeachersRepository(db, auditRepo, authRepo);
      studentsRepo = StudentsRepository(db, auditRepo);
      attendanceRepo = AttendanceRepository(db, auditRepo);
      timetableRepo = TimetableRepository(db, auditRepo);

      // Verify all entities intact
      final reloadedSchool = await schoolRepo.getSchoolById(school.id);
      expect(reloadedSchool!.name, 'Full Test Academy');

      final reloadedAdmin = await authRepo.login(
        usernameOrEmail: 'admin',
        password: 'password123',
      );
      expect(reloadedAdmin.name, 'Admin User');

      final reloadedYear = await academicRepo.getCurrentAcademicYear(school.id);
      expect(reloadedYear!.name, '2026/27');

      final reloadedClasses = await classesRepo.getClasses(
        schoolId: school.id,
        academicYearId: year.id,
      );
      expect(reloadedClasses.length, 1);
      expect(reloadedClasses.first.name, 'Grade 10');

      final reloadedSections = await classesRepo.getSections(cls.id);
      expect(reloadedSections.length, 1);
      expect(reloadedSections.first.name, 'Section A');

      final reloadedSubjects = await subjectsRepo.getSubjects(school.id);
      expect(reloadedSubjects.length, 1);
      expect(reloadedSubjects.first.code, 'SCI10');

      final reloadedTeachers = await teachersRepo.getTeachers(school.id);
      expect(reloadedTeachers.length, 1);
      expect(reloadedTeachers.first.name, 'Ram Sharma');

      final enrolledStudents = await studentsRepo.getEnrolledStudentsForSection(
        academicYearId: year.id,
        sectionId: sec.id,
      );
      expect(enrolledStudents.length, 1);
      expect(enrolledStudents.first.student.firstName, 'Bikash');
      expect(enrolledStudents.first.enrollment.rollNumber, 1);

      final attendanceRecords = await attendanceRepo
          .getSectionAttendanceForDate(
            academicYearId: year.id,
            sectionId: sec.id,
            date: '2026-09-09',
          );
      expect(attendanceRecords[student.id]!.status, AttendanceStatus.late);

      final reloadedTimetable = await timetableRepo.getTimetableForSection(
        sec.id,
      );
      expect(reloadedTimetable.length, 1);
      expect(reloadedTimetable.first.entry.room, '101');
      expect(reloadedTimetable.first.entry.startTime, '09:00');

      await db.close();
    },
  );
}
