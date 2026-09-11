import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../data/app_database.dart';
import '../services/timetable_service.dart';
import 'academic_year_provider.dart';
import 'database_provider.dart';

enum TimetableCalendarMode { weeklyGrid, dayTimeline }

/// Provider for TimetableService
final timetableServiceProvider = Provider<TimetableService>((ref) {
  final db = ref.watch(databaseProvider);
  return TimetableService(db);
});

/// Filter notifier for academic year selection (null = auto-select current active year)
class SelectedTimetableAcademicYearNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void setAcademicYear(int? yearId) => state = yearId;
}

final selectedTimetableAcademicYearProvider =
    NotifierProvider<SelectedTimetableAcademicYearNotifier, int?>(
      SelectedTimetableAcademicYearNotifier.new,
    );

/// Filter notifier for class selection
class SelectedTimetableClassNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void setClass(int? classId) => state = classId;
}

final selectedTimetableClassProvider =
    NotifierProvider<SelectedTimetableClassNotifier, int?>(
      SelectedTimetableClassNotifier.new,
    );

/// Filter notifier for section selection
class SelectedTimetableSectionNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void setSection(int? sectionId) => state = sectionId;
}

final selectedTimetableSectionProvider =
    NotifierProvider<SelectedTimetableSectionNotifier, int?>(
      SelectedTimetableSectionNotifier.new,
    );

/// Filter notifier for day of week ('sunday', 'monday', ... 'saturday')
class SelectedTimetableDayNotifier extends Notifier<String> {
  @override
  String build() {
    // Dart DateTime.weekday: 1 = Monday .. 7 = Sunday
    const days = [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday',
    ];
    final weekday = DateTime.now().weekday;
    return days[weekday - 1];
  }

  void setDay(String day) => state = day.toLowerCase();
}

final selectedTimetableDayProvider =
    NotifierProvider<SelectedTimetableDayNotifier, String>(
      SelectedTimetableDayNotifier.new,
    );

/// Notifier for View Mode: Weekly Matrix Grid vs Day Timeline Schedule
class TimetableCalendarModeNotifier extends Notifier<TimetableCalendarMode> {
  @override
  TimetableCalendarMode build() => TimetableCalendarMode.weeklyGrid;

  void setMode(TimetableCalendarMode mode) => state = mode;
}

final timetableCalendarModeProvider =
    NotifierProvider<TimetableCalendarModeNotifier, TimetableCalendarMode>(
      TimetableCalendarModeNotifier.new,
    );

/// Reactive stream provider for periods of selected class and section in an academic year
final weeklyPeriodsStreamProvider = StreamProvider<List<PeriodWithDetails>>((
  ref,
) {
  final service = ref.watch(timetableServiceProvider);
  final explicitYearId = ref.watch(selectedTimetableAcademicYearProvider);
  final activeYear = ref.watch(activeAcademicYearProvider).value;
  final academicYearId = explicitYearId ?? activeYear?.id;
  final classId = ref.watch(selectedTimetableClassProvider);
  final sectionId = ref.watch(selectedTimetableSectionProvider);

  return service.watchPeriodsWithDetails(
    academicYearId: academicYearId,
    classId: classId,
    sectionId: sectionId,
  );
});

/// Reactive stream provider for periods of selected day in an academic year
final dayPeriodsStreamProvider = StreamProvider<List<PeriodWithDetails>>((ref) {
  final service = ref.watch(timetableServiceProvider);
  final explicitYearId = ref.watch(selectedTimetableAcademicYearProvider);
  final activeYear = ref.watch(activeAcademicYearProvider).value;
  final academicYearId = explicitYearId ?? activeYear?.id;
  final classId = ref.watch(selectedTimetableClassProvider);
  final sectionId = ref.watch(selectedTimetableSectionProvider);
  final day = ref.watch(selectedTimetableDayProvider);

  return service.watchPeriodsWithDetails(
    academicYearId: academicYearId,
    classId: classId,
    sectionId: sectionId,
    dayOfWeek: day,
  );
});

/// Controller for Timetable Mutations
class TimetableController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<int?> createPeriod({
    required int academicYearId,
    required int classId,
    int? sectionId,
    required String dayOfWeek,
    int periodNumber = 1,
    required String startTime,
    required String endTime,
    bool isBreak = false,
    String? breakTitle,
    int? subjectId,
    int? teacherId,
    String? roomNumber,
  }) async {
    state = const AsyncValue.loading();
    int? createdId;
    state = await AsyncValue.guard(() async {
      final service = ref.read(timetableServiceProvider);
      createdId = await service.createPeriod(
        academicYearId: academicYearId,
        classId: classId,
        sectionId: sectionId,
        dayOfWeek: dayOfWeek,
        periodNumber: periodNumber,
        startTime: startTime,
        endTime: endTime,
        isBreak: isBreak,
        breakTitle: breakTitle,
        subjectId: subjectId,
        teacherId: teacherId,
        roomNumber: roomNumber,
      );
    });
    return createdId;
  }

  Future<bool> updatePeriod({
    required int id,
    required int academicYearId,
    required int classId,
    int? sectionId,
    required String dayOfWeek,
    int periodNumber = 1,
    required String startTime,
    required String endTime,
    bool isBreak = false,
    String? breakTitle,
    int? subjectId,
    int? teacherId,
    String? roomNumber,
  }) async {
    state = const AsyncValue.loading();
    bool success = false;
    state = await AsyncValue.guard(() async {
      final service = ref.read(timetableServiceProvider);
      success = await service.updatePeriod(
        id: id,
        academicYearId: academicYearId,
        classId: classId,
        sectionId: sectionId,
        dayOfWeek: dayOfWeek,
        periodNumber: periodNumber,
        startTime: startTime,
        endTime: endTime,
        isBreak: isBreak,
        breakTitle: breakTitle,
        subjectId: subjectId,
        teacherId: teacherId,
        roomNumber: roomNumber,
      );
    });
    return success;
  }

  Future<void> deletePeriod(int id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(timetableServiceProvider);
      await service.deletePeriod(id);
    });
  }

  Future<void> saveWeeklyTimetable({
    required int academicYearId,
    required int classId,
    int? sectionId,
    required List<WeeklyPeriodSlotInput> periods,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(timetableServiceProvider);
      await service.saveWeeklyTimetable(
        academicYearId: academicYearId,
        classId: classId,
        sectionId: sectionId,
        periods: periods,
      );
    });
  }

  Future<void> clearWeeklyTimetable({
    required int academicYearId,
    required int classId,
    int? sectionId,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(timetableServiceProvider);
      await service.clearWeeklyTimetable(
        academicYearId: academicYearId,
        classId: classId,
        sectionId: sectionId,
      );
    });
  }

  Future<int> copyTimetableFromYear({
    required int sourceAcademicYearId,
    required int targetAcademicYearId,
    int? classId,
    int? sectionId,
  }) async {
    state = const AsyncValue.loading();
    int copiedCount = 0;
    state = await AsyncValue.guard(() async {
      final service = ref.read(timetableServiceProvider);
      copiedCount = await service.copyTimetableFromYear(
        sourceAcademicYearId: sourceAcademicYearId,
        targetAcademicYearId: targetAcademicYearId,
        classId: classId,
        sectionId: sectionId,
      );
    });
    return copiedCount;
  }
}

final timetableControllerProvider =
    AsyncNotifierProvider<TimetableController, void>(TimetableController.new);
