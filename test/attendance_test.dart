import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sms/config/enums.dart';
import 'package:sms/data/app_database.dart';
import 'package:sms/data/database_seeder.dart';
import 'package:sms/services/attendance_service.dart';
import 'helpers/test_data_seeder.dart';

void main() {
  late AppDatabase db;
  late AttendanceService service;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    service = AttendanceService(db);
    // Seed prerequisite data
    await DatabaseSeeder.seedAcademicYears(db);
    await DatabaseSeeder.seedClassesAndSections(db);
    await TestDataSeeder.seedStudents(db);
    await TestDataSeeder.seedEmployees(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('AttendanceStatus Enum Tests', () {
    test('displayName and shortCode return expected values', () {
      expect(AttendanceStatus.present.displayName, 'Present');
      expect(AttendanceStatus.present.shortCode, 'P');

      expect(AttendanceStatus.absent.displayName, 'Absent');
      expect(AttendanceStatus.absent.shortCode, 'A');

      expect(AttendanceStatus.late.displayName, 'Late');
      expect(AttendanceStatus.late.shortCode, 'L');

      expect(AttendanceStatus.halfDay.displayName, 'Half Day');
      expect(AttendanceStatus.halfDay.shortCode, 'HD');

      expect(AttendanceStatus.onLeave.displayName, 'On Leave');
      expect(AttendanceStatus.onLeave.shortCode, 'LV');

      expect(AttendanceStatus.excused.displayName, 'Excused');
      expect(AttendanceStatus.excused.shortCode, 'EX');
    });
  });

  group('Attendance Calculation Unit Tests', () {
    test('calculateStudentSummary handles empty list correctly', () {
      final summary = service.calculateStudentSummary([]);
      expect(summary.total, 0);
      expect(summary.present, 0);
      expect(summary.percentage, 0.0);
    });

    test(
      'calculateStudentSummary calculates correct counts and percentage',
      () {
        final now = DateTime.now();
        final dummyStudent = Student(
          id: 1,
          studentId: 'STU-001',
          admissionNumber: 'ADM-001',
          admissionDate: now,
          name: 'Test Student',
          gender: 'Male',
          hasTransport: false,
          hasHostel: false,
          hasLibrary: false,
          isActive: true,
          createdAt: now,
        );

        final items = [
          StudentAttendanceRecordItem(
            student: dummyStudent,
            status: AttendanceStatus.present,
          ),
          StudentAttendanceRecordItem(
            student: dummyStudent,
            status: AttendanceStatus.present,
          ),
          StudentAttendanceRecordItem(
            student: dummyStudent,
            status: AttendanceStatus.late,
          ),
          StudentAttendanceRecordItem(
            student: dummyStudent,
            status: AttendanceStatus.halfDay,
          ),
          StudentAttendanceRecordItem(
            student: dummyStudent,
            status: AttendanceStatus.absent,
          ),
          StudentAttendanceRecordItem(
            student: dummyStudent,
            status: AttendanceStatus.excused,
          ),
        ];

        final summary = service.calculateStudentSummary(items);
        expect(summary.total, 6);
        expect(summary.present, 2);
        expect(summary.late, 1);
        expect(summary.halfDay, 1);
        expect(summary.absent, 1);
        expect(summary.excusedOrLeave, 1);

        // (2 present + 1 late + 0.5 halfDay) = 3.5 out of 6 = 58.3%
        expect(summary.percentage, 58.3);
      },
    );

    test('calculateStaffSummary handles onLeave and calculates percentage', () {
      final now = DateTime.now();
      final dummyEmp = Employee(
        id: 1,
        name: 'Test Teacher',
        employeeType: EmployeeType.teacher,
        designation: 'Teacher',
        isActive: true,
        createdAt: now,
      );

      final items = [
        StaffAttendanceRecordItem(
          employee: dummyEmp,
          status: AttendanceStatus.present,
        ),
        StaffAttendanceRecordItem(
          employee: dummyEmp,
          status: AttendanceStatus.present,
        ),
        StaffAttendanceRecordItem(
          employee: dummyEmp,
          status: AttendanceStatus.onLeave,
        ),
        StaffAttendanceRecordItem(
          employee: dummyEmp,
          status: AttendanceStatus.absent,
        ),
      ];

      final summary = service.calculateStaffSummary(items);
      expect(summary.total, 4);
      expect(summary.present, 2);
      expect(summary.excusedOrLeave, 1);
      expect(summary.absent, 1);
      expect(summary.percentage, 50.0);
    });
  });

  group('Student Attendance Database Operations', () {
    test(
      'getStudentsWithAttendanceForDate returns active students with default status on unrecorded date',
      () async {
        final allStudents = await db.getAllStudents();
        expect(allStudents.isNotEmpty, isTrue);

        final studentClassId = allStudents.first.classId!;
        final unrecordedDate = DateTime(2026, 11, 15);

        final items = await service.getStudentsWithAttendanceForDate(
          classId: studentClassId,
          date: unrecordedDate,
        );

        expect(items.isNotEmpty, isTrue);
        for (final item in items) {
          expect(item.status, AttendanceStatus.present);
          expect(item.student.classId, studentClassId);
        }
      },
    );

    test(
      'saveStudentAttendanceBatch persists and updates records without duplicates',
      () async {
        final allStudents = await db.getAllStudents();
        final currentYear = await db.getCurrentAcademicYear();
        expect(currentYear, isNotNull);

        final studentsInClass = <int, int>{};
        for (final s in allStudents) {
          if (s.classId != null) {
            studentsInClass[s.classId!] =
                (studentsInClass[s.classId!] ?? 0) + 1;
          }
        }
        final studentClassId =
            studentsInClass.entries.firstWhere((e) => e.value >= 2).key;
        final testDate = DateTime(2026, 11, 20);

        final items = await service.getStudentsWithAttendanceForDate(
          classId: studentClassId,
          date: testDate,
        );
        expect(items.length, greaterThanOrEqualTo(2));

        // Mark first student absent and second student late
        items[0].status = AttendanceStatus.absent;
        items[0].remarks = 'Fever';
        items[1].status = AttendanceStatus.late;
        items[1].remarks = 'Traffic';

        await service.saveStudentAttendanceBatch(
          academicYearId: currentYear!.id,
          classId: studentClassId,
          date: testDate,
          records: items,
        );

        // Re-fetch
        final reloaded = await service.getStudentsWithAttendanceForDate(
          classId: studentClassId,
          date: testDate,
        );

        expect(reloaded[0].status, AttendanceStatus.absent);
        expect(reloaded[0].remarks, 'Fever');
        expect(reloaded[1].status, AttendanceStatus.late);
        expect(reloaded[1].remarks, 'Traffic');

        // Update record for student 0 to present
        reloaded[0].status = AttendanceStatus.present;
        reloaded[0].remarks = 'Recovered and attended';

        await service.saveStudentAttendanceBatch(
          academicYearId: currentYear.id,
          classId: studentClassId,
          date: testDate,
          records: reloaded,
        );

        final updatedReload = await service.getStudentsWithAttendanceForDate(
          classId: studentClassId,
          date: testDate,
        );
        expect(updatedReload[0].status, AttendanceStatus.present);
        expect(updatedReload[0].remarks, 'Recovered and attended');
      },
    );

    test(
      'getStudentMonthlyRegister returns student-by-day attendance register',
      () async {
        final allStudents = await db.getAllStudents();
        final currentYear = await db.getCurrentAcademicYear();
        final studentClassId = allStudents.first.classId!;

        final day1 = DateTime(2026, 11, 1);
        final day2 = DateTime(2026, 11, 2);

        final itemsDay1 = await service.getStudentsWithAttendanceForDate(
          classId: studentClassId,
          date: day1,
        );
        itemsDay1[0].status = AttendanceStatus.present;
        await service.saveStudentAttendanceBatch(
          academicYearId: currentYear!.id,
          classId: studentClassId,
          date: day1,
          records: itemsDay1,
        );

        final itemsDay2 = await service.getStudentsWithAttendanceForDate(
          classId: studentClassId,
          date: day2,
        );
        itemsDay2[0].status = AttendanceStatus.absent;
        await service.saveStudentAttendanceBatch(
          academicYearId: currentYear.id,
          classId: studentClassId,
          date: day2,
          records: itemsDay2,
        );

        final register = await service.getStudentMonthlyRegister(
          classId: studentClassId,
          year: 2026,
          month: 11,
        );

        expect(register.isNotEmpty, isTrue);
        final student1Row = register.first;
        expect(student1Row.dayStatusMap[1], AttendanceStatus.present);
        expect(student1Row.dayStatusMap[2], AttendanceStatus.absent);
        expect(student1Row.presentDays, 1);
        expect(student1Row.absentDays, 1);
        expect(student1Row.totalWorkingDays, 2);
        expect(student1Row.attendancePercentage, 50.0);
      },
    );
  });

  group('Staff Attendance Database Operations', () {
    test(
      'getStaffWithAttendanceForDate returns active staff with default times on unrecorded date',
      () async {
        final unrecordedDate = DateTime(2026, 11, 15);
        final items = await service.getStaffWithAttendanceForDate(
          date: unrecordedDate,
        );

        expect(items.isNotEmpty, isTrue);
        for (final item in items) {
          expect(item.status, AttendanceStatus.present);
          expect(item.checkInTime, isNotNull);
          expect(item.checkOutTime, isNotNull);
        }
      },
    );

    test(
      'saveStaffAttendanceBatch persists and updates staff attendance',
      () async {
        final date = DateTime(2026, 11, 25);
        final items = await service.getStaffWithAttendanceForDate(date: date);
        expect(items.isNotEmpty, isTrue);

        items[0].status = AttendanceStatus.onLeave;
        items[0].remarks = 'Sick leave';
        items[0].checkInTime = null;
        items[0].checkOutTime = null;

        await service.saveStaffAttendanceBatch(date: date, records: items);

        final reloaded = await service.getStaffWithAttendanceForDate(
          date: date,
        );
        expect(reloaded[0].status, AttendanceStatus.onLeave);
        expect(reloaded[0].remarks, 'Sick leave');
      },
    );

    test(
      'getStaffWithAttendanceForDate filters by department and employeeType',
      () async {
        final date = DateTime(2026, 11, 15);

        final teachers = await service.getStaffWithAttendanceForDate(
          date: date,
          employeeType: EmployeeType.teacher,
        );
        for (final t in teachers) {
          expect(t.employee.employeeType, EmployeeType.teacher);
        }

        final staff = await service.getStaffWithAttendanceForDate(
          date: date,
          employeeType: EmployeeType.staff,
        );
        for (final s in staff) {
          expect(s.employee.employeeType, EmployeeType.staff);
        }
      },
    );

    test(
      'getStaffMonthlyRegister returns month matrix for employees',
      () async {
        final day1 = DateTime(2026, 11, 1);
        final staffItems = await service.getStaffWithAttendanceForDate(
          date: day1,
        );
        staffItems[0].status = AttendanceStatus.present;

        await service.saveStaffAttendanceBatch(date: day1, records: staffItems);

        final register = await service.getStaffMonthlyRegister(
          year: 2026,
          month: 11,
        );

        expect(register.isNotEmpty, isTrue);
        final firstRow = register.first;
        expect(firstRow.dayStatusMap[1], AttendanceStatus.present);
        expect(firstRow.presentDays, 1);
      },
    );
  });

  group('DatabaseSeeder Attendance Regression Test', () {
    test(
      'seedAttendance populates multiple days of student and staff attendance',
      () async {
        await TestDataSeeder.seedAttendance(db);

        final allStudents = await db.getAllStudents();
        expect(allStudents.isNotEmpty, isTrue);
        final studentClassId = allStudents.first.classId!;

        final today = DateTime.now();
        final normalizedToday = DateTime(today.year, today.month, today.day);

        final studentAttendance = await db.getStudentAttendancesForClassAndDate(
          classId: studentClassId,
          date: normalizedToday,
        );
        expect(studentAttendance.isNotEmpty, isTrue);

        final staffAttendance = await db.getEmployeeAttendancesForDate(
          date: normalizedToday,
        );
        expect(staffAttendance.isNotEmpty, isTrue);
      },
    );
  });
}
