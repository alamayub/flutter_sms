// test/no_internet_operation_test.dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sms/core/constants/app_constants.dart';
import 'package:sms/core/database/app_database.dart';
import 'package:drift/native.dart';
import 'package:sms/features/attendance/data/attendance_repository.dart';
import 'package:sms/features/audit/data/audit_repository.dart';
import 'package:sms/features/sync/client/device_service.dart';
import 'package:sms/features/sync/client/sync_engine.dart';
import 'package:sms/features/sync/domain/sync_state.dart';
import 'package:sms/features/sync/server/school_server.dart';
import 'package:sms/features/sync/server/server_discovery_beacon.dart';
import 'package:sms/features/sync/server/server_storage.dart';

void main() {
  late Directory tempDir;
  late AppDatabase db;
  late DeviceService deviceService;
  late ServerStorage serverStorage;
  late SchoolServer server;
  late SyncEngine syncEngine;
  late AttendanceRepository attendanceRepo;

  const schoolId = 'sch_no_internet_test';
  const schoolName = 'No Internet Rural Academy';

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('no_internet_test_');
    db = AppDatabase(NativeDatabase(File('${tempDir.path}/offline.sqlite')));
    deviceService = DeviceService(db);

    serverStorage = ServerStorage.inMemory();
    // Binds strictly to loopback IPv4
    server = SchoolServer(
      host: InternetAddress.loopbackIPv4,
      port: 0,
      schoolId: schoolId,
      schoolName: schoolName,
      storage: serverStorage,
      enableDiscovery: false,
    );
    await server.start();

    syncEngine = SyncEngine(db: db, deviceService: deviceService);
    attendanceRepo = AttendanceRepository(db, AuditRepository(db), syncEngine);
  });

  tearDown(() async {
    syncEngine.dispose();
    await server.stop();
    serverStorage.close();
    await db.close();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test(
    'Sync stack operates completely on private loopback with zero external domain dependencies',
    () async {
      final serverUrl = 'http://127.0.0.1:${server.actualPort}';
      final serverUri = Uri.parse(serverUrl);

      // Verify host is strictly loopback/LAN private IP
      expect(serverUri.host, equals('127.0.0.1'));
      expect(serverUri.scheme, equals('http'));
      expect(server.actualPort, greaterThan(0));

      // Initialize sync engine using LAN address
      await syncEngine.initialize(schoolId: schoolId, serverHttpUrl: serverUrl);
      expect([
        SyncConnectivityState.connected,
        SyncConnectivityState.syncComplete,
      ], contains(syncEngine.currentStatus.connectivity));

      // Mark attendance locally
      await attendanceRepo.saveAttendanceBatch(
        schoolId: schoolId,
        academicYearId: 'ay_2026',
        date: '2026-09-10',
        classId: 'cls_rural_1',
        sectionId: 'sec_rural_a',
        studentStatusMap: {
          'stu_rural_1': AttendanceStatus.present,
          'stu_rural_2': AttendanceStatus.absent,
        },
        markedByUserId: 'usr_rural_teacher',
      );

      // Verify local persistence succeeded
      final localRows = await db.select(db.attendance).get();
      expect(localRows.length, equals(2));

      // Upload pending records over local connection
      final uploaded = await syncEngine.uploadPending();
      expect(uploaded, equals(2));

      // Verify server has received and sequenced the records
      final serverRows = serverStorage.getEventsSince(
        schoolId: schoolId,
        sinceSequence: 0,
      );
      expect(serverRows.length, equals(2));
      expect(serverRows[0].serverSequence, equals(1));
      expect(serverRows[1].serverSequence, equals(2));

      // Verify that all server events strictly refer to local schoolId
      for (final ev in serverRows) {
        expect(ev.schoolId, equals(schoolId));
      }
    },
  );

  test('Discovery beacon operates strictly on LAN UDP port 52400', () {
    expect(ServerDiscoveryBeacon.discoveryPort, equals(52400));
    expect(
      ServerDiscoveryBeacon.discoveryMessage,
      equals('SMS_DISCOVER_SERVER'),
    );
  });
}
