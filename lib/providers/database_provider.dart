import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../data/app_database.dart';

/// Provider for singleton AppDatabase
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() {
    db.close();
  });
  return db;
});
