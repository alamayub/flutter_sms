// lib/features/sync/handlers/section_handler.dart
import 'package:drift/drift.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/database/app_database.dart';
import '../client/conflict_manager.dart';
import '../domain/sync_event_model.dart';
import 'entity_sync_handler.dart';

class SectionHandler implements EntitySyncHandler {
  @override
  String get entityType => SyncEntityType.section;

  @override
  bool canHandle(String type) => type == SyncEntityType.section;

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
    final classId = p['classId'] as String? ?? '';

    // Referential integrity check: parent Class must exist
    final parentClass =
        await (db.select(db.schoolClasses)
          ..where((t) => t.id.equals(classId))).getSingleOrNull();

    if (parentClass == null && classId.isNotEmpty) {
      throw MissingDependencyException(SyncEntityType.schoolClass, classId);
    }

    final name = p['name'] as String? ?? 'Unnamed Section';
    final capacity = p['capacity'] as int? ?? 40;
    final classTeacherId = p['classTeacherId'] as String?;
    final isArchived =
        event.operation == SyncOperation.delete ||
        (p['isArchived'] as bool? ?? false);
    final archivedAt =
        p['archivedAt'] != null
            ? DateTime.parse(p['archivedAt'] as String)
            : (isArchived ? DateTime.now() : null);
    final now = DateTime.now();

    final existing =
        await (db.select(db.sections)
          ..where((t) => t.id.equals(id))).getSingleOrNull();

    if (existing != null) {
      await (db.update(db.sections)..where((t) => t.id.equals(id))).write(
        SectionsCompanion(
          classId: Value(classId),
          name: Value(name),
          capacity: Value(capacity),
          classTeacherId: Value(classTeacherId),
          isArchived: Value(isArchived),
          archivedAt: Value(archivedAt),
          updatedAt: Value(now),
        ),
      );
    } else {
      await db
          .into(db.sections)
          .insert(
            SectionsCompanion.insert(
              id: id,
              classId: classId,
              name: name,
              capacity: Value(capacity),
              classTeacherId: Value(classTeacherId),
              isArchived: Value(isArchived),
              archivedAt: Value(archivedAt),
              createdAt: event.timestamp,
              updatedAt: now,
            ),
          );
    }
  }
}
