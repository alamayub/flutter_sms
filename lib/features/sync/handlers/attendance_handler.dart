// lib/features/sync/handlers/attendance_handler.dart
import 'package:drift/drift.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/database/app_database.dart';
import '../client/conflict_manager.dart';
import '../domain/sync_event_model.dart';
import 'entity_sync_handler.dart';

class AttendanceHandler implements EntitySyncHandler {
  @override
  String get entityType => SyncEntityType.attendance;

  @override
  bool canHandle(String type) => type == SyncEntityType.attendance;

  @override
  Future<void> apply(
    SyncEventModel event,
    AppDatabase db,
    ConflictManager conflictManager,
  ) async {
    // Evaluate conflict against local pending attendance changes
    final conflictResult = await conflictManager.evaluateConflict(
      remoteEvent: event,
    );
    final p = conflictResult.mergedPayload;

    final id = event.entityId;
    final schoolId = event.schoolId;
    final academicYearId = p['academicYearId'] as String? ?? '';
    final date = p['date'] as String? ?? '';
    final studentId = p['studentId'] as String? ?? '';
    final classId = p['classId'] as String? ?? '';
    final sectionId = p['sectionId'] as String? ?? '';
    final status = p['status'] as String? ?? AttendanceStatus.present;
    final markedBy = p['markedBy'] as String? ?? event.userId;
    final remarks = p['remarks'] as String?;
    final now = DateTime.now();

    final existingAttendance =
        await (db.select(db.attendance)..where(
          (t) =>
              t.date.equals(date) &
              t.studentId.equals(studentId) &
              t.classId.equals(classId) &
              t.sectionId.equals(sectionId),
        )).getSingleOrNull();

    if (existingAttendance != null) {
      await (db.update(db.attendance)
        ..where((t) => t.id.equals(existingAttendance.id))).write(
        AttendanceCompanion(
          status: Value(status),
          remarks: Value(remarks),
          markedBy: Value(markedBy),
          updatedAt: Value(now),
        ),
      );
    } else {
      await db
          .into(db.attendance)
          .insert(
            AttendanceCompanion.insert(
              id: id,
              schoolId: schoolId,
              academicYearId: academicYearId,
              date: date,
              studentId: studentId,
              classId: classId,
              sectionId: sectionId,
              status: status,
              markedBy: markedBy,
              remarks: Value(remarks),
              createdAt: event.timestamp,
              updatedAt: now,
            ),
          );
    }
  }
}
