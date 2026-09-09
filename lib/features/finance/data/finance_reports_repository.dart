// lib/features/finance/data/finance_reports_repository.dart
import 'dart:math';
import 'package:drift/drift.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_service.dart';
import '../domain/finance_models.dart';
import '../domain/money.dart';

final financeReportsRepositoryProvider =
    Provider<FinanceReportsRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return FinanceReportsRepository(db);
});

class FinanceReportsRepository {
  final AppDatabase _db;

  FinanceReportsRepository(this._db);

  /// Generates an immutable, date-ordered student financial ledger statement.
  Future<List<StudentLedgerEntry>> getStudentLedger(
    String schoolId,
    String studentId,
  ) async {
    final rawEntries = <_RawLedgerEvent>[];

    // 1. Fee Invoices
    final fees = await (_db.select(_db.studentFees)
          ..where(
            (t) => t.schoolId.equals(schoolId) & t.studentId.equals(studentId),
          ))
        .get();

    for (final fee in fees) {
      // Debit: Invoiced Net Amount
      rawEntries.add(
        _RawLedgerEvent(
          date: fee.createdAt,
          type: LedgerEntryType.invoice,
          referenceId: fee.id,
          description: fee.title,
          debitCents: fee.netAmountCents,
          creditCents: 0,
        ),
      );

      // If waived, credit the waived remaining
      if (fee.isWaived) {
        rawEntries.add(
          _RawLedgerEvent(
            date: fee.updatedAt,
            type: LedgerEntryType.waiver,
            referenceId: fee.id,
            description: 'Fee Waived: ${fee.waiveReason ?? ''}',
            debitCents: 0,
            creditCents: fee.netAmountCents - fee.paidAmountCents,
          ),
        );
      }
    }

    // 2. Payments
    final payments = await (_db.select(_db.feePayments)
          ..where(
            (t) => t.schoolId.equals(schoolId) & t.studentId.equals(studentId),
          ))
        .get();

    for (final payment in payments) {
      // Credit: Payment received
      rawEntries.add(
        _RawLedgerEvent(
          date: payment.paymentDate,
          type: LedgerEntryType.payment,
          referenceId: payment.receiptNumber,
          description:
              'Payment: ${PaymentMethod.fromString(payment.paymentMethod).displayName}'
              '${payment.reference != null ? " (${payment.reference})" : ""}',
          debitCents: 0,
          creditCents: payment.amountCents,
        ),
      );

      // If reversed, debit the payment amount back
      if (payment.isReversed && payment.reversedAt != null) {
        rawEntries.add(
          _RawLedgerEvent(
            date: payment.reversedAt!,
            type: LedgerEntryType.reversal,
            referenceId: payment.receiptNumber,
            description:
                'Payment Reversed: ${payment.reversalReason ?? "Correction"}',
            debitCents: payment.amountCents,
            creditCents: 0,
          ),
        );
      }
    }

    // Sort events strictly by timestamp ascending
    rawEntries.sort((a, b) => a.date.compareTo(b.date));

    // Calculate running balance
    int runningCents = 0;
    final ledger = <StudentLedgerEntry>[];

    for (final e in rawEntries) {
      runningCents += e.debitCents;
      runningCents -= e.creditCents;

      ledger.add(
        StudentLedgerEntry(
          date: e.date,
          type: e.type,
          referenceId: e.referenceId,
          description: e.description,
          debit: Money(e.debitCents),
          credit: Money(e.creditCents),
          runningBalance: Money(runningCents),
        ),
      );
    }

    return ledger;
  }

  /// Aggregates outstanding fees by student with filters.
  Future<Map<String, dynamic>> getOutstandingSummary(
    String schoolId, {
    String? academicYearId,
    String? classId,
    String? sectionId,
  }) async {
    final query = _db.select(_db.studentFees).join([
      innerJoin(_db.students, _db.students.id.equalsExp(_db.studentFees.studentId)),
      innerJoin(_db.schoolClasses, _db.schoolClasses.id.equalsExp(_db.studentFees.classId)),
      leftOuterJoin(_db.sections, _db.sections.id.equalsExp(_db.studentFees.sectionId)),
    ])
      ..where(
        _db.studentFees.schoolId.equals(schoolId) &
            _db.studentFees.isWaived.equals(false),
      );

    if (academicYearId != null) {
      query.where(_db.studentFees.academicYearId.equals(academicYearId));
    }
    if (classId != null) {
      query.where(_db.studentFees.classId.equals(classId));
    }
    if (sectionId != null) {
      query.where(_db.studentFees.sectionId.equals(sectionId));
    }

    final rows = await query.get();

    int totalInvoicedCents = 0;
    int totalDiscountCents = 0;
    int totalPaidCents = 0;
    int totalRemainingCents = 0;
    int overdueCount = 0;
    int overdueCents = 0;

    final studentMap = <String, Map<String, dynamic>>{};
    final now = DateTime.now();

    for (final row in rows) {
      final fee = row.readTable(_db.studentFees);
      final student = row.readTable(_db.students);
      final sClass = row.readTable(_db.schoolClasses);
      final section = row.readTableOrNull(_db.sections);

      totalInvoicedCents += fee.dueAmountCents;
      totalDiscountCents += fee.discountAmountCents;
      totalPaidCents += fee.paidAmountCents;
      totalRemainingCents += fee.remainingAmountCents;

      final isOverdue =
          fee.remainingAmountCents > 0 && fee.dueDate.isBefore(now);
      if (isOverdue) {
        overdueCount++;
        overdueCents += fee.remainingAmountCents;
      }

      if (!studentMap.containsKey(student.id)) {
        studentMap[student.id] = {
          'studentId': student.id,
          'studentName': '${student.firstName} ${student.lastName}',
          // 'admissionNumber': student.admissionNumber,
          'className': sClass.name,
          'sectionName': section?.name ?? '',
          'totalDueCents': 0,
          'totalDiscountCents': 0,
          'totalPaidCents': 0,
          'remainingCents': 0,
          'overdueCents': 0,
          'feeCount': 0,
        };
      }

      final record = studentMap[student.id]!;
      record['totalDueCents'] =
          (record['totalDueCents'] as int) + fee.dueAmountCents;
      record['totalDiscountCents'] =
          (record['totalDiscountCents'] as int) + fee.discountAmountCents;
      record['totalPaidCents'] =
          (record['totalPaidCents'] as int) + fee.paidAmountCents;
      record['remainingCents'] =
          (record['remainingCents'] as int) + fee.remainingAmountCents;
      if (isOverdue) {
        record['overdueCents'] =
            (record['overdueCents'] as int) + fee.remainingAmountCents;
      }
      record['feeCount'] = (record['feeCount'] as int) + 1;
    }

    final studentSummaries = studentMap.values
        .where((s) => (s['remainingCents'] as int) > 0)
        .toList();
    studentSummaries.sort(
      (a, b) => (b['remainingCents'] as int).compareTo(a['remainingCents'] as int),
    );

    return {
      'totalInvoicedCents': totalInvoicedCents,
      'totalDiscountCents': totalDiscountCents,
      'totalPaidCents': totalPaidCents,
      'totalRemainingCents': totalRemainingCents,
      'overdueCount': overdueCount,
      'overdueCents': overdueCents,
      'students': studentSummaries,
    };
  }

  /// Generates KPI summary for the finance dashboard.
  Future<Map<String, dynamic>> getFinanceDashboardKpis(
    String schoolId, {
    DateTime? today,
  }) async {
    final now = today ?? DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day, 0, 0, 0);
    final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59);

    final startOfMonth = DateTime(now.year, now.month, 1, 0, 0, 0);
    final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    final startOfYear = DateTime(now.year, 1, 1, 0, 0, 0);
    final endOfYear = DateTime(now.year, 12, 31, 23, 59, 59);

    final allPayments = await (_db.select(_db.feePayments)
          ..where((t) => t.schoolId.equals(schoolId) & t.isReversed.equals(false)))
        .get();

    int todayCollectionCents = 0;
    int monthCollectionCents = 0;
    int yearCollectionCents = 0;
    int todayCashCents = 0;
    int todayBankCents = 0;

    for (final p in allPayments) {
      final date = p.paymentDate;
      if (date.isAfter(startOfToday) && date.isBefore(endOfToday)) {
        todayCollectionCents += p.amountCents;
        if (p.paymentMethod == PaymentMethod.cash.name) {
          todayCashCents += p.amountCents;
        } else {
          todayBankCents += p.amountCents;
        }
      }
      if (date.isAfter(startOfMonth) && date.isBefore(endOfMonth)) {
        monthCollectionCents += p.amountCents;
      }
      if (date.isAfter(startOfYear) && date.isBefore(endOfYear)) {
        yearCollectionCents += p.amountCents;
      }
    }

    // Outstanding Dues
    final dues = await (_db.select(_db.studentFees)
          ..where(
            (t) =>
                t.schoolId.equals(schoolId) &
                t.isWaived.equals(false) &
                t.remainingAmountCents.isBiggerThanValue(0),
          ))
        .get();

    int totalOutstandingCents = 0;
    int totalOverdueCents = 0;
    int overdueInvoicesCount = 0;

    for (final d in dues) {
      totalOutstandingCents += d.remainingAmountCents;
      if (d.dueDate.isBefore(now)) {
        totalOverdueCents += d.remainingAmountCents;
        overdueInvoicesCount++;
      }
    }

    // Monthly Expenses
    final expenses = await (_db.select(_db.schoolExpenses)
          ..where(
            (t) =>
                t.schoolId.equals(schoolId) &
                t.isApproved.equals(true) &
                t.isReversed.equals(false) &
                t.date.isBiggerOrEqualValue(startOfMonth) &
                t.date.isSmallerOrEqualValue(endOfMonth),
          ))
        .get();

    final monthExpensesCents =
        expenses.fold<int>(0, (sum, e) => sum + e.amountCents);

    return {
      'todayCollectionCents': todayCollectionCents,
      'todayCashCents': todayCashCents,
      'todayBankCents': todayBankCents,
      'monthCollectionCents': monthCollectionCents,
      'yearCollectionCents': yearCollectionCents,
      'totalOutstandingCents': totalOutstandingCents,
      'totalOverdueCents': totalOverdueCents,
      'overdueInvoicesCount': overdueInvoicesCount,
      'monthExpensesCents': monthExpensesCents,
      'netMonthProfitCents': monthCollectionCents - monthExpensesCents,
    };
  }
}

class _RawLedgerEvent {
  final DateTime date;
  final LedgerEntryType type;
  final String referenceId;
  final String description;
  final int debitCents;
  final int creditCents;

  const _RawLedgerEvent({
    required this.date,
    required this.type,
    required this.referenceId,
    required this.description,
    required this.debitCents,
    required this.creditCents,
  });
}
