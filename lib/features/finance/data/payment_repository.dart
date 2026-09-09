// lib/features/finance/data/payment_repository.dart
import 'dart:math';
import 'package:drift/drift.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_service.dart';
import '../../../core/utils/uuid_generator.dart';
import '../../audit/data/audit_repository.dart';
import '../../sync/client/sync_engine.dart';
import '../../sync/presentation/sync_controller.dart';
import '../domain/finance_calculator.dart';
import '../domain/finance_models.dart';

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final audit = ref.watch(auditRepositoryProvider);
  final syncEngine = ref.watch(syncEngineProvider);
  return PaymentRepository(db, audit, syncEngine);
});

class PaymentRepository {
  final AppDatabase _db;
  final AuditRepository _audit;
  final SyncEngine? _syncEngine;

  PaymentRepository(this._db, this._audit, [this._syncEngine]);

  // ==========================================
  // Receipt Number Generation
  // ==========================================

  Future<String> generateReceiptNumber({
    required String schoolId,
    required String deviceId,
    bool isOffline = false,
  }) async {
    final year = DateTime.now().year.toString();

    if (isOffline) {
      final shortDev = deviceId.length >= 4
          ? deviceId.substring(0, 4).toUpperCase()
          : deviceId.toUpperCase().padRight(4, 'X');
      final offlineCount = await (_db.select(_db.feePayments)
            ..where((t) => t.schoolId.equals(schoolId) & t.deviceId.equals(deviceId)))
          .get()
          .then((l) => l.length + 1);
      return 'OFFLINE-$shortDev-${offlineCount.toString().padLeft(6, '0')}';
    }

    final totalCount = await (_db.select(_db.feePayments)
          ..where((t) => t.schoolId.equals(schoolId)))
        .get()
        .then((l) => l.length + 1);

    return 'REC-$year-${totalCount.toString().padLeft(6, '0')}';
  }

  // ==========================================
  // Payment Collection
  // ==========================================

  Future<FeePayment> recordPayment({
    required String schoolId,
    required String studentId,
    required String academicYearId,
    required int amountCents,
    required PaymentMethod paymentMethod,
    String? reference,
    required String collectedBy,
    required String deviceId,
    String? remarks,
    List<String>? selectedFeeIds,
    bool isOffline = false,
    DateTime? paymentDate,
  }) async {
    if (amountCents <= 0) {
      throw ArgumentError('Payment amount must be greater than zero');
    }

    final date = paymentDate ?? DateTime.now();
    final paymentId = UuidGenerator.v4();

    final receiptNumber = await generateReceiptNumber(
      schoolId: schoolId,
      deviceId: deviceId,
      isOffline: isOffline,
    );

    final offlineReceiptNumber = isOffline ? receiptNumber : null;

    // Execute in transaction for complete atomicity
    return await _db.transaction(() async {
      // 1. Fetch dues to allocate against
      final duesQuery = _db.select(_db.studentFees)
        ..where(
          (t) =>
              t.schoolId.equals(schoolId) &
              t.studentId.equals(studentId) &
              t.isWaived.equals(false) &
              t.remainingAmountCents.isBiggerThanValue(0),
        );

      if (selectedFeeIds != null && selectedFeeIds.isNotEmpty) {
        duesQuery.where((t) => t.id.isIn(selectedFeeIds));
      }

      duesQuery.orderBy([(t) => OrderingTerm.asc(t.dueDate)]);
      final eligibleDues = await duesQuery.get();

      final duesList = eligibleDues
          .map((d) => {
                'id': d.id,
                'netAmountCents': d.netAmountCents,
                'paidAmountCents': d.paidAmountCents,
                'dueDate': d.dueDate,
              })
          .toList();

      final distribution = FinanceCalculator.distributePayment(
        dues: duesList,
        paymentAmountCents: amountCents,
        now: date,
      );

      // 2. Update each allocated StudentFee & record FeePaymentItem
      for (final alloc in distribution.allocations) {
        await (_db.update(_db.studentFees)
              ..where((t) => t.id.equals(alloc.studentFeeId)))
            .write(
          StudentFeesCompanion(
            paidAmountCents: Value(alloc.newPaidAmountCents),
            remainingAmountCents: Value(alloc.newRemainingAmountCents),
            status: Value(alloc.newStatus.name),
            updatedAt: Value(date),
          ),
        );

        final itemId = UuidGenerator.v4();
        await _db.into(_db.feePaymentItems).insert(
          FeePaymentItemsCompanion.insert(
            id: itemId,
            paymentId: paymentId,
            studentFeeId: alloc.studentFeeId,
            amountCents: alloc.allocatedCents,
            createdAt: date,
          ),
        );

        // Fetch updated fee to sync
        final updatedFee = await (_db.select(_db.studentFees)
              ..where((t) => t.id.equals(alloc.studentFeeId)))
            .getSingle();

        final feePayload = {
          'id': updatedFee.id,
          'schoolId': updatedFee.schoolId,
          'studentId': updatedFee.studentId,
          'academicYearId': updatedFee.academicYearId,
          'classId': updatedFee.classId,
          'sectionId': updatedFee.sectionId,
          'feeStructureId': updatedFee.feeStructureId,
          'categoryId': updatedFee.categoryId,
          'feePeriod': updatedFee.feePeriod,
          'title': updatedFee.title,
          'dueAmountCents': updatedFee.dueAmountCents,
          'discountAmountCents': updatedFee.discountAmountCents,
          'netAmountCents': updatedFee.netAmountCents,
          'paidAmountCents': updatedFee.paidAmountCents,
          'remainingAmountCents': updatedFee.remainingAmountCents,
          'dueDate': updatedFee.dueDate.toIso8601String(),
          'status': updatedFee.status,
          'isWaived': updatedFee.isWaived,
          'createdAt': updatedFee.createdAt.toIso8601String(),
          'updatedAt': date.toIso8601String(),
        };

        await _syncEngine?.enqueue(
          schoolId: schoolId,
          userId: collectedBy,
          entityType: SyncEntityType.studentFee,
          entityId: updatedFee.id,
          operation: SyncOperation.update,
          payload: feePayload,
        );
      }

      // 3. If there is excess payment, record StudentAdvance
      final isAdvance = distribution.excessAdvanceCents > 0;
      if (isAdvance) {
        final advanceId = UuidGenerator.v4();
        await _db.into(_db.studentAdvances).insert(
          StudentAdvancesCompanion.insert(
            id: advanceId,
            schoolId: schoolId,
            studentId: studentId,
            amountCents: distribution.excessAdvanceCents,
            consumedCents: const Value(0),
            remainingCents: distribution.excessAdvanceCents,
            paymentId: paymentId,
            createdAt: date,
            updatedAt: date,
          ),
        );

        final advancePayload = {
          'id': advanceId,
          'schoolId': schoolId,
          'studentId': studentId,
          'amountCents': distribution.excessAdvanceCents,
          'consumedCents': 0,
          'remainingCents': distribution.excessAdvanceCents,
          'paymentId': paymentId,
          'createdAt': date.toIso8601String(),
          'updatedAt': date.toIso8601String(),
        };

        await _syncEngine?.enqueue(
          schoolId: schoolId,
          userId: collectedBy,
          entityType: SyncEntityType.studentAdvance,
          entityId: advanceId,
          operation: SyncOperation.create,
          payload: advancePayload,
        );
      }

      // 4. Insert FeePayment record
      final paymentCompanion = FeePaymentsCompanion.insert(
        id: paymentId,
        schoolId: schoolId,
        receiptNumber: receiptNumber,
        offlineReceiptNumber: Value(offlineReceiptNumber),
        studentId: studentId,
        academicYearId: academicYearId,
        amountCents: amountCents,
        amount: amountCents / 100.0,
        paymentMethod: paymentMethod.name,
        reference: Value(reference),
        paymentDate: date,
        collectedBy: collectedBy,
        deviceId: deviceId,
        remarks: Value(remarks),
        isAdvance: Value(isAdvance),
        isReversed: const Value(false),
        isReconciled: Value(!isOffline),
        createdAt: date,
        updatedAt: date,
      );

      await _db.into(_db.feePayments).insert(paymentCompanion);

      final paymentPayload = {
        'id': paymentId,
        'schoolId': schoolId,
        'receiptNumber': receiptNumber,
        'offlineReceiptNumber': offlineReceiptNumber,
        'studentId': studentId,
        'academicYearId': academicYearId,
        'amountCents': amountCents,
        'amount': amountCents / 100.0,
        'paymentMethod': paymentMethod.name,
        'reference': reference,
        'paymentDate': date.toIso8601String(),
        'collectedBy': collectedBy,
        'deviceId': deviceId,
        'remarks': remarks,
        'isAdvance': isAdvance,
        'isReversed': false,
        'isReconciled': !isOffline,
        'createdAt': date.toIso8601String(),
        'updatedAt': date.toIso8601String(),
      };

      await _syncEngine?.enqueue(
        schoolId: schoolId,
        userId: collectedBy,
        entityType: SyncEntityType.feePayment,
        entityId: paymentId,
        operation: SyncOperation.create,
        payload: paymentPayload,
      );

      await _audit.log(
        action: AuditAction.feePaymentCollected,
        entityType: 'FeePayment',
        entityId: paymentId,
        schoolId: schoolId,
        userId: collectedBy,
        metadata: {
          'receiptNumber': receiptNumber,
          'amountCents': amountCents,
          'method': paymentMethod.name,
          'studentId': studentId,
        },
      );

      return (_db.select(_db.feePayments)..where((t) => t.id.equals(paymentId)))
          .getSingle();
    });
  }

  // ==========================================
  // Immutable Payment Reversal
  // ==========================================

  Future<void> reversePayment({
    required String paymentId,
    required String reversedBy,
    required String reason,
    required String schoolId,
  }) async {
    final payment = await (_db.select(_db.feePayments)
          ..where((t) => t.id.equals(paymentId)))
        .getSingle();

    if (payment.isReversed) {
      throw StateError('This payment has already been reversed');
    }

    final now = DateTime.now();

    await _db.transaction(() async {
      // 1. Fetch itemized breakdown
      final items = await (_db.select(_db.feePaymentItems)
            ..where((t) => t.paymentId.equals(paymentId)))
          .get();

      // 2. Restore fee balances
      for (final item in items) {
        final fee = await (_db.select(_db.studentFees)
              ..where((t) => t.id.equals(item.studentFeeId)))
            .getSingle();

        final restoredPaidCents = max(0, fee.paidAmountCents - item.amountCents);
        final restoredRemainingCents = fee.netAmountCents - restoredPaidCents;
        final newStatus = FinanceCalculator.determineFeeStatus(
          dueDate: fee.dueDate,
          netAmountCents: fee.netAmountCents,
          paidAmountCents: restoredPaidCents,
          now: now,
        );

        await (_db.update(_db.studentFees)..where((t) => t.id.equals(fee.id)))
            .write(
          StudentFeesCompanion(
            paidAmountCents: Value(restoredPaidCents),
            remainingAmountCents: Value(restoredRemainingCents),
            status: Value(newStatus.name),
            updatedAt: Value(now),
          ),
        );

        final feePayload = {
          'id': fee.id,
          'schoolId': fee.schoolId,
          'studentId': fee.studentId,
          'academicYearId': fee.academicYearId,
          'classId': fee.classId,
          'sectionId': fee.sectionId,
          'feeStructureId': fee.feeStructureId,
          'categoryId': fee.categoryId,
          'feePeriod': fee.feePeriod,
          'title': fee.title,
          'dueAmountCents': fee.dueAmountCents,
          'discountAmountCents': fee.discountAmountCents,
          'netAmountCents': fee.netAmountCents,
          'paidAmountCents': restoredPaidCents,
          'remainingAmountCents': restoredRemainingCents,
          'dueDate': fee.dueDate.toIso8601String(),
          'status': newStatus.name,
          'isWaived': fee.isWaived,
          'createdAt': fee.createdAt.toIso8601String(),
          'updatedAt': now.toIso8601String(),
        };

        await _syncEngine?.enqueue(
          schoolId: schoolId,
          userId: reversedBy,
          entityType: SyncEntityType.studentFee,
          entityId: fee.id,
          operation: SyncOperation.update,
          payload: feePayload,
        );
      }

      // 3. Invalidate any advances linked to this payment
      final advances = await (_db.select(_db.studentAdvances)
            ..where((t) => t.paymentId.equals(paymentId)))
          .get();
      for (final adv in advances) {
        await (_db.update(_db.studentAdvances)..where((t) => t.id.equals(adv.id)))
            .write(
          StudentAdvancesCompanion(
            remainingCents: const Value(0),
            updatedAt: Value(now),
          ),
        );
      }

      // 4. Mark payment as reversed (IMMUTABLE RECORD)
      await (_db.update(_db.feePayments)..where((t) => t.id.equals(paymentId)))
          .write(
        FeePaymentsCompanion(
          isReversed: const Value(true),
          reversedAt: Value(now),
          reversedBy: Value(reversedBy),
          reversalReason: Value(reason),
          updatedAt: Value(now),
        ),
      );

      final paymentPayload = {
        'id': payment.id,
        'schoolId': payment.schoolId,
        'receiptNumber': payment.receiptNumber,
        'offlineReceiptNumber': payment.offlineReceiptNumber,
        'studentId': payment.studentId,
        'academicYearId': payment.academicYearId,
        'amountCents': payment.amountCents,
        'amount': payment.amount,
        'paymentMethod': payment.paymentMethod,
        'reference': payment.reference,
        'paymentDate': payment.paymentDate.toIso8601String(),
        'collectedBy': payment.collectedBy,
        'deviceId': payment.deviceId,
        'remarks': payment.remarks,
        'isAdvance': payment.isAdvance,
        'isReversed': true,
        'reversedAt': now.toIso8601String(),
        'reversedBy': reversedBy,
        'reversalReason': reason,
        'isReconciled': payment.isReconciled,
        'createdAt': payment.createdAt.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      };

      await _syncEngine?.enqueue(
        schoolId: schoolId,
        userId: reversedBy,
        entityType: SyncEntityType.feePayment,
        entityId: paymentId,
        operation: SyncOperation.update,
        payload: paymentPayload,
      );

      await _audit.log(
        action: AuditAction.feePaymentReversed,
        entityType: 'FeePayment',
        entityId: paymentId,
        schoolId: schoolId,
        userId: reversedBy,
        metadata: {
          'receiptNumber': payment.receiptNumber,
          'reason': reason,
          'amountCents': payment.amountCents,
        },
      );
    });
  }

  // ==========================================
  // Student Advances & Credit Consumption
  // ==========================================

  Future<int> getStudentAdvanceBalance(String schoolId, String studentId) async {
    final advances = await (_db.select(_db.studentAdvances)
          ..where(
            (t) =>
                t.schoolId.equals(schoolId) &
                t.studentId.equals(studentId) &
                t.remainingCents.isBiggerThanValue(0),
          ))
        .get();

    return advances.fold<int>(0, (sum, a) => sum + a.remainingCents);
  }

  /// Consumes available advance credit towards unpaid student fees.
  Future<FeePayment> applyAdvanceCreditToFees({
    required String schoolId,
    required String studentId,
    required String academicYearId,
    required int amountCents,
    required String collectedBy,
    required String deviceId,
    List<String>? selectedFeeIds,
  }) async {
    final availableBalance = await getStudentAdvanceBalance(schoolId, studentId);
    if (amountCents > availableBalance) {
      throw StateError(
        'Insufficient advance credit: requested $amountCents cents, but student has only $availableBalance cents',
      );
    }

    final now = DateTime.now();

    // Consume from oldest advances first
    final advances = await (_db.select(_db.studentAdvances)
          ..where(
            (t) =>
                t.schoolId.equals(schoolId) &
                t.studentId.equals(studentId) &
                t.remainingCents.isBiggerThanValue(0),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();

    int remainingToDeduct = amountCents;
    for (final adv in advances) {
      if (remainingToDeduct <= 0) break;

      final deduct = min(remainingToDeduct, adv.remainingCents);
      final newConsumed = adv.consumedCents + deduct;
      final newRemaining = adv.remainingCents - deduct;

      await (_db.update(_db.studentAdvances)..where((t) => t.id.equals(adv.id)))
          .write(
        StudentAdvancesCompanion(
          consumedCents: Value(newConsumed),
          remainingCents: Value(newRemaining),
          updatedAt: Value(now),
        ),
      );

      remainingToDeduct -= deduct;
    }

    // Now record as a standard payment with method 'advanceCredit'
    return recordPayment(
      schoolId: schoolId,
      studentId: studentId,
      academicYearId: academicYearId,
      amountCents: amountCents,
      paymentMethod: PaymentMethod.advanceCredit,
      reference: 'ADVANCE-CONSUMPTION',
      collectedBy: collectedBy,
      deviceId: deviceId,
      remarks: 'Paid using accumulated advance balance',
      selectedFeeIds: selectedFeeIds,
    );
  }

  // ==========================================
  // Queries
  // ==========================================

  Future<List<FeePayment>> getPayments(
    String schoolId, {
    String? studentId,
    DateTime? startDate,
    DateTime? endDate,
    bool includeReversed = false,
  }) async {
    final query = _db.select(_db.feePayments)
      ..where((t) => t.schoolId.equals(schoolId));

    if (studentId != null) {
      query.where((t) => t.studentId.equals(studentId));
    }
    if (startDate != null) {
      query.where((t) => t.paymentDate.isBiggerOrEqualValue(startDate));
    }
    if (endDate != null) {
      query.where((t) => t.paymentDate.isSmallerOrEqualValue(endDate));
    }
    if (!includeReversed) {
      query.where((t) => t.isReversed.equals(false));
    }

    query.orderBy([(t) => OrderingTerm.desc(t.paymentDate)]);
    return query.get();
  }

  Future<List<FeePaymentItem>> getPaymentItems(String paymentId) async {
    return (_db.select(_db.feePaymentItems)
          ..where((t) => t.paymentId.equals(paymentId)))
        .get();
  }

  Future<FeePayment?> getPaymentByReceiptNumber(
    String schoolId,
    String receiptNumber,
  ) async {
    final query = _db.select(_db.feePayments)
      ..where(
        (t) =>
            t.schoolId.equals(schoolId) &
            (t.receiptNumber.equals(receiptNumber) |
                t.offlineReceiptNumber.equals(receiptNumber)),
      );
    return query.getSingleOrNull();
  }
}
