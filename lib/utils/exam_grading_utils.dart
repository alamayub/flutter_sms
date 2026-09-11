import 'package:flutter/material.dart';

/// Grade representation with Letter, Grade Point (GPA), Description, and Pass/Fail status
class GradeInfo {
  final String letterGrade;
  final double gradePoint;
  final String description;
  final Color color;

  const GradeInfo({
    required this.letterGrade,
    required this.gradePoint,
    required this.description,
    required this.color,
  });
}

/// Detailed evaluation result for a subject or overall assessment
class SubjectGradeResult {
  final double theoryMarksObtained;
  final double theoryFullMarks;
  final double theoryPassMarks;
  final double? practicalMarksObtained;
  final double? practicalFullMarks;
  final double? practicalPassMarks;
  final double totalMarksObtained;
  final double totalFullMarks;
  final double totalPassMarks;
  final double percentage;
  final double gradePoint;
  final String letterGrade;
  final String description;
  final bool isPassed;
  final bool isAbsent;
  final Color color;

  const SubjectGradeResult({
    required this.theoryMarksObtained,
    required this.theoryFullMarks,
    required this.theoryPassMarks,
    this.practicalMarksObtained,
    this.practicalFullMarks,
    this.practicalPassMarks,
    required this.totalMarksObtained,
    required this.totalFullMarks,
    required this.totalPassMarks,
    required this.percentage,
    required this.gradePoint,
    required this.letterGrade,
    required this.description,
    required this.isPassed,
    required this.isAbsent,
    required this.color,
  });
}

/// Overall summary calculation for a student across all subjects
class OverallGradeResult {
  final double totalMarksObtained;
  final double totalFullMarks;
  final double percentage;
  final double gpa;
  final String letterGrade;
  final String description;
  final bool isPassed;
  final int totalSubjects;
  final int passedSubjects;
  final int failedSubjects;
  final Color color;

  const OverallGradeResult({
    required this.totalMarksObtained,
    required this.totalFullMarks,
    required this.percentage,
    required this.gpa,
    required this.letterGrade,
    required this.description,
    required this.isPassed,
    required this.totalSubjects,
    required this.passedSubjects,
    required this.failedSubjects,
    required this.color,
  });
}

/// Central grading calculator and formatter
class ExamGradingUtils {
  /// Standard Grading Scale Definition:
  /// 90% - 100%: O  (Outstanding)   - 4.0 GPA
  /// 80% - 89.9%: A+ (Excellent)     - 3.6 GPA
  /// 70% - 79.9%: A  (Very Good)     - 3.2 GPA
  /// 60% - 69.9%: B+ (Good)          - 2.8 GPA
  /// 50% - 59.9%: B  (Above Average) - 2.4 GPA
  /// 40% - 49.9%: C+ (Average)       - 2.0 GPA
  /// 35% - 39.9%: C  (Below Average) - 1.6 GPA
  /// 30% - 34.9%: D  (Pass)          - 1.2 GPA
  /// Below 30%:   F  (Fail / NG)     - 0.0 GPA
  static GradeInfo getGradeFromPercentage(double percentage) {
    if (percentage >= 90.0) {
      return const GradeInfo(
        letterGrade: 'O',
        gradePoint: 4.0,
        description: 'Outstanding',
        color: Color(0xFF1B5E20), // Dark Green
      );
    } else if (percentage >= 80.0) {
      return const GradeInfo(
        letterGrade: 'A+',
        gradePoint: 3.6,
        description: 'Excellent',
        color: Color(0xFF2E7D32), // Green
      );
    } else if (percentage >= 70.0) {
      return const GradeInfo(
        letterGrade: 'A',
        gradePoint: 3.2,
        description: 'Very Good',
        color: Color(0xFF388E3C), // Light Green
      );
    } else if (percentage >= 60.0) {
      return const GradeInfo(
        letterGrade: 'B+',
        gradePoint: 2.8,
        description: 'Good',
        color: Color(0xFF0288D1), // Cyan/Blue
      );
    } else if (percentage >= 50.0) {
      return const GradeInfo(
        letterGrade: 'B',
        gradePoint: 2.4,
        description: 'Above Average',
        color: Color(0xFF0097A7), // Teal
      );
    } else if (percentage >= 40.0) {
      return const GradeInfo(
        letterGrade: 'C+',
        gradePoint: 2.0,
        description: 'Average',
        color: Color(0xFFF57C00), // Orange
      );
    } else if (percentage >= 35.0) {
      return const GradeInfo(
        letterGrade: 'C',
        gradePoint: 1.6,
        description: 'Below Average',
        color: Color(0xFFE65100), // Dark Orange
      );
    } else if (percentage >= 30.0) {
      return const GradeInfo(
        letterGrade: 'D',
        gradePoint: 1.2,
        description: 'Pass',
        color: Color(0xFF795548), // Brown
      );
    } else {
      return const GradeInfo(
        letterGrade: 'F',
        gradePoint: 0.0,
        description: 'Fail / Non-Graded',
        color: Color(0xFFC62828), // Red
      );
    }
  }

  /// Calculates subject grade, GPA, and pass status.
  /// Subject is passed ONLY if both theory >= theoryPassMarks AND practical >= practicalPassMarks (if applicable).
  static SubjectGradeResult calculateSubjectResult({
    required double theoryMarksObtained,
    required double theoryFullMarks,
    required double theoryPassMarks,
    double? practicalMarksObtained,
    double? practicalFullMarks,
    double? practicalPassMarks,
    bool isAbsent = false,
  }) {
    if (isAbsent) {
      return SubjectGradeResult(
        theoryMarksObtained: 0,
        theoryFullMarks: theoryFullMarks,
        theoryPassMarks: theoryPassMarks,
        practicalMarksObtained: practicalMarksObtained != null ? 0 : null,
        practicalFullMarks: practicalFullMarks,
        practicalPassMarks: practicalPassMarks,
        totalMarksObtained: 0,
        totalFullMarks: theoryFullMarks + (practicalFullMarks ?? 0),
        totalPassMarks: theoryPassMarks + (practicalPassMarks ?? 0),
        percentage: 0.0,
        gradePoint: 0.0,
        letterGrade: 'AB',
        description: 'Absent',
        isPassed: false,
        isAbsent: true,
        color: const Color(0xFF757575), // Grey
      );
    }

    // Theory evaluation
    final hasTheory = theoryFullMarks > 0;
    final theoryPassed = !hasTheory || (theoryMarksObtained >= theoryPassMarks);

    // Practical evaluation
    final hasPractical = practicalFullMarks != null && practicalFullMarks > 0;
    final practicalPassed =
        !hasPractical ||
        ((practicalMarksObtained ?? 0) >= (practicalPassMarks ?? 0));

    final isPassed = theoryPassed && practicalPassed;

    final totalObtained =
        theoryMarksObtained +
        (hasPractical ? (practicalMarksObtained ?? 0) : 0);
    final totalFull = theoryFullMarks + (hasPractical ? practicalFullMarks : 0);
    final totalPass =
        theoryPassMarks + (hasPractical ? (practicalPassMarks ?? 0) : 0);

    final rawPercentage =
        totalFull > 0 ? (totalObtained / totalFull) * 100 : 0.0;
    final percentage = double.parse(rawPercentage.toStringAsFixed(2));

    GradeInfo gradeInfo;
    if (!isPassed) {
      // Failed in either theory or practical component
      gradeInfo = const GradeInfo(
        letterGrade: 'F',
        gradePoint: 0.0,
        description: 'Fail / Non-Graded',
        color: Color(0xFFC62828),
      );
    } else {
      gradeInfo = getGradeFromPercentage(percentage);
    }

    return SubjectGradeResult(
      theoryMarksObtained: theoryMarksObtained,
      theoryFullMarks: theoryFullMarks,
      theoryPassMarks: theoryPassMarks,
      practicalMarksObtained: practicalMarksObtained,
      practicalFullMarks: practicalFullMarks,
      practicalPassMarks: practicalPassMarks,
      totalMarksObtained: totalObtained,
      totalFullMarks: totalFull,
      totalPassMarks: totalPass,
      percentage: percentage,
      gradePoint: gradeInfo.gradePoint,
      letterGrade: gradeInfo.letterGrade,
      description: gradeInfo.description,
      isPassed: isPassed,
      isAbsent: false,
      color: gradeInfo.color,
    );
  }

  /// Calculates overall aggregate result across all evaluated subjects for a student
  static OverallGradeResult calculateOverallResult(
    List<SubjectGradeResult> subjects,
  ) {
    if (subjects.isEmpty) {
      return const OverallGradeResult(
        totalMarksObtained: 0,
        totalFullMarks: 0,
        percentage: 0.0,
        gpa: 0.0,
        letterGrade: 'N/A',
        description: 'No Results',
        isPassed: false,
        totalSubjects: 0,
        passedSubjects: 0,
        failedSubjects: 0,
        color: Colors.grey,
      );
    }

    double totalObtained = 0.0;
    double totalFull = 0.0;
    double sumGpa = 0.0;
    int passedCount = 0;
    int failedCount = 0;

    for (final s in subjects) {
      totalObtained += s.totalMarksObtained;
      totalFull += s.totalFullMarks;
      sumGpa += s.gradePoint;
      if (s.isPassed) {
        passedCount++;
      } else {
        failedCount++;
      }
    }

    final rawPercentage =
        totalFull > 0 ? (totalObtained / totalFull) * 100 : 0.0;
    final percentage = double.parse(rawPercentage.toStringAsFixed(2));

    final rawGpa = subjects.isNotEmpty ? sumGpa / subjects.length : 0.0;
    final gpa = double.parse(rawGpa.toStringAsFixed(2));

    final isPassed = failedCount == 0;

    GradeInfo gradeInfo;
    if (!isPassed) {
      gradeInfo = const GradeInfo(
        letterGrade: 'F',
        gradePoint: 0.0,
        description: 'Failed',
        color: Color(0xFFC62828),
      );
    } else {
      gradeInfo = getGradeFromPercentage(percentage);
    }

    return OverallGradeResult(
      totalMarksObtained: totalObtained,
      totalFullMarks: totalFull,
      percentage: percentage,
      gpa: gpa,
      letterGrade: gradeInfo.letterGrade,
      description: gradeInfo.description,
      isPassed: isPassed,
      totalSubjects: subjects.length,
      passedSubjects: passedCount,
      failedSubjects: failedCount,
      color: gradeInfo.color,
    );
  }

  /// Format GPA to 2 decimal places string e.g. "3.60"
  static String formatGpa(double gpa) {
    return gpa.toStringAsFixed(2);
  }

  /// Format percentage string e.g. "85.50%"
  static String formatPercentage(double pct) {
    return '${pct.toStringAsFixed(2)}%';
  }
}
