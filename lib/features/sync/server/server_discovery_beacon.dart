// lib/features/sync/server/server_discovery_beacon.dart
import 'dart:convert';
import 'dart:io';

class ServerDiscoveryBeacon {
  static const int discoveryPort = 52400;
  static const String discoveryMessage = 'SMS_DISCOVER_SERVER';

  final int serverHttpPort;
  final String schoolId;
  final String schoolName;
  final String serverId;
  RawDatagramSocket? _socket;
  bool _isRunning = false;

  ServerDiscoveryBeacon({
    required this.serverHttpPort,
    required this.schoolId,
    required this.schoolName,
    required this.serverId,
  });

  bool get isRunning => _isRunning;

  Future<void> start() async {
    if (_isRunning) return;

    try {
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        discoveryPort,
        reuseAddress: true,
        reusePort: true,
      );
      _socket!.broadcastEnabled = true;
      _isRunning = true;

      _socket!.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          final datagram = _socket?.receive();
          if (datagram == null) return;

          final message = utf8.decode(datagram.data).trim();
          if (message == discoveryMessage) {
            final responsePayload = jsonEncode({
              'service': 'sms_school_server',
              'port': serverHttpPort,
              'schoolId': schoolId,
              'schoolName': schoolName,
              'serverId': serverId,
              'version': '1.0.0',
            });

            final responseBytes = utf8.encode(responsePayload);
            _socket?.send(responseBytes, datagram.address, datagram.port);
          }
        }
      });
    } catch (_) {
      // If port is in use or UDP is not permitted, discovery fallback to manual IP
      _isRunning = false;
    }
  }

  void stop() {
    _isRunning = false;
    _socket?.close();
    _socket = null;
  }
}
