import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../data/app_database.dart';
import '../services/subject_service.dart';
import 'database_provider.dart';

/// Provider for SubjectService
final subjectServiceProvider = Provider<SubjectService>((ref) {
  final db = ref.watch(databaseProvider);
  return SubjectService(db);
});

/// Filter notifier for subject type (null = All Types)
class SelectedSubjectTypeFilterNotifier extends Notifier<SubjectType?> {
  @override
  SubjectType? build() => null;

  void setFilter(SubjectType? type) => state = type;
}

final selectedSubjectTypeFilterProvider =
    NotifierProvider<SelectedSubjectTypeFilterNotifier, SubjectType?>(
      SelectedSubjectTypeFilterNotifier.new,
    );

/// Filter notifier for optional/compulsory (null = All, true = Optional, false = Compulsory)
class SelectedOptionalFilterNotifier extends Notifier<bool?> {
  @override
  bool? build() => null;

  void setFilter(bool? isOptional) => state = isOptional;
}

final selectedOptionalFilterProvider =
    NotifierProvider<SelectedOptionalFilterNotifier, bool?>(
      SelectedOptionalFilterNotifier.new,
    );

/// Reactive stream provider for subjects based on active filters
final subjectsStreamProvider = StreamProvider<List<Subject>>((ref) {
  final service = ref.watch(subjectServiceProvider);
  final type = ref.watch(selectedSubjectTypeFilterProvider);
  final isOptional = ref.watch(selectedOptionalFilterProvider);

  return service.watchSubjects(type: type, isOptional: isOptional);
});

/// Controller for Subject CRUD mutations
class SubjectController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<int?> createSubject({
    required String code,
    required String name,
    required SubjectType subjectType,
    bool isOptional = false,
    int fullMarks = 100,
    int passMarks = 40,
    int? theoryMarks,
    int? practicalMarks,
    String? description,
  }) async {
    state = const AsyncValue.loading();
    int? createdId;
    state = await AsyncValue.guard(() async {
      final service = ref.read(subjectServiceProvider);
      createdId = await service.createSubject(
        code: code,
        name: name,
        subjectType: subjectType,
        isOptional: isOptional,
        fullMarks: fullMarks,
        passMarks: passMarks,
        theoryMarks: theoryMarks,
        practicalMarks: practicalMarks,
        description: description,
      );
    });
    return createdId;
  }

  Future<bool> updateSubject({
    required int id,
    required String code,
    required String name,
    required SubjectType subjectType,
    required bool isOptional,
    int fullMarks = 100,
    int passMarks = 40,
    int? theoryMarks,
    int? practicalMarks,
    String? description,
  }) async {
    state = const AsyncValue.loading();
    bool success = false;
    state = await AsyncValue.guard(() async {
      final service = ref.read(subjectServiceProvider);
      success = await service.updateSubject(
        id: id,
        code: code,
        name: name,
        subjectType: subjectType,
        isOptional: isOptional,
        fullMarks: fullMarks,
        passMarks: passMarks,
        theoryMarks: theoryMarks,
        practicalMarks: practicalMarks,
        description: description,
      );
    });
    return success;
  }

  Future<void> deleteSubject(int id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(subjectServiceProvider);
      await service.deleteSubject(id);
    });
  }
}

final subjectControllerProvider =
    AsyncNotifierProvider<SubjectController, void>(SubjectController.new);
