// lib/features/sync/client/server_discovery_client.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../server/server_discovery_beacon.dart';

class DiscoveredServer {
  final String host;
  final int port;
  final String schoolId;
  final String schoolName;
  final String serverId;

  const DiscoveredServer({
    required this.host,
    required this.port,
    required this.schoolId,
    required this.schoolName,
    required this.serverId,
  });

  String get httpUrl => 'http://$host:$port';
  String get wsUrl => 'ws://$host:$port/ws';
}

class ServerDiscoveryClient {
  /// Broadcasts UDP beacon on LAN to find a running SchoolServer.
  /// Times out after timeoutDuration and returns null if not found.
  static Future<DiscoveredServer?> discover({
    Duration timeoutDuration = const Duration(seconds: 3),
  }) async {
    RawDatagramSocket? socket;
    try {
      socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0, // ephemeral port for client
        reuseAddress: true,
      );
      socket.broadcastEnabled = true;

      final completer = Completer<DiscoveredServer?>();

      socket.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          final datagram = socket?.receive();
          if (datagram == null) return;

          try {
            final text = utf8.decode(datagram.data);
            final json = jsonDecode(text) as Map<String, dynamic>;

            if (json['service'] == 'sms_school_server') {
              final port = json['port'] as int;
              final schoolId = json['schoolId'] as String;
              final schoolName = json['schoolName'] as String;
              final serverId = json['serverId'] as String;

              if (!completer.isCompleted) {
                completer.complete(
                  DiscoveredServer(
                    host: datagram.address.address,
                    port: port,
                    schoolId: schoolId,
                    schoolName: schoolName,
                    serverId: serverId,
                  ),
                );
              }
            }
          } catch (_) {}
        }
      });

      // Send discovery broadcast
      final messageBytes = utf8.encode(ServerDiscoveryBeacon.discoveryMessage);
      socket.send(
        messageBytes,
        InternetAddress('255.255.255.255'),
        ServerDiscoveryBeacon.discoveryPort,
      );

      final result = await completer.future.timeout(
        timeoutDuration,
        onTimeout: () => null,
      );
      return result;
    } catch (_) {
      return null;
    } finally {
      socket?.close();
    }
  }
}
