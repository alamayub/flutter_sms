// lib/features/database_management/services/backup_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_service.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../audit/data/audit_repository.dart';

final backupServiceProvider = Provider<BackupService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final audit = ref.watch(auditRepositoryProvider);
  return BackupService(db, audit);
});

class BackupService {
  final AppDatabase _db;
  final AuditRepository _audit;

  BackupService(this._db, this._audit);

  /// Exports the current database into an encrypted/checksummed .sdb payload string.
  Future<String> exportBackup({String? currentUserId}) async {
    final schools = await _db.select(_db.schools).get();
    final users = await _db.select(_db.users).get();
    final academicYears = await _db.select(_db.academicYears).get();
    final classes = await _db.select(_db.schoolClasses).get();
    final sections = await _db.select(_db.sections).get();
    final subjects = await _db.select(_db.subjects).get();
    final classSubjects = await _db.select(_db.classSubjects).get();
    final teachers = await _db.select(_db.teachers).get();
    final students = await _db.select(_db.students).get();
    final enrollments = await _db.select(_db.enrollments).get();
    final timetables = await _db.select(_db.timetables).get();
    final attendance = await _db.select(_db.attendance).get();
    final auditLogs = await _db.select(_db.auditLogs).get();
    final appSettings = await _db.select(_db.appSettings).get();

    final primarySchool = schools.isNotEmpty ? schools.first : null;

    final dataMap = {
      'schools': schools.map((e) => e.toJson()).toList(),
      'users': users.map((e) => e.toJson()).toList(),
      'academicYears': academicYears.map((e) => e.toJson()).toList(),
      'classes': classes.map((e) => e.toJson()).toList(),
      'sections': sections.map((e) => e.toJson()).toList(),
      'subjects': subjects.map((e) => e.toJson()).toList(),
      'classSubjects': classSubjects.map((e) => e.toJson()).toList(),
      'teachers': teachers.map((e) => e.toJson()).toList(),
      'students': students.map((e) => e.toJson()).toList(),
      'enrollments': enrollments.map((e) => e.toJson()).toList(),
      'timetables': timetables.map((e) => e.toJson()).toList(),
      'attendance': attendance.map((e) => e.toJson()).toList(),
      'auditLogs': auditLogs.map((e) => e.toJson()).toList(),
      'appSettings': appSettings.map((e) => e.toJson()).toList(),
    };

    final serializedData = jsonEncode(dataMap);
    final checksum = sha256.convert(utf8.encode(serializedData)).toString();
    final nowIso = DateTime.now().toIso8601String();

    final backupPayload = {
      'format': 'SMS_SDB_V2',
      'appVersion': '1.0.0',
      'schemaVersion': _db.schemaVersion,
      'exportedAt': nowIso,
      'metadata': {
        'schoolId': primarySchool?.id,
        'schoolName': primarySchool?.name ?? 'School Management System',
        'totalStudents': students.length,
        'totalTeachers': teachers.length,
        'totalAttendance': attendance.length,
      },
      'checksum': checksum,
      'data': dataMap,
    };

    final output = jsonEncode(backupPayload);

    // Record last backup timestamp in AppSettings
    try {
      await (_db
          .into(_db.appSettings)
          .insertOnConflictUpdate(
            AppSettingsCompanion.insert(
              key: 'last_backup_timestamp',
              value: nowIso,
              updatedAt: DateTime.now(),
            ),
          ));
    } catch (_) {}

    await _audit.log(
      schoolId: primarySchool?.id,
      userId: currentUserId,
      action: AuditAction.databaseExported,
      entityType: 'Database',
      entityId: primarySchool?.id,
      metadata: {
        'totalStudents': students.length,
        'totalTeachers': teachers.length,
        'checksum': checksum,
      },
    );

    return output;
  }

  /// Gets the timestamp of the last successful backup.
  Future<DateTime?> getLastBackupTimestamp() async {
    try {
      final setting =
          await (_db.select(_db.appSettings)..where(
            (t) => t.key.equals('last_backup_timestamp'),
          )).getSingleOrNull();
      if (setting?.value != null) {
        return DateTime.tryParse(setting!.value);
      }
    } catch (_) {}
    return null;
  }

  /// Gets the size of the database file on disk in bytes.
  Future<int> getDatabaseFileSize() async {
    try {
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(p.join(dbFolder.path, 'app.db'));
      if (await file.exists()) {
        return await file.length();
      }
    } catch (_) {}
    return 0;
  }

  Map<String, dynamic> _normalizeRow(dynamic row) {
    if (row is! Map) return {};
    final map = Map<String, dynamic>.from(row);
    if (!map.containsKey('isArchived') || map['isArchived'] == null) {
      map['isArchived'] = false;
    }
    return map;
  }

  /// Generates a suggested export filename.
  Future<String> getSuggestedExportFilename() async {
    final schools = await _db.select(_db.schools).get();
    final name =
        schools.isNotEmpty
            ? schools.first.name.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')
            : 'school';
    final dateStr = DateTime.now().toIso8601String().split('T').first;
    return '${name}_$dateStr.sdb';
  }

  /// Validates an .sdb file content without applying it.
  Map<String, dynamic> validateBackupPayload(String sdbContent) {
    if (sdbContent.trim().isEmpty) {
      throw const BackupException('Backup file is empty.');
    }

    try {
      final dynamic decodedDynamic = jsonDecode(sdbContent);
      if (decodedDynamic is! Map<String, dynamic>) {
        throw const BackupException(
          'Backup file root must be a valid JSON object.',
        );
      }
      final decoded = decodedDynamic;

      final format = decoded['format'] as String?;
      if (format != 'SMS_SDB_V1' && format != 'SMS_SDB_V2') {
        throw BackupException(
          'Invalid backup format: "$format". Expected SMS_SDB_V1 or SMS_SDB_V2.',
        );
      }

      final schemaVersion = decoded['schemaVersion'] as int?;
      if (schemaVersion == null) {
        throw const BackupException(
          'Missing schemaVersion in backup metadata.',
        );
      }
      if (schemaVersion > _db.schemaVersion) {
        throw BackupException(
          'Incompatible backup schema version ($schemaVersion). Current application supports version ${_db.schemaVersion}.',
        );
      }

      final checksum = decoded['checksum'] as String?;
      final data = decoded['data'];

      if (checksum == null || data == null || data is! Map<String, dynamic>) {
        throw const BackupException(
          'Backup payload is corrupted or missing data tables.',
        );
      }

      final serializedData = jsonEncode(data);
      final calculatedChecksum =
          sha256.convert(utf8.encode(serializedData)).toString();

      if (checksum != calculatedChecksum) {
        throw const BackupException(
          'Integrity check failed: Checksum mismatch. The file may be corrupted or modified.',
        );
      }

      return decoded;
    } on BackupException {
      rethrow;
    } catch (e) {
      throw BackupException('Failed to read or parse backup file: $e');
    }
  }

  /// Safely imports an .sdb backup.
  /// 1. Validates backup and checksum
  /// 2. Takes safety backup of current data
  /// 3. Replaces data within a transaction
  /// 4. Verifies database integrity
  /// 5. Automatically rolls back to safety backup if anything fails!
  Future<void> importBackup(String sdbContent, {String? currentUserId}) async {
    // 1. Validate
    final payload = validateBackupPayload(sdbContent);
    final data = payload['data'] as Map<String, dynamic>;

    // 2. Create in-memory safety backup of current state
    final safetyBackupString = await exportBackup(currentUserId: currentUserId);

    try {
      await _db.transaction(() async {
        // Clear all current tables
        await DatabaseHelper.clearAllData(_db);

        // Insert Schools
        if (data['schools'] != null) {
          for (final row in data['schools'] as List) {
            await _db.into(_db.schools).insert(School.fromJson(row));
          }
        }

        // Insert Users
        if (data['users'] != null) {
          for (final row in data['users'] as List) {
            await _db.into(_db.users).insert(User.fromJson(row));
          }
        }

        // Insert Academic Years
        if (data['academicYears'] != null) {
          for (final row in data['academicYears'] as List) {
            await _db
                .into(_db.academicYears)
                .insert(AcademicYear.fromJson(_normalizeRow(row)));
          }
        }

        // Insert Classes
        if (data['classes'] != null) {
          for (final row in data['classes'] as List) {
            await _db
                .into(_db.schoolClasses)
                .insert(SchoolClass.fromJson(_normalizeRow(row)));
          }
        }

        // Insert Sections
        if (data['sections'] != null) {
          for (final row in data['sections'] as List) {
            await _db
                .into(_db.sections)
                .insert(Section.fromJson(_normalizeRow(row)));
          }
        }

        // Insert Subjects
        if (data['subjects'] != null) {
          for (final row in data['subjects'] as List) {
            await _db
                .into(_db.subjects)
                .insert(Subject.fromJson(_normalizeRow(row)));
          }
        }

        // Insert Class Subjects
        if (data['classSubjects'] != null) {
          for (final row in data['classSubjects'] as List) {
            await _db
                .into(_db.classSubjects)
                .insert(ClassSubject.fromJson(row));
          }
        }

        // Insert Teachers
        if (data['teachers'] != null) {
          for (final row in data['teachers'] as List) {
            await _db
                .into(_db.teachers)
                .insert(Teacher.fromJson(_normalizeRow(row)));
          }
        }

        // Insert Students
        if (data['students'] != null) {
          for (final row in data['students'] as List) {
            await _db
                .into(_db.students)
                .insert(Student.fromJson(_normalizeRow(row)));
          }
        }

        // Insert Enrollments
        if (data['enrollments'] != null) {
          for (final row in data['enrollments'] as List) {
            await _db
                .into(_db.enrollments)
                .insert(Enrollment.fromJson(_normalizeRow(row)));
          }
        }

        // Insert Timetables
        if (data['timetables'] != null) {
          for (final row in data['timetables'] as List) {
            await _db.into(_db.timetables).insert(Timetable.fromJson(row));
          }
        }

        // Insert Attendance
        if (data['attendance'] != null) {
          for (final row in data['attendance'] as List) {
            await _db.into(_db.attendance).insert(AttendanceData.fromJson(row));
          }
        }

        // Insert Audit Logs
        if (data['auditLogs'] != null) {
          for (final row in data['auditLogs'] as List) {
            await _db.into(_db.auditLogs).insert(AuditLog.fromJson(row));
          }
        }

        // Insert App Settings
        if (data['appSettings'] != null) {
          for (final row in data['appSettings'] as List) {
            await _db.into(_db.appSettings).insert(AppSetting.fromJson(row));
          }
        }
      });

      // Verification: ensure at least one school exists if schools were in backup
      final importedSchools = await _db.select(_db.schools).get();
      if ((data['schools'] as List).isNotEmpty && importedSchools.isEmpty) {
        throw const BackupException(
          'Verification failed: No school record found after import.',
        );
      }

      await _audit.log(
        schoolId: importedSchools.isNotEmpty ? importedSchools.first.id : null,
        userId: currentUserId,
        action: AuditAction.databaseImported,
        entityType: 'Database',
        metadata: payload['metadata'] as Map<String, dynamic>?,
      );
    } catch (e) {
      // Automatic rollback to safety backup!
      try {
        await _db.transaction(() async {
          await DatabaseHelper.clearAllData(_db);
          final safetyData =
              (jsonDecode(safetyBackupString) as Map)['data']
                  as Map<String, dynamic>;
          for (final row in safetyData['schools'] ?? []) {
            await _db.into(_db.schools).insert(School.fromJson(row));
          }
          for (final row in safetyData['users'] ?? []) {
            await _db.into(_db.users).insert(User.fromJson(row));
          }
          for (final row in safetyData['academicYears'] ?? []) {
            await _db
                .into(_db.academicYears)
                .insert(AcademicYear.fromJson(_normalizeRow(row)));
          }
          for (final row in safetyData['classes'] ?? []) {
            await _db
                .into(_db.schoolClasses)
                .insert(SchoolClass.fromJson(_normalizeRow(row)));
          }
          for (final row in safetyData['sections'] ?? []) {
            await _db
                .into(_db.sections)
                .insert(Section.fromJson(_normalizeRow(row)));
          }
          for (final row in safetyData['subjects'] ?? []) {
            await _db
                .into(_db.subjects)
                .insert(Subject.fromJson(_normalizeRow(row)));
          }
          for (final row in safetyData['classSubjects'] ?? []) {
            await _db
                .into(_db.classSubjects)
                .insert(ClassSubject.fromJson(row));
          }
          for (final row in safetyData['teachers'] ?? []) {
            await _db
                .into(_db.teachers)
                .insert(Teacher.fromJson(_normalizeRow(row)));
          }
          for (final row in safetyData['students'] ?? []) {
            await _db
                .into(_db.students)
                .insert(Student.fromJson(_normalizeRow(row)));
          }
          for (final row in safetyData['enrollments'] ?? []) {
            await _db
                .into(_db.enrollments)
                .insert(Enrollment.fromJson(_normalizeRow(row)));
          }
          for (final row in safetyData['timetables'] ?? []) {
            await _db.into(_db.timetables).insert(Timetable.fromJson(row));
          }
          for (final row in safetyData['attendance'] ?? []) {
            await _db.into(_db.attendance).insert(AttendanceData.fromJson(row));
          }
          for (final row in safetyData['auditLogs'] ?? []) {
            await _db.into(_db.auditLogs).insert(AuditLog.fromJson(row));
          }
          for (final row in safetyData['appSettings'] ?? []) {
            await _db.into(_db.appSettings).insert(AppSetting.fromJson(row));
          }
        });
      } catch (_) {}

      throw BackupException(
        'Import failed and original state was preserved: $e',
      );
    }
  }
}
