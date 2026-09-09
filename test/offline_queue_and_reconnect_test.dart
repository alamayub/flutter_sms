// test/offline_queue_and_reconnect_test.dart
import 'dart:io';
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
  late Directory tempDir;
  late AppDatabase db;
  late DeviceService deviceService;
  late SyncEngine syncEngine;
  late AttendanceRepository attendanceRepo;
  late ServerStorage serverStorage;
  late SchoolServer server;

  const schoolId = 'sch_offline_queue_test';
  const schoolName = 'Offline Resilience Academy';
  const academicYearId = 'ay_2026';
  const dateStr = '2026-09-10';

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('offline_test_');
    db = AppDatabase(NativeDatabase(File('${tempDir.path}/client.sqlite')));
    deviceService = DeviceService(db);
    syncEngine = SyncEngine(db: db, deviceService: deviceService);
    attendanceRepo = AttendanceRepository(db, AuditRepository(db), syncEngine);

    // Initialize in local-only mode (no server)
    await syncEngine.initialize(schoolId: schoolId);
  });

  tearDown(() async {
    syncEngine.dispose();
    await db.close();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test(
    'Teacher marks attendance offline -> events queue locally -> server comes online -> auto syncs and clears queue',
    () async {
      // 1. Verify client is in local-only mode
      expect(
        syncEngine.currentStatus.connectivity,
        equals(SyncConnectivityState.localOnly),
      );
      expect(await syncEngine.getPendingCount(), equals(0));

      // 2. Teacher marks first batch of attendance offline (2 students)
      await attendanceRepo.saveAttendanceBatch(
        schoolId: schoolId,
        academicYearId: academicYearId,
        date: dateStr,
        classId: 'cls_8',
        sectionId: 'sec_8_a',
        studentStatusMap: {
          'stu_off_1': AttendanceStatus.present,
          'stu_off_2': AttendanceStatus.absent,
        },
        markedByUserId: 'usr_teacher_offline',
      );

      // 3. Teacher marks second batch of attendance offline (1 student)
      await attendanceRepo.saveAttendanceBatch(
        schoolId: schoolId,
        academicYearId: academicYearId,
        date: dateStr,
        classId: 'cls_8',
        sectionId: 'sec_8_b',
        studentStatusMap: {'stu_off_3': AttendanceStatus.late},
        markedByUserId: 'usr_teacher_offline',
      );

      // 4. Verify all 3 records are saved locally in SQLite
      final localRecords = await db.select(db.attendance).get();
      expect(localRecords.length, equals(3));

      // Verify 3 sync events are queued with pending status
      final pendingEvents = await db.select(db.syncEvents).get();
      expect(pendingEvents.length, equals(3));
      for (final e in pendingEvents) {
        expect(e.status, equals(SyncEventStatus.pending));
        expect(e.serverSequence, isNull);
      }
      expect(await syncEngine.getPendingCount(), equals(3));

      // Attempting upload while server is null returns 0
      final uploadWithoutServer = await syncEngine.uploadPending();
      expect(uploadWithoutServer, equals(0));

      // 5. Server comes online
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

      try {
        // 6. Device connects to the newly online server
        // configureServer automatically triggers syncNow() which uploads pending events!
        final connected = await syncEngine.configureServer(serverUrl);
        expect(connected, isTrue);

        // 7. Verify queue was automatically cleared during reconnection (pending count is 0)
        expect(await syncEngine.getPendingCount(), equals(0));

        // Additional upload returns 0 because all 3 were already flushed
        final remainingUploads = await syncEngine.uploadPending();
        expect(remainingUploads, equals(0));

        // 9. Verify local sync_events rows are updated to 'synced' with valid server sequences
        final updatedEvents = await db.select(db.syncEvents).get();
        expect(updatedEvents.length, equals(3));
        for (final e in updatedEvents) {
          expect(e.status, equals(SyncEventStatus.synced));
          expect(e.serverSequence, isNotNull);
          expect(e.serverSequence, greaterThan(0));
        }

        // 10. Verify server storage now has the 3 events sequenced 1, 2, 3
        final serverStoredEvents = serverStorage.getEventsSince(
          schoolId: schoolId,
          sinceSequence: 0,
        );
        expect(serverStoredEvents.length, equals(3));
        expect(serverStoredEvents[0].serverSequence, equals(1));
        expect(serverStoredEvents[1].serverSequence, equals(2));
        expect(serverStoredEvents[2].serverSequence, equals(3));
      } finally {
        await server.stop();
        serverStorage.close();
      }
    },
  );
}
