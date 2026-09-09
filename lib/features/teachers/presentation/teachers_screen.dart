// lib/features/teachers/presentation/teachers_screen.dart
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../data/teachers_repository.dart';

class TeachersScreen extends ConsumerStatefulWidget {
  const TeachersScreen({super.key});

  @override
  ConsumerState<TeachersScreen> createState() => _TeachersScreenState();
}

class _TeachersScreenState extends ConsumerState<TeachersScreen> {
  void _showAddEditTeacherDialog([Teacher? teacher]) {
    final isEditing = teacher != null;
    final nameController = TextEditingController(text: teacher?.name ?? '');
    final codeController = TextEditingController(
      text: teacher?.employeeCode ?? '',
    );
    final phoneController = TextEditingController(text: teacher?.phone ?? '');
    final emailController = TextEditingController(text: teacher?.email ?? '');
    final addressController = TextEditingController(
      text: teacher?.address ?? '',
    );
    bool createLoginAccount = false;
    final usernameController = TextEditingController();
    final passwordController = TextEditingController(text: 'password123');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: Text(isEditing ? 'Edit Teacher' : 'Add Teacher'),
                  content: Form(
                    key: formKey,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextFormField(
                            controller: nameController,
                            decoration: const InputDecoration(
                              labelText: 'Full Name *',
                              hintText: 'Ram Sharma',
                            ),
                            validator:
                                (v) =>
                                    v == null || v.trim().isEmpty
                                        ? 'Name is required'
                                        : null,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: codeController,
                            decoration: const InputDecoration(
                              labelText: 'Employee Code *',
                              hintText: 'EMP001',
                            ),
                            validator:
                                (v) =>
                                    v == null || v.trim().isEmpty
                                        ? 'Code is required'
                                        : null,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: phoneController,
                            decoration: const InputDecoration(
                              labelText: 'Phone',
                              hintText: '+977-9841234567',
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: emailController,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              hintText: 'teacher@school.edu.np',
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: addressController,
                            decoration: const InputDecoration(
                              labelText: 'Address',
                              hintText: 'City, Ward',
                            ),
                          ),
                          if (!isEditing) ...[
                            const SizedBox(height: 14),
                            CheckboxListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: const Text(
                                'Create Login Account for Teacher',
                              ),
                              value: createLoginAccount,
                              onChanged: (val) {
                                setDialogState(
                                  () => createLoginAccount = val ?? false,
                                );
                                if (createLoginAccount &&
                                    usernameController.text.isEmpty) {
                                  usernameController.text =
                                      'teacher.${nameController.text.split(' ').first.toLowerCase()}';
                                }
                              },
                            ),
                            if (createLoginAccount) ...[
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: usernameController,
                                decoration: const InputDecoration(
                                  labelText: 'Username *',
                                  hintText: 'teacher.ram',
                                ),
                                validator:
                                    (v) =>
                                        createLoginAccount &&
                                                (v == null || v.trim().isEmpty)
                                            ? 'Username is required'
                                            : null,
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: passwordController,
                                decoration: const InputDecoration(
                                  labelText: 'Initial Password *',
                                  hintText: 'password123',
                                ),
                                validator:
                                    (v) =>
                                        createLoginAccount &&
                                                (v == null || v.length < 6)
                                            ? 'Password must be >= 6 chars'
                                            : null,
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) return;
                        final school =
                            ref.read(authControllerProvider).currentSchool;
                        if (school == null) return;

                        final repo = ref.read(teachersRepositoryProvider);
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          if (isEditing) {
                            await repo.updateTeacher(
                              id: teacher.id,
                              employeeCode: codeController.text.trim(),
                              name: nameController.text.trim(),
                              phone:
                                  phoneController.text.trim().isNotEmpty
                                      ? phoneController.text.trim()
                                      : null,
                              email:
                                  emailController.text.trim().isNotEmpty
                                      ? emailController.text.trim()
                                      : null,
                              address:
                                  addressController.text.trim().isNotEmpty
                                      ? addressController.text.trim()
                                      : null,
                              isActive: true,
                            );
                          } else {
                            await repo.createTeacher(
                              schoolId: school.id,
                              employeeCode: codeController.text.trim(),
                              name: nameController.text.trim(),
                              phone:
                                  phoneController.text.trim().isNotEmpty
                                      ? phoneController.text.trim()
                                      : null,
                              email:
                                  emailController.text.trim().isNotEmpty
                                      ? emailController.text.trim()
                                      : null,
                              address:
                                  addressController.text.trim().isNotEmpty
                                      ? addressController.text.trim()
                                      : null,
                              createLoginAccount: createLoginAccount,
                              username:
                                  createLoginAccount
                                      ? usernameController.text.trim()
                                      : null,
                              password:
                                  createLoginAccount
                                      ? passwordController.text
                                      : null,
                              currentUserId:
                                  ref
                                      .read(authControllerProvider)
                                      .currentUser
                                      ?.id,
                            );
                          }
                          if (ctx.mounted) Navigator.pop(ctx);
                        } catch (e) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(e.toString()),
                              backgroundColor: AppColors.danger,
                            ),
                          );
                        }
                      },
                      child: Text(isEditing ? 'Save Changes' : 'Add Teacher'),
                    ),
                  ],
                ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final school = ref.watch(authControllerProvider).currentSchool;
    if (school == null) {
      return const Scaffold(body: Center(child: Text('No school selected')));
    }

    final repo = ref.watch(teachersRepositoryProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Teachers'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              onPressed: () => _showAddEditTeacherDialog(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Teacher'),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<Teacher>>(
        stream: repo.watchTeachers(school.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final teachers = snapshot.data ?? [];
          if (teachers.isEmpty) {
            return EmptyState(
              icon: Icons.badge_outlined,
              title: 'No Teachers Registered',
              message:
                  'Add faculty members with employee codes and optional login accounts.',
              actionLabel: 'Add First Teacher',
              onAction: () => _showAddEditTeacherDialog(),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: teachers.length,
            itemBuilder: (context, idx) {
              final t = teachers[idx];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  leading: CircleAvatar(
                    backgroundColor: AppColors.secondary.withValues(
                      alpha: 0.15,
                    ),
                    child: Text(
                      t.name.isNotEmpty ? t.name[0].toUpperCase() : 'T',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.secondary,
                      ),
                    ),
                  ),
                  title: Row(
                    children: [
                      Text(
                        t.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          t.employeeCode,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      if (t.userId != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'LOGIN ENABLED',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  subtitle: Text(
                    'Phone: ${t.phone ?? "N/A"} • Email: ${t.email ?? "N/A"}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        tooltip: 'Edit',
                        onPressed: () => _showAddEditTeacherDialog(t),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.archive_outlined,
                          size: 20,
                          color: AppColors.warning,
                        ),
                        tooltip: 'Archive',
                        onPressed: () async {
                          await repo.archiveTeacher(t.id);
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
