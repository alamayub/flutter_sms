import 'package:isar/isar.dart';

part 'staff_model.g.dart';

@collection
class StaffModel {
  Id id = Isar.autoIncrement;

  late String firstName;
  String? middleName;
  late String lastName;

  @Index(unique: true)
  late String phoneNumber;

  late String address;
  late String joiningDate;
  late double salary;

  late int createdBy;
  late String createdAt;
  int? updatedBy;
  String? updatedAt;

  @ignore
  String get fullName => [
    firstName,
    middleName,
    lastName,
  ].where((e) => e != null && e.trim().isNotEmpty).join(' ');
}
