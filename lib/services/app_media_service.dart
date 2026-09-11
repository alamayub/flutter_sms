import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Central service for persistent local media files (school logos, student photos, employee photos)
/// stored in a dedicated `sms_media` folder alongside the SQLite database (`app.db`).
class AppMediaService {
  static final ImagePicker _picker = ImagePicker();

  /// Dedicated media directory alongside `app.db`
  static Future<Directory> getMediaDirectory() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final mediaDir = Directory(p.join(docsDir.path, 'sms_media'));
    if (!await mediaDir.exists()) {
      await mediaDir.create(recursive: true);
    }
    return mediaDir;
  }

  /// Subdirectory for school logos
  static Future<Directory> getLogosDirectory() async {
    final mediaDir = await getMediaDirectory();
    final logosDir = Directory(p.join(mediaDir.path, 'logos'));
    if (!await logosDir.exists()) {
      await logosDir.create(recursive: true);
    }
    return logosDir;
  }

  /// Subdirectory for student profile pictures
  static Future<Directory> getStudentsDirectory() async {
    final mediaDir = await getMediaDirectory();
    final studentsDir = Directory(p.join(mediaDir.path, 'students'));
    if (!await studentsDir.exists()) {
      await studentsDir.create(recursive: true);
    }
    return studentsDir;
  }

  /// Subdirectory for employee & teacher profile pictures
  static Future<Directory> getEmployeesDirectory() async {
    final mediaDir = await getMediaDirectory();
    final employeesDir = Directory(p.join(mediaDir.path, 'employees'));
    if (!await employeesDir.exists()) {
      await employeesDir.create(recursive: true);
    }
    return employeesDir;
  }

  /// Copies a picked or source file into the persistent `logos/` directory
  static Future<String> saveLogoFile(File sourceFile) async {
    final logosDir = await getLogosDirectory();
    final ext =
        p.extension(sourceFile.path).isNotEmpty
            ? p.extension(sourceFile.path)
            : '.png';
    final fileName = 'school_logo_${DateTime.now().millisecondsSinceEpoch}$ext';
    final targetPath = p.join(logosDir.path, fileName);
    final saved = await sourceFile.copy(targetPath);
    return saved.path;
  }

  /// Picks an image from device gallery and saves it into `logos/`
  static Future<String?> pickAndSaveLogo() async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 90,
      );
      if (picked == null) return null;
      return await saveLogoFile(File(picked.path));
    } catch (_) {
      return null;
    }
  }

  /// Copies a picked or source file into the persistent `students/` directory
  static Future<String> saveStudentPhotoFile(
    File sourceFile, {
    String? studentId,
  }) async {
    final studentsDir = await getStudentsDirectory();
    final ext =
        p.extension(sourceFile.path).isNotEmpty
            ? p.extension(sourceFile.path)
            : '.jpg';
    final safeId =
        studentId != null && studentId.trim().isNotEmpty
            ? studentId.trim().replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')
            : '${DateTime.now().millisecondsSinceEpoch}';
    final fileName =
        'student_${safeId}_${DateTime.now().millisecondsSinceEpoch}$ext';
    final targetPath = p.join(studentsDir.path, fileName);
    final saved = await sourceFile.copy(targetPath);
    return saved.path;
  }

  /// Picks an image from device gallery and saves it into `students/`
  static Future<String?> pickAndSaveStudentPhoto({String? studentId}) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked == null) return null;
      return await saveStudentPhotoFile(
        File(picked.path),
        studentId: studentId,
      );
    } catch (_) {
      return null;
    }
  }

  /// Copies a picked or source file into the persistent `employees/` directory
  static Future<String> saveEmployeePhotoFile(
    File sourceFile, {
    String? employeeCode,
  }) async {
    final employeesDir = await getEmployeesDirectory();
    final ext =
        p.extension(sourceFile.path).isNotEmpty
            ? p.extension(sourceFile.path)
            : '.jpg';
    final safeCode =
        employeeCode != null && employeeCode.trim().isNotEmpty
            ? employeeCode.trim().replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')
            : '${DateTime.now().millisecondsSinceEpoch}';
    final fileName =
        'emp_${safeCode}_${DateTime.now().millisecondsSinceEpoch}$ext';
    final targetPath = p.join(employeesDir.path, fileName);
    final saved = await sourceFile.copy(targetPath);
    return saved.path;
  }

  /// Picks an image from device gallery and saves it into `employees/`
  static Future<String?> pickAndSaveEmployeePhoto({
    String? employeeCode,
  }) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked == null) return null;
      return await saveEmployeePhotoFile(
        File(picked.path),
        employeeCode: employeeCode,
      );
    } catch (_) {
      return null;
    }
  }

  /// Safely deletes a media file from local disk if it exists
  static Future<void> deleteMediaFile(String? path) async {
    if (path == null || path.trim().isEmpty) return;
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Ignore cleanup error if already deleted or inaccessible
    }
  }

  /// Validates whether a given path points to an existing file
  static bool isLocalFile(String? path) {
    if (path == null || path.trim().isEmpty) return false;
    try {
      return File(path).existsSync();
    } catch (_) {
      return false;
    }
  }

  /// Recursively counts all media files within `sms_media`
  static Future<int> countMediaFiles() async {
    try {
      final mediaDir = await getMediaDirectory();
      if (!await mediaDir.exists()) return 0;
      var count = 0;
      await for (final entity in mediaDir.list(recursive: true)) {
        if (entity is File) {
          count++;
        }
      }
      return count;
    } catch (_) {
      return 0;
    }
  }

  /// Migrates legacy photos from `student_photos/` and `employee_photos/` to `sms_media/`
  static Future<void> migrateLegacyPhotos() async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();

      // Migrate student photos
      final legacyStudents = Directory(p.join(docsDir.path, 'student_photos'));
      if (await legacyStudents.exists()) {
        final targetStudents = await getStudentsDirectory();
        await for (final entity in legacyStudents.list()) {
          if (entity is File) {
            final target = File(
              p.join(targetStudents.path, p.basename(entity.path)),
            );
            if (!await target.exists()) {
              await entity.copy(target.path);
            }
          }
        }
      }

      // Migrate employee photos
      final legacyEmployees = Directory(
        p.join(docsDir.path, 'employee_photos'),
      );
      if (await legacyEmployees.exists()) {
        final targetEmployees = await getEmployeesDirectory();
        await for (final entity in legacyEmployees.list()) {
          if (entity is File) {
            final target = File(
              p.join(targetEmployees.path, p.basename(entity.path)),
            );
            if (!await target.exists()) {
              await entity.copy(target.path);
            }
          }
        }
      }
    } catch (_) {
      // Best-effort migration
    }
  }
}
