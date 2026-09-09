// lib/features/sync/server/school_server.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../../../core/utils/uuid_generator.dart';
import '../domain/sync_event_model.dart';
import 'server_discovery_beacon.dart';
import 'server_storage.dart';

class ConnectedClient {
  final WebSocket socket;
  final String deviceId;
  final String schoolId;

  ConnectedClient({
    required this.socket,
    required this.deviceId,
    required this.schoolId,
  });
}

class SchoolServer {
  final dynamic host; // InternetAddress or String
  final int port;
  final String schoolId;
  final String schoolName;
  final ServerStorage storage;
  final bool enableDiscovery;

  HttpServer? _httpServer;
  ServerDiscoveryBeacon? _beacon;
  final List<ConnectedClient> _clients = [];
  final DateTime _startTime = DateTime.now();
  late final String serverId;
  bool _isRunning = false;

  SchoolServer({
    dynamic host,
    this.port = 8080,
    required this.schoolId,
    required this.schoolName,
    required this.storage,
    this.enableDiscovery = true,
  }) : host = host ?? InternetAddress.anyIPv4 {
    serverId = storage.getServerInfo('server_id') ?? UuidGenerator.v4();
    storage.setServerInfo('server_id', serverId);
    storage.setServerInfo('school_id', schoolId);
    storage.setServerInfo('school_name', schoolName);
  }

  bool get isRunning => _isRunning;
  int get actualPort => _httpServer?.port ?? port;
  int get connectedClientsCount => _clients.length;

  Future<void> start() async {
    if (_isRunning) return;

    _httpServer = await HttpServer.bind(host, port);
    _isRunning = true;

    _httpServer!.listen(_handleHttpRequest);

    if (enableDiscovery) {
      _beacon = ServerDiscoveryBeacon(
        serverHttpPort: actualPort,
        schoolId: schoolId,
        schoolName: schoolName,
        serverId: serverId,
      );
      await _beacon!.start();
    }
  }

  Future<void> stop() async {
    _isRunning = false;
    _beacon?.stop();
    _beacon = null;

    for (final client in List<ConnectedClient>.from(_clients)) {
      try {
        await client.socket.close(WebSocketStatus.goingAway, 'Server stopping');
      } catch (_) {}
    }
    _clients.clear();

    await _httpServer?.close(force: true);
    _httpServer = null;
  }

  void _handleHttpRequest(HttpRequest request) async {
    // Add CORS headers for flexibility
    request.response.headers.add('Access-Control-Allow-Origin', '*');
    request.response.headers.add(
      'Access-Control-Allow-Methods',
      'GET, POST, OPTIONS',
    );
    request.response.headers.add(
      'Access-Control-Allow-Headers',
      'Content-Type, Authorization',
    );

    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.ok;
      await request.response.close();
      return;
    }

    final path = request.uri.path;

    try {
      if (path == '/ws') {
        await _handleWebSocketUpgrade(request);
        return;
      }

      if (path == '/health') {
        _handleHealth(request);
      } else if (path == '/admin/status') {
        _handleAdminStatus(request);
      } else if (path == '/api/v1/devices/register' &&
          request.method == 'POST') {
        await _handleDeviceRegister(request);
      } else if (path == '/api/v1/devices' && request.method == 'GET') {
        _handleListDevices(request);
      } else if (path == '/api/v1/devices/approve' &&
          request.method == 'POST') {
        await _handleApproveDevice(request);
      } else if (path == '/api/v1/devices/revoke' && request.method == 'POST') {
        await _handleRevokeDevice(request);
      } else if (path == '/api/v1/sync/events' && request.method == 'POST') {
        await _handleIngestEvents(request);
      } else if (path == '/api/v1/sync/events' && request.method == 'GET') {
        _handleGetEventsSince(request);
      } else {
        request.response
          ..statusCode = HttpStatus.notFound
          ..write(jsonEncode({'error': 'Not found'}))
          ..close();
      }
    } catch (e) {
      try {
        request.response
          ..statusCode = HttpStatus.internalServerError
          ..write(jsonEncode({'error': e.toString()}))
          ..close();
      } catch (_) {}
    }
  }

  void _handleHealth(HttpRequest request) {
    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.json
      ..write(
        jsonEncode({
          'status': 'ok',
          'database': 'accessible',
          'schoolConfigured': true,
          'version': '1.0.0',
          'serverId': serverId,
          'schoolId': schoolId,
          'schoolName': schoolName,
          'serverTime': DateTime.now().toIso8601String(),
        }),
      )
      ..close();
  }

  void _handleAdminStatus(HttpRequest request) {
    final uptime = DateTime.now().difference(_startTime).inSeconds;
    final totalEvents = storage.getTotalEventCount();
    final deviceList = storage.listDevices(schoolId);

    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.json
      ..write(
        jsonEncode({
          'status': 'Running',
          'schoolId': schoolId,
          'schoolName': schoolName,
          'serverId': serverId,
          'uptimeSeconds': uptime,
          'connectedDevices': _clients.length,
          'totalEventsReceived': totalEvents,
          'devices': deviceList.map((d) => d.toJson()).toList(),
        }),
      )
      ..close();
  }

  Future<void> _handleDeviceRegister(HttpRequest request) async {
    final body = await utf8.decodeStream(request);
    final data = jsonDecode(body) as Map<String, dynamic>;

    final reqDeviceId = data['deviceId'] as String?;
    final reqSchoolId = data['schoolId'] as String?;
    final reqDeviceName = data['deviceName'] as String? ?? 'Unknown Device';
    final reqDeviceType = data['deviceType'] as String? ?? 'desktop';
    final reqPairingCode = data['pairingCode'] as String?;

    if (reqDeviceId == null || reqSchoolId == null) {
      request.response
        ..statusCode = HttpStatus.badRequest
        ..write(jsonEncode({'error': 'Missing deviceId or schoolId'}))
        ..close();
      return;
    }

    if (reqSchoolId != schoolId) {
      request.response
        ..statusCode = HttpStatus.forbidden
        ..write(
          jsonEncode({
            'error': 'School ID mismatch. This server serves school $schoolId',
          }),
        )
        ..close();
      return;
    }

    final device = storage.registerDevice(
      deviceId: reqDeviceId,
      schoolId: reqSchoolId,
      deviceName: reqDeviceName,
      deviceType: reqDeviceType,
      pairingCode: reqPairingCode,
    );

    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.json
      ..write(
        jsonEncode({
          'deviceId': device.deviceId,
          'schoolId': device.schoolId,
          'status': device.status,
          'serverId': serverId,
          'approved': device.isApproved,
        }),
      )
      ..close();
  }

  void _handleListDevices(HttpRequest request) {
    final reqSchoolId = request.uri.queryParameters['schoolId'] ?? schoolId;
    final devices = storage.listDevices(reqSchoolId);

    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.json
      ..write(jsonEncode({'devices': devices.map((d) => d.toJson()).toList()}))
      ..close();
  }

  Future<void> _handleApproveDevice(HttpRequest request) async {
    final body = await utf8.decodeStream(request);
    final data = jsonDecode(body) as Map<String, dynamic>;
    final reqDeviceId = data['deviceId'] as String?;

    if (reqDeviceId == null) {
      request.response
        ..statusCode = HttpStatus.badRequest
        ..write(jsonEncode({'error': 'Missing deviceId'}))
        ..close();
      return;
    }

    final approved = storage.approveDevice(reqDeviceId);
    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.json
      ..write(jsonEncode({'success': approved}))
      ..close();
  }

  Future<void> _handleRevokeDevice(HttpRequest request) async {
    final body = await utf8.decodeStream(request);
    final data = jsonDecode(body) as Map<String, dynamic>;
    final reqDeviceId = data['deviceId'] as String?;

    if (reqDeviceId == null) {
      request.response
        ..statusCode = HttpStatus.badRequest
        ..write(jsonEncode({'error': 'Missing deviceId'}))
        ..close();
      return;
    }

    final revoked = storage.revokeDevice(reqDeviceId);

    // Disconnect active socket if currently connected
    _clients.removeWhere((client) {
      if (client.deviceId == reqDeviceId) {
        client.socket.close(WebSocketStatus.policyViolation, 'Device revoked');
        return true;
      }
      return false;
    });

    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.json
      ..write(jsonEncode({'success': revoked}))
      ..close();
  }

  Future<void> _handleIngestEvents(HttpRequest request) async {
    final body = await utf8.decodeStream(request);
    final data = jsonDecode(body) as Map<String, dynamic>;
    final rawEvents = data['events'] as List<dynamic>?;

    if (rawEvents == null || rawEvents.isEmpty) {
      request.response
        ..statusCode = HttpStatus.badRequest
        ..write(jsonEncode({'error': 'No events in payload'}))
        ..close();
      return;
    }

    final acks = <Map<String, dynamic>>[];

    for (final raw in rawEvents) {
      final event = SyncEventModel.fromJson(raw as Map<String, dynamic>);

      // School isolation check
      if (event.schoolId != schoolId) {
        request.response
          ..statusCode = HttpStatus.forbidden
          ..write(jsonEncode({'error': 'School ID mismatch'}))
          ..close();
        return;
      }

      // Device authorization check
      final device = storage.getDevice(event.deviceId);
      if (device == null || !device.isApproved) {
        request.response
          ..statusCode = HttpStatus.unauthorized
          ..write(
            jsonEncode({'error': 'Device is not registered or not approved'}),
          )
          ..close();
        return;
      }

      // Ingest into persistent storage (idempotent: returns existing sequence if duplicate)
      final sequence = storage.ingestEvent(event);
      acks.add({'eventId': event.eventId, 'sequence': sequence});

      // Broadcast to other connected devices
      _broadcastEvent(event.copyWith(serverSequence: sequence), event.deviceId);
    }

    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.json
      ..write(jsonEncode({'acknowledged': acks}))
      ..close();
  }

  void _handleGetEventsSince(HttpRequest request) {
    final reqSchoolId = request.uri.queryParameters['schoolId'] ?? schoolId;
    final sinceStr = request.uri.queryParameters['since'] ?? '0';
    final since = int.tryParse(sinceStr) ?? 0;
    final limitStr = request.uri.queryParameters['limit'] ?? '200';
    final limit = int.tryParse(limitStr) ?? 200;

    if (reqSchoolId != schoolId) {
      request.response
        ..statusCode = HttpStatus.forbidden
        ..write(jsonEncode({'error': 'School ID mismatch'}))
        ..close();
      return;
    }

    final events = storage.getEventsSince(
      schoolId: reqSchoolId,
      sinceSequence: since,
      limit: limit,
    );

    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.json
      ..write(jsonEncode({'events': events.map((e) => e.toJson()).toList()}))
      ..close();
  }

  Future<void> _handleWebSocketUpgrade(HttpRequest request) async {
    final reqDeviceId = request.uri.queryParameters['deviceId'];
    final reqSchoolId = request.uri.queryParameters['schoolId'];

    if (reqDeviceId == null || reqSchoolId == null) {
      request.response
        ..statusCode = HttpStatus.badRequest
        ..write('Missing deviceId or schoolId')
        ..close();
      return;
    }

    if (reqSchoolId != schoolId) {
      request.response
        ..statusCode = HttpStatus.forbidden
        ..write('School ID mismatch')
        ..close();
      return;
    }

    final device = storage.getDevice(reqDeviceId);
    if (device == null || !device.isApproved) {
      request.response
        ..statusCode = HttpStatus.unauthorized
        ..write('Device not approved')
        ..close();
      return;
    }

    final socket = await WebSocketTransformer.upgrade(request);
    final client = ConnectedClient(
      socket: socket,
      deviceId: reqDeviceId,
      schoolId: reqSchoolId,
    );
    _clients.add(client);

    socket.listen(
      (message) {
        _handleWebSocketMessage(client, message);
      },
      onDone: () {
        _clients.remove(client);
      },
      onError: (_) {
        _clients.remove(client);
      },
    );

    // Send welcome message with current server sequence and serverId
    socket.add(
      jsonEncode({
        'type': 'welcome',
        'serverId': serverId,
        'schoolId': schoolId,
        'version': '1.0.0',
      }),
    );
  }

  void _handleWebSocketMessage(ConnectedClient client, dynamic message) {
    try {
      final data = jsonDecode(message.toString()) as Map<String, dynamic>;
      final type = data['type'] as String?;

      if (type == 'ping') {
        client.socket.add(
          jsonEncode({
            'type': 'pong',
            'timestamp': DateTime.now().toIso8601String(),
          }),
        );
        return;
      }

      if (type == 'event') {
        final rawEvent = data['event'] as Map<String, dynamic>?;
        if (rawEvent != null) {
          final event = SyncEventModel.fromJson(rawEvent);
          if (event.schoolId == schoolId) {
            final sequence = storage.ingestEvent(event);
            client.socket.add(
              jsonEncode({
                'type': 'ack',
                'eventId': event.eventId,
                'sequence': sequence,
              }),
            );
            _broadcastEvent(
              event.copyWith(serverSequence: sequence),
              client.deviceId,
            );
          }
        }
      }
    } catch (_) {}
  }

  void _broadcastEvent(SyncEventModel event, String senderDeviceId) {
    final message = jsonEncode({'type': 'event', 'event': event.toJson()});

    for (final client in _clients) {
      if (client.schoolId == event.schoolId &&
          client.deviceId != senderDeviceId) {
        try {
          client.socket.add(message);
        } catch (_) {}
      }
    }
  }
}
