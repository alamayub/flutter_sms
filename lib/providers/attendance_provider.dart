import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../config/enums.dart';
import '../services/attendance_service.dart';
import 'database_provider.dart';

/// Provider for AttendanceService
final attendanceServiceProvider = Provider<AttendanceService>((ref) {
  final db = ref.watch(databaseProvider);
  return AttendanceService(db);
});

// ==================== FILTER NOTIFIERS ====================

/// Date filter for student attendance
class StudentAttendanceDateNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  void setDate(DateTime date) {
    state = DateTime(date.year, date.month, date.day);
  }
}

final studentAttendanceDateProvider =
    NotifierProvider<StudentAttendanceDateNotifier, DateTime>(
      StudentAttendanceDateNotifier.new,
    );

/// Selected class ID for student attendance
class StudentAttendanceClassIdNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void setClassId(int? id) => state = id;
}

final studentAttendanceClassIdProvider =
    NotifierProvider<StudentAttendanceClassIdNotifier, int?>(
      StudentAttendanceClassIdNotifier.new,
    );

/// Selected section ID for student attendance
class StudentAttendanceSectionIdNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void setSectionId(int? id) => state = id;
}

final studentAttendanceSectionIdProvider =
    NotifierProvider<StudentAttendanceSectionIdNotifier, int?>(
      StudentAttendanceSectionIdNotifier.new,
    );

/// Search filter for student list
class StudentAttendanceSearchNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setSearch(String query) => state = query;
}

final studentAttendanceSearchProvider =
    NotifierProvider<StudentAttendanceSearchNotifier, String>(
      StudentAttendanceSearchNotifier.new,
    );

/// Date filter for staff attendance
class StaffAttendanceDateNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  void setDate(DateTime date) {
    state = DateTime(date.year, date.month, date.day);
  }
}

final staffAttendanceDateProvider =
    NotifierProvider<StaffAttendanceDateNotifier, DateTime>(
      StaffAttendanceDateNotifier.new,
    );

/// Department filter for staff attendance
class StaffAttendanceDepartmentNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setDepartment(String? dept) => state = dept;
}

final staffAttendanceDepartmentProvider =
    NotifierProvider<StaffAttendanceDepartmentNotifier, String?>(
      StaffAttendanceDepartmentNotifier.new,
    );

/// Role/Type filter for staff attendance (Teacher vs Staff)
class StaffAttendanceTypeNotifier extends Notifier<EmployeeType?> {
  @override
  EmployeeType? build() => null;

  void setType(EmployeeType? type) => state = type;
}

final staffAttendanceTypeProvider =
    NotifierProvider<StaffAttendanceTypeNotifier, EmployeeType?>(
      StaffAttendanceTypeNotifier.new,
    );

/// Search filter for staff list
class StaffAttendanceSearchNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setSearch(String query) => state = query;
}

final staffAttendanceSearchProvider =
    NotifierProvider<StaffAttendanceSearchNotifier, String>(
      StaffAttendanceSearchNotifier.new,
    );

/// Month and year filter for attendance register
class AttendanceRegisterMonthNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, 1);
  }

  void setMonth(DateTime month) {
    state = DateTime(month.year, month.month, 1);
  }
}

final attendanceRegisterMonthProvider =
    NotifierProvider<AttendanceRegisterMonthNotifier, DateTime>(
      AttendanceRegisterMonthNotifier.new,
    );

/// Register view mode: true = Students, false = Staff
class AttendanceRegisterModeNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void setMode(bool isStudents) => state = isStudents;
}

final attendanceRegisterModeProvider =
    NotifierProvider<AttendanceRegisterModeNotifier, bool>(
      AttendanceRegisterModeNotifier.new,
    );

// ==================== STATE CONTROLLERS ====================

/// Student attendance list state and operations
class StudentAttendanceController
    extends Notifier<AsyncValue<List<StudentAttendanceRecordItem>>> {
  @override
  AsyncValue<List<StudentAttendanceRecordItem>> build() {
    return const AsyncValue.data([]);
  }

  Future<void> load({
    required int classId,
    int? sectionId,
    required DateTime date,
  }) async {
    state = const AsyncValue.loading();
    try {
      final service = ref.read(attendanceServiceProvider);
      final items = await service.getStudentsWithAttendanceForDate(
        classId: classId,
        sectionId: sectionId,
        date: date,
      );
      state = AsyncValue.data(items);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void updateStatus(int studentId, AttendanceStatus newStatus) {
    final currentList = state.asData?.value;
    if (currentList == null) return;

    final updated =
        currentList.map((item) {
          if (item.student.id == studentId) {
            return item.copyWith(status: newStatus);
          }
          return item;
        }).toList();

    state = AsyncValue.data(updated);
  }

  void updateRemarks(int studentId, String remarks) {
    final currentList = state.asData?.value;
    if (currentList == null) return;

    final updated =
        currentList.map((item) {
          if (item.student.id == studentId) {
            return item.copyWith(
              remarks: remarks.trim().isEmpty ? null : remarks.trim(),
            );
          }
          return item;
        }).toList();

    state = AsyncValue.data(updated);
  }

  void markAll(AttendanceStatus status) {
    final currentList = state.asData?.value;
    if (currentList == null) return;

    final updated =
        currentList.map((item) {
          return item.copyWith(status: status);
        }).toList();

    state = AsyncValue.data(updated);
  }

  Future<bool> save({
    required int academicYearId,
    required int classId,
    int? sectionId,
    required DateTime date,
  }) async {
    final currentList = state.asData?.value;
    if (currentList == null || currentList.isEmpty) return false;

    try {
      final service = ref.read(attendanceServiceProvider);
      await service.saveStudentAttendanceBatch(
        academicYearId: academicYearId,
        classId: classId,
        sectionId: sectionId,
        date: date,
        records: currentList,
      );
      // Reload to update persisted records
      await load(classId: classId, sectionId: sectionId, date: date);
      return true;
    } catch (e) {
      debugPrint('Error saving student attendance: $e');
      return false;
    }
  }
}

final studentAttendanceControllerProvider = NotifierProvider<
  StudentAttendanceController,
  AsyncValue<List<StudentAttendanceRecordItem>>
>(StudentAttendanceController.new);

/// Staff attendance list state and operations
class StaffAttendanceController
    extends Notifier<AsyncValue<List<StaffAttendanceRecordItem>>> {
  @override
  AsyncValue<List<StaffAttendanceRecordItem>> build() {
    return const AsyncValue.data([]);
  }

  Future<void> load({
    required DateTime date,
    String? department,
    EmployeeType? employeeType,
  }) async {
    state = const AsyncValue.loading();
    try {
      final service = ref.read(attendanceServiceProvider);
      final items = await service.getStaffWithAttendanceForDate(
        date: date,
        department: department,
        employeeType: employeeType,
      );
      state = AsyncValue.data(items);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void updateStatus(int employeeId, AttendanceStatus newStatus) {
    final currentList = state.asData?.value;
    if (currentList == null) return;

    final updated =
        currentList.map((item) {
          if (item.employee.id == employeeId) {
            return item.copyWith(status: newStatus);
          }
          return item;
        }).toList();

    state = AsyncValue.data(updated);
  }

  void updateCheckInTime(int employeeId, String time) {
    final currentList = state.asData?.value;
    if (currentList == null) return;

    final updated =
        currentList.map((item) {
          if (item.employee.id == employeeId) {
            return item.copyWith(
              checkInTime: time.trim().isEmpty ? null : time.trim(),
            );
          }
          return item;
        }).toList();

    state = AsyncValue.data(updated);
  }

  void updateCheckOutTime(int employeeId, String time) {
    final currentList = state.asData?.value;
    if (currentList == null) return;

    final updated =
        currentList.map((item) {
          if (item.employee.id == employeeId) {
            return item.copyWith(
              checkOutTime: time.trim().isEmpty ? null : time.trim(),
            );
          }
          return item;
        }).toList();

    state = AsyncValue.data(updated);
  }

  void updateRemarks(int employeeId, String remarks) {
    final currentList = state.asData?.value;
    if (currentList == null) return;

    final updated =
        currentList.map((item) {
          if (item.employee.id == employeeId) {
            return item.copyWith(
              remarks: remarks.trim().isEmpty ? null : remarks.trim(),
            );
          }
          return item;
        }).toList();

    state = AsyncValue.data(updated);
  }

  void markAll(AttendanceStatus status) {
    final currentList = state.asData?.value;
    if (currentList == null) return;

    final updated =
        currentList.map((item) {
          return item.copyWith(status: status);
        }).toList();

    state = AsyncValue.data(updated);
  }

  Future<bool> save({required DateTime date}) async {
    final currentList = state.asData?.value;
    if (currentList == null || currentList.isEmpty) return false;

    try {
      final service = ref.read(attendanceServiceProvider);
      await service.saveStaffAttendanceBatch(date: date, records: currentList);
      // Reload
      final dept = ref.read(staffAttendanceDepartmentProvider);
      final type = ref.read(staffAttendanceTypeProvider);
      await load(date: date, department: dept, employeeType: type);
      return true;
    } catch (e) {
      debugPrint('Error saving staff attendance: $e');
      return false;
    }
  }
}

final staffAttendanceControllerProvider = NotifierProvider<
  StaffAttendanceController,
  AsyncValue<List<StaffAttendanceRecordItem>>
>(StaffAttendanceController.new);

// ==================== COMPUTED SUMMARY PROVIDERS ====================

/// Computed student summary KPI
final studentDailySummaryProvider = Provider<AttendanceSummary>((ref) {
  final state = ref.watch(studentAttendanceControllerProvider);
  final items = state.asData?.value ?? [];
  final service = ref.read(attendanceServiceProvider);
  return service.calculateStudentSummary(items);
});

/// Computed staff summary KPI
final staffDailySummaryProvider = Provider<AttendanceSummary>((ref) {
  final state = ref.watch(staffAttendanceControllerProvider);
  final items = state.asData?.value ?? [];
  final service = ref.read(attendanceServiceProvider);
  return service.calculateStaffSummary(items);
});

/// Monthly student register data provider
final studentMonthlyRegisterFutureProvider =
    FutureProvider<List<StudentMonthlyRegisterRow>>((ref) async {
      final classId = ref.watch(studentAttendanceClassIdProvider);
      if (classId == null) return [];

      final sectionId = ref.watch(studentAttendanceSectionIdProvider);
      final monthDate = ref.watch(attendanceRegisterMonthProvider);
      final service = ref.read(attendanceServiceProvider);

      return service.getStudentMonthlyRegister(
        classId: classId,
        sectionId: sectionId,
        year: monthDate.year,
        month: monthDate.month,
      );
    });

/// Monthly staff register data provider
final staffMonthlyRegisterFutureProvider =
    FutureProvider<List<StaffMonthlyRegisterRow>>((ref) async {
      final department = ref.watch(staffAttendanceDepartmentProvider);
      final monthDate = ref.watch(attendanceRegisterMonthProvider);
      final service = ref.read(attendanceServiceProvider);

      return service.getStaffMonthlyRegister(
        year: monthDate.year,
        month: monthDate.month,
        department: department,
      );
    });
