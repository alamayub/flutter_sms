// lib/features/sync/client/sync_transport.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../domain/sync_event_model.dart';
import 'sync_websocket_client.dart';

class SyncTransport {
  final HttpClient _httpClient;
  SyncWebSocketClient? _wsClient;
  StreamSubscription? _eventSub;
  StreamSubscription? _connSub;

  SyncTransport({HttpClient? httpClient})
    : _httpClient = httpClient ?? HttpClient();

  Future<Map<String, dynamic>> checkHealth(String serverUrl) async {
    final uri = Uri.parse('$serverUrl/health');
    final req = await _httpClient
        .getUrl(uri)
        .timeout(const Duration(seconds: 3));
    final res = await req.close();
    final body = await utf8.decodeStream(res);
    if (res.statusCode != HttpStatus.ok) {
      throw HttpException(
        'Server returned HTTP ${res.statusCode}: $body',
        uri: uri,
      );
    }
    return jsonDecode(body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> registerDevice({
    required String serverUrl,
    required String deviceId,
    required String schoolId,
    required String deviceName,
    required String deviceType,
    String? pairingCode,
  }) async {
    final uri = Uri.parse('$serverUrl/api/v1/devices/register');
    final req = await _httpClient
        .postUrl(uri)
        .timeout(const Duration(seconds: 3));
    req.headers.contentType = ContentType.json;
    req.write(
      jsonEncode({
        'deviceId': deviceId,
        'schoolId': schoolId,
        'deviceName': deviceName,
        'deviceType': deviceType,
        'pairingCode': pairingCode,
      }),
    );
    final res = await req.close();
    final body = await utf8.decodeStream(res);
    if (res.statusCode != HttpStatus.ok) {
      throw HttpException(
        'Registration failed (${res.statusCode}): $body',
        uri: uri,
      );
    }
    return jsonDecode(body) as Map<String, dynamic>;
  }

  Future<Map<String, int>> uploadEventsBatch({
    required String serverUrl,
    required List<SyncEventModel> events,
  }) async {
    if (events.isEmpty) return {};

    final uri = Uri.parse('$serverUrl/api/v1/sync/events');
    final req = await _httpClient
        .postUrl(uri)
        .timeout(const Duration(seconds: 5));
    req.headers.contentType = ContentType.json;
    req.write(jsonEncode({'events': events.map((e) => e.toJson()).toList()}));

    final res = await req.close();
    final body = await utf8.decodeStream(res);
    if (res.statusCode != HttpStatus.ok) {
      throw HttpException(
        'Server rejected sync events (${res.statusCode}): $body',
        uri: uri,
      );
    }

    final json = jsonDecode(body) as Map<String, dynamic>;
    final acks = json['acknowledged'] as List<dynamic>? ?? [];
    final ackMap = <String, int>{};
    for (final ack in acks) {
      final ackObj = ack as Map<String, dynamic>;
      ackMap[ackObj['eventId'] as String] = ackObj['sequence'] as int;
    }
    return ackMap;
  }

  Future<List<SyncEventModel>> downloadEventsSince({
    required String serverUrl,
    required String schoolId,
    required int sinceSequence,
    int limit = 200,
  }) async {
    final uri = Uri.parse(
      '$serverUrl/api/v1/sync/events?schoolId=$schoolId&since=$sinceSequence&limit=$limit',
    );
    final req = await _httpClient
        .getUrl(uri)
        .timeout(const Duration(seconds: 5));
    final res = await req.close();
    final body = await utf8.decodeStream(res);

    if (res.statusCode != HttpStatus.ok) {
      throw HttpException(
        'Failed to download events (${res.statusCode}): $body',
        uri: uri,
      );
    }

    final json = jsonDecode(body) as Map<String, dynamic>;
    final rawList = json['events'] as List<dynamic>? ?? [];
    return rawList
        .map((e) => SyncEventModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> connectWebSocket({
    required String serverUrl,
    required String deviceId,
    required String schoolId,
    required void Function(SyncEventModel event) onEvent,
    required void Function(bool connected) onConnectionChange,
  }) async {
    final wsUrl = '${serverUrl.replaceFirst(RegExp(r'^http'), 'ws')}/ws';
    await disconnectWebSocket();

    _wsClient = SyncWebSocketClient(
      serverUrl: wsUrl,
      deviceId: deviceId,
      schoolId: schoolId,
    );

    _eventSub = _wsClient!.eventStream.listen(onEvent);
    _connSub = _wsClient!.connectionStateStream.listen(onConnectionChange);

    await _wsClient!.connect();
  }

  Future<void> disconnectWebSocket() async {
    await _eventSub?.cancel();
    await _connSub?.cancel();
    _eventSub = null;
    _connSub = null;
    _wsClient?.dispose();
    _wsClient = null;
  }

  void dispose() {
    disconnectWebSocket();
  }
}
