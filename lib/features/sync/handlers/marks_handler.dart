// lib/features/sync/handlers/marks_handler.dart
import 'package:drift/drift.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/database/app_database.dart';
import '../client/conflict_manager.dart';
import '../domain/sync_event_model.dart';
import 'entity_sync_handler.dart';

class MarksHandler implements EntitySyncHandler {
  @override
  String get entityType => SyncEntityType.marks;

  @override
  bool canHandle(String type) =>
      type == SyncEntityType.marks || type == 'mark' || type == 'marks';

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
    final examSubjectId = p['examSubjectId'] as String? ?? '';
    final studentId = p['studentId'] as String? ?? '';
    final theoryMarks = (p['theoryMarks'] as num?)?.toDouble();
    final practicalMarks = (p['practicalMarks'] as num?)?.toDouble();
    final internalMarks = (p['internalMarks'] as num?)?.toDouble();
    final totalMarks = (p['totalMarks'] as num?)?.toDouble();
    final percentage = (p['percentage'] as num?)?.toDouble();
    final grade = p['grade'] as String?;
    final gradePoint = (p['gradePoint'] as num?)?.toDouble();
    final status = p['status'] as String? ?? 'present';
    final remarks = p['remarks'] as String?;
    final enteredBy = p['enteredBy'] as String? ?? event.userId;
    final isLocked = p['isLocked'] as bool? ?? false;
    final now = DateTime.now();

    // Referential integrity: Student must exist
    if (studentId.isNotEmpty) {
      final student =
          await (db.select(db.students)
            ..where((t) => t.id.equals(studentId))).getSingleOrNull();
      if (student == null) {
        throw MissingDependencyException(SyncEntityType.student, studentId);
      }
    }

    // Referential integrity: Exam must exist
    if (examId.isNotEmpty) {
      final exam =
          await (db.select(db.exams)
            ..where((t) => t.id.equals(examId))).getSingleOrNull();
      if (exam == null) {
        throw MissingDependencyException(SyncEntityType.exam, examId);
      }
    }

    // Referential integrity: ExamSubject must exist
    if (examSubjectId.isNotEmpty) {
      final examSubject =
          await (db.select(db.examSubjects)
            ..where((t) => t.id.equals(examSubjectId))).getSingleOrNull();
      if (examSubject == null) {
        throw MissingDependencyException(
          SyncEntityType.examSubject,
          examSubjectId,
        );
      }
    }

    if (event.operation == SyncOperation.delete) {
      await (db.delete(db.marks)..where((t) => t.id.equals(id))).go();
      return;
    }

    final existing =
        await (db.select(db.marks)
          ..where((t) => t.id.equals(id))).getSingleOrNull();

    if (existing != null) {
      await (db.update(db.marks)..where((t) => t.id.equals(id))).write(
        MarksCompanion(
          theoryMarks: Value(theoryMarks),
          practicalMarks: Value(practicalMarks),
          internalMarks: Value(internalMarks),
          totalMarks: Value(totalMarks),
          percentage: Value(percentage),
          grade: Value(grade),
          gradePoint: Value(gradePoint),
          status: Value(status),
          remarks: Value(remarks),
          enteredBy: Value(enteredBy),
          isLocked: Value(isLocked),
          updatedAt: Value(now),
        ),
      );
    } else {
      await db
          .into(db.marks)
          .insert(
            MarksCompanion.insert(
              id: id,
              schoolId: schoolId,
              examId: examId,
              examSubjectId: examSubjectId,
              studentId: studentId,
              theoryMarks: Value(theoryMarks),
              practicalMarks: Value(practicalMarks),
              internalMarks: Value(internalMarks),
              totalMarks: Value(totalMarks),
              percentage: Value(percentage),
              grade: Value(grade),
              gradePoint: Value(gradePoint),
              status: Value(status),
              remarks: Value(remarks),
              enteredBy: enteredBy,
              isLocked: Value(isLocked),
              createdAt: now,
              updatedAt: now,
            ),
          );
    }
  }
}
