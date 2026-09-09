// test/import_export_test.dart
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sms/core/database/app_database.dart';
import 'package:sms/core/database/database_service.dart';
import 'package:sms/core/errors/app_exceptions.dart';
import 'package:sms/features/attendance/data/attendance_repository.dart';
import 'package:sms/features/audit/data/audit_repository.dart';
import 'package:sms/features/database_management/services/backup_service.dart';
import 'package:sms/features/school/data/demo_data_seeder.dart';
import 'package:sms/features/school/data/school_repository.dart';
import 'package:sms/features/students/data/students_repository.dart';

void main() {
  late Directory tempDir;
  late File dbFile;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sms_backup_test_');
    dbFile = File('${tempDir.path}/test_sms.sqlite');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'Export database -> Reinitialize DB -> Import backup -> Verify 100% data',
    () async {
      final db = AppDatabase(NativeDatabase(dbFile));
      final auditRepo = AuditRepository(db);
      final schoolRepo = SchoolRepository(db, auditRepo);
      final studentsRepo = StudentsRepository(db, auditRepo);
      final backupService = BackupService(db, auditRepo);

      // 1. Seed complete demo data
      final seeder = DemoDataSeeder(db);
      await seeder.seedDemoData();

      final school = await schoolRepo.getActiveSchool();
      expect(school, isNotNull);
      expect(school!.name, 'ABC Secondary School');

      final studentCountBefore = await studentsRepo.getTotalStudentCount(
        school.id,
      );
      expect(studentCountBefore, 150);

      // 2. Export database into .sdb payload
      final sdbContent = await backupService.exportBackup();
      expect(sdbContent, isNotEmpty);
      expect(sdbContent.contains('SMS_SDB_V2'), isTrue);

      // 3. Clear/Reset entire database
      await DatabaseHelper.clearAllData(db);

      final schoolAfterClear = await schoolRepo.getActiveSchool();
      expect(schoolAfterClear, isNull);
      final countAfterClear = await studentsRepo.getTotalStudentCount(
        school.id,
      );
      expect(countAfterClear, 0);

      // 4. Import backup back into database
      await backupService.importBackup(sdbContent);

      // 5. Verify all data restored completely!
      final restoredSchool = await schoolRepo.getActiveSchool();
      expect(restoredSchool, isNotNull);
      expect(restoredSchool!.name, 'ABC Secondary School');
      expect(restoredSchool.shortName, 'ABCSS');

      final restoredStudentCount = await studentsRepo.getTotalStudentCount(
        restoredSchool.id,
      );
      expect(restoredStudentCount, 150);

      final attendanceRepo = AttendanceRepository(db, auditRepo);
      final today = DateTime.now().toIso8601String().split('T').first;
      final summary = await attendanceRepo.getDailySummary(
        schoolId: restoredSchool.id,
        date: today,
      );
      expect(summary.totalCount, 30);
      expect(summary.presentCount, 26);
      expect(summary.absentCount, 2);

      await db.close();
    },
  );

  test(
    'Corrupted/tampered backup must fail safely without destroying data',
    () async {
      final db = AppDatabase(NativeDatabase(dbFile));
      final auditRepo = AuditRepository(db);
      final schoolRepo = SchoolRepository(db, auditRepo);
      final backupService = BackupService(db, auditRepo);

      // Create a school
      await schoolRepo.createSchool(name: 'Precious Existing School');

      // Tampered payload with bad checksum
      const corruptedPayload =
          '{"format":"SMS_SDB_V1","schemaVersion":1,"checksum":"bad-checksum","data":{"schools":[]}}';

      expect(
        () => backupService.importBackup(corruptedPayload),
        throwsA(isA<BackupException>()),
      );

      // Verify existing data remains untouched!
      final school = await schoolRepo.getActiveSchool();
      expect(school, isNotNull);
      expect(school!.name, 'Precious Existing School');

      await db.close();
    },
  );

  test('Invalid format backup throws BackupException', () {
    final db = AppDatabase(NativeDatabase(dbFile));
    final auditRepo = AuditRepository(db);
    final backupService = BackupService(db, auditRepo);

    expect(
      () => backupService.validateBackupPayload('{"random":"json"}'),
      throwsA(isA<BackupException>()),
    );

    db.close();
  });
}
