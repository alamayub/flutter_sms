import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../config/translations.dart';
import '../../data/app_database.dart';
import '../profile_photo.dart';
import '../ui/app_button.dart';
import '../ui/app_empty_state.dart';
import '../ui/app_error_view.dart';
import '../ui/app_skeleton.dart';

/// Reusable sliver student list. Screen-level actions remain callbacks so the
/// component can be used from other student-related screens.
class StudentsList extends StatelessWidget {
  final AsyncValue<List<StudentWithDetails>> studentsAsync;
  final String languageCode;
  final VoidCallback onAddStudent;
  final ValueChanged<StudentWithDetails> onOpenProfile;
  final ValueChanged<StudentWithDetails> onEditStudent;
  final ValueChanged<StudentWithDetails> onDeleteStudent;
  final ValueChanged<StudentWithDetails> onOpenCertificates;
  final VoidCallback onRetry;

  const StudentsList({
    super.key,
    required this.studentsAsync,
    required this.languageCode,
    required this.onAddStudent,
    required this.onOpenProfile,
    required this.onEditStudent,
    required this.onDeleteStudent,
    required this.onOpenCertificates,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return studentsAsync.when(
      data: (students) {
        if (students.isEmpty) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: AppEmptyState.noData(
                title: AppTranslations.text('no_students', languageCode),
                icon: Icons.school_outlined,
                action: AppButton.primary(
                  onPressed: onAddStudent,
                  leadingIcon: const Icon(Icons.person_add_rounded, size: 16),
                  text: AppTranslations.text('admit_student', languageCode),
                ),
              ),
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          sliver: SliverList.builder(
            itemCount: students.length,
            itemBuilder:
                (context, index) => StudentListCard(
                  student: students[index],
                  languageCode: languageCode,
                  onOpenProfile: onOpenProfile,
                  onEditStudent: onEditStudent,
                  onDeleteStudent: onDeleteStudent,
                  onOpenCertificates: onOpenCertificates,
                ),
          ),
        );
      },
      loading:
          () => SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(child: AppSkeleton.list(count: 6)),
          ),
      error:
          (error, stackTrace) => SliverFillRemaining(
            child: Center(
              child: AppErrorView(
                error: error,
                stackTrace: stackTrace,
                onRetry: onRetry,
              ),
            ),
          ),
    );
  }
}

class StudentListCard extends StatelessWidget {
  final StudentWithDetails student;
  final String languageCode;
  final ValueChanged<StudentWithDetails> onOpenProfile;
  final ValueChanged<StudentWithDetails> onEditStudent;
  final ValueChanged<StudentWithDetails> onDeleteStudent;
  final ValueChanged<StudentWithDetails> onOpenCertificates;

  const StudentListCard({
    super.key,
    required this.student,
    required this.languageCode,
    required this.onOpenProfile,
    required this.onEditStudent,
    required this.onDeleteStudent,
    required this.onOpenCertificates,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final className = student.currentClass?.displayName ?? 'Not enrolled';
    final classSection =
        student.currentSection == null
            ? className
            : '$className - ${student.currentSection!.name}';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onOpenProfile(student),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProfilePhoto(
                name: student.name,
                photoPath: student.photoPath,
                size: 54,
                backgroundColor: theme.colorScheme.primaryContainer,
                foregroundColor: theme.colorScheme.onPrimaryContainer,
                borderRadius: BorderRadius.circular(12),
                fontSize: 18,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            student.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        _StudentIdBadge(student.studentId),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _StudentMeta(
                          icon: Icons.class_outlined,
                          text: classSection,
                        ),
                        if (student.rollNumber != null)
                          _StudentMeta(
                            icon: Icons.format_list_numbered_rounded,
                            text: 'Roll: ${student.rollNumber}',
                          ),
                        if (student.bloodGroup != null)
                          Chip(
                            label: Text(student.bloodGroup!),
                            labelStyle: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                            backgroundColor: Colors.red.withValues(alpha: 0.1),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        Text(
                          '${AppTranslations.text("admission_number", languageCode)}: ${student.admissionNumber}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                        if (student.phone?.isNotEmpty == true)
                          Text(
                            '📞 ${student.phone}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 20),
                onSelected: (value) {
                  switch (value) {
                    case 'view':
                      onOpenProfile(student);
                    case 'edit':
                      onEditStudent(student);
                    case 'certificates':
                      onOpenCertificates(student);
                    case 'delete':
                      onDeleteStudent(student);
                  }
                },
                itemBuilder:
                    (context) => [
                      PopupMenuItem(
                        value: 'view',
                        child: _MenuLabel(
                          Icons.visibility_outlined,
                          AppTranslations.text('student_profile', languageCode),
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'certificates',
                        child: _MenuLabel(
                          Icons.card_membership_outlined,
                          'Certificates',
                        ),
                      ),
                      PopupMenuItem(
                        value: 'edit',
                        child: _MenuLabel(
                          Icons.edit_outlined,
                          AppTranslations.text('edit_student', languageCode),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: _MenuLabel(
                          Icons.delete_outline,
                          AppTranslations.text('delete_student', languageCode),
                          color: Colors.red,
                        ),
                      ),
                    ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudentIdBadge extends StatelessWidget {
  final String value;

  const _StudentIdBadge(this.value);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        value,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _StudentMeta extends StatelessWidget {
  final IconData icon;
  final String text;

  const _StudentMeta({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          text,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _MenuLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _MenuLabel(this.icon, this.label, {this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(label, style: color == null ? null : TextStyle(color: color)),
      ],
    );
  }
}
