// lib/features/finance/data/daily_closing_repository.dart
import 'package:drift/drift.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_service.dart';
import '../../../core/utils/uuid_generator.dart';
import '../../audit/data/audit_repository.dart';
import '../../sync/client/sync_engine.dart';
import '../../sync/presentation/sync_controller.dart';
import '../domain/finance_models.dart';

final dailyClosingRepositoryProvider = Provider<DailyClosingRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final audit = ref.watch(auditRepositoryProvider);
  final syncEngine = ref.watch(syncEngineProvider);
  return DailyClosingRepository(db, audit, syncEngine);
});

class DailyClosingRepository {
  final AppDatabase _db;
  final AuditRepository _audit;
  final SyncEngine? _syncEngine;

  DailyClosingRepository(this._db, this._audit, [this._syncEngine]);

  /// Calculates expected cash in till for a given date.
  /// Formula: Cash fee collections + Cash other income - Approved cash expenses.
  Future<int> calculateExpectedCash(String schoolId, DateTime date) async {
    final start = DateTime(date.year, date.month, date.day, 0, 0, 0);
    final end = DateTime(date.year, date.month, date.day, 23, 59, 59);

    // 1. Cash fee collections
    final payments = await (_db.select(_db.feePayments)
          ..where(
            (t) =>
                t.schoolId.equals(schoolId) &
                t.paymentMethod.equals(PaymentMethod.cash.name) &
                t.paymentDate.isBiggerOrEqualValue(start) &
                t.paymentDate.isSmallerOrEqualValue(end) &
                t.isReversed.equals(false),
          ))
        .get();
    final cashPaymentsCents =
        payments.fold<int>(0, (sum, p) => sum + p.amountCents);

    // 2. Other cash income
    final incomes = await (_db.select(_db.schoolIncomes)
          ..where(
            (t) =>
                t.schoolId.equals(schoolId) &
                t.paymentMethod.equals(PaymentMethod.cash.name) &
                t.date.isBiggerOrEqualValue(start) &
                t.date.isSmallerOrEqualValue(end),
          ))
        .get();
    final cashIncomesCents =
        incomes.fold<int>(0, (sum, i) => sum + i.amountCents);

    // 3. Cash expenses paid out
    final expenses = await (_db.select(_db.schoolExpenses)
          ..where(
            (t) =>
                t.schoolId.equals(schoolId) &
                t.paymentMethod.equals(PaymentMethod.cash.name) &
                t.date.isBiggerOrEqualValue(start) &
                t.date.isSmallerOrEqualValue(end) &
                t.isApproved.equals(true) &
                t.isReversed.equals(false),
          ))
        .get();
    final cashExpensesCents =
        expenses.fold<int>(0, (sum, e) => sum + e.amountCents);

    return cashPaymentsCents + cashIncomesCents - cashExpensesCents;
  }

  /// Records daily till closing with discrepancy checking.
  Future<DailyClosing> recordDailyClosing({
    required String schoolId,
    required DateTime closingDate,
    required String closedBy,
    required String deviceId,
    required int actualCashCents,
    String? reason,
    String? notes,
  }) async {
    final expectedCashCents = await calculateExpectedCash(schoolId, closingDate);
    final differenceCents = actualCashCents - expectedCashCents;

    if (differenceCents != 0 && (reason == null || reason.trim().isEmpty)) {
      throw ArgumentError(
        'A reason is mandatory whenever there is a cash difference ($differenceCents cents)',
      );
    }

    final id = UuidGenerator.v4();
    final now = DateTime.now();

    final companion = DailyClosingsCompanion.insert(
      id: id,
      schoolId: schoolId,
      closingDate: closingDate,
      closedBy: closedBy,
      deviceId: deviceId,
      expectedCashCents: expectedCashCents,
      actualCashCents: actualCashCents,
      differenceCents: differenceCents,
      reason: Value(reason),
      notes: Value(notes),
      closedAt: now,
      createdAt: now,
    );

    await _db.into(_db.dailyClosings).insert(companion);

    final payload = {
      'id': id,
      'schoolId': schoolId,
      'closingDate': closingDate.toIso8601String(),
      'closedBy': closedBy,
      'deviceId': deviceId,
      'expectedCashCents': expectedCashCents,
      'actualCashCents': actualCashCents,
      'differenceCents': differenceCents,
      'reason': reason,
      'notes': notes,
      'closedAt': now.toIso8601String(),
      'createdAt': now.toIso8601String(),
    };

    await _syncEngine?.enqueue(
      schoolId: schoolId,
      userId: closedBy,
      entityType: SyncEntityType.dailyClosing,
      entityId: id,
      operation: SyncOperation.create,
      payload: payload,
    );

    await _audit.log(
      action: AuditAction.dailyClosingCompleted,
      entityType: 'DailyClosing',
      entityId: id,
      schoolId: schoolId,
      userId: closedBy,
      metadata: {
        'expectedCents': expectedCashCents,
        'actualCents': actualCashCents,
        'differenceCents': differenceCents,
        'reason': reason,
      },
    );

    return (_db.select(_db.dailyClosings)..where((t) => t.id.equals(id)))
        .getSingle();
  }

  Future<List<DailyClosing>> getDailyClosings(
    String schoolId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final query = _db.select(_db.dailyClosings)
      ..where((t) => t.schoolId.equals(schoolId));

    if (startDate != null) {
      query.where((t) => t.closingDate.isBiggerOrEqualValue(startDate));
    }
    if (endDate != null) {
      query.where((t) => t.closingDate.isSmallerOrEqualValue(endDate));
    }

    query.orderBy([(t) => OrderingTerm.desc(t.closingDate)]);
    return query.get();
  }
}
