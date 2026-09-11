import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sms/data/app_database.dart';
import 'package:sms/data/database_seeder.dart';
import 'package:sms/services/expense_service.dart';

void main() {
  late AppDatabase db;
  late ExpenseService service;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    service = ExpenseService(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('Expense Categories Tests', () {
    test('Can seed default expense categories', () async {
      await DatabaseSeeder.seedExpenseCategories(db);
      final categories = await service.getCategories();

      expect(categories.length, greaterThanOrEqualTo(8));
      final names = categories.map((c) => c.name).toSet();
      expect(names.contains('Room Rent'), isTrue);
      expect(names.contains('Travel'), isTrue);
      expect(names.contains('Breakfast'), isTrue);
      expect(names.contains('Lunch'), isTrue);
      expect(names.contains('Dinner'), isTrue);
      expect(names.contains('Miscellaneous'), isTrue);
      expect(names.contains('Utilities & Bills'), isTrue);
      expect(names.contains('Stationery & Supplies'), isTrue);
    });

    test(
      'Can create custom category and prevent deleting system categories',
      () async {
        await DatabaseSeeder.seedExpenseCategories(db);

        // Create custom category
        final customId = await service.createCategory(
          name: 'Science Lab Equipment',
          iconName: 'science',
          colorValue: 0xFF9C27B0,
        );
        expect(customId, greaterThan(0));

        final allCats = await service.getCategories();
        final labCat = allCats.firstWhere((c) => c.id == customId);
        expect(labCat.name, 'Science Lab Equipment');
        expect(labCat.isSystem, isFalse);

        // Attempting to delete system category should throw StateError
        final roomRent = allCats.firstWhere((c) => c.name == 'Room Rent');
        expect(
          () => service.deleteCategory(roomRent.id),
          throwsA(isA<StateError>()),
        );

        // Custom category can be deleted
        final deletedCount = await service.deleteCategory(customId);
        expect(deletedCount, 1);
      },
    );
  });

  group('Expense CRUD & Validation Tests', () {
    test('Can create, retrieve, update, and delete an expense', () async {
      await DatabaseSeeder.seedExpenseCategories(db);
      final categories = await service.getCategories();
      final roomRent = categories.firstWhere((c) => c.name == 'Room Rent');

      // Create
      final now = DateTime.now();
      final expId = await service.createExpense(
        title: 'Building Rent Baishakh',
        categoryId: roomRent.id,
        amount: 85000.0,
        expenseDate: now,
        paymentMethod: 'Bank Transfer',
        referenceNumber: 'VOUCHER-001',
        paidTo: 'Landlord Ram Shrestha',
        notes: 'Monthly premises rental',
      );
      expect(expId, greaterThan(0));

      // Retrieve
      final item = await service.getExpenseById(expId);
      expect(item, isNotNull);
      expect(item!.title, 'Building Rent Baishakh');
      expect(item.amount, 85000.0);
      expect(item.categoryName, 'Room Rent');
      expect(item.paymentMethod, 'Bank Transfer');
      expect(item.paidTo, 'Landlord Ram Shrestha');

      // Update
      final updated = await service.updateExpense(
        id: expId,
        title: 'Building Rent Baishakh (Updated)',
        categoryId: roomRent.id,
        amount: 90000.0,
        expenseDate: now,
        paymentMethod: 'Cheque',
        referenceNumber: 'CHQ-12345',
        paidTo: 'Landlord Ram Shrestha',
      );
      expect(updated, isTrue);

      final updatedItem = await service.getExpenseById(expId);
      expect(updatedItem!.title, 'Building Rent Baishakh (Updated)');
      expect(updatedItem.amount, 90000.0);
      expect(updatedItem.paymentMethod, 'Cheque');

      // Delete
      final deleted = await service.deleteExpense(expId);
      expect(deleted, 1);

      final afterDelete = await service.getExpenseById(expId);
      expect(afterDelete, isNull);
    });

    test('Validates non-empty title and positive amount', () async {
      await DatabaseSeeder.seedExpenseCategories(db);
      final categories = await service.getCategories();
      final cat = categories.first;

      expect(
        () => service.createExpense(
          title: '   ',
          categoryId: cat.id,
          amount: 500.0,
          expenseDate: DateTime.now(),
        ),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => service.createExpense(
          title: 'Valid Title',
          categoryId: cat.id,
          amount: 0.0,
          expenseDate: DateTime.now(),
        ),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => service.createExpense(
          title: 'Valid Title',
          categoryId: cat.id,
          amount: -150.0,
          expenseDate: DateTime.now(),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('Date Range Filtering & Reporting Breakdown Tests', () {
    test('Calculates period date ranges correctly', () {
      final refDate = DateTime(2026, 5, 15, 14, 30); // Friday May 15, 2026

      // Day
      final dayRange = ExpenseService.getDateRangeForPeriod(
        ExpensePeriodType.day,
        referenceDate: refDate,
      );
      expect(dayRange.start, DateTime(2026, 5, 15, 0, 0, 0));
      expect(dayRange.end, DateTime(2026, 5, 15, 23, 59, 59, 999));

      // Month
      final monthRange = ExpenseService.getDateRangeForPeriod(
        ExpensePeriodType.month,
        referenceDate: refDate,
      );
      expect(monthRange.start, DateTime(2026, 5, 1, 0, 0, 0));
      expect(monthRange.end, DateTime(2026, 5, 31, 23, 59, 59, 999));

      // Year
      final yearRange = ExpenseService.getDateRangeForPeriod(
        ExpensePeriodType.year,
        referenceDate: refDate,
      );
      expect(yearRange.start, DateTime(2026, 1, 1, 0, 0, 0));
      expect(yearRange.end, DateTime(2026, 12, 31, 23, 59, 59, 999));

      // All time
      final allTimeRange = ExpenseService.getDateRangeForPeriod(
        ExpensePeriodType.allTime,
        referenceDate: refDate,
      );
      expect(allTimeRange.start, isNull);
      expect(allTimeRange.end, isNull);
    });

    test(
      'Generates comprehensive expense report with category and payment breakdown',
      () async {
        await DatabaseSeeder.seedExpenseCategories(db);
        final categories = await service.getCategories();
        final catMap = {for (final c in categories) c.name: c.id};

        final now = DateTime.now();

        // Clear any pre-seeded expenses for isolated breakdown test
        await db.delete(db.expenses).go();

        // Insert 3 expenses:
        // 1. Breakfast: 1,000 (Cash)
        await service.createExpense(
          title: 'Morning Breakfast',
          categoryId: catMap['Breakfast']!,
          amount: 1000.0,
          expenseDate: now,
          paymentMethod: 'Cash',
        );

        // 2. Lunch: 3,000 (eSewa)
        await service.createExpense(
          title: 'Staff Lunch',
          categoryId: catMap['Lunch']!,
          amount: 3000.0,
          expenseDate: now,
          paymentMethod: 'eSewa',
        );

        // 3. Travel: 6,000 (Bank Transfer)
        await service.createExpense(
          title: 'Field Trip Bus Fuel',
          categoryId: catMap['Travel']!,
          amount: 6000.0,
          expenseDate: now,
          paymentMethod: 'Bank Transfer',
        );

        // Total = 10,000
        final report = await service.generateReport(
          periodType: ExpensePeriodType.allTime,
        );

        expect(report.totalAmount, 10000.0);
        expect(report.transactionCount, 3);
        expect(report.averageAmount, closeTo(3333.33, 0.01));
        expect(report.maxAmount, 6000.0);

        // Category breakdown checks
        expect(report.categoryBreakdowns.length, 3);
        // Sorted highest first: Travel (6000, 60%), Lunch (3000, 30%), Breakfast (1000, 10%)
        expect(report.categoryBreakdowns[0].categoryName, 'Travel');
        expect(report.categoryBreakdowns[0].totalAmount, 6000.0);
        expect(report.categoryBreakdowns[0].percentage, 60.0);

        expect(report.categoryBreakdowns[1].categoryName, 'Lunch');
        expect(report.categoryBreakdowns[1].totalAmount, 3000.0);
        expect(report.categoryBreakdowns[1].percentage, 30.0);

        expect(report.categoryBreakdowns[2].categoryName, 'Breakfast');
        expect(report.categoryBreakdowns[2].totalAmount, 1000.0);
        expect(report.categoryBreakdowns[2].percentage, 10.0);

        // Sum of percentages equals 100%
        final totalPct = report.categoryBreakdowns.fold<double>(
          0.0,
          (sum, b) => sum + b.percentage,
        );
        expect(totalPct, closeTo(100.0, 0.001));

        // Payment method breakdown checks
        expect(report.paymentMethodBreakdown['Cash'], 1000.0);
        expect(report.paymentMethodBreakdown['eSewa'], 3000.0);
        expect(report.paymentMethodBreakdown['Bank Transfer'], 6000.0);
      },
    );

    test('Seeded expenses populate reports across periods', () async {
      await DatabaseSeeder.seedAcademicYears(db);
      await DatabaseSeeder.seedExpenseCategories(db);
      await DatabaseSeeder.seedExpenses(db);

      final allExpenses = await service.getExpenses();
      expect(allExpenses.length, greaterThanOrEqualTo(10));

      final allTimeReport = await service.generateReport(
        periodType: ExpensePeriodType.allTime,
      );
      expect(allTimeReport.totalAmount, greaterThan(100000.0));
      expect(allTimeReport.categoryBreakdowns.isNotEmpty, isTrue);

      // Check day report (should have today's morning tea and lunch)
      final dayReport = await service.generateReport(
        periodType: ExpensePeriodType.day,
      );
      expect(dayReport.transactionCount, greaterThanOrEqualTo(2));
    });
  });

  group('Expense & Academic Year Integration Tests', () {
    test(
      'Automatically assigns active academic year when none provided',
      () async {
        await DatabaseSeeder.seedAcademicYears(db);
        await DatabaseSeeder.seedExpenseCategories(db);
        final categories = await service.getCategories();

        final expId = await service.createExpense(
          title: 'Science Lab Test Tubes',
          categoryId: categories.first.id,
          amount: 2500.0,
          expenseDate: DateTime.now(),
        );

        final created = await service.getExpenseById(expId);
        expect(created, isNotNull);
        expect(created!.expense.academicYearId, isNotNull);

        final activeYears =
            (await db.getAllAcademicYears()).where((y) => y.isCurrent).toList();
        expect(created.expense.academicYearId, equals(activeYears.first.id));
        expect(created.academicYear, isNotNull);
        expect(created.academicYear!.isCurrent, isTrue);
      },
    );

    test('Can filter expenses and generate reports by academic year', () async {
      await DatabaseSeeder.seedAcademicYears(db);
      await DatabaseSeeder.seedExpenseCategories(db);
      final categories = await service.getCategories();
      final allYears = await db.getAllAcademicYears();
      final year1 = allYears[0];
      final year2 = allYears[1];

      // Create expense in Year 1
      await service.createExpense(
        title: 'Year 1 Expense',
        categoryId: categories.first.id,
        amount: 5000.0,
        expenseDate: DateTime.now(),
        academicYearId: year1.id,
      );

      // Create expense in Year 2
      await service.createExpense(
        title: 'Year 2 Expense',
        categoryId: categories.first.id,
        amount: 8000.0,
        expenseDate: DateTime.now(),
        academicYearId: year2.id,
      );

      // Filter by Year 1
      final year1Expenses = await service.getExpenses(academicYearId: year1.id);
      expect(year1Expenses.length, equals(1));
      expect(year1Expenses.first.title, equals('Year 1 Expense'));
      expect(year1Expenses.first.amount, equals(5000.0));

      // Filter by Year 2
      final year2Expenses = await service.getExpenses(academicYearId: year2.id);
      expect(year2Expenses.length, equals(1));
      expect(year2Expenses.first.title, equals('Year 2 Expense'));
      expect(year2Expenses.first.amount, equals(8000.0));

      // Report for Year 1
      final reportYear1 = await service.generateReport(
        periodType: ExpensePeriodType.allTime,
        academicYearId: year1.id,
      );
      expect(reportYear1.totalAmount, equals(5000.0));
      expect(reportYear1.transactionCount, equals(1));

      // Report for Year 2
      final reportYear2 = await service.generateReport(
        periodType: ExpensePeriodType.allTime,
        academicYearId: year2.id,
      );
      expect(reportYear2.totalAmount, equals(8000.0));
      expect(reportYear2.transactionCount, equals(1));
    });
  });
}
