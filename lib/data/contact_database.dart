part of 'app_database.dart';

@DataClassName('Contact')
class Contacts extends Table {
  IntColumn get id => integer().autoIncrement()();
  // 'student', 'employee', 'other'
  TextColumn get sourceType => textEnum<ContactSourceType>()();
  // Student ID or Employee ID (or null for general/other contacts)
  IntColumn get sourceId => integer().nullable()();
  // Denormalized name of the student/employee for fast display & search
  TextColumn get sourceName => text().nullable()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get phone => text().withLength(min: 1, max: 25)();
  // 'Father', 'Mother', 'Guardian', 'Spouse', 'Sibling', 'Doctor', etc.
  TextColumn get relation => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get occupation => text().nullable()();
  BoolColumn get isEmergency => boolean().withDefault(const Constant(false))();
  BoolColumn get isPrimary => boolean().withDefault(const Constant(false))();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
