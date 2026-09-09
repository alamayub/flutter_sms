// test/duplicate_event_idempotency_test.dart
import 'dart:convert';
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
  late AppDatabase db;
  late DeviceService deviceService;
  late ServerStorage serverStorage;
  late SchoolServer server;
  late SyncEngine syncEngine;
  late HttpClient httpClient;

  const schoolId = 'sch_idempotency_test';
  const schoolName = 'Idempotency Academy';

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('idempotency_test_');
    db = AppDatabase(NativeDatabase(File('${tempDir.path}/client.sqlite')));
    deviceService = DeviceService(db);

    serverStorage = ServerStorage.inMemory();
    server = SchoolServer(
      host: InternetAddress.loopbackIPv4,
      port: 0,
      schoolId: schoolId,
      schoolName: schoolName,
      storage: serverStorage,
      enableDiscovery: false,
    );
    await server.start();

    // Register and approve client test devices on server
    serverStorage.registerDevice(
      deviceId: 'dev_test_device',
      schoolId: schoolId,
      deviceName: 'Test Phone',
      deviceType: 'mobile',
    );
    serverStorage.approveDevice('dev_test_device');

    serverStorage.registerDevice(
      deviceId: 'dev_batch',
      schoolId: schoolId,
      deviceName: 'Batch Device',
      deviceType: 'desktop',
    );
    serverStorage.approveDevice('dev_batch');

    syncEngine = SyncEngine(db: db, deviceService: deviceService);
    await syncEngine.initialize(
      schoolId: schoolId,
      serverHttpUrl: 'http://127.0.0.1:${server.actualPort}',
    );

    httpClient = HttpClient();
  });

  tearDown(() async {
    httpClient.close();
    syncEngine.dispose();
    await server.stop();
    serverStorage.close();
    await db.close();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test(
    'Server idempotently handles duplicate POST /api/v1/sync/events without duplicate rows or sequence shifts',
    () async {
      final payload = {
        'events': [
          {
            'eventId': 'duplicate_evt_1',
            'schoolId': schoolId,
            'deviceId': 'dev_test_device',
            'userId': 'usr_test_teacher',
            'entityType': SyncEntityType.attendance,
            'entityId': 'att_idem_1',
            'operation': SyncOperation.create,
            'version': 1,
            'payload': {
              'academicYearId': 'ay_1',
              'date': '2026-09-10',
              'studentId': 'stu_idem_1',
              'classId': 'cls_1',
              'sectionId': 'sec_1',
              'status': 'present',
            },
            'timestamp': DateTime.now().toIso8601String(),
          },
        ],
      };

      // 1. Post event the first time
      var req = await httpClient.postUrl(
        Uri.parse('http://127.0.0.1:${server.actualPort}/api/v1/sync/events'),
      );
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode(payload));
      var res = await req.close();
      expect(res.statusCode, equals(HttpStatus.ok));

      var body =
          jsonDecode(await utf8.decodeStream(res)) as Map<String, dynamic>;
      final acks1 = body['acknowledged'] as List<dynamic>;
      expect(acks1.length, equals(1));
      final firstSequence = acks1[0]['sequence'] as int;
      expect(firstSequence, equals(1));

      // 2. Post exact same event second time (network retry / timeout replay)
      req = await httpClient.postUrl(
        Uri.parse('http://127.0.0.1:${server.actualPort}/api/v1/sync/events'),
      );
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode(payload));
      res = await req.close();
      expect(res.statusCode, equals(HttpStatus.ok));

      body = jsonDecode(await utf8.decodeStream(res)) as Map<String, dynamic>;
      final acks2 = body['acknowledged'] as List<dynamic>;
      expect(acks2.length, equals(1));
      final secondSequence = acks2[0]['sequence'] as int;

      // Both sequence numbers MUST be identical
      expect(secondSequence, equals(firstSequence));

      // Server must only have stored 1 event
      expect(serverStorage.getTotalEventCount(), equals(1));
    },
  );

  test(
    'Client idempotently applies repeated incoming events with no duplication or database errors',
    () async {
      final incomingEvent = SyncEventModel(
        eventId: 'evt_client_idem_99',
        schoolId: schoolId,
        deviceId: 'dev_remote_sender',
        userId: 'usr_remote_teacher',
        entityType: SyncEntityType.attendance,
        entityId: 'att_idem_client_1',
        operation: SyncOperation.create,
        version: 1,
        payload: {
          'academicYearId': 'ay_1',
          'date': '2026-09-10',
          'studentId': 'stu_client_idem_1',
          'classId': 'cls_1',
          'sectionId': 'sec_1',
          'status': 'present',
        },
        serverSequence: 10,
        status: SyncEventStatus.synced,
        timestamp: DateTime.now(),
      );

      // Apply 5 times in a row
      for (int i = 0; i < 5; i++) {
        await syncEngine.applyIncomingEvent(incomingEvent);
      }

      // Verify local attendance records table has exactly 1 row
      final records = await db.select(db.attendance).get();
      expect(records.length, equals(1));
      expect(records.first.studentId, equals('stu_client_idem_1'));
      expect(records.first.status, equals(AttendanceStatus.present));

      // Verify local sync_events has exactly 1 row
      final syncEvents = await db.select(db.syncEvents).get();
      expect(syncEvents.length, equals(1));
      expect(syncEvents.first.eventId, equals('evt_client_idem_99'));

      // Verify sync_conflicts has 0 rows (duplicate application is not a conflict)
      final conflicts = await db.select(db.syncConflicts).get();
      expect(conflicts.length, equals(0));
    },
  );

  test(
    'Batch ingestion with mixed existing and novel events preserves correct idempotency and sequencing',
    () async {
      // Ingest event A
      final seqA = serverStorage.ingestEvent(
        SyncEventModel(
          eventId: 'evt_batch_A',
          schoolId: schoolId,
          deviceId: 'dev_batch',
          userId: 'usr_batch',
          entityType: SyncEntityType.attendance,
          entityId: 'att_A',
          operation: SyncOperation.create,
          payload: {'studentId': 'stu_A', 'status': 'present'},
          timestamp: DateTime.now(),
        ),
      );
      expect(seqA, equals(1));

      // Ingest batch containing event A (duplicate) and event B (new)
      final req = await httpClient.postUrl(
        Uri.parse('http://127.0.0.1:${server.actualPort}/api/v1/sync/events'),
      );
      req.headers.contentType = ContentType.json;
      req.write(
        jsonEncode({
          'events': [
            {
              'eventId': 'evt_batch_A',
              'schoolId': schoolId,
              'deviceId': 'dev_batch',
              'userId': 'usr_batch',
              'entityType': SyncEntityType.attendance,
              'entityId': 'att_A',
              'operation': SyncOperation.create,
              'version': 1,
              'payload': {'studentId': 'stu_A', 'status': 'present'},
              'timestamp': DateTime.now().toIso8601String(),
            },
            {
              'eventId': 'evt_batch_B',
              'schoolId': schoolId,
              'deviceId': 'dev_batch',
              'userId': 'usr_batch',
              'entityType': SyncEntityType.attendance,
              'entityId': 'att_B',
              'operation': SyncOperation.create,
              'version': 1,
              'payload': {'studentId': 'stu_B', 'status': 'absent'},
              'timestamp': DateTime.now().toIso8601String(),
            },
          ],
        }),
      );
      final res = await req.close();
      expect(res.statusCode, equals(HttpStatus.ok));

      final body =
          jsonDecode(await utf8.decodeStream(res)) as Map<String, dynamic>;
      final acks = body['acknowledged'] as List<dynamic>;
      expect(acks.length, equals(2));

      final ackA = acks.firstWhere((a) => a['eventId'] == 'evt_batch_A');
      final ackB = acks.firstWhere((a) => a['eventId'] == 'evt_batch_B');

      expect(ackA['sequence'], equals(1)); // Returned original sequence
      expect(ackB['sequence'], equals(2)); // Assigned new sequence

      expect(serverStorage.getTotalEventCount(), equals(2));
    },
  );
}
