import 'dart:io' show File;

import 'package:path/path.dart' as p;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/database_backup_service.dart';
import '../../widgets/ui/app_badge.dart';

class ImportDBScreen extends ConsumerWidget {
  const ImportDBScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String formatFileSize(int bytes) {
      if (bytes < 1024) return '$bytes B';
      if (bytes < 1024 * 1024) {
        return '${(bytes / 1024).toStringAsFixed(1)} KB';
      }
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }

    void showImportDatabaseDialog() {
      String? selectedPath;
      String? selectedFileName;
      int? selectedFileSize;
      String? dialogError;
      bool isRestoring = false;

      showDialog(
        context: context,
        builder:
            (ctx) => StatefulBuilder(
              builder: (context, setDialogState) {
                final theme = Theme.of(context);

                Future<void> pickDbFile() async {
                  try {
                    final fileResult = await FilePicker.pickFile(
                      type: FileType.custom,
                      allowedExtensions: [
                        'zip',
                        'smsbackup',
                        'db',
                        'sqlite',
                        'sqlite3',
                      ],
                      dialogTitle:
                          'Select Backup Archive (.zip) or Database (.db)',
                    );

                    if (fileResult != null && fileResult.path != null) {
                      final pickedPath = fileResult.path!;
                      final file = File(pickedPath);
                      final size = await file.length();
                      setDialogState(() {
                        selectedPath = pickedPath;
                        selectedFileName = p.basename(pickedPath);
                        selectedFileSize = size;
                        dialogError = null;
                      });
                    }
                  } catch (e) {
                    setDialogState(
                      () => dialogError = 'Error selecting file: $e',
                    );
                  }
                }

                final isSelectedZip =
                    selectedFileName != null &&
                    (selectedFileName!.endsWith('.zip') ||
                        selectedFileName!.endsWith('.smsbackup'));

                return AlertDialog(
                  title: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withAlpha(25),
                          borderRadius: AppRadius.roundedMd,
                        ),
                        child: Icon(
                          Icons.settings_backup_restore_rounded,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(child: Text('Restore Backup & Data')),
                    ],
                  ),
                  content: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select a full backup archive (.zip) containing database and photos, or a standalone database (.db) file:',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Interactive File Selection Card
                        if (selectedPath == null)
                          InkWell(
                            onTap: isRestoring ? null : pickDbFile,
                            borderRadius: AppRadius.roundedMd,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                vertical: 24,
                                horizontal: 16,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withAlpha(12),
                                borderRadius: AppRadius.roundedMd,
                                border: Border.all(
                                  color: theme.colorScheme.primary.withAlpha(
                                    90,
                                  ),
                                  width: 1.5,
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary
                                          .withAlpha(25),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.file_open_rounded,
                                      size: 32,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Select Backup Package (.zip / .db)',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Click to browse for full backup (.zip with photos) or .db file',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withAlpha(15),
                              borderRadius: AppRadius.roundedMd,
                              border: Border.all(
                                color: theme.colorScheme.primary.withAlpha(100),
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary.withAlpha(
                                      30,
                                    ),
                                    borderRadius: AppRadius.roundedSm,
                                  ),
                                  child: Icon(
                                    isSelectedZip
                                        ? Icons.archive_outlined
                                        : Icons.storage_rounded,
                                    size: 24,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              selectedFileName ?? 'Backup File',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 13,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          AppBadge.primary(
                                            isSelectedZip
                                                ? 'Full Package'
                                                : 'DB Only',
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        selectedFileSize != null
                                            ? '${formatFileSize(selectedFileSize!)} • $selectedPath'
                                            : selectedPath!,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color:
                                              theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  icon: const Icon(
                                    Icons.swap_horiz_rounded,
                                    size: 14,
                                  ),
                                  label: const Text(
                                    'Change',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                  onPressed: isRestoring ? null : pickDbFile,
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        const SizedBox(height: 12),
                        FutureBuilder<List<DatabaseBackupInfo>>(
                          future: DatabaseBackupService.listRecentBackups(),
                          builder: (context, snapshot) {
                            final backups = snapshot.data ?? [];
                            if (backups.isEmpty) return const SizedBox.shrink();

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  'Or choose from recent backups folder:',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  constraints: const BoxConstraints(
                                    maxHeight: 120,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: theme.colorScheme.outlineVariant
                                          .withAlpha(80),
                                    ),
                                    borderRadius: AppRadius.roundedMd,
                                  ),
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: backups.length,
                                    itemBuilder: (context, idx) {
                                      final b = backups[idx];
                                      final isThisSelected =
                                          selectedPath == b.filePath;
                                      return ListTile(
                                        dense: true,
                                        selected: isThisSelected,
                                        selectedTileColor: theme
                                            .colorScheme
                                            .primary
                                            .withAlpha(20),
                                        leading: Icon(
                                          isThisSelected
                                              ? Icons.check_circle_rounded
                                              : (b.isFullBackup
                                                  ? Icons.archive_outlined
                                                  : Icons.storage_outlined),
                                          size: 18,
                                          color:
                                              isThisSelected
                                                  ? theme.colorScheme.primary
                                                  : null,
                                        ),
                                        title: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                b.fileName,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight:
                                                      isThisSelected
                                                          ? FontWeight.bold
                                                          : FontWeight.normal,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            AppBadge.neutral(
                                              b.isFullBackup ? 'FULL' : 'DB',
                                            ),
                                          ],
                                        ),
                                        subtitle: Text(
                                          '${b.formattedSize} • ${b.formattedDate}',
                                          style: const TextStyle(fontSize: 10),
                                        ),
                                        onTap: () {
                                          setDialogState(() {
                                            selectedPath = b.filePath;
                                            selectedFileName = b.fileName;
                                            selectedFileSize = b.fileSizeBytes;
                                            dialogError = null;
                                          });
                                        },
                                      );
                                    },
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        if (dialogError != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.error.withAlpha(20),
                              borderRadius: AppRadius.roundedSm,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.error_outline_rounded,
                                  size: 16,
                                  color: theme.colorScheme.error,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    dialogError!,
                                    style: TextStyle(
                                      color: theme.colorScheme.error,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton.icon(
                      icon:
                          isRestoring
                              ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                              : const Icon(Icons.download_rounded, size: 16),
                      label: const Text('Restore Database'),
                      onPressed:
                          (isRestoring || selectedPath == null)
                              ? null
                              : () async {
                                setDialogState(() {
                                  isRestoring = true;
                                  dialogError = null;
                                });

                                final result = await ref
                                    .read(authStateProvider.notifier)
                                    .importDatabaseAndRestore(selectedPath!);

                                setDialogState(() => isRestoring = false);

                                if (result.success && ctx.mounted) {
                                  Navigator.of(ctx).pop();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Database restored successfully! Logged in.',
                                      ),
                                      backgroundColor: Color(0xFF10B981),
                                    ),
                                  );
                                } else {
                                  setDialogState(
                                    () => dialogError = result.message,
                                  );
                                }
                              },
                    ),
                  ],
                );
              },
            ),
      );
    }

    return OutlinedButton.icon(
      icon: const Icon(Icons.settings_backup_restore_rounded, size: 16),
      label: const Text('Restore / Import Database (.db)'),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 44),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.roundedMd),
      ),
      onPressed: showImportDatabaseDialog,
    );
  }
}
