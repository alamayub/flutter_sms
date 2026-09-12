import 'package:drift/drift.dart';
import '../config/enums.dart';
import '../data/app_database.dart';
import '../utils/exam_grading_utils.dart';

/// Input entry for saving a student's marks in a subject
class SubjectMarksEntryInput {
  final int studentId;
  final double theoryMarks;
  final double? practicalMarks;
  final bool isAbsent;
  final String? remarks;

  const SubjectMarksEntryInput({
    required this.studentId,
    required this.theoryMarks,
    this.practicalMarks,
    this.isAbsent = false,
    this.remarks,
  });
}

/// Input entry for saving all subject marks for a single student
class StudentSubjectMarksEntryInput {
  final int subjectId;
  final int? examScheduleId;
  final double theoryMarks;
  final double theoryFullMarks;
  final double theoryPassMarks;
  final double? practicalMarks;
  final double? practicalFullMarks;
  final double? practicalPassMarks;
  final bool isAbsent;
  final String? remarks;

  const StudentSubjectMarksEntryInput({
    required this.subjectId,
    this.examScheduleId,
    required this.theoryMarks,
    required this.theoryFullMarks,
    required this.theoryPassMarks,
    this.practicalMarks,
    this.practicalFullMarks,
    this.practicalPassMarks,
    this.isAbsent = false,
    this.remarks,
  });
}

/// Marks configuration for a subject in an exam
class SubjectExamMarksConfig {
  final int subjectId;
  final String subjectName;
  final String subjectCode;
  final SubjectType subjectType;
  final int? examScheduleId;
  final double theoryFullMarks;
  final double theoryPassMarks;
  final double? practicalFullMarks;
  final double? practicalPassMarks;
  final double totalFullMarks;
  final double totalPassMarks;

  const SubjectExamMarksConfig({
    required this.subjectId,
    required this.subjectName,
    required this.subjectCode,
    required this.subjectType,
    this.examScheduleId,
    required this.theoryFullMarks,
    required this.theoryPassMarks,
    this.practicalFullMarks,
    this.practicalPassMarks,
    required this.totalFullMarks,
    required this.totalPassMarks,
  });
}

/// Service managing Exam Results, Marks Entry, Grading Calculations, and Tabulation Ledgers
class ExamResultService {
  final AppDatabase _db;

  ExamResultService(this._db);

  /// Watch reactive stream of exam results
  Stream<List<ExamResultWithDetails>> watchExamResults({
    int? examId,
    int? classId,
    int? sectionId,
    int? subjectId,
    int? studentId,
    int? academicYearId,
  }) {
    return _db.watchExamResultsWithDetails(
      examId: examId,
      classId: classId,
      sectionId: sectionId,
      subjectId: subjectId,
      studentId: studentId,
      academicYearId: academicYearId,
    );
  }

  /// Get exam results with details
  Future<List<ExamResultWithDetails>> getExamResults({
    int? examId,
    int? classId,
    int? sectionId,
    int? subjectId,
    int? studentId,
    int? academicYearId,
  }) {
    return _db.getExamResultsWithDetails(
      examId: examId,
      classId: classId,
      sectionId: sectionId,
      subjectId: subjectId,
      studentId: studentId,
      academicYearId: academicYearId,
    );
  }

  /// Watch student summaries with details
  Stream<List<StudentExamSummaryWithDetails>> watchExamSummaries({
    required int examId,
    int? classId,
    int? sectionId,
  }) {
    return _db.watchExamResultSummariesWithDetails(
      examId: examId,
      classId: classId,
      sectionId: sectionId,
    );
  }

  /// Get student summaries with details
  Future<List<StudentExamSummaryWithDetails>> getExamSummaries({
    required int examId,
    int? classId,
    int? sectionId,
  }) {
    return _db.getExamResultSummariesWithDetails(
      examId: examId,
      classId: classId,
      sectionId: sectionId,
    );
  }

  /// Get all active students enrolled in a class/section for the given academic year
  Future<List<Student>> getStudentsForExam({
    required int classId,
    int? sectionId,
    required int academicYearId,
  }) async {
    final query = _db.select(_db.students).join([
      innerJoin(
        _db.studentAcademicHistories,
        _db.studentAcademicHistories.studentId.equalsExp(_db.students.id),
      ),
    ]);

    query.where(
      _db.studentAcademicHistories.academicYearId.equals(academicYearId) &
          _db.studentAcademicHistories.classId.equals(classId) &
          _db.studentAcademicHistories.status.equalsValue(
            AcademicStatus.active,
          ),
    );

    if (sectionId != null) {
      query.where(_db.studentAcademicHistories.sectionId.equals(sectionId));
    }

    query.orderBy([
      OrderingTerm(expression: _db.students.rollNumber, mode: OrderingMode.asc),
      OrderingTerm(expression: _db.students.name, mode: OrderingMode.asc),
    ]);

    final rows = await query.get();
    return rows.map((r) => r.readTable(_db.students)).toList();
  }

  /// Get subject marks configuration (full/pass marks for theory and practical).
  /// Inspects ExamSchedule first, falling back to Subject master table.
  Future<SubjectExamMarksConfig?> getSubjectMarksConfig({
    required int examId,
    required int classId,
    required int subjectId,
  }) async {
    final schedules = await _db.getAllExamSchedulesWithDetails(
      examId: examId,
      classId: classId,
      subjectId: subjectId,
    );

    if (schedules.isNotEmpty) {
      final s = schedules.first;
      final subject = s.subject;
      final hasPractical = subject.subjectType != SubjectType.theory;

      final theoryFull =
          (s.theoryMarks ??
                  (hasPractical ? (subject.theoryMarks ?? 75) : s.fullMarks))
              .toDouble();
      final theoryPass =
          (s.savedTheoryPassMarks?.toDouble() ??
              (hasPractical
                      ? (subject.theoryMarks != null
                          ? (subject.theoryMarks! * 0.4).round()
                          : 30)
                      : s.passMarks)
                  .toDouble());

      final practicalFull =
          hasPractical
              ? (s.practicalMarks ?? subject.practicalMarks ?? 25).toDouble()
              : null;
      final practicalPass =
          hasPractical
              ? (s.savedPracticalPassMarks?.toDouble() ??
                  (practicalFull! * 0.4).toDouble())
              : null;

      return SubjectExamMarksConfig(
        subjectId: subject.id,
        subjectName: subject.name,
        subjectCode: subject.code,
        subjectType: subject.subjectType,
        examScheduleId: s.id,
        theoryFullMarks: theoryFull,
        theoryPassMarks: theoryPass,
        practicalFullMarks: practicalFull,
        practicalPassMarks: practicalPass,
        totalFullMarks: s.fullMarks.toDouble(),
        totalPassMarks: s.passMarks.toDouble(),
      );
    }

    // Fallback: master subjects table
    final subjects = await _db.getAllSubjects();
    final subject = subjects.firstWhere(
      (s) => s.id == subjectId,
      orElse: () => subjects.first,
    );

    final hasPractical = subject.subjectType != SubjectType.theory;
    final theoryFull =
        (hasPractical ? (subject.theoryMarks ?? 75) : subject.fullMarks)
            .toDouble();
    final theoryPass =
        (hasPractical
                ? (subject.theoryMarks != null
                    ? (subject.theoryMarks! * 0.4).round()
                    : 30)
                : subject.passMarks)
            .toDouble();

    final practicalFull =
        hasPractical ? (subject.practicalMarks ?? 25).toDouble() : null;
    final practicalPass =
        hasPractical ? (practicalFull! * 0.4).toDouble() : null;

    return SubjectExamMarksConfig(
      subjectId: subject.id,
      subjectName: subject.name,
      subjectCode: subject.code,
      subjectType: subject.subjectType,
      theoryFullMarks: theoryFull,
      theoryPassMarks: theoryPass,
      practicalFullMarks: practicalFull,
      practicalPassMarks: practicalPass,
      totalFullMarks: subject.fullMarks.toDouble(),
      totalPassMarks: subject.passMarks.toDouble(),
    );
  }

  /// Batch saves subject marks for all students in a class/section, then triggers auto-summary recalculation
  Future<void> saveSubjectMarksBatch({
    required int examId,
    required int academicYearId,
    required int classId,
    int? sectionId,
    required int subjectId,
    int? examScheduleId,
    required double theoryFullMarks,
    required double theoryPassMarks,
    double? practicalFullMarks,
    double? practicalPassMarks,
    required List<SubjectMarksEntryInput> entries,
  }) async {
    final now = DateTime.now();
    final companions = <ExamResultsCompanion>[];

    for (final entry in entries) {
      final calc = ExamGradingUtils.calculateSubjectResult(
        theoryMarksObtained: entry.theoryMarks,
        theoryFullMarks: theoryFullMarks,
        theoryPassMarks: theoryPassMarks,
        practicalMarksObtained: entry.practicalMarks,
        practicalFullMarks: practicalFullMarks,
        practicalPassMarks: practicalPassMarks,
        isAbsent: entry.isAbsent,
      );

      companions.add(
        ExamResultsCompanion(
          examId: Value(examId),
          academicYearId: Value(academicYearId),
          classId: Value(classId),
          sectionId: Value(sectionId),
          studentId: Value(entry.studentId),
          subjectId: Value(subjectId),
          examScheduleId: Value(examScheduleId),
          theoryMarksObtained: Value(calc.theoryMarksObtained),
          theoryFullMarks: Value(calc.theoryFullMarks),
          theoryPassMarks: Value(calc.theoryPassMarks),
          practicalMarksObtained: Value(calc.practicalMarksObtained),
          practicalFullMarks: Value(calc.practicalFullMarks),
          practicalPassMarks: Value(calc.practicalPassMarks),
          totalMarksObtained: Value(calc.totalMarksObtained),
          totalFullMarks: Value(calc.totalFullMarks),
          totalPassMarks: Value(calc.totalPassMarks),
          percentage: Value(calc.percentage),
          gradePoint: Value(calc.gradePoint),
          letterGrade: Value(calc.letterGrade),
          isPassed: Value(calc.isPassed),
          isAbsent: Value(calc.isAbsent),
          remarks: Value(entry.remarks),
          updatedAt: Value(now),
        ),
      );
    }

    await _db.batchUpsertExamResults(companions);

    // Auto recalculate overall summaries for affected students
    await recalculateExamSummariesForClass(
      examId: examId,
      academicYearId: academicYearId,
      classId: classId,
      sectionId: sectionId,
    );
  }

  /// Saves all subject marks for a single student, then updates that student's summary
  Future<void> saveStudentMarksheetBatch({
    required int examId,
    required int academicYearId,
    required int classId,
    int? sectionId,
    required int studentId,
    required List<StudentSubjectMarksEntryInput> entries,
  }) async {
    final now = DateTime.now();
    final companions = <ExamResultsCompanion>[];

    for (final entry in entries) {
      final calc = ExamGradingUtils.calculateSubjectResult(
        theoryMarksObtained: entry.theoryMarks,
        theoryFullMarks: entry.theoryFullMarks,
        theoryPassMarks: entry.theoryPassMarks,
        practicalMarksObtained: entry.practicalMarks,
        practicalFullMarks: entry.practicalFullMarks,
        practicalPassMarks: entry.practicalPassMarks,
        isAbsent: entry.isAbsent,
      );

      companions.add(
        ExamResultsCompanion(
          examId: Value(examId),
          academicYearId: Value(academicYearId),
          classId: Value(classId),
          sectionId: Value(sectionId),
          studentId: Value(studentId),
          subjectId: Value(entry.subjectId),
          examScheduleId: Value(entry.examScheduleId),
          theoryMarksObtained: Value(calc.theoryMarksObtained),
          theoryFullMarks: Value(calc.theoryFullMarks),
          theoryPassMarks: Value(calc.theoryPassMarks),
          practicalMarksObtained: Value(calc.practicalMarksObtained),
          practicalFullMarks: Value(calc.practicalFullMarks),
          practicalPassMarks: Value(calc.practicalPassMarks),
          totalMarksObtained: Value(calc.totalMarksObtained),
          totalFullMarks: Value(calc.totalFullMarks),
          totalPassMarks: Value(calc.totalPassMarks),
          percentage: Value(calc.percentage),
          gradePoint: Value(calc.gradePoint),
          letterGrade: Value(calc.letterGrade),
          isPassed: Value(calc.isPassed),
          isAbsent: Value(calc.isAbsent),
          remarks: Value(entry.remarks),
          updatedAt: Value(now),
        ),
      );
    }

    await _db.batchUpsertExamResults(companions);

    // Auto recalculate overall summaries
    await recalculateExamSummariesForClass(
      examId: examId,
      academicYearId: academicYearId,
      classId: classId,
      sectionId: sectionId,
    );
  }

  /// Recalculates total marks, overall percentage, overall GPA, letter grade, and rank for all students in class/section
  Future<void> recalculateExamSummariesForClass({
    required int examId,
    required int academicYearId,
    required int classId,
    int? sectionId,
  }) async {
    final results = await _db.getExamResultsWithDetails(
      examId: examId,
      classId: classId,
      sectionId: sectionId,
      academicYearId: academicYearId,
    );

    if (results.isEmpty) return;

    // Group results by studentId
    final studentResultsMap = <int, List<ExamResultWithDetails>>{};
    for (final r in results) {
      studentResultsMap.putIfAbsent(r.studentId, () => []).add(r);
    }

    final summaryCompanions = <ExamResultSummariesCompanion>[];

    studentResultsMap.forEach((studentId, studentResults) {
      final subjectGradeResults =
          studentResults.map((r) {
            return SubjectGradeResult(
              theoryMarksObtained: r.theoryMarksObtained,
              theoryFullMarks: r.theoryFullMarks,
              theoryPassMarks: r.theoryPassMarks,
              practicalMarksObtained: r.practicalMarksObtained,
              practicalFullMarks: r.practicalFullMarks,
              practicalPassMarks: r.practicalPassMarks,
              totalMarksObtained: r.totalMarksObtained,
              totalFullMarks: r.totalFullMarks,
              totalPassMarks: r.totalPassMarks,
              percentage: r.percentage,
              gradePoint: r.gradePoint,
              letterGrade: r.letterGrade,
              description: '',
              isPassed: r.isPassed,
              isAbsent: r.isAbsent,
              color:
                  ExamGradingUtils.getGradeFromPercentage(r.percentage).color,
            );
          }).toList();

      final overall = ExamGradingUtils.calculateOverallResult(
        subjectGradeResults,
      );
      final studentSectionId = studentResults.first.sectionId;

      summaryCompanions.add(
        ExamResultSummariesCompanion(
          examId: Value(examId),
          academicYearId: Value(academicYearId),
          classId: Value(classId),
          sectionId: Value(studentSectionId),
          studentId: Value(studentId),
          totalMarksObtained: Value(overall.totalMarksObtained),
          totalFullMarks: Value(overall.totalFullMarks),
          overallPercentage: Value(overall.percentage),
          overallGpa: Value(overall.gpa),
          overallGrade: Value(overall.letterGrade),
          totalSubjects: Value(overall.totalSubjects),
          passedSubjects: Value(overall.passedSubjects),
          failedSubjects: Value(overall.failedSubjects),
          isPassed: Value(overall.isPassed),
          updatedAt: Value(DateTime.now()),
        ),
      );
    });

    // Assign class rankings based on overall GPA, then Percentage, then Total Marks
    summaryCompanions.sort((a, b) {
      final gpaCompare = b.overallGpa.value.compareTo(a.overallGpa.value);
      if (gpaCompare != 0) return gpaCompare;
      final pctCompare = b.overallPercentage.value.compareTo(
        a.overallPercentage.value,
      );
      if (pctCompare != 0) return pctCompare;
      return b.totalMarksObtained.value.compareTo(a.totalMarksObtained.value);
    });

    final rankedCompanions = <ExamResultSummariesCompanion>[];
    for (int i = 0; i < summaryCompanions.length; i++) {
      final c = summaryCompanions[i];
      // Only students who passed all subjects qualify for class rank
      final rank = c.isPassed.value ? (i + 1) : null;
      rankedCompanions.add(c.copyWith(rankInClass: Value(rank)));
    }

    await _db.batchUpsertExamResultSummaries(rankedCompanions);
  }

  /// Delete exam results for a given class/section
  Future<int> deleteExamResultsForClass({
    required int examId,
    required int classId,
    int? sectionId,
    int? subjectId,
  }) {
    return _db.deleteExamResultsForExamAndClass(
      examId,
      classId,
      sectionId: sectionId,
      subjectId: subjectId,
    );
  }
}
