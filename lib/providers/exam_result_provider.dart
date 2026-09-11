import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../data/app_database.dart';
import '../services/exam_result_service.dart';
import 'database_provider.dart';

/// Provider for ExamResultService
final examResultServiceProvider = Provider<ExamResultService>((ref) {
  final db = ref.watch(databaseProvider);
  return ExamResultService(db);
});

// =============================================================================
// Filters for Marks Entry & Results Ledger
// =============================================================================

/// Selected Exam ID filter
class SelectedResultExamIdNotifier extends Notifier<int?> {
  @override
  int? build() => null;
  void setExam(int? id) => state = id;
}

final selectedResultExamIdProvider =
    NotifierProvider<SelectedResultExamIdNotifier, int?>(
      SelectedResultExamIdNotifier.new,
    );

/// Selected Class ID filter
class SelectedResultClassIdNotifier extends Notifier<int?> {
  @override
  int? build() => null;
  void setClass(int? id) => state = id;
}

final selectedResultClassIdProvider =
    NotifierProvider<SelectedResultClassIdNotifier, int?>(
      SelectedResultClassIdNotifier.new,
    );

/// Selected Section ID filter
class SelectedResultSectionIdNotifier extends Notifier<int?> {
  @override
  int? build() => null;
  void setSection(int? id) => state = id;
}

final selectedResultSectionIdProvider =
    NotifierProvider<SelectedResultSectionIdNotifier, int?>(
      SelectedResultSectionIdNotifier.new,
    );

/// Selected Subject ID filter (for Subject Batch Entry)
class SelectedResultSubjectIdNotifier extends Notifier<int?> {
  @override
  int? build() => null;
  void setSubject(int? id) => state = id;
}

final selectedResultSubjectIdProvider =
    NotifierProvider<SelectedResultSubjectIdNotifier, int?>(
      SelectedResultSubjectIdNotifier.new,
    );

/// Selected Student ID filter (for Student Marksheet Entry)
class SelectedResultStudentIdNotifier extends Notifier<int?> {
  @override
  int? build() => null;
  void setStudent(int? id) => state = id;
}

final selectedResultStudentIdProvider =
    NotifierProvider<SelectedResultStudentIdNotifier, int?>(
      SelectedResultStudentIdNotifier.new,
    );

/// Search filter for students
class SelectedResultSearchNotifier extends Notifier<String> {
  @override
  String build() => '';
  void setSearch(String query) => state = query;
}

final selectedResultSearchProvider =
    NotifierProvider<SelectedResultSearchNotifier, String>(
      SelectedResultSearchNotifier.new,
    );

// =============================================================================
// Reactive Streams & Future Providers
// =============================================================================

/// Reactive stream of exam results matching current filter selections
final examResultsStreamProvider =
    StreamProvider.autoDispose<List<ExamResultWithDetails>>((ref) {
      final service = ref.watch(examResultServiceProvider);
      final examId = ref.watch(selectedResultExamIdProvider);
      final classId = ref.watch(selectedResultClassIdProvider);
      final sectionId = ref.watch(selectedResultSectionIdProvider);
      final subjectId = ref.watch(selectedResultSubjectIdProvider);
      final studentId = ref.watch(selectedResultStudentIdProvider);

      if (examId == null) {
        return Stream.value([]);
      }

      return service.watchExamResults(
        examId: examId,
        classId: classId,
        sectionId: sectionId,
        subjectId: subjectId,
        studentId: studentId,
      );
    });

/// Reactive stream of student exam summaries (for Tabulation Ledger & Class Ranks)
final examSummariesStreamProvider =
    StreamProvider.autoDispose<List<StudentExamSummaryWithDetails>>((ref) {
      final service = ref.watch(examResultServiceProvider);
      final examId = ref.watch(selectedResultExamIdProvider);
      final classId = ref.watch(selectedResultClassIdProvider);
      final sectionId = ref.watch(selectedResultSectionIdProvider);

      if (examId == null) {
        return Stream.value([]);
      }

      return service.watchExamSummaries(
        examId: examId,
        classId: classId,
        sectionId: sectionId,
      );
    });

/// Enrolled students in the selected class and section for the active academic year
final enrolledStudentsForExamProvider = FutureProvider.autoDispose
    .family<List<Student>, ({int classId, int? sectionId, int academicYearId})>(
      (ref, params) async {
        final service = ref.watch(examResultServiceProvider);
        return service.getStudentsForExam(
          classId: params.classId,
          sectionId: params.sectionId,
          academicYearId: params.academicYearId,
        );
      },
    );

/// Marks configuration for a chosen subject in an exam
final subjectMarksConfigProvider = FutureProvider.autoDispose.family<
  SubjectExamMarksConfig?,
  ({int examId, int classId, int subjectId})
>((ref, params) async {
  final service = ref.watch(examResultServiceProvider);
  return service.getSubjectMarksConfig(
    examId: params.examId,
    classId: params.classId,
    subjectId: params.subjectId,
  );
});

// =============================================================================
// Mutation Controller
// =============================================================================

class ExamResultController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Save subject marks batch
  Future<bool> saveSubjectMarksBatch({
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
    state = const AsyncValue.loading();
    bool success = false;
    state = await AsyncValue.guard(() async {
      final service = ref.read(examResultServiceProvider);
      await service.saveSubjectMarksBatch(
        examId: examId,
        academicYearId: academicYearId,
        classId: classId,
        sectionId: sectionId,
        subjectId: subjectId,
        examScheduleId: examScheduleId,
        theoryFullMarks: theoryFullMarks,
        theoryPassMarks: theoryPassMarks,
        practicalFullMarks: practicalFullMarks,
        practicalPassMarks: practicalPassMarks,
        entries: entries,
      );
      success = true;
    });
    return success;
  }

  /// Save student marksheet batch
  Future<bool> saveStudentMarksheetBatch({
    required int examId,
    required int academicYearId,
    required int classId,
    int? sectionId,
    required int studentId,
    required List<StudentSubjectMarksEntryInput> entries,
  }) async {
    state = const AsyncValue.loading();
    bool success = false;
    state = await AsyncValue.guard(() async {
      final service = ref.read(examResultServiceProvider);
      await service.saveStudentMarksheetBatch(
        examId: examId,
        academicYearId: academicYearId,
        classId: classId,
        sectionId: sectionId,
        studentId: studentId,
        entries: entries,
      );
      success = true;
    });
    return success;
  }

  /// Recalculate class summaries
  Future<void> recalculateSummaries({
    required int examId,
    required int academicYearId,
    required int classId,
    int? sectionId,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(examResultServiceProvider);
      await service.recalculateExamSummariesForClass(
        examId: examId,
        academicYearId: academicYearId,
        classId: classId,
        sectionId: sectionId,
      );
    });
  }

  /// Delete exam results
  Future<bool> deleteExamResults({
    required int examId,
    required int classId,
    int? sectionId,
    int? subjectId,
  }) async {
    state = const AsyncValue.loading();
    bool success = false;
    state = await AsyncValue.guard(() async {
      final service = ref.read(examResultServiceProvider);
      await service.deleteExamResultsForClass(
        examId: examId,
        classId: classId,
        sectionId: sectionId,
        subjectId: subjectId,
      );
      success = true;
    });
    return success;
  }
}

final examResultControllerProvider =
    AsyncNotifierProvider<ExamResultController, void>(ExamResultController.new);
