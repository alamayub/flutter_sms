part of 'app_database.dart';

@DataClassName('Exam')
class Exams extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 150)();
  TextColumn get category => text().withLength(min: 1, max: 80)();
  IntColumn get academicYearId =>
      integer().references(AcademicYears, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime()();
  TextColumn get description => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('Scheduled'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Exam Subject Routine / Timetable per Class
@DataClassName('ExamSchedule')
class ExamSchedules extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get examId =>
      integer().references(Exams, #id, onDelete: KeyAction.cascade)();
  IntColumn get academicYearId =>
      integer().references(AcademicYears, #id, onDelete: KeyAction.cascade)();
  IntColumn get classId =>
      integer().references(SchoolClasses, #id, onDelete: KeyAction.cascade)();
  IntColumn get subjectId =>
      integer().references(Subjects, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get examDate => dateTime()();
  TextColumn get startTime => text().withLength(min: 1, max: 30)();
  TextColumn get endTime => text().withLength(min: 1, max: 30)();
  IntColumn get fullMarks => integer().withDefault(const Constant(100))();
  IntColumn get passMarks => integer().withDefault(const Constant(40))();
  IntColumn get theoryMarks => integer().nullable()();
  IntColumn get practicalMarks => integer().nullable()();
  TextColumn get roomNumber => text().nullable()();
  TextColumn get remarks => text().nullable()();
  IntColumn get orderIndex => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('ExamResult')
class ExamResults extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get examId =>
      integer().references(Exams, #id, onDelete: KeyAction.cascade)();
  IntColumn get academicYearId =>
      integer().references(AcademicYears, #id, onDelete: KeyAction.cascade)();
  IntColumn get classId =>
      integer().references(SchoolClasses, #id, onDelete: KeyAction.cascade)();
  IntColumn get sectionId =>
      integer().nullable().references(
        Sections,
        #id,
        onDelete: KeyAction.setNull,
      )();
  IntColumn get studentId =>
      integer().references(Students, #id, onDelete: KeyAction.cascade)();
  IntColumn get subjectId =>
      integer().references(Subjects, #id, onDelete: KeyAction.cascade)();
  IntColumn get examScheduleId =>
      integer().nullable().references(
        ExamSchedules,
        #id,
        onDelete: KeyAction.setNull,
      )();

  // Theory marks
  RealColumn get theoryMarksObtained =>
      real().withDefault(const Constant(0.0))();
  RealColumn get theoryFullMarks => real().withDefault(const Constant(100.0))();
  RealColumn get theoryPassMarks => real().withDefault(const Constant(40.0))();

  // Practical marks (nullable for subjects without practical)
  RealColumn get practicalMarksObtained => real().nullable()();
  RealColumn get practicalFullMarks => real().nullable()();
  RealColumn get practicalPassMarks => real().nullable()();

  // Aggregate Subject Marks
  RealColumn get totalMarksObtained =>
      real().withDefault(const Constant(0.0))();
  RealColumn get totalFullMarks => real().withDefault(const Constant(100.0))();
  RealColumn get totalPassMarks => real().withDefault(const Constant(40.0))();

  // Both Percentage and Grading stored persistently
  RealColumn get percentage => real().withDefault(const Constant(0.0))();
  RealColumn get gradePoint => real().withDefault(const Constant(0.0))();
  TextColumn get letterGrade =>
      text().withLength(min: 1, max: 10).withDefault(const Constant('F'))();
  BoolColumn get isPassed => boolean().withDefault(const Constant(false))();
  BoolColumn get isAbsent => boolean().withDefault(const Constant(false))();

  TextColumn get remarks => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
    {examId, studentId, subjectId},
  ];
}

@DataClassName('ExamResultSummary')
class ExamResultSummaries extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get examId =>
      integer().references(Exams, #id, onDelete: KeyAction.cascade)();
  IntColumn get academicYearId =>
      integer().references(AcademicYears, #id, onDelete: KeyAction.cascade)();
  IntColumn get classId =>
      integer().references(SchoolClasses, #id, onDelete: KeyAction.cascade)();
  IntColumn get sectionId =>
      integer().nullable().references(
        Sections,
        #id,
        onDelete: KeyAction.setNull,
      )();
  IntColumn get studentId =>
      integer().references(Students, #id, onDelete: KeyAction.cascade)();

  RealColumn get totalMarksObtained =>
      real().withDefault(const Constant(0.0))();
  RealColumn get totalFullMarks => real().withDefault(const Constant(0.0))();
  RealColumn get overallPercentage => real().withDefault(const Constant(0.0))();
  RealColumn get overallGpa => real().withDefault(const Constant(0.0))();
  TextColumn get overallGrade =>
      text().withLength(min: 1, max: 10).withDefault(const Constant('F'))();

  IntColumn get totalSubjects => integer().withDefault(const Constant(0))();
  IntColumn get passedSubjects => integer().withDefault(const Constant(0))();
  IntColumn get failedSubjects => integer().withDefault(const Constant(0))();
  BoolColumn get isPassed => boolean().withDefault(const Constant(false))();
  IntColumn get rankInClass => integer().nullable()();
  IntColumn get rankInSection => integer().nullable()();

  TextColumn get remarks => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
    {examId, studentId},
  ];
}

/// Composite model for Exam with academic year and schedule counts
class ExamWithDetails {
  final Exam exam;
  final AcademicYear academicYear;
  final int scheduleCount;
  final int classCount;

  const ExamWithDetails({
    required this.exam,
    required this.academicYear,
    this.scheduleCount = 0,
    this.classCount = 0,
  });

  int get id => exam.id;
  String get name => exam.name;
  String get category => exam.category;
  int get academicYearId => exam.academicYearId;
  DateTime get startDate => exam.startDate;
  DateTime get endDate => exam.endDate;
  String? get description => exam.description;
  String get status => exam.status;
  DateTime get createdAt => exam.createdAt;
  String get academicYearName => academicYear.name;
}

/// Composite model for an ExamSchedule item with joined details
class ExamScheduleWithDetails {
  final ExamSchedule schedule;
  final Exam exam;
  final AcademicYear academicYear;
  final SchoolClass schoolClass;
  final Subject subject;

  const ExamScheduleWithDetails({
    required this.schedule,
    required this.exam,
    required this.academicYear,
    required this.schoolClass,
    required this.subject,
  });

  int get id => schedule.id;
  int get examId => schedule.examId;
  int get academicYearId => schedule.academicYearId;
  int get classId => schedule.classId;
  int get subjectId => schedule.subjectId;
  DateTime get examDate => schedule.examDate;
  String get startTime => schedule.startTime;
  String get endTime => schedule.endTime;
  int get fullMarks => schedule.fullMarks;
  int get passMarks => schedule.passMarks;
  int? get theoryMarks => schedule.theoryMarks;
  int? get practicalMarks => schedule.practicalMarks;
  String? get roomNumber => schedule.roomNumber;
  String? get remarks => schedule.remarks;
  int get orderIndex => schedule.orderIndex;

  int? get savedTheoryPassMarks {
    if (remarks != null && remarks!.startsWith('{') && remarks!.endsWith('}')) {
      try {
        final decoded = jsonDecode(remarks!);
        if (decoded is Map && decoded.containsKey('theoryPass')) {
          return decoded['theoryPass'] as int?;
        }
      } catch (_) {}
    }
    return null;
  }

  int? get savedPracticalPassMarks {
    if (remarks != null && remarks!.startsWith('{') && remarks!.endsWith('}')) {
      try {
        final decoded = jsonDecode(remarks!);
        if (decoded is Map && decoded.containsKey('practicalPass')) {
          return decoded['practicalPass'] as int?;
        }
      } catch (_) {}
    }
    return null;
  }

  String? get formattedRemarks {
    if (remarks == null || remarks!.isEmpty) return null;
    if (remarks!.startsWith('{') && remarks!.endsWith('}')) {
      try {
        final decoded = jsonDecode(remarks!);
        if (decoded is Map && decoded.containsKey('note')) {
          final note = decoded['note'] as String?;
          return (note != null && note.isNotEmpty) ? note : null;
        }
        return null;
      } catch (_) {}
    }
    return remarks;
  }

  String get examName => exam.name;
  String get examCategory => exam.category;
  String get academicYearName => academicYear.name;
  String get className => schoolClass.name;
  String get classDisplayName => schoolClass.displayName;
  String get subjectName => subject.name;
  String get subjectCode => subject.code;
  SubjectType get subjectType => subject.subjectType;
}

/// Composite model for an individual student subject exam result with all related entities joined
class ExamResultWithDetails {
  final ExamResult result;
  final Exam exam;
  final AcademicYear academicYear;
  final SchoolClass schoolClass;
  final Section? section;
  final Student student;
  final Subject subject;
  final ExamSchedule? schedule;

  const ExamResultWithDetails({
    required this.result,
    required this.exam,
    required this.academicYear,
    required this.schoolClass,
    this.section,
    required this.student,
    required this.subject,
    this.schedule,
  });

  int get id => result.id;
  int get examId => result.examId;
  int get studentId => result.studentId;
  int get subjectId => result.subjectId;
  int get classId => result.classId;
  int? get sectionId => result.sectionId;
  int get academicYearId => result.academicYearId;

  double get theoryMarksObtained => result.theoryMarksObtained;
  double get theoryFullMarks => result.theoryFullMarks;
  double get theoryPassMarks => result.theoryPassMarks;
  double? get practicalMarksObtained => result.practicalMarksObtained;
  double? get practicalFullMarks => result.practicalFullMarks;
  double? get practicalPassMarks => result.practicalPassMarks;
  double get totalMarksObtained => result.totalMarksObtained;
  double get totalFullMarks => result.totalFullMarks;
  double get totalPassMarks => result.totalPassMarks;
  double get percentage => result.percentage;
  double get gradePoint => result.gradePoint;
  String get letterGrade => result.letterGrade;
  bool get isPassed => result.isPassed;
  bool get isAbsent => result.isAbsent;
  String? get remarks => result.remarks;

  String get studentName => student.name;
  String get studentRollNumber => student.rollNumber?.toString() ?? '';
  String get studentCode => student.studentId;
  String? get studentPhotoPath => student.photoPath;
  String get subjectName => subject.name;
  String get subjectCode => subject.code;
  SubjectType get subjectType => subject.subjectType;
  String get className => schoolClass.name;
  String get classDisplayName => schoolClass.displayName;
  String? get sectionName => section?.name;
  String get examName => exam.name;
  String get examCategory => exam.category;
}

/// Composite model for a student's aggregate exam result summary
class StudentExamSummaryWithDetails {
  final ExamResultSummary summary;
  final Exam exam;
  final AcademicYear academicYear;
  final SchoolClass schoolClass;
  final Section? section;
  final Student student;

  const StudentExamSummaryWithDetails({
    required this.summary,
    required this.exam,
    required this.academicYear,
    required this.schoolClass,
    this.section,
    required this.student,
  });

  int get id => summary.id;
  int get examId => summary.examId;
  int get studentId => summary.studentId;
  int get classId => summary.classId;
  int? get sectionId => summary.sectionId;
  double get totalMarksObtained => summary.totalMarksObtained;
  double get totalFullMarks => summary.totalFullMarks;
  double get overallPercentage => summary.overallPercentage;
  double get overallGpa => summary.overallGpa;
  String get overallGrade => summary.overallGrade;
  int get totalSubjects => summary.totalSubjects;
  int get passedSubjects => summary.passedSubjects;
  int get failedSubjects => summary.failedSubjects;
  bool get isPassed => summary.isPassed;
  int? get rankInClass => summary.rankInClass;
  int? get rankInSection => summary.rankInSection;
  String? get remarks => summary.remarks;

  String get studentName => student.name;
  String get studentRollNumber => student.rollNumber?.toString() ?? '';
  String get studentCode => student.studentId;
  String? get studentPhotoPath => student.photoPath;
  String get className => schoolClass.name;
  String? get sectionName => section?.name;
  String get examName => exam.name;
}
