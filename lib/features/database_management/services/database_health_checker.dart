// lib/features/database_management/services/database_health_checker.dart
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_service.dart';
import '../../../core/logging/app_logger.dart';

final databaseHealthCheckerProvider = Provider<DatabaseHealthChecker>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return DatabaseHealthChecker(db);
});

class HealthCheckReport {
  final bool isHealthy;
  final String integrityCheckResult;
  final List<String> foreignKeyViolations;
  final List<String> logicalIntegrityIssues;
  final Map<String, int> tableCounts;
  final DateTime timestamp;

  HealthCheckReport({
    required this.isHealthy,
    required this.integrityCheckResult,
    required this.foreignKeyViolations,
    required this.logicalIntegrityIssues,
    required this.tableCounts,
    required this.timestamp,
  });

  List<String> get allIssues => [
    if (integrityCheckResult != 'ok') 'Integrity Check: $integrityCheckResult',
    ...foreignKeyViolations,
    ...logicalIntegrityIssues,
  ];
}

class DatabaseHealthChecker {
  final AppDatabase _db;

  DatabaseHealthChecker(this._db);

  /// Performs a comprehensive health check of the local SQLite database.
  Future<HealthCheckReport> checkHealth() async {
    final now = DateTime.now();
    AppLogger.info(
      'DatabaseHealthChecker',
      'Starting comprehensive database health check',
    );

    // 1. PRAGMA integrity_check
    String integrityResult = 'unknown';
    try {
      final rows = await _db.customSelect('PRAGMA integrity_check;').get();
      if (rows.isNotEmpty) {
        integrityResult = rows.first.data.values.first?.toString() ?? 'unknown';
      }
    } catch (e) {
      integrityResult = 'Error running integrity_check: $e';
    }

    // 2. PRAGMA foreign_key_check
    final fkViolations = <String>[];
    try {
      final fkRows = await _db.customSelect('PRAGMA foreign_key_check;').get();
      for (final r in fkRows) {
        fkViolations.add('Foreign key violation: ${r.data}');
      }
    } catch (e) {
      fkViolations.add('Error checking foreign keys: $e');
    }

    // 3. Logical Integrity: Orphan detection & Duplicates
    final logicalIssues = <String>[];

    // Check orphan students (schoolId not in schools)
    final orphanStudents =
        await _db.customSelect('''
      SELECT s.id, s.first_name, s.last_name FROM students s 
      LEFT JOIN schools sc ON s.school_id = sc.id 
      WHERE sc.id IS NULL
    ''').get();
    for (final r in orphanStudents) {
      final name =
          '${r.read<String>('first_name')} ${r.read<String>('last_name')}';
      logicalIssues.add(
        'Orphan Student: $name (${r.read<String>('id')}) references non-existent school',
      );
    }

    // Check orphan enrollments (missing student, class, section, or academic year)
    final orphanEnrollments =
        await _db.customSelect('''
      SELECT e.id FROM enrollments e
      LEFT JOIN students s ON e.student_id = s.id
      LEFT JOIN school_classes c ON e.class_id = c.id
      LEFT JOIN sections sec ON e.section_id = sec.id
      LEFT JOIN academic_years ay ON e.academic_year_id = ay.id
      WHERE s.id IS NULL OR c.id IS NULL OR sec.id IS NULL OR ay.id IS NULL
    ''').get();
    for (final r in orphanEnrollments) {
      logicalIssues.add(
        'Orphan Enrollment: (${r.read<String>('id')}) references missing student, class, section, or academic year',
      );
    }

    // Check duplicate attendance records
    final duplicateAttendance =
        await _db.customSelect('''
      SELECT date, student_id, class_id, section_id, COUNT(*) as cnt 
      FROM attendance 
      GROUP BY date, student_id, class_id, section_id 
      HAVING cnt > 1
    ''').get();
    for (final r in duplicateAttendance) {
      logicalIssues.add(
        'Duplicate Attendance: Student ${r.read<String>('student_id')} has ${r.read<int>('cnt')} entries on date ${r.read<String>('date')}',
      );
    }

    // Check timetable references
    final orphanTimetables =
        await _db.customSelect('''
      SELECT t.id FROM timetables t
      LEFT JOIN subjects s ON t.subject_id = s.id
      LEFT JOIN school_classes c ON t.class_id = c.id
      LEFT JOIN sections sec ON t.section_id = sec.id
      LEFT JOIN teachers tch ON t.teacher_id = tch.id
      WHERE s.id IS NULL OR c.id IS NULL OR sec.id IS NULL OR (t.teacher_id IS NOT NULL AND tch.id IS NULL)
    ''').get();
    for (final r in orphanTimetables) {
      logicalIssues.add(
        'Invalid Timetable Entry: (${r.read<String>('id')}) references non-existent subject, class, section, or teacher',
      );
    }

    // 4. Table row counts
    final tableCounts = <String, int>{};
    final tables = [
      'schools',
      'users',
      'academic_years',
      'school_classes',
      'sections',
      'subjects',
      'class_subjects',
      'teachers',
      'students',
      'enrollments',
      'timetables',
      'attendance',
      'audit_logs',
      'app_settings',
    ];

    for (final t in tables) {
      try {
        final countRow =
            await _db
                .customSelect('SELECT COUNT(*) as cnt FROM $t')
                .getSingle();
        tableCounts[t] = countRow.read<int>('cnt');
      } catch (_) {
        tableCounts[t] = 0;
      }
    }

    final isHealthy =
        integrityResult.toLowerCase() == 'ok' &&
        fkViolations.isEmpty &&
        logicalIssues.isEmpty;

    AppLogger.info(
      'DatabaseHealthChecker',
      'Health check completed: isHealthy=$isHealthy, issuesCount=${fkViolations.length + logicalIssues.length}',
    );

    return HealthCheckReport(
      isHealthy: isHealthy,
      integrityCheckResult: integrityResult,
      foreignKeyViolations: fkViolations,
      logicalIntegrityIssues: logicalIssues,
      tableCounts: tableCounts,
      timestamp: now,
    );
  }
}
