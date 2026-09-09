// lib/features/auth/presentation/login_screen.dart
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/local_mode_badge.dart';
import '../../database_management/services/backup_service.dart';
import 'controllers/auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await ref
        .read(authControllerProvider.notifier)
        .login(
          usernameOrEmail: _usernameController.text.trim(),
          password: _passwordController.text,
        );

    if (success && mounted) {
      context.go('/dashboard');
    }
  }

  void _showForgotPasswordDialog() {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.primary),
                SizedBox(width: 8),
                Text('Local Password Reset'),
              ],
            ),
            content: const Text(
              'Because this is a completely offline, local-first system without an internet server, password resets must be performed on-device by your School Administrator or Principal.\n\nPlease contact your administrator to reset your password.',
              style: TextStyle(fontSize: 14, height: 1.4),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Understood'),
              ),
            ],
          ),
    );
  }

  Future<void> _handleImportBackup() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['sdb', 'json'],
      );

      if (result == null || result.files.isEmpty) return;

      String? content;
      final file = result.files.first;
      if (file.bytes != null) {
        content = utf8.decode(file.bytes!);
      } else if (file.path != null) {
        content = await File(file.path!).readAsString();
      }

      if (content == null || content.isEmpty) return;

      final backupService = ref.read(backupServiceProvider);
      await backupService.importBackup(content);
      await ref.read(authControllerProvider.notifier).checkStatus();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Database restored successfully! Please log in.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import failed: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final school = authState.currentSchool;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // School Header
                      Center(
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.school,
                            size: 32,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        school?.name ?? 'School Management System',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (school?.principalName != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Principal: ${school!.principalName}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: 12),
                      const Center(child: LocalModeBadge(compact: true)),
                      const SizedBox(height: 24),

                      // Error Banner
                      if (authState.errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.dangerLight,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.danger.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: AppColors.danger,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  authState.errorMessage!,
                                  style: const TextStyle(
                                    color: AppColors.danger,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Username field
                      TextFormField(
                        controller: _usernameController,
                        decoration: const InputDecoration(
                          labelText: 'Username or Email',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator:
                            (v) =>
                                v == null || v.trim().isEmpty
                                    ? 'Please enter your username'
                                    : null,
                      ),
                      const SizedBox(height: 16),

                      // Password field
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              size: 20,
                            ),
                            onPressed:
                                () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                          ),
                        ),
                        validator:
                            (v) =>
                                v == null || v.isEmpty
                                    ? 'Please enter your password'
                                    : null,
                        onFieldSubmitted: (_) => _handleLogin(),
                      ),
                      const SizedBox(height: 8),

                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _showForgotPasswordDialog,
                          child: const Text(
                            'Forgot password?',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Login Button
                      ElevatedButton(
                        onPressed: authState.isLoading ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child:
                            authState.isLoading
                                ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                                : const Text('Login'),
                      ),

                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 8),

                      // Quick Demo Switcher
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        children: [
                          ActionChip(
                            label: const Text(
                              'Demo Admin',
                              style: TextStyle(fontSize: 11),
                            ),
                            avatar: const Icon(
                              Icons.admin_panel_settings,
                              size: 14,
                            ),
                            onPressed: () {
                              _usernameController.text = 'admin';
                              _passwordController.text = 'password123';
                            },
                          ),
                          ActionChip(
                            label: const Text(
                              'Demo Teacher',
                              style: TextStyle(fontSize: 11),
                            ),
                            avatar: const Icon(Icons.school, size: 14),
                            onPressed: () {
                              _usernameController.text = 'teacher.ram';
                              _passwordController.text = 'password123';
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: TextButton.icon(
                          onPressed: _handleImportBackup,
                          icon: const Icon(
                            Icons.file_upload_outlined,
                            size: 16,
                          ),
                          label: const Text(
                            'Restore from Backup (.sdb)',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
