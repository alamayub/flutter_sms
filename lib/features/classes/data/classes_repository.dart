// lib/features/classes/data/classes_repository.dart
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

final classesRepositoryProvider = Provider<ClassesRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final audit = ref.watch(auditRepositoryProvider);
  final syncEngine = ref.watch(syncEngineProvider);
  return ClassesRepository(db, audit, syncEngine);
});

class ClassWithSections {
  final SchoolClass schoolClass;
  final List<Section> sections;

  ClassWithSections({required this.schoolClass, required this.sections});
}

class ClassesRepository {
  final AppDatabase _db;
  final AuditRepository _audit;
  final SyncEngine? _syncEngine;

  ClassesRepository(this._db, this._audit, [this._syncEngine]);

  /// Gets all active classes for an academic year.
  Future<List<SchoolClass>> getClasses({
    required String schoolId,
    required String academicYearId,
    bool includeArchived = false,
  }) async {
    final query = _db.select(_db.schoolClasses)..where(
      (t) =>
          t.schoolId.equals(schoolId) & t.academicYearId.equals(academicYearId),
    );
    if (!includeArchived) {
      query.where((t) => t.isArchived.equals(false));
    }
    query.orderBy([
      (t) => OrderingTerm.asc(t.displayOrder),
      (t) => OrderingTerm.asc(t.name),
    ]);
    return await query.get();
  }

  /// Watch classes for an academic year.
  Stream<List<SchoolClass>> watchClasses({
    required String schoolId,
    required String academicYearId,
  }) {
    return (_db.select(_db.schoolClasses)
          ..where(
            (t) =>
                t.schoolId.equals(schoolId) &
                t.academicYearId.equals(academicYearId) &
                t.isArchived.equals(false),
          )
          ..orderBy([
            (t) => OrderingTerm.asc(t.displayOrder),
            (t) => OrderingTerm.asc(t.name),
          ]))
        .watch();
  }

  /// Creates a class.
  Future<SchoolClass> createClass({
    required String schoolId,
    required String academicYearId,
    required String name,
    int displayOrder = 0,
    String? currentUserId,
  }) async {
    final existing =
        await (_db.select(_db.schoolClasses)..where(
          (t) =>
              t.schoolId.equals(schoolId) &
              t.academicYearId.equals(academicYearId) &
              t.name.equals(name.trim()) &
              t.isArchived.equals(false),
        )).getSingleOrNull();

    if (existing != null) {
      throw const ConflictException(
        'A class with this name already exists in the academic year.',
      );
    }

    final id = UuidGenerator.v4();
    final now = DateTime.now();

    return await _db.transaction(() async {
      await _db
          .into(_db.schoolClasses)
          .insert(
            SchoolClassesCompanion.insert(
              id: id,
              schoolId: schoolId,
              academicYearId: academicYearId,
              name: name.trim(),
              displayOrder: Value(displayOrder),
              createdAt: now,
              updatedAt: now,
            ),
          );

      await _audit.log(
        schoolId: schoolId,
        userId: currentUserId,
        action: AuditAction.classCreated,
        entityType: 'Class',
        entityId: id,
        metadata: {'name': name},
      );

      if (_syncEngine != null) {
        await _syncEngine.enqueue(
          schoolId: schoolId,
          userId: currentUserId ?? 'local_user',
          entityType: SyncEntityType.schoolClass,
          entityId: id,
          operation: SyncOperation.create,
          payload: {
            'id': id,
            'schoolId': schoolId,
            'academicYearId': academicYearId,
            'name': name.trim(),
            'displayOrder': displayOrder,
            'isArchived': false,
            'createdAt': now.toIso8601String(),
            'updatedAt': now.toIso8601String(),
          },
        );
      }

      return (await (_db.select(_db.schoolClasses)
        ..where((t) => t.id.equals(id))).getSingle());
    });
  }

  /// Updates a class.
  Future<SchoolClass> updateClass({
    required String id,
    required String name,
    required int displayOrder,
    String? currentUserId,
  }) async {
    final existing =
        await (_db.select(_db.schoolClasses)
          ..where((t) => t.id.equals(id))).getSingleOrNull();
    final now = DateTime.now();
    return await _db.transaction(() async {
      await (_db.update(_db.schoolClasses)
        ..where((t) => t.id.equals(id))).write(
        SchoolClassesCompanion(
          name: Value(name.trim()),
          displayOrder: Value(displayOrder),
          updatedAt: Value(now),
        ),
      );

      await _audit.log(
        userId: currentUserId,
        action: AuditAction.classUpdated,
        entityType: 'Class',
        entityId: id,
        metadata: {'name': name},
      );

      if (_syncEngine != null && existing != null) {
        await _syncEngine.enqueue(
          schoolId: existing.schoolId,
          userId: currentUserId ?? 'local_user',
          entityType: SyncEntityType.schoolClass,
          entityId: id,
          operation: SyncOperation.update,
          payload: {
            'id': id,
            'schoolId': existing.schoolId,
            'academicYearId': existing.academicYearId,
            'name': name.trim(),
            'displayOrder': displayOrder,
            'isArchived': existing.isArchived,
            'updatedAt': now.toIso8601String(),
          },
        );
      }

      return (await (_db.select(_db.schoolClasses)
        ..where((t) => t.id.equals(id))).getSingle());
    });
  }

  /// Archives a class.
  Future<void> archiveClass(String id, {String? currentUserId}) async {
    final existing =
        await (_db.select(_db.schoolClasses)
          ..where((t) => t.id.equals(id))).getSingleOrNull();
    final now = DateTime.now();
    await _db.transaction(() async {
      await (_db.update(_db.schoolClasses)
        ..where((t) => t.id.equals(id))).write(
        SchoolClassesCompanion(
          isArchived: const Value(true),
          archivedAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      await _audit.log(
        userId: currentUserId,
        action: AuditAction.classArchived,
        entityType: 'Class',
        entityId: id,
      );

      if (_syncEngine != null && existing != null) {
        await _syncEngine.enqueue(
          schoolId: existing.schoolId,
          userId: currentUserId ?? 'local_user',
          entityType: SyncEntityType.schoolClass,
          entityId: id,
          operation: SyncOperation.delete,
          payload: {
            'id': id,
            'schoolId': existing.schoolId,
            'isArchived': true,
            'archivedAt': now.toIso8601String(),
            'updatedAt': now.toIso8601String(),
          },
        );
      }
    });
  }

  /// Restores an archived class.
  Future<void> restoreClass(String id, {String? currentUserId}) async {
    final existing =
        await (_db.select(_db.schoolClasses)
          ..where((t) => t.id.equals(id))).getSingleOrNull();
    final now = DateTime.now();
    await _db.transaction(() async {
      await (_db.update(_db.schoolClasses)
        ..where((t) => t.id.equals(id))).write(
        SchoolClassesCompanion(
          isArchived: const Value(false),
          archivedAt: const Value(null),
          updatedAt: Value(now),
        ),
      );
      await _audit.log(
        userId: currentUserId,
        action: 'CLASS_RESTORED',
        entityType: 'Class',
        entityId: id,
      );

      if (_syncEngine != null && existing != null) {
        await _syncEngine.enqueue(
          schoolId: existing.schoolId,
          userId: currentUserId ?? 'local_user',
          entityType: SyncEntityType.schoolClass,
          entityId: id,
          operation: SyncOperation.update,
          payload: {
            'id': id,
            'schoolId': existing.schoolId,
            'isArchived': false,
            'archivedAt': null,
            'updatedAt': now.toIso8601String(),
          },
        );
      }
    });
  }

  // --- SECTIONS ---

  /// Gets sections for a class.
  Future<List<Section>> getSections(
    String classId, {
    bool includeArchived = false,
  }) async {
    final query = _db.select(_db.sections)
      ..where((t) => t.classId.equals(classId));
    if (!includeArchived) {
      query.where((t) => t.isArchived.equals(false));
    }
    query.orderBy([(t) => OrderingTerm.asc(t.name)]);
    return await query.get();
  }

  /// Watch sections for a class.
  Stream<List<Section>> watchSections(String classId) {
    return (_db.select(_db.sections)
          ..where((t) => t.classId.equals(classId) & t.isArchived.equals(false))
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch();
  }

  /// Creates a section.
  Future<Section> createSection({
    required String classId,
    required String name,
    int capacity = 40,
    String? classTeacherId,
    String? currentUserId,
  }) async {
    final existing =
        await (_db.select(_db.sections)..where(
          (t) =>
              t.classId.equals(classId) &
              t.name.equals(name.trim()) &
              t.isArchived.equals(false),
        )).getSingleOrNull();

    if (existing != null) {
      throw const ConflictException(
        'A section with this name already exists in this class.',
      );
    }

    final parentClass =
        await (_db.select(_db.schoolClasses)
          ..where((t) => t.id.equals(classId))).getSingleOrNull();
    final schoolId = parentClass?.schoolId ?? '';
    final id = UuidGenerator.v4();
    final now = DateTime.now();

    return await _db.transaction(() async {
      await _db
          .into(_db.sections)
          .insert(
            SectionsCompanion.insert(
              id: id,
              classId: classId,
              name: name.trim(),
              capacity: Value(capacity),
              classTeacherId: Value(classTeacherId),
              createdAt: now,
              updatedAt: now,
            ),
          );

      await _audit.log(
        userId: currentUserId,
        action: AuditAction.sectionCreated,
        entityType: 'Section',
        entityId: id,
        metadata: {'name': name, 'classId': classId},
      );

      if (_syncEngine != null) {
        await _syncEngine.enqueue(
          schoolId: schoolId,
          userId: currentUserId ?? 'local_user',
          entityType: SyncEntityType.section,
          entityId: id,
          operation: SyncOperation.create,
          payload: {
            'id': id,
            'schoolId': schoolId,
            'classId': classId,
            'name': name.trim(),
            'capacity': capacity,
            'classTeacherId': classTeacherId,
            'isArchived': false,
            'createdAt': now.toIso8601String(),
            'updatedAt': now.toIso8601String(),
          },
        );
      }

      return (await (_db.select(_db.sections)
        ..where((t) => t.id.equals(id))).getSingle());
    });
  }

  /// Updates a section.
  Future<Section> updateSection({
    required String id,
    required String name,
    required int capacity,
    String? classTeacherId,
    String? currentUserId,
  }) async {
    final existing =
        await (_db.select(_db.sections)
          ..where((t) => t.id.equals(id))).getSingleOrNull();
    final parentClass =
        existing != null
            ? await (_db.select(_db.schoolClasses)
              ..where((t) => t.id.equals(existing.classId))).getSingleOrNull()
            : null;
    final schoolId = parentClass?.schoolId ?? '';
    final now = DateTime.now();

    return await _db.transaction(() async {
      await (_db.update(_db.sections)..where((t) => t.id.equals(id))).write(
        SectionsCompanion(
          name: Value(name.trim()),
          capacity: Value(capacity),
          classTeacherId: Value(classTeacherId),
          updatedAt: Value(now),
        ),
      );

      await _audit.log(
        userId: currentUserId,
        action: AuditAction.sectionUpdated,
        entityType: 'Section',
        entityId: id,
        metadata: {'name': name},
      );

      if (_syncEngine != null && existing != null) {
        await _syncEngine.enqueue(
          schoolId: schoolId,
          userId: currentUserId ?? 'local_user',
          entityType: SyncEntityType.section,
          entityId: id,
          operation: SyncOperation.update,
          payload: {
            'id': id,
            'schoolId': schoolId,
            'classId': existing.classId,
            'name': name.trim(),
            'capacity': capacity,
            'classTeacherId': classTeacherId,
            'isArchived': existing.isArchived,
            'updatedAt': now.toIso8601String(),
          },
        );
      }

      return (await (_db.select(_db.sections)
        ..where((t) => t.id.equals(id))).getSingle());
    });
  }

  /// Assigns a class teacher to a section.
  Future<void> assignClassTeacher(
    String sectionId,
    String? teacherId, {
    String? currentUserId,
  }) async {
    final existing =
        await (_db.select(_db.sections)
          ..where((t) => t.id.equals(sectionId))).getSingleOrNull();
    final parentClass =
        existing != null
            ? await (_db.select(_db.schoolClasses)
              ..where((t) => t.id.equals(existing.classId))).getSingleOrNull()
            : null;
    final schoolId = parentClass?.schoolId ?? '';
    final now = DateTime.now();

    await _db.transaction(() async {
      await (_db.update(_db.sections)
        ..where((t) => t.id.equals(sectionId))).write(
        SectionsCompanion(
          classTeacherId: Value(teacherId),
          updatedAt: Value(now),
        ),
      );
      await _audit.log(
        userId: currentUserId,
        action: 'SECTION_TEACHER_ASSIGNED',
        entityType: 'Section',
        entityId: sectionId,
        metadata: {'teacherId': teacherId},
      );

      if (_syncEngine != null && existing != null) {
        await _syncEngine.enqueue(
          schoolId: schoolId,
          userId: currentUserId ?? 'local_user',
          entityType: SyncEntityType.section,
          entityId: sectionId,
          operation: SyncOperation.update,
          payload: {
            'id': sectionId,
            'schoolId': schoolId,
            'classId': existing.classId,
            'name': existing.name,
            'capacity': existing.capacity,
            'classTeacherId': teacherId,
            'isArchived': existing.isArchived,
            'updatedAt': now.toIso8601String(),
          },
        );
      }
    });
  }

  /// Archives a section.
  Future<void> archiveSection(String id, {String? currentUserId}) async {
    final existing =
        await (_db.select(_db.sections)
          ..where((t) => t.id.equals(id))).getSingleOrNull();
    final parentClass =
        existing != null
            ? await (_db.select(_db.schoolClasses)
              ..where((t) => t.id.equals(existing.classId))).getSingleOrNull()
            : null;
    final schoolId = parentClass?.schoolId ?? '';
    final now = DateTime.now();

    await _db.transaction(() async {
      await (_db.update(_db.sections)..where((t) => t.id.equals(id))).write(
        SectionsCompanion(
          isArchived: const Value(true),
          archivedAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      await _audit.log(
        userId: currentUserId,
        action: AuditAction.sectionArchived,
        entityType: 'Section',
        entityId: id,
      );

      if (_syncEngine != null && existing != null) {
        await _syncEngine.enqueue(
          schoolId: schoolId,
          userId: currentUserId ?? 'local_user',
          entityType: SyncEntityType.section,
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

  /// Restores an archived section.
  Future<void> restoreSection(String id, {String? currentUserId}) async {
    final existing =
        await (_db.select(_db.sections)
          ..where((t) => t.id.equals(id))).getSingleOrNull();
    final parentClass =
        existing != null
            ? await (_db.select(_db.schoolClasses)
              ..where((t) => t.id.equals(existing.classId))).getSingleOrNull()
            : null;
    final schoolId = parentClass?.schoolId ?? '';
    final now = DateTime.now();

    await _db.transaction(() async {
      await (_db.update(_db.sections)..where((t) => t.id.equals(id))).write(
        SectionsCompanion(
          isArchived: const Value(false),
          archivedAt: const Value(null),
          updatedAt: Value(now),
        ),
      );
      await _audit.log(
        userId: currentUserId,
        action: 'SECTION_RESTORED',
        entityType: 'Section',
        entityId: id,
      );

      if (_syncEngine != null && existing != null) {
        await _syncEngine.enqueue(
          schoolId: schoolId,
          userId: currentUserId ?? 'local_user',
          entityType: SyncEntityType.section,
          entityId: id,
          operation: SyncOperation.update,
          payload: {
            'id': id,
            'schoolId': schoolId,
            'classId': existing.classId,
            'name': existing.name,
            'capacity': existing.capacity,
            'classTeacherId': existing.classTeacherId,
            'isArchived': false,
            'archivedAt': null,
            'updatedAt': now.toIso8601String(),
          },
        );
      }
    });
  }

  /// Gets all classes with their sections for an academic year.
  Future<List<ClassWithSections>> getClassesWithSections({
    required String schoolId,
    required String academicYearId,
  }) async {
    final classes = await getClasses(
      schoolId: schoolId,
      academicYearId: academicYearId,
    );
    final result = <ClassWithSections>[];

    for (final c in classes) {
      final sections = await getSections(c.id);
      result.add(ClassWithSections(schoolClass: c, sections: sections));
    }

    return result;
  }
}
