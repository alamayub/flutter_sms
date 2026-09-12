import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../config/enums.dart';
import '../data/app_database.dart';
import '../services/payroll_service.dart';
import 'database_provider.dart';

/// Provider for PayrollService
final payrollServiceProvider = Provider<PayrollService>((ref) {
  final db = ref.watch(databaseProvider);
  return PayrollService(db);
});

/// Filter Notifiers
class PayrollEmployeeTypeFilterNotifier extends Notifier<EmployeeType?> {
  @override
  EmployeeType? build() => null;

  void setType(EmployeeType? type) => state = type;
}

final payrollEmployeeTypeFilterProvider =
    NotifierProvider<PayrollEmployeeTypeFilterNotifier, EmployeeType?>(
      PayrollEmployeeTypeFilterNotifier.new,
    );

class PayrollYearFilterNotifier extends Notifier<int> {
  @override
  int build() => DateTime.now().year;

  void setYear(int year) => state = year;
}

final payrollYearFilterProvider =
    NotifierProvider<PayrollYearFilterNotifier, int>(
      PayrollYearFilterNotifier.new,
    );

class PayrollMonthFilterNotifier extends Notifier<int?> {
  @override
  int? build() => null; // null = all months

  void setMonth(int? month) => state = month;
}

final payrollMonthFilterProvider =
    NotifierProvider<PayrollMonthFilterNotifier, int?>(
      PayrollMonthFilterNotifier.new,
    );

class PayrollAcademicYearFilterNotifier extends Notifier<int?> {
  @override
  int? build() => null; // null = all academic years

  void setAcademicYear(int? yearId) => state = yearId;
}

final payrollAcademicYearFilterProvider =
    NotifierProvider<PayrollAcademicYearFilterNotifier, int?>(
      PayrollAcademicYearFilterNotifier.new,
    );

class PayrollSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) => state = query;
}

final payrollSearchQueryProvider =
    NotifierProvider<PayrollSearchQueryNotifier, String>(
      PayrollSearchQueryNotifier.new,
    );

class PayrollAdvanceStatusFilterNotifier extends Notifier<String> {
  @override
  String build() => 'active'; // 'all', 'active', 'settled'

  void setStatus(String status) => state = status;
}

final payrollAdvanceStatusFilterProvider =
    NotifierProvider<PayrollAdvanceStatusFilterNotifier, String>(
      PayrollAdvanceStatusFilterNotifier.new,
    );

/// Stream provider for filtered salary payments list
final salaryPaymentsStreamProvider =
    StreamProvider<List<SalaryPaymentWithDetails>>((ref) {
      final service = ref.watch(payrollServiceProvider);
      final empType = ref.watch(payrollEmployeeTypeFilterProvider);
      final year = ref.watch(payrollYearFilterProvider);
      final month = ref.watch(payrollMonthFilterProvider);
      final academicYearId = ref.watch(payrollAcademicYearFilterProvider);
      final query = ref.watch(payrollSearchQueryProvider);

      return service.watchSalaryPayments(
        year: year,
        month: month,
        employeeType: empType,
        academicYearId: academicYearId,
        query: query,
      );
    });

/// Stream provider for filtered salary advances list
final salaryAdvancesStreamProvider =
    StreamProvider<List<SalaryAdvanceWithEmployee>>((ref) {
      final service = ref.watch(payrollServiceProvider);
      final status = ref.watch(payrollAdvanceStatusFilterProvider);
      final academicYearId = ref.watch(payrollAcademicYearFilterProvider);
      final query = ref.watch(payrollSearchQueryProvider);

      return service.watchSalaryAdvances(
        status: status,
        academicYearId: academicYearId,
        query: query,
      );
    });

/// Future provider for an employee's total outstanding advance balance
final employeeOutstandingAdvanceProvider = FutureProvider.family<double, int>((
  ref,
  employeeId,
) {
  final service = ref.watch(payrollServiceProvider);
  // Re-fetch whenever salary payments or advances change
  ref.watch(salaryAdvancesStreamProvider);
  ref.watch(salaryPaymentsStreamProvider);
  return service.getOutstandingAdvance(employeeId);
});

/// Future provider for summary statistics
final payrollSummaryStatsProvider = FutureProvider<PayrollSummaryStats>((ref) {
  final service = ref.watch(payrollServiceProvider);
  final empType = ref.watch(payrollEmployeeTypeFilterProvider);
  final year = ref.watch(payrollYearFilterProvider);
  final month = ref.watch(payrollMonthFilterProvider);
  final academicYearId = ref.watch(payrollAcademicYearFilterProvider);

  // Watch streams so stats refresh immediately on data mutations
  ref.watch(salaryPaymentsStreamProvider);
  ref.watch(salaryAdvancesStreamProvider);

  return service.getSummaryStats(
    year: year,
    month: month,
    employeeType: empType,
    academicYearId: academicYearId,
  );
});

/// Controller for mutations (Disburse Salary, Give Advance, Delete)
class PayrollController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> processSalaryPayment({
    required int employeeId,
    required int year,
    required int month,
    required DateTime paymentDate,
    required double basicSalary,
    double bonus = 0.0,
    String? bonusReason,
    double deduction = 0.0,
    String? deductionReason,
    double advanceDeduction = 0.0,
    String paymentMethod = 'Bank Transfer',
    String? referenceNumber,
    String status = 'paid',
    String? notes,
    int? academicYearId,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(payrollServiceProvider);
      final targetYearId =
          academicYearId ?? ref.read(payrollAcademicYearFilterProvider);
      await service.processSalaryPayment(
        employeeId: employeeId,
        year: year,
        month: month,
        paymentDate: paymentDate,
        basicSalary: basicSalary,
        bonus: bonus,
        bonusReason: bonusReason,
        deduction: deduction,
        deductionReason: deductionReason,
        advanceDeduction: advanceDeduction,
        paymentMethod: paymentMethod,
        referenceNumber: referenceNumber,
        status: status,
        notes: notes,
        academicYearId: targetYearId,
      );
    });
    return !state.hasError;
  }

  Future<bool> giveSalaryAdvance({
    required int employeeId,
    required double amount,
    required DateTime advanceDate,
    String paymentMethod = 'Cash',
    String? referenceNumber,
    String? reason,
    String? notes,
    int? academicYearId,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(payrollServiceProvider);
      final targetYearId =
          academicYearId ?? ref.read(payrollAcademicYearFilterProvider);
      await service.giveSalaryAdvance(
        employeeId: employeeId,
        amount: amount,
        advanceDate: advanceDate,
        paymentMethod: paymentMethod,
        referenceNumber: referenceNumber,
        reason: reason,
        notes: notes,
        academicYearId: targetYearId,
      );
    });
    return !state.hasError;
  }

  Future<bool> deleteSalaryPayment(int paymentId) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(payrollServiceProvider);
      await service.deleteSalaryPayment(paymentId);
    });
    return !state.hasError;
  }

  Future<bool> deleteSalaryAdvance(int advanceId) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final db = ref.read(databaseProvider);
      await db.deleteSalaryAdvance(advanceId);
    });
    return !state.hasError;
  }
}

final payrollControllerProvider =
    AsyncNotifierProvider<PayrollController, void>(PayrollController.new);
