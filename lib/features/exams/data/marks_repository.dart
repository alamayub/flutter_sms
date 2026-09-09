// lib/features/exams/data/marks_repository.dart
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
import '../domain/result_calculator.dart';

final marksRepositoryProvider = Provider<MarksRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final audit = ref.watch(auditRepositoryProvider);
  final syncEngine = ref.watch(syncEngineProvider);
  return MarksRepository(db, audit, syncEngine);
});

class MarksProgress {
  final int totalStudents;
  final int enteredStudents;
  final double percentage;

  const MarksProgress({
    required this.totalStudents,
    required this.enteredStudents,
    required this.percentage,
  });
}

class MarkInputData {
  final String studentId;
  final double? theoryMarks;
  final double? practicalMarks;
  final double? internalMarks;
  final MarkStatus status;
  final String? remarks;

  const MarkInputData({
    required this.studentId,
    this.theoryMarks,
    this.practicalMarks,
    this.internalMarks,
    this.status = MarkStatus.present,
    this.remarks,
  });
}

class MarksRepository {
  final AppDatabase _db;
  final AuditRepository _audit;
  final SyncEngine? _syncEngine;

  MarksRepository(this._db, this._audit, [this._syncEngine]);

  /// Saves a single mark with full validation.
  Future<Mark> saveMark({
    required String schoolId,
    required String examId,
    required String examSubjectId,
    required String studentId,
    double? theoryMarks,
    double? practicalMarks,
    double? internalMarks,
    MarkStatus status = MarkStatus.present,
    String? remarks,
    required String userId,
    String? deviceId,
    bool isAdminOverride = false,
    String? correctionReason,
    List<GradeRuleModel>? customRules,
  }) async {
    // 1. Fetch exam subject constraints
    final examSubject =
        await (_db.select(_db.examSubjects)
          ..where((t) => t.id.equals(examSubjectId))).getSingleOrNull();

    if (examSubject == null) {
      throw ArgumentError('ExamSubject $examSubjectId not found');
    }

    // 2. Validate bounds
    _validateMarks(
      examSubject: examSubject,
      theoryMarks: theoryMarks,
      practicalMarks: practicalMarks,
      internalMarks: internalMarks,
      status: status,
    );

    // 3. Check for existing mark and publication lock
    final existing =
        await (_db.select(_db.marks)..where(
          (t) =>
              t.examId.equals(examId) &
              t.examSubjectId.equals(examSubjectId) &
              t.studentId.equals(studentId),
        )).getSingleOrNull();

    if (existing != null && existing.isLocked && !isAdminOverride) {
      throw StateError(
        'Marks for this examination are published and protected. Admin authorization and correction reason required.',
      );
    }

    final now = DateTime.now();

    // 4. Calculate total, percentage, grade, grade point
    final subjectResult = ResultCalculator.calculateSubjectResult(
      subjectId: examSubject.subjectId,
      subjectName: '',
      fullMarks: examSubject.fullMarks,
      passMarks: examSubject.passMarks,
      theoryMarks: theoryMarks,
      practicalMarks: practicalMarks,
      internalMarks: internalMarks,
      status: status,
      customRules: customRules,
    );

    final String markId;

    if (existing != null) {
      markId = existing.id;

      // Log audit if this is an update or correction
      if (existing.isLocked ||
          (existing.totalMarks != subjectResult.totalMarks)) {
        await _recordMarksAudit(
          schoolId: schoolId,
          markId: markId,
          studentId: studentId,
          examId: examId,
          subjectId: examSubject.subjectId,
          oldMarks: existing.totalMarks,
          newMarks: subjectResult.totalMarks,
          oldStatus: existing.status,
          newStatus: status.value,
          changedBy: userId,
          deviceId: deviceId ?? 'local',
          reason: correctionReason ?? 'Teacher updated mark',
        );
      }

      await (_db.update(_db.marks)..where((t) => t.id.equals(markId))).write(
        MarksCompanion(
          theoryMarks: Value(theoryMarks),
          practicalMarks: Value(practicalMarks),
          internalMarks: Value(internalMarks),
          totalMarks: Value(subjectResult.totalMarks),
          percentage: Value(subjectResult.percentage),
          grade: Value(subjectResult.grade),
          gradePoint: Value(subjectResult.gradePoint),
          status: Value(status.value),
          remarks: Value(remarks),
          enteredBy: Value(userId),
          updatedAt: Value(now),
        ),
      );

      final payload = {
        'id': markId,
        'schoolId': schoolId,
        'examId': examId,
        'examSubjectId': examSubjectId,
        'studentId': studentId,
        'theoryMarks': theoryMarks,
        'practicalMarks': practicalMarks,
        'internalMarks': internalMarks,
        'totalMarks': subjectResult.totalMarks,
        'percentage': subjectResult.percentage,
        'grade': subjectResult.grade,
        'gradePoint': subjectResult.gradePoint,
        'status': status.value,
        'remarks': remarks,
        'enteredBy': userId,
        'isLocked': existing.isLocked,
        'updatedAt': now.toIso8601String(),
      };

      await _syncEngine?.enqueue(
        schoolId: schoolId,
        userId: userId,
        entityType: SyncEntityType.marks,
        entityId: markId,
        operation: SyncOperation.update,
        payload: payload,
      );
    } else {
      markId = UuidGenerator.v4();
      final companion = MarksCompanion.insert(
        id: markId,
        schoolId: schoolId,
        examId: examId,
        examSubjectId: examSubjectId,
        studentId: studentId,
        theoryMarks: Value(theoryMarks),
        practicalMarks: Value(practicalMarks),
        internalMarks: Value(internalMarks),
        totalMarks: Value(subjectResult.totalMarks),
        percentage: Value(subjectResult.percentage),
        grade: Value(subjectResult.grade),
        gradePoint: Value(subjectResult.gradePoint),
        status: Value(status.value),
        remarks: Value(remarks),
        enteredBy: userId,
        isLocked: const Value(false),
        createdAt: now,
        updatedAt: now,
      );

      await _db.into(_db.marks).insert(companion);

      final payload = {
        'id': markId,
        'schoolId': schoolId,
        'examId': examId,
        'examSubjectId': examSubjectId,
        'studentId': studentId,
        'theoryMarks': theoryMarks,
        'practicalMarks': practicalMarks,
        'internalMarks': internalMarks,
        'totalMarks': subjectResult.totalMarks,
        'percentage': subjectResult.percentage,
        'grade': subjectResult.grade,
        'gradePoint': subjectResult.gradePoint,
        'status': status.value,
        'remarks': remarks,
        'enteredBy': userId,
        'isLocked': false,
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      };

      await _syncEngine?.enqueue(
        schoolId: schoolId,
        userId: userId,
        entityType: SyncEntityType.marks,
        entityId: markId,
        operation: SyncOperation.create,
        payload: payload,
      );
    }

    return await (_db.select(_db.marks)
      ..where((t) => t.id.equals(markId))).getSingle();
  }

  /// Batch saves multiple student marks (e.g. for a class session).
  Future<void> saveDraftMarksBatch({
    required String schoolId,
    required String examId,
    required String examSubjectId,
    required List<MarkInputData> entries,
    required String userId,
    String? deviceId,
    List<GradeRuleModel>? customRules,
  }) async {
    for (final entry in entries) {
      await saveMark(
        schoolId: schoolId,
        examId: examId,
        examSubjectId: examSubjectId,
        studentId: entry.studentId,
        theoryMarks: entry.theoryMarks,
        practicalMarks: entry.practicalMarks,
        internalMarks: entry.internalMarks,
        status: entry.status,
        remarks: entry.remarks,
        userId: userId,
        deviceId: deviceId,
        customRules: customRules,
      );
    }
  }

  /// Administrator workflow to correct a published mark.
  Future<Mark> correctPublishedMark({
    required String schoolId,
    required String markId,
    required double? newTheoryMarks,
    required double? newPracticalMarks,
    required double? newInternalMarks,
    required MarkStatus newStatus,
    required String reason,
    required String adminUserId,
    String? deviceId,
  }) async {
    final existing =
        await (_db.select(_db.marks)
          ..where((t) => t.id.equals(markId))).getSingle();

    return await saveMark(
      schoolId: schoolId,
      examId: existing.examId,
      examSubjectId: existing.examSubjectId,
      studentId: existing.studentId,
      theoryMarks: newTheoryMarks,
      practicalMarks: newPracticalMarks,
      internalMarks: newInternalMarks,
      status: newStatus,
      remarks: 'Corrected: $reason',
      userId: adminUserId,
      deviceId: deviceId,
      isAdminOverride: true,
      correctionReason: reason,
    );
  }

  /// Gets all marks for a specific exam subject.
  Future<List<Mark>> getMarksForExamSubject(
    String examId,
    String examSubjectId,
  ) async {
    return await (_db.select(_db.marks)..where(
      (t) => t.examId.equals(examId) & t.examSubjectId.equals(examSubjectId),
    )).get();
  }

  /// Stream of marks for an exam subject.
  Stream<List<Mark>> watchMarksForExamSubject(
    String examId,
    String examSubjectId,
  ) {
    return (_db.select(_db.marks)..where(
      (t) => t.examId.equals(examId) & t.examSubjectId.equals(examSubjectId),
    )).watch();
  }

  /// Gets all marks for a specific student in an exam.
  Future<List<Mark>> getStudentMarksForExam(
    String examId,
    String studentId,
  ) async {
    return await (_db.select(_db.marks)..where(
      (t) => t.examId.equals(examId) & t.studentId.equals(studentId),
    )).get();
  }

  /// Calculates marks entry completion progress for a subject.
  Future<MarksProgress> getMarksProgress({
    required String examId,
    required String examSubjectId,
    required String classId,
    String? sectionId,
  }) async {
    // 1. Count enrolled students
    final enrollQuery = _db.select(_db.enrollments)
      ..where((t) => t.classId.equals(classId) & t.isArchived.equals(false));
    if (sectionId != null) {
      enrollQuery.where((t) => t.sectionId.equals(sectionId));
    }
    final enrollments = await enrollQuery.get();
    final total = enrollments.length;

    if (total == 0) {
      return const MarksProgress(
        totalStudents: 0,
        enteredStudents: 0,
        percentage: 100.0,
      );
    }

    // 2. Count entered marks
    final marks = await getMarksForExamSubject(examId, examSubjectId);
    final entered = marks.length;
    final pct = ResultCalculator.round2(
      (entered / total) * 100.0,
    ).clamp(0.0, 100.0);

    return MarksProgress(
      totalStudents: total,
      enteredStudents: entered,
      percentage: pct,
    );
  }

  /// Audits list for a mark.
  Future<List<MarksAudit>> getMarksAudits(String markId) async {
    return await (_db.select(_db.marksAudits)
          ..where((t) => t.markId.equals(markId))
          ..orderBy([(t) => OrderingTerm.desc(t.timestamp)]))
        .get();
  }

  // --- Helper Methods ---

  void _validateMarks({
    required ExamSubject examSubject,
    double? theoryMarks,
    double? practicalMarks,
    double? internalMarks,
    required MarkStatus status,
  }) {
    if (status == MarkStatus.absent ||
        status == MarkStatus.notAppeared ||
        status == MarkStatus.exempt) {
      return; // Absent or exempt do not require numerical validation
    }

    if (theoryMarks != null) {
      if (theoryMarks < 0) {
        throw ArgumentError('Theory marks cannot be negative ($theoryMarks)');
      }
      final maxTheory = examSubject.theoryMarks ?? examSubject.fullMarks;
      if (theoryMarks > maxTheory) {
        throw ArgumentError(
          'Theory marks ($theoryMarks) exceed maximum allowed ($maxTheory)',
        );
      }
    }

    if (practicalMarks != null) {
      if (practicalMarks < 0) {
        throw ArgumentError(
          'Practical marks cannot be negative ($practicalMarks)',
        );
      }
      final maxPractical = examSubject.practicalMarks ?? examSubject.fullMarks;
      if (practicalMarks > maxPractical) {
        throw ArgumentError(
          'Practical marks ($practicalMarks) exceed maximum allowed ($maxPractical)',
        );
      }
    }

    if (internalMarks != null) {
      if (internalMarks < 0) {
        throw ArgumentError(
          'Internal marks cannot be negative ($internalMarks)',
        );
      }
      final maxInternal = examSubject.internalMarks ?? examSubject.fullMarks;
      if (internalMarks > maxInternal) {
        throw ArgumentError(
          'Internal marks ($internalMarks) exceed maximum allowed ($maxInternal)',
        );
      }
    }

    final total =
        (theoryMarks ?? 0) + (practicalMarks ?? 0) + (internalMarks ?? 0);
    if (total > examSubject.fullMarks) {
      throw ArgumentError(
        'Total marks ($total) exceed full marks (${examSubject.fullMarks})',
      );
    }
  }

  Future<void> _recordMarksAudit({
    required String schoolId,
    required String markId,
    required String studentId,
    required String examId,
    required String subjectId,
    double? oldMarks,
    double? newMarks,
    String? oldStatus,
    String? newStatus,
    required String changedBy,
    required String deviceId,
    required String reason,
  }) async {
    final auditId = UuidGenerator.v4();
    final now = DateTime.now();

    await _db
        .into(_db.marksAudits)
        .insert(
          MarksAuditsCompanion.insert(
            id: auditId,
            schoolId: schoolId,
            markId: markId,
            studentId: studentId,
            examId: examId,
            subjectId: subjectId,
            oldMarks: Value(oldMarks),
            newMarks: Value(newMarks),
            oldStatus: Value(oldStatus),
            newStatus: Value(newStatus),
            changedBy: changedBy,
            deviceId: deviceId,
            timestamp: now,
            reason: reason,
          ),
        );

    await _audit.log(
      action: 'UPDATE_MARK',
      entityType: 'Mark',
      entityId: markId,
      schoolId: schoolId,
      userId: changedBy,
      metadata: {'oldMarks': oldMarks, 'newMarks': newMarks, 'reason': reason},
    );
  }
}
