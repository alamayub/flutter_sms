// lib/features/school/presentation/registration_wizard_screen.dart
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../core/database/database_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../../database_management/services/backup_service.dart';
import '../data/demo_data_seeder.dart';

class RegistrationWizardScreen extends ConsumerStatefulWidget {
  const RegistrationWizardScreen({super.key});

  @override
  ConsumerState<RegistrationWizardScreen> createState() =>
      _RegistrationWizardScreenState();
}

class _RegistrationWizardScreenState
    extends ConsumerState<RegistrationWizardScreen> {
  int _currentStep = 0; // 0: Choice, 1: School Info, 2: Admin Info, 3: Success
  bool _isProcessing = false;
  String? _errorMessage;

  // School Form Controllers
  final _schoolNameController = TextEditingController();
  final _shortNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _principalController = TextEditingController();

  // Admin Form Controllers
  final _adminNameController = TextEditingController();
  final _adminUsernameController = TextEditingController();
  final _adminEmailController = TextEditingController();
  final _adminPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _schoolFormKey = GlobalKey<FormState>();
  final _adminFormKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _schoolNameController.dispose();
    _shortNameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _principalController.dispose();
    _adminNameController.dispose();
    _adminUsernameController.dispose();
    _adminEmailController.dispose();
    _adminPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleImportBackup() async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['sdb', 'json'],
      );

      if (result == null || result.files.isEmpty) {
        setState(() => _isProcessing = false);
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
      await backupService.importBackup(content);

      // Refresh auth controller state
      await ref.read(authControllerProvider.notifier).checkStatus();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Database imported successfully! Please login.'),
            backgroundColor: AppColors.success,
          ),
        );
        context.go('/login');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Import failed: $e';
        _isProcessing = false;
      });
    }
  }

  Future<void> _handleSeedDemoData() async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final db = ref.read(appDatabaseProvider);
      final seeder = DemoDataSeeder(db);
      await seeder.seedDemoData();

      await ref.read(authControllerProvider.notifier).checkStatus();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Demo data (ABC Secondary School) seeded! Logging in as Admin...',
            ),
            backgroundColor: AppColors.success,
          ),
        );

        // Auto login as admin with demo credentials
        final success = await ref
            .read(authControllerProvider.notifier)
            .login(usernameOrEmail: 'admin', password: 'password123');

        if (success && mounted) {
          context.go('/dashboard');
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Seeding failed: $e';
        _isProcessing = false;
      });
    }
  }

  Future<void> _handleCompleteSetup() async {
    if (!_adminFormKey.currentState!.validate()) return;

    if (_adminPasswordController.text != _confirmPasswordController.text) {
      setState(() => _errorMessage = 'Passwords do not match.');
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    final success = await ref
        .read(authControllerProvider.notifier)
        .registerSchoolAndAdmin(
          schoolName: _schoolNameController.text.trim(),
          shortName:
              _shortNameController.text.trim().isNotEmpty
                  ? _shortNameController.text.trim()
                  : null,
          address:
              _addressController.text.trim().isNotEmpty
                  ? _addressController.text.trim()
                  : null,
          phone:
              _phoneController.text.trim().isNotEmpty
                  ? _phoneController.text.trim()
                  : null,
          email:
              _emailController.text.trim().isNotEmpty
                  ? _emailController.text.trim()
                  : null,
          principalName:
              _principalController.text.trim().isNotEmpty
                  ? _principalController.text.trim()
                  : null,
          adminName: _adminNameController.text.trim(),
          adminUsername: _adminUsernameController.text.trim(),
          adminEmail:
              _adminEmailController.text.trim().isNotEmpty
                  ? _adminEmailController.text.trim()
                  : null,
          adminPassword: _adminPasswordController.text,
        );

    setState(() => _isProcessing = false);

    if (success && mounted) {
      context.go('/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: _buildCurrentStepContent(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildChoiceStep();
      case 1:
        return _buildSchoolInfoStep();
      case 2:
        return _buildAdminInfoStep();
      default:
        return _buildChoiceStep();
    }
  }

  Widget _buildChoiceStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.school, size: 36, color: AppColors.primary),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Welcome to School Management System',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        const Text(
          '100% Local-First & Offline. Set up a new school database or restore from a portable backup file.',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        if (_errorMessage != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.dangerLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: AppColors.danger, fontSize: 13),
            ),
          ),
          const SizedBox(height: 16),
        ],
        ElevatedButton.icon(
          onPressed:
              _isProcessing ? null : () => setState(() => _currentStep = 1),
          icon: const Icon(Icons.add_business),
          label: const Text('Create New School'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _isProcessing ? null : _handleImportBackup,
          icon: const Icon(Icons.file_upload_outlined),
          label: const Text('Import Existing Database (.sdb)'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
        const SizedBox(height: 24),
        const Row(
          children: [
            Expanded(child: Divider()),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'OR QUICK TEST',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
            ),
            Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 16),
        TextButton.icon(
          onPressed: _isProcessing ? null : _handleSeedDemoData,
          icon: const Icon(Icons.auto_fix_high, size: 18),
          label: const Text('Load Demo School (ABC Secondary School)'),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.secondary,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
        if (_isProcessing) ...[
          const SizedBox(height: 20),
          const Center(child: CircularProgressIndicator()),
        ],
      ],
    );
  }

  Widget _buildSchoolInfoStep() {
    return Form(
      key: _schoolFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _currentStep = 0),
              ),
              const SizedBox(width: 8),
              const Text(
                'Step 1: School Information',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _schoolNameController,
            decoration: const InputDecoration(
              labelText: 'School Name *',
              hintText: 'e.g., Mount Everest Secondary School',
              prefixIcon: Icon(Icons.school_outlined),
            ),
            validator:
                (v) =>
                    v == null || v.trim().isEmpty
                        ? 'School name is required'
                        : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _shortNameController,
            decoration: const InputDecoration(
              labelText: 'Short Name / Code',
              hintText: 'e.g., MESS',
              prefixIcon: Icon(Icons.short_text),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _addressController,
            decoration: const InputDecoration(
              labelText: 'Address',
              hintText: 'e.g., Kathmandu, Ward 4',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _phoneController,
            decoration: const InputDecoration(
              labelText: 'Phone Number',
              hintText: '+977-1-4412345',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'School Email',
              hintText: 'info@school.edu.np',
              prefixIcon: Icon(Icons.email_outlined),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _principalController,
            decoration: const InputDecoration(
              labelText: 'Principal / Headmaster Name',
              hintText: 'Dr. Ananda Sharma',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              if (_schoolFormKey.currentState!.validate()) {
                setState(() => _currentStep = 2);
              }
            },
            child: const Text('Continue to Administrator Setup'),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminInfoStep() {
    return Form(
      key: _adminFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _currentStep = 1),
              ),
              const SizedBox(width: 8),
              const Text(
                'Step 2: Administrator Account',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.dangerLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: AppColors.danger, fontSize: 13),
              ),
            ),
            const SizedBox(height: 14),
          ],
          TextFormField(
            controller: _adminNameController,
            decoration: const InputDecoration(
              labelText: 'Full Name *',
              hintText: 'e.g., John Doe',
              prefixIcon: Icon(Icons.person_outline),
            ),
            validator:
                (v) =>
                    v == null || v.trim().isEmpty
                        ? 'Full name is required'
                        : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _adminUsernameController,
            decoration: const InputDecoration(
              labelText: 'Username *',
              hintText: 'admin',
              prefixIcon: Icon(Icons.alternate_email),
            ),
            validator:
                (v) =>
                    v == null || v.trim().isEmpty
                        ? 'Username is required'
                        : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _adminEmailController,
            decoration: const InputDecoration(
              labelText: 'Admin Email',
              hintText: 'admin@school.edu.np',
              prefixIcon: Icon(Icons.email_outlined),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _adminPasswordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Password *',
              prefixIcon: Icon(Icons.lock_outline),
            ),
            validator:
                (v) =>
                    v == null || v.length < 6
                        ? 'Password must be at least 6 characters'
                        : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Confirm Password *',
              prefixIcon: Icon(Icons.lock_outline),
            ),
            validator:
                (v) =>
                    v == null || v.isEmpty
                        ? 'Confirm password is required'
                        : null,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isProcessing ? null : _handleCompleteSetup,
            child:
                _isProcessing
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                    : const Text('Complete Setup & Initialize Database'),
          ),
        ],
      ),
    );
  }
}
