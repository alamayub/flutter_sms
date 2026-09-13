part of 'app_database.dart';

@DataClassName('Employee')
class Employees extends Table {
  IntColumn get id => integer().autoIncrement()();
  // e.g. "EMP-2026-001", "TCH-001"
  TextColumn get employeeCode => text().nullable()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  // 'teacher' or 'staff'
  TextColumn get employeeType => textEnum<EmployeeType>()();
  // 'Teacher', 'Peon', 'Accountant', etc.
  TextColumn get designation => text().withLength(min: 1, max: 100)();
  TextColumn get email => text().nullable()();
  TextColumn get phone => text().nullable()();
  // Local image path or avatar URI
  TextColumn get photoPath => text().nullable()();
  // Emergency Contact Details
  TextColumn get emergencyContactName => text().nullable()();
  TextColumn get emergencyContactPhone => text().nullable()();
  // Spouse, Parent, Sibling, Relative, etc.
  TextColumn get emergencyContactRelation => text().nullable()();

  // Optional biographical & personal information
  // AD date only, converted to BS for display
  DateTimeColumn get dateOfBirth => dateTime().nullable()();
  TextColumn get gender => text().nullable()(); // 'Male', 'Female', 'Other'
  TextColumn get bloodGroup => text().nullable()(); // 'A+', 'B+', 'O+', etc.
  // 'Single', 'Married', etc.
  TextColumn get maritalStatus => text().nullable()();
  TextColumn get address => text().nullable()();

  // Optional professional details
  // e.g. 'M.Sc. B.Ed', 'B.B.S', 'Under SLC'
  TextColumn get qualification => text().nullable()();
  // e.g. 'Mathematics', 'Accounts', 'Administration'
  TextColumn get department => text().nullable()();
  DateTimeColumn get joiningDate => dateTime().nullable()();
  RealColumn get basicSalary => real().nullable()();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
