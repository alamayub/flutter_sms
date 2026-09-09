// lib/features/database_management/presentation/database_screen.dart
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../../core/database/database_service.dart';
import '../../../core/errors/app_error_handler.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../../school/data/demo_data_seeder.dart';
import '../services/backup_service.dart';
import '../services/database_health_checker.dart';

class DatabaseScreen extends ConsumerStatefulWidget {
  const DatabaseScreen({super.key});

  @override
  ConsumerState<DatabaseScreen> createState() => _DatabaseScreenState();
}

class _DatabaseScreenState extends ConsumerState<DatabaseScreen> {
  bool _isExporting = false;
  bool _isImporting = false;
  bool _isCheckingHealth = false;
  String? _lastExportPath;
  int _dbFileSize = 0;
  DateTime? _lastBackupTime;

  @override
  void initState() {
    super.initState();
    _loadDatabaseStats();
  }

  Future<void> _loadDatabaseStats() async {
    final backupService = ref.read(backupServiceProvider);
    final size = await backupService.getDatabaseFileSize();
    final lastTime = await backupService.getLastBackupTimestamp();
    if (mounted) {
      setState(() {
        _dbFileSize = size;
        _lastBackupTime = lastTime;
      });
    }
  }

  Future<void> _handleExport() async {
    setState(() => _isExporting = true);
    final user = ref.read(authControllerProvider).currentUser;
    final backupService = ref.read(backupServiceProvider);

    try {
      final sdbPayload = await backupService.exportBackup(
        currentUserId: user?.id,
      );
      final filename = await backupService.getSuggestedExportFilename();

      // Save file to documents directory or user-chosen path
      final dir = await getApplicationDocumentsDirectory();
      final targetFile = File(p.join(dir.path, filename));
      await targetFile.writeAsString(sdbPayload);

      setState(() {
        _lastExportPath = targetFile.path;
        _isExporting = false;
      });
      await _loadDatabaseStats();

      if (mounted) {
        showDialog(
          context: context,
          builder:
              (ctx) => AlertDialog(
                title: const Row(
                  children: [
                    Icon(Icons.check_circle, color: AppColors.success),
                    SizedBox(width: 8),
                    Text('Backup Exported Successfully'),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Your portable database backup has been generated with SHA-256 integrity checksum:',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SelectableText(
                        targetFile.path,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'You can transfer this .sdb file to any other device running the app to restore all records.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                actions: [
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('OK'),
                  ),
                ],
              ),
        );
      }
    } catch (e) {
      setState(() => _isExporting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppErrorHandler.toUserFriendlyMessage(e)),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _handleImport() async {
    setState(() => _isImporting = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['sdb', 'json'],
      );

      if (result == null || result.files.isEmpty) {
        setState(() => _isImporting = false);
        return;
      }

      String? content;
      final file = result.files.first;
      if (file.bytes != null) {
        content = utf8.decode(file.bytes!);
      } else if (file.path != null) {
        content = await File(file.path!).readAsString();
      }

      if (content == null || content.isEmpty) {
        throw Exception('Selected file is empty or could not be read.');
      }

      final backupService = ref.read(backupServiceProvider);
      final user = ref.read(authControllerProvider).currentUser;

      await backupService.importBackup(content, currentUserId: user?.id);
      await ref.read(authControllerProvider.notifier).checkStatus();
      await _loadDatabaseStats();

      setState(() => _isImporting = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Database restored successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        context.go('/dashboard');
      }
    } catch (e) {
      setState(() => _isImporting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppErrorHandler.toUserFriendlyMessage(e)),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _handleCheckHealth() async {
    setState(() => _isCheckingHealth = true);
    try {
      final checker = ref.read(databaseHealthCheckerProvider);
      final report = await checker.checkHealth();
      setState(() => _isCheckingHealth = false);

      if (!mounted) return;

      showDialog(
        context: context,
        builder:
            (ctx) => AlertDialog(
              title: Row(
                children: [
                  Icon(
                    report.isHealthy ? Icons.verified : Icons.warning_amber,
                    color:
                        report.isHealthy
                            ? AppColors.success
                            : AppColors.warning,
                  ),
                  const SizedBox(width: 8),
                  const Text('Database Health Report'),
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 500,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color:
                              report.isHealthy
                                  ? AppColors.success.withValues(alpha: 0.1)
                                  : AppColors.warning.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color:
                                report.isHealthy
                                    ? AppColors.success
                                    : AppColors.warning,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              report.isHealthy
                                  ? Icons.check_circle
                                  : Icons.error,
                              color:
                                  report.isHealthy
                                      ? AppColors.success
                                      : AppColors.warning,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                report.isHealthy
                                    ? 'Database is healthy. No integrity or foreign key violations detected.'
                                    : 'Integrity issues detected! Review below.',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color:
                                      report.isHealthy
                                          ? AppColors.success
                                          : AppColors.warning,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Diagnostic Checks:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '• SQLite PRAGMA Integrity: ${report.integrityCheckResult}',
                      ),
                      Text(
                        '• Foreign Key Violations: ${report.foreignKeyViolations.length}',
                      ),
                      Text(
                        '• Logical Integrity Issues: ${report.logicalIntegrityIssues.length}',
                      ),
                      if (report.allIssues.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        const Text(
                          'Detected Issues:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.danger,
                          ),
                        ),
                        const SizedBox(height: 4),
                        ...report.allIssues.map(
                          (issue) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              '⚠ $issue',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.danger,
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      const Text(
                        'Table Row Counts:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children:
                            report.tableCounts.entries.map((e) {
                              return Chip(
                                label: Text('${e.key}: ${e.value}'),
                                backgroundColor: AppColors.surfaceVariant,
                              );
                            }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close'),
                ),
              ],
            ),
      );
    } catch (e) {
      setState(() => _isCheckingHealth = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppErrorHandler.toUserFriendlyMessage(e)),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _handleResetDatabase() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.warning, color: AppColors.danger),
                SizedBox(width: 8),
                Text('Reset Database?'),
              ],
            ),
            content: Text(
              kDebugMode
                  ? 'This will permanently delete all local school data, classes, students, and attendance records on this device.\n\nMake sure you have exported a backup first if you need this data.'
                  : 'DANGER: This action is permanent and destroys all local records! Please confirm that you want to wipe the device database.',
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.danger,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Yes, Wipe Database'),
              ),
            ],
          ),
    );

    if (confirm != true) return;

    final db = ref.read(appDatabaseProvider);
    await DatabaseHelper.clearAllData(db);
    await ref.read(authControllerProvider.notifier).checkStatus();

    if (mounted) {
      context.go('/welcome');
    }
  }

  Future<void> _handleSeedDemo() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Seed Demo Data?'),
            content: const Text(
              'This will wipe current data and populate ABC Secondary School with 5 grades, 150 students, teachers, timetable, and attendance.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Seed Demo Data'),
              ),
            ],
          ),
    );

    if (confirm != true) return;

    final db = ref.read(appDatabaseProvider);
    final seeder = DemoDataSeeder(db);
    await seeder.seedDemoData();
    await ref.read(authControllerProvider.notifier).checkStatus();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Demo data seeded successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
      context.go('/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Database Management & Backups')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status & Info Card
              Card(
                color: AppColors.surface,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.storage,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    ref
                                            .watch(authControllerProvider)
                                            .currentSchool
                                            ?.name ??
                                        'School Database',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'Local SQLite Database Architecture (Offline-First)',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.secondary,
                            ),
                            onPressed:
                                _isCheckingHealth ? null : _handleCheckHealth,
                            icon:
                                _isCheckingHealth
                                    ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                    : const Icon(
                                      Icons.health_and_safety,
                                      size: 18,
                                    ),
                            label: const Text('Check Database Health'),
                          ),
                        ],
                      ),
                      const Divider(height: 32),
                      Row(
                        children: [
                          Expanded(
                            child: _buildInfoItem(
                              icon: Icons.schema_outlined,
                              label: 'Schema Version',
                              value: 'v2 (Wal Mode)',
                            ),
                          ),
                          Expanded(
                            child: _buildInfoItem(
                              icon: Icons.data_usage,
                              label: 'Database Size',
                              value:
                                  _dbFileSize > 0
                                      ? '${(_dbFileSize / 1024).toStringAsFixed(1)} KB'
                                      : 'Calculating...',
                            ),
                          ),
                          Expanded(
                            child: _buildInfoItem(
                              icon: Icons.backup_outlined,
                              label: 'Last Backup',
                              value:
                                  _lastBackupTime != null
                                      ? _lastBackupTime!
                                          .toLocal()
                                          .toString()
                                          .split('.')
                                          .first
                                      : 'Never',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Export Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.file_download_outlined,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Export Portable Backup (.sdb)',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Packages your entire local database into a versioned, checksummed backup file.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_lastExportPath != null) ...[
                        Text(
                          'Last exported to: $_lastExportPath',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.success,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      ElevatedButton.icon(
                        onPressed: _isExporting ? null : _handleExport,
                        icon:
                            _isExporting
                                ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                                : const Icon(Icons.download, size: 18),
                        label: const Text('Export Backup Now'),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Import Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.secondaryLight,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.file_upload_outlined,
                              color: AppColors.secondary,
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Import Existing Backup (.sdb)',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Restores data from a portable backup with automatic validation and zero data-loss rollback safety.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: _isImporting ? null : _handleImport,
                        icon:
                            _isImporting
                                ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primary,
                                  ),
                                )
                                : const Icon(Icons.upload_file, size: 18),
                        label: const Text('Select & Restore .sdb File'),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Danger Zone Card
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: AppColors.danger.withValues(alpha: 0.3),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.warning_amber,
                            color: AppColors.danger,
                            size: 22,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Administrative Reset & Seed Tools',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.danger,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Use these options during testing or device decommissioning.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.danger,
                            ),
                            onPressed: _handleResetDatabase,
                            icon: const Icon(Icons.delete_forever, size: 18),
                            label: const Text('Clear All Local Database Data'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _handleSeedDemo,
                            icon: const Icon(Icons.auto_fix_high, size: 18),
                            label: const Text(
                              'Reset & Load Demo Data (ABC Secondary)',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
            Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }
}
