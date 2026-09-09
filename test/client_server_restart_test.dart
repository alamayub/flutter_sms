// test/client_server_restart_test.dart
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sms/core/constants/app_constants.dart';
import 'package:sms/core/database/app_database.dart';
import 'package:sms/features/sync/client/device_service.dart';
import 'package:sms/features/sync/client/sync_engine.dart';
import 'package:sms/features/sync/domain/sync_event_model.dart';
import 'package:sms/features/sync/server/school_server.dart';
import 'package:sms/features/sync/server/server_storage.dart';

void main() {
  late Directory tempDir;
  late File clientDbFile;
  late File serverDbFile;
  const schoolId = 'sch_restart_test';
  const schoolName = 'Durable Academy';

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('restart_test_');
    clientDbFile = File('${tempDir.path}/client_durable.sqlite');
    serverDbFile = File('${tempDir.path}/server_durable.sqlite');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'Server restart preserves monotonic sequence numbers, registered devices, and event history',
    () async {
      // 1. Initial server run with file-backed storage
      var storage = ServerStorage.openFile(serverDbFile.path);
      var server = SchoolServer(
        host: InternetAddress.loopbackIPv4,
        port: 0,
        schoolId: schoolId,
        schoolName: schoolName,
        storage: storage,
        enableDiscovery: false,
      );
      await server.start();

      // Register a device and ingest 2 events
      storage.registerDevice(
        deviceId: 'dev_durable_1',
        schoolId: schoolId,
        deviceName: 'Durable Device 1',
        deviceType: 'desktop',
      );
      storage.approveDevice('dev_durable_1');

      final seq1 = storage.ingestEvent(
        SyncEventModel(
          eventId: 'evt_durable_1',
          schoolId: schoolId,
          deviceId: 'dev_durable_1',
          userId: 'usr_1',
          entityType: SyncEntityType.attendance,
          entityId: 'att_1',
          operation: SyncOperation.create,
          payload: {'studentId': 'stu_1', 'status': 'present'},
          timestamp: DateTime.now(),
        ),
      );
      final seq2 = storage.ingestEvent(
        SyncEventModel(
          eventId: 'evt_durable_2',
          schoolId: schoolId,
          deviceId: 'dev_durable_1',
          userId: 'usr_1',
          entityType: SyncEntityType.attendance,
          entityId: 'att_2',
          operation: SyncOperation.create,
          payload: {'studentId': 'stu_2', 'status': 'absent'},
          timestamp: DateTime.now(),
        ),
      );

      expect(seq1, equals(1));
      expect(seq2, equals(2));

      // Stop server completely
      await server.stop();
      storage.close();

      // 2. Restart server from the existing database file
      storage = ServerStorage.openFile(serverDbFile.path);
      server = SchoolServer(
        host: InternetAddress.loopbackIPv4,
        port: 0,
        schoolId: schoolId,
        schoolName: schoolName,
        storage: storage,
        enableDiscovery: false,
      );
      await server.start();

      try {
        // Verify device approval survived server restart
        final dev = storage.getDevice('dev_durable_1');
        expect(dev, isNotNull);
        expect(dev!.status, equals(DeviceStatus.approved));

        // Verify previous events survived
        final pastEvents = storage.getEventsSince(
          schoolId: schoolId,
          sinceSequence: 0,
        );
        expect(pastEvents.length, equals(2));

        // Ingest 3rd event after restart -> must receive sequence 3 (strict monotonic continuity!)
        final seq3 = storage.ingestEvent(
          SyncEventModel(
            eventId: 'evt_durable_3',
            schoolId: schoolId,
            deviceId: 'dev_durable_1',
            userId: 'usr_1',
            entityType: SyncEntityType.attendance,
            entityId: 'att_3',
            operation: SyncOperation.create,
            payload: {'studentId': 'stu_3', 'status': 'late'},
            timestamp: DateTime.now(),
          ),
        );

        expect(
          seq3,
          equals(3),
          reason: 'Server restart must continue monotonic sequence progression',
        );

        // Total count should be 3
        expect(storage.getTotalEventCount(), equals(3));
      } finally {
        await server.stop();
        storage.close();
      }
    },
  );

  test(
    'Client restart retains cursor and resumes sync without re-downloading existing records',
    () async {
      // 1. Setup server with 3 events
      final storage = ServerStorage.openFile(serverDbFile.path);
      final server = SchoolServer(
        host: InternetAddress.loopbackIPv4,
        port: 0,
        schoolId: schoolId,
        schoolName: schoolName,
        storage: storage,
        enableDiscovery: false,
      );
      await server.start();
      final serverUrl = 'http://127.0.0.1:${server.actualPort}';

      // Ingest 2 events on server
      storage.ingestEvent(
        SyncEventModel(
          eventId: 'evt_init_1',
          schoolId: schoolId,
          deviceId: 'dev_server_source',
          userId: 'usr_srv',
          entityType: SyncEntityType.attendance,
          entityId: 'att_init_1',
          operation: SyncOperation.create,
          payload: {
            'academicYearId': 'ay_1',
            'date': '2026-09-10',
            'studentId': 'stu_init_1',
            'classId': 'cls_1',
            'sectionId': 'sec_1',
            'status': 'present',
          },
          timestamp: DateTime.now(),
        ),
      );

      storage.ingestEvent(
        SyncEventModel(
          eventId: 'evt_init_2',
          schoolId: schoolId,
          deviceId: 'dev_server_source',
          userId: 'usr_srv',
          entityType: SyncEntityType.attendance,
          entityId: 'att_init_2',
          operation: SyncOperation.create,
          payload: {
            'academicYearId': 'ay_1',
            'date': '2026-09-10',
            'studentId': 'stu_init_2',
            'classId': 'cls_1',
            'sectionId': 'sec_1',
            'status': 'absent',
          },
          timestamp: DateTime.now(),
        ),
      );

      // 2. Client run 1: downloads the 2 events and updates cursor to 2
      var clientDb = AppDatabase(NativeDatabase(clientDbFile));
      var deviceService = DeviceService(clientDb);
      var syncEngine = SyncEngine(db: clientDb, deviceService: deviceService);

      await syncEngine.initialize(schoolId: schoolId, serverHttpUrl: serverUrl);
      expect(
        await clientDb.select(clientDb.attendance).get().then((l) => l.length),
        equals(2),
      );

      final cursors = await clientDb.select(clientDb.syncCursors).get();
      expect(cursors.isNotEmpty, isTrue);
      expect(cursors.first.lastServerSequence, equals(2));

      final originalDeviceId = await deviceService.getOrCreateDeviceId();

      // Client process terminates (simulating app close)
      syncEngine.dispose();
      await clientDb.close();

      // Ingest a 3rd event while client is offline
      storage.ingestEvent(
        SyncEventModel(
          eventId: 'evt_init_3',
          schoolId: schoolId,
          deviceId: 'dev_server_source',
          userId: 'usr_srv',
          entityType: SyncEntityType.attendance,
          entityId: 'att_init_3',
          operation: SyncOperation.create,
          payload: {
            'academicYearId': 'ay_1',
            'date': '2026-09-10',
            'studentId': 'stu_init_3',
            'classId': 'cls_1',
            'sectionId': 'sec_1',
            'status': 'late',
          },
          timestamp: DateTime.now(),
        ),
      );

      // 3. Client run 2: restarts with same database
      clientDb = AppDatabase(NativeDatabase(clientDbFile));
      deviceService = DeviceService(clientDb);
      syncEngine = SyncEngine(db: clientDb, deviceService: deviceService);

      // Verify device identity persisted across restart
      final restartedDeviceId = await deviceService.getOrCreateDeviceId();
      expect(restartedDeviceId, equals(originalDeviceId));

      // Initialize syncEngine again: automatically performs catch-up sync on connect
      await syncEngine.initialize(schoolId: schoolId, serverHttpUrl: serverUrl);

      // Total attendance in client DB is now 3 (event 3 was downloaded during initialize)
      final allAttendance = await clientDb.select(clientDb.attendance).get();
      expect(allAttendance.length, equals(3));

      // Cursor is updated to 3
      final updatedCursors = await clientDb.select(clientDb.syncCursors).get();
      expect(updatedCursors.first.lastServerSequence, equals(3));

      // Subsequent download missing returns 0 because client is already caught up
      final downloadedAgain = await syncEngine.downloadMissing();
      expect(downloadedAgain, equals(0));

      // Cleanup
      syncEngine.dispose();
      await clientDb.close();
      await server.stop();
      storage.close();
    },
  );
}
