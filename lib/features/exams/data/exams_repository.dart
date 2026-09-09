// lib/features/exams/data/exams_repository.dart
import 'package:drift/drift.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_service.dart';
import '../../../core/utils/uuid_generator.dart';
import '../../audit/data/audit_repository.dart';
import '../../sync/client/sync_engine.dart';
import '../../sync/presentation/sync_controller.dart';
import '../domain/exam_models.dart';

final examsRepositoryProvider = Provider<ExamsRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final audit = ref.watch(auditRepositoryProvider);
  final syncEngine = ref.watch(syncEngineProvider);
  return ExamsRepository(db, audit, syncEngine);
});

class ExamsRepository {
  final AppDatabase _db;
  final AuditRepository _audit;
  final SyncEngine? _syncEngine;

  ExamsRepository(this._db, this._audit, [this._syncEngine]);

  /// Creates a new examination record.
  Future<Exam> createExam({
    required String schoolId,
    required String academicYearId,
    required String name,
    String? description,
    required DateTime startDate,
    required DateTime endDate,
    ExamStatus status = ExamStatus.draft,
    double weight = 1.0,
    required String userId,
  }) async {
    final id = UuidGenerator.v4();
    final now = DateTime.now();

    final examCompanion = ExamsCompanion.insert(
      id: id,
      schoolId: schoolId,
      academicYearId: academicYearId,
      name: name,
      description: Value(description),
      startDate: startDate,
      endDate: endDate,
      status: Value(status.value),
      weight: Value(weight),
      createdBy: userId,
      createdAt: now,
      updatedAt: now,
    );

    await _db.into(_db.exams).insert(examCompanion);

    final payload = {
      'id': id,
      'schoolId': schoolId,
      'academicYearId': academicYearId,
      'name': name,
      'description': description,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'status': status.value,
      'weight': weight,
      'createdBy': userId,
      'createdAt': now.toIso8601String(),
      'updatedAt': now.toIso8601String(),
    };

    await _syncEngine?.enqueue(
      schoolId: schoolId,
      userId: userId,
      entityType: SyncEntityType.exam,
      entityId: id,
      operation: SyncOperation.create,
      payload: payload,
    );

    await _audit.log(
      action: 'CREATE_EXAM',
      entityType: 'Exam',
      entityId: id,
      schoolId: schoolId,
      userId: userId,
      metadata: {'name': name},
    );

    return await (_db.select(_db.exams)
      ..where((t) => t.id.equals(id))).getSingle();
  }

  /// Updates an existing examination.
  Future<Exam> updateExam({
    required String examId,
    required String name,
    String? description,
    required DateTime startDate,
    required DateTime endDate,
    ExamStatus? status,
    double? weight,
    required String userId,
  }) async {
    final existing =
        await (_db.select(_db.exams)
          ..where((t) => t.id.equals(examId))).getSingle();
    final now = DateTime.now();

    final companion = ExamsCompanion(
      name: Value(name),
      description: Value(description),
      startDate: Value(startDate),
      endDate: Value(endDate),
      status: status != null ? Value(status.value) : Value(existing.status),
      weight: weight != null ? Value(weight) : Value(existing.weight),
      updatedAt: Value(now),
    );

    await (_db.update(_db.exams)
      ..where((t) => t.id.equals(examId))).write(companion);

    final payload = {
      'id': examId,
      'schoolId': existing.schoolId,
      'academicYearId': existing.academicYearId,
      'name': name,
      'description': description,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'status': status?.value ?? existing.status,
      'weight': weight ?? existing.weight,
      'updatedAt': now.toIso8601String(),
    };

    await _syncEngine?.enqueue(
      schoolId: existing.schoolId,
      userId: userId,
      entityType: SyncEntityType.exam,
      entityId: examId,
      operation: SyncOperation.update,
      payload: payload,
    );

    return await (_db.select(_db.exams)
      ..where((t) => t.id.equals(examId))).getSingle();
  }

  /// Updates status of an exam.
  Future<void> updateExamStatus({
    required String examId,
    required ExamStatus newStatus,
    required String userId,
  }) async {
    final existing =
        await (_db.select(_db.exams)
          ..where((t) => t.id.equals(examId))).getSingle();
    final now = DateTime.now();

    await (_db.update(_db.exams)..where((t) => t.id.equals(examId))).write(
      ExamsCompanion(status: Value(newStatus.value), updatedAt: Value(now)),
    );

    await _syncEngine?.enqueue(
      schoolId: existing.schoolId,
      userId: userId,
      entityType: SyncEntityType.exam,
      entityId: examId,
      operation: SyncOperation.update,
      payload: {
        'id': examId,
        'schoolId': existing.schoolId,
        'status': newStatus.value,
        'updatedAt': now.toIso8601String(),
      },
    );

    await _audit.log(
      action: 'UPDATE_EXAM_STATUS',
      entityType: 'Exam',
      entityId: examId,
      schoolId: existing.schoolId,
      userId: userId,
      metadata: {'from': existing.status, 'to': newStatus.value},
    );
  }

  /// Soft deletes an exam.
  Future<void> archiveExam({
    required String examId,
    required String userId,
  }) async {
    final existing =
        await (_db.select(_db.exams)
          ..where((t) => t.id.equals(examId))).getSingle();
    final now = DateTime.now();

    await (_db.update(_db.exams)..where((t) => t.id.equals(examId))).write(
      ExamsCompanion(
        isArchived: const Value(true),
        archivedAt: Value(now),
        updatedAt: Value(now),
      ),
    );

    await _syncEngine?.enqueue(
      schoolId: existing.schoolId,
      userId: userId,
      entityType: SyncEntityType.exam,
      entityId: examId,
      operation: SyncOperation.delete,
      payload: {
        'id': examId,
        'schoolId': existing.schoolId,
        'isArchived': true,
        'archivedAt': now.toIso8601String(),
      },
    );
  }

  /// Lists exams for a school and optional academic year.
  Future<List<Exam>> getExams({
    required String schoolId,
    String? academicYearId,
    bool includeArchived = false,
  }) async {
    final query = _db.select(_db.exams)
      ..where((t) => t.schoolId.equals(schoolId));
    if (academicYearId != null) {
      query.where((t) => t.academicYearId.equals(academicYearId));
    }
    if (!includeArchived) {
      query.where((t) => t.isArchived.equals(false));
    }
    query.orderBy([(t) => OrderingTerm.desc(t.startDate)]);
    return await query.get();
  }

  /// Stream of exams.
  Stream<List<Exam>> watchExams({
    required String schoolId,
    String? academicYearId,
  }) {
    final query = _db.select(_db.exams)
      ..where((t) => t.schoolId.equals(schoolId) & t.isArchived.equals(false));
    if (academicYearId != null) {
      query.where((t) => t.academicYearId.equals(academicYearId));
    }
    query.orderBy([(t) => OrderingTerm.desc(t.startDate)]);
    return query.watch();
  }

  /// Gets a single exam by ID.
  Future<Exam?> getExamById(String examId) async {
    return await (_db.select(_db.exams)
      ..where((t) => t.id.equals(examId))).getSingleOrNull();
  }

  // --- Exam Subjects Configuration ---

  /// Configures a subject for an examination in a class.
  Future<ExamSubject> configureExamSubject({
    required String schoolId,
    required String examId,
    required String classId,
    required String subjectId,
    required double fullMarks,
    required double passMarks,
    double? theoryMarks,
    double? practicalMarks,
    double? internalMarks,
    double? creditHours,
    double weight = 1.0,
    required String userId,
  }) async {
    final existing =
        await (_db.select(_db.examSubjects)..where(
          (t) =>
              t.examId.equals(examId) &
              t.classId.equals(classId) &
              t.subjectId.equals(subjectId),
        )).getSingleOrNull();

    final now = DateTime.now();

    if (existing != null) {
      // Update
      await (_db.update(_db.examSubjects)
        ..where((t) => t.id.equals(existing.id))).write(
        ExamSubjectsCompanion(
          fullMarks: Value(fullMarks),
          passMarks: Value(passMarks),
          theoryMarks: Value(theoryMarks),
          practicalMarks: Value(practicalMarks),
          internalMarks: Value(internalMarks),
          creditHours: Value(creditHours),
          weight: Value(weight),
          updatedAt: Value(now),
        ),
      );

      final payload = {
        'id': existing.id,
        'schoolId': schoolId,
        'examId': examId,
        'classId': classId,
        'subjectId': subjectId,
        'fullMarks': fullMarks,
        'passMarks': passMarks,
        'theoryMarks': theoryMarks,
        'practicalMarks': practicalMarks,
        'internalMarks': internalMarks,
        'creditHours': creditHours,
        'weight': weight,
        'updatedAt': now.toIso8601String(),
      };

      await _syncEngine?.enqueue(
        schoolId: schoolId,
        userId: userId,
        entityType: SyncEntityType.examSubject,
        entityId: existing.id,
        operation: SyncOperation.update,
        payload: payload,
      );

      return await (_db.select(_db.examSubjects)
        ..where((t) => t.id.equals(existing.id))).getSingle();
    } else {
      // Insert
      final id = UuidGenerator.v4();
      final companion = ExamSubjectsCompanion.insert(
        id: id,
        schoolId: schoolId,
        examId: examId,
        classId: classId,
        subjectId: subjectId,
        fullMarks: fullMarks,
        passMarks: passMarks,
        theoryMarks: Value(theoryMarks),
        practicalMarks: Value(practicalMarks),
        internalMarks: Value(internalMarks),
        creditHours: Value(creditHours),
        weight: Value(weight),
        createdAt: now,
        updatedAt: now,
      );

      await _db.into(_db.examSubjects).insert(companion);

      final payload = {
        'id': id,
        'schoolId': schoolId,
        'examId': examId,
        'classId': classId,
        'subjectId': subjectId,
        'fullMarks': fullMarks,
        'passMarks': passMarks,
        'theoryMarks': theoryMarks,
        'practicalMarks': practicalMarks,
        'internalMarks': internalMarks,
        'creditHours': creditHours,
        'weight': weight,
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      };

      await _syncEngine?.enqueue(
        schoolId: schoolId,
        userId: userId,
        entityType: SyncEntityType.examSubject,
        entityId: id,
        operation: SyncOperation.create,
        payload: payload,
      );

      return await (_db.select(_db.examSubjects)
        ..where((t) => t.id.equals(id))).getSingle();
    }
  }

  /// Gets all subjects configured for an exam and class.
  Future<List<ExamSubject>> getExamSubjects({
    required String examId,
    String? classId,
  }) async {
    final query = _db.select(_db.examSubjects)
      ..where((t) => t.examId.equals(examId));
    if (classId != null) {
      query.where((t) => t.classId.equals(classId));
    }
    return await query.get();
  }

  /// Stream of exam subjects.
  Stream<List<ExamSubject>> watchExamSubjects({
    required String examId,
    String? classId,
  }) {
    final query = _db.select(_db.examSubjects)
      ..where((t) => t.examId.equals(examId));
    if (classId != null) {
      query.where((t) => t.classId.equals(classId));
    }
    return query.watch();
  }

  /// Deletes an exam subject configuration.
  Future<void> deleteExamSubject({
    required String id,
    required String userId,
  }) async {
    final existing =
        await (_db.select(_db.examSubjects)
          ..where((t) => t.id.equals(id))).getSingleOrNull();
    if (existing == null) return;

    await (_db.delete(_db.examSubjects)..where((t) => t.id.equals(id))).go();

    await _syncEngine?.enqueue(
      schoolId: existing.schoolId,
      userId: userId,
      entityType: SyncEntityType.examSubject,
      entityId: id,
      operation: SyncOperation.delete,
      payload: {'id': id, 'schoolId': existing.schoolId},
    );
  }
}
