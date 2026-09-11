import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../data/app_database.dart';
import '../services/class_section_service.dart';
import 'database_provider.dart';

/// Provider for ClassSectionService
final classSectionServiceProvider = Provider<ClassSectionService>((ref) {
  final db = ref.watch(databaseProvider);
  return ClassSectionService(db);
});

/// Reactive stream of all classes with their sections
final classesWithSectionsStreamProvider =
    StreamProvider<List<ClassWithSections>>((ref) {
      final service = ref.watch(classSectionServiceProvider);
      return service.watchClassesWithSections();
    });

/// AsyncNotifier controller for class and section mutations
class ClassSectionController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<int?> createClass({
    required String name,
    required String displayName,
    int orderIndex = 0,
    List<String> sections = const [],
  }) async {
    state = const AsyncValue.loading();
    int? createdId;
    state = await AsyncValue.guard(() async {
      final service = ref.read(classSectionServiceProvider);
      createdId = await service.createClass(
        name: name,
        displayName: displayName,
        orderIndex: orderIndex,
        sections: sections,
      );
    });
    return createdId;
  }

  Future<void> updateClass({
    required int id,
    required String name,
    required String displayName,
    int orderIndex = 0,
    List<String> sections = const [],
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(classSectionServiceProvider);
      await service.updateClass(
        id: id,
        name: name,
        displayName: displayName,
        orderIndex: orderIndex,
        sections: sections,
      );
    });
  }

  Future<void> deleteClass(int id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(classSectionServiceProvider);
      await service.deleteClass(id);
    });
  }

  Future<void> addSection({
    required int classId,
    required String name,
    String? roomNumber,
    int? capacity,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(classSectionServiceProvider);
      await service.addSection(
        classId: classId,
        name: name,
        roomNumber: roomNumber,
        capacity: capacity,
      );
    });
  }

  Future<void> deleteSection(int sectionId) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(classSectionServiceProvider);
      await service.deleteSection(sectionId);
    });
  }
}

final classSectionControllerProvider =
    AsyncNotifierProvider<ClassSectionController, void>(
      ClassSectionController.new,
    );
