// lib/features/sync/handlers/grade_scheme_handler.dart
import 'package:drift/drift.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/database/app_database.dart';
import '../../../core/utils/uuid_generator.dart';
import '../client/conflict_manager.dart';
import '../domain/sync_event_model.dart';
import 'entity_sync_handler.dart';

class GradeSchemeHandler implements EntitySyncHandler {
  @override
  String get entityType => SyncEntityType.gradeScheme;

  @override
  bool canHandle(String type) => type == SyncEntityType.gradeScheme;

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
    final name = p['name'] as String? ?? 'Grading Scheme';
    final isDefault = p['isDefault'] as bool? ?? false;
    final enableGpa = p['enableGpa'] as bool? ?? true;
    final passingGrade = p['passingGrade'] as String? ?? 'D';
    final requireAllSubjectsPass = p['requireAllSubjectsPass'] as bool? ?? true;
    final enableRanking = p['enableRanking'] as bool? ?? false;
    final now = DateTime.now();

    final existing =
        await (db.select(db.gradeSchemes)
          ..where((t) => t.id.equals(id))).getSingleOrNull();

    if (existing != null) {
      await (db.update(db.gradeSchemes)..where((t) => t.id.equals(id))).write(
        GradeSchemesCompanion(
          name: Value(name),
          isDefault: Value(isDefault),
          enableGpa: Value(enableGpa),
          passingGrade: Value(passingGrade),
          requireAllSubjectsPass: Value(requireAllSubjectsPass),
          enableRanking: Value(enableRanking),
          updatedAt: Value(now),
        ),
      );
    } else {
      await db
          .into(db.gradeSchemes)
          .insert(
            GradeSchemesCompanion.insert(
              id: id,
              schoolId: schoolId,
              name: name,
              isDefault: Value(isDefault),
              enableGpa: Value(enableGpa),
              passingGrade: Value(passingGrade),
              requireAllSubjectsPass: Value(requireAllSubjectsPass),
              enableRanking: Value(enableRanking),
              createdAt: now,
              updatedAt: now,
            ),
          );
    }

    // Update rules if provided in payload
    final rawRules = p['rules'] as List<dynamic>?;
    if (rawRules != null) {
      await (db.delete(db.gradeSchemeRules)
        ..where((t) => t.schemeId.equals(id))).go();

      for (final r in rawRules) {
        final ruleMap = r as Map<String, dynamic>;
        final ruleId = ruleMap['id'] as String? ?? UuidGenerator.v4();
        await db
            .into(db.gradeSchemeRules)
            .insert(
              GradeSchemeRulesCompanion.insert(
                id: ruleId,
                schemeId: id,
                grade: ruleMap['grade'] as String? ?? 'F',
                minPercentage:
                    (ruleMap['minPercentage'] as num?)?.toDouble() ?? 0.0,
                maxPercentage:
                    (ruleMap['maxPercentage'] as num?)?.toDouble() ?? 100.0,
                gradePoint: Value((ruleMap['gradePoint'] as num?)?.toDouble()),
                description: Value(ruleMap['description'] as String?),
                isPassing: Value(ruleMap['isPassing'] as bool? ?? true),
              ),
            );
      }
    }
  }
}
