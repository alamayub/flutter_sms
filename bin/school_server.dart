// bin/school_server.dart
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:sms/features/sync/server/school_server.dart';
import 'package:sms/features/sync/server/server_storage.dart';

void main(List<String> args) async {
  int port = 8080;
  String schoolId = 'school_default_01';
  String schoolName = 'School Management LAN Server';
  String dbPath = p.join(Directory.current.path, 'sms_server.sqlite');

  for (int i = 0; i < args.length; i++) {
    if (args[i] == '--port' && i + 1 < args.length) {
      port = int.tryParse(args[i + 1]) ?? port;
    } else if (args[i] == '--school-id' && i + 1 < args.length) {
      schoolId = args[i + 1];
    } else if (args[i] == '--school-name' && i + 1 < args.length) {
      schoolName = args[i + 1];
    } else if (args[i] == '--db' && i + 1 < args.length) {
      dbPath = args[i + 1];
    }
  }

  stdout.writeln('==================================================');
  stdout.writeln('     School Sync Server (LAN-Only Real-Time)      ');
  stdout.writeln('==================================================');
  stdout.writeln('Port: $port');
  stdout.writeln('School ID: $schoolId');
  stdout.writeln('School Name: $schoolName');
  stdout.writeln('Database: $dbPath');

  final storage = ServerStorage.openFile(dbPath);
  final server = SchoolServer(
    port: port,
    schoolId: schoolId,
    schoolName: schoolName,
    storage: storage,
    enableDiscovery: true,
  );

  await server.start();

  stdout.writeln('Server running on port ${server.actualPort}');
  stdout.writeln('Server ID: ${server.serverId}');
  stdout.writeln(
    'Health endpoint: http://localhost:${server.actualPort}/health',
  );
  stdout.writeln(
    'Admin status: http://localhost:${server.actualPort}/admin/status',
  );
  stdout.writeln('WebSocket endpoint: ws://localhost:${server.actualPort}/ws');
  stdout.writeln('UDP Discovery active on port 52400');
  stdout.writeln('Press Ctrl+C to terminate.');

  ProcessSignal.sigint.watch().listen((_) async {
    stdout.writeln('\nShutting down server...');
    await server.stop();
    storage.close();
    stdout.writeln('Server stopped.');
    exit(0);
  });
}
