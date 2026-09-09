// lib/features/exams/domain/grading_engine.dart
import 'exam_models.dart';

class GradeCalculationResult {
  final String grade;
  final double? gradePoint;
  final String? description;
  final bool isPassing;

  const GradeCalculationResult({
    required this.grade,
    this.gradePoint,
    this.description,
    required this.isPassing,
  });
}

class GradingEngine {
  static const List<GradeRuleModel> defaultRules = [
    GradeRuleModel(
      grade: 'A+',
      minPercentage: 90.0,
      maxPercentage: 100.0,
      gradePoint: 4.0,
      description: 'Outstanding',
      isPassing: true,
    ),
    GradeRuleModel(
      grade: 'A',
      minPercentage: 80.0,
      maxPercentage: 89.999,
      gradePoint: 3.6,
      description: 'Excellent',
      isPassing: true,
    ),
    GradeRuleModel(
      grade: 'B+',
      minPercentage: 70.0,
      maxPercentage: 79.999,
      gradePoint: 3.2,
      description: 'Very Good',
      isPassing: true,
    ),
    GradeRuleModel(
      grade: 'B',
      minPercentage: 60.0,
      maxPercentage: 69.999,
      gradePoint: 2.8,
      description: 'Good',
      isPassing: true,
    ),
    GradeRuleModel(
      grade: 'C+',
      minPercentage: 50.0,
      maxPercentage: 59.999,
      gradePoint: 2.4,
      description: 'Satisfactory',
      isPassing: true,
    ),
    GradeRuleModel(
      grade: 'C',
      minPercentage: 40.0,
      maxPercentage: 49.999,
      gradePoint: 2.0,
      description: 'Acceptable',
      isPassing: true,
    ),
    GradeRuleModel(
      grade: 'D',
      minPercentage: 35.0,
      maxPercentage: 39.999,
      gradePoint: 1.6,
      description: 'Basic Pass',
      isPassing: true,
    ),
    GradeRuleModel(
      grade: 'F',
      minPercentage: 0.0,
      maxPercentage: 34.999,
      gradePoint: 0.0,
      description: 'Fail',
      isPassing: false,
    ),
  ];

  /// Validates a list of grading rules.
  /// Returns null if valid, or a descriptive error message if invalid.
  static String? validateRules(List<GradeRuleModel> rules) {
    if (rules.isEmpty) return 'At least one grade rule is required.';

    for (final r in rules) {
      if (r.minPercentage < 0 || r.maxPercentage > 100) {
        return 'Grade ${r.grade} boundaries must be within 0% and 100%.';
      }
      if (r.minPercentage > r.maxPercentage) {
        return 'Grade ${r.grade} min percentage (${r.minPercentage}) cannot exceed max percentage (${r.maxPercentage}).';
      }
    }

    // Check for overlapping intervals
    final sorted = List<GradeRuleModel>.from(rules)
      ..sort((a, b) => a.minPercentage.compareTo(b.minPercentage));

    for (int i = 0; i < sorted.length - 1; i++) {
      final current = sorted[i];
      final next = sorted[i + 1];
      if (current.maxPercentage >= next.minPercentage) {
        return 'Grade ranges for ${current.grade} and ${next.grade} overlap.';
      }
    }

    return null;
  }

  /// Evaluates percentage against grading rules with deterministic boundary matching.
  static GradeCalculationResult getGradeForPercentage({
    required double percentage,
    List<GradeRuleModel>? customRules,
  }) {
    final rules = customRules ?? defaultRules;
    final clamped = percentage.clamp(0.0, 100.0);

    for (final rule in rules) {
      // Use inclusive upper bound on 100%, and [min, max] matching with epsilon tolerance for floating precision
      final min = rule.minPercentage;
      final max = rule.maxPercentage;
      const epsilon = 0.0001;

      if (clamped >= (min - epsilon) && clamped <= (max + epsilon)) {
        return GradeCalculationResult(
          grade: rule.grade,
          gradePoint: rule.gradePoint,
          description: rule.description,
          isPassing: rule.isPassing,
        );
      }
    }

    // Fallback: If above highest rule, return highest rule; if below, return lowest
    if (rules.isNotEmpty) {
      final sortedDesc = List<GradeRuleModel>.from(rules)
        ..sort((a, b) => b.minPercentage.compareTo(a.minPercentage));
      if (clamped >= sortedDesc.first.minPercentage) {
        final top = sortedDesc.first;
        return GradeCalculationResult(
          grade: top.grade,
          gradePoint: top.gradePoint,
          description: top.description,
          isPassing: top.isPassing,
        );
      }
      final bottom = sortedDesc.last;
      return GradeCalculationResult(
        grade: bottom.grade,
        gradePoint: bottom.gradePoint,
        description: bottom.description,
        isPassing: bottom.isPassing,
      );
    }

    return const GradeCalculationResult(
      grade: 'F',
      gradePoint: 0.0,
      description: 'Fail',
      isPassing: false,
    );
  }
}
