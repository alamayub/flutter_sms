// lib/features/finance/data/expenses_repository.dart
import 'package:drift/drift.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_service.dart';
import '../../../core/utils/uuid_generator.dart';
import '../../audit/data/audit_repository.dart';
import '../../sync/client/sync_engine.dart';
import '../../sync/presentation/sync_controller.dart';

final expensesRepositoryProvider = Provider<ExpensesRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final audit = ref.watch(auditRepositoryProvider);
  final syncEngine = ref.watch(syncEngineProvider);
  return ExpensesRepository(db, audit, syncEngine);
});

class ExpensesRepository {
  final AppDatabase _db;
  final AuditRepository _audit;
  final SyncEngine? _syncEngine;

  ExpensesRepository(this._db, this._audit, [this._syncEngine]);

  // ==========================================
  // School Expenses
  // ==========================================

  Future<List<SchoolExpense>> getExpenses(
    String schoolId, {
    DateTime? startDate,
    DateTime? endDate,
    String? category,
    bool? isApproved,
    bool includeReversed = false,
  }) async {
    final query = _db.select(_db.schoolExpenses)
      ..where((t) => t.schoolId.equals(schoolId));

    if (startDate != null) {
      query.where((t) => t.date.isBiggerOrEqualValue(startDate));
    }
    if (endDate != null) {
      query.where((t) => t.date.isSmallerOrEqualValue(endDate));
    }
    if (category != null) {
      query.where((t) => t.category.equals(category));
    }
    if (isApproved != null) {
      query.where((t) => t.isApproved.equals(isApproved));
    }
    if (!includeReversed) {
      query.where((t) => t.isReversed.equals(false));
    }

    query.orderBy([(t) => OrderingTerm.desc(t.date)]);
    return query.get();
  }

  Future<SchoolExpense> recordExpense({
    required String schoolId,
    required String category,
    required int amountCents,
    required DateTime date,
    required String description,
    required String paymentMethod,
    String? reference,
    required String recordedBy,
    bool autoApprove = false,
  }) async {
    if (amountCents <= 0) {
      throw ArgumentError('Expense amount must be greater than zero');
    }

    final id = UuidGenerator.v4();
    final now = DateTime.now();

    final companion = SchoolExpensesCompanion.insert(
      id: id,
      schoolId: schoolId,
      category: category,
      amountCents: amountCents,
      amount: amountCents / 100.0,
      date: date,
      description: description,
      paymentMethod: paymentMethod,
      reference: Value(reference),
      recordedBy: recordedBy,
      isApproved: Value(autoApprove),
      approvedBy: Value(autoApprove ? recordedBy : null),
      approvedAt: Value(autoApprove ? now : null),
      isReversed: const Value(false),
      createdAt: now,
      updatedAt: now,
    );

    await _db.into(_db.schoolExpenses).insert(companion);

    final payload = {
      'id': id,
      'schoolId': schoolId,
      'category': category,
      'amountCents': amountCents,
      'amount': amountCents / 100.0,
      'date': date.toIso8601String(),
      'description': description,
      'paymentMethod': paymentMethod,
      'reference': reference,
      'recordedBy': recordedBy,
      'isApproved': autoApprove,
      'approvedBy': autoApprove ? recordedBy : null,
      'approvedAt': autoApprove ? now.toIso8601String() : null,
      'isReversed': false,
      'createdAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
    };

    await _syncEngine?.enqueue(
      schoolId: schoolId,
      userId: recordedBy,
      entityType: SyncEntityType.schoolExpense,
      entityId: id,
      operation: SyncOperation.create,
      payload: payload,
    );

    await _audit.log(
      action: AuditAction.expenseRecorded,
      entityType: 'SchoolExpense',
      entityId: id,
      schoolId: schoolId,
      userId: recordedBy,
      metadata: {'amountCents': amountCents, 'category': category},
    );

    return (_db.select(_db.schoolExpenses)..where((t) => t.id.equals(id)))
        .getSingle();
  }

  Future<void> approveExpense({
    required String expenseId,
    required String approvedBy,
    required String schoolId,
  }) async {
    final existing = await (_db.select(_db.schoolExpenses)
          ..where((t) => t.id.equals(expenseId)))
        .getSingle();

    if (existing.isApproved) return;

    final now = DateTime.now();

    await (_db.update(_db.schoolExpenses)..where((t) => t.id.equals(expenseId)))
        .write(
      SchoolExpensesCompanion(
        isApproved: const Value(true),
        approvedBy: Value(approvedBy),
        approvedAt: Value(now),
        updatedAt: Value(now),
      ),
    );

    final payload = {
      'id': existing.id,
      'schoolId': existing.schoolId,
      'category': existing.category,
      'amountCents': existing.amountCents,
      'amount': existing.amount,
      'date': existing.date.toIso8601String(),
      'description': existing.description,
      'paymentMethod': existing.paymentMethod,
      'reference': existing.reference,
      'recordedBy': existing.recordedBy,
      'isApproved': true,
      'approvedBy': approvedBy,
      'approvedAt': now.toIso8601String(),
      'isReversed': existing.isReversed,
      'createdAt': existing.createdAt.toIso8601String(),
      'updatedAt': now.toIso8601String(),
    };

    await _syncEngine?.enqueue(
      schoolId: schoolId,
      userId: approvedBy,
      entityType: SyncEntityType.schoolExpense,
      entityId: expenseId,
      operation: SyncOperation.update,
      payload: payload,
    );

    await _audit.log(
      action: AuditAction.expenseApproved,
      entityType: 'SchoolExpense',
      entityId: expenseId,
      schoolId: schoolId,
      userId: approvedBy,
      metadata: {'amountCents': existing.amountCents},
    );
  }

  Future<void> reverseExpense({
    required String expenseId,
    required String reversedBy,
    required String reason,
    required String schoolId,
  }) async {
    final existing = await (_db.select(_db.schoolExpenses)
          ..where((t) => t.id.equals(expenseId)))
        .getSingle();

    if (existing.isReversed) {
      throw StateError('This expense has already been reversed');
    }

    final now = DateTime.now();

    await (_db.update(_db.schoolExpenses)..where((t) => t.id.equals(expenseId)))
        .write(
      SchoolExpensesCompanion(
        isReversed: const Value(true),
        reversedAt: Value(now),
        reversedBy: Value(reversedBy),
        reversalReason: Value(reason),
        updatedAt: Value(now),
      ),
    );

    final payload = {
      'id': existing.id,
      'schoolId': existing.schoolId,
      'category': existing.category,
      'amountCents': existing.amountCents,
      'amount': existing.amount,
      'date': existing.date.toIso8601String(),
      'description': existing.description,
      'paymentMethod': existing.paymentMethod,
      'reference': existing.reference,
      'recordedBy': existing.recordedBy,
      'isApproved': existing.isApproved,
      'approvedBy': existing.approvedBy,
      'approvedAt': existing.approvedAt?.toIso8601String(),
      'isReversed': true,
      'reversedAt': now.toIso8601String(),
      'reversedBy': reversedBy,
      'reversalReason': reason,
      'createdAt': existing.createdAt.toIso8601String(),
      'updatedAt': now.toIso8601String(),
    };

    await _syncEngine?.enqueue(
      schoolId: schoolId,
      userId: reversedBy,
      entityType: SyncEntityType.schoolExpense,
      entityId: expenseId,
      operation: SyncOperation.update,
      payload: payload,
    );

    await _audit.log(
      action: AuditAction.expenseReversed,
      entityType: 'SchoolExpense',
      entityId: expenseId,
      schoolId: schoolId,
      userId: reversedBy,
      metadata: {'reason': reason, 'amountCents': existing.amountCents},
    );
  }

  // ==========================================
  // School Incomes
  // ==========================================

  Future<List<SchoolIncome>> getIncomes(
    String schoolId, {
    DateTime? startDate,
    DateTime? endDate,
    String? category,
  }) async {
    final query = _db.select(_db.schoolIncomes)
      ..where((t) => t.schoolId.equals(schoolId));

    if (startDate != null) {
      query.where((t) => t.date.isBiggerOrEqualValue(startDate));
    }
    if (endDate != null) {
      query.where((t) => t.date.isSmallerOrEqualValue(endDate));
    }
    if (category != null) {
      query.where((t) => t.category.equals(category));
    }

    query.orderBy([(t) => OrderingTerm.desc(t.date)]);
    return query.get();
  }

  Future<SchoolIncome> recordIncome({
    required String schoolId,
    required String category,
    required int amountCents,
    required DateTime date,
    required String description,
    required String paymentMethod,
    String? reference,
    required String receivedBy,
  }) async {
    if (amountCents <= 0) {
      throw ArgumentError('Income amount must be greater than zero');
    }

    final id = UuidGenerator.v4();
    final now = DateTime.now();

    final companion = SchoolIncomesCompanion.insert(
      id: id,
      schoolId: schoolId,
      category: category,
      amountCents: amountCents,
      amount: amountCents / 100.0,
      date: date,
      description: description,
      paymentMethod: paymentMethod,
      reference: Value(reference),
      receivedBy: receivedBy,
      createdAt: now,
      updatedAt: now,
    );

    await _db.into(_db.schoolIncomes).insert(companion);

    final payload = {
      'id': id,
      'schoolId': schoolId,
      'category': category,
      'amountCents': amountCents,
      'amount': amountCents / 100.0,
      'date': date.toIso8601String(),
      'description': description,
      'paymentMethod': paymentMethod,
      'reference': reference,
      'receivedBy': receivedBy,
      'createdAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
    };

    await _syncEngine?.enqueue(
      schoolId: schoolId,
      userId: receivedBy,
      entityType: SyncEntityType.schoolIncome,
      entityId: id,
      operation: SyncOperation.create,
      payload: payload,
    );

    await _audit.log(
      action: AuditAction.incomeRecorded,
      entityType: 'SchoolIncome',
      entityId: id,
      schoolId: schoolId,
      userId: receivedBy,
      metadata: {'amountCents': amountCents, 'category': category},
    );

    return (_db.select(_db.schoolIncomes)..where((t) => t.id.equals(id)))
        .getSingle();
  }
}
