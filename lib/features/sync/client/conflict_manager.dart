// lib/features/sync/client/conflict_manager.dart
import 'dart:convert';
import 'package:drift/drift.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/database/app_database.dart';
import '../../../core/utils/uuid_generator.dart';
import '../domain/sync_event_model.dart';

class ConflictMergeResult {
  final bool hasConflict;
  final bool canAutoMerge;
  final Map<String, dynamic> mergedPayload;
  final String? conflictId;
  final List<String> conflictingFields;

  ConflictMergeResult({
    required this.hasConflict,
    required this.canAutoMerge,
    required this.mergedPayload,
    this.conflictId,
    this.conflictingFields = const [],
  });
}

class ConflictManager {
  final AppDatabase _db;

  ConflictManager(this._db);

  /// Checks if incoming event conflicts with an unsynced pending local event.
  /// If fields are disjoint, merges them automatically.
  /// If values collide on identical fields, logs a structured conflict in sync_conflicts.
  Future<ConflictMergeResult> evaluateConflict({
    required SyncEventModel remoteEvent,
  }) async {
    final pendingLocal =
        await (_db.select(_db.syncEvents)..where(
          (t) =>
              t.entityType.equals(remoteEvent.entityType) &
              t.entityId.equals(remoteEvent.entityId) &
              t.status.isIn([SyncEventStatus.pending, SyncEventStatus.failed]),
        )).getSingleOrNull();

    if (pendingLocal == null) {
      return ConflictMergeResult(
        hasConflict: false,
        canAutoMerge: true,
        mergedPayload: remoteEvent.payload,
      );
    }

    // Both have edits on the same entity
    Map<String, dynamic> localPayload;
    try {
      localPayload = jsonDecode(pendingLocal.payload) as Map<String, dynamic>;
    } catch (_) {
      localPayload = {};
    }

    final remotePayload = remoteEvent.payload;
    final conflictingFields = <String>[];
    final merged = Map<String, dynamic>.from(remotePayload);

    // Identify conflicting vs safe fields
    for (final key in localPayload.keys) {
      // Ignore metadata keys
      if (key == 'updatedAt' || key == 'createdAt' || key == 'version') {
        continue;
      }

      if (remotePayload.containsKey(key)) {
        final localVal = localPayload[key];
        final remoteVal = remotePayload[key];

        if (localVal != remoteVal) {
          // Different values on same field!
          conflictingFields.add(key);
        }
      } else {
        // Disjoint field: present locally but not in remote -> safe to retain!
        merged[key] = localPayload[key];
      }
    }

    if (conflictingFields.isEmpty) {
      // Clean field-level merge!
      return ConflictMergeResult(
        hasConflict: false,
        canAutoMerge: true,
        mergedPayload: merged,
      );
    }

    // Unresolvable field collision: record in sync_conflicts
    final conflictId = UuidGenerator.v4();
    final now = DateTime.now();

    final resolutionMeta = {
      'status': SyncConflictStatus.pending,
      'localVersion': pendingLocal.version,
      'remoteVersion': remoteEvent.version,
      'conflictingFields': conflictingFields,
    };

    await _db
        .into(_db.syncConflicts)
        .insert(
          SyncConflictsCompanion.insert(
            id: conflictId,
            schoolId: remoteEvent.schoolId,
            entityType: remoteEvent.entityType,
            entityId: remoteEvent.entityId,
            localEventId: Value(pendingLocal.eventId),
            remoteEventId: Value(remoteEvent.eventId),
            localPayload: jsonEncode(localPayload),
            remotePayload: jsonEncode(remotePayload),
            detectedAt: now,
            resolutionNote: Value(jsonEncode(resolutionMeta)),
          ),
        );

    return ConflictMergeResult(
      hasConflict: true,
      canAutoMerge: false,
      mergedPayload: remotePayload,
      conflictId: conflictId,
      conflictingFields: conflictingFields,
    );
  }

  /// Lists all unresolved conflicts for a school
  Future<List<SyncConflict>> getPendingConflicts(String schoolId) async {
    final rows =
        await (_db.select(_db.syncConflicts)
              ..where(
                (t) => t.schoolId.equals(schoolId) & t.resolvedAt.isNull(),
              )
              ..orderBy([(t) => OrderingTerm.desc(t.detectedAt)]))
            .get();

    return rows;
  }

  /// Reactive stream of pending conflict count for badging and alerts
  Stream<int> watchPendingConflictCount(String schoolId) {
    final countExp = _db.syncConflicts.id.count();
    final query =
        _db.selectOnly(_db.syncConflicts)
          ..addColumns([countExp])
          ..where(
            _db.syncConflicts.schoolId.equals(schoolId) &
                _db.syncConflicts.resolvedAt.isNull(),
          );

    return query.watchSingle().map((row) => row.read(countExp) ?? 0);
  }

  /// Resolves a conflict with resolution action: 'keep_local', 'keep_remote', or 'merged'
  Future<void> resolveConflict({
    required String conflictId,
    required String resolvedByUserId,
    required String resolution, // 'keep_local', 'keep_remote', 'merged'
    Map<String, dynamic>? mergedPayload,
  }) async {
    final conflict =
        await (_db.select(_db.syncConflicts)
          ..where((t) => t.id.equals(conflictId))).getSingleOrNull();

    if (conflict == null) return;

    final now = DateTime.now();
    final resolutionNote = jsonEncode({
      'status': SyncConflictStatus.resolved,
      'resolution': resolution,
      'resolvedBy': resolvedByUserId,
      'resolvedAt': now.toIso8601String(),
      if (mergedPayload != null) 'mergedPayload': mergedPayload,
    });

    await (_db.update(_db.syncConflicts)
      ..where((t) => t.id.equals(conflictId))).write(
      SyncConflictsCompanion(
        resolvedAt: Value(now),
        resolutionNote: Value(resolutionNote),
      ),
    );
  }
}
