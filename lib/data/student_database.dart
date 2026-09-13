part of 'app_database.dart';

@DataClassName('Student')
class Students extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get studentId => text().unique().withLength(min: 1, max: 20)();
  TextColumn get admissionNumber =>
      text().unique().withLength(min: 1, max: 30)();
  DateTimeColumn get admissionDate => dateTime()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get gender => text().withLength(min: 1, max: 20)();
  // 'Male', 'Female', 'Other'
  DateTimeColumn get dateOfBirth => dateTime().nullable()();
  TextColumn get bloodGroup => text().nullable()();
  // 'A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'
  TextColumn get address => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get photoPath => text().nullable()();

  // Emergency contact fields (denormalized for rapid access)
  TextColumn get emergencyContactName => text().nullable()();
  TextColumn get emergencyContactPhone => text().nullable()();
  TextColumn get emergencyContactRelation => text().nullable()();

  // Current enrolled reference (cached for quick lookups & backwards compatibility)
  IntColumn get classId =>
      integer().nullable().references(
        SchoolClasses,
        #id,
        onDelete: KeyAction.setNull,
      )();
  IntColumn get sectionId =>
      integer().nullable().references(
        Sections,
        #id,
        onDelete: KeyAction.setNull,
      )();
  IntColumn get rollNumber => integer().nullable()();

  // Facility Opt-in flags
  BoolColumn get hasTransport => boolean().withDefault(const Constant(false))();
  BoolColumn get hasHostel => boolean().withDefault(const Constant(false))();
  BoolColumn get hasLibrary => boolean().withDefault(const Constant(false))();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('StudentAcademicHistory')
class StudentAcademicHistories extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get studentId =>
      integer().references(Students, #id, onDelete: KeyAction.cascade)();
  IntColumn get academicYearId =>
      integer().references(AcademicYears, #id, onDelete: KeyAction.cascade)();
  IntColumn get classId =>
      integer().references(SchoolClasses, #id, onDelete: KeyAction.cascade)();
  IntColumn get sectionId =>
      integer().references(Sections, #id, onDelete: KeyAction.cascade)();
  IntColumn get rollNumber => integer().nullable()();
  TextColumn get status =>
      textEnum<AcademicStatus>().withDefault(
        Constant(AcademicStatus.active.name),
      )();
  TextColumn get resultStatus =>
      textEnum<AcademicResult>().withDefault(
        Constant(AcademicResult.pending.name),
      )();
  TextColumn get remarks => text().nullable()();
  DateTimeColumn get enrolledAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
    {studentId, academicYearId},
  ];
}

/// Composite model representing a student with full current enrollment details
class StudentWithDetails {
  final Student student;
  final SchoolClass? currentClass;
  final Section? currentSection;
  final StudentAcademicHistory? currentEnrollment;
  final AcademicYear? currentAcademicYear;

  const StudentWithDetails({
    required this.student,
    this.currentClass,
    this.currentSection,
    this.currentEnrollment,
    this.currentAcademicYear,
  });

  int get id => student.id;
  String get name => student.name;
  String get studentId => student.studentId;
  String get admissionNumber => student.admissionNumber;
  DateTime get admissionDate => student.admissionDate;
  String get gender => student.gender;
  DateTime? get dateOfBirth => student.dateOfBirth;
  String? get bloodGroup => student.bloodGroup;
  String? get address => student.address;
  String? get phone => student.phone;
  String? get email => student.email;
  String? get photoPath => student.photoPath;
  String? get emergencyContactName => student.emergencyContactName;
  String? get emergencyContactPhone => student.emergencyContactPhone;
  String? get emergencyContactRelation => student.emergencyContactRelation;
  int? get classId => student.classId;
  int? get sectionId => student.sectionId;
  int? get rollNumber => currentEnrollment?.rollNumber ?? student.rollNumber;
  bool get hasTransport => student.hasTransport;
  bool get hasHostel => student.hasHostel;
  bool get hasLibrary => student.hasLibrary;
  bool get isActive => student.isActive;
}

/// Composite model representing a single academic history record with year, class, and section
class StudentAcademicHistoryWithDetails {
  final StudentAcademicHistory history;
  final AcademicYear academicYear;
  final SchoolClass schoolClass;
  final Section section;

  const StudentAcademicHistoryWithDetails({
    required this.history,
    required this.academicYear,
    required this.schoolClass,
    required this.section,
  });

  int get id => history.id;
  int get studentId => history.studentId;
  int get academicYearId => history.academicYearId;
  int get classId => history.classId;
  int get sectionId => history.sectionId;
  int? get rollNumber => history.rollNumber;
  AcademicStatus get status => history.status;
  AcademicResult get resultStatus => history.resultStatus;
  String? get remarks => history.remarks;
  DateTime get enrolledAt => history.enrolledAt;
}
