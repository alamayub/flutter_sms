// lib/features/sync/handlers/result_publication_handler.dart
import 'package:drift/drift.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/database/app_database.dart';
import '../client/conflict_manager.dart';
import '../domain/sync_event_model.dart';
import 'entity_sync_handler.dart';

class ResultPublicationHandler implements EntitySyncHandler {
  @override
  String get entityType => SyncEntityType.resultPublication;

  @override
  bool canHandle(String type) => type == SyncEntityType.resultPublication;

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
    final sectionId = p['sectionId'] as String?;
    final publishedAt =
        p['publishedAt'] != null
            ? DateTime.parse(p['publishedAt'] as String)
            : DateTime.now();
    final publishedBy = p['publishedBy'] as String? ?? event.userId;
    final isPublished = p['isPublished'] as bool? ?? true;
    final status = p['status'] as String? ?? 'published';
    final now = DateTime.now();

    final existing =
        await (db.select(db.resultPublications)
          ..where((t) => t.id.equals(id))).getSingleOrNull();

    if (existing != null) {
      await (db.update(db.resultPublications)
        ..where((t) => t.id.equals(id))).write(
        ResultPublicationsCompanion(
          publishedAt: Value(publishedAt),
          publishedBy: Value(publishedBy),
          isPublished: Value(isPublished),
          status: Value(status),
        ),
      );
    } else {
      await db
          .into(db.resultPublications)
          .insert(
            ResultPublicationsCompanion.insert(
              id: id,
              schoolId: schoolId,
              examId: examId,
              classId: classId,
              sectionId: Value(sectionId),
              publishedAt: publishedAt,
              publishedBy: publishedBy,
              isPublished: Value(isPublished),
              status: Value(status),
            ),
          );
    }

    if (isPublished) {
      // 1. Lock all marks for this exam and class
      final examSubjects =
          await (db.select(db.examSubjects)..where(
            (t) => t.examId.equals(examId) & t.classId.equals(classId),
          )).get();
      final esIds = examSubjects.map((es) => es.id).toList();

      if (esIds.isNotEmpty) {
        await (db.update(db.marks)..where(
          (t) => t.examSubjectId.isIn(esIds),
        )).write(const MarksCompanion(isLocked: Value(true)));
      }

      // 2. Set exam status to published
      await (db.update(db.exams)..where((t) => t.id.equals(examId))).write(
        ExamsCompanion(status: const Value('published'), updatedAt: Value(now)),
      );
    }
  }
}
