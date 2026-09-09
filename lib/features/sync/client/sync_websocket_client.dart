// lib/features/sync/client/sync_websocket_client.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../domain/sync_event_model.dart';

class SyncWebSocketClient {
  final String serverUrl; // e.g. "ws://192.168.1.100:8080/ws"
  final String deviceId;
  final String schoolId;

  WebSocket? _socket;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  bool _isDisposed = false;
  int _reconnectAttempts = 0;

  final _eventController = StreamController<SyncEventModel>.broadcast();
  final _connectionStateController = StreamController<bool>.broadcast();

  Stream<SyncEventModel> get eventStream => _eventController.stream;
  Stream<bool> get connectionStateStream => _connectionStateController.stream;
  bool get isConnected =>
      _socket != null && _socket!.readyState == WebSocket.open;

  SyncWebSocketClient({
    required this.serverUrl,
    required this.deviceId,
    required this.schoolId,
  });

  Future<void> connect() async {
    if (_isDisposed || isConnected) return;

    final uri = Uri.parse('$serverUrl?deviceId=$deviceId&schoolId=$schoolId');

    try {
      _socket = await WebSocket.connect(
        uri.toString(),
      ).timeout(const Duration(seconds: 4));

      _reconnectAttempts = 0;
      _connectionStateController.add(true);
      _startHeartbeat();

      _socket!.listen(
        _onMessage,
        onDone: _onDisconnected,
        onError: (_) => _onDisconnected(),
        cancelOnError: true,
      );
    } catch (_) {
      _onDisconnected();
    }
  }

  void _onMessage(dynamic raw) {
    try {
      final json = jsonDecode(raw.toString()) as Map<String, dynamic>;
      final type = json['type'] as String?;

      if (type == 'event') {
        final rawEvent = json['event'] as Map<String, dynamic>?;
        if (rawEvent != null) {
          final event = SyncEventModel.fromJson(rawEvent);
          _eventController.add(event);
        }
      }
    } catch (_) {}
  }

  void _onDisconnected() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _socket = null;

    if (!_isDisposed && !_connectionStateController.isClosed) {
      _connectionStateController.add(false);
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    if (_isDisposed) return;

    // Exponential backoff: 1s, 2s, 4s, capped at 8s
    final delaySeconds = (1 << _reconnectAttempts).clamp(1, 8);
    _reconnectAttempts++;

    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      if (!_isDisposed) {
        connect();
      }
    });
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!_isDisposed && isConnected) {
        try {
          _socket?.add(jsonEncode({'type': 'ping'}));
        } catch (_) {
          _onDisconnected();
        }
      }
    });
  }

  void sendEvent(SyncEventModel event) {
    if (!_isDisposed && isConnected) {
      try {
        _socket?.add(jsonEncode({'type': 'event', 'event': event.toJson()}));
      } catch (_) {}
    }
  }

  void dispose() {
    _isDisposed = true;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    try {
      _socket?.close();
    } catch (_) {}
    _socket = null;
    if (!_eventController.isClosed) {
      _eventController.close();
    }
    if (!_connectionStateController.isClosed) {
      _connectionStateController.close();
    }
  }
}
