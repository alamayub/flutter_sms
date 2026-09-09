// lib/features/audit/data/audit_repository.dart
import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_service.dart';
import '../../../core/utils/uuid_generator.dart';

final auditRepositoryProvider = Provider<AuditRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return AuditRepository(db);
});

class AuditRepository {
  final AppDatabase _db;

  AuditRepository(this._db);

  /// Records an audit log entry.
  Future<void> log({
    String? schoolId,
    String? userId,
    required String action,
    required String entityType,
    String? entityId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await _db
          .into(_db.auditLogs)
          .insert(
            AuditLogsCompanion.insert(
              id: UuidGenerator.v4(),
              schoolId: Value(schoolId),
              userId: Value(userId),
              action: action,
              entityType: entityType,
              entityId: Value(entityId),
              metadata: Value(metadata != null ? jsonEncode(metadata) : null),
              createdAt: DateTime.now(),
            ),
          );
    } catch (_) {
      // Audit logging failure should not crash the app, but could be logged
    }
  }

  /// Gets recent audit logs.
  Future<List<AuditLog>> getRecentLogs({
    String? schoolId,
    int limit = 100,
  }) async {
    final query =
        _db.select(_db.auditLogs)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
          ..limit(limit);

    if (schoolId != null) {
      query.where((t) => t.schoolId.equals(schoolId));
    }

    return await query.get();
  }

  /// Watch audit logs stream.
  Stream<List<AuditLog>> watchLogs({String? schoolId, int limit = 50}) {
    final query =
        _db.select(_db.auditLogs)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
          ..limit(limit);

    if (schoolId != null) {
      query.where((t) => t.schoolId.equals(schoolId));
    }

    return query.watch();
  }
}
