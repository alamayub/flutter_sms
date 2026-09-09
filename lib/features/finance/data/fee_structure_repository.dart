// lib/features/finance/data/fee_structure_repository.dart
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

final feeStructureRepositoryProvider = Provider<FeeStructureRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final audit = ref.watch(auditRepositoryProvider);
  final syncEngine = ref.watch(syncEngineProvider);
  return FeeStructureRepository(db, audit, syncEngine);
});

class FeeStructureRepository {
  final AppDatabase _db;
  final AuditRepository _audit;
  final SyncEngine? _syncEngine;

  FeeStructureRepository(this._db, this._audit, [this._syncEngine]);

  // ==========================================
  // Fee Categories
  // ==========================================

  Future<List<FeeCategory>> getCategories(
    String schoolId, {
    bool activeOnly = true,
  }) async {
    final query = _db.select(_db.feeCategories)
      ..where((t) => t.schoolId.equals(schoolId));
    if (activeOnly) {
      query.where((t) => t.isActive.equals(true));
    }
    query.orderBy([(t) => OrderingTerm.asc(t.name)]);
    return query.get();
  }

  Future<FeeCategory> createCategory({
    required String schoolId,
    required String name,
    String? description,
    bool isDefault = false,
    required String userId,
  }) async {
    final id = UuidGenerator.v4();
    final now = DateTime.now();

    final companion = FeeCategoriesCompanion.insert(
      id: id,
      schoolId: schoolId,
      name: name,
      description: Value(description),
      isDefault: Value(isDefault),
      isActive: const Value(true),
      createdAt: now,
      updatedAt: now,
    );

    await _db.into(_db.feeCategories).insert(companion);

    final payload = {
      'id': id,
      'schoolId': schoolId,
      'name': name,
      'description': description,
      'isDefault': isDefault,
      'isActive': true,
      'createdAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
    };

    await _syncEngine?.enqueue(
      schoolId: schoolId,
      userId: userId,
      entityType: SyncEntityType.feeCategory,
      entityId: id,
      operation: SyncOperation.create,
      payload: payload,
    );

    await _audit.log(
      action: AuditAction.feeCategoryCreated,
      entityType: 'FeeCategory',
      entityId: id,
      schoolId: schoolId,
      userId: userId,
      metadata: {'name': name},
    );

    return (_db.select(_db.feeCategories)..where((t) => t.id.equals(id)))
        .getSingle();
  }

  Future<void> seedDefaultCategories(String schoolId, String userId) async {
    final existing = await getCategories(schoolId, activeOnly: false);
    if (existing.isNotEmpty) return;

    final defaults = [
      ('Tuition Fee', 'Regular monthly tuition fee'),
      ('Admission Fee', 'One-time student admission and enrollment fee'),
      ('Annual Development Fee', 'Yearly facility and development charges'),
      ('Examination Fee', 'Term-end examination and paper fee'),
      ('Laboratory Fee', 'Science and computer lab maintenance fee'),
      ('Library Fee', 'Library books and reading resource fee'),
      ('Transportation Fee', 'School bus and commuting fee'),
      ('Sports & Activities Fee', 'Extracurricular and sports activity fee'),
    ];

    for (final (name, desc) in defaults) {
      await createCategory(
        schoolId: schoolId,
        name: name,
        description: desc,
        isDefault: true,
        userId: userId,
      );
    }
  }

  // ==========================================
  // Fee Structures
  // ==========================================

  Future<List<FeeStructure>> getStructures(
    String schoolId, {
    String? academicYearId,
    String? classId,
    bool activeOnly = true,
  }) async {
    final query = _db.select(_db.feeStructures)
      ..where((t) => t.schoolId.equals(schoolId));

    if (academicYearId != null) {
      query.where((t) => t.academicYearId.equals(academicYearId));
    }
    if (classId != null) {
      query.where((t) => t.classId.equals(classId));
    }
    if (activeOnly) {
      query.where((t) => t.isActive.equals(true));
    }

    return query.get();
  }

  Future<FeeStructure> createStructure({
    required String schoolId,
    required String academicYearId,
    required String classId,
    String? sectionId,
    required String categoryId,
    required int amountCents,
    required String frequency,
    DateTime? dueDate,
    required String userId,
  }) async {
    final id = UuidGenerator.v4();
    final now = DateTime.now();

    final companion = FeeStructuresCompanion.insert(
      id: id,
      schoolId: schoolId,
      academicYearId: academicYearId,
      classId: classId,
      sectionId: Value(sectionId),
      categoryId: categoryId,
      amountCents: amountCents,
      amount: amountCents / 100.0,
      frequency: frequency,
      dueDate: Value(dueDate),
      isActive: const Value(true),
      createdAt: now,
      updatedAt: now,
    );

    await _db.into(_db.feeStructures).insert(companion);

    final payload = {
      'id': id,
      'schoolId': schoolId,
      'academicYearId': academicYearId,
      'classId': classId,
      'sectionId': sectionId,
      'categoryId': categoryId,
      'amountCents': amountCents,
      'amount': amountCents / 100.0,
      'frequency': frequency,
      'dueDate': dueDate?.toIso8601String(),
      'isActive': true,
      'createdAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
    };

    await _syncEngine?.enqueue(
      schoolId: schoolId,
      userId: userId,
      entityType: SyncEntityType.feeStructure,
      entityId: id,
      operation: SyncOperation.create,
      payload: payload,
    );

    await _audit.log(
      action: AuditAction.feeStructureCreated,
      entityType: 'FeeStructure',
      entityId: id,
      schoolId: schoolId,
      userId: userId,
      metadata: {'amountCents': amountCents, 'frequency': frequency},
    );

    return (_db.select(_db.feeStructures)..where((t) => t.id.equals(id)))
        .getSingle();
  }

  Future<void> updateStructure({
    required String structureId,
    int? amountCents,
    String? frequency,
    DateTime? dueDate,
    bool? isActive,
    required String userId,
  }) async {
    final existing = await (_db.select(_db.feeStructures)
          ..where((t) => t.id.equals(structureId)))
        .getSingle();
    final now = DateTime.now();

    final companion = FeeStructuresCompanion(
      amountCents: amountCents != null ? Value(amountCents) : const Value.absent(),
      amount: amountCents != null ? Value(amountCents / 100.0) : const Value.absent(),
      frequency: frequency != null ? Value(frequency) : const Value.absent(),
      dueDate: dueDate != null ? Value(dueDate) : const Value.absent(),
      isActive: isActive != null ? Value(isActive) : const Value.absent(),
      updatedAt: Value(now),
    );

    await (_db.update(_db.feeStructures)..where((t) => t.id.equals(structureId)))
        .write(companion);

    final updated = await (_db.select(_db.feeStructures)
          ..where((t) => t.id.equals(structureId)))
        .getSingle();

    final payload = {
      'id': updated.id,
      'schoolId': updated.schoolId,
      'academicYearId': updated.academicYearId,
      'classId': updated.classId,
      'sectionId': updated.sectionId,
      'categoryId': updated.categoryId,
      'amountCents': updated.amountCents,
      'amount': updated.amount,
      'frequency': updated.frequency,
      'dueDate': updated.dueDate?.toIso8601String(),
      'isActive': updated.isActive,
      'createdAt': updated.createdAt.toIso8601String(),
      'updatedAt': now.toIso8601String(),
    };

    await _syncEngine?.enqueue(
      schoolId: existing.schoolId,
      userId: userId,
      entityType: SyncEntityType.feeStructure,
      entityId: structureId,
      operation: SyncOperation.update,
      payload: payload,
    );
  }

  // ==========================================
  // Fee Discounts
  // ==========================================

  Future<List<FeeDiscount>> getDiscounts(
    String schoolId, {
    String? academicYearId,
    bool activeOnly = true,
  }) async {
    final query = _db.select(_db.feeDiscounts)
      ..where((t) => t.schoolId.equals(schoolId));
    if (academicYearId != null) {
      query.where((t) => t.academicYearId.equals(academicYearId));
    }
    if (activeOnly) {
      query.where((t) => t.isActive.equals(true));
    }
    return query.get();
  }

  Future<FeeDiscount> createDiscount({
    required String schoolId,
    required String name,
    required DiscountType type,
    required double value,
    required DiscountReason reason,
    String? approvedBy,
    required String academicYearId,
    required String userId,
  }) async {
    final id = UuidGenerator.v4();
    final now = DateTime.now();

    final companion = FeeDiscountsCompanion.insert(
      id: id,
      schoolId: schoolId,
      name: name,
      type: type.name,
      value: value,
      reason: reason.name,
      approvedBy: Value(approvedBy),
      academicYearId: academicYearId,
      isActive: const Value(true),
      createdAt: now,
      updatedAt: now,
    );

    await _db.into(_db.feeDiscounts).insert(companion);

    final payload = {
      'id': id,
      'schoolId': schoolId,
      'name': name,
      'type': type.name,
      'value': value,
      'reason': reason.name,
      'approvedBy': approvedBy,
      'academicYearId': academicYearId,
      'isActive': true,
      'createdAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
    };

    await _syncEngine?.enqueue(
      schoolId: schoolId,
      userId: userId,
      entityType: SyncEntityType.feeDiscount,
      entityId: id,
      operation: SyncOperation.create,
      payload: payload,
    );

    await _audit.log(
      action: AuditAction.feeDiscountCreated,
      entityType: 'FeeDiscount',
      entityId: id,
      schoolId: schoolId,
      userId: userId,
      metadata: {'name': name, 'value': value},
    );

    return (_db.select(_db.feeDiscounts)..where((t) => t.id.equals(id)))
        .getSingle();
  }

  // ==========================================
  // Student Fee Assignments
  // ==========================================

  Future<List<StudentFeeAssignment>> getAssignments(
    String schoolId, {
    String? studentId,
    String? academicYearId,
  }) async {
    final query = _db.select(_db.studentFeeAssignments)
      ..where((t) => t.schoolId.equals(schoolId));
    if (studentId != null) {
      query.where((t) => t.studentId.equals(studentId));
    }
    if (academicYearId != null) {
      query.where((t) => t.academicYearId.equals(academicYearId));
    }
    return query.get();
  }

  Future<StudentFeeAssignment> assignFeeToStudent({
    required String schoolId,
    required String studentId,
    required String feeStructureId,
    required String academicYearId,
    int? customAmountCents,
    String? discountId,
    required String userId,
  }) async {
    final id = UuidGenerator.v4();
    final now = DateTime.now();

    final companion = StudentFeeAssignmentsCompanion.insert(
      id: id,
      schoolId: schoolId,
      studentId: studentId,
      feeStructureId: feeStructureId,
      academicYearId: academicYearId,
      customAmountCents: Value(customAmountCents),
      discountId: Value(discountId),
      isActive: const Value(true),
      assignedAt: now,
      createdAt: now,
      updatedAt: now,
    );

    await _db.into(_db.studentFeeAssignments).insert(companion);

    final payload = {
      'id': id,
      'schoolId': schoolId,
      'studentId': studentId,
      'feeStructureId': feeStructureId,
      'academicYearId': academicYearId,
      'customAmountCents': customAmountCents,
      'discountId': discountId,
      'isActive': true,
      'assignedAt': now.toIso8601String(),
      'createdAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
    };

    await _syncEngine?.enqueue(
      schoolId: schoolId,
      userId: userId,
      entityType: SyncEntityType.studentFeeAssignment,
      entityId: id,
      operation: SyncOperation.create,
      payload: payload,
    );

    return (_db.select(_db.studentFeeAssignments)
          ..where((t) => t.id.equals(id)))
        .getSingle();
  }
}
