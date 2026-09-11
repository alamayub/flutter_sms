import '../services/app_media_service.dart';

/// Helper utility for picking and storing images locally in the app's persistent media storage
class ImageStorageHelper {
  /// Prompts user to pick an image from device gallery, copies it to local
  /// app storage (`<app_doc_dir>/sms_media/employees/`), and returns the absolute local path.
  static Future<String?> pickAndSaveEmployeePhoto({
    String? employeeCode,
  }) async {
    return AppMediaService.pickAndSaveEmployeePhoto(employeeCode: employeeCode);
  }

  /// Safely deletes an employee's photo from local storage if it exists
  static Future<void> deleteEmployeePhoto(String? path) async {
    return AppMediaService.deleteMediaFile(path);
  }

  /// Prompts user to pick an image from device gallery, copies it to local
  /// app storage (`<app_doc_dir>/sms_media/students/`), and returns the absolute local path.
  static Future<String?> pickAndSaveStudentPhoto({String? studentId}) async {
    return AppMediaService.pickAndSaveStudentPhoto(studentId: studentId);
  }

  /// Safely deletes a student's photo from local storage if it exists
  static Future<void> deleteStudentPhoto(String? path) async {
    return AppMediaService.deleteMediaFile(path);
  }

  /// Checks whether a given path points to an existing local file
  static bool isLocalFile(String? path) {
    return AppMediaService.isLocalFile(path);
  }
}
