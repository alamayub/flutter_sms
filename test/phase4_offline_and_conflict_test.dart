// test/phase4_offline_and_conflict_test.dart
import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart' hide Column, isNotNull, isNull;
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
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late Directory tempDir;
  late AppDatabase dbA;
  late AppDatabase dbB;
  late DeviceService deviceServiceA;
  late DeviceService deviceServiceB;
  late ServerStorage serverStorage;
  late SchoolServer server;
  late SyncEngine engineA;
  late SyncEngine engineB;

  const schoolId = 'sch_phase4_conflict';
  const schoolName = 'Phase 4 Conflict Test Academy';

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('phase4_conflict_test_');

    // Client Device A
    final dbFileA = File('${tempDir.path}/clientA.sqlite');
    dbA = AppDatabase(NativeDatabase(dbFileA));
    deviceServiceA = DeviceService(dbA);

    // Client Device B
    final dbFileB = File('${tempDir.path}/clientB.sqlite');
    dbB = AppDatabase(NativeDatabase(dbFileB));
    deviceServiceB = DeviceService(dbB);

    // Central School Server
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

    // Auto-approve test devices in server storage
    final devIdA = await deviceServiceA.getOrCreateDeviceId();
    final devIdB = await deviceServiceB.getOrCreateDeviceId();
    await serverStorage.registerDevice(
      deviceId: devIdA,
      schoolId: schoolId,
      deviceName: 'Device A Admin',
      deviceType: 'Desktop',
    );
    serverStorage.approveDevice(devIdA);

    await serverStorage.registerDevice(
      deviceId: devIdB,
      schoolId: schoolId,
      deviceName: 'Device B Teacher',
      deviceType: 'Mobile',
    );
    serverStorage.approveDevice(devIdB);

    final serverUrl = 'http://127.0.0.1:${server.actualPort}';

    engineA = SyncEngine(db: dbA, deviceService: deviceServiceA);
    engineB = SyncEngine(db: dbB, deviceService: deviceServiceB);

    await engineA.initialize(schoolId: schoolId, serverHttpUrl: serverUrl);
    await engineB.initialize(schoolId: schoolId);
  });

  tearDown(() async {
    engineA.dispose();
    engineB.dispose();
    await server.stop();
    serverStorage.close();
    await dbA.close();
    await dbB.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'Test 10: Multi-device sync (Device A creates -> Server receives -> Device B catches up)',
    () async {
      await engineA.enqueue(
        schoolId: schoolId,
        userId: 'usr_admin',
        entityType: SyncEntityType.student,
        entityId: 'stu_multi_01',
        operation: SyncOperation.create,
        payload: {
          'id': 'stu_multi_01',
          'schoolId': schoolId,
          'studentCode': 'STU-M1',
          'firstName': 'Isaac',
          'lastName': 'Newton',
        },
      );

      // 1. Ensure uploaded
      await engineA.uploadPending();

      // 2. Verify in server storage
      final serverEvents = serverStorage.getEventsSince(
        schoolId: schoolId,
        sinceSequence: 0,
      );
      expect(serverEvents.length, equals(1));
      expect(serverEvents.first.entityId, equals('stu_multi_01'));

      // 3. Connect Device B and sync
      final serverUrl = 'http://127.0.0.1:${server.actualPort}';
      await engineB.initialize(schoolId: schoolId, serverHttpUrl: serverUrl);

      final studentOnB =
          await (dbB.select(dbB.students)
            ..where((t) => t.id.equals('stu_multi_01'))).getSingleOrNull();
      expect(studentOnB, isNotNull);
      expect(studentOnB!.firstName, equals('Isaac'));
      expect(studentOnB.lastName, equals('Newton'));
    },
  );

  test(
    'Test 11: Offline queueing and automatic sync resumption after reconnect',
    () async {
      // Stop server to simulate offline
      await server.stop();
      await engineA.initialize(schoolId: schoolId);

      // Device A edits while offline
      await engineA.enqueue(
        schoolId: schoolId,
        userId: 'usr_admin',
        entityType: SyncEntityType.subject,
        entityId: 'sub_chem',
        operation: SyncOperation.create,
        payload: {
          'id': 'sub_chem',
          'schoolId': schoolId,
          'name': 'Chemistry',
          'code': 'CHEM101',
        },
      );

      final pendingBefore = await engineA.getPendingCount();
      expect(pendingBefore, equals(1));

      // Restart server
      server = SchoolServer(
        host: InternetAddress.loopbackIPv4,
        port: 0,
        schoolId: schoolId,
        schoolName: schoolName,
        storage: serverStorage,
        enableDiscovery: false,
      );
      await server.start();
      final newUrl = 'http://127.0.0.1:${server.actualPort}';

      // Connecting automatically triggers burst sync of pending events
      await engineA.initialize(schoolId: schoolId, serverHttpUrl: newUrl);
      final pendingAfter = await engineA.getPendingCount();
      expect(pendingAfter, equals(0));

      await engineB.initialize(schoolId: schoolId, serverHttpUrl: newUrl);
      final subjectB =
          await (dbB.select(dbB.subjects)
            ..where((t) => t.id.equals('sub_chem'))).getSingleOrNull();
      expect(subjectB, isNotNull);
      expect(subjectB!.code, equals('CHEM101'));
    },
  );

  test(
    'Test 12: Concurrent non-colliding edits on same Student perform clean field-level merge',
    () async {
      // Disconnect both engines from live auto-upload
      await engineA.initialize(schoolId: schoolId);
      await engineB.initialize(schoolId: schoolId);

      // Common base student inserted directly in SQLite on Device A
      final now = DateTime.now();
      await dbA
          .into(dbA.students)
          .insert(
            StudentsCompanion.insert(
              id: 'stu_common_merge',
              schoolId: schoolId,
              studentCode: 'STU-CM',
              firstName: 'Ada',
              lastName: 'Lovelace',
              phone: const Value('111-1111'),
              address: const Value('Old Address'),
              createdAt: now,
              updatedAt: now,
            ),
          );

      // Device A edits phone while offline -> pending event with phone field
      await engineA.enqueue(
        schoolId: schoolId,
        userId: 'usr_admin',
        entityType: SyncEntityType.student,
        entityId: 'stu_common_merge',
        operation: SyncOperation.update,
        payload: {
          'id': 'stu_common_merge',
          'schoolId': schoolId,
          'phone': '999-9999', // Disjoint edit on phone
        },
      );
      await (dbA.update(dbA.students)..where(
        (t) => t.id.equals('stu_common_merge'),
      )).write(const StudentsCompanion(phone: Value('999-9999')));

      // Remote event arrives from Device B updating address:
      final remoteEventFromB = SyncEventModel(
        eventId: 'evt_from_b_address',
        schoolId: schoolId,
        deviceId: 'dev_b',
        userId: 'usr_teacher',
        entityType: SyncEntityType.student,
        entityId: 'stu_common_merge',
        operation: SyncOperation.update,
        timestamp: DateTime.now(),
        payload: {
          'id': 'stu_common_merge',
          'schoolId': schoolId,
          'studentCode': 'STU-CM',
          'firstName': 'Ada',
          'lastName': 'Lovelace',
          'address': 'New Address 42 Computing St', // Disjoint edit on address
        },
      );

      // Apply on Device A: Should auto-merge phone (from local edit) and address (from remote edit)!
      await engineA.applyIncomingEvent(remoteEventFromB);

      final mergedOnA =
          await (dbA.select(dbA.students)
            ..where((t) => t.id.equals('stu_common_merge'))).getSingle();

      expect(mergedOnA.phone, equals('999-9999')); // Preserved local edit!
      expect(
        mergedOnA.address,
        equals('New Address 42 Computing St'),
      ); // Preserved remote edit!

      // Zero conflicts logged because fields were non-colliding
      final conflicts = await engineA.conflictManager.getPendingConflicts(
        schoolId,
      );
      expect(conflicts.isEmpty, isTrue);
    },
  );

  test(
    'Test 13: Concurrent colliding edits log structured conflict in sync_conflicts table',
    () async {
      await engineA.initialize(schoolId: schoolId);

      // Insert base student
      final now = DateTime.now();
      await dbA
          .into(dbA.students)
          .insert(
            StudentsCompanion.insert(
              id: 'stu_collide_1',
              schoolId: schoolId,
              studentCode: 'STU-COL',
              firstName: 'InitialName',
              lastName: 'Smith',
              createdAt: now,
              updatedAt: now,
            ),
          );

      // Local Device A changes firstName to 'Alice'
      await engineA.enqueue(
        schoolId: schoolId,
        userId: 'usr_admin',
        entityType: SyncEntityType.student,
        entityId: 'stu_collide_1',
        operation: SyncOperation.update,
        payload: {
          'id': 'stu_collide_1',
          'schoolId': schoolId,
          'studentCode': 'STU-COL',
          'firstName': 'Alice',
          'lastName': 'Smith',
        },
      );
      await (dbA.update(dbA.students)..where(
        (t) => t.id.equals('stu_collide_1'),
      )).write(const StudentsCompanion(firstName: Value('Alice')));

      // Incoming remote event from Device B changes firstName to 'Alicia'
      final remoteColliding = SyncEventModel(
        eventId: 'evt_collide_remote',
        schoolId: schoolId,
        deviceId: 'dev_b',
        userId: 'usr_teacher',
        entityType: SyncEntityType.student,
        entityId: 'stu_collide_1',
        operation: SyncOperation.update,
        timestamp: DateTime.now(),
        payload: {
          'id': 'stu_collide_1',
          'schoolId': schoolId,
          'studentCode': 'STU-COL',
          'firstName': 'Alicia',
          'lastName': 'Smith',
        },
      );

      await engineA.applyIncomingEvent(remoteColliding);

      // Check sync_conflicts table
      final pendingConflicts = await engineA.conflictManager
          .getPendingConflicts(schoolId);
      expect(pendingConflicts.length, equals(1));

      final conflict = pendingConflicts.first;
      expect(conflict.entityType, equals(SyncEntityType.student));
      expect(conflict.entityId, equals('stu_collide_1'));

      final meta = jsonDecode(conflict.resolutionNote!) as Map<String, dynamic>;
      expect(meta['conflictingFields'], contains('firstName'));
    },
  );

  test(
    'Test 14: Conflict resolution UI action "Keep Local" retains local data',
    () async {
      await engineA.initialize(schoolId: schoolId);

      // Setup conflict on stu_collide_local
      final now = DateTime.now();
      await dbA
          .into(dbA.students)
          .insert(
            StudentsCompanion.insert(
              id: 'stu_collide_local',
              schoolId: schoolId,
              studentCode: 'STU-LOC',
              firstName: 'InitialName',
              lastName: 'Smith',
              createdAt: now,
              updatedAt: now,
            ),
          );

      await engineA.enqueue(
        schoolId: schoolId,
        userId: 'usr_admin',
        entityType: SyncEntityType.student,
        entityId: 'stu_collide_local',
        operation: SyncOperation.update,
        payload: {
          'id': 'stu_collide_local',
          'schoolId': schoolId,
          'firstName': 'AliceLocal',
          'lastName': 'Smith',
        },
      );
      await (dbA.update(dbA.students)..where(
        (t) => t.id.equals('stu_collide_local'),
      )).write(const StudentsCompanion(firstName: Value('AliceLocal')));

      final remoteColliding = SyncEventModel(
        eventId: 'evt_collide_remote_loc',
        schoolId: schoolId,
        deviceId: 'dev_b',
        userId: 'usr_teacher',
        entityType: SyncEntityType.student,
        entityId: 'stu_collide_local',
        operation: SyncOperation.update,
        timestamp: DateTime.now(),
        payload: {
          'id': 'stu_collide_local',
          'schoolId': schoolId,
          'firstName': 'AliciaRemote',
          'lastName': 'Smith',
        },
      );
      await engineA.applyIncomingEvent(remoteColliding);

      final pending = await engineA.conflictManager.getPendingConflicts(
        schoolId,
      );
      expect(pending.isNotEmpty, isTrue);
      final conflict = pending.first;

      // Admin chooses "Keep Local"
      await engineA.resolveConflictWithAction(
        conflictId: conflict.id,
        resolvedByUserId: 'admin_1',
        resolution: 'keep_local',
      );

      // Verify marked as resolved
      final pendingAfter = await engineA.conflictManager.getPendingConflicts(
        schoolId,
      );
      expect(pendingAfter.isEmpty, isTrue);

      // Verify local DB retains 'AliceLocal'
      final student =
          await (dbA.select(dbA.students)
            ..where((t) => t.id.equals('stu_collide_local'))).getSingle();
      expect(student.firstName, equals('AliceLocal'));
    },
  );

  test(
    'Test 15: Conflict resolution UI action "Keep Remote" overwrites local DB with remote version',
    () async {
      await engineA.initialize(schoolId: schoolId);
      final now = DateTime.now();
      await dbA
          .into(dbA.students)
          .insert(
            StudentsCompanion.insert(
              id: 'stu_collide_2',
              schoolId: schoolId,
              studentCode: 'STU-COL2',
              firstName: 'Bob',
              lastName: 'Jones',
              createdAt: now,
              updatedAt: now,
            ),
          );

      // Local changes to 'Robert'
      await engineA.enqueue(
        schoolId: schoolId,
        userId: 'usr_admin',
        entityType: SyncEntityType.student,
        entityId: 'stu_collide_2',
        operation: SyncOperation.update,
        payload: {
          'id': 'stu_collide_2',
          'schoolId': schoolId,
          'studentCode': 'STU-COL2',
          'firstName': 'Robert',
          'lastName': 'Jones',
        },
      );

      // Remote arrives with 'Robbie'
      final remoteEvent = SyncEventModel(
        eventId: 'evt_remote_bob',
        schoolId: schoolId,
        deviceId: 'dev_b',
        userId: 'usr_teacher',
        entityType: SyncEntityType.student,
        entityId: 'stu_collide_2',
        operation: SyncOperation.update,
        timestamp: DateTime.now(),
        payload: {
          'id': 'stu_collide_2',
          'schoolId': schoolId,
          'studentCode': 'STU-COL2',
          'firstName': 'Robbie',
          'lastName': 'Jones',
        },
      );

      await engineA.applyIncomingEvent(remoteEvent);

      final pending = await engineA.conflictManager.getPendingConflicts(
        schoolId,
      );
      final conflict = pending.firstWhere((c) => c.entityId == 'stu_collide_2');

      // Admin chooses "Keep Remote"
      await engineA.resolveConflictWithAction(
        conflictId: conflict.id,
        resolvedByUserId: 'admin_1',
        resolution: 'keep_remote',
      );

      // Local DB should now have 'Robbie'
      final student =
          await (dbA.select(dbA.students)
            ..where((t) => t.id.equals('stu_collide_2'))).getSingle();
      expect(student.firstName, equals('Robbie'));
    },
  );

  test(
    'Test 16: Conflict resolution UI action "Merge Fields" applies custom field choices',
    () async {
      await engineA.initialize(schoolId: schoolId);
      final now = DateTime.now();
      await dbA
          .into(dbA.students)
          .insert(
            StudentsCompanion.insert(
              id: 'stu_collide_3',
              schoolId: schoolId,
              studentCode: 'STU-COL3',
              firstName: 'Charlie',
              lastName: 'Brown',
              phone: const Value('333-3333'),
              createdAt: now,
              updatedAt: now,
            ),
          );

      // Local changes firstName to 'Charles'
      await engineA.enqueue(
        schoolId: schoolId,
        userId: 'usr_admin',
        entityType: SyncEntityType.student,
        entityId: 'stu_collide_3',
        operation: SyncOperation.update,
        payload: {
          'id': 'stu_collide_3',
          'schoolId': schoolId,
          'studentCode': 'STU-COL3',
          'firstName': 'Charles',
          'lastName': 'Brown',
          'phone': '333-0000',
        },
      );

      // Remote changes firstName to 'Chuck' and phone to '333-9999'
      final remoteEvent = SyncEventModel(
        eventId: 'evt_remote_charlie',
        schoolId: schoolId,
        deviceId: 'dev_b',
        userId: 'usr_teacher',
        entityType: SyncEntityType.student,
        entityId: 'stu_collide_3',
        operation: SyncOperation.update,
        timestamp: DateTime.now(),
        payload: {
          'id': 'stu_collide_3',
          'schoolId': schoolId,
          'studentCode': 'STU-COL3',
          'firstName': 'Chuck',
          'phone': '333-9999',
        },
      );

      await engineA.applyIncomingEvent(remoteEvent);

      final pending = await engineA.conflictManager.getPendingConflicts(
        schoolId,
      );
      final conflict = pending.firstWhere((c) => c.entityId == 'stu_collide_3');

      // Admin chooses Merge: take firstName 'Charles' from local, phone '333-9999' from remote
      final mergedChoice = {
        'id': 'stu_collide_3',
        'schoolId': schoolId,
        'studentCode': 'STU-COL3',
        'firstName': 'Charles',
        'lastName': 'Brown',
        'phone': '333-9999',
      };

      await engineA.resolveConflictWithAction(
        conflictId: conflict.id,
        resolvedByUserId: 'admin_1',
        resolution: 'merged',
        customMergedPayload: mergedChoice,
      );

      final student =
          await (dbA.select(dbA.students)
            ..where((t) => t.id.equals('stu_collide_3'))).getSingle();
      expect(student.firstName, equals('Charles'));
      expect(student.phone, equals('333-9999'));
    },
  );

  test(
    'Test 17: Device revocation check rejects unauthorized device sync',
    () async {
      final serverUrl = 'http://127.0.0.1:${server.actualPort}';
      await engineB.initialize(schoolId: schoolId, serverHttpUrl: serverUrl);
      final devIdB = await deviceServiceB.getOrCreateDeviceId();

      // Revoke Device B on server
      serverStorage.revokeDevice(devIdB);

      // Device B tries to enqueue and upload
      await engineB.enqueue(
        schoolId: schoolId,
        userId: 'usr_teacher',
        entityType: SyncEntityType.attendance,
        entityId: 'att_revoked_01',
        operation: SyncOperation.create,
        payload: {
          'id': 'att_revoked_01',
          'schoolId': schoolId,
          'date': '2026-09-10',
          'status': 'present',
        },
      );

      // Upload from revoked device must be rejected by server with HTTP 403 / exception
      expect(() => engineB.uploadPending(), throwsA(isA<Exception>()));
    },
  );
}
