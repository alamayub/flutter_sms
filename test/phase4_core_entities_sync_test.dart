// test/phase4_core_entities_sync_test.dart
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
  late AppDatabase dbA;
  late AppDatabase dbB;
  late DeviceService deviceServiceA;
  late DeviceService deviceServiceB;
  late ServerStorage serverStorage;
  late SchoolServer server;
  late SyncEngine engineA;
  late SyncEngine engineB;

  const schoolId = 'sch_phase4_core';
  const schoolName = 'Phase 4 Core Test Academy';

  Future<void> propagateSync() async {
    await engineA.uploadPending();
    await engineB.downloadMissing();
    await engineB.uploadPending();
    await engineA.downloadMissing();
  }

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('phase4_core_test_');

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
      deviceName: 'Admin PC',
      deviceType: 'Desktop',
    );
    serverStorage.approveDevice(devIdA);

    await serverStorage.registerDevice(
      deviceId: devIdB,
      schoolId: schoolId,
      deviceName: 'Teacher Phone',
      deviceType: 'Mobile',
    );
    serverStorage.approveDevice(devIdB);

    final serverUrl = 'http://127.0.0.1:${server.actualPort}';

    engineA = SyncEngine(db: dbA, deviceService: deviceServiceA);
    await engineA.initialize(schoolId: schoolId, serverHttpUrl: serverUrl);

    engineB = SyncEngine(db: dbB, deviceService: deviceServiceB);
    await engineB.initialize(schoolId: schoolId, serverHttpUrl: serverUrl);
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

  test('Test 1: Academic Year sync creates and propagates current year', () async {
    // Device A enqueues academic year
    await engineA.enqueue(
      schoolId: schoolId,
      userId: 'admin_1',
      entityType: SyncEntityType.academicYear,
      entityId: 'ay_2026',
      operation: SyncOperation.create,
      payload: {
        'id': 'ay_2026',
        'schoolId': schoolId,
        'name': '2026-2027 Academic Session',
        'startDate': '2026-06-01T00:00:00.000',
        'endDate': '2027-04-30T00:00:00.000',
        'isCurrent': true,
        'isArchived': false,
        'createdAt': '2026-06-01T00:00:00.000',
        'updatedAt': '2026-06-01T00:00:00.000',
      },
    );

    await propagateSync();

    // Check Device B SQLite
    final yearB = await (dbB.select(dbB.academicYears)
          ..where((t) => t.id.equals('ay_2026')))
        .getSingleOrNull();

    expect(yearB, isNotNull);
    expect(yearB!.name, equals('2026-2027 Academic Session'));
    expect(yearB.isCurrent, isTrue);
  });

  test('Test 2: Class & Section sync preserves hierarchy and capacity', () async {
    // Device A enqueues Class and Section
    await engineA.enqueue(
      schoolId: schoolId,
      userId: 'admin_1',
      entityType: SyncEntityType.schoolClass,
      entityId: 'cls_grade10',
      operation: SyncOperation.create,
      payload: {
        'id': 'cls_grade10',
        'schoolId': schoolId,
        'academicYearId': 'ay_2026',
        'name': 'Grade 10',
        'displayOrder': 10,
        'isArchived': false,
      },
    );

    await engineA.enqueue(
      schoolId: schoolId,
      userId: 'admin_1',
      entityType: SyncEntityType.section,
      entityId: 'sec_10a',
      operation: SyncOperation.create,
      payload: {
        'id': 'sec_10a',
        'schoolId': schoolId,
        'classId': 'cls_grade10',
        'name': 'Section A',
        'capacity': 35,
        'classTeacherId': 'tch_101',
        'isArchived': false,
      },
    );

    await propagateSync();

    final classB = await (dbB.select(dbB.schoolClasses)
          ..where((t) => t.id.equals('cls_grade10')))
        .getSingleOrNull();
    final secB = await (dbB.select(dbB.sections)
          ..where((t) => t.id.equals('sec_10a')))
        .getSingleOrNull();

    expect(classB, isNotNull);
    expect(classB!.name, equals('Grade 10'));
    expect(secB, isNotNull);
    expect(secB!.name, equals('Section A'));
    expect(secB.capacity, equals(35));
    expect(secB.classId, equals('cls_grade10'));
  });

  test('Test 3: Subject sync propagates code and name', () async {
    await engineA.enqueue(
      schoolId: schoolId,
      userId: 'admin_1',
      entityType: SyncEntityType.subject,
      entityId: 'sub_math',
      operation: SyncOperation.create,
      payload: {
        'id': 'sub_math',
        'schoolId': schoolId,
        'name': 'Mathematics',
        'code': 'MATH101',
        'description': 'Advanced High School Math',
        'isActive': true,
        'isArchived': false,
      },
    );

    await propagateSync();

    final subB = await (dbB.select(dbB.subjects)
          ..where((t) => t.id.equals('sub_math')))
        .getSingleOrNull();

    expect(subB, isNotNull);
    expect(subB!.name, equals('Mathematics'));
    expect(subB.code, equals('MATH101'));
  });

  test('Test 4: Teacher sync propagates staff details', () async {
    await engineA.enqueue(
      schoolId: schoolId,
      userId: 'admin_1',
      entityType: SyncEntityType.teacher,
      entityId: 'tch_einstein',
      operation: SyncOperation.create,
      payload: {
        'id': 'tch_einstein',
        'schoolId': schoolId,
        'employeeCode': 'EMP-001',
        'name': 'Albert Einstein',
        'email': 'albert@school.lan',
        'phone': '555-0199',
        'isActive': true,
        'isArchived': false,
      },
    );

    await propagateSync();

    final tchB = await (dbB.select(dbB.teachers)
          ..where((t) => t.id.equals('tch_einstein')))
        .getSingleOrNull();

    expect(tchB, isNotNull);
    expect(tchB!.name, equals('Albert Einstein'));
    expect(tchB.employeeCode, equals('EMP-001'));
    expect(tchB.email, equals('albert@school.lan'));
  });

  test('Test 5: Student sync propagates demographic and contact info', () async {
    await engineA.enqueue(
      schoolId: schoolId,
      userId: 'admin_1',
      entityType: SyncEntityType.student,
      entityId: 'stu_curie',
      operation: SyncOperation.create,
      payload: {
        'id': 'stu_curie',
        'schoolId': schoolId,
        'studentCode': 'STU-001',
        'firstName': 'Marie',
        'lastName': 'Curie',
        'phone': '555-0200',
        'address': '10 Science Way',
        'isActive': true,
        'isArchived': false,
      },
    );

    await propagateSync();

    final stuB = await (dbB.select(dbB.students)
          ..where((t) => t.id.equals('stu_curie')))
        .getSingleOrNull();

    expect(stuB, isNotNull);
    expect(stuB!.firstName, equals('Marie'));
    expect(stuB.lastName, equals('Curie'));
    expect(stuB.studentCode, equals('STU-001'));
  });

  test('Test 6: Enrollment sync links student to class/section', () async {
    // First ensure student and section exist
    await engineA.enqueue(
      schoolId: schoolId,
      userId: 'admin_1',
      entityType: SyncEntityType.student,
      entityId: 'stu_curie',
      operation: SyncOperation.create,
      payload: {
        'id': 'stu_curie',
        'schoolId': schoolId,
        'studentCode': 'STU-001',
        'firstName': 'Marie',
        'lastName': 'Curie',
      },
    );

    await engineA.enqueue(
      schoolId: schoolId,
      userId: 'admin_1',
      entityType: SyncEntityType.enrollment,
      entityId: 'enr_001',
      operation: SyncOperation.create,
      payload: {
        'id': 'enr_001',
        'schoolId': schoolId,
        'studentId': 'stu_curie',
        'academicYearId': 'ay_2026',
        'classId': 'cls_grade10',
        'sectionId': 'sec_10a',
        'rollNumber': 1,
        'status': 'active',
      },
    );

    await propagateSync();

    final enrB = await (dbB.select(dbB.enrollments)
          ..where((t) => t.id.equals('enr_001')))
        .getSingleOrNull();

    expect(enrB, isNotNull);
    expect(enrB!.studentId, equals('stu_curie'));
    expect(enrB.sectionId, equals('sec_10a'));
    expect(enrB.rollNumber, equals(1));
  });

  test('Test 7: Timetable sync schedules periods and rooms', () async {
    await engineA.enqueue(
      schoolId: schoolId,
      userId: 'admin_1',
      entityType: SyncEntityType.timetable,
      entityId: 'tt_period1',
      operation: SyncOperation.create,
      payload: {
        'id': 'tt_period1',
        'schoolId': schoolId,
        'academicYearId': 'ay_2026',
        'classId': 'cls_grade10',
        'sectionId': 'sec_10a',
        'dayOfWeek': 1,
        'period': 1,
        'subjectId': 'sub_math',
        'teacherId': 'tch_einstein',
        'startTime': '09:00',
        'endTime': '09:45',
        'room': 'Lab 101',
      },
    );

    await propagateSync();

    final ttB = await (dbB.select(dbB.timetables)
          ..where((t) => t.id.equals('tt_period1')))
        .getSingleOrNull();

    expect(ttB, isNotNull);
    expect(ttB!.dayOfWeek, equals(1));
    expect(ttB.period, equals(1));
    expect(ttB.startTime, equals('09:00'));
    expect(ttB.endTime, equals('09:45'));
    expect(ttB.room, equals('Lab 101'));
  });

  test('Test 8: Attendance sync records daily presence', () async {
    await engineA.enqueue(
      schoolId: schoolId,
      userId: 'tch_einstein',
      entityType: SyncEntityType.attendance,
      entityId: 'att_20260910_001',
      operation: SyncOperation.create,
      payload: {
        'id': 'att_20260910_001',
        'schoolId': schoolId,
        'studentId': 'stu_curie',
        'classId': 'cls_grade10',
        'sectionId': 'sec_10a',
        'academicYearId': 'ay_2026',
        'date': '2026-09-10',
        'status': 'present',
        'markedBy': 'tch_einstein',
      },
    );

    await propagateSync();

    final attB = await (dbB.select(dbB.attendance)
          ..where((t) => t.id.equals('att_20260910_001')))
        .getSingleOrNull();

    expect(attB, isNotNull);
    expect(attB!.status, equals('present'));
    expect(attB.date, equals('2026-09-10'));
  });

  test('Test 9: Referential integrity with out-of-order event arrivals', () async {
    // Arrival 1: Section arrives first before parent Class exists on Device B
    final sectionEvent = SyncEventModel(
      eventId: 'evt_sec_delayed',
      schoolId: schoolId,
      deviceId: 'dev_a',
      userId: 'admin_1',
      entityType: SyncEntityType.section,
      entityId: 'sec_delayed_1',
      operation: SyncOperation.create,
      timestamp: DateTime.now(),
      payload: {
        'id': 'sec_delayed_1',
        'schoolId': schoolId,
        'classId': 'cls_delayed_parent',
        'name': 'Section Alpha',
        'capacity': 30,
      },
    );

    // Apply section directly on Device B
    await engineB.applyIncomingEvent(sectionEvent);

    // Section should be deferred because cls_delayed_parent does not exist yet
    var secInDb = await (dbB.select(dbB.sections)
          ..where((t) => t.id.equals('sec_delayed_1')))
        .getSingleOrNull();
    expect(secInDb, isNull);
    expect(engineB.deferredEventManager.pendingCount, equals(1));

    // Arrival 2: Parent Class arrives on Device B
    final classEvent = SyncEventModel(
      eventId: 'evt_class_parent',
      schoolId: schoolId,
      deviceId: 'dev_a',
      userId: 'admin_1',
      entityType: SyncEntityType.schoolClass,
      entityId: 'cls_delayed_parent',
      operation: SyncOperation.create,
      timestamp: DateTime.now(),
      payload: {
        'id': 'cls_delayed_parent',
        'schoolId': schoolId,
        'academicYearId': 'ay_2026',
        'name': 'Grade 12',
      },
    );

    await engineB.applyIncomingEvent(classEvent);

    // Now parent class exists AND deferred section should have automatically been resolved and inserted!
    final classInDb = await (dbB.select(dbB.schoolClasses)
          ..where((t) => t.id.equals('cls_delayed_parent')))
        .getSingleOrNull();
    expect(classInDb, isNotNull);
    expect(classInDb!.name, equals('Grade 12'));

    secInDb = await (dbB.select(dbB.sections)
          ..where((t) => t.id.equals('sec_delayed_1')))
        .getSingleOrNull();
    expect(secInDb, isNotNull);
    expect(secInDb!.name, equals('Section Alpha'));
    expect(engineB.deferredEventManager.pendingCount, equals(0));
  });
}
