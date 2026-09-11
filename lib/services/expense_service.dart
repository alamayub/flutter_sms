import 'package:drift/drift.dart';
import '../data/app_database.dart';

/// Predefined reporting periods
enum ExpensePeriodType {
  day,
  week,
  month,
  year,
  allTime,
  custom;

  String get label {
    switch (this) {
      case ExpensePeriodType.day:
        return 'Today';
      case ExpensePeriodType.week:
        return 'This Week';
      case ExpensePeriodType.month:
        return 'This Month';
      case ExpensePeriodType.year:
        return 'This Year';
      case ExpensePeriodType.allTime:
        return 'All Time';
      case ExpensePeriodType.custom:
        return 'Custom Range';
    }
  }
}

/// Category-wise expense breakdown item for analytics and reports
class CategoryExpenseBreakdown {
  final int categoryId;
  final String categoryName;
  final String iconName;
  final int colorValue;
  final double totalAmount;
  final int transactionCount;
  final double percentage; // 0.0 to 100.0

  const CategoryExpenseBreakdown({
    required this.categoryId,
    required this.categoryName,
    required this.iconName,
    required this.colorValue,
    required this.totalAmount,
    required this.transactionCount,
    required this.percentage,
  });
}

/// Comprehensive expense report summary for selected period/filter
class ExpenseReportSummary {
  final double totalAmount;
  final int transactionCount;
  final double averageAmount;
  final double maxAmount;
  final List<CategoryExpenseBreakdown> categoryBreakdowns;
  final Map<String, double> paymentMethodBreakdown;
  final DateTime? startDate;
  final DateTime? endDate;
  final ExpensePeriodType periodType;

  const ExpenseReportSummary({
    required this.totalAmount,
    required this.transactionCount,
    required this.averageAmount,
    required this.maxAmount,
    required this.categoryBreakdowns,
    required this.paymentMethodBreakdown,
    this.startDate,
    this.endDate,
    required this.periodType,
  });

  factory ExpenseReportSummary.fromExpenses({
    required List<ExpenseWithCategory> expenses,
    required ExpensePeriodType periodType,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    if (expenses.isEmpty) {
      return ExpenseReportSummary(
        totalAmount: 0.0,
        transactionCount: 0,
        averageAmount: 0.0,
        maxAmount: 0.0,
        categoryBreakdowns: const [],
        paymentMethodBreakdown: const {},
        startDate: startDate,
        endDate: endDate,
        periodType: periodType,
      );
    }

    double total = 0.0;
    double max = 0.0;
    final Map<int, _CategoryAgg> catAggs = {};
    final Map<String, double> paymentAggs = {};

    for (final item in expenses) {
      final amt = item.amount;
      total += amt;
      if (amt > max) max = amt;

      // Group by category
      final catId = item.category.id;
      final existing = catAggs[catId];
      if (existing != null) {
        existing.amount += amt;
        existing.count += 1;
      } else {
        catAggs[catId] = _CategoryAgg(
          category: item.category,
          amount: amt,
          count: 1,
        );
      }

      // Group by payment method
      final method =
          item.paymentMethod.isNotEmpty ? item.paymentMethod : 'Cash';
      paymentAggs[method] = (paymentAggs[method] ?? 0.0) + amt;
    }

    final breakdowns =
        catAggs.values.map((agg) {
            final percentage = total > 0 ? (agg.amount / total) * 100 : 0.0;
            return CategoryExpenseBreakdown(
              categoryId: agg.category.id,
              categoryName: agg.category.name,
              iconName: agg.category.iconName,
              colorValue: agg.category.colorValue,
              totalAmount: agg.amount,
              transactionCount: agg.count,
              percentage: percentage,
            );
          }).toList()
          ..sort(
            (a, b) => b.totalAmount.compareTo(a.totalAmount),
          ); // Highest spend first

    return ExpenseReportSummary(
      totalAmount: total,
      transactionCount: expenses.length,
      averageAmount: expenses.isNotEmpty ? total / expenses.length : 0.0,
      maxAmount: max,
      categoryBreakdowns: breakdowns,
      paymentMethodBreakdown: paymentAggs,
      startDate: startDate,
      endDate: endDate,
      periodType: periodType,
    );
  }
}

class _CategoryAgg {
  final ExpenseCategory category;
  double amount;
  int count;

  _CategoryAgg({
    required this.category,
    required this.amount,
    required this.count,
  });
}

class ExpenseService {
  final AppDatabase _db;

  ExpenseService(this._db);

  // ================= DATE RANGE COMPUTATION =================

  /// Calculates start and end DateTimes for a given period preset
  static ({DateTime? start, DateTime? end}) getDateRangeForPeriod(
    ExpensePeriodType type, {
    DateTime? customStart,
    DateTime? customEnd,
    DateTime? referenceDate,
  }) {
    final now = referenceDate ?? DateTime.now();

    switch (type) {
      case ExpensePeriodType.day:
        final start = DateTime(now.year, now.month, now.day, 0, 0, 0);
        final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
        return (start: start, end: end);

      case ExpensePeriodType.week:
        // Sunday is start of week in Nepal (in Dart: Mon=1, Sun=7)
        final daysFromSunday = now.weekday == 7 ? 0 : now.weekday;
        final startDay = now.subtract(Duration(days: daysFromSunday));
        final start = DateTime(
          startDay.year,
          startDay.month,
          startDay.day,
          0,
          0,
          0,
        );
        final endDay = start.add(const Duration(days: 6));
        final end = DateTime(
          endDay.year,
          endDay.month,
          endDay.day,
          23,
          59,
          59,
          999,
        );
        return (start: start, end: end);

      case ExpensePeriodType.month:
        final start = DateTime(now.year, now.month, 1, 0, 0, 0);
        // Day 0 of next month is last day of current month
        final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);
        final end = DateTime(
          now.year,
          now.month,
          lastDayOfMonth.day,
          23,
          59,
          59,
          999,
        );
        return (start: start, end: end);

      case ExpensePeriodType.year:
        final start = DateTime(now.year, 1, 1, 0, 0, 0);
        final end = DateTime(now.year, 12, 31, 23, 59, 59, 999);
        return (start: start, end: end);

      case ExpensePeriodType.allTime:
        return (start: null, end: null);

      case ExpensePeriodType.custom:
        final start =
            customStart != null
                ? DateTime(
                  customStart.year,
                  customStart.month,
                  customStart.day,
                  0,
                  0,
                  0,
                )
                : null;
        final end =
            customEnd != null
                ? DateTime(
                  customEnd.year,
                  customEnd.month,
                  customEnd.day,
                  23,
                  59,
                  59,
                  999,
                )
                : null;
        return (start: start, end: end);
    }
  }

  // ================= EXPENSES CRUD =================

  Stream<List<ExpenseWithCategory>> watchExpenses({
    DateTime? startDate,
    DateTime? endDate,
    int? categoryId,
    String? query,
    int? academicYearId,
  }) {
    return _db.watchExpensesWithCategory(
      startDate: startDate,
      endDate: endDate,
      categoryId: categoryId,
      query: query,
      academicYearId: academicYearId,
    );
  }

  Future<List<ExpenseWithCategory>> getExpenses({
    DateTime? startDate,
    DateTime? endDate,
    int? categoryId,
    String? query,
    int? academicYearId,
  }) {
    return _db.getExpensesWithCategory(
      startDate: startDate,
      endDate: endDate,
      categoryId: categoryId,
      query: query,
      academicYearId: academicYearId,
    );
  }

  Future<ExpenseWithCategory?> getExpenseById(int id) async {
    final expense = await _db.getExpenseById(id);
    if (expense == null) return null;
    final category = await _db.getExpenseCategoryById(expense.categoryId);
    if (category == null) return null;
    final year =
        expense.academicYearId != null
            ? await _db.getAcademicYearById(expense.academicYearId!)
            : null;
    return ExpenseWithCategory(
      expense: expense,
      category: category,
      academicYear: year,
    );
  }

  Future<int> createExpense({
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
    if (title.trim().isEmpty) {
      throw ArgumentError('Expense title cannot be empty');
    }
    if (amount <= 0) {
      throw ArgumentError('Expense amount must be greater than 0');
    }

    int? resolvedYearId = academicYearId;
    if (resolvedYearId == null) {
      final years = await _db.getAllAcademicYears();
      if (years.isNotEmpty) {
        resolvedYearId =
            years.firstWhere((y) => y.isCurrent, orElse: () => years.first).id;
      }
    }

    final now = DateTime.now();
    return await _db.insertExpense(
      ExpensesCompanion(
        title: Value(title.trim()),
        categoryId: Value(categoryId),
        amount: Value(amount),
        expenseDate: Value(expenseDate),
        paymentMethod: Value(paymentMethod),
        referenceNumber: Value(referenceNumber?.trim()),
        paidTo: Value(paidTo?.trim()),
        notes: Value(notes?.trim()),
        receiptPath: Value(receiptPath?.trim()),
        academicYearId: Value(resolvedYearId),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );
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
    if (title.trim().isEmpty) {
      throw ArgumentError('Expense title cannot be empty');
    }
    if (amount <= 0) {
      throw ArgumentError('Expense amount must be greater than 0');
    }

    final existing = await _db.getExpenseById(id);
    if (existing == null) {
      throw StateError('Expense not found with ID $id');
    }

    final updated = existing.copyWith(
      title: title.trim(),
      categoryId: categoryId,
      amount: amount,
      expenseDate: expenseDate,
      paymentMethod: paymentMethod,
      referenceNumber: Value(referenceNumber?.trim()),
      paidTo: Value(paidTo?.trim()),
      notes: Value(notes?.trim()),
      receiptPath: Value(receiptPath?.trim()),
      academicYearId: Value(academicYearId),
      updatedAt: DateTime.now(),
    );

    return await _db.updateExpenseEntry(updated);
  }

  Future<int> deleteExpense(int id) async {
    return await _db.deleteExpense(id);
  }

  // ================= EXPENSE CATEGORIES CRUD =================

  Stream<List<ExpenseCategory>> watchCategories() {
    return _db.watchAllExpenseCategories();
  }

  Future<List<ExpenseCategory>> getCategories() {
    return _db.getAllExpenseCategories();
  }

  Future<int> createCategory({
    required String name,
    String iconName = 'category',
    int colorValue = 0xFF78909C,
    bool isSystem = false,
  }) async {
    if (name.trim().isEmpty) {
      throw ArgumentError('Category name cannot be empty');
    }

    return await _db.insertExpenseCategory(
      ExpenseCategoriesCompanion(
        name: Value(name.trim()),
        iconName: Value(iconName),
        colorValue: Value(colorValue),
        isSystem: Value(isSystem),
      ),
    );
  }

  Future<bool> updateCategory(ExpenseCategory category) async {
    return await _db.updateExpenseCategory(category);
  }

  Future<int> deleteCategory(int id) async {
    final cat = await _db.getExpenseCategoryById(id);
    if (cat != null && cat.isSystem) {
      throw StateError('System predefined categories cannot be deleted');
    }
    return await _db.deleteExpenseCategory(id);
  }

  // ================= REPORT AGGREGATION =================

  /// Computes expense report summary for a given period
  Future<ExpenseReportSummary> generateReport({
    ExpensePeriodType periodType = ExpensePeriodType.month,
    DateTime? customStart,
    DateTime? customEnd,
    int? categoryId,
    int? academicYearId,
  }) async {
    final range = getDateRangeForPeriod(
      periodType,
      customStart: customStart,
      customEnd: customEnd,
    );

    final expenses = await _db.getExpensesWithCategory(
      startDate: range.start,
      endDate: range.end,
      categoryId: categoryId,
      academicYearId: academicYearId,
    );

    return ExpenseReportSummary.fromExpenses(
      expenses: expenses,
      periodType: periodType,
      startDate: range.start,
      endDate: range.end,
    );
  }
}
