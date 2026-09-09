// test/exams/exams_sync_test.dart
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sms/core/constants/app_constants.dart';
import 'package:sms/core/database/app_database.dart';
import 'package:sms/features/audit/data/audit_repository.dart';
import 'package:sms/features/exams/data/exams_repository.dart';
import 'package:sms/features/exams/data/grade_scheme_repository.dart';
import 'package:sms/features/exams/data/marks_repository.dart';
import 'package:sms/features/exams/data/results_repository.dart';
import 'package:sms/features/sync/client/device_service.dart';
import 'package:sms/features/sync/client/sync_engine.dart';
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

  late ExamsRepository examsRepoA;
  late MarksRepository marksRepoA;
  late ResultsRepository resultsRepoA;

  const schoolId = 'sch_exam_sync';
  const schoolName = 'Exam Sync Test School';
  const academicYearId = 'ay_exam_2026';
  const classId = 'cls_grade9';
  const sectionId = 'sec_9a';
  const subjectId = 'subj_english';
  const studentId = 'stud_alex';
  const userId = 'usr_principal';

  Future<void> propagateSync() async {
    await engineA.uploadPending();
    await engineB.downloadMissing();
    await engineB.uploadPending();
    await engineA.downloadMissing();
  }

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('exam_sync_test_');

    // Device A
    final dbFileA = File('${tempDir.path}/clientA.sqlite');
    dbA = AppDatabase(NativeDatabase(dbFileA));
    deviceServiceA = DeviceService(dbA);

    // Device B
    final dbFileB = File('${tempDir.path}/clientB.sqlite');
    dbB = AppDatabase(NativeDatabase(dbFileB));
    deviceServiceB = DeviceService(dbB);

    // Central Server
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

    // Auto-approve test devices
    final devIdA = await deviceServiceA.getOrCreateDeviceId();
    final devIdB = await deviceServiceB.getOrCreateDeviceId();
    serverStorage.registerDevice(
      deviceId: devIdA,
      schoolId: schoolId,
      deviceName: 'Admin Desktop',
      deviceType: 'Desktop',
    );
    serverStorage.approveDevice(devIdA);

    serverStorage.registerDevice(
      deviceId: devIdB,
      schoolId: schoolId,
      deviceName: 'Teacher Tablet',
      deviceType: 'Tablet',
    );
    serverStorage.approveDevice(devIdB);

    final serverUrl = 'http://127.0.0.1:${server.actualPort}';

    engineA = SyncEngine(db: dbA, deviceService: deviceServiceA);
    await engineA.initialize(schoolId: schoolId, serverHttpUrl: serverUrl);

    engineB = SyncEngine(db: dbB, deviceService: deviceServiceB);
    await engineB.initialize(schoolId: schoolId, serverHttpUrl: serverUrl);

    examsRepoA = ExamsRepository(dbA, AuditRepository(dbA), engineA);
    marksRepoA = MarksRepository(dbA, AuditRepository(dbA), engineA);
    resultsRepoA = ResultsRepository(
      dbA,
      AuditRepository(dbA),
      GradeSchemeRepository(dbA, engineA),
      engineA,
    );

    // Seed shared prerequisite entities on both databases
    final now = DateTime.now();
    for (final db in [dbA, dbB]) {
      await db
          .into(db.schools)
          .insert(
            SchoolsCompanion.insert(
              id: schoolId,
              name: schoolName,
              createdAt: now,
              updatedAt: now,
            ),
          );
      await db
          .into(db.academicYears)
          .insert(
            AcademicYearsCompanion.insert(
              id: academicYearId,
              schoolId: schoolId,
              name: '2026 Academic Year',
              startDate: now,
              endDate: now.add(const Duration(days: 365)),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await db
          .into(db.schoolClasses)
          .insert(
            SchoolClassesCompanion.insert(
              id: classId,
              schoolId: schoolId,
              academicYearId: academicYearId,
              name: 'Grade 9',
              createdAt: now,
              updatedAt: now,
            ),
          );
      await db
          .into(db.sections)
          .insert(
            SectionsCompanion.insert(
              id: sectionId,
              classId: classId,
              name: 'Section 9A',
              createdAt: now,
              updatedAt: now,
            ),
          );
      await db
          .into(db.subjects)
          .insert(
            SubjectsCompanion.insert(
              id: subjectId,
              schoolId: schoolId,
              name: 'English Language',
              code: 'ENG9',
              createdAt: now,
              updatedAt: now,
            ),
          );
      await db
          .into(db.students)
          .insert(
            StudentsCompanion.insert(
              id: studentId,
              schoolId: schoolId,
              studentCode: 'STD901',
              firstName: 'Alex',
              lastName: 'Miller',
              createdAt: now,
              updatedAt: now,
            ),
          );
    }
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

  test('Exam and ExamSubject sync from Device A to Device B', () async {
    // 1. Device A creates an exam and configures subject
    final exam = await examsRepoA.createExam(
      schoolId: schoolId,
      academicYearId: academicYearId,
      name: 'First Term Examination 2026',
      startDate: DateTime.now(),
      endDate: DateTime.now().add(const Duration(days: 7)),
      userId: userId,
    );

    final examSubject = await examsRepoA.configureExamSubject(
      schoolId: schoolId,
      examId: exam.id,
      classId: classId,
      subjectId: subjectId,
      fullMarks: 100.0,
      passMarks: 40.0,
      theoryMarks: 80.0,
      practicalMarks: 20.0,
      userId: userId,
    );

    // 2. Propagate LAN sync
    await propagateSync();

    // 3. Verify on Device B
    final examOnB =
        await (dbB.select(dbB.exams)
          ..where((t) => t.id.equals(exam.id))).getSingleOrNull();
    expect(examOnB, isNotNull);
    expect(examOnB!.name, equals('First Term Examination 2026'));

    final subjectOnB =
        await (dbB.select(dbB.examSubjects)
          ..where((t) => t.id.equals(examSubject.id))).getSingleOrNull();
    expect(subjectOnB, isNotNull);
    expect(subjectOnB!.fullMarks, equals(100.0));
    expect(subjectOnB.passMarks, equals(40.0));
    expect(subjectOnB.theoryMarks, equals(80.0));
    expect(subjectOnB.practicalMarks, equals(20.0));
  });

  test(
    'Marks entry syncs across LAN with accurate grade, percentage, and total',
    () async {
      // 1. Setup Exam and ExamSubject on Device A
      final exam = await examsRepoA.createExam(
        schoolId: schoolId,
        academicYearId: academicYearId,
        name: 'First Term Exam',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 7)),
        userId: userId,
      );

      final examSubject = await examsRepoA.configureExamSubject(
        schoolId: schoolId,
        examId: exam.id,
        classId: classId,
        subjectId: subjectId,
        fullMarks: 100.0,
        passMarks: 40.0,
        theoryMarks: 80.0,
        practicalMarks: 20.0,
        userId: userId,
      );

      // 2. Enter Mark on Device A
      final mark = await marksRepoA.saveMark(
        schoolId: schoolId,
        examId: exam.id,
        examSubjectId: examSubject.id,
        studentId: studentId,
        theoryMarks: 72.0,
        practicalMarks: 16.0,
        userId: 'teacher_1',
      );

      // 3. Propagate LAN sync
      await propagateSync();

      // 4. Verify on Device B
      final markOnB =
          await (dbB.select(dbB.marks)
            ..where((t) => t.id.equals(mark.id))).getSingleOrNull();
      expect(markOnB, isNotNull);
      expect(markOnB!.theoryMarks, equals(72.0));
      expect(markOnB.practicalMarks, equals(16.0));
      expect(markOnB.totalMarks, equals(88.0));
      expect(markOnB.percentage, equals(88.0));
      expect(markOnB.grade, equals('A'));
      expect(markOnB.status, equals('present'));
    },
  );

  test(
    'Parent-child dependency deferral: Mark resolves after ExamSubject arrives',
    () async {
      const examId = 'exam_defer_1';
      const examSubjectId = 'es_defer_1';
      const markId = 'mark_defer_1';
      final now = DateTime.now();

      // Seed exam on Device B, but NOT the ExamSubject yet
      await dbB
          .into(dbB.exams)
          .insert(
            ExamsCompanion.insert(
              id: examId,
              schoolId: schoolId,
              academicYearId: academicYearId,
              name: 'Deferred Exam Test',
              startDate: now,
              endDate: now.add(const Duration(days: 5)),
              createdBy: userId,
              createdAt: now,
              updatedAt: now,
            ),
          );

      // Device A creates the ExamSubject and Mark
      await dbA
          .into(dbA.exams)
          .insert(
            ExamsCompanion.insert(
              id: examId,
              schoolId: schoolId,
              academicYearId: academicYearId,
              name: 'Deferred Exam Test',
              startDate: now,
              endDate: now.add(const Duration(days: 5)),
              createdBy: userId,
              createdAt: now,
              updatedAt: now,
            ),
          );

      // Device A enqueues Mark FIRST (simulating out-of-order event delivery)
      await engineA.enqueue(
        schoolId: schoolId,
        userId: userId,
        entityType: SyncEntityType.marks,
        entityId: markId,
        operation: SyncOperation.create,
        payload: {
          'id': markId,
          'schoolId': schoolId,
          'examId': examId,
          'examSubjectId': examSubjectId,
          'studentId': studentId,
          'totalMarks': 85.0,
          'status': 'present',
          'isLocked': false,
          'createdAt': now.toIso8601String(),
          'updatedAt': now.toIso8601String(),
        },
      );

      // Sync the mark event to Device B
      await engineA.uploadPending();
      await engineB.downloadMissing();

      // Mark should NOT be in marks table on B yet because ExamSubject is missing (deferred!)
      var markOnB =
          await (dbB.select(dbB.marks)
            ..where((t) => t.id.equals(markId))).getSingleOrNull();
      expect(markOnB, isNull);

      // Now Device A enqueues the missing ExamSubject
      await engineA.enqueue(
        schoolId: schoolId,
        userId: userId,
        entityType: SyncEntityType.examSubject,
        entityId: examSubjectId,
        operation: SyncOperation.create,
        payload: {
          'id': examSubjectId,
          'schoolId': schoolId,
          'examId': examId,
          'classId': classId,
          'subjectId': subjectId,
          'fullMarks': 100.0,
          'passMarks': 40.0,
          'weight': 1.0,
          'createdAt': now.toIso8601String(),
          'updatedAt': now.toIso8601String(),
        },
      );

      // Sync ExamSubject to Device B -> DeferredEventManager triggers and applies the mark!
      await propagateSync();

      // Now verify Mark is present on Device B!
      markOnB =
          await (dbB.select(dbB.marks)
            ..where((t) => t.id.equals(markId))).getSingleOrNull();
      expect(markOnB, isNotNull);
      expect(markOnB!.totalMarks, equals(85.0));
    },
  );

  test('Result publication locks marks across the LAN', () async {
    // 1. Setup Exam and ExamSubject on Device A
    final exam = await examsRepoA.createExam(
      schoolId: schoolId,
      academicYearId: academicYearId,
      name: 'Term Exam For Locking',
      startDate: DateTime.now(),
      endDate: DateTime.now().add(const Duration(days: 7)),
      userId: userId,
    );

    final examSubject = await examsRepoA.configureExamSubject(
      schoolId: schoolId,
      examId: exam.id,
      classId: classId,
      subjectId: subjectId,
      fullMarks: 100.0,
      passMarks: 40.0,
      userId: userId,
    );

    final mark = await marksRepoA.saveMark(
      schoolId: schoolId,
      examId: exam.id,
      examSubjectId: examSubject.id,
      studentId: studentId,
      theoryMarks: 65.0,
      userId: userId,
    );

    // Sync to Device B
    await propagateSync();

    var markOnB =
        await (dbB.select(dbB.marks)
          ..where((t) => t.id.equals(mark.id))).getSingle();
    expect(markOnB.isLocked, isFalse);

    // 2. Publish results on Device A
    await resultsRepoA.publishResults(
      schoolId: schoolId,
      examId: exam.id,
      classId: classId,
      sectionId: sectionId,
      publishedBy: 'admin_principal',
    );

    // 3. Propagate sync to Device B
    await propagateSync();

    // 4. Verify mark on Device B is now locked!
    markOnB =
        await (dbB.select(dbB.marks)
          ..where((t) => t.id.equals(mark.id))).getSingle();
    expect(markOnB.isLocked, isTrue);

    // 5. Verify exam status on Device B is published
    final examOnB =
        await (dbB.select(dbB.exams)
          ..where((t) => t.id.equals(exam.id))).getSingle();
    expect(examOnB.status, equals('published'));
  });
}
