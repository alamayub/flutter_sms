// lib/features/sync/client/sync_engine.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/database/app_database.dart';
import '../../../core/utils/uuid_generator.dart';
import '../domain/sync_event_model.dart';
import '../domain/sync_state.dart';
import '../handlers/academic_year_handler.dart';
import '../handlers/attendance_handler.dart';
import '../handlers/class_handler.dart';
import '../handlers/enrollment_handler.dart';
import '../handlers/entity_sync_handler.dart';
import '../handlers/exam_handler.dart';
import '../handlers/exam_subject_handler.dart';
import '../handlers/grade_scheme_handler.dart';
import '../handlers/marks_handler.dart';
import '../handlers/result_handler.dart';
import '../handlers/result_publication_handler.dart';
import '../handlers/section_handler.dart';
import '../handlers/student_handler.dart';
import '../handlers/subject_handler.dart';
import '../handlers/teacher_handler.dart';
import '../handlers/timetable_handler.dart';
import 'conflict_manager.dart';
import 'deferred_event_manager.dart';
import 'device_service.dart';
import 'sync_queue.dart';
import 'sync_transport.dart';

class SyncEngine {
  final AppDatabase _db;
  final DeviceService _deviceService;
  final SyncTransport _transport;
  final SyncQueue _queue;
  final ConflictManager _conflictManager;
  final DeferredEventManager _deferredEventManager;

  final List<EntitySyncHandler> _handlers = [];

  String? _serverHttpUrl;
  String? _serverId;
  String? _schoolId;
  String? _currentDeviceId;

  SyncConnectivityState _connectivity = SyncConnectivityState.localOnly;
  DateTime? _lastSyncTime;
  String? _errorMessage;
  bool _isDisposed = false;
  bool _isSyncing = false;

  final _statusController = StreamController<SyncStatusInfo>.broadcast();
  Stream<SyncStatusInfo> get statusStream => _statusController.stream;

  SyncEngine({
    required AppDatabase db,
    required DeviceService deviceService,
    HttpClient? httpClient,
    SyncTransport? transport,
    SyncQueue? queue,
    ConflictManager? conflictManager,
    DeferredEventManager? deferredEventManager,
  }) : _db = db,
       _deviceService = deviceService,
       _transport = transport ?? SyncTransport(httpClient: httpClient),
       _queue = queue ?? SyncQueue(db),
       _conflictManager = conflictManager ?? ConflictManager(db),
       _deferredEventManager = deferredEventManager ?? DeferredEventManager() {
    _registerDefaultHandlers();
  }

  void _registerDefaultHandlers() {
    registerHandler(AcademicYearHandler());
    registerHandler(ClassHandler());
    registerHandler(SectionHandler());
    registerHandler(SubjectHandler());
    registerHandler(TeacherHandler());
    registerHandler(StudentHandler());
    registerHandler(EnrollmentHandler());
    registerHandler(TimetableHandler());
    registerHandler(AttendanceHandler());
    registerHandler(ExamHandler());
    registerHandler(ExamSubjectHandler());
    registerHandler(MarksHandler());
    registerHandler(GradeSchemeHandler());
    registerHandler(ResultHandler());
    registerHandler(ResultPublicationHandler());
  }

  void registerHandler(EntitySyncHandler handler) {
    _handlers.removeWhere((h) => h.entityType == handler.entityType);
    _handlers.add(handler);
  }

  ConflictManager get conflictManager => _conflictManager;
  SyncQueue get queue => _queue;
  SyncTransport get transport => _transport;
  DeferredEventManager get deferredEventManager => _deferredEventManager;

  SyncStatusInfo get currentStatus => SyncStatusInfo(
    connectivity: _connectivity,
    serverUrl: _serverHttpUrl,
    serverId: _serverId,
    lastSyncTime: _lastSyncTime,
    errorMessage: _errorMessage,
  );

  String? get serverHttpUrl => _serverHttpUrl;
  String? get serverId => _serverId;
  String? get currentDeviceId => _currentDeviceId;
  String? get currentSchoolId => _schoolId;

  Future<void> initialize({
    required String schoolId,
    String? serverHttpUrl,
  }) async {
    _schoolId = schoolId;
    _currentDeviceId = await _deviceService.getOrCreateDeviceId();

    // Ensure device is in local sync_devices table
    await _deviceService.getOrCreateCurrentDevice(schoolId);

    if (serverHttpUrl != null && serverHttpUrl.isNotEmpty) {
      await configureServer(serverHttpUrl);
    } else {
      _updateStatus(SyncConnectivityState.localOnly);
    }
  }

  Future<bool> configureServer(String httpUrl) async {
    _serverHttpUrl = httpUrl.replaceAll(RegExp(r'/+$'), '');
    _errorMessage = null;

    try {
      // 1. Health check
      final healthJson = await _transport.checkHealth(_serverHttpUrl!);
      _serverId = healthJson['serverId'] as String?;
      final serverSchoolId = healthJson['schoolId'] as String?;

      if (serverSchoolId != null && serverSchoolId != _schoolId) {
        _errorMessage = 'Server serves a different school ($serverSchoolId)';
        _updateStatus(SyncConnectivityState.error);
        return false;
      }

      // 2. Register this device on the server
      final pairingCode = await _deviceService.getOrCreatePairingCode();
      final deviceName = _deviceService.getDefaultDeviceName();
      final deviceType = _deviceService.getDeviceType();

      final regData = await _transport.registerDevice(
        serverUrl: _serverHttpUrl!,
        deviceId: _currentDeviceId!,
        schoolId: _schoolId!,
        deviceName: deviceName,
        deviceType: deviceType,
        pairingCode: pairingCode,
      );

      final status =
          regData['status'] as String? ?? DeviceStatus.pendingApproval;
      await _deviceService.updateDeviceStatus(_currentDeviceId!, status);

      // 3. Setup WebSocket connection for live sync
      await _transport.connectWebSocket(
        serverUrl: _serverHttpUrl!,
        deviceId: _currentDeviceId!,
        schoolId: _schoolId!,
        onEvent: (event) {
          applyIncomingEvent(event);
        },
        onConnectionChange: (connected) {
          if (connected) {
            _updateStatus(SyncConnectivityState.connected);
            syncNow();
          } else {
            _updateStatus(SyncConnectivityState.localOnly);
          }
        },
      );

      _updateStatus(SyncConnectivityState.connected);
      await syncNow();
      return true;
    } catch (e) {
      _errorMessage = 'Could not connect to School Server: $e';
      _updateStatus(SyncConnectivityState.localOnly);
      return false;
    }
  }

  /// Enqueues a local change to the sync queue within a transaction
  Future<SyncEventModel> enqueue({
    required String schoolId,
    required String userId,
    required String entityType,
    required String entityId,
    required String operation,
    required Map<String, dynamic> payload,
    int version = 1,
    DateTime? timestamp,
  }) async {
    final event = await _queue.enqueue(
      schoolId: schoolId,
      deviceId: _currentDeviceId ?? 'unknown_device',
      userId: userId,
      entityType: entityType,
      entityId: entityId,
      operation: operation,
      payload: payload,
      version: version,
      timestamp: timestamp,
    );

    // If connected, trigger background upload
    if (_connectivity == SyncConnectivityState.connected ||
        _connectivity == SyncConnectivityState.syncComplete) {
      notifyPending();
    }

    return event;
  }

  /// Triggers background upload without awaiting
  void notifyPending() {
    uploadPending().catchError((_) => 0);
  }

  /// Full bidirectional synchronization: download missing, then upload pending
  Future<void> syncNow() async {
    if (_isDisposed ||
        _isSyncing ||
        _serverHttpUrl == null ||
        _schoolId == null) {
      return;
    }

    _isSyncing = true;
    _updateStatus(SyncConnectivityState.syncing);

    try {
      await downloadMissing();
      await uploadPending();
      _lastSyncTime = DateTime.now();
      _errorMessage = null;
      _updateStatus(SyncConnectivityState.syncComplete);
    } catch (e) {
      _errorMessage = e.toString();
      _updateStatus(SyncConnectivityState.error);
    } finally {
      _isSyncing = false;
    }
  }

  /// Uploads all local pending sync events to School Server in batches
  Future<int> uploadPending({int batchSize = 100}) async {
    if (_serverHttpUrl == null || _schoolId == null) return 0;

    int totalUploaded = 0;
    while (true) {
      final pending = await _queue.getPendingBatch(limit: batchSize);
      if (pending.isEmpty) break;

      final eventIds = pending.map((e) => e.eventId).toList();
      await _queue.markSending(eventIds);

      try {
        final ackMap = await _transport.uploadEventsBatch(
          serverUrl: _serverHttpUrl!,
          events: pending,
        );

        await _queue.markSynced(ackMap);
        totalUploaded += ackMap.length;

        if (pending.length < batchSize) break;
      } catch (e) {
        await _queue.markFailed(eventIds, e.toString());
        rethrow;
      }
    }

    return totalUploaded;
  }

  /// Downloads missing events from server sequence cursor
  Future<int> downloadMissing({int limit = 200}) async {
    if (_serverHttpUrl == null || _schoolId == null) return 0;

    final cursorRow =
        await (_db.select(_db.syncCursors)..where(
          (t) =>
              t.schoolId.equals(_schoolId!) &
              t.serverId.equals(_serverId ?? 'default'),
        )).getSingleOrNull();

    final lastSequence = cursorRow?.lastServerSequence ?? 0;

    final events = await _transport.downloadEventsSince(
      serverUrl: _serverHttpUrl!,
      schoolId: _schoolId!,
      sinceSequence: lastSequence,
      limit: limit,
    );

    int appliedCount = 0;
    for (final event in events) {
      await applyIncomingEvent(event);
      appliedCount++;
    }

    return appliedCount;
  }

  /// Applies an incoming sync event (from WebSocket or catch-up) to local SQLite
  Future<void> applyIncomingEvent(SyncEventModel event) async {
    // 1. Ignore own event echo
    if (event.deviceId == _currentDeviceId) {
      if (event.serverSequence != null) {
        await _updateCursor(event.serverSequence!);
      }
      return;
    }

    // 2. Idempotency check: if event was already applied and marked synced
    final existing =
        await (_db.select(_db.syncEvents)
          ..where((t) => t.eventId.equals(event.eventId))).getSingleOrNull();

    if (existing != null && existing.status == SyncEventStatus.synced) {
      if (event.serverSequence != null) {
        await _updateCursor(event.serverSequence!);
      }
      return;
    }

    // 3. Find matching entity handler
    final handler = _handlers.firstWhere(
      (h) => h.canHandle(event.entityType),
      orElse:
          () =>
              throw UnsupportedError(
                'No handler registered for entityType: ${event.entityType}',
              ),
    );

    // 4. Apply within local SQLite transaction
    await _db.transaction(() async {
      try {
        await handler.apply(event, _db, _conflictManager);

        // Record applied event in sync_events
        await _db
            .into(_db.syncEvents)
            .insertOnConflictUpdate(
              SyncEventsCompanion.insert(
                eventId: event.eventId,
                schoolId: event.schoolId,
                deviceId: event.deviceId,
                userId: event.userId,
                entityType: event.entityType,
                entityId: event.entityId,
                operation: event.operation,
                version: Value(event.version),
                payload: jsonEncode(event.payload),
                serverSequence: Value(event.serverSequence),
                status: const Value(SyncEventStatus.synced),
                createdAt: event.timestamp,
                syncedAt: Value(DateTime.now()),
              ),
            );

        if (event.serverSequence != null) {
          await _updateCursor(event.serverSequence!);
        }

        // 5. Check if any deferred events can now be applied
        final resolvable = _deferredEventManager.takeResolvableEvents(
          event.entityType,
          event.entityId,
        );
        for (final deferred in resolvable) {
          await applyIncomingEvent(deferred);
        }
      } on MissingDependencyException catch (dep) {
        // Parent entity missing: defer until parent arrives
        _deferredEventManager.defer(
          event: event,
          requiredEntityType: dep.requiredEntityType,
          requiredEntityId: dep.requiredEntityId,
        );
      }
    });
  }

  Future<void> _updateCursor(int sequence) async {
    final serverKey = _serverId ?? 'default';
    final existing =
        await (_db.select(_db.syncCursors)..where(
          (t) => t.schoolId.equals(_schoolId!) & t.serverId.equals(serverKey),
        )).getSingleOrNull();

    if (existing == null || sequence > existing.lastServerSequence) {
      await _db
          .into(_db.syncCursors)
          .insertOnConflictUpdate(
            SyncCursorsCompanion.insert(
              schoolId: _schoolId!,
              serverId: serverKey,
              lastServerSequence: Value(sequence),
              lastSyncedAt: DateTime.now(),
            ),
          );
    }
  }

  /// Resolves a conflict and updates local DB according to resolution choice:
  /// - 'keep_local': leaves local database state as-is, updates conflict record and re-enqueues local state
  /// - 'keep_remote': applies remote payload to local database via entity handler
  /// - 'merged': applies merged payload to local database via entity handler and enqueues to peers
  Future<void> resolveConflictWithAction({
    required String conflictId,
    required String resolvedByUserId,
    required String resolution, // 'keep_local', 'keep_remote', 'merged'
    Map<String, dynamic>? customMergedPayload,
  }) async {
    final conflict =
        await (_db.select(_db.syncConflicts)
          ..where((t) => t.id.equals(conflictId))).getSingleOrNull();

    if (conflict == null) return;

    if (resolution == 'keep_remote') {
      final remotePayload =
          jsonDecode(conflict.remotePayload) as Map<String, dynamic>;
      final handler = _handlers.firstWhere(
        (h) => h.canHandle(conflict.entityType),
        orElse:
            () =>
                throw UnsupportedError('No handler for ${conflict.entityType}'),
      );
      final syntheticEvent = SyncEventModel(
        eventId: conflict.remoteEventId ?? UuidGenerator.v4(),
        schoolId: conflict.schoolId,
        deviceId: 'server',
        userId: resolvedByUserId,
        entityType: conflict.entityType,
        entityId: conflict.entityId,
        operation: SyncOperation.update,
        timestamp: DateTime.now(),
        payload: remotePayload,
      );
      await _db.transaction(() async {
        await handler.apply(syntheticEvent, _db, _conflictManager);
      });
    } else if (resolution == 'merged' && customMergedPayload != null) {
      final handler = _handlers.firstWhere(
        (h) => h.canHandle(conflict.entityType),
        orElse:
            () =>
                throw UnsupportedError('No handler for ${conflict.entityType}'),
      );
      final syntheticEvent = SyncEventModel(
        eventId: UuidGenerator.v4(),
        schoolId: conflict.schoolId,
        deviceId: _currentDeviceId ?? 'local',
        userId: resolvedByUserId,
        entityType: conflict.entityType,
        entityId: conflict.entityId,
        operation: SyncOperation.update,
        timestamp: DateTime.now(),
        payload: customMergedPayload,
      );
      await _db.transaction(() async {
        await handler.apply(syntheticEvent, _db, _conflictManager);
      });
      // Also enqueue this merged state so remote server and peers converge
      await enqueue(
        schoolId: conflict.schoolId,
        userId: resolvedByUserId,
        entityType: conflict.entityType,
        entityId: conflict.entityId,
        operation: SyncOperation.update,
        payload: customMergedPayload,
      );
    } else if (resolution == 'keep_local') {
      final localPayload =
          jsonDecode(conflict.localPayload) as Map<String, dynamic>;
      final handler = _handlers.firstWhere(
        (h) => h.canHandle(conflict.entityType),
        orElse:
            () =>
                throw UnsupportedError('No handler for ${conflict.entityType}'),
      );
      final syntheticEvent = SyncEventModel(
        eventId: UuidGenerator.v4(),
        schoolId: conflict.schoolId,
        deviceId: _currentDeviceId ?? 'local',
        userId: resolvedByUserId,
        entityType: conflict.entityType,
        entityId: conflict.entityId,
        operation: SyncOperation.update,
        timestamp: DateTime.now(),
        payload: localPayload,
      );
      await _db.transaction(() async {
        await handler.apply(syntheticEvent, _db, _conflictManager);
      });

      // Re-enqueue local state so peers receive local resolution
      await enqueue(
        schoolId: conflict.schoolId,
        userId: resolvedByUserId,
        entityType: conflict.entityType,
        entityId: conflict.entityId,
        operation: SyncOperation.update,
        payload: localPayload,
      );
    }

    await _conflictManager.resolveConflict(
      conflictId: conflictId,
      resolvedByUserId: resolvedByUserId,
      resolution: resolution,
      mergedPayload: customMergedPayload,
    );
  }

  Future<int> getPendingCount() async {
    return await _queue.getPendingCount();
  }

  void _updateStatus(SyncConnectivityState state) async {
    if (_isDisposed) return;
    _connectivity = state;
    try {
      final count = await getPendingCount();
      if (!_isDisposed && !_statusController.isClosed) {
        _statusController.add(
          SyncStatusInfo(
            connectivity: _connectivity,
            serverUrl: _serverHttpUrl,
            serverId: _serverId,
            pendingCount: count,
            lastSyncTime: _lastSyncTime,
            errorMessage: _errorMessage,
          ),
        );
      }
    } catch (_) {}
  }

  void dispose() {
    _isDisposed = true;
    _transport.dispose();
    if (!_statusController.isClosed) _statusController.close();
  }
}
