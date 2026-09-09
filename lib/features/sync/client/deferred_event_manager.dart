// lib/features/sync/client/deferred_event_manager.dart
import '../domain/sync_event_model.dart';

class DeferredEventItem {
  final SyncEventModel event;
  final String requiredEntityType;
  final String requiredEntityId;
  final DateTime deferredAt;

  DeferredEventItem({
    required this.event,
    required this.requiredEntityType,
    required this.requiredEntityId,
    DateTime? deferredAt,
  }) : deferredAt = deferredAt ?? DateTime.now();
}

class DeferredEventManager {
  final List<DeferredEventItem> _deferredQueue = [];

  int get pendingCount => _deferredQueue.length;

  /// Defer an event that has an unfulfilled referential dependency.
  void defer({
    required SyncEventModel event,
    required String requiredEntityType,
    required String requiredEntityId,
  }) {
    // Avoid duplicate deferred entries for the same event
    if (!_deferredQueue.any((item) => item.event.eventId == event.eventId)) {
      _deferredQueue.add(
        DeferredEventItem(
          event: event,
          requiredEntityType: requiredEntityType,
          requiredEntityId: requiredEntityId,
        ),
      );
    }
  }

  /// Removes and returns all events waiting on a newly arrived entity.
  List<SyncEventModel> takeResolvableEvents(
    String entityType,
    String entityId,
  ) {
    final resolvable = <SyncEventModel>[];
    _deferredQueue.removeWhere((item) {
      if (item.requiredEntityType == entityType &&
          item.requiredEntityId == entityId) {
        resolvable.add(item.event);
        return true;
      }
      return false;
    });
    return resolvable;
  }

  void clear() {
    _deferredQueue.clear();
  }
}
