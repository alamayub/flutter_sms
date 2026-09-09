// lib/features/sync/handlers/academic_year_handler.dart
import 'package:drift/drift.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/database/app_database.dart';
import '../client/conflict_manager.dart';
import '../domain/sync_event_model.dart';
import 'entity_sync_handler.dart';

class AcademicYearHandler implements EntitySyncHandler {
  @override
  String get entityType => SyncEntityType.academicYear;

  @override
  bool canHandle(String type) =>
      type == SyncEntityType.academicYear || type == 'academicYear';

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
    final name = p['name'] as String? ?? 'Unnamed Year';
    final startDate =
        p['startDate'] != null
            ? DateTime.parse(p['startDate'] as String)
            : DateTime.now();
    final endDate =
        p['endDate'] != null
            ? DateTime.parse(p['endDate'] as String)
            : DateTime.now().add(const Duration(days: 365));
    final isCurrent = p['isCurrent'] as bool? ?? false;
    final isArchived =
        event.operation == SyncOperation.delete ||
        (p['isArchived'] as bool? ?? false);
    final archivedAt =
        p['archivedAt'] != null
            ? DateTime.parse(p['archivedAt'] as String)
            : (isArchived ? DateTime.now() : null);
    final now = DateTime.now();

    // Enforce exactly one current academic year if isCurrent is true
    if (isCurrent) {
      await (db.update(db.academicYears)..where(
        (t) => t.schoolId.equals(schoolId) & t.id.isNotValue(id),
      )).write(const AcademicYearsCompanion(isCurrent: Value(false)));
    }

    final existing =
        await (db.select(db.academicYears)
          ..where((t) => t.id.equals(id))).getSingleOrNull();

    if (existing != null) {
      await (db.update(db.academicYears)..where((t) => t.id.equals(id))).write(
        AcademicYearsCompanion(
          name: Value(name),
          startDate: Value(startDate),
          endDate: Value(endDate),
          isCurrent: Value(isCurrent),
          isArchived: Value(isArchived),
          archivedAt: Value(archivedAt),
          updatedAt: Value(now),
        ),
      );
    } else {
      await db
          .into(db.academicYears)
          .insert(
            AcademicYearsCompanion.insert(
              id: id,
              schoolId: schoolId,
              name: name,
              startDate: startDate,
              endDate: endDate,
              isCurrent: Value(isCurrent),
              isArchived: Value(isArchived),
              archivedAt: Value(archivedAt),
              createdAt: event.timestamp,
              updatedAt: now,
            ),
          );
    }
  }
}
