// lib/features/sync/handlers/exam_subject_handler.dart
import 'package:drift/drift.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/database/app_database.dart';
import '../client/conflict_manager.dart';
import '../domain/sync_event_model.dart';
import 'entity_sync_handler.dart';

class ExamSubjectHandler implements EntitySyncHandler {
  @override
  String get entityType => SyncEntityType.examSubject;

  @override
  bool canHandle(String type) => type == SyncEntityType.examSubject;

  @override
  Future<void> apply(
    SyncEventModel event,
    AppDatabase db,
    ConflictManager conflictManager,
  ) async {
    final conflictResult = await conflictManager.evaluateConflict(
      remoteEvent: event,
    );
    final p = conflictResult.mergedPayload;

    final id = event.entityId;
    final schoolId = event.schoolId;
    final examId = p['examId'] as String? ?? '';
    final classId = p['classId'] as String? ?? '';
    final subjectId = p['subjectId'] as String? ?? '';
    final fullMarks = (p['fullMarks'] as num?)?.toDouble() ?? 100.0;
    final passMarks = (p['passMarks'] as num?)?.toDouble() ?? 40.0;
    final theoryMarks = (p['theoryMarks'] as num?)?.toDouble();
    final practicalMarks = (p['practicalMarks'] as num?)?.toDouble();
    final internalMarks = (p['internalMarks'] as num?)?.toDouble();
    final creditHours = (p['creditHours'] as num?)?.toDouble();
    final weight = (p['weight'] as num?)?.toDouble() ?? 1.0;
    final now = DateTime.now();

    // Referential integrity: Exam must exist
    if (examId.isNotEmpty) {
      final exam =
          await (db.select(db.exams)
            ..where((t) => t.id.equals(examId))).getSingleOrNull();
      if (exam == null) {
        throw MissingDependencyException(SyncEntityType.exam, examId);
      }
    }

    if (event.operation == SyncOperation.delete) {
      await (db.delete(db.examSubjects)..where((t) => t.id.equals(id))).go();
      return;
    }

    final existing =
        await (db.select(db.examSubjects)
          ..where((t) => t.id.equals(id))).getSingleOrNull();

    if (existing != null) {
      await (db.update(db.examSubjects)..where((t) => t.id.equals(id))).write(
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
    } else {
      await db
          .into(db.examSubjects)
          .insert(
            ExamSubjectsCompanion.insert(
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
            ),
          );
    }
  }
}
