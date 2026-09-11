import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:path/path.dart' as p;
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/school_profile_provider.dart';
import '../services/app_media_service.dart';
import '../services/database_backup_service.dart';
import '../widgets/ui/app_badge.dart';
import '../widgets/ui/app_card.dart';
import '../widgets/ui/app_vector_graphics.dart';

class AuthScreen extends ConsumerStatefulWidget {
  final bool initialIsRegister;

  const AuthScreen({super.key, this.initialIsRegister = false});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  late bool _isRegisterMode;

  // Registration Form Controllers
  final _schoolNameCtrl = TextEditingController(text: 'Pragyan Academy');
  final _schoolCodeCtrl = TextEditingController(text: 'EMIS-2081-001');
  final _addressCtrl = TextEditingController(text: 'Kathmandu, Nepal');
  final _phoneCtrl = TextEditingController(text: '+977-1-4567890');
  final _emailCtrl = TextEditingController(text: 'info@pragyan.edu.np');
  final _websiteCtrl = TextEditingController(text: 'www.pragyan.edu.np');
  final _principalCtrl = TextEditingController(text: 'Dr. Ramesh Sharma');
  final _establishedCtrl = TextEditingController(text: '2052 BS (1995 AD)');
  final _taglineCtrl = TextEditingController(
    text: 'Knowledge, Character, Excellence',
  );
  final _idCardFooterCtrl = TextEditingController(
    text:
        'This card is non-transferable and must be returned upon leaving the school.',
  );
  final _regUsernameCtrl = TextEditingController(text: 'admin');
  final _regPasswordCtrl = TextEditingController(text: 'admin123');
  final _regConfirmPasswordCtrl = TextEditingController(text: 'admin123');
  final _regPinCtrl = TextEditingController(text: '1234');
  final _regConfirmPinCtrl = TextEditingController(text: '1234');

  String? _logoPath;

  // Login Form Controllers
  final _loginUsernameCtrl = TextEditingController(text: 'admin');
  final _loginPasswordCtrl = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  bool _obscurePin = true;
  String? _localError;

  @override
  void initState() {
    super.initState();
    final authState = ref.read(authStateProvider);
    _isRegisterMode =
        widget.initialIsRegister || authState.status == AuthStatus.unregistered;
  }

  @override
  void dispose() {
    _schoolNameCtrl.dispose();
    _schoolCodeCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _websiteCtrl.dispose();
    _principalCtrl.dispose();
    _establishedCtrl.dispose();
    _taglineCtrl.dispose();
    _idCardFooterCtrl.dispose();
    _regUsernameCtrl.dispose();
    _regPasswordCtrl.dispose();
    _regConfirmPasswordCtrl.dispose();
    _regPinCtrl.dispose();
    _regConfirmPinCtrl.dispose();
    _loginUsernameCtrl.dispose();
    _loginPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    try {
      final savedPath = await AppMediaService.pickAndSaveLogo();
      if (savedPath != null && mounted) {
        setState(() => _logoPath = savedPath);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not pick logo: $e')));
      }
    }
  }

  void _removeLogo() {
    setState(() => _logoPath = null);
  }

  void _submitRegister() async {
    setState(() => _localError = null);
    if (!_formKey.currentState!.validate()) return;

    if (_regPasswordCtrl.text != _regConfirmPasswordCtrl.text) {
      setState(() => _localError = 'Passwords do not match');
      return;
    }

    final pin = _regPinCtrl.text.trim();
    final confirmPin = _regConfirmPinCtrl.text.trim();
    if (pin.length != 4 || !RegExp(r'^\d{4}$').hasMatch(pin)) {
      setState(
        () => _localError = 'Security PIN must be exactly 4 numeric digits',
      );
      return;
    }
    if (pin != confirmPin) {
      setState(() => _localError = '4-digit PINs do not match');
      return;
    }

    final success = await ref
        .read(authStateProvider.notifier)
        .registerSchool(
          name: _schoolNameCtrl.text,
          code: _schoolCodeCtrl.text,
          address: _addressCtrl.text,
          phone: _phoneCtrl.text,
          email: _emailCtrl.text,
          website: _websiteCtrl.text,
          principalName: _principalCtrl.text,
          establishedYear: _establishedCtrl.text,
          logoPath: _logoPath,
          adminUsername: _regUsernameCtrl.text,
          password: _regPasswordCtrl.text,
          pin: pin,
          tagline: _taglineCtrl.text,
          idCardFooter: _idCardFooterCtrl.text,
        );

    if (!success && mounted) {
      final error = ref.read(authStateProvider).errorMessage;
      if (error != null) {
        setState(() => _localError = error);
      }
    }
  }

  void _submitLogin() async {
    setState(() => _localError = null);
    if (_loginPasswordCtrl.text.isEmpty) {
      setState(() => _localError = 'Please enter your password or PIN');
      return;
    }

    final success = await ref
        .read(authStateProvider.notifier)
        .login(
          username: _loginUsernameCtrl.text,
          password: _loginPasswordCtrl.text,
        );

    if (!success && mounted) {
      final error = ref.read(authStateProvider).errorMessage;
      if (error != null) {
        setState(() => _localError = error);
      }
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  void _showImportDatabaseDialog() {
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authStateProvider);
    final school = ref.watch(schoolProfileProvider);

    final isNarrow = MediaQuery.of(context).size.width < 700;

    return Scaffold(
      body: Stack(
        children: [
          // Background ambient aurora gradient mesh
          const Positioned.fill(child: AuroraMeshBackground(opacity: 0.8)),

          // Main Center Content
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: _isRegisterMode ? 720 : 440,
                ),
                child: AppCard(
                  depth3d: true,
                  isHoverable: false,
                  padding: EdgeInsets.all(isNarrow ? 20 : 32),
                  accentColor: theme.colorScheme.primary,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // School Crest Icon Badge
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          gradient: AppGradients.primary,
                          shape: BoxShape.circle,
                          boxShadow: AppShadows.glow(
                            theme.colorScheme.primary,
                            opacity: 0.35,
                            blur: 12,
                          ),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.school_rounded,
                            size: 32,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Title & Subtitle
                      Text(
                        _isRegisterMode
                            ? 'Register Institution'
                            : (school.name.isNotEmpty
                                ? school.name
                                : 'School Management System'),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isRegisterMode
                            ? 'Set up your school profile and administrator credentials'
                            : 'Sign in to access your administrative dashboard',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (!_isRegisterMode && school.code.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        AppBadge.primary(
                          'Affiliation: ${school.code}',
                          size: AppBadgeSize.sm,
                        ),
                      ],
                      const SizedBox(height: 24),

                      // Error message if any
                      if (_localError != null ||
                          authState.errorMessage != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.errorContainer.withAlpha(
                              160,
                            ),
                            borderRadius: AppRadius.roundedMd,
                            border: Border.all(
                              color: theme.colorScheme.error.withAlpha(80),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline_rounded,
                                size: 18,
                                color: theme.colorScheme.error,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _localError ?? authState.errorMessage!,
                                  style: TextStyle(
                                    color: theme.colorScheme.onErrorContainer,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Form Body
                      Form(
                        key: _formKey,
                        child:
                            _isRegisterMode
                                ? _buildRegisterForm(context, theme, isNarrow)
                                : _buildLoginForm(context, theme),
                      ),

                      const SizedBox(height: 20),

                      // Mode Switcher & Database Import Action
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _isRegisterMode
                                ? 'Already registered?'
                                : 'Need to set up a new school?',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _isRegisterMode = !_isRegisterMode;
                                _localError = null;
                              });
                            },
                            child: Text(
                              _isRegisterMode ? 'Sign In' : 'Register School',
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),

                      // Database Import Option
                      OutlinedButton.icon(
                        icon: const Icon(
                          Icons.settings_backup_restore_rounded,
                          size: 16,
                        ),
                        label: const Text('Restore / Import Database (.db)'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 44),
                          shape: RoundedRectangleBorder(
                            borderRadius: AppRadius.roundedMd,
                          ),
                        ),
                        onPressed: _showImportDatabaseDialog,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginForm(BuildContext context, ThemeData theme) {
    final authState = ref.watch(authStateProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _loginUsernameCtrl,
          decoration: InputDecoration(
            labelText: 'Administrator Username',
            prefixIcon: const Icon(Icons.person_outline_rounded),
            border: OutlineInputBorder(borderRadius: AppRadius.roundedMd),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _loginPasswordCtrl,
          obscureText: _obscurePassword,
          onFieldSubmitted: (_) => _submitLogin(),
          decoration: InputDecoration(
            labelText: 'Password or PIN',
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
              onPressed:
                  () => setState(() => _obscurePassword = !_obscurePassword),
            ),
            border: OutlineInputBorder(borderRadius: AppRadius.roundedMd),
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: AppRadius.roundedMd),
            elevation: 2,
          ),
          onPressed: authState.isLoading ? null : _submitLogin,
          child:
              authState.isLoading
                  ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                  : const Text(
                    'Sign In to SMS',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
        ),
      ],
    );
  }

  Widget _buildRegisterForm(
    BuildContext context,
    ThemeData theme,
    bool isNarrow,
  ) {
    final authState = ref.watch(authStateProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section: Institution Details
        // 0. School Logo Upload Section
        Center(
          child: Column(
            children: [
              Stack(
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.colorScheme.surfaceContainerHighest
                          .withAlpha(90),
                      border: Border.all(
                        color: theme.colorScheme.primary.withAlpha(120),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withAlpha(30),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child:
                          _logoPath != null && File(_logoPath!).existsSync()
                              ? Image.file(File(_logoPath!), fit: BoxFit.cover)
                              : Center(
                                child: Icon(
                                  Icons.school_rounded,
                                  size: 42,
                                  color: theme.colorScheme.primary,
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
                        padding: const EdgeInsets.all(7),
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
                  TextButton.icon(
                    onPressed: _pickLogo,
                    icon: const Icon(Icons.upload_rounded, size: 15),
                    label: Text(
                      _logoPath == null ? 'Upload School Logo' : 'Change Logo',
                    ),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (_logoPath != null) ...[
                    const SizedBox(width: 4),
                    TextButton.icon(
                      onPressed: _removeLogo,
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        size: 15,
                        color: theme.colorScheme.error,
                      ),
                      label: Text(
                        'Remove',
                        style: TextStyle(
                          color: theme.colorScheme.error,
                          fontSize: 12,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 1. Institution Details
        Row(
          children: [
            Icon(
              Icons.account_balance_outlined,
              size: 16,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              'INSTITUTION DETAILS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (isNarrow) ...[
          TextFormField(
            controller: _schoolNameCtrl,
            decoration: InputDecoration(
              labelText: 'School / College Name *',
              hintText: 'e.g. Pragyan Academy',
              prefixIcon: const Icon(Icons.school_outlined),
              border: OutlineInputBorder(borderRadius: AppRadius.roundedMd),
            ),
            validator:
                (val) =>
                    val == null || val.trim().isEmpty
                        ? 'School name is required'
                        : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _schoolCodeCtrl,
            decoration: InputDecoration(
              labelText: 'EMIS / EIMS Code *',
              hintText: 'e.g. EMIS-2081-001 or SCH-001',
              prefixIcon: const Icon(Icons.tag_rounded),
              border: OutlineInputBorder(borderRadius: AppRadius.roundedMd),
            ),
            validator:
                (val) =>
                    val == null || val.trim().isEmpty
                        ? 'EMIS / School code required'
                        : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _establishedCtrl,
            decoration: InputDecoration(
              labelText: 'Year of Establishment *',
              hintText: 'e.g. 2052 BS (1995 AD)',
              prefixIcon: const Icon(Icons.calendar_today_outlined),
              border: OutlineInputBorder(borderRadius: AppRadius.roundedMd),
            ),
            validator:
                (val) =>
                    val == null || val.trim().isEmpty
                        ? 'Establishment year required'
                        : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _principalCtrl,
            decoration: InputDecoration(
              labelText: 'Principal / Headmaster Name',
              hintText: 'e.g. Dr. Ramesh Sharma',
              prefixIcon: const Icon(Icons.person_pin_outlined),
              border: OutlineInputBorder(borderRadius: AppRadius.roundedMd),
            ),
          ),
        ] else ...[
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: _schoolNameCtrl,
                  decoration: InputDecoration(
                    labelText: 'School / College Name *',
                    hintText: 'e.g. Pragyan Academy',
                    prefixIcon: const Icon(Icons.school_outlined),
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.roundedMd,
                    ),
                  ),
                  validator:
                      (val) =>
                          val == null || val.trim().isEmpty
                              ? 'School name is required'
                              : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _schoolCodeCtrl,
                  decoration: InputDecoration(
                    labelText: 'EMIS / EIMS Code *',
                    hintText: 'e.g. EMIS-2081-001',
                    prefixIcon: const Icon(Icons.tag_rounded),
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.roundedMd,
                    ),
                  ),
                  validator:
                      (val) =>
                          val == null || val.trim().isEmpty
                              ? 'EMIS code required'
                              : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _establishedCtrl,
                  decoration: InputDecoration(
                    labelText: 'Year of Establishment *',
                    hintText: 'e.g. 2052 BS (1995 AD)',
                    prefixIcon: const Icon(Icons.calendar_today_outlined),
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.roundedMd,
                    ),
                  ),
                  validator:
                      (val) =>
                          val == null || val.trim().isEmpty
                              ? 'Establishment year required'
                              : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _principalCtrl,
                  decoration: InputDecoration(
                    labelText: 'Principal / Headmaster Name',
                    hintText: 'e.g. Dr. Ramesh Sharma',
                    prefixIcon: const Icon(Icons.person_pin_outlined),
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.roundedMd,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 20),

        // 2. Contact & Location
        Row(
          children: [
            Icon(
              Icons.location_on_outlined,
              size: 16,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              'CONTACT & LOCATION',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (isNarrow) ...[
          TextFormField(
            controller: _addressCtrl,
            decoration: InputDecoration(
              labelText: 'Address / Campus Location *',
              hintText: 'e.g. Kathmandu, Nepal',
              prefixIcon: const Icon(Icons.map_outlined),
              border: OutlineInputBorder(borderRadius: AppRadius.roundedMd),
            ),
            validator:
                (val) =>
                    val == null || val.trim().isEmpty
                        ? 'Address is required'
                        : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _phoneCtrl,
            decoration: InputDecoration(
              labelText: 'Phone Number *',
              hintText: 'e.g. +977-1-4567890',
              prefixIcon: const Icon(Icons.phone_outlined),
              border: OutlineInputBorder(borderRadius: AppRadius.roundedMd),
            ),
            validator:
                (val) =>
                    val == null || val.trim().isEmpty
                        ? 'Phone number is required'
                        : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _emailCtrl,
            decoration: InputDecoration(
              labelText: 'Official Email',
              hintText: 'info@school.edu.np',
              prefixIcon: const Icon(Icons.email_outlined),
              border: OutlineInputBorder(borderRadius: AppRadius.roundedMd),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _websiteCtrl,
            decoration: InputDecoration(
              labelText: 'Official Website',
              hintText: 'www.school.edu.np',
              prefixIcon: const Icon(Icons.language_outlined),
              border: OutlineInputBorder(borderRadius: AppRadius.roundedMd),
            ),
          ),
        ] else ...[
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _addressCtrl,
                  decoration: InputDecoration(
                    labelText: 'Address / Campus Location *',
                    hintText: 'e.g. Kathmandu, Nepal',
                    prefixIcon: const Icon(Icons.map_outlined),
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.roundedMd,
                    ),
                  ),
                  validator:
                      (val) =>
                          val == null || val.trim().isEmpty
                              ? 'Address is required'
                              : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _phoneCtrl,
                  decoration: InputDecoration(
                    labelText: 'Phone Number *',
                    hintText: 'e.g. +977-1-4567890',
                    prefixIcon: const Icon(Icons.phone_outlined),
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.roundedMd,
                    ),
                  ),
                  validator:
                      (val) =>
                          val == null || val.trim().isEmpty
                              ? 'Phone number is required'
                              : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _emailCtrl,
                  decoration: InputDecoration(
                    labelText: 'Official Email',
                    hintText: 'info@school.edu.np',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.roundedMd,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _websiteCtrl,
                  decoration: InputDecoration(
                    labelText: 'Official Website',
                    hintText: 'www.school.edu.np',
                    prefixIcon: const Icon(Icons.language_outlined),
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.roundedMd,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 20),

        // Section: Administrator Credentials
        // 3. Branding & ID Configuration
        Row(
          children: [
            Icon(
              Icons.badge_outlined,
              size: 16,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              'MOTTO & ID CARD SETTINGS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        TextFormField(
          controller: _taglineCtrl,
          decoration: InputDecoration(
            labelText: 'Motto / Tagline',
            hintText: 'e.g. Knowledge, Character, Excellence',
            prefixIcon: const Icon(Icons.format_quote_rounded),
            border: OutlineInputBorder(borderRadius: AppRadius.roundedMd),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _idCardFooterCtrl,
          decoration: InputDecoration(
            labelText: 'Student ID Card Footer Note',
            hintText: 'e.g. This card is non-transferable...',
            prefixIcon: const Icon(Icons.notes_rounded),
            border: OutlineInputBorder(borderRadius: AppRadius.roundedMd),
          ),
        ),
        const SizedBox(height: 20),

        // 4. Administrator Credentials & 4-Digit PIN
        Row(
          children: [
            Icon(
              Icons.admin_panel_settings_outlined,
              size: 16,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              'ADMINISTRATOR ACCESS & 4-DIGIT PIN',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        TextFormField(
          controller: _regUsernameCtrl,
          decoration: InputDecoration(
            labelText: 'Admin Username *',
            hintText: 'e.g. admin',
            prefixIcon: const Icon(Icons.person_outline_rounded),
            border: OutlineInputBorder(borderRadius: AppRadius.roundedMd),
          ),
          validator:
              (val) =>
                  val == null || val.trim().isEmpty
                      ? 'Admin username required'
                      : null,
        ),
        const SizedBox(height: 12),

        if (isNarrow) ...[
          TextFormField(
            controller: _regPasswordCtrl,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Admin Password *',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed:
                    () => setState(() => _obscurePassword = !_obscurePassword),
              ),
              border: OutlineInputBorder(borderRadius: AppRadius.roundedMd),
            ),
            validator:
                (val) =>
                    (val == null || val.length < 4)
                        ? 'Minimum 4 characters'
                        : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _regConfirmPasswordCtrl,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Confirm Password *',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              border: OutlineInputBorder(borderRadius: AppRadius.roundedMd),
            ),
            validator:
                (val) =>
                    (val == null || val.isEmpty)
                        ? 'Please confirm password'
                        : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _regPinCtrl,
            obscureText: _obscurePin,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ],
            decoration: InputDecoration(
              labelText: '4-Digit Security PIN *',
              hintText: 'e.g. 1234',
              prefixIcon: const Icon(Icons.pin_outlined),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePin
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: () => setState(() => _obscurePin = !_obscurePin),
              ),
              border: OutlineInputBorder(borderRadius: AppRadius.roundedMd),
            ),
            validator:
                (val) =>
                    (val == null || val.length != 4)
                        ? 'Must be exactly 4 digits'
                        : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _regConfirmPinCtrl,
            obscureText: _obscurePin,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ],
            decoration: InputDecoration(
              labelText: 'Confirm 4-Digit PIN *',
              prefixIcon: const Icon(Icons.pin_outlined),
              border: OutlineInputBorder(borderRadius: AppRadius.roundedMd),
            ),
            validator:
                (val) =>
                    (val == null || val.length != 4)
                        ? 'Must be exactly 4 digits'
                        : null,
          ),
        ] else ...[
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _regPasswordCtrl,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Admin Password *',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed:
                          () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.roundedMd,
                    ),
                  ),
                  validator:
                      (val) =>
                          (val == null || val.length < 4)
                              ? 'Minimum 4 characters'
                              : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _regConfirmPasswordCtrl,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password *',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.roundedMd,
                    ),
                  ),
                  validator:
                      (val) =>
                          (val == null || val.isEmpty)
                              ? 'Please confirm password'
                              : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _regPinCtrl,
                  obscureText: _obscurePin,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  decoration: InputDecoration(
                    labelText: '4-Digit Security PIN *',
                    hintText: 'e.g. 1234',
                    prefixIcon: const Icon(Icons.pin_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePin
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed:
                          () => setState(() => _obscurePin = !_obscurePin),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.roundedMd,
                    ),
                  ),
                  validator:
                      (val) =>
                          (val == null || val.length != 4)
                              ? 'Must be 4 digits'
                              : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _regConfirmPinCtrl,
                  obscureText: _obscurePin,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Confirm 4-Digit PIN *',
                    prefixIcon: const Icon(Icons.pin_outlined),
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.roundedMd,
                    ),
                  ),
                  validator:
                      (val) =>
                          (val == null || val.length != 4)
                              ? 'Must be 4 digits'
                              : null,
                ),
              ),
            ],
          ),
        ],

        const SizedBox(height: 24),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: AppRadius.roundedMd),
            elevation: 2,
          ),
          onPressed: authState.isLoading ? null : _submitRegister,
          child:
              authState.isLoading
                  ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                  : const Text(
                    'Register Institution & Enter SMS',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
        ),
      ],
    );
  }
}
