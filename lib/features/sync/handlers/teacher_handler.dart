// lib/features/sync/handlers/teacher_handler.dart
import 'package:drift/drift.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/database/app_database.dart';
import '../client/conflict_manager.dart';
import '../domain/sync_event_model.dart';
import 'entity_sync_handler.dart';

class TeacherHandler implements EntitySyncHandler {
  @override
  String get entityType => SyncEntityType.teacher;

  @override
  bool canHandle(String type) => type == SyncEntityType.teacher;

  @override
  Future<void> apply(
    SyncEventModel event,
    AppDatabase db,
    ConflictManager conflictManager,
  ) async {
    final conflictResult = await conflictManager.evaluateConflict(
      remoteEvent: event,
    );
    final p = conflictResult.mergedPayload;

    final id = event.entityId;
    final schoolId = event.schoolId;
    final employeeCode =
        p['employeeCode'] as String? ?? id.substring(0, 6).toUpperCase();
    final name = p['name'] as String? ?? 'Unnamed Teacher';
    final phone = p['phone'] as String?;
    final email = p['email'] as String?;
    final address = p['address'] as String?;
    final userId = p['userId'] as String?;
    final joiningDate =
        p['joiningDate'] != null
            ? DateTime.parse(p['joiningDate'] as String)
            : null;
    final isActive = p['isActive'] as bool? ?? true;
    final isArchived =
        event.operation == SyncOperation.delete ||
        (p['isArchived'] as bool? ?? false);
    final archivedAt =
        p['archivedAt'] != null
            ? DateTime.parse(p['archivedAt'] as String)
            : (isArchived ? DateTime.now() : null);
    final now = DateTime.now();

    final existing =
        await (db.select(db.teachers)
          ..where((t) => t.id.equals(id))).getSingleOrNull();

    if (existing != null) {
      await (db.update(db.teachers)..where((t) => t.id.equals(id))).write(
        TeachersCompanion(
          employeeCode: Value(employeeCode),
          name: Value(name),
          phone: Value(phone),
          email: Value(email),
          address: Value(address),
          userId: Value(userId),
          joiningDate: Value(joiningDate),
          isActive: Value(isActive),
          isArchived: Value(isArchived),
          archivedAt: Value(archivedAt),
          updatedAt: Value(now),
        ),
      );
    } else {
      await db
          .into(db.teachers)
          .insert(
            TeachersCompanion.insert(
              id: id,
              schoolId: schoolId,
              employeeCode: employeeCode,
              name: name,
              phone: Value(phone),
              email: Value(email),
              address: Value(address),
              userId: Value(userId),
              joiningDate: Value(joiningDate),
              isActive: Value(isActive),
              isArchived: Value(isArchived),
              archivedAt: Value(archivedAt),
              createdAt: event.timestamp,
              updatedAt: now,
            ),
          );
    }
  }
}
