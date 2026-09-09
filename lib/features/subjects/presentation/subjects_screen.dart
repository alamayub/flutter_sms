// lib/features/subjects/presentation/subjects_screen.dart
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../data/subjects_repository.dart';

class SubjectsScreen extends ConsumerStatefulWidget {
  const SubjectsScreen({super.key});

  @override
  ConsumerState<SubjectsScreen> createState() => _SubjectsScreenState();
}

class _SubjectsScreenState extends ConsumerState<SubjectsScreen> {
  void _showAddEditSubjectDialog([Subject? subject]) {
    final isEditing = subject != null;
    final nameController = TextEditingController(text: subject?.name ?? '');
    final codeController = TextEditingController(text: subject?.code ?? '');
    final descController = TextEditingController(
      text: subject?.description ?? '',
    );
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(isEditing ? 'Edit Subject' : 'New Subject'),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Subject Name *',
                      hintText: 'e.g., Mathematics',
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
                      labelText: 'Subject Code *',
                      hintText: 'e.g., MATH101',
                    ),
                    validator:
                        (v) =>
                            v == null || v.trim().isEmpty
                                ? 'Code is required'
                                : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: descController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Description (Optional)',
                      hintText: 'Curriculum notes...',
                    ),
                  ),
                ],
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
                  final school = ref.read(authControllerProvider).currentSchool;
                  if (school == null) return;

                  final repo = ref.read(subjectsRepositoryProvider);
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    if (isEditing) {
                      await repo.updateSubject(
                        id: subject.id,
                        name: nameController.text.trim(),
                        code: codeController.text.trim(),
                        description:
                            descController.text.trim().isNotEmpty
                                ? descController.text.trim()
                                : null,
                        isActive: true,
                      );
                    } else {
                      await repo.createSubject(
                        schoolId: school.id,
                        name: nameController.text.trim(),
                        code: codeController.text.trim(),
                        description:
                            descController.text.trim().isNotEmpty
                                ? descController.text.trim()
                                : null,
                        currentUserId:
                            ref.read(authControllerProvider).currentUser?.id,
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
                child: Text(isEditing ? 'Save' : 'Create'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final school = ref.watch(authControllerProvider).currentSchool;
    if (school == null) {
      return const Scaffold(body: Center(child: Text('No school selected')));
    }

    final repo = ref.watch(subjectsRepositoryProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Subjects Catalog'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              onPressed: () => _showAddEditSubjectDialog(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Subject'),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<Subject>>(
        stream: repo.watchSubjects(school.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final subjects = snapshot.data ?? [];
          if (subjects.isEmpty) {
            return EmptyState(
              icon: Icons.menu_book_outlined,
              title: 'No Subjects Found',
              message:
                  'Add subjects such as Mathematics, English, Science, Nepali, or Computer Science.',
              actionLabel: 'Create Subject',
              onAction: () => _showAddEditSubjectDialog(),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(20),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 360,
              mainAxisExtent: 140,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: subjects.length,
            itemBuilder: (context, idx) {
              final sub = subjects[idx];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              sub.code,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            tooltip: 'Edit',
                            onPressed: () => _showAddEditSubjectDialog(sub),
                          ),
                        ],
                      ),
                      Text(
                        sub.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        sub.description?.isNotEmpty == true
                            ? sub.description!
                            : 'No description provided',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
