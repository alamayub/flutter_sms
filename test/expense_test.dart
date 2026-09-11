import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sms/data/app_database.dart';
import 'package:sms/services/expense_service.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
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
  });
}
