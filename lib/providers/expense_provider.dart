import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../data/app_database.dart';
import '../services/expense_service.dart';
import 'database_provider.dart';

/// Provider for ExpenseService
final expenseServiceProvider = Provider<ExpenseService>((ref) {
  final db = ref.watch(databaseProvider);
  return ExpenseService(db);
});

/// Filter Notifiers
class ExpensePeriodFilterNotifier extends Notifier<ExpensePeriodType> {
  @override
  ExpensePeriodType build() => ExpensePeriodType.month;

  void setPeriod(ExpensePeriodType type) => state = type;
}

final expensePeriodFilterProvider =
    NotifierProvider<ExpensePeriodFilterNotifier, ExpensePeriodType>(
      ExpensePeriodFilterNotifier.new,
    );

class ExpenseCustomDateRangeNotifier
    extends Notifier<({DateTime? start, DateTime? end})> {
  @override
  ({DateTime? start, DateTime? end}) build() => (start: null, end: null);

  void setRange(DateTime? start, DateTime? end) {
    state = (start: start, end: end);
  }

  void clear() => state = (start: null, end: null);
}

final expenseCustomDateRangeProvider = NotifierProvider<
  ExpenseCustomDateRangeNotifier,
  ({DateTime? start, DateTime? end})
>(ExpenseCustomDateRangeNotifier.new);

class ExpenseCategoryFilterNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void setCategory(int? categoryId) => state = categoryId;
}

final expenseCategoryFilterProvider =
    NotifierProvider<ExpenseCategoryFilterNotifier, int?>(
      ExpenseCategoryFilterNotifier.new,
    );

class ExpenseAcademicYearFilterNotifier extends Notifier<int?> {
  @override
  int? build() => null; // null = all academic years

  void setAcademicYear(int? yearId) => state = yearId;
}

final expenseAcademicYearFilterProvider =
    NotifierProvider<ExpenseAcademicYearFilterNotifier, int?>(
      ExpenseAcademicYearFilterNotifier.new,
    );

class ExpenseSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) => state = query;
}

final expenseSearchQueryProvider =
    NotifierProvider<ExpenseSearchQueryNotifier, String>(
      ExpenseSearchQueryNotifier.new,
    );

/// Stream provider for all expense categories
final expenseCategoriesStreamProvider = StreamProvider<List<ExpenseCategory>>((
  ref,
) {
  final service = ref.watch(expenseServiceProvider);
  return service.watchCategories();
});

/// Active computed date range based on period type & custom range
final activeExpenseDateRangeProvider =
    Provider<({DateTime? start, DateTime? end})>((ref) {
      final period = ref.watch(expensePeriodFilterProvider);
      final custom = ref.watch(expenseCustomDateRangeProvider);
      return ExpenseService.getDateRangeForPeriod(
        period,
        customStart: custom.start,
        customEnd: custom.end,
      );
    });

/// Stream provider for filtered expenses list
final filteredExpensesStreamProvider =
    StreamProvider<List<ExpenseWithCategory>>((ref) {
      final service = ref.watch(expenseServiceProvider);
      final dateRange = ref.watch(activeExpenseDateRangeProvider);
      final categoryId = ref.watch(expenseCategoryFilterProvider);
      final academicYearId = ref.watch(expenseAcademicYearFilterProvider);
      final query = ref.watch(expenseSearchQueryProvider);

      return service.watchExpenses(
        startDate: dateRange.start,
        endDate: dateRange.end,
        categoryId: categoryId,
        academicYearId: academicYearId,
        query: query,
      );
    });

/// Computed report provider for the current filtered view
final expenseReportProvider = Provider<ExpenseReportSummary?>((ref) {
  final expensesAsync = ref.watch(filteredExpensesStreamProvider);
  final period = ref.watch(expensePeriodFilterProvider);
  final dateRange = ref.watch(activeExpenseDateRangeProvider);

  return expensesAsync.when(
    data:
        (expenses) => ExpenseReportSummary.fromExpenses(
          expenses: expenses,
          periodType: period,
          startDate: dateRange.start,
          endDate: dateRange.end,
        ),
    loading: () => null,
    error: (err, stack) => null,
  );
});

/// Controller for mutations (Add, Update, Delete)
class ExpenseController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> createExpense({
    required String title,
    required int categoryId,
    required double amount,
    required DateTime expenseDate,
    String paymentMethod = 'Cash',
    String? referenceNumber,
    String? paidTo,
    String? notes,
    String? receiptPath,
    int? academicYearId,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(expenseServiceProvider);
      final targetYearId =
          academicYearId ?? ref.read(expenseAcademicYearFilterProvider);
      await service.createExpense(
        title: title,
        categoryId: categoryId,
        amount: amount,
        expenseDate: expenseDate,
        paymentMethod: paymentMethod,
        referenceNumber: referenceNumber,
        paidTo: paidTo,
        notes: notes,
        receiptPath: receiptPath,
        academicYearId: targetYearId,
      );
    });
    return !state.hasError;
  }

  Future<bool> updateExpense({
    required int id,
    required String title,
    required int categoryId,
    required double amount,
    required DateTime expenseDate,
    String paymentMethod = 'Cash',
    String? referenceNumber,
    String? paidTo,
    String? notes,
    String? receiptPath,
    int? academicYearId,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(expenseServiceProvider);
      await service.updateExpense(
        id: id,
        title: title,
        categoryId: categoryId,
        amount: amount,
        expenseDate: expenseDate,
        paymentMethod: paymentMethod,
        referenceNumber: referenceNumber,
        paidTo: paidTo,
        notes: notes,
        receiptPath: receiptPath,
        academicYearId: academicYearId,
      );
    });
    return !state.hasError;
  }

  Future<bool> deleteExpense(int id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(expenseServiceProvider);
      await service.deleteExpense(id);
    });
    return !state.hasError;
  }

  Future<bool> createCategory({
    required String name,
    String iconName = 'category',
    int colorValue = 0xFF78909C,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(expenseServiceProvider);
      await service.createCategory(
        name: name,
        iconName: iconName,
        colorValue: colorValue,
      );
    });
    return !state.hasError;
  }

  Future<bool> deleteCategory(int id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(expenseServiceProvider);
      await service.deleteCategory(id);
    });
    return !state.hasError;
  }
}

final expenseControllerProvider =
    AsyncNotifierProvider<ExpenseController, void>(ExpenseController.new);
