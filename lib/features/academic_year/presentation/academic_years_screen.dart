// lib/features/academic_year/presentation/academic_years_screen.dart
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_helpers.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../data/academic_year_repository.dart';

class AcademicYearsScreen extends ConsumerStatefulWidget {
  const AcademicYearsScreen({super.key});

  @override
  ConsumerState<AcademicYearsScreen> createState() =>
      _AcademicYearsScreenState();
}

class _AcademicYearsScreenState extends ConsumerState<AcademicYearsScreen> {
  void _showAddEditDialog([AcademicYear? year]) {
    final isEditing = year != null;
    final nameController = TextEditingController(text: year?.name ?? '');
    DateTime startDate = year?.startDate ?? DateTime.now();
    DateTime endDate =
        year?.endDate ?? DateTime.now().add(const Duration(days: 365));
    bool isCurrent = year?.isCurrent ?? false;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: Text(
                    isEditing ? 'Edit Academic Year' : 'New Academic Year',
                  ),
                  content: Form(
                    key: formKey,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextFormField(
                            controller: nameController,
                            decoration: const InputDecoration(
                              labelText: 'Academic Year Name *',
                              hintText: 'e.g., 2026/27',
                            ),
                            validator:
                                (v) =>
                                    v == null || v.trim().isEmpty
                                        ? 'Name is required'
                                        : null,
                          ),
                          const SizedBox(height: 16),
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Start Date'),
                            subtitle: Text(
                              DateHelpers.formatDisplayDate(startDate),
                            ),
                            trailing: const Icon(
                              Icons.calendar_today,
                              size: 18,
                            ),
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: startDate,
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (picked != null) {
                                setDialogState(() => startDate = picked);
                              }
                            },
                          ),
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: const Text('End Date'),
                            subtitle: Text(
                              DateHelpers.formatDisplayDate(endDate),
                            ),
                            trailing: const Icon(
                              Icons.calendar_today,
                              size: 18,
                            ),
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: endDate,
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (picked != null) {
                                setDialogState(() => endDate = picked);
                              }
                            },
                          ),
                          CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Set as Current Academic Year'),
                            value: isCurrent,
                            onChanged: (val) {
                              setDialogState(() => isCurrent = val ?? false);
                            },
                          ),
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
                        final auth = ref.read(authControllerProvider);
                        final schoolId = auth.currentSchool?.id;
                        if (schoolId == null) return;

                        final repo = ref.read(academicYearRepositoryProvider);
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          if (isEditing) {
                            await repo.updateAcademicYear(
                              id: year.id,
                              schoolId: schoolId,
                              name: nameController.text.trim(),
                              startDate: startDate,
                              endDate: endDate,
                              isCurrent: isCurrent,
                              currentUserId: auth.currentUser?.id,
                            );
                          } else {
                            await repo.createAcademicYear(
                              schoolId: schoolId,
                              name: nameController.text.trim(),
                              startDate: startDate,
                              endDate: endDate,
                              isCurrent: isCurrent,
                              currentUserId: auth.currentUser?.id,
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
                      child: Text(isEditing ? 'Save Changes' : 'Create Year'),
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

    final repo = ref.watch(academicYearRepositoryProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Academic Years'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              onPressed: () => _showAddEditDialog(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Academic Year'),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<AcademicYear>>(
        stream: repo.watchAcademicYears(school.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final years = snapshot.data ?? [];
          if (years.isEmpty) {
            return EmptyState(
              icon: Icons.calendar_today,
              title: 'No Academic Years',
              message:
                  'Create an academic year (e.g. 2026/27) to begin setting up classes, sections, and enrollments.',
              actionLabel: 'Create Academic Year',
              onAction: () => _showAddEditDialog(),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: years.length,
            itemBuilder: (context, index) {
              final year = years[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  leading: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:
                          year.isCurrent
                              ? AppColors.successLight
                              : AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.calendar_today,
                      color:
                          year.isCurrent
                              ? AppColors.success
                              : AppColors.textSecondary,
                    ),
                  ),
                  title: Row(
                    children: [
                      Text(
                        year.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (year.isCurrent)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'CURRENT',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  subtitle: Text(
                    '${DateHelpers.formatDisplayDate(year.startDate)} — ${DateHelpers.formatDisplayDate(year.endDate)}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!year.isCurrent)
                        TextButton(
                          onPressed: () async {
                            await repo.setCurrentYear(year.id, school.id);
                          },
                          child: const Text('Set as Current'),
                        ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        tooltip: 'Edit',
                        onPressed: () => _showAddEditDialog(year),
                      ),
                      if (!year.isCurrent)
                        IconButton(
                          icon: const Icon(
                            Icons.archive_outlined,
                            size: 20,
                            color: AppColors.warning,
                          ),
                          tooltip: 'Archive',
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder:
                                  (ctx) => AlertDialog(
                                    title: const Text('Archive Academic Year?'),
                                    content: Text(
                                      'Are you sure you want to archive "${year.name}"?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed:
                                            () => Navigator.pop(ctx, false),
                                        child: const Text('Cancel'),
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.warning,
                                        ),
                                        onPressed:
                                            () => Navigator.pop(ctx, true),
                                        child: const Text('Archive'),
                                      ),
                                    ],
                                  ),
                            );
                            if (confirm == true) {
                              await repo.archiveAcademicYear(
                                year.id,
                                school.id,
                              );
                            }
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
