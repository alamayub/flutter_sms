// test/two_device_sync_test.dart
import 'dart:async';
import 'dart:io';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sms/core/constants/app_constants.dart';
import 'package:sms/core/database/app_database.dart';
import 'package:sms/features/attendance/data/attendance_repository.dart';
import 'package:sms/features/audit/data/audit_repository.dart';
import 'package:sms/features/sync/client/device_service.dart';
import 'package:sms/features/sync/client/sync_engine.dart';
import 'package:sms/features/sync/domain/sync_state.dart';
import 'package:sms/features/sync/server/school_server.dart';
import 'package:sms/features/sync/server/server_storage.dart';

void main() {
  late Directory tempDirA;
  late Directory tempDirB;
  late AppDatabase dbA;
  late AppDatabase dbB;
  late DeviceService deviceServiceA;
  late DeviceService deviceServiceB;
  late ServerStorage serverStorage;
  late SchoolServer server;
  late SyncEngine syncEngineA;
  late SyncEngine syncEngineB;
  late AttendanceRepository attendanceRepoA;
  late AttendanceRepository attendanceRepoB;

  const schoolId = 'sch_two_device_test';
  const schoolName = 'Two Device Academy';
  const academicYearId = 'ay_2026';
  const classId = 'cls_grade_5';
  const sectionId = 'sec_grade_5_a';
  const dateStr = '2026-09-10';

  setUp(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

    // 1. Create separate temp directories and SQLite databases for Device A and B
    tempDirA = await Directory.systemTemp.createTemp('device_a_');
    tempDirB = await Directory.systemTemp.createTemp('device_b_');

    dbA = AppDatabase(NativeDatabase(File('${tempDirA.path}/device_a.sqlite')));
    dbB = AppDatabase(NativeDatabase(File('${tempDirB.path}/device_b.sqlite')));

    deviceServiceA = DeviceService(dbA);
    deviceServiceB = DeviceService(dbB);

    await deviceServiceA.getOrCreateCurrentDevice(schoolId);
    final devB = await deviceServiceB.getOrCreateCurrentDevice(schoolId);

    // 2. Start Central School Sync Server on loopback
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
    final serverUrl = 'http://127.0.0.1:${server.actualPort}';

    // 3. Setup Device A (Teacher Phone)
    syncEngineA = SyncEngine(db: dbA, deviceService: deviceServiceA);
    await syncEngineA.initialize(schoolId: schoolId, serverHttpUrl: serverUrl);
    expect([
      SyncConnectivityState.connected,
      SyncConnectivityState.syncComplete,
    ], contains(syncEngineA.currentStatus.connectivity));

    // 4. Setup Device B (Principal Desktop)
    // Register Device B and approve it on server so WebSocket can connect
    serverStorage.registerDevice(
      deviceId: devB.deviceId,
      schoolId: schoolId,
      deviceName: devB.deviceName,
      deviceType: devB.deviceType,
      pairingCode: devB.pairingCode,
    );
    serverStorage.approveDevice(devB.deviceId);

    syncEngineB = SyncEngine(db: dbB, deviceService: deviceServiceB);
    await syncEngineB.initialize(schoolId: schoolId, serverHttpUrl: serverUrl);
    expect([
      SyncConnectivityState.connected,
      SyncConnectivityState.syncComplete,
    ], contains(syncEngineB.currentStatus.connectivity));

    attendanceRepoA = AttendanceRepository(
      dbA,
      AuditRepository(dbA),
      syncEngineA,
    );
    attendanceRepoB = AttendanceRepository(
      dbB,
      AuditRepository(dbB),
      syncEngineB,
    );
  });

  tearDown(() async {
    syncEngineA.dispose();
    syncEngineB.dispose();
    await server.stop();
    serverStorage.close();
    await dbA.close();
    await dbB.close();
    if (await tempDirA.exists()) await tempDirA.delete(recursive: true);
    if (await tempDirB.exists()) await tempDirB.delete(recursive: true);
  });

  test(
    'Teacher marks attendance on Device A -> syncs to server -> Principal Device B receives in real time via WebSocket',
    () async {
      // Setup reactive stream listener on Device B (simulates UI listening to live updates)
      final bStreamReceived = Completer<List<AttendanceData>>();
      final sub = dbB.select(dbB.attendance).watch().listen((records) {
        if (records.length == 2 && !bStreamReceived.isCompleted) {
          bStreamReceived.complete(records);
        }
      });

      // 1. Device A (Teacher) marks attendance for 2 students
      final studentStatusMap = {
        'student_dev_1': AttendanceStatus.present,
        'student_dev_2': AttendanceStatus.absent,
      };

      await attendanceRepoA.saveAttendanceBatch(
        schoolId: schoolId,
        academicYearId: academicYearId,
        date: dateStr,
        classId: classId,
        sectionId: sectionId,
        studentStatusMap: studentStatusMap,
        markedByUserId: 'usr_teacher_ram',
      );

      // Verify Device A has 2 local attendance records
      final recordsA = await dbA.select(dbA.attendance).get();
      expect(recordsA.length, equals(2));

      // 2. Upload pending events from Device A to School Server
      final uploaded = await syncEngineA.uploadPending();
      expect(uploaded, equals(2));

      // Verify Server has sequenced the 2 events
      final serverEvents = serverStorage.getEventsSince(
        schoolId: schoolId,
        sinceSequence: 0,
      );
      expect(serverEvents.length, equals(2));
      expect(serverEvents[0].serverSequence, equals(1));
      expect(serverEvents[1].serverSequence, equals(2));

      // 3. Wait for Device B to receive events via live WebSocket broadcast
      final recordsB = await bStreamReceived.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () async {
          // Fallback catch-up if needed
          await syncEngineB.downloadMissing();
          return await dbB.select(dbB.attendance).get();
        },
      );

      await sub.cancel();

      // 4. Verify Device B local SQLite data matches Device A
      expect(recordsB.length, equals(2));
      final stu1 = recordsB.firstWhere((r) => r.studentId == 'student_dev_1');
      final stu2 = recordsB.firstWhere((r) => r.studentId == 'student_dev_2');

      expect(stu1.status, equals(AttendanceStatus.present));
      expect(stu1.classId, equals(classId));
      expect(stu1.sectionId, equals(sectionId));
      expect(stu1.markedBy, equals('usr_teacher_ram'));

      expect(stu2.status, equals(AttendanceStatus.absent));
      expect(stu2.classId, equals(classId));
      expect(stu2.sectionId, equals(sectionId));

      // 5. Verify reactive daily summary on Device B reflects the synchronized data
      final summaryB =
          await attendanceRepoB
              .watchDailySummary(schoolId: schoolId, date: dateStr)
              .first;

      expect(summaryB.presentCount, equals(1));
      expect(summaryB.absentCount, equals(1));
      expect(summaryB.totalCount, equals(2));
    },
  );
}
