// lib/features/attendance/data/attendance_repository.dart
import 'package:drift/drift.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_service.dart';
import '../../../core/utils/uuid_generator.dart';
import '../../audit/data/audit_repository.dart';

import '../../sync/client/sync_engine.dart';
import '../../sync/presentation/sync_controller.dart';

final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final audit = ref.watch(auditRepositoryProvider);
  final syncEngine = ref.watch(syncEngineProvider);
  return AttendanceRepository(db, audit, syncEngine);
});

class AttendanceSummary {
  final int totalCount;
  final int presentCount;
  final int absentCount;
  final int lateCount;
  final int excusedCount;

  const AttendanceSummary({
    this.totalCount = 0,
    this.presentCount = 0,
    this.absentCount = 0,
    this.lateCount = 0,
    this.excusedCount = 0,
  });

  double get attendancePercentage {
    if (totalCount == 0) return 0.0;
    return (presentCount + lateCount) / totalCount * 100.0;
  }
}

class AttendanceRepository {
  final AppDatabase _db;
  final AuditRepository _audit;
  final SyncEngine? _syncEngine;

  AttendanceRepository(this._db, this._audit, [this._syncEngine]);

  /// Gets attendance records for a section on a specific date (YYYY-MM-DD).
  Future<Map<String, AttendanceData>> getSectionAttendanceForDate({
    required String academicYearId,
    required String sectionId,
    required String date,
  }) async {
    final records =
        await (_db.select(_db.attendance)..where(
          (t) =>
              t.academicYearId.equals(academicYearId) &
              t.sectionId.equals(sectionId) &
              t.date.equals(date),
        )).get();

    return {for (var r in records) r.studentId: r};
  }

  /// Reactive stream of attendance records for a section on a specific date.
  /// Automatically emits when local database is updated (locally or via LAN sync).
  Stream<Map<String, AttendanceData>> watchSectionAttendanceForDate({
    required String academicYearId,
    required String sectionId,
    required String date,
  }) {
    return (_db.select(_db.attendance)..where(
      (t) =>
          t.academicYearId.equals(academicYearId) &
          t.sectionId.equals(sectionId) &
          t.date.equals(date),
    )).watch().map((records) => {for (var r in records) r.studentId: r});
  }

  /// Saves or updates attendance for multiple students in a single atomic transaction.
  Future<void> saveAttendanceBatch({
    required String schoolId,
    required String academicYearId,
    required String classId,
    required String sectionId,
    required String date,
    required Map<String, String> studentStatusMap, // studentId -> status
    required String markedByUserId,
  }) async {
    final now = DateTime.now();

    await _db.transaction(() async {
      for (final entry in studentStatusMap.entries) {
        final studentId = entry.key;
        final status = entry.value;

        // Check for existing record
        final existing =
            await (_db.select(_db.attendance)..where(
              (t) =>
                  t.date.equals(date) &
                  t.studentId.equals(studentId) &
                  t.classId.equals(classId) &
                  t.sectionId.equals(sectionId),
            )).getSingleOrNull();

        final attendanceId = existing?.id ?? UuidGenerator.v4();

        if (existing != null) {
          await (_db.update(_db.attendance)
            ..where((t) => t.id.equals(existing.id))).write(
            AttendanceCompanion(
              status: Value(status),
              markedBy: Value(markedByUserId),
              updatedAt: Value(now),
            ),
          );
        } else {
          await _db
              .into(_db.attendance)
              .insert(
                AttendanceCompanion.insert(
                  id: attendanceId,
                  schoolId: schoolId,
                  academicYearId: academicYearId,
                  date: date,
                  studentId: studentId,
                  classId: classId,
                  sectionId: sectionId,
                  status: status,
                  markedBy: markedByUserId,
                  createdAt: now,
                  updatedAt: now,
                ),
              );
        }

        // Enqueue sync event inside the atomic transaction
        if (_syncEngine != null) {
          await _syncEngine.enqueue(
            schoolId: schoolId,
            userId: markedByUserId,
            entityType: SyncEntityType.attendance,
            entityId: attendanceId,
            operation:
                existing != null ? SyncOperation.update : SyncOperation.create,
            payload: {
              'id': attendanceId,
              'schoolId': schoolId,
              'academicYearId': academicYearId,
              'date': date,
              'studentId': studentId,
              'classId': classId,
              'sectionId': sectionId,
              'status': status,
              'markedBy': markedByUserId,
              'createdAt':
                  existing?.createdAt.toIso8601String() ??
                  now.toIso8601String(),
              'updatedAt': now.toIso8601String(),
            },
          );
        }
      }

      await _audit.log(
        schoolId: schoolId,
        userId: markedByUserId,
        action: AuditAction.attendanceMarked,
        entityType: 'Attendance',
        metadata: {
          'date': date,
          'sectionId': sectionId,
          'count': studentStatusMap.length,
        },
      );
    });

    // Notify sync engine outside transaction to push pending events to LAN server
    _syncEngine?.notifyPending();
  }

  /// Calculates the school-wide daily attendance summary for a specific date.
  Future<AttendanceSummary> getDailySummary({
    required String schoolId,
    required String date,
  }) async {
    final records =
        await (_db.select(_db.attendance)..where(
          (t) => t.schoolId.equals(schoolId) & t.date.equals(date),
        )).get();

    int present = 0;
    int absent = 0;
    int late = 0;
    int excused = 0;

    for (final r in records) {
      switch (r.status) {
        case AttendanceStatus.present:
          present++;
          break;
        case AttendanceStatus.absent:
          absent++;
          break;
        case AttendanceStatus.late:
          late++;
          break;
        case AttendanceStatus.excused:
          excused++;
          break;
      }
    }

    return AttendanceSummary(
      totalCount: records.length,
      presentCount: present,
      absentCount: absent,
      lateCount: late,
      excusedCount: excused,
    );
  }

  /// Reactive stream of daily attendance summary.
  /// Emits automatically whenever any attendance record is inserted or updated.
  Stream<AttendanceSummary> watchDailySummary({
    required String schoolId,
    required String date,
  }) {
    return (_db.select(_db.attendance)..where(
      (t) => t.schoolId.equals(schoolId) & t.date.equals(date),
    )).watch().map((records) {
      int present = 0;
      int absent = 0;
      int late = 0;
      int excused = 0;

      for (final r in records) {
        switch (r.status) {
          case AttendanceStatus.present:
            present++;
            break;
          case AttendanceStatus.absent:
            absent++;
            break;
          case AttendanceStatus.late:
            late++;
            break;
          case AttendanceStatus.excused:
            excused++;
            break;
        }
      }

      return AttendanceSummary(
        totalCount: records.length,
        presentCount: present,
        absentCount: absent,
        lateCount: late,
        excusedCount: excused,
      );
    });
  }

  /// Calculates individual student attendance stats.
  Future<AttendanceSummary> getStudentAttendanceStats({
    required String studentId,
    required String academicYearId,
  }) async {
    final records =
        await (_db.select(_db.attendance)..where(
          (t) =>
              t.studentId.equals(studentId) &
              t.academicYearId.equals(academicYearId),
        )).get();

    int present = 0;
    int absent = 0;
    int late = 0;
    int excused = 0;

    for (final r in records) {
      switch (r.status) {
        case AttendanceStatus.present:
          present++;
          break;
        case AttendanceStatus.absent:
          absent++;
          break;
        case AttendanceStatus.late:
          late++;
          break;
        case AttendanceStatus.excused:
          excused++;
          break;
      }
    }

    return AttendanceSummary(
      totalCount: records.length,
      presentCount: present,
      absentCount: absent,
      lateCount: late,
      excusedCount: excused,
    );
  }
}
