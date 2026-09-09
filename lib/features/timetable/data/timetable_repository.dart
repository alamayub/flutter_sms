// lib/features/timetable/data/timetable_repository.dart
import 'package:drift/drift.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_service.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/utils/date_helpers.dart';
import '../../../core/utils/uuid_generator.dart';
import '../../audit/data/audit_repository.dart';
import '../../sync/client/sync_engine.dart';
import '../../sync/presentation/sync_controller.dart';

final timetableRepositoryProvider = Provider<TimetableRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final audit = ref.watch(auditRepositoryProvider);
  final syncEngine = ref.watch(syncEngineProvider);
  return TimetableRepository(db, audit, syncEngine);
});

class TimetableEntryDetail {
  final Timetable entry;
  final Subject subject;
  final Teacher? teacher;
  final SchoolClass? schoolClass;
  final Section? section;

  TimetableEntryDetail({
    required this.entry,
    required this.subject,
    this.teacher,
    this.schoolClass,
    this.section,
  });
}

class TimetableRepository {
  final AppDatabase _db;
  final AuditRepository _audit;
  final SyncEngine? _syncEngine;

  TimetableRepository(this._db, this._audit, [this._syncEngine]);

  /// Checks for timetable conflicts (Teacher, Section, Room) across the academic year.
  Future<void> validateNoConflicts({
    required String academicYearId,
    required String sectionId,
    required int dayOfWeek,
    required String startTime,
    required String endTime,
    String? teacherId,
    String? room,
    String? excludeEntryId,
  }) async {
    // 1. Fetch all entries for this day in this academic year
    final dayEntries =
        await (_db.select(_db.timetables)..where(
          (t) =>
              t.academicYearId.equals(academicYearId) &
              t.dayOfWeek.equals(dayOfWeek),
        )).get();

    for (final existing in dayEntries) {
      if (excludeEntryId != null && existing.id == excludeEntryId) continue;

      // Check if time intervals overlap
      final overlaps = DateHelpers.doTimeIntervalsOverlap(
        startA: startTime,
        endA: endTime,
        startB: existing.startTime,
        endB: existing.endTime,
      );

      if (!overlaps) continue;

      // Conflict 1: Section overlap
      if (existing.sectionId == sectionId) {
        final existingSubject =
            await (_db.select(
              _db.subjects,
            )..where((s) => s.id.equals(existing.subjectId))).getSingleOrNull();

        throw ConflictException(
          'Section conflict: A period for "${existingSubject?.name ?? 'Subject'}" is already scheduled from ${existing.startTime} to ${existing.endTime}.',
        );
      }

      // Conflict 2: Teacher overlap
      if (teacherId != null &&
          existing.teacherId != null &&
          existing.teacherId == teacherId) {
        final teacher =
            await (_db.select(_db.teachers)
              ..where((t) => t.id.equals(teacherId))).getSingleOrNull();
        final existingClass =
            await (_db.select(_db.schoolClasses)
              ..where((c) => c.id.equals(existing.classId))).getSingleOrNull();
        final existingSection =
            await (_db.select(
              _db.sections,
            )..where((s) => s.id.equals(existing.sectionId))).getSingleOrNull();

        final teacherName = teacher?.name ?? 'Teacher';
        final className = existingClass?.name ?? 'Class';
        final sectionName = existingSection?.name ?? '';

        throw ConflictException(
          'Teacher conflict: $teacherName is already scheduled to teach $className $sectionName from ${existing.startTime} to ${existing.endTime}.',
        );
      }

      // Conflict 3: Room overlap
      if (room != null &&
          room.trim().isNotEmpty &&
          existing.room != null &&
          existing.room!.trim().toLowerCase() == room.trim().toLowerCase()) {
        throw ConflictException(
          'Room conflict: Room "$room" is already booked from ${existing.startTime} to ${existing.endTime}.',
        );
      }
    }
  }

  /// Creates a timetable entry.
  Future<Timetable> createEntry({
    required String schoolId,
    required String academicYearId,
    required String classId,
    required String sectionId,
    required int dayOfWeek,
    required int period,
    required String subjectId,
    String? teacherId,
    required String startTime,
    required String endTime,
    String? room,
    String? currentUserId,
  }) async {
    return await _db.transaction(() async {
      await validateNoConflicts(
        academicYearId: academicYearId,
        sectionId: sectionId,
        dayOfWeek: dayOfWeek,
        startTime: startTime,
        endTime: endTime,
        teacherId: teacherId,
        room: room,
      );

      final id = UuidGenerator.v4();
      final now = DateTime.now();

      await _db
          .into(_db.timetables)
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
              startTime: startTime.trim(),
              endTime: endTime.trim(),
              room: Value(room?.trim()),
              createdAt: now,
              updatedAt: now,
            ),
          );

      await _audit.log(
        schoolId: schoolId,
        userId: currentUserId,
        action: AuditAction.timetableCreated,
        entityType: 'Timetable',
        entityId: id,
        metadata: {
          'dayOfWeek': dayOfWeek,
          'period': period,
          'startTime': startTime,
          'endTime': endTime,
        },
      );

      if (_syncEngine != null) {
        await _syncEngine.enqueue(
          schoolId: schoolId,
          userId: currentUserId ?? 'local_user',
          entityType: SyncEntityType.timetable,
          entityId: id,
          operation: SyncOperation.create,
          payload: {
            'id': id,
            'schoolId': schoolId,
            'academicYearId': academicYearId,
            'classId': classId,
            'sectionId': sectionId,
            'dayOfWeek': dayOfWeek,
            'period': period,
            'subjectId': subjectId,
            'teacherId': teacherId,
            'startTime': startTime.trim(),
            'endTime': endTime.trim(),
            'room': room?.trim(),
            'createdAt': now.toIso8601String(),
            'updatedAt': now.toIso8601String(),
          },
        );
      }

      return (await (_db.select(_db.timetables)
        ..where((t) => t.id.equals(id))).getSingle());
    });
  }

  /// Updates a timetable entry.
  Future<Timetable> updateEntry({
    required String id,
    required String academicYearId,
    required String sectionId,
    required int dayOfWeek,
    required int period,
    required String subjectId,
    String? teacherId,
    required String startTime,
    required String endTime,
    String? room,
    String? currentUserId,
  }) async {
    final existing = await (_db.select(_db.timetables)
      ..where((t) => t.id.equals(id))).getSingleOrNull();

    return await _db.transaction(() async {
      await validateNoConflicts(
        academicYearId: academicYearId,
        sectionId: sectionId,
        dayOfWeek: dayOfWeek,
        startTime: startTime,
        endTime: endTime,
        teacherId: teacherId,
        room: room,
        excludeEntryId: id,
      );

      final now = DateTime.now();

      await (_db.update(_db.timetables)..where((t) => t.id.equals(id))).write(
        TimetablesCompanion(
          dayOfWeek: Value(dayOfWeek),
          period: Value(period),
          subjectId: Value(subjectId),
          teacherId: Value(teacherId),
          startTime: Value(startTime.trim()),
          endTime: Value(endTime.trim()),
          room: Value(room?.trim()),
          updatedAt: Value(now),
        ),
      );

      await _audit.log(
        userId: currentUserId,
        action: AuditAction.timetableUpdated,
        entityType: 'Timetable',
        entityId: id,
        metadata: {
          'dayOfWeek': dayOfWeek,
          'period': period,
          'startTime': startTime,
          'endTime': endTime,
        },
      );

      if (_syncEngine != null && existing != null) {
        await _syncEngine.enqueue(
          schoolId: existing.schoolId,
          userId: currentUserId ?? 'local_user',
          entityType: SyncEntityType.timetable,
          entityId: id,
          operation: SyncOperation.update,
          payload: {
            'id': id,
            'schoolId': existing.schoolId,
            'academicYearId': academicYearId,
            'classId': existing.classId,
            'sectionId': sectionId,
            'dayOfWeek': dayOfWeek,
            'period': period,
            'subjectId': subjectId,
            'teacherId': teacherId,
            'startTime': startTime.trim(),
            'endTime': endTime.trim(),
            'room': room?.trim(),
            'updatedAt': now.toIso8601String(),
          },
        );
      }

      return (await (_db.select(_db.timetables)
        ..where((t) => t.id.equals(id))).getSingle());
    });
  }

  /// Deletes a timetable entry.
  Future<void> deleteEntry(String id, {String? currentUserId}) async {
    final existing = await (_db.select(_db.timetables)
      ..where((t) => t.id.equals(id))).getSingleOrNull();

    await _db.transaction(() async {
      await (_db.delete(_db.timetables)..where((t) => t.id.equals(id))).go();
      await _audit.log(
        userId: currentUserId,
        action: AuditAction.timetableDeleted,
        entityType: 'Timetable',
        entityId: id,
      );

      if (_syncEngine != null && existing != null) {
        await _syncEngine.enqueue(
          schoolId: existing.schoolId,
          userId: currentUserId ?? 'local_user',
          entityType: SyncEntityType.timetable,
          entityId: id,
          operation: SyncOperation.delete,
          payload: {
            'id': id,
            'schoolId': existing.schoolId,
          },
        );
      }
    });
  }

  /// Gets timetable entries for a specific section.
  Future<List<TimetableEntryDetail>> getTimetableForSection(
    String sectionId, {
    int? dayOfWeek,
  }) async {
    final query = _db.select(_db.timetables)
      ..where((t) => t.sectionId.equals(sectionId));

    if (dayOfWeek != null) {
      query.where((t) => t.dayOfWeek.equals(dayOfWeek));
    }

    query.orderBy([
      (t) => OrderingTerm.asc(t.dayOfWeek),
      (t) => OrderingTerm.asc(t.period),
    ]);

    final entries = await query.get();
    return _populateEntryDetails(entries);
  }

  /// Gets timetable entries for a specific teacher.
  Future<List<TimetableEntryDetail>> getTimetableForTeacher(
    String teacherId, {
    required String academicYearId,
    int? dayOfWeek,
  }) async {
    final query = _db.select(_db.timetables)..where(
      (t) =>
          t.teacherId.equals(teacherId) &
          t.academicYearId.equals(academicYearId),
    );

    if (dayOfWeek != null) {
      query.where((t) => t.dayOfWeek.equals(dayOfWeek));
    }

    query.orderBy([
      (t) => OrderingTerm.asc(t.dayOfWeek),
      (t) => OrderingTerm.asc(t.period),
    ]);

    final entries = await query.get();
    return _populateEntryDetails(entries);
  }

  Future<List<TimetableEntryDetail>> _populateEntryDetails(
    List<Timetable> entries,
  ) async {
    final result = <TimetableEntryDetail>[];

    for (final entry in entries) {
      final subject =
          await (_db.select(_db.subjects)
            ..where((s) => s.id.equals(entry.subjectId))).getSingleOrNull();
      if (subject == null) continue;

      Teacher? teacher;
      if (entry.teacherId != null) {
        teacher =
            await (_db.select(_db.teachers)
              ..where((t) => t.id.equals(entry.teacherId!))).getSingleOrNull();
      }

      final schoolClass =
          await (_db.select(_db.schoolClasses)
            ..where((c) => c.id.equals(entry.classId))).getSingleOrNull();

      final section =
          await (_db.select(_db.sections)
            ..where((s) => s.id.equals(entry.sectionId))).getSingleOrNull();

      result.add(
        TimetableEntryDetail(
          entry: entry,
          subject: subject,
          teacher: teacher,
          schoolClass: schoolClass,
          section: section,
        ),
      );
    }

    return result;
  }
}
