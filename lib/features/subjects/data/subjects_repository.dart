// lib/features/subjects/data/subjects_repository.dart
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

final subjectsRepositoryProvider = Provider<SubjectsRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final audit = ref.watch(auditRepositoryProvider);
  final syncEngine = ref.watch(syncEngineProvider);
  return SubjectsRepository(db, audit, syncEngine);
});

class SubjectWithTeacher {
  final Subject subject;
  final Teacher? teacher;
  final String classSubjectId;

  SubjectWithTeacher({
    required this.subject,
    this.teacher,
    required this.classSubjectId,
  });
}

class SubjectsRepository {
  final AppDatabase _db;
  final AuditRepository _audit;
  final SyncEngine? _syncEngine;

  SubjectsRepository(this._db, this._audit, [this._syncEngine]);

  /// Gets all active subjects for a school.
  Future<List<Subject>> getSubjects(
    String schoolId, {
    bool includeInactive = false,
    bool includeArchived = false,
  }) async {
    final query = _db.select(_db.subjects)
      ..where((t) => t.schoolId.equals(schoolId));
    if (!includeInactive) {
      query.where((t) => t.isActive.equals(true));
    }
    if (!includeArchived) {
      query.where((t) => t.isArchived.equals(false));
    }
    query.orderBy([(t) => OrderingTerm.asc(t.name)]);
    return await query.get();
  }

  /// Watch subjects for a school.
  Stream<List<Subject>> watchSubjects(String schoolId) {
    return (_db.select(_db.subjects)
          ..where(
            (t) =>
                t.schoolId.equals(schoolId) &
                t.isActive.equals(true) &
                t.isArchived.equals(false),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch();
  }

  /// Creates a subject.
  Future<Subject> createSubject({
    required String schoolId,
    required String name,
    required String code,
    String? description,
    String? currentUserId,
  }) async {
    final normalizedCode = code.trim().toUpperCase();

    final existing =
        await (_db.select(_db.subjects)..where(
          (t) => t.schoolId.equals(schoolId) & t.code.equals(normalizedCode),
        )).getSingleOrNull();

    if (existing != null) {
      throw const ConflictException(
        'A subject with this code already exists in this school.',
      );
    }

    final id = UuidGenerator.v4();
    final now = DateTime.now();

    return await _db.transaction(() async {
      await _db
          .into(_db.subjects)
          .insert(
            SubjectsCompanion.insert(
              id: id,
              schoolId: schoolId,
              name: name.trim(),
              code: normalizedCode,
              description: Value(description),
              isActive: const Value(true),
              isArchived: const Value(false),
              createdAt: now,
              updatedAt: now,
            ),
          );

      await _audit.log(
        schoolId: schoolId,
        userId: currentUserId,
        action: AuditAction.subjectCreated,
        entityType: 'Subject',
        entityId: id,
        metadata: {'name': name, 'code': normalizedCode},
      );

      if (_syncEngine != null) {
        await _syncEngine.enqueue(
          schoolId: schoolId,
          userId: currentUserId ?? 'local_user',
          entityType: SyncEntityType.subject,
          entityId: id,
          operation: SyncOperation.create,
          payload: {
            'id': id,
            'schoolId': schoolId,
            'name': name.trim(),
            'code': normalizedCode,
            'description': description,
            'isActive': true,
            'isArchived': false,
            'createdAt': now.toIso8601String(),
            'updatedAt': now.toIso8601String(),
          },
        );
      }

      return (await (_db.select(_db.subjects)
        ..where((t) => t.id.equals(id))).getSingle());
    });
  }

  /// Updates a subject.
  Future<Subject> updateSubject({
    required String id,
    required String name,
    required String code,
    String? description,
    required bool isActive,
    String? currentUserId,
  }) async {
    final existing =
        await (_db.select(_db.subjects)
          ..where((t) => t.id.equals(id))).getSingleOrNull();
    final now = DateTime.now();
    return await _db.transaction(() async {
      await (_db.update(_db.subjects)..where((t) => t.id.equals(id))).write(
        SubjectsCompanion(
          name: Value(name.trim()),
          code: Value(code.trim().toUpperCase()),
          description: Value(description),
          isActive: Value(isActive),
          updatedAt: Value(now),
        ),
      );

      await _audit.log(
        userId: currentUserId,
        action: AuditAction.subjectUpdated,
        entityType: 'Subject',
        entityId: id,
        metadata: {'name': name},
      );

      if (_syncEngine != null && existing != null) {
        await _syncEngine.enqueue(
          schoolId: existing.schoolId,
          userId: currentUserId ?? 'local_user',
          entityType: SyncEntityType.subject,
          entityId: id,
          operation: SyncOperation.update,
          payload: {
            'id': id,
            'schoolId': existing.schoolId,
            'name': name.trim(),
            'code': code.trim().toUpperCase(),
            'description': description,
            'isActive': isActive,
            'isArchived': existing.isArchived,
            'updatedAt': now.toIso8601String(),
          },
        );
      }

      return (await (_db.select(_db.subjects)
        ..where((t) => t.id.equals(id))).getSingle());
    });
  }

  /// Archives a subject.
  Future<void> archiveSubject(String id, {String? currentUserId}) async {
    final existing =
        await (_db.select(_db.subjects)
          ..where((t) => t.id.equals(id))).getSingleOrNull();
    final now = DateTime.now();
    await _db.transaction(() async {
      await (_db.update(_db.subjects)..where((t) => t.id.equals(id))).write(
        SubjectsCompanion(
          isActive: const Value(false),
          isArchived: const Value(true),
          archivedAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      await _audit.log(
        userId: currentUserId,
        action: AuditAction.subjectArchived,
        entityType: 'Subject',
        entityId: id,
      );

      if (_syncEngine != null && existing != null) {
        await _syncEngine.enqueue(
          schoolId: existing.schoolId,
          userId: currentUserId ?? 'local_user',
          entityType: SyncEntityType.subject,
          entityId: id,
          operation: SyncOperation.delete,
          payload: {
            'id': id,
            'schoolId': existing.schoolId,
            'isActive': false,
            'isArchived': true,
            'archivedAt': now.toIso8601String(),
            'updatedAt': now.toIso8601String(),
          },
        );
      }
    });
  }

  /// Restores an archived subject.
  Future<void> restoreSubject(String id, {String? currentUserId}) async {
    final existing =
        await (_db.select(_db.subjects)
          ..where((t) => t.id.equals(id))).getSingleOrNull();
    final now = DateTime.now();
    await _db.transaction(() async {
      await (_db.update(_db.subjects)..where((t) => t.id.equals(id))).write(
        SubjectsCompanion(
          isActive: const Value(true),
          isArchived: const Value(false),
          archivedAt: const Value(null),
          updatedAt: Value(now),
        ),
      );

      await _audit.log(
        userId: currentUserId,
        action: 'SUBJECT_RESTORED',
        entityType: 'Subject',
        entityId: id,
      );

      if (_syncEngine != null && existing != null) {
        await _syncEngine.enqueue(
          schoolId: existing.schoolId,
          userId: currentUserId ?? 'local_user',
          entityType: SyncEntityType.subject,
          entityId: id,
          operation: SyncOperation.update,
          payload: {
            'id': id,
            'schoolId': existing.schoolId,
            'isActive': true,
            'isArchived': false,
            'archivedAt': null,
            'updatedAt': now.toIso8601String(),
          },
        );
      }
    });
  }

  /// Assigns a subject to a class with an optional assigned teacher.
  Future<void> assignSubjectToClass({
    required String classId,
    required String subjectId,
    String? teacherId,
  }) async {
    final existing =
        await (_db.select(_db.classSubjects)..where(
          (t) => t.classId.equals(classId) & t.subjectId.equals(subjectId),
        )).getSingleOrNull();

    final now = DateTime.now();

    await _db.transaction(() async {
      if (existing != null) {
        await (_db.update(_db.classSubjects)
          ..where((t) => t.id.equals(existing.id))).write(
          ClassSubjectsCompanion(
            teacherId: Value(teacherId),
            updatedAt: Value(now),
          ),
        );
      } else {
        await _db
            .into(_db.classSubjects)
            .insert(
              ClassSubjectsCompanion.insert(
                id: UuidGenerator.v4(),
                classId: classId,
                subjectId: subjectId,
                teacherId: Value(teacherId),
                createdAt: now,
                updatedAt: now,
              ),
            );
      }
    });
  }

  /// Removes a subject assignment from a class.
  Future<void> removeSubjectFromClass(String classId, String subjectId) async {
    await (_db.delete(_db.classSubjects)..where(
      (t) => t.classId.equals(classId) & t.subjectId.equals(subjectId),
    )).go();
  }

  /// Gets all subjects assigned to a class with teacher details.
  Future<List<SubjectWithTeacher>> getSubjectsForClass(String classId) async {
    final classSubjects =
        await (_db.select(_db.classSubjects)
          ..where((t) => t.classId.equals(classId))).get();

    final result = <SubjectWithTeacher>[];

    for (final cs in classSubjects) {
      final subject =
          await (_db.select(_db.subjects)
            ..where((t) => t.id.equals(cs.subjectId))).getSingleOrNull();

      if (subject == null) continue;

      Teacher? teacher;
      if (cs.teacherId != null) {
        teacher =
            await (_db.select(_db.teachers)
              ..where((t) => t.id.equals(cs.teacherId!))).getSingleOrNull();
      }

      result.add(
        SubjectWithTeacher(
          subject: subject,
          teacher: teacher,
          classSubjectId: cs.id,
        ),
      );
    }

    return result;
  }
}
