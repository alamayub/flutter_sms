import 'package:isar/isar.dart';

part 'student_model.g.dart';

@Collection()
class StudentModel {
  Id id = Isar.autoIncrement;

  late String firstName;
  late String? middleName;
  late String lastName;
  late String dob;
  late String grade;
  late String section;
  late String rollNo;
  late String address;
  late String createdBy;
  late String createdAt;
  late String? updatedBy;
  late String? updatedAt;

  @ignore
  String get fullName => '$firstName $middleName $lastName';
}
