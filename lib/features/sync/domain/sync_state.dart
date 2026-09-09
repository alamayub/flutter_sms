// lib/features/sync/domain/sync_state.dart

enum SyncConnectivityState {
  localOnly, // Operating fully offline, no server reachable
  connected, // Connected to School Server on LAN, idle
  syncing, // Actively uploading or downloading sync events
  syncComplete, // All local pending events synced, up to date with server
  error, // Network error or sync rejection
}

class SyncStatusInfo {
  final SyncConnectivityState connectivity;
  final String? serverUrl;
  final String? serverId;
  final int pendingCount;
  final DateTime? lastSyncTime;
  final String? errorMessage;

  const SyncStatusInfo({
    this.connectivity = SyncConnectivityState.localOnly,
    this.serverUrl,
    this.serverId,
    this.pendingCount = 0,
    this.lastSyncTime,
    this.errorMessage,
  });

  SyncStatusInfo copyWith({
    SyncConnectivityState? connectivity,
    String? serverUrl,
    String? serverId,
    int? pendingCount,
    DateTime? lastSyncTime,
    String? errorMessage,
  }) {
    return SyncStatusInfo(
      connectivity: connectivity ?? this.connectivity,
      serverUrl: serverUrl ?? this.serverUrl,
      serverId: serverId ?? this.serverId,
      pendingCount: pendingCount ?? this.pendingCount,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  String get displayLabel {
    switch (connectivity) {
      case SyncConnectivityState.localOnly:
        return 'Local Only';
      case SyncConnectivityState.connected:
        return 'Connected';
      case SyncConnectivityState.syncing:
        return 'Syncing ($pendingCount)';
      case SyncConnectivityState.syncComplete:
        return 'Synced';
      case SyncConnectivityState.error:
        return 'Sync Error';
    }
  }
}
