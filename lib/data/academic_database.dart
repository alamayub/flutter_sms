part of 'app_database.dart';

class AcademicYears extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime()();
  BoolColumn get isCurrent => boolean().withDefault(const Constant(false))();
  TextColumn get description => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('SchoolClass')
class SchoolClasses extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 50)();
  TextColumn get displayName => text().withLength(min: 1, max: 100)();
  IntColumn get orderIndex => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('Section')
class Sections extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get classId =>
      integer().references(SchoolClasses, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text().withLength(min: 1, max: 50)();
  TextColumn get roomNumber => text().nullable()();
  IntColumn get capacity => integer().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Composite model representing a class along with all its sections
class ClassWithSections {
  final SchoolClass schoolClass;
  final List<Section> sections;

  const ClassWithSections({required this.schoolClass, required this.sections});

  int get id => schoolClass.id;
  String get name => schoolClass.name;
  String get displayName => schoolClass.displayName;
  int get orderIndex => schoolClass.orderIndex;

  ClassWithSections copyWith({
    SchoolClass? schoolClass,
    List<Section>? sections,
  }) {
    return ClassWithSections(
      schoolClass: schoolClass ?? this.schoolClass,
      sections: sections ?? this.sections,
    );
  }
}

@DataClassName('Subject')
class Subjects extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get code => text().withLength(min: 1, max: 30)();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get subjectType => textEnum<SubjectType>()();
  BoolColumn get isOptional => boolean().withDefault(const Constant(false))();
  IntColumn get fullMarks => integer().withDefault(const Constant(100))();
  IntColumn get passMarks => integer().withDefault(const Constant(40))();
  IntColumn get theoryMarks => integer().nullable()();
  IntColumn get practicalMarks => integer().nullable()();
  TextColumn get description => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
