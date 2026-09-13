part of 'app_database.dart';

@DataClassName('Certificate')
class Certificates extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get certificateNumber =>
      text().unique().withLength(min: 1, max: 60)();
  IntColumn get studentId =>
      integer().references(Students, #id, onDelete: KeyAction.cascade)();
  IntColumn get academicYearId =>
      integer().nullable().references(
        AcademicYears,
        #id,
        onDelete: KeyAction.setNull,
      )();
  // 'tc', 'cc', 'bonafide', 'marksheet', 'custom'
  TextColumn get certificateType => text()();
  // e.g. "Transfer Certificate", "Character Certificate"
  TextColumn get title => text().withLength(min: 1, max: 150)();
  DateTimeColumn get issueDate => dateTime()();
  // 'issued', 'draft', 'revoked'
  TextColumn get status => text().withDefault(const Constant('issued'))();
  // e.g. Reason for leaving, purpose of bonafide
  TextColumn get reason => text().nullable()();
  // e.g. "Good", "Exemplary", "Very Good"
  TextColumn get conduct => text().nullable()();
  BoolColumn get duesCleared => boolean().withDefault(const Constant(true))();
  TextColumn get remarks => text().nullable()();
  TextColumn get issuedBy => text().nullable()();
  // JSON payload for Mark Sheet / TC / CC / Bonafide / Custom specifics
  TextColumn get dataJson => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class CertificateWithDetails {
  final Certificate certificate;
  final Student student;
  final SchoolClass? schoolClass;
  final Section? section;
  final AcademicYear? academicYear;

  const CertificateWithDetails({
    required this.certificate,
    required this.student,
    this.schoolClass,
    this.section,
    this.academicYear,
  });

  int get id => certificate.id;
  String get certificateNumber => certificate.certificateNumber;
  String get certificateType => certificate.certificateType;
  String get title => certificate.title;
  DateTime get issueDate => certificate.issueDate;
  String get status => certificate.status;
  String? get reason => certificate.reason;
  String? get conduct => certificate.conduct;
  bool get duesCleared => certificate.duesCleared;
  String? get remarks => certificate.remarks;
  String? get issuedBy => certificate.issuedBy;
  String? get dataJson => certificate.dataJson;
  DateTime get createdAt => certificate.createdAt;

  String get studentName => student.name;
  String get admissionNumber => student.admissionNumber;
  int? get rollNumber => student.rollNumber;
  String? get className => schoolClass?.name;
  String? get sectionName => section?.name;
  String? get academicYearName => academicYear?.name;
}

/// Exam Master Table (e.g. First Terminal Exam, Unit Test 1, Half Yearly, Final Exam)
