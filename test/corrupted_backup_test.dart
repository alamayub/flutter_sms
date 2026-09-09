// test/corrupted_backup_test.dart
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sms/core/database/app_database.dart';
import 'package:sms/core/errors/app_exceptions.dart';
import 'package:sms/features/audit/data/audit_repository.dart';
import 'package:sms/features/database_management/services/backup_service.dart';
import 'package:sms/features/school/data/school_repository.dart';

void main() {
  late Directory tempDir;
  late File dbFile;
  late AppDatabase db;
  late AuditRepository auditRepo;
  late SchoolRepository schoolRepo;
  late BackupService backupService;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'sms_corrupted_backup_test_',
    );
    dbFile = File('${tempDir.path}/corrupt_test.sqlite');
    db = AppDatabase(NativeDatabase(dbFile));
    auditRepo = AuditRepository(db);
    schoolRepo = SchoolRepository(db, auditRepo);
    backupService = BackupService(db, auditRepo);

    // Create a pristine active school
    await schoolRepo.createSchool(
      name: 'Pristine Safe School',
      shortName: 'PSS',
    );
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('Rejects empty or whitespace backup file without touching DB', () async {
    expect(
      () => backupService.validateBackupPayload(''),
      throwsA(isA<BackupException>()),
    );
    expect(
      () => backupService.validateBackupPayload('   \n\t  '),
      throwsA(isA<BackupException>()),
    );

    // Ensure database remained untouched
    final school = await schoolRepo.getActiveSchool();
    expect(school, isNotNull);
    expect(school!.name, 'Pristine Safe School');
  });

  test('Rejects random non-JSON binary bytes without touching DB', () async {
    const randomGarbage = '\x00\x01\xFF\xFERandomGarbage!#\$%^&*()';
    expect(
      () => backupService.validateBackupPayload(randomGarbage),
      throwsA(isA<BackupException>()),
    );

    expect(
      () => backupService.importBackup(randomGarbage),
      throwsA(isA<BackupException>()),
    );

    final school = await schoolRepo.getActiveSchool();
    expect(school, isNotNull);
    expect(school!.name, 'Pristine Safe School');
  });

  test('Rejects truncated JSON without touching DB', () async {
    const truncated =
        '{"format":"SMS_SDB_V2","schemaVersion":2,"data":{"schools":[';
    expect(
      () => backupService.validateBackupPayload(truncated),
      throwsA(isA<BackupException>()),
    );

    expect(
      () => backupService.importBackup(truncated),
      throwsA(isA<BackupException>()),
    );

    final school = await schoolRepo.getActiveSchool();
    expect(school, isNotNull);
    expect(school!.name, 'Pristine Safe School');
  });

  test('Rejects missing or invalid format identifier', () async {
    const missingFormat = '{"schemaVersion":2,"data":{}}';
    expect(
      () => backupService.validateBackupPayload(missingFormat),
      throwsA(isA<BackupException>()),
    );

    const invalidFormat =
        '{"format":"WORDPRESS_BACKUP","schemaVersion":2,"data":{}}';
    expect(
      () => backupService.validateBackupPayload(invalidFormat),
      throwsA(isA<BackupException>()),
    );
  });

  test('Rejects unsupported future schema version', () async {
    final data = {'schools': []};
    final serializedData = jsonEncode(data);
    final checksum = sha256.convert(utf8.encode(serializedData)).toString();

    final futurePayload = jsonEncode({
      'format': 'SMS_SDB_V2',
      'schemaVersion': 999, // Incompatible future version
      'checksum': checksum,
      'data': data,
    });

    expect(
      () => backupService.validateBackupPayload(futurePayload),
      throwsA(isA<BackupException>()),
    );

    expect(
      () => backupService.importBackup(futurePayload),
      throwsA(isA<BackupException>()),
    );

    final school = await schoolRepo.getActiveSchool();
    expect(school!.name, 'Pristine Safe School');
  });

  test('Rejects tampered checksum', () async {
    final validExport = await backupService.exportBackup();
    final decoded = jsonDecode(validExport) as Map<String, dynamic>;

    // Tamper the checksum
    decoded['checksum'] = 'tampered-fake-checksum-12345';
    final tamperedPayload = jsonEncode(decoded);

    expect(
      () => backupService.validateBackupPayload(tamperedPayload),
      throwsA(isA<BackupException>()),
    );

    expect(
      () => backupService.importBackup(tamperedPayload),
      throwsA(isA<BackupException>()),
    );

    final school = await schoolRepo.getActiveSchool();
    expect(school!.name, 'Pristine Safe School');
  });

  test('Rejects tampered payload data where checksum does not match', () async {
    final validExport = await backupService.exportBackup();
    final decoded = jsonDecode(validExport) as Map<String, dynamic>;

    // Tamper the data inside
    final data = decoded['data'] as Map<String, dynamic>;
    data['schools'] = [
      {'id': 'injected_hack', 'name': 'Hacked School', 'is_active': true},
    ];
    final tamperedPayload = jsonEncode(decoded);

    expect(
      () => backupService.validateBackupPayload(tamperedPayload),
      throwsA(isA<BackupException>()),
    );

    expect(
      () => backupService.importBackup(tamperedPayload),
      throwsA(isA<BackupException>()),
    );

    final school = await schoolRepo.getActiveSchool();
    expect(school!.name, 'Pristine Safe School');
  });
}
