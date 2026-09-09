// lib/features/sync/handlers/entity_sync_handler.dart
import '../../../core/database/app_database.dart';
import '../client/conflict_manager.dart';
import '../domain/sync_event_model.dart';

class MissingDependencyException implements Exception {
  final String requiredEntityType;
  final String requiredEntityId;

  const MissingDependencyException(
    this.requiredEntityType,
    this.requiredEntityId,
  );

  @override
  String toString() =>
      'MissingDependencyException: $requiredEntityType ($requiredEntityId)';
}

abstract class EntitySyncHandler {
  String get entityType;

  bool canHandle(String type) => type == entityType;

  /// Applies an incoming sync event to local SQLite database.
  /// Throws [MissingDependencyException] if a prerequisite parent entity is missing.
  Future<void> apply(
    SyncEventModel event,
    AppDatabase db,
    ConflictManager conflictManager,
  );
}
