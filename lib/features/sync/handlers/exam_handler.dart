// lib/features/sync/handlers/exam_handler.dart
import 'package:drift/drift.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/database/app_database.dart';
import '../client/conflict_manager.dart';
import '../domain/sync_event_model.dart';
import 'entity_sync_handler.dart';

class ExamHandler implements EntitySyncHandler {
  @override
  String get entityType => SyncEntityType.exam;

  @override
  bool canHandle(String type) => type == SyncEntityType.exam;

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
    final name = p['name'] as String? ?? 'Unnamed Exam';
    final description = p['description'] as String?;
    final startDate =
        p['startDate'] != null
            ? DateTime.parse(p['startDate'] as String)
            : DateTime.now();
    final endDate =
        p['endDate'] != null
            ? DateTime.parse(p['endDate'] as String)
            : DateTime.now();
    final status = p['status'] as String? ?? 'draft';
    final weight = (p['weight'] as num?)?.toDouble() ?? 1.0;
    final createdBy = p['createdBy'] as String? ?? event.userId;
    final isArchived =
        event.operation == SyncOperation.delete ||
        (p['isArchived'] as bool? ?? false);
    final archivedAt =
        p['archivedAt'] != null
            ? DateTime.parse(p['archivedAt'] as String)
            : (isArchived ? DateTime.now() : null);
    final now = DateTime.now();

    // Referential integrity check: Academic year must exist
    if (academicYearId.isNotEmpty) {
      final year =
          await (db.select(db.academicYears)
            ..where((t) => t.id.equals(academicYearId))).getSingleOrNull();
      if (year == null) {
        throw MissingDependencyException(
          SyncEntityType.academicYear,
          academicYearId,
        );
      }
    }

    final existing =
        await (db.select(db.exams)
          ..where((t) => t.id.equals(id))).getSingleOrNull();

    if (existing != null) {
      await (db.update(db.exams)..where((t) => t.id.equals(id))).write(
        ExamsCompanion(
          name: Value(name),
          description: Value(description),
          startDate: Value(startDate),
          endDate: Value(endDate),
          status: Value(status),
          weight: Value(weight),
          isArchived: Value(isArchived),
          archivedAt: Value(archivedAt),
          updatedAt: Value(now),
        ),
      );
    } else {
      await db
          .into(db.exams)
          .insert(
            ExamsCompanion.insert(
              id: id,
              schoolId: schoolId,
              academicYearId: academicYearId,
              name: name,
              description: Value(description),
              startDate: startDate,
              endDate: endDate,
              status: Value(status),
              weight: Value(weight),
              isArchived: Value(isArchived),
              archivedAt: Value(archivedAt),
              createdBy: createdBy,
              createdAt: now,
              updatedAt: now,
            ),
          );
    }
  }
}
