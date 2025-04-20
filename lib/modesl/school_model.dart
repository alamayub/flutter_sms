import 'package:isar/isar.dart';

part 'school_model.g.dart';

@collection
class SchoolModel {
  Id id = Isar.autoIncrement;

  late String name;
  late String address;

  @Index(unique: true, caseSensitive: false)
  late String username;

  late String password;
}
