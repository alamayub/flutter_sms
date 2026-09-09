// lib/core/database/database_service.dart
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'app_database.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() {
    db.close();
  });
  return db;
});

class DatabaseHelper {
  /// Clears all school data from the database in safe reverse-dependency order.
  static Future<void> clearAllData(AppDatabase db) async {
    await db.transaction(() async {
      await db.delete(db.attendance).go();
      await db.delete(db.timetables).go();
      await db.delete(db.enrollments).go();
      await db.delete(db.classSubjects).go();
      await db.delete(db.sections).go();
      await db.delete(db.schoolClasses).go();
      await db.delete(db.subjects).go();
      await db.delete(db.students).go();
      await db.delete(db.teachers).go();
      await db.delete(db.academicYears).go();
      await db.delete(db.users).go();
      await db.delete(db.schools).go();
      await db.delete(db.auditLogs).go();
      await db.delete(db.appSettings).go();
    });
  }
}
