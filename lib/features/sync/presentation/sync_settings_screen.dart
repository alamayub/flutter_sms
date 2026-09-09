import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../client/device_service.dart';
import '../domain/device_model.dart';
import '../domain/sync_state.dart';
import 'sync_conflicts_screen.dart';
import 'sync_controller.dart';

class SyncSettingsScreen extends ConsumerStatefulWidget {
  const SyncSettingsScreen({super.key});

  @override
  ConsumerState<SyncSettingsScreen> createState() => _SyncSettingsScreenState();
}

class _SyncSettingsScreenState extends ConsumerState<SyncSettingsScreen> {
  final _serverUrlController = TextEditingController();
  DeviceModel? _currentDevice;
  List<DeviceModel> _schoolDevices = [];
  bool _isLoading = true;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadDeviceData();
  }

  @override
  void dispose() {
    _serverUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadDeviceData() async {
    setState(() => _isLoading = true);
    final school = ref.read(authControllerProvider).currentSchool;
    if (school == null) return;

    final deviceService = ref.read(deviceServiceProvider);
    final dev = await deviceService.getOrCreateCurrentDevice(school.id);
    final allDevs = await deviceService.getDevicesForSchool(school.id);

    final syncStatus = ref.read(syncControllerProvider);
    if (syncStatus.serverUrl != null && _serverUrlController.text.isEmpty) {
      _serverUrlController.text = syncStatus.serverUrl!;
    }

    if (mounted) {
      setState(() {
        _currentDevice = dev;
        _schoolDevices = allDevs;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleFindServer() async {
    setState(() => _isSearching = true);
    final success =
        await ref.read(syncControllerProvider.notifier).discoverAndConnect();

    if (mounted) {
      setState(() => _isSearching = false);
      final syncStatus = ref.read(syncControllerProvider);
      if (syncStatus.serverUrl != null) {
        _serverUrlController.text = syncStatus.serverUrl!;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Found and connected to School Server!'
                : 'Could not find School Server on Wi-Fi. Check network or enter IP manually.',
          ),
          backgroundColor: success ? AppColors.success : AppColors.danger,
        ),
      );
      _loadDeviceData();
    }
  }

  Future<void> _handleManualConnect() async {
    final url = _serverUrlController.text.trim();
    if (url.isEmpty) return;

    final success = await ref
        .read(syncControllerProvider.notifier)
        .connectToServer(url);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Successfully connected to School Server!'
                : 'Failed to connect to School Server at $url',
          ),
          backgroundColor: success ? AppColors.success : AppColors.danger,
        ),
      );
      _loadDeviceData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final syncStatus = ref.watch(syncControllerProvider);
    final authState = ref.watch(authControllerProvider);
    final school = authState.currentSchool;
    final user = authState.currentUser;
    final isAdmin = user != null && UserRole.isPrincipalOrAdmin(user.role);

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('LAN Synchronization Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () {
              _loadDeviceData();
              ref.read(syncControllerProvider.notifier).syncNow();
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // 1. Device Identity Card
          _buildDeviceIdentityCard(),
          const SizedBox(height: 20),

          // 2. School Server Connection Card
          _buildServerConnectionCard(syncStatus),
          const SizedBox(height: 20),

          // 3. Sync Status & Quick Actions
          _buildSyncStatusCard(syncStatus),
          const SizedBox(height: 20),

          // 4. LAN Sync Conflicts
          if (school != null) ...[
            _buildConflictsCard(school.id),
            const SizedBox(height: 20),
          ],

          // 5. Admin Device Approval Section
          if (isAdmin) ...[
            _buildAdminDeviceManagementCard(),
            const SizedBox(height: 20),
          ],

          // 6. Sync Event Logs Viewer
          _buildSyncLogsCard(),
        ],
      ),
    );
  }

  Widget _buildConflictsCard(String schoolId) {
    final syncEngine = ref.watch(syncEngineProvider);
    final conflictCountStream = syncEngine.conflictManager
        .watchPendingConflictCount(schoolId);

    return StreamBuilder<int>(
      stream: conflictCountStream,
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        final hasConflicts = count > 0;

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: hasConflicts ? AppColors.warning : AppColors.border,
              width: hasConflicts ? 1.5 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      hasConflicts
                          ? Icons.warning_amber_rounded
                          : Icons.rule_folder_outlined,
                      color:
                          hasConflicts ? AppColors.warning : AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'LAN Sync Conflicts',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: (hasConflicts
                                ? AppColors.warning
                                : AppColors.success)
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color:
                              hasConflicts
                                  ? AppColors.warning
                                  : AppColors.success,
                        ),
                      ),
                      child: Text(
                        hasConflicts ? '$count CONFLICTS' : 'ALL CLEAN',
                        style: TextStyle(
                          color:
                              hasConflicts
                                  ? AppColors.warning
                                  : AppColors.success,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  hasConflicts
                      ? '$count data conflicts detected between LAN devices. Review and resolve to ensure school database consistency.'
                      : 'Automatic field-level merging is active. No pending data conflicts across LAN peers.',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.rule_folder_outlined, size: 18),
                    label: Text(
                      hasConflicts
                          ? 'Review & Resolve Conflicts ($count)'
                          : 'View Conflict History',
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SyncConflictsScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDeviceIdentityCard() {
    final statusColor =
        _currentDevice?.isApproved == true
            ? AppColors.success
            : _currentDevice?.isRevoked == true
            ? AppColors.danger
            : Colors.orange;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.devices, color: AppColors.primary),
                const SizedBox(width: 8),
                const Text(
                  'This Device Identity',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor),
                  ),
                  child: Text(
                    (_currentDevice?.status ?? 'Pending').toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildDetailRow(
              'Device Name',
              _currentDevice?.deviceName ?? 'Unknown',
            ),
            const SizedBox(height: 8),
            _buildDetailRow(
              'Device Type',
              _currentDevice?.deviceType ?? 'Desktop',
            ),
            const SizedBox(height: 8),
            _buildDetailRow('Device ID', _currentDevice?.deviceId ?? 'Not set'),
            if (_currentDevice?.pairingCode != null) ...[
              const SizedBox(height: 8),
              _buildDetailRow(
                'Pairing Code',
                _currentDevice!.pairingCode!,
                highlight: true,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildServerConnectionCard(SyncStatusInfo status) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.dns, color: AppColors.primary),
                const SizedBox(width: 8),
                const Text(
                  'School Sync Server (LAN)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Enter the School Server IP/URL or click Find Server to auto-discover over local Wi-Fi.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _serverUrlController,
              decoration: const InputDecoration(
                labelText: 'Server URL',
                hintText: 'http://192.168.1.100:8080 or http://localhost:8080',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.wifi),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isSearching ? null : _handleFindServer,
                    icon:
                        _isSearching
                            ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.search),
                    label: const Text('Find School Server'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _handleManualConnect,
                    icon: const Icon(Icons.link),
                    label: const Text('Connect'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncStatusCard(SyncStatusInfo status) {
    final timeStr =
        status.lastSyncTime != null
            ? DateFormat.yMd().add_jms().format(status.lastSyncTime!)
            : 'Never';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.sync_alt, color: AppColors.primary),
                const SizedBox(width: 8),
                const Text(
                  'Synchronization Status',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () {
                    ref.read(syncControllerProvider.notifier).syncNow();
                  },
                  icon: const Icon(Icons.sync, size: 16),
                  label: const Text('Sync Now'),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildDetailRow('Connectivity', status.displayLabel),
            const SizedBox(height: 8),
            _buildDetailRow(
              'Pending Local Changes',
              '${status.pendingCount} queued',
            ),
            const SizedBox(height: 8),
            _buildDetailRow('Last Successful Sync', timeStr),
            if (status.errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  status.errorMessage!,
                  style: const TextStyle(color: AppColors.danger, fontSize: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAdminDeviceManagementCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.admin_panel_settings,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Device Pairing & Access Control (Admin)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Approve or revoke peer devices connecting to this school on the LAN.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const Divider(height: 24),
            if (_schoolDevices.isEmpty)
              const Text('No other registered devices yet.')
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _schoolDevices.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final dev = _schoolDevices[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      dev.deviceType == 'mobile'
                          ? Icons.phone_android
                          : Icons.computer,
                      color: AppColors.primary,
                    ),
                    title: Text('${dev.deviceName} (${dev.status})'),
                    subtitle: Text(
                      'ID: ${dev.deviceId.substring(0, 8)}... | Code: ${dev.pairingCode ?? "None"}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!dev.isApproved)
                          TextButton(
                            onPressed: () async {
                              final devService = ref.read(
                                deviceServiceProvider,
                              );
                              await devService.updateDeviceStatus(
                                dev.deviceId,
                                DeviceStatus.approved,
                              );
                              _loadDeviceData();
                            },
                            child: const Text('Approve'),
                          ),
                        if (dev.isApproved && !dev.isCurrentDevice)
                          TextButton(
                            onPressed: () async {
                              final devService = ref.read(
                                deviceServiceProvider,
                              );
                              await devService.updateDeviceStatus(
                                dev.deviceId,
                                DeviceStatus.revoked,
                              );
                              _loadDeviceData();
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.danger,
                            ),
                            child: const Text('Revoke'),
                          ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncLogsCard() {
    final db = ref.read(appDatabaseProvider);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.history, color: AppColors.primary),
                const SizedBox(width: 8),
                const Text(
                  'Local Sync Event Queue & History',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 24),
            FutureBuilder<List<SyncEvent>>(
              future:
                  (db.select(db.syncEvents)
                        ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
                        ..limit(10))
                      .get(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final events = snapshot.data!;
                if (events.isEmpty) {
                  return const Text('No sync events recorded yet.');
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: events.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    final e = events[index];
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '${e.operation.toUpperCase()} ${e.entityType.toUpperCase()}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'ID: ${e.eventId.substring(0, 8)}... | Created: ${DateFormat.jm().format(e.createdAt)}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color:
                              e.status == SyncEventStatus.synced
                                  ? AppColors.successLight
                                  : Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          e.status.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color:
                                e.status == SyncEventStatus.synced
                                    ? AppColors.success
                                    : Colors.orange.shade800,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool highlight = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: highlight ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
