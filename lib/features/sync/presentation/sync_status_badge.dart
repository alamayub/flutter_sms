// lib/features/sync/presentation/sync_status_badge.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/sync_state.dart';
import 'sync_controller.dart';

class SyncStatusBadge extends ConsumerWidget {
  final bool compact;

  const SyncStatusBadge({super.key, this.compact = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncStatus = ref.watch(syncControllerProvider);

    Color badgeColor;
    Color dotColor;
    IconData? icon;
    String label;

    switch (syncStatus.connectivity) {
      case SyncConnectivityState.localOnly:
        badgeColor = Colors.grey.shade200;
        dotColor = Colors.grey.shade600;
        label = compact ? 'Local' : '● Local Only • Offline';
        break;
      case SyncConnectivityState.connected:
        badgeColor = AppColors.successLight;
        dotColor = AppColors.success;
        label = compact ? 'Connected' : '● Connected to School LAN';
        break;
      case SyncConnectivityState.syncing:
        badgeColor = Colors.blue.shade50;
        dotColor = Colors.blue;
        icon = Icons.sync;
        label = compact ? 'Syncing' : '↻ Syncing (${syncStatus.pendingCount})';
        break;
      case SyncConnectivityState.syncComplete:
        badgeColor = AppColors.successLight;
        dotColor = AppColors.success;
        icon = Icons.check_circle_outline;
        label = compact ? 'Synced' : '✓ Synced with School Server';
        break;
      case SyncConnectivityState.error:
        badgeColor = Colors.orange.shade50;
        dotColor = Colors.orange.shade800;
        icon = Icons.warning_amber_outlined;
        label = compact ? 'Sync Error' : '⚠ Sync Error';
        break;
    }

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => _showSyncDetails(context, ref, syncStatus),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 12,
          vertical: compact ? 4 : 6,
        ),
        decoration: BoxDecoration(
          color: badgeColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: dotColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null)
              Icon(icon, size: 12, color: dotColor)
            else
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: dotColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSyncDetails(
    BuildContext context,
    WidgetRef ref,
    SyncStatusInfo status,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        final timeStr =
            status.lastSyncTime != null
                ? DateFormat.jm().format(status.lastSyncTime!)
                : 'Never';

        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.sync, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text('LAN Synchronization'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildRow('Status', status.displayLabel),
              const SizedBox(height: 8),
              _buildRow('School Server', status.serverUrl ?? 'Not connected'),
              const SizedBox(height: 8),
              _buildRow('Pending Changes', '${status.pendingCount} queued'),
              const SizedBox(height: 8),
              _buildRow('Last Sync', timeStr),
              if (status.errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  status.errorMessage!,
                  style: const TextStyle(color: AppColors.danger, fontSize: 12),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                context.go('/sync-settings');
              },
              child: const Text('Sync Settings'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                ref.read(syncControllerProvider.notifier).syncNow();
              },
              child: const Text('Sync Now'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
