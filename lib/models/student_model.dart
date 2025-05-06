import 'package:isar/isar.dart';

part 'student_model.g.dart';

@Collection()
class StudentModel {
  Id id = Isar.autoIncrement;

  late String firstName;
  String? middleName;
  late String lastName;
  late String dob;
  late double fee;
  late String grade;
  late String section;
  late String rollNo;
  late String address;
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
