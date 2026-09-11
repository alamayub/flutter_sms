import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../data/app_database.dart';
import '../services/exam_service.dart';
import 'academic_year_provider.dart';
import 'database_provider.dart';

/// Provider for ExamService
final examServiceProvider = Provider<ExamService>((ref) {
  final db = ref.watch(databaseProvider);
  return ExamService(db);
});

/// Filter for Academic Year in Exam screens (defaults to active academic year)
class SelectedExamAcademicYearFilterNotifier extends Notifier<int?> {
  @override
  int? build() {
    final activeYearAsync = ref.watch(activeAcademicYearProvider);
    return activeYearAsync.value?.id;
  }

  void setFilter(int? yearId) => state = yearId;
}

final selectedExamAcademicYearFilterProvider =
    NotifierProvider<SelectedExamAcademicYearFilterNotifier, int?>(
      SelectedExamAcademicYearFilterNotifier.new,
    );

/// Filter for Exam Category (null = All Categories)
class SelectedExamCategoryFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setFilter(String? category) => state = category;
}

final selectedExamCategoryFilterProvider =
    NotifierProvider<SelectedExamCategoryFilterNotifier, String?>(
      SelectedExamCategoryFilterNotifier.new,
    );

/// Filter for Class in Exam Schedules (null = All Classes)
class SelectedExamClassFilterNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void setFilter(int? classId) => state = classId;
}

final selectedExamClassFilterProvider =
    NotifierProvider<SelectedExamClassFilterNotifier, int?>(
      SelectedExamClassFilterNotifier.new,
    );

/// Filter for specific Exam in schedule view (null = All Exams)
class SelectedExamIdFilterNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void setFilter(int? examId) => state = examId;
}

final selectedExamIdFilterProvider =
    NotifierProvider<SelectedExamIdFilterNotifier, int?>(
      SelectedExamIdFilterNotifier.new,
    );

/// Filter for Exam Status (null = All Statuses)
class SelectedExamStatusFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setFilter(String? status) => state = status;
}

final selectedExamStatusFilterProvider =
    NotifierProvider<SelectedExamStatusFilterNotifier, String?>(
      SelectedExamStatusFilterNotifier.new,
    );

/// Reactive stream of Exams based on active filters
final examsStreamProvider = StreamProvider<List<ExamWithDetails>>((ref) {
  final service = ref.watch(examServiceProvider);
  final yearId = ref.watch(selectedExamAcademicYearFilterProvider);
  final category = ref.watch(selectedExamCategoryFilterProvider);
  final status = ref.watch(selectedExamStatusFilterProvider);

  return service.watchExamsWithDetails(
    academicYearId: yearId,
    category: category,
    status: status,
  );
});

/// Reactive stream of Exam Schedules / Routines based on active filters
final examSchedulesStreamProvider =
    StreamProvider<List<ExamScheduleWithDetails>>((ref) {
      final service = ref.watch(examServiceProvider);
      final examId = ref.watch(selectedExamIdFilterProvider);
      final classId = ref.watch(selectedExamClassFilterProvider);
      final yearId = ref.watch(selectedExamAcademicYearFilterProvider);

      return service.watchExamSchedulesWithDetails(
        examId: examId,
        classId: classId,
        academicYearId: yearId,
      );
    });

/// Async controller for Exam and Schedule mutations
class ExamController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Create an exam
  Future<int?> createExam({
    required String name,
    required String category,
    required int academicYearId,
    required DateTime startDate,
    required DateTime endDate,
    String? description,
    String status = 'Scheduled',
  }) async {
    state = const AsyncValue.loading();
    int? createdId;
    state = await AsyncValue.guard(() async {
      final service = ref.read(examServiceProvider);
      createdId = await service.createExam(
        name: name,
        category: category,
        academicYearId: academicYearId,
        startDate: startDate,
        endDate: endDate,
        description: description,
        status: status,
      );
    });
    return createdId;
  }

  /// Update an exam
  Future<bool> updateExam({
    required int id,
    required String name,
    required String category,
    required int academicYearId,
    required DateTime startDate,
    required DateTime endDate,
    String? description,
    required String status,
  }) async {
    state = const AsyncValue.loading();
    bool success = false;
    state = await AsyncValue.guard(() async {
      final service = ref.read(examServiceProvider);
      success = await service.updateExam(
        id: id,
        name: name,
        category: category,
        academicYearId: academicYearId,
        startDate: startDate,
        endDate: endDate,
        description: description,
        status: status,
      );
    });
    return success;
  }

  /// Delete an exam
  Future<bool> deleteExam(int id) async {
    state = const AsyncValue.loading();
    bool success = false;
    state = await AsyncValue.guard(() async {
      final service = ref.read(examServiceProvider);
      final count = await service.deleteExam(id);
      success = count > 0;
    });
    return success;
  }

  /// Save or replace subject routines for a class in an exam
  Future<bool> saveClassExamSchedule({
    required int examId,
    required int academicYearId,
    required int classId,
    required List<ExamScheduleItemInput> items,
  }) async {
    state = const AsyncValue.loading();
    bool success = false;
    state = await AsyncValue.guard(() async {
      final service = ref.read(examServiceProvider);
      await service.saveClassExamSchedule(
        examId: examId,
        academicYearId: academicYearId,
        classId: classId,
        items: items,
      );
      success = true;
    });
    return success;
  }

  /// Create or update an exam and its class schedules in a single unified operation
  Future<int?> saveExamWithClassSchedules({
    int? examId,
    required String name,
    required String category,
    required int academicYearId,
    required int classId,
    int? sectionId,
    required DateTime startDate,
    required DateTime endDate,
    String? description,
    required String status,
    required List<ExamScheduleItemInput> schedules,
  }) async {
    state = const AsyncValue.loading();
    int? resultId;
    state = await AsyncValue.guard(() async {
      final service = ref.read(examServiceProvider);
      resultId = await service.saveExamWithClassSchedules(
        examId: examId,
        name: name,
        category: category,
        academicYearId: academicYearId,
        classId: classId,
        sectionId: sectionId,
        startDate: startDate,
        endDate: endDate,
        description: description,
        status: status,
        schedules: schedules,
      );
    });
    return resultId;
  }

  /// Delete a single scheduled exam paper
  Future<bool> deleteExamSchedule(int id) async {
    state = const AsyncValue.loading();
    bool success = false;
    state = await AsyncValue.guard(() async {
      final service = ref.read(examServiceProvider);
      final count = await service.deleteExamSchedule(id);
      success = count > 0;
    });
    return success;
  }

  /// Delete all schedules for a class within an exam
  Future<bool> deleteClassSchedule(int examId, int classId) async {
    state = const AsyncValue.loading();
    bool success = false;
    state = await AsyncValue.guard(() async {
      final service = ref.read(examServiceProvider);
      final count = await service.deleteClassSchedule(examId, classId);
      success = count > 0;
    });
    return success;
  }
}

final examControllerProvider = AsyncNotifierProvider<ExamController, void>(
  ExamController.new,
);
