part of 'app_database.dart';

@DataClassName('StudentAttendance')
class StudentAttendances extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get studentId =>
      integer().references(Students, #id, onDelete: KeyAction.cascade)();
  IntColumn get academicYearId =>
      integer().references(AcademicYears, #id, onDelete: KeyAction.cascade)();
  IntColumn get classId =>
      integer().references(SchoolClasses, #id, onDelete: KeyAction.cascade)();
  IntColumn get sectionId =>
      integer().nullable().references(
        Sections,
        #id,
        onDelete: KeyAction.setNull,
      )();
  DateTimeColumn get date => dateTime()();
  TextColumn get status => textEnum<AttendanceStatus>()();
  TextColumn get remarks => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
    {studentId, date},
  ];
}

@DataClassName('EmployeeAttendance')
class EmployeeAttendances extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get employeeId =>
      integer().references(Employees, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get date => dateTime()();
  TextColumn get status => textEnum<AttendanceStatus>()();
  TextColumn get checkInTime => text().nullable()();
  TextColumn get checkOutTime => text().nullable()();
  TextColumn get remarks => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
    {employeeId, date},
  ];
}

class StudentAttendanceWithStudent {
  final StudentAttendance attendance;
  final Student student;

  const StudentAttendanceWithStudent({
    required this.attendance,
    required this.student,
  });
}

class EmployeeAttendanceWithEmployee {
  final EmployeeAttendance attendance;
  final Employee employee;

  const EmployeeAttendanceWithEmployee({
    required this.attendance,
    required this.employee,
  });
}
