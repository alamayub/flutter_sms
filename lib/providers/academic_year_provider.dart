import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../data/app_database.dart';
import '../services/academic_year_service.dart';
import 'database_provider.dart';
import 'storage_provider.dart';

/// Provider for AcademicYearService
final academicYearServiceProvider = Provider<AcademicYearService>((ref) {
  final db = ref.watch(databaseProvider);
  final storage = ref.watch(storageServiceProvider);
  return AcademicYearService(db, storage);
});

/// Reactive stream of all academic years
final academicYearsStreamProvider = StreamProvider<List<AcademicYear>>((ref) {
  final service = ref.watch(academicYearServiceProvider);
  return service.watchAcademicYears();
});

/// Reactive stream of currently active academic year
final activeAcademicYearProvider = StreamProvider<AcademicYear?>((ref) {
  final service = ref.watch(academicYearServiceProvider);
  return service.watchCurrentAcademicYear();
});

/// Async controller for managing mutations (create, edit, delete, activate)
class AcademicYearController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<int?> createYear({
    required String name,
    required DateTime startDate,
    required DateTime endDate,
    bool isCurrent = false,
    String? description,
  }) async {
    state = const AsyncValue.loading();
    int? createdId;
    state = await AsyncValue.guard(() async {
      final service = ref.read(academicYearServiceProvider);
      createdId = await service.createAcademicYear(
        name: name,
        startDate: startDate,
        endDate: endDate,
        isCurrent: isCurrent,
        description: description,
      );
    });
    return createdId;
  }

  Future<bool> updateYear({
    required int id,
    required String name,
    required DateTime startDate,
    required DateTime endDate,
    required bool isCurrent,
    String? description,
  }) async {
    state = const AsyncValue.loading();
    bool success = false;
    state = await AsyncValue.guard(() async {
      final service = ref.read(academicYearServiceProvider);
      success = await service.updateAcademicYear(
        id: id,
        name: name,
        startDate: startDate,
        endDate: endDate,
        isCurrent: isCurrent,
        description: description,
      );
    });
    return success;
  }

  Future<void> setActiveYear(int id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(academicYearServiceProvider);
      await service.setActiveYear(id);
    });
  }

  Future<void> deleteYear(int id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(academicYearServiceProvider);
      await service.deleteAcademicYear(id);
    });
  }
}

final academicYearControllerProvider =
    AsyncNotifierProvider<AcademicYearController, void>(
      AcademicYearController.new,
    );
