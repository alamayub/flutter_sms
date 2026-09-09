// lib/features/sync/presentation/sync_conflicts_screen.dart
import 'dart:convert';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import 'sync_controller.dart';

class SyncConflictsScreen extends ConsumerStatefulWidget {
  const SyncConflictsScreen({super.key});

  @override
  ConsumerState<SyncConflictsScreen> createState() =>
      _SyncConflictsScreenState();
}

class _SyncConflictsScreenState extends ConsumerState<SyncConflictsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final school = authState.currentSchool;
    final db = ref.watch(appDatabaseProvider);

    if (school == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Sync Conflicts')),
        body: const Center(child: Text('No school selected.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('LAN Sync Conflicts'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(icon: Icon(Icons.warning_amber_rounded), text: 'Unresolved'),
            Tab(
              icon: Icon(Icons.check_circle_outline),
              text: 'Resolved History',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ConflictList(db: db, schoolId: school.id, resolved: false),
          _ConflictList(db: db, schoolId: school.id, resolved: true),
        ],
      ),
    );
  }
}

class _ConflictList extends ConsumerWidget {
  final AppDatabase db;
  final String schoolId;
  final bool resolved;

  const _ConflictList({
    required this.db,
    required this.schoolId,
    required this.resolved,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query =
        db.select(db.syncConflicts)
          ..where(
            (t) =>
                t.schoolId.equals(schoolId) &
                (resolved ? t.resolvedAt.isNotNull() : t.resolvedAt.isNull()),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.detectedAt)]);

    return StreamBuilder<List<SyncConflict>>(
      stream: query.watch(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final conflicts = snapshot.data ?? [];
        if (conflicts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  resolved
                      ? Icons.history_toggle_off_rounded
                      : Icons.check_circle_outline_rounded,
                  size: 64,
                  color: resolved ? AppColors.textSecondary : AppColors.success,
                ),
                const SizedBox(height: 16),
                Text(
                  resolved
                      ? 'No conflict history recorded'
                      : 'Zero conflicts! All data in sync.',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  resolved
                      ? 'Past resolutions will appear here.'
                      : 'Concurrent LAN edits are cleanly synchronized.',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: conflicts.length,
          itemBuilder: (context, index) {
            return _ConflictCard(conflict: conflicts[index]);
          },
        );
      },
    );
  }
}

class _ConflictCard extends ConsumerWidget {
  final SyncConflict conflict;

  const _ConflictCard({required this.conflict});

  Map<String, dynamic> _parseJson(String str) {
    try {
      return jsonDecode(str) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localPayload = _parseJson(conflict.localPayload);
    final remotePayload = _parseJson(conflict.remotePayload);
    final meta = _parseJson(conflict.resolutionNote ?? '{}');

    final conflictingFields =
        (meta['conflictingFields'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        _findDiffFields(localPayload, remotePayload);

    final isResolved = conflict.resolvedAt != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color:
              isResolved
                  ? AppColors.border
                  : AppColors.warning.withValues(alpha: 0.6),
          width: isResolved ? 1 : 1.5,
        ),
      ),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row: Entity Type, Entity ID, and Status
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    conflict.entityType.toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'ID: ${conflict.entityId}',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color:
                        isResolved
                            ? AppColors.success.withValues(alpha: 0.1)
                            : AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isResolved ? AppColors.success : AppColors.warning,
                    ),
                  ),
                  child: Text(
                    isResolved ? 'RESOLVED' : 'UNRESOLVED',
                    style: TextStyle(
                      color: isResolved ? AppColors.success : AppColors.warning,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Detected: ${DateFormat.yMMMd().add_jms().format(conflict.detectedAt)}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            if (isResolved && conflict.resolvedAt != null) ...[
              const SizedBox(height: 4),
              Text(
                'Resolution: ${meta['resolution'] ?? 'manual'} at ${DateFormat.yMMMd().add_jms().format(conflict.resolvedAt!)}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.success,
                ),
              ),
            ],
            const Divider(height: 24),

            // Conflicting fields comparison
            const Text(
              'Field Differences:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 8),
            if (conflictingFields.isEmpty)
              const Text(
                'No specific field collision identified; check raw payloads.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              )
            else
              ...conflictingFields.map((field) {
                final localVal = localPayload[field]?.toString() ?? '<null>';
                final remoteVal = remotePayload[field]?.toString() ?? '<null>';
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        field,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Local',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                    ),
                                  ),
                                  Text(
                                    localVal,
                                    style: const TextStyle(fontSize: 12),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Remote',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange,
                                    ),
                                  ),
                                  Text(
                                    remoteVal,
                                    style: const TextStyle(fontSize: 12),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),

            // Action buttons if unresolved
            if (!isResolved) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.phone_android, size: 16),
                    label: const Text('Keep Local'),
                    onPressed: () => _handleKeepLocal(context, ref),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.lan, size: 16),
                    label: const Text('Keep Remote'),
                    onPressed: () => _handleKeepRemote(context, ref),
                  ),
                  FilledButton.icon(
                    icon: const Icon(Icons.call_merge, size: 16),
                    label: const Text('Merge Fields'),
                    onPressed:
                        () => _handleMerge(
                          context,
                          ref,
                          conflictingFields,
                          localPayload,
                          remotePayload,
                        ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<String> _findDiffFields(
    Map<String, dynamic> local,
    Map<String, dynamic> remote,
  ) {
    final diffs = <String>[];
    for (final k in local.keys) {
      if (k == 'updatedAt' || k == 'createdAt') continue;
      if (remote.containsKey(k) && local[k] != remote[k]) {
        diffs.add(k);
      }
    }
    return diffs;
  }

  Future<void> _handleKeepLocal(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Keep Local Version?'),
            content: const Text(
              'This will retain the local edits on this device and re-broadcast them to update the LAN server and other devices.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Confirm Keep Local'),
              ),
            ],
          ),
    );

    if (confirm != true) return;

    final authState = ref.read(authControllerProvider);
    final userId = authState.currentUser?.id ?? 'admin';
    final syncEngine = ref.read(syncEngineProvider);

    await syncEngine.resolveConflictWithAction(
      conflictId: conflict.id,
      resolvedByUserId: userId,
      resolution: 'keep_local',
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Resolved: Local version retained.'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _handleKeepRemote(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Keep Remote Version?'),
            content: const Text(
              'This will overwrite local edits with the remote server version.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Confirm Keep Remote'),
              ),
            ],
          ),
    );

    if (confirm != true) return;

    final authState = ref.read(authControllerProvider);
    final userId = authState.currentUser?.id ?? 'admin';
    final syncEngine = ref.read(syncEngineProvider);

    await syncEngine.resolveConflictWithAction(
      conflictId: conflict.id,
      resolvedByUserId: userId,
      resolution: 'keep_remote',
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Resolved: Remote version applied.'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _handleMerge(
    BuildContext context,
    WidgetRef ref,
    List<String> conflictingFields,
    Map<String, dynamic> localPayload,
    Map<String, dynamic> remotePayload,
  ) async {
    final fieldChoices = <String, String>{};
    for (final f in conflictingFields) {
      fieldChoices[f] = 'local';
    }

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Field-by-Field Merge',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Choose whether each field should take the Local or Remote value:',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const Divider(height: 24),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children:
                          conflictingFields.map((field) {
                            final localVal =
                                localPayload[field]?.toString() ?? '<null>';
                            final remoteVal =
                                remotePayload[field]?.toString() ?? '<null>';
                            final choice = fieldChoices[field] ?? 'local';

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border.all(color: AppColors.border),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    field,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  RadioListTile<String>(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    title: Text('Local: $localVal'),
                                    value: 'local',
                                    groupValue: choice,
                                    onChanged: (val) {
                                      if (val != null) {
                                        setModalState(() {
                                          fieldChoices[field] = val;
                                        });
                                      }
                                    },
                                  ),
                                  RadioListTile<String>(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    title: Text('Remote: $remoteVal'),
                                    value: 'remote',
                                    groupValue: choice,
                                    onChanged: (val) {
                                      if (val != null) {
                                        setModalState(() {
                                          fieldChoices[field] = val;
                                        });
                                      }
                                    },
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        final merged = Map<String, dynamic>.from(remotePayload);
                        for (final f in conflictingFields) {
                          if (fieldChoices[f] == 'local') {
                            merged[f] = localPayload[f];
                          } else {
                            merged[f] = remotePayload[f];
                          }
                        }
                        Navigator.pop(ctx, merged);
                      },
                      child: const Text('Apply Merged Version'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (result == null) return;

    final authState = ref.read(authControllerProvider);
    final userId = authState.currentUser?.id ?? 'admin';
    final syncEngine = ref.read(syncEngineProvider);

    await syncEngine.resolveConflictWithAction(
      conflictId: conflict.id,
      resolvedByUserId: userId,
      resolution: 'merged',
      customMergedPayload: result,
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Resolved: Merged version applied and synced.'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }
}
