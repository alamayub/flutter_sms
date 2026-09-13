import 'dart:io';
import '../../config/extensions.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:path/path.dart' as p;
import '../../config/theme.dart';
import '../../models/school_profile.dart';
import '../../providers/auth_provider.dart';
import '../../providers/school_profile_provider.dart';
import '../../services/app_media_service.dart';
import '../../services/database_backup_service.dart';
import '../../widgets/ui/app_badge.dart';
import '../../widgets/ui/app_card.dart';
import '../../widgets/ui/app_page_header.dart';

class SchoolProfileScreen extends ConsumerStatefulWidget {
  const SchoolProfileScreen({super.key});

  @override
  ConsumerState<SchoolProfileScreen> createState() =>
      _SchoolProfileScreenState();
}

class _SchoolProfileScreenState extends ConsumerState<SchoolProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameCtrl;
  late TextEditingController _codeCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _websiteCtrl;
  late TextEditingController _principalCtrl;
  late TextEditingController _establishedCtrl;
  late TextEditingController _taglineCtrl;
  late TextEditingController _idCardFooterCtrl;
  late TextEditingController _adminUsernameCtrl;
  late TextEditingController _newPasswordCtrl;
  late TextEditingController _newPinCtrl;

  String? _logoPath;
  bool _isSaving = false;
  DatabaseBackupInfo? _latestExport;
  List<DatabaseBackupInfo> _recentBackups = [];

  @override
  void initState() {
    super.initState();
    final profile = ref.read(schoolProfileProvider);

    _nameCtrl = TextEditingController(text: profile.name);
    _codeCtrl = TextEditingController(text: profile.code);
    _addressCtrl = TextEditingController(text: profile.address);
    _phoneCtrl = TextEditingController(text: profile.phone);
    _emailCtrl = TextEditingController(text: profile.email);
    _websiteCtrl = TextEditingController(text: profile.website);
    _principalCtrl = TextEditingController(text: profile.principalName);
    _establishedCtrl = TextEditingController(text: profile.establishedYear);
    _taglineCtrl = TextEditingController(text: profile.tagline);
    _idCardFooterCtrl = TextEditingController(text: profile.idCardFooter);
    _adminUsernameCtrl = TextEditingController(text: profile.adminUsername);
    _newPasswordCtrl = TextEditingController();
    _newPinCtrl = TextEditingController();
    _logoPath = profile.logoPath;

    _loadRecentBackups();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _websiteCtrl.dispose();
    _principalCtrl.dispose();
    _establishedCtrl.dispose();
    _taglineCtrl.dispose();
    _idCardFooterCtrl.dispose();
    _adminUsernameCtrl.dispose();
    _newPasswordCtrl.dispose();
    _newPinCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRecentBackups() async {
    final list = await DatabaseBackupService.listRecentBackups();
    if (mounted) {
      setState(() => _recentBackups = list);
    }
  }

  Future<void> _pickLogo() async {
    try {
      final savedPath = await AppMediaService.pickAndSaveLogo();
      if (savedPath != null && mounted) {
        setState(() => _logoPath = savedPath);
      }
    } catch (e) {
      if (mounted) {
        context.showSnackbar(
          SnackBar(content: Text('Could not pick image: $e')),
        );
      }
    }
  }

  void _removeLogo() {
    setState(() => _logoPath = null);
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final current = ref.read(schoolProfileProvider);

    String passwordHash = current.adminPasswordHash;
    if (_newPasswordCtrl.text.trim().isNotEmpty) {
      passwordHash = SchoolProfile.hashPassword(_newPasswordCtrl.text.trim());
      final newPass = _newPasswordCtrl.text.trim();
      if (newPass.length < 4) {
        context.showSnackbar(
          const SnackBar(
            content: Text('Password must be at least 4 characters'),
          ),
        );
        return;
      }
      passwordHash = SchoolProfile.hashPassword(newPass);
    }

    String pinHash = current.adminPinHash;
    if (_newPinCtrl.text.trim().isNotEmpty) {
      final newPin = _newPinCtrl.text.trim();
      if (newPin.length != 4 || !RegExp(r'^\d{4}$').hasMatch(newPin)) {
        context.showSnackbar(
          const SnackBar(
            content: Text(
              '4-Digit Security PIN must be exactly 4 numeric digits',
            ),
          ),
        );
        return;
      }
      pinHash = SchoolProfile.hashPassword(newPin);
    }

    setState(() => _isSaving = true);

    final updated = current.copyWith(
      name: _nameCtrl.text.trim(),
      code: _codeCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      website: _websiteCtrl.text.trim(),
      principalName: _principalCtrl.text.trim(),
      establishedYear: _establishedCtrl.text.trim(),
      tagline: _taglineCtrl.text.trim(),
      idCardFooter: _idCardFooterCtrl.text.trim(),
      adminUsername: _adminUsernameCtrl.text.trim(),
      adminPasswordHash: passwordHash,
      adminPinHash: pinHash,
      logoPath: _logoPath,
    );

    await ref.read(schoolProfileProvider.notifier).updateProfile(updated);

    if (mounted) {
      setState(() {
        _isSaving = false;
        _newPasswordCtrl.clear();
        _newPinCtrl.clear();
      });
      context.showSnackbar(
        const SnackBar(
          content: Text('School profile updated successfully!'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    }
  }

  Future<void> _exportDatabase() async {
    final school = ref.read(schoolProfileProvider);
    final result = await DatabaseBackupService.exportDatabase(
      schoolName: school.name,
    );

    if (result.success && mounted) {
      setState(() {
        _latestExport = result.backupInfo;
      });
      _loadRecentBackups();
      context.showSnackbar(
        SnackBar(
          content: Text('${result.message} (${result.backupInfo?.fileName})'),
          backgroundColor: const Color(0xFF10B981),
          action: SnackBarAction(
            label: 'Copy Path',
            textColor: Colors.white,
            onPressed: () {
              if (result.backupInfo != null) {
                Clipboard.setData(
                  ClipboardData(text: result.backupInfo!.filePath),
                );
              }
            },
          ),
        ),
      );
    } else if (mounted) {
      context.showSnackbar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  void _showImportModal() {
    String? selectedPath;
    String? selectedFileName;
    int? selectedFileSize;
    String? dialogError;
    bool isImporting = false;

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
                        color: const Color(0xFFEF4444).withAlpha(25),
                        borderRadius: AppRadius.roundedMd,
                      ),
                      child: const Icon(
                        Icons.warning_amber_rounded,
                        color: Color(0xFFEF4444),
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
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withAlpha(25),
                          borderRadius: AppRadius.roundedMd,
                          border: Border.all(
                            color: const Color(0xFFF59E0B).withAlpha(80),
                          ),
                        ),
                        child: const Text(
                          'Warning: Restoring will overwrite the current live database and restore media. A safety backup of your existing data will be saved automatically.',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Interactive File Selection Card
                      if (selectedPath == null)
                        InkWell(
                          onTap: isImporting ? null : pickDbFile,
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
                                color: theme.colorScheme.primary.withAlpha(90),
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary.withAlpha(
                                      25,
                                    ),
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                          ? '${_formatFileSize(selectedFileSize!)} • $selectedPath'
                                          : selectedPath!,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
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
                                onPressed: isImporting ? null : pickDbFile,
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

                      if (_recentBackups.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        const Text(
                          'Or choose from recent backups folder:',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          constraints: const BoxConstraints(maxHeight: 110),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: theme.colorScheme.outlineVariant.withAlpha(
                                80,
                              ),
                            ),
                            borderRadius: AppRadius.roundedMd,
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: _recentBackups.length,
                            itemBuilder: (context, idx) {
                              final b = _recentBackups[idx];
                              final isThisSelected = selectedPath == b.filePath;
                              return ListTile(
                                dense: true,
                                selected: isThisSelected,
                                selectedTileColor: theme.colorScheme.primary
                                    .withAlpha(20),
                                leading: Icon(
                                  isThisSelected
                                      ? Icons.check_circle_rounded
                                      : (b.isFullBackup
                                          ? Icons.archive_outlined
                                          : Icons.storage_rounded),
                                  size: 16,
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
                                          fontSize: 11.5,
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
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      foregroundColor: Colors.white,
                    ),
                    icon:
                        isImporting
                            ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                            : const Icon(Icons.restore_page_rounded, size: 16),
                    label: const Text('Confirm & Restore'),
                    onPressed:
                        (isImporting || selectedPath == null)
                            ? null
                            : () async {
                              setDialogState(() {
                                isImporting = true;
                                dialogError = null;
                              });

                              final result = await ref
                                  .read(authStateProvider.notifier)
                                  .importDatabaseAndRestore(selectedPath!);

                              setDialogState(() => isImporting = false);

                              if (result.success && ctx.mounted) {
                                Navigator.of(ctx).pop();
                                _loadRecentBackups();
                                context.showSnackbar(
                                  const SnackBar(
                                    content: Text(
                                      'Database successfully restored!',
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final school = ref.watch(schoolProfileProvider);

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Standardized Page Header
            AppPageHeader(
              title: 'School Profile & Settings',
              subtitle:
                  'Update institution identity, administrative credentials, and manage SQLite database backups',
              badge: const AppBadge.primary(
                'Institution Profile',
                size: AppBadgeSize.sm,
              ),
              actions: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.download_rounded, size: 16),
                  label: const Text('Export Database'),
                  onPressed: _exportDatabase,
                ),
                ElevatedButton.icon(
                  icon:
                      _isSaving
                          ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                          : const Icon(Icons.save_rounded, size: 16),
                  label: const Text('Save Profile'),
                  onPressed: _isSaving ? null : _saveProfile,
                ),
              ],
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // 1. Hero School Identity Banner
                    AppCard(
                      isHoverable: false,
                      accentColor: theme.colorScheme.primary,
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          // Logo / Crest Avatar with Upload & Remove Actions
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Stack(
                                children: [
                                  Container(
                                    width: 84,
                                    height: 84,
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary
                                          .withAlpha(25),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: theme.colorScheme.primary
                                            .withAlpha(80),
                                        width: 2,
                                      ),
                                    ),
                                    child: ClipOval(
                                      child:
                                          _logoPath != null &&
                                                  File(_logoPath!).existsSync()
                                              ? Image.file(
                                                File(_logoPath!),
                                                fit: BoxFit.cover,
                                              )
                                              : Center(
                                                child: Icon(
                                                  Icons.school_rounded,
                                                  size: 44,
                                                  color:
                                                      theme.colorScheme.primary,
                                                ),
                                              ),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: InkWell(
                                      onTap: _pickLogo,
                                      borderRadius: BorderRadius.circular(20),
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.primary,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withAlpha(40),
                                              blurRadius: 4,
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          Icons.camera_alt_rounded,
                                          size: 14,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  InkWell(
                                    onTap: _pickLogo,
                                    child: Text(
                                      _logoPath == null ? 'Upload' : 'Change',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                  if (_logoPath != null) ...[
                                    const SizedBox(width: 8),
                                    InkWell(
                                      onTap: _removeLogo,
                                      child: Text(
                                        'Remove',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: theme.colorScheme.error,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(width: 20),

                          // School Title & Quick Badges
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        school.name,
                                        style: theme.textTheme.headlineSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const AppBadge.success(
                                      'Verified Institution',
                                      size: AppBadgeSize.sm,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  school.tagline.isNotEmpty
                                      ? school.tagline
                                      : 'SMS Educational Platform',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: [
                                    if (school.code.isNotEmpty)
                                      AppBadge.neutral(
                                        'Code: ${school.code}',
                                        size: AppBadgeSize.sm,
                                      ),
                                    if (school.establishedYear.isNotEmpty)
                                      AppBadge.neutral(
                                        'Est: ${school.establishedYear}',
                                        size: AppBadgeSize.sm,
                                      ),
                                    if (school.principalName.isNotEmpty)
                                      AppBadge.neutral(
                                        'Principal: ${school.principalName}',
                                        size: AppBadgeSize.sm,
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 2. Main Edit Sections (2 Columns on Desktop)
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isDesktop = constraints.maxWidth >= 900;

                        final leftCol = Column(
                          children: [
                            // General Institutional Profile
                            _buildSectionCard(
                              theme,
                              title: 'Institutional Profile',
                              icon: Icons.account_balance_outlined,
                              children: [
                                TextFormField(
                                  controller: _nameCtrl,
                                  decoration: InputDecoration(
                                    labelText: 'School / College Name *',
                                    border: OutlineInputBorder(
                                      borderRadius: AppRadius.roundedMd,
                                    ),
                                  ),
                                  validator:
                                      (val) =>
                                          val == null || val.trim().isEmpty
                                              ? 'Name required'
                                              : null,
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: _codeCtrl,
                                        decoration: InputDecoration(
                                          labelText: 'EMIS / EIMS Code *',
                                          hintText: 'e.g. EMIS-2081-001',
                                          prefixIcon: const Icon(
                                            Icons.tag_rounded,
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius: AppRadius.roundedMd,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _establishedCtrl,
                                        decoration: InputDecoration(
                                          labelText: 'Year of Establishment *',
                                          hintText: 'e.g. 2052 BS (1995 AD)',
                                          prefixIcon: const Icon(
                                            Icons.calendar_today_outlined,
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius: AppRadius.roundedMd,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _principalCtrl,
                                  decoration: InputDecoration(
                                    labelText: 'Principal / Headmaster Name',
                                    hintText: 'e.g. Dr. Ramesh Sharma',
                                    prefixIcon: const Icon(
                                      Icons.person_pin_outlined,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: AppRadius.roundedMd,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _taglineCtrl,
                                  decoration: InputDecoration(
                                    labelText: 'Motto / Tagline',
                                    border: OutlineInputBorder(
                                      borderRadius: AppRadius.roundedMd,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Contact & Location Details
                            _buildSectionCard(
                              theme,
                              title: 'Contact & Location Details',
                              icon: Icons.contact_mail_outlined,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: _phoneCtrl,
                                        decoration: InputDecoration(
                                          labelText: 'Primary Phone Number',
                                          border: OutlineInputBorder(
                                            borderRadius: AppRadius.roundedMd,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _emailCtrl,
                                        decoration: InputDecoration(
                                          labelText: 'Official Email',
                                          border: OutlineInputBorder(
                                            borderRadius: AppRadius.roundedMd,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _websiteCtrl,
                                  decoration: InputDecoration(
                                    labelText: 'Website URL',
                                    border: OutlineInputBorder(
                                      borderRadius: AppRadius.roundedMd,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _addressCtrl,
                                  decoration: InputDecoration(
                                    labelText:
                                        'Physical Address (Street, City, District)',
                                    border: OutlineInputBorder(
                                      borderRadius: AppRadius.roundedMd,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // ID Card & Reports Customization
                            _buildSectionCard(
                              theme,
                              title: 'ID Card & Report Customization',
                              icon: Icons.badge_outlined,
                              children: [
                                TextFormField(
                                  controller: _idCardFooterCtrl,
                                  maxLines: 2,
                                  decoration: InputDecoration(
                                    labelText:
                                        'ID Card Footer Disclaimer / Validity Note',
                                    border: OutlineInputBorder(
                                      borderRadius: AppRadius.roundedMd,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );

                        final rightCol = Column(
                          children: [
                            // Admin Security & Credentials
                            _buildSectionCard(
                              theme,
                              title: 'Admin Access & Security',
                              icon: Icons.lock_outline_rounded,
                              children: [
                                TextFormField(
                                  controller: _adminUsernameCtrl,
                                  decoration: InputDecoration(
                                    labelText: 'Administrator Username',
                                    prefixIcon: const Icon(
                                      Icons.person_outline_rounded,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: AppRadius.roundedMd,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _newPasswordCtrl,
                                  obscureText: true,
                                  decoration: InputDecoration(
                                    labelText:
                                        'Change Password (Leave empty to keep)',
                                    prefixIcon: const Icon(Icons.key_outlined),
                                    border: OutlineInputBorder(
                                      borderRadius: AppRadius.roundedMd,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _newPinCtrl,
                                  obscureText: true,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(4),
                                  ],
                                  decoration: InputDecoration(
                                    labelText:
                                        'Change 4-Digit PIN (Leave empty to keep)',
                                    prefixIcon: const Icon(Icons.pin_outlined),
                                    border: OutlineInputBorder(
                                      borderRadius: AppRadius.roundedMd,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Database Backup, Export & Migration Hub
                            _buildSectionCard(
                              theme,
                              title: 'Database Backup & Restore Hub',
                              icon: Icons.cloud_sync_outlined,
                              children: [
                                Text(
                                  'Easily create local timestamped SQLite database backups or import an existing .db file.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(
                                            0xFF059669,
                                          ),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: AppRadius.roundedMd,
                                          ),
                                        ),
                                        icon: const Icon(
                                          Icons.upload_file_rounded,
                                          size: 16,
                                        ),
                                        label: const Text('Export Backup'),
                                        onPressed: _exportDatabase,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: AppRadius.roundedMd,
                                          ),
                                        ),
                                        icon: const Icon(
                                          Icons.download_rounded,
                                          size: 16,
                                        ),
                                        label: const Text('Restore Backup'),
                                        onPressed: _showImportModal,
                                      ),
                                    ),
                                  ],
                                ),
                                if (_latestExport != null) ...[
                                  const SizedBox(height: 14),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF10B981,
                                      ).withAlpha(20),
                                      borderRadius: AppRadius.roundedMd,
                                      border: Border.all(
                                        color: const Color(
                                          0xFF10B981,
                                        ).withAlpha(60),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.check_circle_rounded,
                                              size: 16,
                                              color: Color(0xFF10B981),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Exported: ${_latestExport!.fileName}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Size: ${_latestExport!.formattedSize} • ${_latestExport!.formattedDate}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 16),

                                // Recent Backups List
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'RECENT BACKUPS',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.refresh_rounded,
                                        size: 16,
                                      ),
                                      onPressed: _loadRecentBackups,
                                    ),
                                  ],
                                ),
                                if (_recentBackups.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                    child: Text(
                                      'No backup files found yet. Tap "Export Backup" to create one.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  )
                                else
                                  Container(
                                    constraints: const BoxConstraints(
                                      maxHeight: 180,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: theme.colorScheme.outlineVariant
                                            .withAlpha(70),
                                      ),
                                      borderRadius: AppRadius.roundedMd,
                                    ),
                                    child: ListView.separated(
                                      shrinkWrap: true,
                                      itemCount: _recentBackups.length,
                                      separatorBuilder:
                                          (_, _) => const Divider(height: 1),
                                      itemBuilder: (context, idx) {
                                        final b = _recentBackups[idx];
                                        return ListTile(
                                          dense: true,
                                          leading: const Icon(
                                            Icons.storage_rounded,
                                            size: 18,
                                          ),
                                          title: Text(
                                            b.fileName,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          subtitle: Text(
                                            '${b.formattedSize} • ${b.formattedDate}',
                                            style: const TextStyle(
                                              fontSize: 10.5,
                                            ),
                                          ),
                                          trailing: IconButton(
                                            icon: const Icon(
                                              Icons.copy_rounded,
                                              size: 15,
                                            ),
                                            tooltip: 'Copy path',
                                            onPressed: () {
                                              Clipboard.setData(
                                                ClipboardData(text: b.filePath),
                                              );
                                              context.showSnackbar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Path copied to clipboard',
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        );

                        if (isDesktop) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 5, child: leftCol),
                              const SizedBox(width: 16),
                              Expanded(flex: 4, child: rightCol),
                            ],
                          );
                        }

                        return Column(
                          children: [
                            leftCol,
                            const SizedBox(height: 16),
                            rightCol,
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard(
    ThemeData theme, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return AppCard(
      isHoverable: false,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withAlpha(22),
                  borderRadius: AppRadius.roundedSm,
                ),
                child: Icon(icon, size: 18, color: theme.colorScheme.primary),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}
