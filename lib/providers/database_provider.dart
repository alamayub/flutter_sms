import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../data/app_database.dart';
import '../data/database_seeder.dart';

/// Provider for singleton AppDatabase
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  // Ensure database has default seed data if empty
  DatabaseSeeder.seedIfEmpty(db);
  ref.onDispose(() {
    db.close();
  });
  return db;
});
