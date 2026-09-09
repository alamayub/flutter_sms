// lib/features/exams/data/results_repository.dart
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
import '../domain/ranking_service.dart';
import '../domain/result_calculator.dart';
import 'grade_scheme_repository.dart';

final resultsRepositoryProvider = Provider<ResultsRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final audit = ref.watch(auditRepositoryProvider);
  final schemeRepo = ref.watch(gradeSchemeRepositoryProvider);
  final syncEngine = ref.watch(syncEngineProvider);
  return ResultsRepository(db, audit, schemeRepo, syncEngine);
});

class ClassResultsSummary {
  final int totalStudents;
  final int passCount;
  final int failCount;
  final double averagePercentage;
  final double highestPercentage;
  final double lowestPercentage;
  final List<StudentExamResult> studentResults;
  final Map<String, double> subjectAverages; // Subject Name -> Average %
  final bool isPublished;

  const ClassResultsSummary({
    required this.totalStudents,
    required this.passCount,
    required this.failCount,
    required this.averagePercentage,
    required this.highestPercentage,
    required this.lowestPercentage,
    required this.studentResults,
    required this.subjectAverages,
    required this.isPublished,
  });
}

class StudentResultHistoryItem {
  final String academicYearName;
  final String examName;
  final DateTime examDate;
  final double percentage;
  final String overallGrade;
  final double? gpa;
  final bool isPassed;
  final int? rank;

  const StudentResultHistoryItem({
    required this.academicYearName,
    required this.examName,
    required this.examDate,
    required this.percentage,
    required this.overallGrade,
    this.gpa,
    required this.isPassed,
    this.rank,
  });
}

class ResultsRepository {
  final AppDatabase _db;
  final AuditRepository _audit;
  final GradeSchemeRepository _schemeRepo;
  final SyncEngine? _syncEngine;

  ResultsRepository(
    this._db,
    this._audit,
    this._schemeRepo, [
    this._syncEngine,
  ]);

  /// Calculates and persists examination results for all students in a class/section.
  Future<List<StudentExamResult>> calculateAndSaveResults({
    required String schoolId,
    required String examId,
    required String classId,
    String? sectionId,
    required String userId,
  }) async {
    // 1. Fetch grading scheme
    final scheme = await _schemeRepo.ensureDefaultScheme(schoolId);
    final rules = await _schemeRepo.getRulesForScheme(scheme.id);

    // 2. Fetch exam subjects for this class
    final examSubjects =
        await (_db.select(_db.examSubjects)..where(
          (t) => t.examId.equals(examId) & t.classId.equals(classId),
        )).get();

    if (examSubjects.isEmpty) return [];

    // Map subject details
    final subjectIds = examSubjects.map((s) => s.subjectId).toList();
    final subjects =
        await (_db.select(_db.subjects)
          ..where((t) => t.id.isIn(subjectIds))).get();
    final subjectMap = {for (final s in subjects) s.id: s.name};
    final creditHoursMap = {
      for (final es in examSubjects) es.subjectId: es.creditHours ?? 1.0,
    };

    // 3. Fetch enrolled students
    final enrollQuery = _db.select(_db.enrollments)
      ..where((t) => t.classId.equals(classId) & t.isArchived.equals(false));
    if (sectionId != null) {
      enrollQuery.where((t) => t.sectionId.equals(sectionId));
    }
    final enrollments = await enrollQuery.get();
    if (enrollments.isEmpty) return [];

    final studentIds = enrollments.map((e) => e.studentId).toList();
    final students =
        await (_db.select(_db.students)
          ..where((t) => t.id.isIn(studentIds))).get();
    final studentMap = {for (final s in students) s.id: s};
    final enrollmentMap = {for (final e in enrollments) e.studentId: e};

    // 4. Fetch all marks entered for this exam
    final allMarks =
        await (_db.select(_db.marks)
          ..where((t) => t.examId.equals(examId))).get();

    final unrankedResults = <StudentExamResult>[];

    for (final studentId in studentIds) {
      final student = studentMap[studentId];
      final enrollment = enrollmentMap[studentId];
      if (student == null || enrollment == null) continue;

      final studentMarks =
          allMarks.where((m) => m.studentId == studentId).toList();
      final subjectResults = <SubjectResult>[];

      for (final es in examSubjects) {
        final mark =
            studentMarks.where((m) => m.examSubjectId == es.id).firstOrNull;
        final subName = subjectMap[es.subjectId] ?? 'Subject';
        final status =
            mark != null
                ? MarkStatus.fromString(mark.status)
                : MarkStatus.absent;

        final subRes = ResultCalculator.calculateSubjectResult(
          subjectId: es.subjectId,
          subjectName: subName,
          fullMarks: es.fullMarks,
          passMarks: es.passMarks,
          theoryMarks: mark?.theoryMarks,
          practicalMarks: mark?.practicalMarks,
          internalMarks: mark?.internalMarks,
          status: status,
          customRules: rules,
        );
        subjectResults.add(subRes);
      }

      final studentResult = ResultCalculator.calculateStudentResult(
        studentId: studentId,
        studentName: '${student.firstName} ${student.lastName}'.trim(),
        studentCode: student.studentCode,
        rollNumber: enrollment.rollNumber,
        classId: classId,
        sectionId: enrollment.sectionId,
        subjectResults: subjectResults,
        enableGpa: scheme.enableGpa,
        requireAllSubjectsPass: scheme.requireAllSubjectsPass,
        customRules: rules,
        subjectCreditHours: creditHoursMap,
      );

      unrankedResults.add(studentResult);
    }

    // 5. Rank students
    final finalResults =
        scheme.enableRanking
            ? RankingService.rankStudents(
              unrankedResults,
              rankPassingOnly: true,
            )
            : unrankedResults;

    final now = DateTime.now();

    // 6. Save results to database and sync
    for (final res in finalResults) {
      final existingResult =
          await (_db.select(_db.results)..where(
            (t) => t.examId.equals(examId) & t.studentId.equals(res.studentId),
          )).getSingleOrNull();

      if (existingResult != null) {
        await (_db.update(_db.results)
          ..where((t) => t.id.equals(existingResult.id))).write(
          ResultsCompanion(
            totalMarksObtained: Value(res.totalMarksObtained),
            totalFullMarks: Value(res.totalFullMarks),
            percentage: Value(res.percentage),
            gpa: Value(res.gpa),
            overallGrade: Value(res.overallGrade),
            isPassed: Value(res.isPassed),
            rank: Value(res.rank),
            calculatedAt: Value(now),
          ),
        );

        await _syncEngine?.enqueue(
          schoolId: schoolId,
          userId: userId,
          entityType: SyncEntityType.result,
          entityId: existingResult.id,
          operation: SyncOperation.update,
          payload: {
            'id': existingResult.id,
            'schoolId': schoolId,
            'examId': examId,
            'studentId': res.studentId,
            'classId': res.classId,
            'sectionId': res.sectionId,
            'totalMarksObtained': res.totalMarksObtained,
            'totalFullMarks': res.totalFullMarks,
            'percentage': res.percentage,
            'gpa': res.gpa,
            'overallGrade': res.overallGrade,
            'isPassed': res.isPassed,
            'rank': res.rank,
            'calculatedAt': now.toIso8601String(),
          },
        );
      } else {
        final resultId = UuidGenerator.v4();
        await _db
            .into(_db.results)
            .insert(
              ResultsCompanion.insert(
                id: resultId,
                schoolId: schoolId,
                examId: examId,
                studentId: res.studentId,
                classId: res.classId,
                sectionId: res.sectionId,
                totalMarksObtained: res.totalMarksObtained,
                totalFullMarks: res.totalFullMarks,
                percentage: res.percentage,
                gpa: Value(res.gpa),
                overallGrade: Value(res.overallGrade),
                isPassed: res.isPassed,
                rank: Value(res.rank),
                calculatedAt: now,
              ),
            );

        await _syncEngine?.enqueue(
          schoolId: schoolId,
          userId: userId,
          entityType: SyncEntityType.result,
          entityId: resultId,
          operation: SyncOperation.create,
          payload: {
            'id': resultId,
            'schoolId': schoolId,
            'examId': examId,
            'studentId': res.studentId,
            'classId': res.classId,
            'sectionId': res.sectionId,
            'totalMarksObtained': res.totalMarksObtained,
            'totalFullMarks': res.totalFullMarks,
            'percentage': res.percentage,
            'gpa': res.gpa,
            'overallGrade': res.overallGrade,
            'isPassed': res.isPassed,
            'rank': res.rank,
            'calculatedAt': now.toIso8601String(),
          },
        );
      }
    }

    return finalResults;
  }

  /// Publishes results, locking marks against standard modifications.
  Future<void> publishResults({
    required String schoolId,
    required String examId,
    required String classId,
    String? sectionId,
    required String publishedBy,
  }) async {
    final now = DateTime.now();

    // 1. Create or update publication record
    final existing =
        await (_db.select(_db.resultPublications)..where(
          (t) => t.examId.equals(examId) & t.classId.equals(classId),
        )).getSingleOrNull();

    final String pubId;
    if (existing != null) {
      pubId = existing.id;
      await (_db.update(_db.resultPublications)
        ..where((t) => t.id.equals(pubId))).write(
        ResultPublicationsCompanion(
          publishedAt: Value(now),
          publishedBy: Value(publishedBy),
          isPublished: const Value(true),
          status: const Value('published'),
        ),
      );
    } else {
      pubId = UuidGenerator.v4();
      await _db
          .into(_db.resultPublications)
          .insert(
            ResultPublicationsCompanion.insert(
              id: pubId,
              schoolId: schoolId,
              examId: examId,
              classId: classId,
              sectionId: Value(sectionId),
              publishedAt: now,
              publishedBy: publishedBy,
              isPublished: const Value(true),
              status: const Value('published'),
            ),
          );
    }

    // 2. Lock marks for this exam & class
    final examSubjects =
        await (_db.select(_db.examSubjects)..where(
          (t) => t.examId.equals(examId) & t.classId.equals(classId),
        )).get();
    final examSubjectIds = examSubjects.map((es) => es.id).toList();

    if (examSubjectIds.isNotEmpty) {
      await (_db.update(_db.marks)..where(
        (t) => t.examSubjectId.isIn(examSubjectIds),
      )).write(const MarksCompanion(isLocked: Value(true)));
    }

    // 3. Update exam status to published
    await (_db.update(_db.exams)..where((t) => t.id.equals(examId))).write(
      ExamsCompanion(status: const Value('published'), updatedAt: Value(now)),
    );

    // 4. Enqueue sync events
    await _syncEngine?.enqueue(
      schoolId: schoolId,
      userId: publishedBy,
      entityType: SyncEntityType.resultPublication,
      entityId: pubId,
      operation: SyncOperation.create,
      payload: {
        'id': pubId,
        'schoolId': schoolId,
        'examId': examId,
        'classId': classId,
        'sectionId': sectionId,
        'publishedAt': now.toIso8601String(),
        'publishedBy': publishedBy,
        'isPublished': true,
        'status': 'published',
      },
    );

    await _audit.log(
      action: 'PUBLISH_RESULTS',
      entityType: 'Exam',
      entityId: examId,
      schoolId: schoolId,
      userId: publishedBy,
      metadata: {'classId': classId},
    );
  }

  /// Checks if results for an exam & class are published.
  Future<bool> isResultsPublished(String examId, String classId) async {
    final pub =
        await (_db.select(_db.resultPublications)..where(
          (t) =>
              t.examId.equals(examId) &
              t.classId.equals(classId) &
              t.isPublished.equals(true),
        )).getSingleOrNull();
    return pub != null;
  }

  /// Gets class results summary for display on results dashboard.
  Future<ClassResultsSummary> getClassResultsSummary({
    required String schoolId,
    required String examId,
    required String classId,
    String? sectionId,
  }) async {
    final results = await calculateAndSaveResults(
      schoolId: schoolId,
      examId: examId,
      classId: classId,
      sectionId: sectionId,
      userId: 'system_calc',
    );

    final isPub = await isResultsPublished(examId, classId);

    if (results.isEmpty) {
      return ClassResultsSummary(
        totalStudents: 0,
        passCount: 0,
        failCount: 0,
        averagePercentage: 0.0,
        highestPercentage: 0.0,
        lowestPercentage: 0.0,
        studentResults: const [],
        subjectAverages: const {},
        isPublished: isPub,
      );
    }

    int passCount = 0;
    int failCount = 0;
    double totalPct = 0.0;
    double highest = results.first.percentage;
    double lowest = results.first.percentage;

    final subjectTotalMap = <String, double>{};
    final subjectCountMap = <String, int>{};

    for (final r in results) {
      if (r.isPassed) {
        passCount++;
      } else {
        failCount++;
      }
      totalPct += r.percentage;
      if (r.percentage > highest) highest = r.percentage;
      if (r.percentage < lowest) lowest = r.percentage;

      for (final sr in r.subjectResults) {
        if (sr.percentage != null) {
          subjectTotalMap[sr.subjectName] =
              (subjectTotalMap[sr.subjectName] ?? 0.0) + sr.percentage!;
          subjectCountMap[sr.subjectName] =
              (subjectCountMap[sr.subjectName] ?? 0) + 1;
        }
      }
    }

    final subjectAverages = <String, double>{};
    subjectTotalMap.forEach((name, total) {
      final count = subjectCountMap[name] ?? 1;
      subjectAverages[name] = ResultCalculator.round2(total / count);
    });

    final avgPct = ResultCalculator.round2(totalPct / results.length);

    return ClassResultsSummary(
      totalStudents: results.length,
      passCount: passCount,
      failCount: failCount,
      averagePercentage: avgPct,
      highestPercentage: highest,
      lowestPercentage: lowest,
      studentResults: results,
      subjectAverages: subjectAverages,
      isPublished: isPub,
    );
  }

  /// Retrieves student historical results grouped by academic year and exam.
  Future<List<StudentResultHistoryItem>> getStudentResultsHistory(
    String studentId,
  ) async {
    final query =
        _db.select(_db.results).join([
            innerJoin(_db.exams, _db.exams.id.equalsExp(_db.results.examId)),
            innerJoin(
              _db.academicYears,
              _db.academicYears.id.equalsExp(_db.exams.academicYearId),
            ),
          ])
          ..where(_db.results.studentId.equals(studentId))
          ..orderBy([OrderingTerm.desc(_db.exams.startDate)]);

    final rows = await query.get();

    return rows.map((row) {
      final res = row.readTable(_db.results);
      final ex = row.readTable(_db.exams);
      final ay = row.readTable(_db.academicYears);

      return StudentResultHistoryItem(
        academicYearName: ay.name,
        examName: ex.name,
        examDate: ex.startDate,
        percentage: res.percentage,
        overallGrade: res.overallGrade ?? 'N/A',
        gpa: res.gpa,
        isPassed: res.isPassed,
        rank: res.rank,
      );
    }).toList();
  }
}
