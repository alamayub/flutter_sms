part of 'app_database.dart';

@DataClassName('PeriodEntry')
class PeriodEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get academicYearId =>
      integer().references(AcademicYears, #id, onDelete: KeyAction.cascade)();
  IntColumn get classId =>
      integer().references(SchoolClasses, #id, onDelete: KeyAction.cascade)();
  IntColumn get sectionId =>
      integer().nullable().references(
        Sections,
        #id,
        onDelete: KeyAction.cascade,
      )();
  TextColumn get dayOfWeek => text()();
  // 'sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'
  IntColumn get periodNumber => integer().withDefault(const Constant(1))();
  TextColumn get startTime => text()(); // e.g. "10:15"
  TextColumn get endTime => text()(); // e.g. "11:00"
  BoolColumn get isBreak => boolean().withDefault(const Constant(false))();
  TextColumn get breakTitle => text().nullable()(); // e.g. "Lunch Break"
  IntColumn get subjectId =>
      integer().nullable().references(
        Subjects,
        #id,
        onDelete: KeyAction.setNull,
      )();
  IntColumn get teacherId =>
      integer().nullable().references(
        Employees,
        #id,
        onDelete: KeyAction.setNull,
      )();
  TextColumn get roomNumber => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Composite model for Period with its joined subject, teacher, class, section, and academic year
class PeriodWithDetails {
  final PeriodEntry period;
  final Subject? subject;
  final Employee? teacher;
  final SchoolClass? schoolClass;
  final Section? section;
  final AcademicYear? academicYear;

  const PeriodWithDetails({
    required this.period,
    this.subject,
    this.teacher,
    this.schoolClass,
    this.section,
    this.academicYear,
  });

  int get id => period.id;
  int get academicYearId => period.academicYearId;
  int get classId => period.classId;
  int? get sectionId => period.sectionId;
  String get dayOfWeek => period.dayOfWeek;
  int get periodNumber => period.periodNumber;
  String get startTime => period.startTime;
  String get endTime => period.endTime;
  bool get isBreak => period.isBreak;
  String? get breakTitle => period.breakTitle;
  int? get subjectId => period.subjectId;
  int? get teacherId => period.teacherId;
  String? get roomNumber => period.roomNumber;

  AcademicYear? get academicYearObj => academicYear;
  SchoolClass? get schoolClassObj => schoolClass;
  Section? get sectionObj => section;
  Subject? get subjectObj => subject;
  Employee? get teacherObj => teacher;

  String get displayName {
    if (isBreak) {
      return breakTitle ?? 'Break';
    }
    return subject?.name ?? 'No Subject';
  }
}
