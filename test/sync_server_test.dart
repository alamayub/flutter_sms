// test/sync_server_test.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sms/core/constants/app_constants.dart';
import 'package:sms/features/sync/server/school_server.dart';
import 'package:sms/features/sync/server/server_storage.dart';

void main() {
  late ServerStorage storage;
  late SchoolServer server;
  late HttpClient client;
  final schoolId = 'test_sch_01';
  final schoolName = 'Test Academy';

  setUp(() async {
    storage = ServerStorage.inMemory();
    server = SchoolServer(
      host: InternetAddress.loopbackIPv4,
      port: 0, // ephemeral port
      schoolId: schoolId,
      schoolName: schoolName,
      storage: storage,
      enableDiscovery: false,
    );
    await server.start();
    client = HttpClient();
  });

  tearDown(() async {
    client.close();
    await server.stop();
    storage.close();
  });

  test(
    'GET /health returns 200 with school info and accessible database',
    () async {
      final req = await client.getUrl(
        Uri.parse('http://127.0.0.1:${server.actualPort}/health'),
      );
      final res = await req.close();
      expect(res.statusCode, equals(HttpStatus.ok));

      final body = await utf8.decodeStream(res);
      final data = jsonDecode(body) as Map<String, dynamic>;
      expect(data['status'], equals('ok'));
      expect(data['database'], equals('accessible'));
      expect(data['schoolConfigured'], isTrue);
      expect(data['schoolId'], equals(schoolId));
      expect(data['schoolName'], equals(schoolName));
    },
  );

  test(
    'Device registration, auto-approval for first device, and approval/revocation',
    () async {
      // 1. Register first device (Teacher Phone) -> auto-approved
      var req = await client.postUrl(
        Uri.parse(
          'http://127.0.0.1:${server.actualPort}/api/v1/devices/register',
        ),
      );
      req.headers.contentType = ContentType.json;
      req.write(
        jsonEncode({
          'deviceId': 'dev_teacher_1',
          'schoolId': schoolId,
          'deviceName': 'Teacher Phone - Ram',
          'deviceType': 'mobile',
          'pairingCode': '123456',
        }),
      );
      var res = await req.close();
      expect(res.statusCode, equals(HttpStatus.ok));
      var body =
          jsonDecode(await utf8.decodeStream(res)) as Map<String, dynamic>;
      expect(body['status'], equals(DeviceStatus.approved));

      // 2. Register second device (Teacher Phone 2) -> pending_approval
      req = await client.postUrl(
        Uri.parse(
          'http://127.0.0.1:${server.actualPort}/api/v1/devices/register',
        ),
      );
      req.headers.contentType = ContentType.json;
      req.write(
        jsonEncode({
          'deviceId': 'dev_teacher_2',
          'schoolId': schoolId,
          'deviceName': 'Teacher Phone - Sita',
          'deviceType': 'mobile',
          'pairingCode': '654321',
        }),
      );
      res = await req.close();
      expect(res.statusCode, equals(HttpStatus.ok));
      body = jsonDecode(await utf8.decodeStream(res)) as Map<String, dynamic>;
      expect(body['status'], equals(DeviceStatus.pendingApproval));

      // 3. Admin approves second device
      req = await client.postUrl(
        Uri.parse(
          'http://127.0.0.1:${server.actualPort}/api/v1/devices/approve',
        ),
      );
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode({'deviceId': 'dev_teacher_2'}));
      res = await req.close();
      expect(res.statusCode, equals(HttpStatus.ok));

      // Verify status is now approved
      final dev2 = storage.getDevice('dev_teacher_2');
      expect(dev2?.status, equals(DeviceStatus.approved));

      // 4. Admin revokes device
      req = await client.postUrl(
        Uri.parse(
          'http://127.0.0.1:${server.actualPort}/api/v1/devices/revoke',
        ),
      );
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode({'deviceId': 'dev_teacher_2'}));
      res = await req.close();
      expect(res.statusCode, equals(HttpStatus.ok));

      final dev2Revoked = storage.getDevice('dev_teacher_2');
      expect(dev2Revoked?.status, equals(DeviceStatus.revoked));
    },
  );

  test(
    'Event ingestion assigns auto-incrementing sequence and handles duplicates idempotently',
    () async {
      // Register teacher device
      storage.registerDevice(
        deviceId: 'dev_teacher_1',
        schoolId: schoolId,
        deviceName: 'Teacher Phone',
        deviceType: 'mobile',
      );

      // Ingest event 1
      var req = await client.postUrl(
        Uri.parse('http://127.0.0.1:${server.actualPort}/api/v1/sync/events'),
      );
      req.headers.contentType = ContentType.json;
      req.write(
        jsonEncode({
          'events': [
            {
              'eventId': 'evt_001',
              'schoolId': schoolId,
              'deviceId': 'dev_teacher_1',
              'userId': 'usr_teacher',
              'entityType': 'attendance',
              'entityId': 'att_101',
              'operation': 'create',
              'version': 1,
              'payload': {'studentId': 'stu_1', 'status': 'present'},
              'timestamp': DateTime.now().toIso8601String(),
            },
          ],
        }),
      );
      var res = await req.close();
      expect(res.statusCode, equals(HttpStatus.ok));
      var body =
          jsonDecode(await utf8.decodeStream(res)) as Map<String, dynamic>;
      final acks = body['acknowledged'] as List;
      expect(acks.length, equals(1));
      final seq1 = acks[0]['sequence'] as int;
      expect(acks[0]['eventId'], equals('evt_001'));
      expect(seq1, greaterThan(0));

      // Ingest event 2
      req = await client.postUrl(
        Uri.parse('http://127.0.0.1:${server.actualPort}/api/v1/sync/events'),
      );
      req.headers.contentType = ContentType.json;
      req.write(
        jsonEncode({
          'events': [
            {
              'eventId': 'evt_002',
              'schoolId': schoolId,
              'deviceId': 'dev_teacher_1',
              'userId': 'usr_teacher',
              'entityType': 'attendance',
              'entityId': 'att_102',
              'operation': 'create',
              'version': 1,
              'payload': {'studentId': 'stu_2', 'status': 'absent'},
              'timestamp': DateTime.now().toIso8601String(),
            },
          ],
        }),
      );
      res = await req.close();
      body = jsonDecode(await utf8.decodeStream(res)) as Map<String, dynamic>;
      final acks2 = body['acknowledged'] as List;
      final seq2 = acks2[0]['sequence'] as int;
      expect(seq2, equals(seq1 + 1));

      // Ingest DUPLICATE of event 1 -> must return identical sequence and not insert duplicate
      req = await client.postUrl(
        Uri.parse('http://127.0.0.1:${server.actualPort}/api/v1/sync/events'),
      );
      req.headers.contentType = ContentType.json;
      req.write(
        jsonEncode({
          'events': [
            {
              'eventId': 'evt_001',
              'schoolId': schoolId,
              'deviceId': 'dev_teacher_1',
              'userId': 'usr_teacher',
              'entityType': 'attendance',
              'entityId': 'att_101',
              'operation': 'create',
              'version': 1,
              'payload': {'studentId': 'stu_1', 'status': 'present'},
              'timestamp': DateTime.now().toIso8601String(),
            },
          ],
        }),
      );
      res = await req.close();
      body = jsonDecode(await utf8.decodeStream(res)) as Map<String, dynamic>;
      final duplicateAcks = body['acknowledged'] as List;
      expect(duplicateAcks[0]['sequence'], equals(seq1));

      // Total stored events must still be exactly 2
      expect(storage.getTotalEventCount(), equals(2));

      // Verify GET /api/v1/sync/events?since=seq1 returns only event 2
      req = await client.getUrl(
        Uri.parse(
          'http://127.0.0.1:${server.actualPort}/api/v1/sync/events?schoolId=$schoolId&since=$seq1',
        ),
      );
      res = await req.close();
      body = jsonDecode(await utf8.decodeStream(res)) as Map<String, dynamic>;
      final events = body['events'] as List;
      expect(events.length, equals(1));
      expect(events[0]['eventId'], equals('evt_002'));
    },
  );

  test('WebSocket real-time broadcast to connected peer devices', () async {
    // Register two devices
    storage.registerDevice(
      deviceId: 'dev_sender',
      schoolId: schoolId,
      deviceName: 'Sender Phone',
      deviceType: 'mobile',
    );
    storage.registerDevice(
      deviceId: 'dev_receiver',
      schoolId: schoolId,
      deviceName: 'Receiver Desktop',
      deviceType: 'desktop',
    );
    storage.approveDevice('dev_receiver');

    // Connect receiver to WebSocket
    final receiverSocket = await WebSocket.connect(
      'ws://127.0.0.1:${server.actualPort}/ws?deviceId=dev_receiver&schoolId=$schoolId',
    );

    final completer = Completer<Map<String, dynamic>>();

    receiverSocket.listen((message) {
      final data = jsonDecode(message.toString()) as Map<String, dynamic>;
      if (data['type'] == 'event') {
        completer.complete(data);
      }
    });

    // Sender ingests an event via REST
    final req = await client.postUrl(
      Uri.parse('http://127.0.0.1:${server.actualPort}/api/v1/sync/events'),
    );
    req.headers.contentType = ContentType.json;
    req.write(
      jsonEncode({
        'events': [
          {
            'eventId': 'evt_broadcast_1',
            'schoolId': schoolId,
            'deviceId': 'dev_sender',
            'userId': 'usr_teacher',
            'entityType': 'attendance',
            'entityId': 'att_broadcast_01',
            'operation': 'create',
            'version': 1,
            'payload': {'studentId': 'stu_99', 'status': 'present'},
            'timestamp': DateTime.now().toIso8601String(),
          },
        ],
      }),
    );
    final res = await req.close();
    expect(res.statusCode, equals(HttpStatus.ok));

    // Receiver should get real-time broadcast message
    final broadcastMsg = await completer.future.timeout(
      const Duration(seconds: 3),
    );
    expect(broadcastMsg['type'], equals('event'));
    final receivedEvent = broadcastMsg['event'] as Map<String, dynamic>;
    expect(receivedEvent['eventId'], equals('evt_broadcast_1'));
    expect(receivedEvent['payload']['studentId'], equals('stu_99'));

    await receiverSocket.close();
  });
}
