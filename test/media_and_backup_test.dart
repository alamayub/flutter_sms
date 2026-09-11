import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sms/services/app_media_service.dart';
import 'package:sms/services/database_backup_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory globalTempDir;

  setUpAll(() async {
    globalTempDir = await Directory.systemTemp.createTemp('sms_test_global_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (MethodCall methodCall) async {
            return globalTempDir.path;
          },
        );
  });

  tearDownAll(() async {
    if (await globalTempDir.exists()) {
      await globalTempDir.delete(recursive: true);
    }
  });

  group('AppMediaService Tests', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('sms_media_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('Media directories are resolved and created properly', () async {
      final mediaDir = await AppMediaService.getMediaDirectory();
      final logosDir = await AppMediaService.getLogosDirectory();
      final studentsDir = await AppMediaService.getStudentsDirectory();
      final employeesDir = await AppMediaService.getEmployeesDirectory();

      expect(await mediaDir.exists(), isTrue);
      expect(await logosDir.exists(), isTrue);
      expect(await studentsDir.exists(), isTrue);
      expect(await employeesDir.exists(), isTrue);
      expect(p.basename(mediaDir.path), 'sms_media');
      expect(p.isWithin(mediaDir.path, logosDir.path), isTrue);
      expect(p.isWithin(mediaDir.path, studentsDir.path), isTrue);
      expect(p.isWithin(mediaDir.path, employeesDir.path), isTrue);
    });

    test(
      'Saving logo, student, and employee files persists to dedicated folders',
      () async {
        // Create a mock source image file
        final mockSource = File(p.join(tempDir.path, 'sample_photo.png'));
        await mockSource.writeAsBytes([1, 2, 3, 4, 5, 6, 7, 8]);

        // Save logo
        final savedLogoPath = await AppMediaService.saveLogoFile(mockSource);
        expect(File(savedLogoPath).existsSync(), isTrue);
        expect(savedLogoPath.contains('sms_media/logos'), isTrue);

        // Save student photo
        final savedStudentPath = await AppMediaService.saveStudentPhotoFile(
          mockSource,
          studentId: 'STD-101',
        );
        expect(File(savedStudentPath).existsSync(), isTrue);
        expect(savedStudentPath.contains('sms_media/students'), isTrue);
        expect(savedStudentPath.contains('STD_101'), isTrue);

        // Save employee photo
        final savedEmpPath = await AppMediaService.saveEmployeePhotoFile(
          mockSource,
          employeeCode: 'TCH-005',
        );
        expect(File(savedEmpPath).existsSync(), isTrue);
        expect(savedEmpPath.contains('sms_media/employees'), isTrue);
        expect(savedEmpPath.contains('TCH_005'), isTrue);

        // Verify countMediaFiles is positive
        final count = await AppMediaService.countMediaFiles();
        expect(count, greaterThanOrEqualTo(3));

        // Test deleteMediaFile
        await AppMediaService.deleteMediaFile(savedLogoPath);
        expect(File(savedLogoPath).existsSync(), isFalse);
        await AppMediaService.deleteMediaFile(savedStudentPath);
        expect(File(savedStudentPath).existsSync(), isFalse);
        await AppMediaService.deleteMediaFile(savedEmpPath);
        expect(File(savedEmpPath).existsSync(), isFalse);
      },
    );
  });

  group('DatabaseBackupService Full ZIP & DB Tests', () {
    late Directory testDir;
    late File validMockDb;

    setUp(() async {
      testDir = await Directory.systemTemp.createTemp('sms_backup_test_');

      // Create a mock SQLite 3 database file with valid 16-byte magic header
      validMockDb = File(p.join(testDir.path, 'valid.db'));
      final headerBytes = Uint8List.fromList([
        0x53, 0x51, 0x4c, 0x69, 0x74, 0x65, 0x20, 0x66,
        0x6f, 0x72, 0x6d, 0x61, 0x74, 0x20, 0x33, 0x00,
        ...List.filled(100, 0), // padding
      ]);
      await validMockDb.writeAsBytes(headerBytes);
    });

    tearDown(() async {
      if (await testDir.exists()) {
        await testDir.delete(recursive: true);
      }
    });

    test('Validates SQLite database header correctly', () async {
      expect(
        await DatabaseBackupService.validateDatabaseFile(validMockDb),
        isTrue,
      );

      final invalidFile = File(p.join(testDir.path, 'invalid.db'));
      await invalidFile.writeAsString('THIS IS NOT A SQLITE DATABASE');
      expect(
        await DatabaseBackupService.validateDatabaseFile(invalidFile),
        isFalse,
      );
    });

    test(
      'Full ZIP export bundles database, manifest, and media folder',
      () async {
        // Ensure live db exists for export test
        final liveDb = await DatabaseBackupService.getLiveDatabaseFile();
        await liveDb.parent.create(recursive: true);
        await liveDb.writeAsBytes(await validMockDb.readAsBytes());

        // Save a sample photo to media folder
        final mockPhoto = File(p.join(testDir.path, 'test_media.jpg'));
        await mockPhoto.writeAsBytes([10, 20, 30, 40]);
        final savedMedia = await AppMediaService.saveLogoFile(mockPhoto);

        // Perform full export
        final exportResult = await DatabaseBackupService.exportDatabase(
          customTargetDirectory: testDir.path,
          schoolName: 'Pragyan High',
          includeMedia: true,
        );

        expect(exportResult.success, isTrue);
        expect(exportResult.backupInfo, isNotNull);
        expect(exportResult.backupInfo!.isFullBackup, isTrue);
        expect(exportResult.backupInfo!.fileName.endsWith('.zip'), isTrue);

        final zipFile = File(exportResult.backupInfo!.filePath);
        expect(await zipFile.exists(), isTrue);

        // Validate backup file using validateBackupFile
        final isValidZip = await DatabaseBackupService.validateBackupFile(
          zipFile,
        );
        expect(isValidZip, isTrue);

        // Inspect zip archive contents
        final zipBytes = await zipFile.readAsBytes();
        final archive = ZipDecoder().decodeBytes(zipBytes, verify: false);
        final entryNames = archive.map((e) => e.name).toList();

        expect(entryNames.contains('app.db'), isTrue);
        expect(entryNames.contains('backup_manifest.json'), isTrue);

        // Cleanup saved media
        await AppMediaService.deleteMediaFile(savedMedia);
      },
    );

    test('Full ZIP import restores database and unpacks media files', () async {
      // Create a packaged zip archive with a mock app.db and sms_media/
      final zipPath = p.join(testDir.path, 'test_full_backup.zip');
      final encoder = ZipFileEncoder();
      encoder.create(zipPath);

      // Add db
      await encoder.addFile(validMockDb, 'app.db');

      // Add dummy media file
      final dummyMediaDir = Directory(p.join(testDir.path, 'mock_media'));
      await dummyMediaDir.create(recursive: true);
      final dummyLogo = File(
        p.join(dummyMediaDir.path, 'sms_media', 'logos', 'test_logo.png'),
      );
      await dummyLogo.parent.create(recursive: true);
      await dummyLogo.writeAsBytes([99, 98, 97]);
      await encoder.addDirectory(
        Directory(p.join(dummyMediaDir.path, 'sms_media')),
        includeDirName: true,
      );
      await encoder.close();

      // Test import
      final importResult = await DatabaseBackupService.importDatabase(zipPath);
      expect(importResult.success, isTrue);
      expect(importResult.backupInfo!.isFullBackup, isTrue);

      // Verify live db was restored
      final liveDb = await DatabaseBackupService.getLiveDatabaseFile();
      expect(await liveDb.exists(), isTrue);
      expect(await DatabaseBackupService.validateDatabaseFile(liveDb), isTrue);

      // Verify media file was restored to live sms_media
      final mediaDir = await AppMediaService.getMediaDirectory();
      final restoredLogo = File(
        p.join(mediaDir.path, 'logos', 'test_logo.png'),
      );
      expect(await restoredLogo.exists(), isTrue);

      // Cleanup
      await AppMediaService.deleteMediaFile(restoredLogo.path);
    });

    test(
      'Standalone .db import continues to work for backward compatibility',
      () async {
        final importResult = await DatabaseBackupService.importDatabase(
          validMockDb.path,
        );
        expect(importResult.success, isTrue);
        expect(importResult.backupInfo!.isFullBackup, isFalse);

        final liveDb = await DatabaseBackupService.getLiveDatabaseFile();
        expect(await liveDb.exists(), isTrue);
        expect(
          await DatabaseBackupService.validateDatabaseFile(liveDb),
          isTrue,
        );
      },
    );
  });
}
