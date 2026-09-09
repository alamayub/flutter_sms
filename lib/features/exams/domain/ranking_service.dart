// lib/features/exams/domain/ranking_service.dart
import 'result_calculator.dart';

class RankingService {
  /// Ranks students in a class/section based on overall performance.
  /// If [rankPassingOnly] is true, failing students receive rank = null.
  /// Ties are handled using standard competition ranking (1, 2, 2, 4...).
  static List<StudentExamResult> rankStudents(
    List<StudentExamResult> results, {
    bool rankPassingOnly = false,
  }) {
    if (results.isEmpty) return [];

    final list = List<StudentExamResult>.from(results);

    list.sort((a, b) {
      // First sort by passing status if rankPassingOnly
      if (rankPassingOnly && a.isPassed != b.isPassed) {
        return a.isPassed ? -1 : 1;
      }
      // Then by percentage descending
      final pctComp = b.percentage.compareTo(a.percentage);
      if (pctComp != 0) return pctComp;

      // Then by total marks obtained descending
      return b.totalMarksObtained.compareTo(a.totalMarksObtained);
    });

    final ranked = <StudentExamResult>[];

    for (int i = 0; i < list.length; i++) {
      final student = list[i];

      if (rankPassingOnly && !student.isPassed) {
        ranked.add(student.copyWith(rank: null));
        continue;
      }

      if (i > 0) {
        final prev = list[i - 1];
        if (student.percentage == prev.percentage &&
            student.totalMarksObtained == prev.totalMarksObtained) {
          // Tied with previous student
          ranked.add(student.copyWith(rank: ranked.last.rank));
          continue;
        }
      }

      ranked.add(student.copyWith(rank: i + 1));
    }

    return ranked;
  }
}
