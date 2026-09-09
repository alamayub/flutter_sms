// lib/features/sync/client/sync_queue.dart
import 'dart:convert';
import 'dart:math';
import 'package:drift/drift.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/database/app_database.dart';
import '../../../core/utils/uuid_generator.dart';
import '../domain/sync_event_model.dart';

class SyncQueue {
  final AppDatabase _db;

  SyncQueue(this._db);

  /// Enqueues a change event atomically inside an existing or new database transaction.
  Future<SyncEventModel> enqueue({
    required String schoolId,
    required String deviceId,
    required String userId,
    required String entityType,
    required String entityId,
    required String operation,
    required Map<String, dynamic> payload,
    int version = 1,
    DateTime? timestamp,
  }) async {
    final eventId = UuidGenerator.v4();
    final now = timestamp ?? DateTime.now();

    final companion = SyncEventsCompanion.insert(
      eventId: eventId,
      schoolId: schoolId,
      deviceId: deviceId,
      userId: userId,
      entityType: entityType,
      entityId: entityId,
      operation: operation,
      version: Value(version),
      payload: jsonEncode(payload),
      status: const Value(SyncEventStatus.pending),
      attemptCount: const Value(0),
      createdAt: now,
    );

    await _db.into(_db.syncEvents).insert(companion);

    return SyncEventModel(
      eventId: eventId,
      schoolId: schoolId,
      deviceId: deviceId,
      userId: userId,
      entityType: entityType,
      entityId: entityId,
      operation: operation,
      version: version,
      payload: payload,
      status: SyncEventStatus.pending,
      timestamp: now,
    );
  }

  /// Gets pending events eligible for transmission, ordered chronologically.
  Future<List<SyncEventModel>> getPendingBatch({int limit = 100}) async {
    final rows =
        await (_db.select(_db.syncEvents)
              ..where(
                (t) => t.status.isIn([
                  SyncEventStatus.pending,
                  SyncEventStatus.failed,
                  SyncEventStatus.sending,
                ]),
              )
              ..orderBy([(t) => OrderingTerm.asc(t.createdAt)])
              ..limit(limit))
            .get();

    return rows.map(SyncEventModel.fromTableData).toList();
  }

  /// Transitions events to sending status
  Future<void> markSending(List<String> eventIds) async {
    if (eventIds.isEmpty) return;
    await (_db.update(_db.syncEvents)..where(
      (t) => t.eventId.isIn(eventIds),
    )).write(const SyncEventsCompanion(status: Value(SyncEventStatus.sending)));
  }

  /// Marks successfully acknowledged events as synced
  Future<void> markSynced(Map<String, int> ackMap) async {
    if (ackMap.isEmpty) return;
    final now = DateTime.now();

    await _db.transaction(() async {
      for (final entry in ackMap.entries) {
        await (_db.update(_db.syncEvents)
          ..where((t) => t.eventId.equals(entry.key))).write(
          SyncEventsCompanion(
            status: const Value(SyncEventStatus.synced),
            serverSequence: Value(entry.value),
            syncedAt: Value(now),
            errorMessage: const Value(null),
          ),
        );
      }
    });
  }

  /// Marks events as failed with attempt tracking and backoff error message
  Future<void> markFailed(List<String> eventIds, String errorMessage) async {
    if (eventIds.isEmpty) return;
    final now = DateTime.now();

    await _db.transaction(() async {
      for (final id in eventIds) {
        final existing =
            await (_db.select(_db.syncEvents)
              ..where((t) => t.eventId.equals(id))).getSingleOrNull();

        final nextAttempt = (existing?.attemptCount ?? 0) + 1;
        await (_db.update(_db.syncEvents)
          ..where((t) => t.eventId.equals(id))).write(
          SyncEventsCompanion(
            status: const Value(SyncEventStatus.failed),
            attemptCount: Value(nextAttempt),
            lastAttemptAt: Value(now),
            errorMessage: Value(errorMessage),
          ),
        );
      }
    });
  }

  /// Calculates exponential backoff duration in seconds based on attempt count.
  Duration getBackoffDuration(int attemptCount) {
    // 2^min(attempt, 6) seconds: 2s, 4s, 8s, 16s, 32s, 64s max
    final exp = min(attemptCount, 6);
    final seconds = pow(2, exp).toInt();
    return Duration(seconds: seconds);
  }

  /// Returns total count of un-synchronized events
  Future<int> getPendingCount() async {
    final countExp = _db.syncEvents.eventId.count();
    final query =
        _db.selectOnly(_db.syncEvents)
          ..addColumns([countExp])
          ..where(
            _db.syncEvents.status.isIn([
              SyncEventStatus.pending,
              SyncEventStatus.failed,
              SyncEventStatus.sending,
            ]),
          );
    final result = await query.getSingle();
    return result.read(countExp) ?? 0;
  }
}
