// lib/features/finance/data/fee_dues_repository.dart

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

final feeDuesRepositoryProvider = Provider<FeeDuesRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final audit = ref.watch(auditRepositoryProvider);
  final syncEngine = ref.watch(syncEngineProvider);
  return FeeDuesRepository(db, audit, syncEngine);
});

class FeeDuesRepository {
  final AppDatabase _db;
  final AuditRepository _audit;
  final SyncEngine? _syncEngine;

  FeeDuesRepository(this._db, this._audit, [this._syncEngine]);

  Future<List<StudentFee>> getStudentFees(
    String schoolId, {
    String? studentId,
    String? classId,
    String? sectionId,
    String? academicYearId,
    String? feePeriod,
    FeeStatus? status,
  }) async {
    final query = _db.select(_db.studentFees)
      ..where((t) => t.schoolId.equals(schoolId));

    if (studentId != null) {
      query.where((t) => t.studentId.equals(studentId));
    }
    if (classId != null) {
      query.where((t) => t.classId.equals(classId));
    }
    if (sectionId != null) {
      query.where((t) => t.sectionId.equals(sectionId));
    }
    if (academicYearId != null) {
      query.where((t) => t.academicYearId.equals(academicYearId));
    }
    if (feePeriod != null) {
      query.where((t) => t.feePeriod.equals(feePeriod));
    }
    if (status != null) {
      query.where((t) => t.status.equals(status.name));
    }

    query.orderBy([(t) => OrderingTerm.desc(t.dueDate)]);
    return query.get();
  }

  Future<List<StudentFee>> getDueAndOverdueFees(
    String schoolId, {
    String? studentId,
  }) async {
    final query = _db.select(_db.studentFees)..where(
      (t) =>
          t.schoolId.equals(schoolId) &
          t.isWaived.equals(false) &
          t.remainingAmountCents.isBiggerThanValue(0),
    );

    if (studentId != null) {
      query.where((t) => t.studentId.equals(studentId));
    }

    query.orderBy([(t) => OrderingTerm.asc(t.dueDate)]);
    return query.get();
  }

  /// Previews batch fee generation to detect duplicates before applying changes.
  Future<Map<String, dynamic>> previewFeeGeneration({
    required String schoolId,
    required String academicYearId,
    required String classId,
    String? sectionId,
    required String feePeriod,
    required String feeStructureId,
  }) async {
    // 1. Fetch active enrollments
    final enrollmentsQuery = _db.select(_db.enrollments).join([
      innerJoin(
        _db.students,
        _db.students.id.equalsExp(_db.enrollments.studentId),
      ),
    ])..where(
      _db.enrollments.schoolId.equals(schoolId) &
          _db.enrollments.academicYearId.equals(academicYearId) &
          _db.enrollments.classId.equals(classId) &
          // _db.enrollments.status.equals('active') &
          _db.students.isArchived.equals(false),
    );

    if (sectionId != null) {
      enrollmentsQuery.where(_db.enrollments.sectionId.equals(sectionId));
    }

    final enrollmentRows = await enrollmentsQuery.get();
    final studentIds =
        enrollmentRows.map((r) => r.readTable(_db.students).id).toSet();

    // 2. Fetch existing fees for this period & structure
    final existingFees =
        await (_db.select(_db.studentFees)..where(
          (t) =>
              t.schoolId.equals(schoolId) &
              t.academicYearId.equals(academicYearId) &
              t.feeStructureId.equals(feeStructureId) &
              t.feePeriod.equals(feePeriod),
        )).get();

    final existingByStudent = {for (var f in existingFees) f.studentId: f};

    int alreadyGeneratedCount = 0;
    int unpaidExistingCount = 0;
    int paidExistingCount = 0;
    int newGenerationCount = 0;

    for (final studentId in studentIds) {
      if (existingByStudent.containsKey(studentId)) {
        alreadyGeneratedCount++;
        final f = existingByStudent[studentId]!;
        if (f.paidAmountCents > 0) {
          paidExistingCount++;
        } else {
          unpaidExistingCount++;
        }
      } else {
        newGenerationCount++;
      }
    }

    return {
      'totalStudents': studentIds.length,
      'alreadyGeneratedCount': alreadyGeneratedCount,
      'unpaidExistingCount': unpaidExistingCount,
      'paidExistingCount': paidExistingCount,
      'newGenerationCount': newGenerationCount,
    };
  }

  /// Generates fee dues for a class/section with duplicate prevention strategy.
  /// [duplicateStrategy] can be 'skipExisting' or 'regenerate'.
  /// Paid/partially paid fees are NEVER overwritten under any strategy.
  Future<int> generateFeesBatch({
    required String schoolId,
    required String academicYearId,
    required String classId,
    String? sectionId,
    required String feeStructureId,
    required String feePeriod,
    required String title,
    required DateTime dueDate,
    required String userId,
    String duplicateStrategy = 'skipExisting',
  }) async {
    // 1. Get Fee Structure
    final structure =
        await (_db.select(_db.feeStructures)
          ..where((t) => t.id.equals(feeStructureId))).getSingle();

    // 2. Get active enrollments
    final enrollmentsQuery = _db.select(_db.enrollments).join([
      innerJoin(
        _db.students,
        _db.students.id.equalsExp(_db.enrollments.studentId),
      ),
    ])..where(
      _db.enrollments.schoolId.equals(schoolId) &
          _db.enrollments.academicYearId.equals(academicYearId) &
          _db.enrollments.classId.equals(classId) &
          // _db.enrollments.status.equals('active') &
          _db.students.isArchived.equals(false),
    );

    if (sectionId != null) {
      enrollmentsQuery.where(_db.enrollments.sectionId.equals(sectionId));
    }

    final enrollmentRows = await enrollmentsQuery.get();
    if (enrollmentRows.isEmpty) return 0;

    // 3. Pre-fetch discounts and student assignments
    final discounts =
        await (_db.select(_db.feeDiscounts)..where(
          (t) => t.schoolId.equals(schoolId) & t.isActive.equals(true),
        )).get();
    final discountMap = {for (var d in discounts) d.id: d};

    final assignments =
        await (_db.select(_db.studentFeeAssignments)..where(
          (t) =>
              t.schoolId.equals(schoolId) &
              t.feeStructureId.equals(feeStructureId) &
              t.isActive.equals(true),
        )).get();
    final assignmentMap = {for (var a in assignments) a.studentId: a};

    // 4. Pre-fetch existing fees for duplicate prevention
    final existingFees =
        await (_db.select(_db.studentFees)..where(
          (t) =>
              t.schoolId.equals(schoolId) &
              t.academicYearId.equals(academicYearId) &
              t.feeStructureId.equals(feeStructureId) &
              t.feePeriod.equals(feePeriod),
        )).get();
    final existingMap = {for (var f in existingFees) f.studentId: f};

    int processedCount = 0;
    final now = DateTime.now();

    for (final row in enrollmentRows) {
      final student = row.readTable(_db.students);
      final enrollment = row.readTable(_db.enrollments);

      final existing = existingMap[student.id];
      if (existing != null) {
        if (duplicateStrategy == 'skipExisting') {
          continue;
        }

        // If 'regenerate', skip if any payment was already collected
        if (existing.paidAmountCents > 0) {
          continue;
        }

        // Otherwise recalculate unpaid fee
        final assignment = assignmentMap[student.id];
        final grossCents =
            assignment?.customAmountCents ?? structure.amountCents;

        int discountCents = 0;
        if (assignment?.discountId != null &&
            discountMap.containsKey(assignment!.discountId)) {
          final discount = discountMap[assignment.discountId]!;
          discountCents = FinanceCalculator.calculateDiscountCents(
            grossAmountCents: grossCents,
            type: DiscountType.fromString(discount.type),
            value: discount.value,
          );
        }

        final netCents = FinanceCalculator.calculateNetAmountCents(
          grossAmountCents: grossCents,
          discountAmountCents: discountCents,
        );

        final initialStatus = FinanceCalculator.determineFeeStatus(
          dueDate: dueDate,
          netAmountCents: netCents,
          paidAmountCents: 0,
          now: now,
        );

        await (_db.update(_db.studentFees)
          ..where((t) => t.id.equals(existing.id))).write(
          StudentFeesCompanion(
            title: Value(title),
            dueAmountCents: Value(grossCents),
            discountAmountCents: Value(discountCents),
            netAmountCents: Value(netCents),
            remainingAmountCents: Value(netCents),
            dueDate: Value(dueDate),
            status: Value(initialStatus.name),
            updatedAt: Value(now),
          ),
        );

        final payload = {
          'id': existing.id,
          'schoolId': schoolId,
          'studentId': student.id,
          'academicYearId': academicYearId,
          'classId': enrollment.classId,
          'sectionId': enrollment.sectionId,
          'feeStructureId': feeStructureId,
          'categoryId': structure.categoryId,
          'feePeriod': feePeriod,
          'title': title,
          'dueAmountCents': grossCents,
          'discountAmountCents': discountCents,
          'netAmountCents': netCents,
          'paidAmountCents': 0,
          'remainingAmountCents': netCents,
          'dueDate': dueDate.toIso8601String(),
          'status': initialStatus.name,
          'isWaived': false,
          'createdAt': existing.createdAt.toIso8601String(),
          'updatedAt': now.toIso8601String(),
        };

        await _syncEngine?.enqueue(
          schoolId: schoolId,
          userId: userId,
          entityType: SyncEntityType.studentFee,
          entityId: existing.id,
          operation: SyncOperation.update,
          payload: payload,
        );

        processedCount++;
        continue;
      }

      // 5. Calculate new fee
      final assignment = assignmentMap[student.id];
      final grossCents = assignment?.customAmountCents ?? structure.amountCents;

      int discountCents = 0;
      if (assignment?.discountId != null &&
          discountMap.containsKey(assignment!.discountId)) {
        final discount = discountMap[assignment.discountId]!;
        discountCents = FinanceCalculator.calculateDiscountCents(
          grossAmountCents: grossCents,
          type: DiscountType.fromString(discount.type),
          value: discount.value,
        );
      }

      final netCents = FinanceCalculator.calculateNetAmountCents(
        grossAmountCents: grossCents,
        discountAmountCents: discountCents,
      );

      final initialStatus = FinanceCalculator.determineFeeStatus(
        dueDate: dueDate,
        netAmountCents: netCents,
        paidAmountCents: 0,
        now: now,
      );

      final feeId = UuidGenerator.v4();

      final companion = StudentFeesCompanion.insert(
        id: feeId,
        schoolId: schoolId,
        studentId: student.id,
        academicYearId: academicYearId,
        classId: enrollment.classId,
        sectionId: enrollment.sectionId,
        feeStructureId: feeStructureId,
        categoryId: structure.categoryId,
        feePeriod: feePeriod,
        title: title,
        dueAmountCents: grossCents,
        discountAmountCents: Value(discountCents),
        netAmountCents: netCents,
        paidAmountCents: const Value(0),
        remainingAmountCents: netCents,
        dueDate: dueDate,
        status: initialStatus.name,
        isWaived: const Value(false),
        createdAt: now,
        updatedAt: now,
      );

      await _db.into(_db.studentFees).insert(companion);

      final payload = {
        'id': feeId,
        'schoolId': schoolId,
        'studentId': student.id,
        'academicYearId': academicYearId,
        'classId': enrollment.classId,
        'sectionId': enrollment.sectionId,
        'feeStructureId': feeStructureId,
        'categoryId': structure.categoryId,
        'feePeriod': feePeriod,
        'title': title,
        'dueAmountCents': grossCents,
        'discountAmountCents': discountCents,
        'netAmountCents': netCents,
        'paidAmountCents': 0,
        'remainingAmountCents': netCents,
        'dueDate': dueDate.toIso8601String(),
        'status': initialStatus.name,
        'isWaived': false,
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      };

      await _syncEngine?.enqueue(
        schoolId: schoolId,
        userId: userId,
        entityType: SyncEntityType.studentFee,
        entityId: feeId,
        operation: SyncOperation.create,
        payload: payload,
      );

      processedCount++;
    }

    if (processedCount > 0) {
      await _audit.log(
        action: AuditAction.studentFeesGenerated,
        entityType: 'StudentFee',
        entityId: feeStructureId,
        schoolId: schoolId,
        userId: userId,
        metadata: {
          'period': feePeriod,
          'count': processedCount,
          'strategy': duplicateStrategy,
        },
      );
    }

    return processedCount;
  }

  /// Waives a student fee with authorization and audit reason.
  Future<void> waiveFee({
    required String feeId,
    required String waivedBy,
    required String reason,
    required String schoolId,
  }) async {
    final existing =
        await (_db.select(_db.studentFees)
          ..where((t) => t.id.equals(feeId))).getSingle();

    if (existing.paidAmountCents > 0) {
      throw StateError('Cannot waive a fee that has existing payments');
    }

    final now = DateTime.now();

    await (_db.update(_db.studentFees)..where((t) => t.id.equals(feeId))).write(
      StudentFeesCompanion(
        isWaived: const Value(true),
        status: const Value('waived'),
        waivedBy: Value(waivedBy),
        waiveReason: Value(reason),
        remainingAmountCents: const Value(0),
        updatedAt: Value(now),
      ),
    );

    final payload = {
      'id': feeId,
      'schoolId': schoolId,
      'studentId': existing.studentId,
      'academicYearId': existing.academicYearId,
      'classId': existing.classId,
      'sectionId': existing.sectionId,
      'feeStructureId': existing.feeStructureId,
      'categoryId': existing.categoryId,
      'feePeriod': existing.feePeriod,
      'title': existing.title,
      'dueAmountCents': existing.dueAmountCents,
      'discountAmountCents': existing.discountAmountCents,
      'netAmountCents': existing.netAmountCents,
      'paidAmountCents': existing.paidAmountCents,
      'remainingAmountCents': 0,
      'dueDate': existing.dueDate.toIso8601String(),
      'status': 'waived',
      'isWaived': true,
      'waivedBy': waivedBy,
      'waiveReason': reason,
      'createdAt': existing.createdAt.toIso8601String(),
      'updatedAt': now.toIso8601String(),
    };

    await _syncEngine?.enqueue(
      schoolId: schoolId,
      userId: waivedBy,
      entityType: SyncEntityType.studentFee,
      entityId: feeId,
      operation: SyncOperation.update,
      payload: payload,
    );

    await _audit.log(
      action: AuditAction.feeWaived,
      entityType: 'StudentFee',
      entityId: feeId,
      schoolId: schoolId,
      userId: waivedBy,
      metadata: {'reason': reason, 'originalAmount': existing.netAmountCents},
    );
  }
}
