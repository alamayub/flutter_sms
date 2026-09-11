import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../data/app_database.dart';
import '../services/fee_service.dart';
import 'database_provider.dart';

/// Provider for FeeService
final feeServiceProvider = Provider<FeeService>((ref) {
  final db = ref.watch(databaseProvider);
  return FeeService(db);
});

/// Selected student for fee ledger and collection (null = school overview)
class SelectedStudentForFeeNotifier extends Notifier<Student?> {
  @override
  Student? build() => null;

  void selectStudent(Student? student) => state = student;
  void clear() => state = null;
}

final selectedStudentForFeeProvider =
    NotifierProvider<SelectedStudentForFeeNotifier, Student?>(
      SelectedStudentForFeeNotifier.new,
    );

/// Fee period filter (Today, Week, Month, Year, All Time, Custom)
class FeePeriodFilterNotifier extends Notifier<FeePeriodType> {
  @override
  FeePeriodType build() => FeePeriodType.allTime;

  void setPeriod(FeePeriodType type) => state = type;
}

final feePeriodFilterProvider =
    NotifierProvider<FeePeriodFilterNotifier, FeePeriodType>(
      FeePeriodFilterNotifier.new,
    );

/// Custom date range filter
class FeeCustomDateRangeNotifier
    extends Notifier<({DateTime? start, DateTime? end})> {
  @override
  ({DateTime? start, DateTime? end}) build() => (start: null, end: null);

  void setRange(DateTime? start, DateTime? end) =>
      state = (start: start, end: end);
  void clear() => state = (start: null, end: null);
}

final feeCustomDateRangeProvider = NotifierProvider<
  FeeCustomDateRangeNotifier,
  ({DateTime? start, DateTime? end})
>(FeeCustomDateRangeNotifier.new);

/// Academic Year filter
class FeeAcademicYearFilterNotifier extends Notifier<int?> {
  @override
  int? build() => null; // null = all academic years

  void setAcademicYear(int? yearId) => state = yearId;
}

final feeAcademicYearFilterProvider =
    NotifierProvider<FeeAcademicYearFilterNotifier, int?>(
      FeeAcademicYearFilterNotifier.new,
    );

/// Fee Status filter ('all', 'pending', 'partial', 'paid')
class FeeStatusFilterNotifier extends Notifier<String> {
  @override
  String build() => 'all';

  void setStatus(String status) => state = status;
}

final feeStatusFilterProvider =
    NotifierProvider<FeeStatusFilterNotifier, String>(
      FeeStatusFilterNotifier.new,
    );

/// Fee Frequency filter ('all', 'one_time', 'monthly', 'term_wise', 'quarterly', 'yearly')
class FeeFrequencyFilterNotifier extends Notifier<String> {
  @override
  String build() => 'all';

  void setFrequency(String freq) => state = freq;
}

final feeFrequencyFilterProvider =
    NotifierProvider<FeeFrequencyFilterNotifier, String>(
      FeeFrequencyFilterNotifier.new,
    );

/// Search query filter
class FeeSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) => state = query;
}

final feeSearchQueryProvider = NotifierProvider<FeeSearchQueryNotifier, String>(
  FeeSearchQueryNotifier.new,
);

/// Stream provider for all fee categories
final feeCategoriesStreamProvider = StreamProvider<List<FeeCategory>>((ref) {
  final service = ref.watch(feeServiceProvider);
  return service.watchFeeCategories();
});

/// Stream provider for student fees
final studentFeesStreamProvider = StreamProvider<List<StudentFeeWithDetails>>((
  ref,
) {
  final service = ref.watch(feeServiceProvider);
  final selectedStudent = ref.watch(selectedStudentForFeeProvider);
  final academicYearId = ref.watch(feeAcademicYearFilterProvider);
  final status = ref.watch(feeStatusFilterProvider);
  final freq = ref.watch(feeFrequencyFilterProvider);
  final query = ref.watch(feeSearchQueryProvider);

  return service.watchStudentFees(
    studentId: selectedStudent?.id,
    academicYearId: academicYearId,
    status: status,
    frequency: freq,
    query: query,
  );
});

/// Stream provider for fee payments transactions
final feePaymentsStreamProvider = StreamProvider<List<FeePaymentWithDetails>>((
  ref,
) {
  final service = ref.watch(feeServiceProvider);
  final selectedStudent = ref.watch(selectedStudentForFeeProvider);
  final academicYearId = ref.watch(feeAcademicYearFilterProvider);
  final query = ref.watch(feeSearchQueryProvider);

  return service.watchFeePayments(
    studentId: selectedStudent?.id,
    academicYearId: academicYearId,
    query: query,
  );
});

/// Future provider for summary statistics across time periods
final feeSummaryStatsProvider = FutureProvider<FeeCollectionSummary>((
  ref,
) async {
  final service = ref.watch(feeServiceProvider);
  final period = ref.watch(feePeriodFilterProvider);
  final academicYearId = ref.watch(feeAcademicYearFilterProvider);
  final selectedStudent = ref.watch(selectedStudentForFeeProvider);
  final customRange = ref.watch(feeCustomDateRangeProvider);

  // Watch fee payments and student fees streams so stats auto-recalculate when new payments/fees are added!
  ref.watch(studentFeesStreamProvider);
  ref.watch(feePaymentsStreamProvider);

  return service.getFeeCollectionSummary(
    academicYearId: academicYearId,
    period: period,
    studentId: selectedStudent?.id,
    customStart: customRange.start,
    customEnd: customRange.end,
  );
});

/// Future provider for financial summary of currently selected student
final selectedStudentFinancialSummaryProvider =
    FutureProvider<StudentFeeFinancialSummary?>((ref) async {
      final student = ref.watch(selectedStudentForFeeProvider);
      if (student == null) return null;

      final service = ref.watch(feeServiceProvider);
      final academicYearId = ref.watch(feeAcademicYearFilterProvider);

      // Re-run when student fees change
      ref.watch(studentFeesStreamProvider);
      ref.watch(feePaymentsStreamProvider);

      return service.getStudentFeeSummary(
        student.id,
        academicYearId: academicYearId,
      );
    });

/// Controller handling async fee collection actions
class FeeController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<FeePayment?> recordPayment({
    required int studentFeeId,
    required double amount,
    required String paymentMethod,
    String? referenceNumber,
    String? remarks,
    String? receivedBy,
    DateTime? paymentDate,
    int? academicYearId,
    double? discountAmount,
    String? discountReason,
  }) async {
    state = const AsyncValue.loading();
    try {
      final service = ref.read(feeServiceProvider);
      final payment = await service.recordFeePayment(
        studentFeeId: studentFeeId,
        amount: amount,
        paymentMethod: paymentMethod,
        referenceNumber: referenceNumber,
        remarks: remarks,
        receivedBy: receivedBy,
        paymentDate: paymentDate,
        academicYearId:
            academicYearId ?? ref.read(feeAcademicYearFilterProvider),
        discountAmount: discountAmount,
        discountReason: discountReason,
      );
      state = const AsyncValue.data(null);
      ref.invalidate(feeSummaryStatsProvider);
      ref.invalidate(selectedStudentFinancialSummaryProvider);
      return payment;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<ConsolidatedFeeReceipt> recordMultiplePayments({
    required int studentId,
    required List<FeePaymentAllocation> allocations,
    required String paymentMethod,
    String? referenceNumber,
    String? remarks,
    String? receivedBy,
    DateTime? paymentDate,
    int? academicYearId,
  }) async {
    state = const AsyncValue.loading();
    try {
      final service = ref.read(feeServiceProvider);
      final receipt = await service.recordMultipleFeePayments(
        studentId: studentId,
        allocations: allocations,
        paymentMethod: paymentMethod,
        referenceNumber: referenceNumber,
        remarks: remarks,
        receivedBy: receivedBy,
        paymentDate: paymentDate,
        academicYearId:
            academicYearId ?? ref.read(feeAcademicYearFilterProvider),
      );
      state = const AsyncValue.data(null);
      ref.invalidate(feeSummaryStatsProvider);
      ref.invalidate(selectedStudentFinancialSummaryProvider);
      return receipt;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<List<int>> assessAdmissionPackage({
    required int studentId,
    required int academicYearId,
    String schoolFeeFrequency = 'monthly',
    double? customAdmissionFee,
    double? customDressFee,
    double? customBookFee,
    double? customSchoolFee,
    double defaultDiscount = 0.0,
    DateTime? dueDate,
  }) async {
    state = const AsyncValue.loading();
    try {
      final service = ref.read(feeServiceProvider);
      final ids = await service.assessAdmissionPackageForStudent(
        studentId: studentId,
        academicYearId: academicYearId,
        schoolFeeFrequency: schoolFeeFrequency,
        customAdmissionFee: customAdmissionFee,
        customDressFee: customDressFee,
        customBookFee: customBookFee,
        customSchoolFee: customSchoolFee,
        defaultDiscount: defaultDiscount,
        dueDate: dueDate,
      );
      state = const AsyncValue.data(null);
      ref.invalidate(feeSummaryStatsProvider);
      ref.invalidate(selectedStudentFinancialSummaryProvider);
      return ids;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> updateDiscount({
    required int studentFeeId,
    required double discountAmount,
    String? reason,
  }) async {
    state = const AsyncValue.loading();
    try {
      final service = ref.read(feeServiceProvider);
      await service.updateFeeDiscount(
        studentFeeId: studentFeeId,
        discountAmount: discountAmount,
        reason: reason,
      );
      state = const AsyncValue.data(null);
      ref.invalidate(feeSummaryStatsProvider);
      ref.invalidate(selectedStudentFinancialSummaryProvider);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<bool> deletePayment(int paymentId) async {
    state = const AsyncValue.loading();
    try {
      final service = ref.read(feeServiceProvider);
      final ok = await service.deleteFeePayment(paymentId);
      state = const AsyncValue.data(null);
      ref.invalidate(feeSummaryStatsProvider);
      ref.invalidate(selectedStudentFinancialSummaryProvider);
      return ok;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<int> assignFee({
    required int studentId,
    required int feeCategoryId,
    required String title,
    required double totalAmount,
    double discountAmount = 0.0,
    DateTime? dueDate,
    int? academicYearId,
    int? academicMonth,
    String? academicTerm,
    String? notes,
  }) async {
    state = const AsyncValue.loading();
    try {
      final service = ref.read(feeServiceProvider);
      final id = await service.assignFeeToStudent(
        studentId: studentId,
        feeCategoryId: feeCategoryId,
        title: title,
        totalAmount: totalAmount,
        discountAmount: discountAmount,
        dueDate: dueDate,
        academicYearId:
            academicYearId ?? ref.read(feeAcademicYearFilterProvider),
        academicMonth: academicMonth,
        academicTerm: academicTerm,
        notes: notes,
      );
      state = const AsyncValue.data(null);
      ref.invalidate(feeSummaryStatsProvider);
      ref.invalidate(selectedStudentFinancialSummaryProvider);
      return id;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<int> bulkAssignFee({
    required int classId,
    int? sectionId,
    required int feeCategoryId,
    required String title,
    required double totalAmount,
    double discountAmount = 0.0,
    DateTime? dueDate,
    int? academicYearId,
    int? academicMonth,
    String? academicTerm,
    String? notes,
  }) async {
    state = const AsyncValue.loading();
    try {
      final service = ref.read(feeServiceProvider);
      final count = await service.bulkAssignFeeToClass(
        classId: classId,
        sectionId: sectionId,
        feeCategoryId: feeCategoryId,
        title: title,
        totalAmount: totalAmount,
        discountAmount: discountAmount,
        dueDate: dueDate,
        academicYearId:
            academicYearId ?? ref.read(feeAcademicYearFilterProvider),
        academicMonth: academicMonth,
        academicTerm: academicTerm,
        notes: notes,
      );
      state = const AsyncValue.data(null);
      ref.invalidate(feeSummaryStatsProvider);
      ref.invalidate(selectedStudentFinancialSummaryProvider);
      return count;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<int> deleteFee(int feeId) async {
    state = const AsyncValue.loading();
    try {
      final service = ref.read(feeServiceProvider);
      final count = await service.deleteStudentFee(feeId);
      state = const AsyncValue.data(null);
      ref.invalidate(feeSummaryStatsProvider);
      ref.invalidate(selectedStudentFinancialSummaryProvider);
      return count;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final feeControllerProvider = NotifierProvider<FeeController, AsyncValue<void>>(
  FeeController.new,
);
