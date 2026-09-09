// lib/features/sync/server/server_storage.dart
import 'dart:convert';
import 'package:sqlite3/sqlite3.dart';
import '../../../core/constants/app_constants.dart';
import '../domain/device_model.dart';
import '../domain/sync_event_model.dart';

class ServerStorage {
  final Database _db;

  ServerStorage(this._db) {
    _initSchema();
  }

  factory ServerStorage.openFile(String path) {
    final db = sqlite3.open(path);
    return ServerStorage(db);
  }

  factory ServerStorage.inMemory() {
    final db = sqlite3.openInMemory();
    return ServerStorage(db);
  }

  void _initSchema() {
    _db.execute('PRAGMA foreign_keys = ON;');
    _db.execute('PRAGMA journal_mode = WAL;');

    _db.execute('''
      CREATE TABLE IF NOT EXISTS server_info (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      );

      CREATE TABLE IF NOT EXISTS registered_devices (
        device_id TEXT PRIMARY KEY,
        school_id TEXT NOT NULL,
        device_name TEXT NOT NULL,
        device_type TEXT NOT NULL,
        pairing_code TEXT,
        status TEXT NOT NULL,
        registered_at INTEGER NOT NULL,
        last_seen_at INTEGER NOT NULL
      );

      CREATE TABLE IF NOT EXISTS sync_events (
        sequence INTEGER PRIMARY KEY AUTOINCREMENT,
        event_id TEXT NOT NULL UNIQUE,
        school_id TEXT NOT NULL,
        device_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        operation TEXT NOT NULL,
        version INTEGER NOT NULL DEFAULT 1,
        payload TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        received_at INTEGER NOT NULL
      );

      CREATE INDEX IF NOT EXISTS idx_sync_events_school_seq 
      ON sync_events(school_id, sequence);
    ''');
  }

  void setServerInfo(String key, String value) {
    final stmt = _db.prepare('''
      INSERT INTO server_info (key, value)
      VALUES (?, ?)
      ON CONFLICT(key) DO UPDATE SET value = excluded.value;
    ''');
    stmt.execute([key, value]);
    stmt.dispose();
  }

  String? getServerInfo(String key) {
    final stmt = _db.prepare('SELECT value FROM server_info WHERE key = ?;');
    final result = stmt.select([key]);
    stmt.dispose();
    if (result.isEmpty) return null;
    return result.first['value'] as String?;
  }

  /// Registers or updates device. If autoApproveFirst is true and no devices exist, approves immediately.
  DeviceModel registerDevice({
    required String deviceId,
    required String schoolId,
    required String deviceName,
    required String deviceType,
    String? pairingCode,
    bool autoApproveFirst = true,
  }) {
    final existing = getDevice(deviceId);
    final now = DateTime.now();

    if (existing != null) {
      // Update last seen and details if still valid
      final stmt = _db.prepare('''
        UPDATE registered_devices
        SET device_name = ?, device_type = ?, last_seen_at = ?
        WHERE device_id = ?;
      ''');
      stmt.execute([
        deviceName,
        deviceType,
        now.millisecondsSinceEpoch,
        deviceId,
      ]);
      stmt.dispose();
      return existing.copyWith(lastSeenAt: now);
    }

    // Check count of approved devices
    var status = DeviceStatus.pendingApproval;
    if (autoApproveFirst) {
      final countResult = _db.select(
        'SELECT COUNT(*) as cnt FROM registered_devices WHERE school_id = ?;',
        [schoolId],
      );
      final count = countResult.first['cnt'] as int;
      if (count == 0) {
        status = DeviceStatus.approved;
      }
    }

    final stmt = _db.prepare('''
      INSERT INTO registered_devices (
        device_id, school_id, device_name, device_type, pairing_code, status, registered_at, last_seen_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?);
    ''');
    stmt.execute([
      deviceId,
      schoolId,
      deviceName,
      deviceType,
      pairingCode,
      status,
      now.millisecondsSinceEpoch,
      now.millisecondsSinceEpoch,
    ]);
    stmt.dispose();

    return DeviceModel(
      deviceId: deviceId,
      schoolId: schoolId,
      deviceName: deviceName,
      deviceType: deviceType,
      pairingCode: pairingCode,
      status: status,
      registeredAt: now,
      lastSeenAt: now,
    );
  }

  DeviceModel? getDevice(String deviceId) {
    final stmt = _db.prepare(
      'SELECT * FROM registered_devices WHERE device_id = ?;',
    );
    final result = stmt.select([deviceId]);
    stmt.dispose();
    if (result.isEmpty) return null;
    final row = result.first;

    return DeviceModel(
      deviceId: row['device_id'] as String,
      schoolId: row['school_id'] as String,
      deviceName: row['device_name'] as String,
      deviceType: row['device_type'] as String,
      pairingCode: row['pairing_code'] as String?,
      status: row['status'] as String,
      registeredAt: DateTime.fromMillisecondsSinceEpoch(
        row['registered_at'] as int,
      ),
      lastSeenAt: DateTime.fromMillisecondsSinceEpoch(
        row['last_seen_at'] as int,
      ),
    );
  }

  List<DeviceModel> listDevices(String schoolId) {
    final stmt = _db.prepare('''
      SELECT * FROM registered_devices
      WHERE school_id = ?
      ORDER BY registered_at DESC;
    ''');
    final result = stmt.select([schoolId]);
    stmt.dispose();

    return result.map((row) {
      return DeviceModel(
        deviceId: row['device_id'] as String,
        schoolId: row['school_id'] as String,
        deviceName: row['device_name'] as String,
        deviceType: row['device_type'] as String,
        pairingCode: row['pairing_code'] as String?,
        status: row['status'] as String,
        registeredAt: DateTime.fromMillisecondsSinceEpoch(
          row['registered_at'] as int,
        ),
        lastSeenAt: DateTime.fromMillisecondsSinceEpoch(
          row['last_seen_at'] as int,
        ),
      );
    }).toList();
  }

  bool approveDevice(String deviceId) {
    final stmt = _db.prepare('''
      UPDATE registered_devices
      SET status = ?, last_seen_at = ?
      WHERE device_id = ?;
    ''');
    stmt.execute([
      DeviceStatus.approved,
      DateTime.now().millisecondsSinceEpoch,
      deviceId,
    ]);
    final updated = _db.updatedRows > 0;
    stmt.dispose();
    return updated;
  }

  bool revokeDevice(String deviceId) {
    final stmt = _db.prepare('''
      UPDATE registered_devices
      SET status = ?, last_seen_at = ?
      WHERE device_id = ?;
    ''');
    stmt.execute([
      DeviceStatus.revoked,
      DateTime.now().millisecondsSinceEpoch,
      deviceId,
    ]);
    final updated = _db.updatedRows > 0;
    stmt.dispose();
    return updated;
  }

  /// Ingests an event idempotently into the server database.
  /// If the eventId has already been persisted, returns the existing sequence.
  /// Otherwise inserts the event and returns the newly assigned sequence.
  int ingestEvent(SyncEventModel event) {
    // 1. Check if eventId already exists (idempotency check)
    final existingStmt = _db.prepare(
      'SELECT sequence FROM sync_events WHERE event_id = ?;',
    );
    final existingResult = existingStmt.select([event.eventId]);
    existingStmt.dispose();

    if (existingResult.isNotEmpty) {
      return existingResult.first['sequence'] as int;
    }

    // 2. Insert new event inside transaction
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final insertStmt = _db.prepare('''
      INSERT INTO sync_events (
        event_id, school_id, device_id, user_id, entity_type, entity_id,
        operation, version, payload, timestamp, received_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
    ''');

    insertStmt.execute([
      event.eventId,
      event.schoolId,
      event.deviceId,
      event.userId,
      event.entityType,
      event.entityId,
      event.operation,
      event.version,
      jsonEncode(event.payload),
      event.timestamp.toIso8601String(),
      nowMs,
    ]);
    insertStmt.dispose();

    return _db.lastInsertRowId;
  }

  /// Returns events for a given school where sequence > sinceSequence.
  List<SyncEventModel> getEventsSince({
    required String schoolId,
    required int sinceSequence,
    int limit = 200,
  }) {
    final stmt = _db.prepare('''
      SELECT * FROM sync_events
      WHERE school_id = ? AND sequence > ?
      ORDER BY sequence ASC
      LIMIT ?;
    ''');
    final result = stmt.select([schoolId, sinceSequence, limit]);
    stmt.dispose();

    return result.map((row) {
      Map<String, dynamic> payloadMap;
      try {
        payloadMap =
            jsonDecode(row['payload'] as String) as Map<String, dynamic>;
      } catch (_) {
        payloadMap = {};
      }

      return SyncEventModel(
        eventId: row['event_id'] as String,
        schoolId: row['school_id'] as String,
        deviceId: row['device_id'] as String,
        userId: row['user_id'] as String,
        entityType: row['entity_type'] as String,
        entityId: row['entity_id'] as String,
        operation: row['operation'] as String,
        version: row['version'] as int,
        payload: payloadMap,
        serverSequence: row['sequence'] as int,
        status: SyncEventStatus.synced,
        timestamp: DateTime.parse(row['timestamp'] as String),
      );
    }).toList();
  }

  int getTotalEventCount() {
    final result = _db.select('SELECT COUNT(*) as cnt FROM sync_events;');
    return result.first['cnt'] as int;
  }

  int getDeviceCount() {
    final result = _db.select(
      'SELECT COUNT(*) as cnt FROM registered_devices;',
    );
    return result.first['cnt'] as int;
  }

  void close() {
    _db.dispose();
  }
}
