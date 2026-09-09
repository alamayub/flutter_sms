// lib/features/sync/handlers/class_handler.dart
import 'package:drift/drift.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/database/app_database.dart';
import '../client/conflict_manager.dart';
import '../domain/sync_event_model.dart';
import 'entity_sync_handler.dart';

class ClassHandler implements EntitySyncHandler {
  @override
  String get entityType => SyncEntityType.schoolClass;

  @override
  bool canHandle(String type) =>
      type == SyncEntityType.schoolClass ||
      type == 'class' ||
      type == 'schoolClasses';

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
    final academicYearId = p['academicYearId'] as String? ?? '';
    final name = p['name'] as String? ?? 'Unnamed Class';
    final displayOrder = p['displayOrder'] as int? ?? 0;
    final isArchived =
        event.operation == SyncOperation.delete ||
        (p['isArchived'] as bool? ?? false);
    final archivedAt =
        p['archivedAt'] != null
            ? DateTime.parse(p['archivedAt'] as String)
            : (isArchived ? DateTime.now() : null);
    final now = DateTime.now();

    final existing =
        await (db.select(db.schoolClasses)
          ..where((t) => t.id.equals(id))).getSingleOrNull();

    if (existing != null) {
      await (db.update(db.schoolClasses)..where((t) => t.id.equals(id))).write(
        SchoolClassesCompanion(
          academicYearId: Value(academicYearId),
          name: Value(name),
          displayOrder: Value(displayOrder),
          isArchived: Value(isArchived),
          archivedAt: Value(archivedAt),
          updatedAt: Value(now),
        ),
      );
    } else {
      await db
          .into(db.schoolClasses)
          .insert(
            SchoolClassesCompanion.insert(
              id: id,
              schoolId: schoolId,
              academicYearId: academicYearId,
              name: name,
              displayOrder: Value(displayOrder),
              isArchived: Value(isArchived),
              archivedAt: Value(archivedAt),
              createdAt: event.timestamp,
              updatedAt: now,
            ),
          );
    }
  }
}
