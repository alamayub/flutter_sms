// test/three_device_sync_test.dart
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
import 'package:sms/features/sync/server/school_server.dart';
import 'package:sms/features/sync/server/server_storage.dart';

void main() {
  late Directory tempDirA;
  late Directory tempDirB;
  late Directory tempDirC;
  late AppDatabase dbA;
  late AppDatabase dbB;
  late AppDatabase dbC;
  late DeviceService deviceServiceA;
  late DeviceService deviceServiceB;
  late DeviceService deviceServiceC;
  late ServerStorage serverStorage;
  late SchoolServer server;
  late SyncEngine syncEngineA;
  late SyncEngine syncEngineB;
  late SyncEngine syncEngineC;
  late AttendanceRepository attendanceRepoA;
  late AttendanceRepository attendanceRepoB;
  late AttendanceRepository attendanceRepoC;

  const schoolId = 'sch_three_device_test';
  const schoolName = 'Multi Device Academy';
  const academicYearId = 'ay_2026';
  const dateStr = '2026-09-10';

  setUp(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

    tempDirA = await Directory.systemTemp.createTemp('dev_teacher1_');
    tempDirB = await Directory.systemTemp.createTemp('dev_teacher2_');
    tempDirC = await Directory.systemTemp.createTemp('dev_principal_');

    dbA = AppDatabase(NativeDatabase(File('${tempDirA.path}/device_a.sqlite')));
    dbB = AppDatabase(NativeDatabase(File('${tempDirB.path}/device_b.sqlite')));
    dbC = AppDatabase(NativeDatabase(File('${tempDirC.path}/device_c.sqlite')));

    deviceServiceA = DeviceService(dbA);
    deviceServiceB = DeviceService(dbB);
    deviceServiceC = DeviceService(dbC);

    await deviceServiceA.getOrCreateCurrentDevice(schoolId);
    final devB = await deviceServiceB.getOrCreateCurrentDevice(schoolId);
    final devC = await deviceServiceC.getOrCreateCurrentDevice(schoolId);

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

    // Device A (First device auto-approved)
    syncEngineA = SyncEngine(db: dbA, deviceService: deviceServiceA);
    await syncEngineA.initialize(schoolId: schoolId, serverHttpUrl: serverUrl);

    // Device B (Pre-approved on server)
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

    // Device C (Pre-approved on server)
    serverStorage.registerDevice(
      deviceId: devC.deviceId,
      schoolId: schoolId,
      deviceName: devC.deviceName,
      deviceType: devC.deviceType,
      pairingCode: devC.pairingCode,
    );
    serverStorage.approveDevice(devC.deviceId);
    syncEngineC = SyncEngine(db: dbC, deviceService: deviceServiceC);
    await syncEngineC.initialize(schoolId: schoolId, serverHttpUrl: serverUrl);

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
    attendanceRepoC = AttendanceRepository(
      dbC,
      AuditRepository(dbC),
      syncEngineC,
    );
  });

  tearDown(() async {
    syncEngineA.dispose();
    syncEngineB.dispose();
    syncEngineC.dispose();
    await server.stop();
    serverStorage.close();
    await dbA.close();
    await dbB.close();
    await dbC.close();
    if (await tempDirA.exists()) await tempDirA.delete(recursive: true);
    if (await tempDirB.exists()) await tempDirB.delete(recursive: true);
    if (await tempDirC.exists()) await tempDirC.delete(recursive: true);
  });

  test(
    'Teacher 1 and Teacher 2 mark attendance concurrently -> Server sequences all events -> Principal Desktop receives full set',
    () async {
      // Principal (Device C) watches attendance count until all 4 records arrive
      final cStreamReceived = Completer<List<AttendanceData>>();
      final sub = dbC.select(dbC.attendance).watch().listen((records) {
        if (records.length == 4 && !cStreamReceived.isCompleted) {
          cStreamReceived.complete(records);
        }
      });

      // 1. Teacher 1 marks attendance for Section A (2 students)
      await attendanceRepoA.saveAttendanceBatch(
        schoolId: schoolId,
        academicYearId: academicYearId,
        date: dateStr,
        classId: 'cls_10',
        sectionId: 'sec_10_a',
        studentStatusMap: {
          'stu_10_a_1': AttendanceStatus.present,
          'stu_10_a_2': AttendanceStatus.absent,
        },
        markedByUserId: 'usr_teacher_1',
      );

      // 2. Teacher 2 marks attendance for Section B (2 students)
      await attendanceRepoB.saveAttendanceBatch(
        schoolId: schoolId,
        academicYearId: academicYearId,
        date: dateStr,
        classId: 'cls_10',
        sectionId: 'sec_10_b',
        studentStatusMap: {
          'stu_10_b_1': AttendanceStatus.present,
          'stu_10_b_2': AttendanceStatus.late,
        },
        markedByUserId: 'usr_teacher_2',
      );

      // 3. Both devices upload pending events concurrently
      final results = await Future.wait([
        syncEngineA.uploadPending(),
        syncEngineB.uploadPending(),
      ]);

      expect(results[0], equals(2));
      expect(results[1], equals(2));

      // 4. Verify Server stored 4 events sequenced strictly from 1 to 4
      final serverEvents = serverStorage.getEventsSince(
        schoolId: schoolId,
        sinceSequence: 0,
      );
      expect(serverEvents.length, equals(4));
      for (int i = 0; i < 4; i++) {
        expect(serverEvents[i].serverSequence, equals(i + 1));
      }

      // 5. Wait for Principal (Device C) to receive all 4 events
      final recordsC = await cStreamReceived.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () async {
          await syncEngineC.downloadMissing();
          return await dbC.select(dbC.attendance).get();
        },
      );

      await sub.cancel();

      expect(recordsC.length, equals(4));

      // Verify all statuses are accurately reflected on Principal's device
      final stu10A1 = recordsC.firstWhere((r) => r.studentId == 'stu_10_a_1');
      final stu10A2 = recordsC.firstWhere((r) => r.studentId == 'stu_10_a_2');
      final stu10B1 = recordsC.firstWhere((r) => r.studentId == 'stu_10_b_1');
      final stu10B2 = recordsC.firstWhere((r) => r.studentId == 'stu_10_b_2');

      expect(stu10A1.status, equals(AttendanceStatus.present));
      expect(stu10A2.status, equals(AttendanceStatus.absent));
      expect(stu10B1.status, equals(AttendanceStatus.present));
      expect(stu10B2.status, equals(AttendanceStatus.late));

      // 6. Verify daily summary on Principal's device aggregates both classes correctly
      final summaryC =
          await attendanceRepoC
              .watchDailySummary(schoolId: schoolId, date: dateStr)
              .first;

      expect(summaryC.totalCount, equals(4));
      expect(summaryC.presentCount, equals(2));
      expect(summaryC.absentCount, equals(1));
      expect(summaryC.lateCount, equals(1));
    },
  );
}
