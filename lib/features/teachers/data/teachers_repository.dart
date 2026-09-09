// lib/features/teachers/data/teachers_repository.dart
import 'package:drift/drift.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_service.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/utils/uuid_generator.dart';
import '../../audit/data/audit_repository.dart';
import '../../auth/data/auth_repository.dart';
import '../../sync/client/sync_engine.dart';
import '../../sync/presentation/sync_controller.dart';

final teachersRepositoryProvider = Provider<TeachersRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final audit = ref.watch(auditRepositoryProvider);
  final auth = ref.watch(authRepositoryProvider);
  final syncEngine = ref.watch(syncEngineProvider);
  return TeachersRepository(db, audit, auth, syncEngine);
});

class TeachersRepository {
  final AppDatabase _db;
  final AuditRepository _audit;
  final AuthRepository _auth;
  final SyncEngine? _syncEngine;

  TeachersRepository(this._db, this._audit, this._auth, [this._syncEngine]);

  /// Gets all active teachers for a school.
  Future<List<Teacher>> getTeachers(
    String schoolId, {
    bool includeInactive = false,
  }) async {
    final query = _db.select(_db.teachers)
      ..where((t) => t.schoolId.equals(schoolId));
    if (!includeInactive) {
      query.where((t) => t.isActive.equals(true));
    }
    query.orderBy([(t) => OrderingTerm.asc(t.name)]);
    return await query.get();
  }

  /// Watch teachers for a school.
  Stream<List<Teacher>> watchTeachers(String schoolId) {
    return (_db.select(_db.teachers)
          ..where((t) => t.schoolId.equals(schoolId) & t.isActive.equals(true))
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch();
  }

  /// Gets teacher by ID.
  Future<Teacher?> getTeacherById(String id) async {
    return await (_db.select(_db.teachers)
      ..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Gets teacher associated with a userId.
  Future<Teacher?> getTeacherByUserId(String userId) async {
    return await (_db.select(_db.teachers)
      ..where((t) => t.userId.equals(userId))).getSingleOrNull();
  }

  /// Creates a teacher. Optionally creates a login user account.
  Future<Teacher> createTeacher({
    required String schoolId,
    required String employeeCode,
    required String name,
    String? phone,
    String? email,
    String? address,
    DateTime? joiningDate,
    bool createLoginAccount = false,
    String? username,
    String? password,
    String? currentUserId,
  }) async {
    final normalizedCode = employeeCode.trim().toUpperCase();

    final existing =
        await (_db.select(_db.teachers)..where(
          (t) =>
              t.schoolId.equals(schoolId) &
              t.employeeCode.equals(normalizedCode),
        )).getSingleOrNull();

    if (existing != null) {
      throw const ConflictException(
        'A teacher with this employee code already exists.',
      );
    }

    String? createdUserId;
    if (createLoginAccount && username != null && password != null) {
      final user = await _auth.createUser(
        schoolId: schoolId,
        name: name,
        username: username,
        email: email,
        password: password,
        role: UserRole.teacher,
        createdByUserId: currentUserId,
      );
      createdUserId = user.id;
    }

    final id = UuidGenerator.v4();
    final now = DateTime.now();

    return await _db.transaction(() async {
      await _db
          .into(_db.teachers)
          .insert(
            TeachersCompanion.insert(
              id: id,
              schoolId: schoolId,
              userId: Value(createdUserId),
              employeeCode: normalizedCode,
              name: name.trim(),
              phone: Value(phone),
              email: Value(email),
              address: Value(address),
              joiningDate: Value(joiningDate),
              isActive: const Value(true),
              isArchived: const Value(false),
              createdAt: now,
              updatedAt: now,
            ),
          );

      await _audit.log(
        schoolId: schoolId,
        userId: currentUserId,
        action: AuditAction.teacherCreated,
        entityType: 'Teacher',
        entityId: id,
        metadata: {'name': name, 'employeeCode': normalizedCode},
      );

      if (_syncEngine != null) {
        await _syncEngine.enqueue(
          schoolId: schoolId,
          userId: currentUserId ?? 'local_user',
          entityType: SyncEntityType.teacher,
          entityId: id,
          operation: SyncOperation.create,
          payload: {
            'id': id,
            'schoolId': schoolId,
            'employeeCode': normalizedCode,
            'name': name.trim(),
            'phone': phone,
            'email': email,
            'address': address,
            'joiningDate': joiningDate?.toIso8601String(),
            'isActive': true,
            'isArchived': false,
            'userId': createdUserId,
            'createdAt': now.toIso8601String(),
            'updatedAt': now.toIso8601String(),
          },
        );
      }

      return (await getTeacherById(id))!;
    });
  }

  /// Updates a teacher.
  Future<Teacher> updateTeacher({
    required String id,
    required String employeeCode,
    required String name,
    String? phone,
    String? email,
    String? address,
    DateTime? joiningDate,
    required bool isActive,
    String? currentUserId,
  }) async {
    final now = DateTime.now();

    return await _db.transaction(() async {
      await (_db.update(_db.teachers)..where((t) => t.id.equals(id))).write(
        TeachersCompanion(
          employeeCode: Value(employeeCode.trim().toUpperCase()),
          name: Value(name.trim()),
          phone: Value(phone),
          email: Value(email),
          address: Value(address),
          joiningDate: Value(joiningDate),
          isActive: Value(isActive),
          updatedAt: Value(now),
        ),
      );

      await _audit.log(
        userId: currentUserId,
        action: AuditAction.teacherUpdated,
        entityType: 'Teacher',
        entityId: id,
        metadata: {'name': name},
      );

      if (_syncEngine != null) {
        final t = await getTeacherById(id);
        if (t != null) {
          await _syncEngine.enqueue(
            schoolId: t.schoolId,
            userId: currentUserId ?? 'local_user',
            entityType: SyncEntityType.teacher,
            entityId: id,
            operation: SyncOperation.update,
            payload: {
              'id': id,
              'schoolId': t.schoolId,
              'employeeCode': employeeCode.trim().toUpperCase(),
              'name': name.trim(),
              'phone': phone,
              'email': email,
              'address': address,
              'joiningDate': joiningDate?.toIso8601String(),
              'isActive': isActive,
              'updatedAt': now.toIso8601String(),
            },
          );
        }
      }

      return (await getTeacherById(id))!;
    });
  }

  /// Archives/deactivates a teacher.
  Future<void> archiveTeacher(String id, {String? currentUserId}) async {
    final now = DateTime.now();
    await _db.transaction(() async {
      await (_db.update(_db.teachers)..where((t) => t.id.equals(id))).write(
        TeachersCompanion(
          isActive: const Value(false),
          isArchived: const Value(true),
          archivedAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      await _audit.log(
        userId: currentUserId,
        action: AuditAction.teacherArchived,
        entityType: 'Teacher',
        entityId: id,
      );

      if (_syncEngine != null) {
        final t = await getTeacherById(id);
        if (t != null) {
          await _syncEngine.enqueue(
            schoolId: t.schoolId,
            userId: currentUserId ?? 'local_user',
            entityType: SyncEntityType.teacher,
            entityId: id,
            operation: SyncOperation.delete,
            payload: {
              'id': id,
              'schoolId': t.schoolId,
              'isActive': false,
              'isArchived': true,
              'archivedAt': now.toIso8601String(),
              'updatedAt': now.toIso8601String(),
            },
          );
        }
      }
    });
  }

  /// Restores an archived teacher.
  Future<void> restoreTeacher(String id, {String? currentUserId}) async {
    final now = DateTime.now();
    await _db.transaction(() async {
      await (_db.update(_db.teachers)..where((t) => t.id.equals(id))).write(
        TeachersCompanion(
          isActive: const Value(true),
          isArchived: const Value(false),
          archivedAt: const Value(null),
          updatedAt: Value(now),
        ),
      );

      await _audit.log(
        userId: currentUserId,
        action: 'TEACHER_RESTORED',
        entityType: 'Teacher',
        entityId: id,
      );

      if (_syncEngine != null) {
        final t = await getTeacherById(id);
        if (t != null) {
          await _syncEngine.enqueue(
            schoolId: t.schoolId,
            userId: currentUserId ?? 'local_user',
            entityType: SyncEntityType.teacher,
            entityId: id,
            operation: SyncOperation.update,
            payload: {
              'id': id,
              'schoolId': t.schoolId,
              'isActive': true,
              'isArchived': false,
              'archivedAt': null,
              'updatedAt': now.toIso8601String(),
            },
          );
        }
      }
    });
  }
}
