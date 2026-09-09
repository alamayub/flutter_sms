// lib/features/sync/handlers/enrollment_handler.dart
import 'package:drift/drift.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/database/app_database.dart';
import '../client/conflict_manager.dart';
import '../domain/sync_event_model.dart';
import 'entity_sync_handler.dart';

class EnrollmentHandler implements EntitySyncHandler {
  @override
  String get entityType => SyncEntityType.enrollment;

  @override
  bool canHandle(String type) => type == SyncEntityType.enrollment;

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
    final studentId = p['studentId'] as String? ?? '';
    final academicYearId = p['academicYearId'] as String? ?? '';
    final classId = p['classId'] as String? ?? '';
    final sectionId = p['sectionId'] as String? ?? '';
    final rollNumber = p['rollNumber'] as int?;
    final isActive = p['isActive'] as bool? ?? true;
    final isArchived =
        event.operation == SyncOperation.delete ||
        (p['isArchived'] as bool? ?? false);
    final archivedAt =
        p['archivedAt'] != null
            ? DateTime.parse(p['archivedAt'] as String)
            : (isArchived ? DateTime.now() : null);
    final now = DateTime.now();

    // Referential dependency check: student must exist
    if (studentId.isNotEmpty) {
      final student =
          await (db.select(db.students)
            ..where((t) => t.id.equals(studentId))).getSingleOrNull();
      if (student == null) {
        throw MissingDependencyException(SyncEntityType.student, studentId);
      }
    }

    final existing =
        await (db.select(db.enrollments)
          ..where((t) => t.id.equals(id))).getSingleOrNull();

    if (existing != null) {
      await (db.update(db.enrollments)..where((t) => t.id.equals(id))).write(
        EnrollmentsCompanion(
          schoolId: Value(schoolId),
          studentId: Value(studentId),
          academicYearId: Value(academicYearId),
          classId: Value(classId),
          sectionId: Value(sectionId),
          rollNumber: Value(rollNumber),
          isActive: Value(isActive),
          isArchived: Value(isArchived),
          archivedAt: Value(archivedAt),
          updatedAt: Value(now),
        ),
      );
    } else {
      await db
          .into(db.enrollments)
          .insert(
            EnrollmentsCompanion.insert(
              id: id,
              schoolId: schoolId,
              studentId: studentId,
              academicYearId: academicYearId,
              classId: classId,
              sectionId: sectionId,
              rollNumber: Value(rollNumber),
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
