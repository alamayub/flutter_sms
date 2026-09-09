// lib/features/academic_year/data/academic_year_repository.dart
import 'package:drift/drift.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_service.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/utils/uuid_generator.dart';
import '../../audit/data/audit_repository.dart';
import '../../sync/client/sync_engine.dart';
import '../../sync/presentation/sync_controller.dart';

final academicYearRepositoryProvider = Provider<AcademicYearRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final audit = ref.watch(auditRepositoryProvider);
  final syncEngine = ref.watch(syncEngineProvider);
  return AcademicYearRepository(db, audit, syncEngine);
});

class AcademicYearRepository {
  final AppDatabase _db;
  final AuditRepository _audit;
  final SyncEngine? _syncEngine;

  AcademicYearRepository(this._db, this._audit, [this._syncEngine]);

  /// Gets all academic years for a school.
  Future<List<AcademicYear>> getAcademicYears(
    String schoolId, {
    bool includeArchived = false,
  }) async {
    final query = _db.select(_db.academicYears)
      ..where((t) => t.schoolId.equals(schoolId));
    if (!includeArchived) {
      query.where((t) => t.isArchived.equals(false));
    }
    query.orderBy([(t) => OrderingTerm.desc(t.startDate)]);
    return await query.get();
  }

  /// Watch academic years stream.
  Stream<List<AcademicYear>> watchAcademicYears(String schoolId) {
    return (_db.select(_db.academicYears)
          ..where(
            (t) => t.schoolId.equals(schoolId) & t.isArchived.equals(false),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.startDate)]))
        .watch();
  }

  /// Gets the currently active academic year.
  Future<AcademicYear?> getCurrentAcademicYear(String schoolId) async {
    return await (_db.select(_db.academicYears)..where(
      (t) =>
          t.schoolId.equals(schoolId) &
          t.isCurrent.equals(true) &
          t.isArchived.equals(false),
    )).getSingleOrNull();
  }

  /// Watches the currently active academic year.
  Stream<AcademicYear?> watchCurrentAcademicYear(String schoolId) {
    return (_db.select(_db.academicYears)..where(
      (t) =>
          t.schoolId.equals(schoolId) &
          t.isCurrent.equals(true) &
          t.isArchived.equals(false),
    )).watchSingleOrNull();
  }

  /// Creates a new academic year.
  Future<AcademicYear> createAcademicYear({
    required String schoolId,
    required String name,
    required DateTime startDate,
    required DateTime endDate,
    bool isCurrent = false,
    String? currentUserId,
  }) async {
    if (endDate.isBefore(startDate)) {
      throw const ValidationException('End date must be after start date.');
    }

    // Check duplicate name
    final existing =
        await (_db.select(_db.academicYears)..where(
          (t) => t.schoolId.equals(schoolId) & t.name.equals(name.trim()),
        )).getSingleOrNull();

    if (existing != null) {
      throw const ConflictException(
        'An academic year with this name already exists.',
      );
    }

    final id = UuidGenerator.v4();
    final now = DateTime.now();

    return await _db.transaction(() async {
      if (isCurrent) {
        // Unset any existing current year
        await (_db.update(_db.academicYears)..where(
          (t) => t.schoolId.equals(schoolId),
        )).write(const AcademicYearsCompanion(isCurrent: Value(false)));
      }

      await _db
          .into(_db.academicYears)
          .insert(
            AcademicYearsCompanion.insert(
              id: id,
              schoolId: schoolId,
              name: name.trim(),
              startDate: startDate,
              endDate: endDate,
              isCurrent: Value(isCurrent),
              createdAt: now,
              updatedAt: now,
            ),
          );

      await _audit.log(
        schoolId: schoolId,
        userId: currentUserId,
        action: AuditAction.academicYearCreated,
        entityType: 'AcademicYear',
        entityId: id,
        metadata: {'name': name, 'isCurrent': isCurrent},
      );

      if (_syncEngine != null) {
        await _syncEngine.enqueue(
          schoolId: schoolId,
          userId: currentUserId ?? 'local_user',
          entityType: SyncEntityType.academicYear,
          entityId: id,
          operation: SyncOperation.create,
          payload: {
            'id': id,
            'schoolId': schoolId,
            'name': name.trim(),
            'startDate': startDate.toIso8601String(),
            'endDate': endDate.toIso8601String(),
            'isCurrent': isCurrent,
            'isArchived': false,
            'createdAt': now.toIso8601String(),
            'updatedAt': now.toIso8601String(),
          },
        );
      }

      return (await (_db.select(_db.academicYears)
        ..where((t) => t.id.equals(id))).getSingle());
    });
  }

  /// Updates an academic year.
  Future<AcademicYear> updateAcademicYear({
    required String id,
    required String schoolId,
    required String name,
    required DateTime startDate,
    required DateTime endDate,
    required bool isCurrent,
    String? currentUserId,
  }) async {
    if (endDate.isBefore(startDate)) {
      throw const ValidationException('End date must be after start date.');
    }

    final now = DateTime.now();

    return await _db.transaction(() async {
      if (isCurrent) {
        await (_db.update(_db.academicYears)..where(
          (t) => t.schoolId.equals(schoolId) & t.id.isNotValue(id),
        )).write(const AcademicYearsCompanion(isCurrent: Value(false)));
      }

      await (_db.update(_db.academicYears)
        ..where((t) => t.id.equals(id))).write(
        AcademicYearsCompanion(
          name: Value(name.trim()),
          startDate: Value(startDate),
          endDate: Value(endDate),
          isCurrent: Value(isCurrent),
          updatedAt: Value(now),
        ),
      );

      await _audit.log(
        schoolId: schoolId,
        userId: currentUserId,
        action: AuditAction.academicYearUpdated,
        entityType: 'AcademicYear',
        entityId: id,
        metadata: {'name': name, 'isCurrent': isCurrent},
      );

      if (_syncEngine != null) {
        await _syncEngine.enqueue(
          schoolId: schoolId,
          userId: currentUserId ?? 'local_user',
          entityType: SyncEntityType.academicYear,
          entityId: id,
          operation: SyncOperation.update,
          payload: {
            'id': id,
            'schoolId': schoolId,
            'name': name.trim(),
            'startDate': startDate.toIso8601String(),
            'endDate': endDate.toIso8601String(),
            'isCurrent': isCurrent,
            'isArchived': false,
            'updatedAt': now.toIso8601String(),
          },
        );
      }

      return (await (_db.select(_db.academicYears)
        ..where((t) => t.id.equals(id))).getSingle());
    });
  }

  /// Sets an academic year as current.
  Future<void> setCurrentYear(
    String id,
    String schoolId, {
    String? currentUserId,
  }) async {
    final now = DateTime.now();
    await _db.transaction(() async {
      await (_db.update(_db.academicYears)..where(
        (t) => t.schoolId.equals(schoolId),
      )).write(const AcademicYearsCompanion(isCurrent: Value(false)));

      await (_db.update(_db.academicYears)
        ..where((t) => t.id.equals(id))).write(
        AcademicYearsCompanion(
          isCurrent: const Value(true),
          updatedAt: Value(now),
        ),
      );

      await _audit.log(
        schoolId: schoolId,
        userId: currentUserId,
        action: AuditAction.academicYearUpdated,
        entityType: 'AcademicYear',
        entityId: id,
        metadata: {'action': 'set_current'},
      );

      if (_syncEngine != null) {
        await _syncEngine.enqueue(
          schoolId: schoolId,
          userId: currentUserId ?? 'local_user',
          entityType: SyncEntityType.academicYear,
          entityId: id,
          operation: SyncOperation.update,
          payload: {
            'id': id,
            'schoolId': schoolId,
            'isCurrent': true,
            'updatedAt': now.toIso8601String(),
          },
        );
      }
    });
  }

  /// Archives an academic year (safe deletion).
  Future<void> archiveAcademicYear(
    String id,
    String schoolId, {
    String? currentUserId,
  }) async {
    final year =
        await (_db.select(_db.academicYears)
          ..where((t) => t.id.equals(id))).getSingleOrNull();

    if (year != null && year.isCurrent) {
      throw const ValidationException(
        'Cannot archive the currently active academic year. Please activate another year first.',
      );
    }

    final now = DateTime.now();
    await _db.transaction(() async {
      await (_db.update(_db.academicYears)
        ..where((t) => t.id.equals(id))).write(
        AcademicYearsCompanion(
          isArchived: const Value(true),
          archivedAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      await _audit.log(
        schoolId: schoolId,
        userId: currentUserId,
        action: AuditAction.academicYearArchived,
        entityType: 'AcademicYear',
        entityId: id,
      );

      if (_syncEngine != null) {
        await _syncEngine.enqueue(
          schoolId: schoolId,
          userId: currentUserId ?? 'local_user',
          entityType: SyncEntityType.academicYear,
          entityId: id,
          operation: SyncOperation.delete,
          payload: {
            'id': id,
            'schoolId': schoolId,
            'isArchived': true,
            'archivedAt': now.toIso8601String(),
            'updatedAt': now.toIso8601String(),
          },
        );
      }
    });
  }

  /// Restores an archived academic year.
  Future<void> restoreAcademicYear(
    String id,
    String schoolId, {
    String? currentUserId,
  }) async {
    final now = DateTime.now();
    await _db.transaction(() async {
      await (_db.update(_db.academicYears)
        ..where((t) => t.id.equals(id))).write(
        AcademicYearsCompanion(
          isArchived: const Value(false),
          archivedAt: const Value(null),
          updatedAt: Value(now),
        ),
      );

      await _audit.log(
        schoolId: schoolId,
        userId: currentUserId,
        action: 'ACADEMIC_YEAR_RESTORED',
        entityType: 'AcademicYear',
        entityId: id,
      );

      if (_syncEngine != null) {
        await _syncEngine.enqueue(
          schoolId: schoolId,
          userId: currentUserId ?? 'local_user',
          entityType: SyncEntityType.academicYear,
          entityId: id,
          operation: SyncOperation.update,
          payload: {
            'id': id,
            'schoolId': schoolId,
            'isArchived': false,
            'archivedAt': null,
            'updatedAt': now.toIso8601String(),
          },
        );
      }
    });
  }
}
