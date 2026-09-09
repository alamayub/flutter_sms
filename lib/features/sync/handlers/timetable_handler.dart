// lib/features/sync/handlers/timetable_handler.dart
import 'dart:convert';
import 'package:drift/drift.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/database/app_database.dart';
import '../../../core/utils/date_helpers.dart';
import '../../../core/utils/uuid_generator.dart';
import '../client/conflict_manager.dart';
import '../domain/sync_event_model.dart';
import 'entity_sync_handler.dart';

class TimetableHandler implements EntitySyncHandler {
  @override
  String get entityType => SyncEntityType.timetable;

  @override
  bool canHandle(String type) => type == SyncEntityType.timetable;

  @override
  Future<void> apply(
    SyncEventModel event,
    AppDatabase db,
    ConflictManager conflictManager,
  ) async {
    if (event.operation == SyncOperation.delete) {
      await (db.delete(db.timetables)
        ..where((t) => t.id.equals(event.entityId))).go();
      return;
    }

    final p = event.payload;
    final id = event.entityId;
    final schoolId = event.schoolId;
    final academicYearId = p['academicYearId'] as String? ?? '';
    final classId = p['classId'] as String? ?? '';
    final sectionId = p['sectionId'] as String? ?? '';
    final dayOfWeek = p['dayOfWeek'] as int? ?? 1;
    final period = p['period'] as int? ?? 1;
    final subjectId = p['subjectId'] as String? ?? '';
    final teacherId = p['teacherId'] as String?;
    final startTime = p['startTime'] as String? ?? '09:00';
    final endTime = p['endTime'] as String? ?? '09:45';
    final room = p['room'] as String?;
    final now = DateTime.now();

    // Timetable Conflict Detection across same day and academic year
    final dayEntries =
        await (db.select(db.timetables)..where(
          (t) =>
              t.academicYearId.equals(academicYearId) &
              t.dayOfWeek.equals(dayOfWeek) &
              t.id.isNotValue(id),
        )).get();

    String? conflictType;
    String? conflictDetails;

    for (final existing in dayEntries) {
      final overlaps = DateHelpers.doTimeIntervalsOverlap(
        startA: startTime,
        endA: endTime,
        startB: existing.startTime,
        endB: existing.endTime,
      );
      if (!overlaps) continue;

      // 1. Section conflict
      if (existing.sectionId == sectionId) {
        conflictType = 'Class/Section collision';
        conflictDetails =
            'Section already has a class scheduled from ${existing.startTime} to ${existing.endTime}';
        break;
      }

      // 2. Teacher conflict
      if (teacherId != null &&
          existing.teacherId != null &&
          existing.teacherId == teacherId) {
        conflictType = 'Teacher collision';
        conflictDetails =
            'Teacher is already scheduled for another class from ${existing.startTime} to ${existing.endTime}';
        break;
      }

      // 3. Room conflict
      if (room != null &&
          room.trim().isNotEmpty &&
          existing.room != null &&
          existing.room!.trim().toLowerCase() == room.trim().toLowerCase()) {
        conflictType = 'Room collision';
        conflictDetails =
            'Room $room is already occupied from ${existing.startTime} to ${existing.endTime}';
        break;
      }
    }

    if (conflictType != null) {
      // Record structured conflict rather than corrupting timetable
      await db
          .into(db.syncConflicts)
          .insert(
            SyncConflictsCompanion.insert(
              id: UuidGenerator.v4(),
              schoolId: schoolId,
              entityType: SyncEntityType.timetable,
              entityId: id,
              localEventId: Value(event.eventId),
              remoteEventId: Value(event.eventId),
              localPayload: jsonEncode({'conflictType': conflictType}),
              remotePayload: jsonEncode(p),
              detectedAt: now,
              resolutionNote: Value(
                jsonEncode({
                  'status': SyncConflictStatus.pending,
                  'type': conflictType,
                  'details': conflictDetails,
                }),
              ),
            ),
          );
      return;
    }

    final existingEntry =
        await (db.select(db.timetables)
          ..where((t) => t.id.equals(id))).getSingleOrNull();

    if (existingEntry != null) {
      await (db.update(db.timetables)..where((t) => t.id.equals(id))).write(
        TimetablesCompanion(
          classId: Value(classId),
          sectionId: Value(sectionId),
          dayOfWeek: Value(dayOfWeek),
          period: Value(period),
          subjectId: Value(subjectId),
          teacherId: Value(teacherId),
          startTime: Value(startTime),
          endTime: Value(endTime),
          room: Value(room),
          updatedAt: Value(now),
        ),
      );
    } else {
      await db
          .into(db.timetables)
          .insert(
            TimetablesCompanion.insert(
              id: id,
              schoolId: schoolId,
              academicYearId: academicYearId,
              classId: classId,
              sectionId: sectionId,
              dayOfWeek: dayOfWeek,
              period: period,
              subjectId: subjectId,
              teacherId: Value(teacherId),
              startTime: startTime,
              endTime: endTime,
              room: Value(room),
              createdAt: event.timestamp,
              updatedAt: now,
            ),
          );
    }
  }
}
