// lib/features/sync/handlers/subject_handler.dart
import 'package:drift/drift.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/database/app_database.dart';
import '../client/conflict_manager.dart';
import '../domain/sync_event_model.dart';
import 'entity_sync_handler.dart';

class SubjectHandler implements EntitySyncHandler {
  @override
  String get entityType => SyncEntityType.subject;

  @override
  bool canHandle(String type) => type == SyncEntityType.subject;

  @override
  Future<void> apply(
    SyncEventModel event,
    AppDatabase db,
    ConflictManager conflictManager,
  ) async {
    final conflictResult =
        await conflictManager.evaluateConflict(remoteEvent: event);
    final p = conflictResult.mergedPayload;

    final id = event.entityId;
    final schoolId = event.schoolId;
    final name = p['name'] as String? ?? 'Unnamed Subject';
    final code = p['code'] as String? ?? id.substring(0, 4).toUpperCase();
    final description = p['description'] as String?;
    final isActive = p['isActive'] as bool? ?? true;
    final isArchived =
        event.operation == SyncOperation.delete || (p['isArchived'] as bool? ?? false);
    final archivedAt = p['archivedAt'] != null
        ? DateTime.parse(p['archivedAt'] as String)
        : (isArchived ? DateTime.now() : null);
    final now = DateTime.now();

    final existing = await (db.select(db.subjects)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();

    if (existing != null) {
      await (db.update(db.subjects)..where((t) => t.id.equals(id))).write(
        SubjectsCompanion(
          name: Value(name),
          code: Value(code),
          description: Value(description),
          isActive: Value(isActive),
          isArchived: Value(isArchived),
          archivedAt: Value(archivedAt),
          updatedAt: Value(now),
        ),
      );
    } else {
      await db.into(db.subjects).insert(
            SubjectsCompanion.insert(
              id: id,
              schoolId: schoolId,
              name: name,
              code: code,
              description: Value(description),
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

