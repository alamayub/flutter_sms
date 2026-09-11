import 'dart:convert';
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/app_database.dart';
import 'app_media_service.dart';

class DatabaseBackupInfo {
  final String filePath;
  final String fileName;
  final int fileSizeBytes;
  final DateTime createdAt;
  final bool isFullBackup;
  final int mediaFileCount;

  const DatabaseBackupInfo({
    required this.filePath,
    required this.fileName,
    required this.fileSizeBytes,
    required this.createdAt,
    this.isFullBackup = false,
    this.mediaFileCount = 0,
  });

  String get formattedSize {
    if (fileSizeBytes < 1024) return '$fileSizeBytes B';
    if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  String get formattedDate {
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(createdAt);
  }
}

class DatabaseBackupResult {
  final bool success;
  final String message;
  final DatabaseBackupInfo? backupInfo;

  const DatabaseBackupResult.success(
    this.backupInfo, [
    this.message = 'Backup processed successfully',
  ]) : success = true;

  const DatabaseBackupResult.failure(this.message)
    : success = false,
      backupInfo = null;
}

class DatabaseBackupService {
  /// Header bytes for standard SQLite 3 databases: "SQLite format 3\0"
  static const List<int> _sqliteHeaderBytes = [
    0x53,
    0x51,
    0x4c,
    0x69,
    0x74,
    0x65,
    0x20,
    0x66,
    0x6f,
    0x72,
    0x6d,
    0x61,
    0x74,
    0x20,
    0x33,
    0x00,
  ];

  /// Retrieves the active live database file path
  static Future<File> getLiveDatabaseFile() async {
    final docsDir = await getApplicationDocumentsDirectory();
    return File(p.join(docsDir.path, 'app.db'));
  }

  /// Retrieves the dedicated folder where backups are saved
  static Future<Directory> getBackupsDirectory() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final backupDir = Directory(p.join(docsDir.path, 'sms_backups'));
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }
    return backupDir;
  }

  /// Validates whether the given file is an authentic SQLite 3 database
  static Future<bool> validateDatabaseFile(File file) async {
    if (!await file.exists()) return false;
    final length = await file.length();
    if (length < 100) return false;

    try {
      final raf = await file.open(mode: FileMode.read);
      final header = await raf.read(16);
      await raf.close();

      if (header.length < 16) return false;
      for (int i = 0; i < 16; i++) {
        if (header[i] != _sqliteHeaderBytes[i]) return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Validates whether a file is a valid backup (either SQLite 3 DB or Full ZIP Backup)
  static Future<bool> validateBackupFile(File file) async {
    if (!await file.exists()) return false;
    final ext = p.extension(file.path).toLowerCase();

    if (ext == '.zip' || ext == '.smsbackup') {
      try {
        final bytes = await file.readAsBytes();
        final archive = ZipDecoder().decodeBytes(bytes, verify: false);

        for (final archiveFile in archive) {
          if (archiveFile.name == 'app.db' ||
              archiveFile.name.endsWith('/app.db') ||
              archiveFile.name.endsWith('.db')) {
            final content = archiveFile.content;
            if (content.length >= 16) {
              var matches = true;
              for (int i = 0; i < 16; i++) {
                if (content[i] != _sqliteHeaderBytes[i]) {
                  matches = false;
                  break;
                }
              }
              if (matches) return true;
            }
          }
        }
        return false;
      } catch (_) {
        return false;
      }
    } else {
      return validateDatabaseFile(file);
    }
  }

  /// Exports the system database and all media (logos, student & employee photos)
  /// into a bundled .zip archive (or standalone .db if includeMedia is false).
  static Future<DatabaseBackupResult> exportDatabase({
    String? customTargetDirectory,
    String? schoolName,
    bool includeMedia = true,
  }) async {
    try {
      final liveDb = await getLiveDatabaseFile();
      if (!await liveDb.exists()) {
        await liveDb.create(recursive: true);
      }

      Directory targetDir;
      if (customTargetDirectory != null && customTargetDirectory.isNotEmpty) {
        targetDir = Directory(customTargetDirectory);
        if (!await targetDir.exists()) {
          await targetDir.create(recursive: true);
        }
      } else {
        targetDir = await getBackupsDirectory();
      }

      final now = DateTime.now();
      final dateStr = DateFormat('yyyyMMdd_HHmmss').format(now);
      final sanitizedSchool = (schoolName ?? 'sms').toLowerCase().replaceAll(
        RegExp(r'[^a-z0-9]'),
        '_',
      );

      final mediaDir = await AppMediaService.getMediaDirectory();
      final mediaCount = await AppMediaService.countMediaFiles();

      if (includeMedia) {
        final zipFileName = '${sanitizedSchool}_backup_$dateStr.zip';
        final zipPath = p.join(targetDir.path, zipFileName);

        final encoder = ZipFileEncoder();
        encoder.create(zipPath);

        // 1. Add live SQLite database
        await encoder.addFile(liveDb, 'app.db');

        // 2. Add manifest metadata file
        final manifestData = {
          'version': 1,
          'schoolName': schoolName ?? 'SMS School',
          'exportedAt': now.toIso8601String(),
          'databaseFile': 'app.db',
          'mediaDirectory': 'sms_media',
          'mediaCount': mediaCount,
          'isFullBackup': true,
        };
        final tempDir = await getTemporaryDirectory();
        final manifestFile = File(
          p.join(tempDir.path, 'manifest_${now.millisecondsSinceEpoch}.json'),
        );
        await manifestFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(manifestData),
        );
        await encoder.addFile(manifestFile, 'backup_manifest.json');
        try {
          await manifestFile.delete();
        } catch (_) {}

        // 3. Add entire sms_media directory tree (logos, students, employees)
        if (await mediaDir.exists()) {
          await encoder.addDirectory(mediaDir, includeDirName: true);
        }

        await encoder.close();

        final zipFile = File(zipPath);
        final size = await zipFile.length();

        final info = DatabaseBackupInfo(
          filePath: zipFile.path,
          fileName: zipFileName,
          fileSizeBytes: size,
          createdAt: now,
          isFullBackup: true,
          mediaFileCount: mediaCount,
        );

        return DatabaseBackupResult.success(
          info,
          'Full backup exported successfully with database and $mediaCount media items',
        );
      } else {
        final fileName = '${sanitizedSchool}_backup_$dateStr.db';
        final backupPath = p.join(targetDir.path, fileName);
        final targetFile = await liveDb.copy(backupPath);
        final size = await targetFile.length();

        final info = DatabaseBackupInfo(
          filePath: targetFile.path,
          fileName: fileName,
          fileSizeBytes: size,
          createdAt: now,
          isFullBackup: false,
          mediaFileCount: 0,
        );

        return DatabaseBackupResult.success(
          info,
          'Database exported successfully',
        );
      }
    } catch (e) {
      return DatabaseBackupResult.failure('Failed to export backup: $e');
    }
  }

  /// Restores/imports a backup from either a full .zip archive (database + media)
  /// or a standalone .db SQLite file.
  static Future<DatabaseBackupResult> importDatabase(
    String sourceFilePath, {
    AppDatabase? currentDb,
  }) async {
    try {
      final sourceFile = File(sourceFilePath);
      if (!await sourceFile.exists()) {
        return const DatabaseBackupResult.failure(
          'Backup file not found at specified path',
        );
      }

      final ext = p.extension(sourceFilePath).toLowerCase();
      final isZip = ext == '.zip' || ext == '.smsbackup';

      if (isZip) {
        return await _importZipBackup(sourceFile, currentDb: currentDb);
      } else {
        return await _importDbFile(sourceFile, currentDb: currentDb);
      }
    } catch (e) {
      return DatabaseBackupResult.failure('Failed to import backup: $e');
    }
  }

  /// Internal handler to restore a full .zip backup containing app.db and sms_media/
  static Future<DatabaseBackupResult> _importZipBackup(
    File sourceFile, {
    AppDatabase? currentDb,
  }) async {
    final tempDir = Directory(
      p.join(
        (await getTemporaryDirectory()).path,
        'sms_extract_${DateTime.now().millisecondsSinceEpoch}',
      ),
    );
    await tempDir.create(recursive: true);

    try {
      await extractFileToDisk(sourceFile.path, tempDir.path);

      // Locate app.db inside the extracted directory
      File? extractedDb;
      final directDb = File(p.join(tempDir.path, 'app.db'));
      if (await directDb.exists()) {
        extractedDb = directDb;
      } else {
        await for (final entity in tempDir.list(recursive: true)) {
          if (entity is File && p.basename(entity.path) == 'app.db') {
            extractedDb = entity;
            break;
          }
        }
      }

      if (extractedDb == null || !await validateDatabaseFile(extractedDb)) {
        return const DatabaseBackupResult.failure(
          'Invalid backup archive. No valid SQLite database found inside.',
        );
      }

      final liveDb = await getLiveDatabaseFile();
      final backupDir = await getBackupsDirectory();
      final dateStr = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());

      // Create safety backup of existing live database
      if (await liveDb.exists()) {
        final safetyDbPath = p.join(
          backupDir.path,
          'pre_import_safety_$dateStr.db',
        );
        await liveDb.copy(safetyDbPath);
      }

      // Close the current active database connection before replacing the file
      if (currentDb != null) {
        try {
          await currentDb.close();
        } catch (_) {}
      }

      // 1. Restore the SQLite database file
      await extractedDb.copy(liveDb.path);

      // 2. Restore media files to live sms_media folder
      var restoredMediaCount = 0;
      final liveMediaDir = await AppMediaService.getMediaDirectory();

      // Look for extracted sms_media or media directory
      Directory? extractedMediaDir;
      final directMedia = Directory(p.join(tempDir.path, 'sms_media'));
      if (await directMedia.exists()) {
        extractedMediaDir = directMedia;
      } else {
        final altMedia = Directory(p.join(tempDir.path, 'media'));
        if (await altMedia.exists()) {
          extractedMediaDir = altMedia;
        }
      }

      if (extractedMediaDir != null) {
        await for (final entity in extractedMediaDir.list(recursive: true)) {
          if (entity is File) {
            final relPath = p.relative(
              entity.path,
              from: extractedMediaDir.path,
            );
            final targetFile = File(p.join(liveMediaDir.path, relPath));
            await targetFile.parent.create(recursive: true);
            await entity.copy(targetFile.path);
            restoredMediaCount++;
          }
        }
      }

      final size = await liveDb.length();
      final info = DatabaseBackupInfo(
        filePath: liveDb.path,
        fileName: p.basename(sourceFile.path),
        fileSizeBytes: size,
        createdAt: DateTime.now(),
        isFullBackup: true,
        mediaFileCount: restoredMediaCount,
      );

      return DatabaseBackupResult.success(
        info,
        'Full backup restored successfully: database and $restoredMediaCount media files restored',
      );
    } finally {
      // Clean up temporary extraction folder
      try {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      } catch (_) {}
    }
  }

  /// Internal handler to restore a standalone .db SQLite file
  static Future<DatabaseBackupResult> _importDbFile(
    File sourceFile, {
    AppDatabase? currentDb,
  }) async {
    final isValid = await validateDatabaseFile(sourceFile);
    if (!isValid) {
      return const DatabaseBackupResult.failure(
        'Invalid file format. The file is not a valid SQLite database.',
      );
    }

    final liveDb = await getLiveDatabaseFile();

    // Close the current active database connection before replacing the file
    if (currentDb != null) {
      try {
        await currentDb.close();
      } catch (_) {}
    }

    // Create fallback safety copy of the existing live DB if it exists
    if (await liveDb.exists()) {
      final backupDir = await getBackupsDirectory();
      final safetyPath = p.join(
        backupDir.path,
        'pre_import_safety_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.db',
      );
      await liveDb.copy(safetyPath);
    }

    // Overwrite the live database with imported backup
    await sourceFile.copy(liveDb.path);

    final size = await liveDb.length();
    final info = DatabaseBackupInfo(
      filePath: liveDb.path,
      fileName: p.basename(liveDb.path),
      fileSizeBytes: size,
      createdAt: DateTime.now(),
      isFullBackup: false,
      mediaFileCount: 0,
    );

    return DatabaseBackupResult.success(
      info,
      'Database successfully imported and restored',
    );
  }

  /// Lists previously saved backup files in the default backups directory (.zip and .db)
  static Future<List<DatabaseBackupInfo>> listRecentBackups() async {
    try {
      final backupDir = await getBackupsDirectory();
      final entities = await backupDir.list().toList();
      final backups = <DatabaseBackupInfo>[];

      for (final entity in entities) {
        if (entity is File) {
          final ext = p.extension(entity.path).toLowerCase();
          if (ext == '.zip' || ext == '.smsbackup' || ext == '.db') {
            final stat = await entity.stat();
            final isZip = ext == '.zip' || ext == '.smsbackup';
            backups.add(
              DatabaseBackupInfo(
                filePath: entity.path,
                fileName: p.basename(entity.path),
                fileSizeBytes: stat.size,
                createdAt: stat.modified,
                isFullBackup: isZip,
              ),
            );
          }
        }
      }

      backups.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return backups;
    } catch (_) {
      return [];
    }
  }
}
