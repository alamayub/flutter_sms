// lib/features/exams/data/grade_scheme_repository.dart
import 'package:drift/drift.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_service.dart';
import '../../../core/utils/uuid_generator.dart';
import '../../sync/client/sync_engine.dart';
import '../../sync/presentation/sync_controller.dart';
import '../domain/exam_models.dart';
import '../domain/grading_engine.dart';

final gradeSchemeRepositoryProvider = Provider<GradeSchemeRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final syncEngine = ref.watch(syncEngineProvider);
  return GradeSchemeRepository(db, syncEngine);
});

class GradeSchemeRepository {
  final AppDatabase _db;
  final SyncEngine? _syncEngine;

  GradeSchemeRepository(this._db, [this._syncEngine]);

  /// Ensures a default grading scheme exists for the school.
  Future<GradeScheme> ensureDefaultScheme(String schoolId) async {
    final existing =
        await (_db.select(_db.gradeSchemes)..where(
          (t) => t.schoolId.equals(schoolId) & t.isDefault.equals(true),
        )).getSingleOrNull();

    if (existing != null) return existing;

    final id = UuidGenerator.v4();
    final now = DateTime.now();

    await _db
        .into(_db.gradeSchemes)
        .insert(
          GradeSchemesCompanion.insert(
            id: id,
            schoolId: schoolId,
            name: 'Standard Letter Grading (GPA 4.0)',
            isDefault: const Value(true),
            enableGpa: const Value(true),
            passingGrade: const Value('D'),
            requireAllSubjectsPass: const Value(true),
            enableRanking: const Value(true),
            createdAt: now,
            updatedAt: now,
          ),
        );

    // Insert default rules
    for (final rule in GradingEngine.defaultRules) {
      final ruleId = UuidGenerator.v4();
      await _db
          .into(_db.gradeSchemeRules)
          .insert(
            GradeSchemeRulesCompanion.insert(
              id: ruleId,
              schemeId: id,
              grade: rule.grade,
              minPercentage: rule.minPercentage,
              maxPercentage: rule.maxPercentage,
              gradePoint: Value(rule.gradePoint),
              description: Value(rule.description),
              isPassing: Value(rule.isPassing),
            ),
          );
    }

    return await (_db.select(_db.gradeSchemes)
      ..where((t) => t.id.equals(id))).getSingle();
  }

  /// Gets all grading schemes for a school.
  Future<List<GradeScheme>> getSchemes(String schoolId) async {
    await ensureDefaultScheme(schoolId);
    return await (_db.select(_db.gradeSchemes)
      ..where((t) => t.schoolId.equals(schoolId))).get();
  }

  /// Gets rules for a specific scheme.
  Future<List<GradeRuleModel>> getRulesForScheme(String schemeId) async {
    final rules =
        await (_db.select(_db.gradeSchemeRules)
              ..where((t) => t.schemeId.equals(schemeId))
              ..orderBy([(t) => OrderingTerm.desc(t.minPercentage)]))
            .get();

    return rules
        .map(
          (r) => GradeRuleModel(
            grade: r.grade,
            minPercentage: r.minPercentage,
            maxPercentage: r.maxPercentage,
            gradePoint: r.gradePoint,
            description: r.description,
            isPassing: r.isPassing,
          ),
        )
        .toList();
  }

  /// Saves a custom scheme with its rules.
  Future<GradeScheme> saveScheme({
    required String schoolId,
    String? schemeId,
    required String name,
    bool isDefault = false,
    bool enableGpa = true,
    String passingGrade = 'D',
    bool requireAllSubjectsPass = true,
    bool enableRanking = false,
    required List<GradeRuleModel> rules,
    required String userId,
  }) async {
    final validationError = GradingEngine.validateRules(rules);
    if (validationError != null) {
      throw ArgumentError(validationError);
    }

    final id = schemeId ?? UuidGenerator.v4();
    final now = DateTime.now();

    if (isDefault) {
      // Unset previous defaults
      await (_db.update(_db.gradeSchemes)..where(
        (t) => t.schoolId.equals(schoolId),
      )).write(const GradeSchemesCompanion(isDefault: Value(false)));
    }

    if (schemeId != null) {
      await (_db.update(_db.gradeSchemes)..where((t) => t.id.equals(id))).write(
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

      // Replace rules
      await (_db.delete(_db.gradeSchemeRules)
        ..where((t) => t.schemeId.equals(id))).go();
    } else {
      await _db
          .into(_db.gradeSchemes)
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

    for (final rule in rules) {
      final ruleId = UuidGenerator.v4();
      await _db
          .into(_db.gradeSchemeRules)
          .insert(
            GradeSchemeRulesCompanion.insert(
              id: ruleId,
              schemeId: id,
              grade: rule.grade,
              minPercentage: rule.minPercentage,
              maxPercentage: rule.maxPercentage,
              gradePoint: Value(rule.gradePoint),
              description: Value(rule.description),
              isPassing: Value(rule.isPassing),
            ),
          );
    }

    final payload = {
      'id': id,
      'schoolId': schoolId,
      'name': name,
      'isDefault': isDefault,
      'enableGpa': enableGpa,
      'passingGrade': passingGrade,
      'requireAllSubjectsPass': requireAllSubjectsPass,
      'enableRanking': enableRanking,
      'rules': rules.map((r) => r.toJson()).toList(),
      'updatedAt': now.toIso8601String(),
    };

    await _syncEngine?.enqueue(
      schoolId: schoolId,
      userId: userId,
      entityType: SyncEntityType.gradeScheme,
      entityId: id,
      operation: schemeId != null ? SyncOperation.update : SyncOperation.create,
      payload: payload,
    );

    return await (_db.select(_db.gradeSchemes)
      ..where((t) => t.id.equals(id))).getSingle();
  }
}
