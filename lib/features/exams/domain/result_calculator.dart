// lib/features/exams/domain/result_calculator.dart
import 'exam_models.dart';
import 'grading_engine.dart';

class SubjectResult {
  final String subjectId;
  final String subjectName;
  final double fullMarks;
  final double passMarks;
  final double? theoryMarks;
  final double? practicalMarks;
  final double? internalMarks;
  final double? totalMarks;
  final double? percentage;
  final String grade;
  final double? gradePoint;
  final MarkStatus status;
  final bool isPassed;

  const SubjectResult({
    required this.subjectId,
    required this.subjectName,
    required this.fullMarks,
    required this.passMarks,
    this.theoryMarks,
    this.practicalMarks,
    this.internalMarks,
    this.totalMarks,
    this.percentage,
    required this.grade,
    this.gradePoint,
    required this.status,
    required this.isPassed,
  });
}

class StudentExamResult {
  final String studentId;
  final String studentName;
  final String? studentCode;
  final int? rollNumber;
  final String classId;
  final String sectionId;
  final double totalMarksObtained;
  final double totalFullMarks;
  final double percentage;
  final double? gpa;
  final String overallGrade;
  final bool isPassed;
  final int? rank;
  final List<SubjectResult> subjectResults;

  const StudentExamResult({
    required this.studentId,
    required this.studentName,
    this.studentCode,
    this.rollNumber,
    required this.classId,
    required this.sectionId,
    required this.totalMarksObtained,
    required this.totalFullMarks,
    required this.percentage,
    this.gpa,
    required this.overallGrade,
    required this.isPassed,
    this.rank,
    required this.subjectResults,
  });

  StudentExamResult copyWith({int? rank}) {
    return StudentExamResult(
      studentId: studentId,
      studentName: studentName,
      studentCode: studentCode,
      rollNumber: rollNumber,
      classId: classId,
      sectionId: sectionId,
      totalMarksObtained: totalMarksObtained,
      totalFullMarks: totalFullMarks,
      percentage: percentage,
      gpa: gpa,
      overallGrade: overallGrade,
      isPassed: isPassed,
      rank: rank ?? this.rank,
      subjectResults: subjectResults,
    );
  }
}

class ResultCalculator {
  /// Deterministic rounding to 2 decimal places.
  static double round2(double val) {
    return (val * 100.0).roundToDouble() / 100.0;
  }

  /// Calculates the result for an individual subject mark.
  static SubjectResult calculateSubjectResult({
    required String subjectId,
    required String subjectName,
    required double fullMarks,
    required double passMarks,
    double? theoryMarks,
    double? practicalMarks,
    double? internalMarks,
    MarkStatus status = MarkStatus.present,
    List<GradeRuleModel>? customRules,
  }) {
    if (status == MarkStatus.absent || status == MarkStatus.notAppeared) {
      return SubjectResult(
        subjectId: subjectId,
        subjectName: subjectName,
        fullMarks: fullMarks,
        passMarks: passMarks,
        theoryMarks: null,
        practicalMarks: null,
        internalMarks: null,
        totalMarks: null,
        percentage: null,
        grade: 'F',
        gradePoint: 0.0,
        status: status,
        isPassed: false,
      );
    }

    if (status == MarkStatus.exempt) {
      return SubjectResult(
        subjectId: subjectId,
        subjectName: subjectName,
        fullMarks: fullMarks,
        passMarks: passMarks,
        theoryMarks: null,
        practicalMarks: null,
        internalMarks: null,
        totalMarks: null,
        percentage: null,
        grade: 'EX',
        gradePoint: null,
        status: status,
        isPassed: true,
      );
    }

    if (status == MarkStatus.withheld) {
      return SubjectResult(
        subjectId: subjectId,
        subjectName: subjectName,
        fullMarks: fullMarks,
        passMarks: passMarks,
        theoryMarks: theoryMarks,
        practicalMarks: practicalMarks,
        internalMarks: internalMarks,
        totalMarks: null,
        percentage: null,
        grade: 'WH',
        gradePoint: null,
        status: status,
        isPassed: false,
      );
    }

    final total =
        (theoryMarks ?? 0.0) + (practicalMarks ?? 0.0) + (internalMarks ?? 0.0);
    final pct = fullMarks > 0 ? round2((total / fullMarks) * 100.0) : 0.0;
    final gradeInfo = GradingEngine.getGradeForPercentage(
      percentage: pct,
      customRules: customRules,
    );
    final isPassed = total >= passMarks && gradeInfo.isPassing;

    return SubjectResult(
      subjectId: subjectId,
      subjectName: subjectName,
      fullMarks: fullMarks,
      passMarks: passMarks,
      theoryMarks: theoryMarks,
      practicalMarks: practicalMarks,
      internalMarks: internalMarks,
      totalMarks: total,
      percentage: pct,
      grade: gradeInfo.grade,
      gradePoint: gradeInfo.gradePoint,
      status: status,
      isPassed: isPassed,
    );
  }

  /// Calculates the aggregated student exam result across all subjects.
  static StudentExamResult calculateStudentResult({
    required String studentId,
    required String studentName,
    String? studentCode,
    int? rollNumber,
    required String classId,
    required String sectionId,
    required List<SubjectResult> subjectResults,
    bool enableGpa = true,
    bool requireAllSubjectsPass = true,
    List<GradeRuleModel>? customRules,
    Map<String, double>? subjectCreditHours, // subjectId -> creditHours
  }) {
    double totalObtained = 0.0;
    double totalFull = 0.0;
    double gpaWeightedSum = 0.0;
    double totalCredits = 0.0;
    bool allPassed = true;

    for (final s in subjectResults) {
      if (s.status == MarkStatus.exempt) continue;

      if (s.status == MarkStatus.absent ||
          s.status == MarkStatus.notAppeared ||
          s.status == MarkStatus.withheld ||
          !s.isPassed) {
        allPassed = false;
      }

      if (s.totalMarks != null) {
        totalObtained += s.totalMarks!;
      }
      totalFull += s.fullMarks;

      final credit = subjectCreditHours?[s.subjectId] ?? 1.0;
      if (s.gradePoint != null) {
        gpaWeightedSum += (s.gradePoint! * credit);
        totalCredits += credit;
      }
    }

    totalObtained = round2(totalObtained);
    totalFull = round2(totalFull);
    final overallPct =
        totalFull > 0 ? round2((totalObtained / totalFull) * 100.0) : 0.0;
    final overallGradeInfo = GradingEngine.getGradeForPercentage(
      percentage: overallPct,
      customRules: customRules,
    );

    final double? gpa =
        (enableGpa && totalCredits > 0)
            ? round2(gpaWeightedSum / totalCredits)
            : null;

    final isOverallPassed =
        requireAllSubjectsPass
            ? allPassed && overallGradeInfo.isPassing
            : overallGradeInfo.isPassing;

    return StudentExamResult(
      studentId: studentId,
      studentName: studentName,
      studentCode: studentCode,
      rollNumber: rollNumber,
      classId: classId,
      sectionId: sectionId,
      totalMarksObtained: totalObtained,
      totalFullMarks: totalFull,
      percentage: overallPct,
      gpa: gpa,
      overallGrade: overallGradeInfo.grade,
      isPassed: isOverallPassed,
      subjectResults: subjectResults,
    );
  }

  /// Calculates weighted aggregate score across multiple exam terms
  /// e.g. Term 1 (20%) + Midterm (20%) + Final (60%).
  static double calculateWeightedScore({
    required List<double> termPercentages,
    required List<double> termWeights,
  }) {
    if (termPercentages.length != termWeights.length ||
        termPercentages.isEmpty) {
      return 0.0;
    }
    double weightedSum = 0.0;
    double totalWeight = 0.0;
    for (int i = 0; i < termPercentages.length; i++) {
      weightedSum += termPercentages[i] * termWeights[i];
      totalWeight += termWeights[i];
    }
    if (totalWeight <= 0) return 0.0;
    return round2(weightedSum / totalWeight);
  }
}
