// test/sync_engine_test.dart
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sms/core/constants/app_constants.dart';
import 'package:sms/core/database/app_database.dart';
import 'package:sms/features/sync/client/device_service.dart';
import 'package:sms/features/sync/client/sync_engine.dart';
import 'package:sms/features/sync/domain/sync_event_model.dart';
import 'package:sms/features/sync/server/school_server.dart';
import 'package:sms/features/sync/server/server_storage.dart';

void main() {
  late Directory tempDir;
  late AppDatabase clientDb;
  late DeviceService deviceService;
  late ServerStorage serverStorage;
  late SchoolServer server;
  late SyncEngine syncEngine;
  final schoolId = 'engine_test_school';
  final schoolName = 'Engine Test Academy';

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sync_engine_test_');
    final dbFile = File('${tempDir.path}/client.sqlite');
    clientDb = AppDatabase(NativeDatabase(dbFile));
    deviceService = DeviceService(clientDb);

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

    syncEngine = SyncEngine(db: clientDb, deviceService: deviceService);
    await syncEngine.initialize(
      schoolId: schoolId,
      serverHttpUrl: 'http://127.0.0.1:${server.actualPort}',
    );
  });

  tearDown(() async {
    syncEngine.dispose();
    await server.stop();
    serverStorage.close();
    await clientDb.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'Enqueue creates pending event and uploadPending marks it synced with sequence',
    () async {
      // 1. Enqueue attendance event
      final event = await syncEngine.enqueue(
        schoolId: schoolId,
        userId: 'usr_teacher_1',
        entityType: SyncEntityType.attendance,
        entityId: 'att_test_1',
        operation: SyncOperation.create,
        payload: {
          'date': '2026-09-09',
          'studentId': 'stu_01',
          'classId': 'cls_01',
          'sectionId': 'sec_01',
          'status': 'present',
        },
      );

      expect(event.status, equals(SyncEventStatus.pending));

      // Verify stored locally as pending
      final storedEvents = await clientDb.select(clientDb.syncEvents).get();
      expect(storedEvents.length, equals(1));
      expect(storedEvents.first.status, equals(SyncEventStatus.pending));

      // 2. Upload pending
      final uploadedCount = await syncEngine.uploadPending();
      expect(uploadedCount, equals(1));

      // 3. Verify status in local database is now synced with valid serverSequence
      final updatedEvents = await clientDb.select(clientDb.syncEvents).get();
      expect(updatedEvents.first.status, equals(SyncEventStatus.synced));
      expect(updatedEvents.first.serverSequence, isNotNull);
      expect(updatedEvents.first.serverSequence, greaterThan(0));

      // 4. Verify server storage has the event
      expect(serverStorage.getTotalEventCount(), equals(1));
    },
  );

  test(
    'applyIncomingEvent inserts attendance and idempotently handles duplicates',
    () async {
      final incomingEvent = SyncEventModel(
        eventId: 'evt_remote_101',
        schoolId: schoolId,
        deviceId: 'dev_remote_teacher',
        userId: 'usr_teacher_remote',
        entityType: SyncEntityType.attendance,
        entityId: 'att_remote_101',
        operation: SyncOperation.create,
        version: 1,
        payload: {
          'academicYearId': 'ay_1',
          'date': '2026-09-09',
          'studentId': 'stu_remote_99',
          'classId': 'cls_1',
          'sectionId': 'sec_1',
          'status': 'absent',
          'remarks': 'Sick leave',
        },
        serverSequence: 50,
        status: SyncEventStatus.synced,
        timestamp: DateTime.now(),
      );

      // Apply first time
      await syncEngine.applyIncomingEvent(incomingEvent);

      // Verify attendance row inserted in local DB
      final attendanceRecords =
          await clientDb.select(clientDb.attendance).get();
      expect(attendanceRecords.length, equals(1));
      expect(attendanceRecords.first.studentId, equals('stu_remote_99'));
      expect(attendanceRecords.first.status, equals('absent'));
      expect(attendanceRecords.first.remarks, equals('Sick leave'));

      // Apply exact same event second time (duplicate delivery)
      await syncEngine.applyIncomingEvent(incomingEvent);

      // Verify still exactly 1 attendance row
      final attendanceAfterDuplicate =
          await clientDb.select(clientDb.attendance).get();
      expect(attendanceAfterDuplicate.length, equals(1));
    },
  );

  test(
    'Conflict detection logs record to sync_conflicts table when local pending edit exists',
    () async {
      // 1. Enqueue local pending edit for student_x
      await syncEngine.enqueue(
        schoolId: schoolId,
        userId: 'usr_local_teacher',
        entityType: SyncEntityType.attendance,
        entityId: 'att_conflict_target',
        operation: SyncOperation.update,
        payload: {
          'date': '2026-09-09',
          'studentId': 'student_conflict_x',
          'status': 'present',
        },
      );

      // 2. Incoming remote event arrives for same entity with different status
      final remoteEvent = SyncEventModel(
        eventId: 'evt_remote_conflict',
        schoolId: schoolId,
        deviceId: 'dev_peer_pc',
        userId: 'usr_peer_teacher',
        entityType: SyncEntityType.attendance,
        entityId: 'att_conflict_target',
        operation: SyncOperation.update,
        version: 2,
        payload: {
          'date': '2026-09-09',
          'studentId': 'student_conflict_x',
          'status': 'absent',
        },
        serverSequence: 99,
        status: SyncEventStatus.synced,
        timestamp: DateTime.now(),
      );

      await syncEngine.applyIncomingEvent(remoteEvent);

      // 3. Verify conflict recorded in sync_conflicts table
      final conflicts = await clientDb.select(clientDb.syncConflicts).get();
      expect(conflicts.length, equals(1));
      expect(conflicts.first.entityId, equals('att_conflict_target'));
      expect(conflicts.first.remoteEventId, equals('evt_remote_conflict'));
    },
  );
}
