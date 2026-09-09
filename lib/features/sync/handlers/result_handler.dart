// lib/features/sync/handlers/result_handler.dart
import 'package:drift/drift.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/database/app_database.dart';
import '../client/conflict_manager.dart';
import '../domain/sync_event_model.dart';
import 'entity_sync_handler.dart';

class ResultHandler implements EntitySyncHandler {
  @override
  String get entityType => SyncEntityType.result;

  @override
  bool canHandle(String type) => type == SyncEntityType.result;

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
    final studentId = p['studentId'] as String? ?? '';
    final classId = p['classId'] as String? ?? '';
    final sectionId = p['sectionId'] as String? ?? '';
    final totalMarksObtained =
        (p['totalMarksObtained'] as num?)?.toDouble() ?? 0.0;
    final totalFullMarks = (p['totalFullMarks'] as num?)?.toDouble() ?? 0.0;
    final percentage = (p['percentage'] as num?)?.toDouble() ?? 0.0;
    final gpa = (p['gpa'] as num?)?.toDouble();
    final overallGrade = p['overallGrade'] as String?;
    final isPassed = p['isPassed'] as bool? ?? false;
    final rank = p['rank'] as int?;
    final calculatedAt =
        p['calculatedAt'] != null
            ? DateTime.parse(p['calculatedAt'] as String)
            : DateTime.now();

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

    final existing =
        await (db.select(db.results)
          ..where((t) => t.id.equals(id))).getSingleOrNull();

    if (existing != null) {
      await (db.update(db.results)..where((t) => t.id.equals(id))).write(
        ResultsCompanion(
          totalMarksObtained: Value(totalMarksObtained),
          totalFullMarks: Value(totalFullMarks),
          percentage: Value(percentage),
          gpa: Value(gpa),
          overallGrade: Value(overallGrade),
          isPassed: Value(isPassed),
          rank: Value(rank),
          calculatedAt: Value(calculatedAt),
        ),
      );
    } else {
      await db
          .into(db.results)
          .insert(
            ResultsCompanion.insert(
              id: id,
              schoolId: schoolId,
              examId: examId,
              studentId: studentId,
              classId: classId,
              sectionId: sectionId,
              totalMarksObtained: totalMarksObtained,
              totalFullMarks: totalFullMarks,
              percentage: percentage,
              gpa: Value(gpa),
              overallGrade: Value(overallGrade),
              isPassed: isPassed,
              rank: Value(rank),
              calculatedAt: calculatedAt,
            ),
          );
    }
  }
}
