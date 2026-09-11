// ignore_for_file: deprecated_member_use
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../config/responsive.dart';
import '../config/translations.dart';
import '../data/app_database.dart';
import '../providers/academic_year_provider.dart';
import '../providers/class_section_provider.dart';
import '../providers/contact_provider.dart';
import '../providers/database_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/student_provider.dart';
import '../services/student_service.dart';
import '../utils/image_storage_helper.dart';
import 'certificates_screen.dart';
import '../widgets/app_input.dart';
import '../widgets/ui/app_button.dart';
import '../widgets/ui/app_empty_state.dart';
import '../widgets/ui/app_error_view.dart';
import '../widgets/ui/app_skeleton.dart';
import '../widgets/ui/app_tabs.dart';

class StudentsScreen extends ConsumerStatefulWidget {
  const StudentsScreen({super.key});

  @override
  ConsumerState<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends ConsumerState<StudentsScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeProvider).locale.languageCode;
    final studentsAsync = ref.watch(studentsListStreamProvider);
    final activeYearAsync = ref.watch(activeAcademicYearProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: ResponsiveScaffoldWrapper(
        child: CustomScrollView(
          slivers: [
            // Top Bar
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.12,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.school_rounded,
                        color: theme.colorScheme.primary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppTranslations.text('students', lang),
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            AppTranslations.text('enrollment_info', lang),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _showPromotionDialog(context),
                          icon: const Icon(Icons.upgrade_rounded, size: 20),
                          label: Text(
                            AppTranslations.text('promote_students', lang),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: () => _showAdmissionDialog(context),
                          icon: const Icon(Icons.person_add_rounded, size: 20),
                          label: Text(
                            AppTranslations.text('admit_student', lang),
                          ),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Quick Metrics Summary Cards
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: studentsAsync.when(
                  data: (students) {
                    final activeCount =
                        students.where((s) => s.isActive).length;
                    final activeYearName =
                        activeYearAsync.value?.name ?? 'Current';

                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final isSmall = constraints.maxWidth < 600;
                        final cards = [
                          _buildMetricCard(
                            context,
                            title: AppTranslations.text('total_students', lang),
                            value: '${students.length}',
                            icon: Icons.groups_rounded,
                            color: theme.colorScheme.primary,
                          ),
                          _buildMetricCard(
                            context,
                            title: AppTranslations.text(
                              'active_students',
                              lang,
                            ),
                            value: '$activeCount',
                            icon: Icons.check_circle_rounded,
                            color: Colors.green,
                          ),
                          _buildMetricCard(
                            context,
                            title: AppTranslations.text(
                              'academic_session',
                              lang,
                            ),
                            value: activeYearName,
                            icon: Icons.calendar_month_rounded,
                            color: Colors.deepOrange,
                          ),
                        ];

                        if (isSmall) {
                          return Column(
                            children:
                                cards
                                    .map(
                                      (c) => Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 8,
                                        ),
                                        child: c,
                                      ),
                                    )
                                    .toList(),
                          );
                        }

                        return Row(
                          children:
                              cards
                                  .map(
                                    (c) => Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                        ),
                                        child: c,
                                      ),
                                    ),
                                  )
                                  .toList(),
                        );
                      },
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                ),
              ),
            ),

            // Filter Bar (Academic Year, Class, Section, Search)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Card(
                  elevation: 0,
                  color: theme.colorScheme.surfaceContainerLow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: 0.5,
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        // Search text box
                        AppSearchField(
                          controller: _searchController,
                          hintText: AppTranslations.text('search', lang),
                          onChanged: (val) {
                            ref
                                .read(studentSearchQueryProvider.notifier)
                                .setQuery(val);
                          },
                          onClear: () {
                            ref
                                .read(studentSearchQueryProvider.notifier)
                                .setQuery('');
                          },
                        ),
                        const SizedBox(height: 12),
                        // Dropdown Filters Row
                        _buildFilterDropdowns(context, lang),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Students List / Cards
            studentsAsync.when(
              data: (students) {
                if (students.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: AppEmptyState.noData(
                        title: AppTranslations.text('no_students', lang),
                        icon: Icons.school_outlined,
                        action: AppButton.primary(
                          onPressed: () => _showAdmissionDialog(context),
                          leadingIcon: const Icon(
                            Icons.person_add_rounded,
                            size: 16,
                          ),
                          text: AppTranslations.text('admit_student', lang),
                        ),
                      ),
                    ),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final item = students[index];
                      return _buildStudentCard(context, item, lang);
                    }, childCount: students.length),
                  ),
                );
              },
              loading:
                  () => SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverToBoxAdapter(
                      child: AppSkeleton.list(count: 6),
                    ),
                  ),
              error:
                  (err, stack) => SliverFillRemaining(
                    child: Center(
                      child: AppErrorView(
                        error: err,
                        stackTrace: stack,
                        onRetry: () => ref.refresh(studentsListStreamProvider),
                      ),
                    ),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterDropdowns(BuildContext context, String lang) {
    final yearsAsync = ref.watch(academicYearsStreamProvider);
    final classesAsync = ref.watch(classesWithSectionsStreamProvider);
    final selectedYear = ref.watch(selectedStudentYearFilterProvider);
    final selectedClass = ref.watch(selectedStudentClassFilterProvider);
    final selectedSection = ref.watch(selectedStudentSectionFilterProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmall = constraints.maxWidth < 600;

        final yearDropdown = yearsAsync.when(
          data: (years) {
            return AppSearchableSelect<int?>.filter(
              value: selectedYear,
              hint: AppTranslations.text('academic_session', lang),
              items: [
                const SearchableSelectItem<int?>(
                  value: null,
                  label: 'All / Current Session',
                ),
                ...years.map(
                  (y) => SearchableSelectItem<int?>(
                    value: y.id,
                    label: '${y.name} ${y.isCurrent ? "(Active)" : ""}',
                  ),
                ),
              ],
              onChanged: (val) {
                ref
                    .read(selectedStudentYearFilterProvider.notifier)
                    .setYear(val);
              },
            );
          },
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => const SizedBox.shrink(),
        );

        final classDropdown = classesAsync.when(
          data: (classes) {
            return AppSearchableSelect<int?>.filter(
              value: selectedClass,
              hint: AppTranslations.text('class', lang),
              items: [
                const SearchableSelectItem<int?>(
                  value: null,
                  label: 'All Classes',
                ),
                ...classes.map(
                  (c) => SearchableSelectItem<int?>(
                    value: c.schoolClass.id,
                    label: c.schoolClass.displayName,
                  ),
                ),
              ],
              onChanged: (val) {
                ref
                    .read(selectedStudentClassFilterProvider.notifier)
                    .setClass(val);
                ref
                    .read(selectedStudentSectionFilterProvider.notifier)
                    .setSection(null);
              },
            );
          },
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => const SizedBox.shrink(),
        );

        final sectionDropdown = classesAsync.when(
          data: (classes) {
            final activeClassObj =
                selectedClass != null
                    ? classes
                        .where((c) => c.schoolClass.id == selectedClass)
                        .firstOrNull
                    : null;

            final availableSections = activeClassObj?.sections ?? [];

            return AppSearchableSelect<int?>.filter(
              value: selectedSection,
              hint: AppTranslations.text('section', lang),
              items: [
                const SearchableSelectItem<int?>(
                  value: null,
                  label: 'All Sections',
                ),
                ...availableSections.map(
                  (s) => SearchableSelectItem<int?>(
                    value: s.id,
                    label: 'Section ${s.name}',
                  ),
                ),
              ],
              onChanged: (val) {
                ref
                    .read(selectedStudentSectionFilterProvider.notifier)
                    .setSection(val);
              },
            );
          },
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => const SizedBox.shrink(),
        );

        if (isSmall) {
          return Column(
            children: [
              yearDropdown,
              const SizedBox(height: 8),
              classDropdown,
              const SizedBox(height: 8),
              sectionDropdown,
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: yearDropdown),
            const SizedBox(width: 8),
            Expanded(child: classDropdown),
            const SizedBox(width: 8),
            Expanded(child: sectionDropdown),
          ],
        );
      },
    );
  }

  Widget _buildStudentCard(
    BuildContext context,
    StudentWithDetails item,
    String lang,
  ) {
    final theme = Theme.of(context);
    final hasPhoto = ImageStorageHelper.isLocalFile(item.photoPath);

    String classSectionDisplay = 'Not enrolled';
    if (item.currentClass != null) {
      classSectionDisplay = item.currentClass!.displayName;
      if (item.currentSection != null) {
        classSectionDisplay += ' - ${item.currentSection!.name}';
      }
    }

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
        onTap: () => _showStudentProfileDialog(context, item),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Photo / Avatar
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child:
                    hasPhoto
                        ? Image.file(
                          File(item.photoPath!),
                          width: 54,
                          height: 54,
                          fit: BoxFit.cover,
                          errorBuilder:
                              (_, _, _) => _buildInitialsAvatar(context, item),
                        )
                        : _buildInitialsAvatar(context, item),
              ),
              const SizedBox(width: 14),

              // Main Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        // Student ID badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.1,
                            ),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.3,
                              ),
                            ),
                          ),
                          child: Text(
                            item.studentId,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Class, Section & Roll
                    Row(
                      children: [
                        Icon(
                          Icons.class_outlined,
                          size: 16,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          classSectionDisplay,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (item.rollNumber != null) ...[
                          const SizedBox(width: 12),
                          Icon(
                            Icons.format_list_numbered_rounded,
                            size: 16,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Roll: ${item.rollNumber}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                        if (item.bloodGroup != null) ...[
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              item.bloodGroup!,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: Colors.red.shade700,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Phone & Admission number
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        Text(
                          '${AppTranslations.text("admission_number", lang)}: ${item.admissionNumber}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                        if (item.phone != null && item.phone!.isNotEmpty)
                          Text(
                            '📞 ${item.phone}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Action Popup
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 20),
                onSelected: (val) {
                  if (val == 'view') {
                    _showStudentProfileDialog(context, item);
                  } else if (val == 'edit') {
                    _showAdmissionDialog(context, existingStudent: item);
                  } else if (val == 'certificates') {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder:
                            (_) => Scaffold(
                              appBar: AppBar(
                                title: Text('Certificates - ${item.name}'),
                              ),
                              body: CertificatesScreen(
                                preselectedStudentId: item.id,
                              ),
                            ),
                      ),
                    );
                  } else if (val == 'delete') {
                    _confirmDeleteStudent(context, item);
                  }
                },
                itemBuilder:
                    (context) => [
                      PopupMenuItem(
                        value: 'view',
                        child: Row(
                          children: [
                            const Icon(Icons.visibility_outlined, size: 18),
                            const SizedBox(width: 8),
                            Text(AppTranslations.text('student_profile', lang)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'certificates',
                        child: const Row(
                          children: [
                            Icon(Icons.card_membership_outlined, size: 18),
                            SizedBox(width: 8),
                            Text('Certificates'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            const Icon(Icons.edit_outlined, size: 18),
                            const SizedBox(width: 8),
                            Text(AppTranslations.text('edit_student', lang)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            const Icon(
                              Icons.delete_outline,
                              size: 18,
                              color: Colors.red,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              AppTranslations.text('delete_student', lang),
                              style: const TextStyle(color: Colors.red),
                            ),
                          ],
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

  Widget _buildInitialsAvatar(BuildContext context, StudentWithDetails item) {
    final theme = Theme.of(context);
    final initials =
        item.name.isNotEmpty
            ? item.name
                .trim()
                .split(' ')
                .map((e) => e.isNotEmpty ? e[0] : '')
                .take(2)
                .join()
                .toUpperCase()
            : 'ST';

    return Container(
      width: 54,
      height: 54,
      color: theme.colorScheme.primaryContainer,
      child: Center(
        child: Text(
          initials,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
      ),
    );
  }

  void _showAdmissionDialog(
    BuildContext context, {
    StudentWithDetails? existingStudent,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => StudentAdmissionDialog(existingStudent: existingStudent),
    );
  }

  void _showPromotionDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const StudentPromotionDialog(),
    );
  }

  void _showStudentProfileDialog(
    BuildContext context,
    StudentWithDetails student,
  ) {
    showDialog(
      context: context,
      builder: (context) => StudentProfileDialog(student: student),
    );
  }

  void _confirmDeleteStudent(BuildContext context, StudentWithDetails student) {
    final lang = ref.read(localeProvider).locale.languageCode;
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(AppTranslations.text('delete_student', lang)),
            content: Text(
              'Are you sure you want to delete ${student.name} (${student.studentId})?\nAll academic records and contacts will be permanently removed.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(AppTranslations.text('cancel', lang)),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () async {
                  Navigator.of(context).pop();
                  final success = await ref
                      .read(studentControllerProvider.notifier)
                      .deleteStudent(student.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          success
                              ? 'Student deleted successfully'
                              : 'Failed to delete student',
                        ),
                      ),
                    );
                  }
                },
                child: Text(AppTranslations.text('delete', lang)),
              ),
            ],
          ),
    );
  }
}

// ==============================================================================
// 1. STUDENT ADMISSION & EDIT DIALOG
// ==============================================================================

class StudentAdmissionDialog extends ConsumerStatefulWidget {
  final StudentWithDetails? existingStudent;

  const StudentAdmissionDialog({super.key, this.existingStudent});

  @override
  ConsumerState<StudentAdmissionDialog> createState() =>
      _StudentAdmissionDialogState();
}

class _StudentAdmissionDialogState
    extends ConsumerState<StudentAdmissionDialog> {
  final _formKey = GlobalKey<FormState>();

  // Personal Fields
  late TextEditingController _nameController;
  late TextEditingController _addressController;
  String _gender = 'Male';
  DateTime? _dateOfBirth;
  String? _bloodGroup;
  String? _photoPath;

  // Enrollment Fields
  int? _selectedAcademicYearId;
  int? _selectedClassId;
  int? _selectedSectionId;
  late TextEditingController _rollNumberController;
  DateTime _admissionDate = DateTime.now();

  // Contacts
  late TextEditingController _guardianNameController;
  late TextEditingController _guardianPhoneController;
  late TextEditingController _guardianRelationController;
  late TextEditingController _guardianOccupationController;

  late TextEditingController _emergencyNameController;
  late TextEditingController _emergencyPhoneController;
  late TextEditingController _emergencyRelationController;
  late TextEditingController _emergencyOccupationController;

  // Facilities Opted
  bool _hasTransport = false;
  bool _hasHostel = false;
  bool _hasLibrary = false;

  bool _isSaving = false;
  String? _previewStudentId;
  String? _previewAdmissionNumber;

  @override
  void initState() {
    super.initState();
    final student = widget.existingStudent?.student;

    _nameController = TextEditingController(text: student?.name ?? '');
    _addressController = TextEditingController(text: student?.address ?? '');
    _gender = student?.gender ?? 'Male';
    _dateOfBirth = student?.dateOfBirth;
    _bloodGroup = student?.bloodGroup;
    _photoPath = student?.photoPath;

    _hasTransport = student?.hasTransport ?? false;
    _hasHostel = student?.hasHostel ?? false;
    _hasLibrary = student?.hasLibrary ?? false;

    _selectedAcademicYearId = widget.existingStudent?.currentAcademicYear?.id;
    _selectedClassId = widget.existingStudent?.classId;
    _selectedSectionId = widget.existingStudent?.sectionId;
    _rollNumberController = TextEditingController(
      text: widget.existingStudent?.rollNumber?.toString() ?? '',
    );
    _admissionDate = student?.admissionDate ?? DateTime.now();

    _guardianNameController = TextEditingController();
    _guardianPhoneController = TextEditingController();
    _guardianRelationController = TextEditingController(text: 'Father');
    _guardianOccupationController = TextEditingController();

    _emergencyNameController = TextEditingController(
      text: student?.emergencyContactName ?? '',
    );
    _emergencyPhoneController = TextEditingController(
      text: student?.emergencyContactPhone ?? '',
    );
    _emergencyRelationController = TextEditingController(
      text: student?.emergencyContactRelation ?? 'Emergency Contact',
    );
    _emergencyOccupationController = TextEditingController();

    _loadPreviews();
    _loadExistingContacts();
  }

  Future<void> _loadExistingContacts() async {
    if (widget.existingStudent == null) return;
    try {
      final contactService = ref.read(contactServiceProvider);
      final contacts = await contactService.getContactsBySource(
        ContactSourceType.student,
        widget.existingStudent!.id,
      );
      if (!mounted) return;
      for (final c in contacts) {
        if (c.isPrimary ||
            (!c.isEmergency && _guardianNameController.text.isEmpty)) {
          if (_guardianNameController.text.isEmpty) {
            _guardianNameController.text = c.name;
            _guardianPhoneController.text = c.phone;
            if (c.relation != null && c.relation!.isNotEmpty) {
              _guardianRelationController.text = c.relation!;
            }
            if (c.occupation != null && c.occupation!.isNotEmpty) {
              _guardianOccupationController.text = c.occupation!;
            }
          }
        }
        if (c.isEmergency) {
          if (_emergencyNameController.text.isEmpty) {
            _emergencyNameController.text = c.name;
          }
          if (_emergencyPhoneController.text.isEmpty) {
            _emergencyPhoneController.text = c.phone;
          }
          if (c.relation != null && c.relation!.isNotEmpty) {
            _emergencyRelationController.text = c.relation!;
          }
          if (c.occupation != null && c.occupation!.isNotEmpty) {
            _emergencyOccupationController.text = c.occupation!;
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _loadPreviews() async {
    if (widget.existingStudent != null) {
      setState(() {
        _previewStudentId = widget.existingStudent!.studentId;
        _previewAdmissionNumber = widget.existingStudent!.admissionNumber;
      });
      return;
    }
    final service = ref.read(studentServiceProvider);
    final year = _admissionDate.year;
    final nextId = await service.generateNextStudentId(year);
    final nextAdm = await service.generateNextAdmissionNumber(year);
    if (mounted) {
      setState(() {
        _previewStudentId = nextId;
        _previewAdmissionNumber = nextAdm;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _rollNumberController.dispose();
    _guardianNameController.dispose();
    _guardianPhoneController.dispose();
    _guardianRelationController.dispose();
    _guardianOccupationController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    _emergencyRelationController.dispose();
    _emergencyOccupationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeProvider).locale.languageCode;
    final theme = Theme.of(context);
    final yearsAsync = ref.watch(academicYearsStreamProvider);
    final classesAsync = ref.watch(classesWithSectionsStreamProvider);
    final isEditing = widget.existingStudent != null;

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            isEditing ? Icons.edit_rounded : Icons.person_add_rounded,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Text(
            isEditing
                ? AppTranslations.text('edit_student', lang)
                : AppTranslations.text('admit_student', lang),
          ),
        ],
      ),
      content: SizedBox(
        width: 650,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ID Preview Banner
                if (_previewStudentId != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withValues(
                        alpha: 0.4,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: theme.colorScheme.primary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${AppTranslations.text("student_id", lang)}: $_previewStudentId',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        Text(
                          '${AppTranslations.text("admission_number", lang)}: $_previewAdmissionNumber',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Photo Picker & Basic Personal Info
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Photo
                    Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 104,
                            height: 104,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: theme.dividerColor.withAlpha(120),
                              ),
                            ),
                            child:
                                ImageStorageHelper.isLocalFile(_photoPath)
                                    ? Image.file(
                                      File(_photoPath!),
                                      fit: BoxFit.cover,
                                    )
                                    : Icon(
                                      Icons.person,
                                      size: 52,
                                      color: theme.colorScheme.primary
                                          .withAlpha(120),
                                    ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton.icon(
                              onPressed: () async {
                                final path =
                                    await ImageStorageHelper.pickAndSaveStudentPhoto(
                                      studentId:
                                          widget
                                              .existingStudent
                                              ?.student
                                              .studentId ??
                                          _previewStudentId,
                                    );
                                if (path != null) {
                                  setState(() => _photoPath = path);
                                }
                              },
                              icon: const Icon(
                                Icons.camera_alt_outlined,
                                size: 15,
                              ),
                              label: Text(
                                _photoPath != null
                                    ? AppTranslations.text('change_photo', lang)
                                    : AppTranslations.text(
                                      'select_photo',
                                      lang,
                                    ),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            if (_photoPath != null) ...[
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                tooltip: 'Remove photo',
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.redAccent,
                                  size: 18,
                                ),
                                onPressed: () {
                                  setState(() => _photoPath = null);
                                },
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),

                    // Name & Gender
                    Expanded(
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Student Full Name *',
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Student name is required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: AppSearchableSelect<String>(
                                  value: _gender,
                                  label: 'Gender *',
                                  hint: 'Select Gender',
                                  items: const [
                                    SearchableSelectItem(
                                      value: 'Male',
                                      label: 'Male',
                                    ),
                                    SearchableSelectItem(
                                      value: 'Female',
                                      label: 'Female',
                                    ),
                                    SearchableSelectItem(
                                      value: 'Other',
                                      label: 'Other',
                                    ),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() => _gender = val);
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: AppSearchableSelect<String?>(
                                  value: _bloodGroup,
                                  label: AppTranslations.text(
                                    'blood_group',
                                    lang,
                                  ),
                                  hint: 'Select Blood Group',
                                  isClearable: true,
                                  items: const [
                                    SearchableSelectItem(
                                      value: null,
                                      label: 'Unknown',
                                    ),
                                    SearchableSelectItem(
                                      value: 'A+',
                                      label: 'A+',
                                    ),
                                    SearchableSelectItem(
                                      value: 'A-',
                                      label: 'A-',
                                    ),
                                    SearchableSelectItem(
                                      value: 'B+',
                                      label: 'B+',
                                    ),
                                    SearchableSelectItem(
                                      value: 'B-',
                                      label: 'B-',
                                    ),
                                    SearchableSelectItem(
                                      value: 'O+',
                                      label: 'O+',
                                    ),
                                    SearchableSelectItem(
                                      value: 'O-',
                                      label: 'O-',
                                    ),
                                    SearchableSelectItem(
                                      value: 'AB+',
                                      label: 'AB+',
                                    ),
                                    SearchableSelectItem(
                                      value: 'AB-',
                                      label: 'AB-',
                                    ),
                                  ],
                                  onChanged:
                                      (val) =>
                                          setState(() => _bloodGroup = val),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Date of birth & Address
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate:
                                _dateOfBirth ??
                                DateTime(DateTime.now().year - 10),
                            firstDate: DateTime(1990),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setState(() => _dateOfBirth = picked);
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Date of Birth',
                            suffixIcon: Icon(Icons.calendar_today, size: 18),
                          ),
                          child: Text(
                            _dateOfBirth != null
                                ? DateFormat('yyyy-MM-dd').format(_dateOfBirth!)
                                : 'Select DOB',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _addressController,
                        decoration: const InputDecoration(labelText: 'Address'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Section 2: Academic Enrollment
                Text(
                  AppTranslations.text('enrollment_info', lang),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Divider(),
                const SizedBox(height: 8),

                // Academic Year & Class
                Row(
                  children: [
                    Expanded(
                      child: yearsAsync.when(
                        data: (years) {
                          _selectedAcademicYearId ??=
                              years.where((y) => y.isCurrent).firstOrNull?.id ??
                              (years.isNotEmpty ? years.first.id : null);

                          return AppSearchableSelect<int>(
                            value: _selectedAcademicYearId,
                            label:
                                '${AppTranslations.text("academic_session", lang)} *',
                            hint: 'Select Session',
                            items:
                                years
                                    .map(
                                      (y) => SearchableSelectItem<int>(
                                        value: y.id,
                                        label:
                                            '${y.name} ${y.isCurrent ? "(Current)" : ""}',
                                      ),
                                    )
                                    .toList(),
                            onChanged:
                                (val) => setState(
                                  () => _selectedAcademicYearId = val,
                                ),
                            validator:
                                (v) => v == null ? 'Session is required' : null,
                          );
                        },
                        loading: () => const LinearProgressIndicator(),
                        error: (_, _) => const SizedBox.shrink(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: classesAsync.when(
                        data: (classes) {
                          _selectedClassId ??=
                              classes.isNotEmpty
                                  ? classes.first.schoolClass.id
                                  : null;

                          return AppSearchableSelect<int>(
                            value: _selectedClassId,
                            label: '${AppTranslations.text("class", lang)} *',
                            hint: 'Select Class',
                            items:
                                classes
                                    .map(
                                      (c) => SearchableSelectItem<int>(
                                        value: c.schoolClass.id,
                                        label: c.schoolClass.displayName,
                                      ),
                                    )
                                    .toList(),
                            onChanged: (val) {
                              setState(() {
                                _selectedClassId = val;
                                _selectedSectionId = null;
                              });
                            },
                            validator:
                                (v) => v == null ? 'Class is required' : null,
                          );
                        },
                        loading: () => const LinearProgressIndicator(),
                        error: (_, _) => const SizedBox.shrink(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Section & Roll Number
                Row(
                  children: [
                    Expanded(
                      child: classesAsync.when(
                        data: (classes) {
                          final curClass =
                              classes
                                  .where(
                                    (c) => c.schoolClass.id == _selectedClassId,
                                  )
                                  .firstOrNull;
                          final sections = curClass?.sections ?? [];

                          if (_selectedSectionId == null &&
                              sections.isNotEmpty) {
                            _selectedSectionId = sections.first.id;
                          }

                          return AppSearchableSelect<int>(
                            value: _selectedSectionId,
                            label: '${AppTranslations.text("section", lang)} *',
                            hint: 'Select Section',
                            items:
                                sections
                                    .map(
                                      (s) => SearchableSelectItem<int>(
                                        value: s.id,
                                        label: 'Section ${s.name}',
                                      ),
                                    )
                                    .toList(),
                            onChanged:
                                (val) =>
                                    setState(() => _selectedSectionId = val),
                            validator:
                                (v) => v == null ? 'Section is required' : null,
                          );
                        },
                        loading: () => const LinearProgressIndicator(),
                        error: (_, _) => const SizedBox.shrink(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _rollNumberController,
                        decoration: InputDecoration(
                          labelText: AppTranslations.text('roll_number', lang),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Facilities Opted Section
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50.withAlpha(90),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.indigo.shade100),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.room_service,
                            size: 16,
                            color: Colors.indigo,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Facilities Opted',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo.shade900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          FilterChip(
                            avatar: const Icon(Icons.directions_bus, size: 16),
                            label: const Text('Transport Facility'),
                            selected: _hasTransport,
                            selectedColor: Colors.indigo.shade100,
                            onSelected:
                                (val) => setState(() => _hasTransport = val),
                          ),
                          FilterChip(
                            avatar: const Icon(Icons.hotel, size: 16),
                            label: const Text('Hostel Facility'),
                            selected: _hasHostel,
                            selectedColor: Colors.indigo.shade100,
                            onSelected:
                                (val) => setState(() => _hasHostel = val),
                          ),
                          FilterChip(
                            avatar: const Icon(Icons.local_library, size: 16),
                            label: const Text('Library Facility'),
                            selected: _hasLibrary,
                            selectedColor: Colors.indigo.shade100,
                            onSelected:
                                (val) => setState(() => _hasLibrary = val),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Section 3: Guardian & Emergency Contacts
                Text(
                  AppTranslations.text('guardian_info', lang),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Divider(),
                const SizedBox(height: 8),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _guardianNameController,
                        decoration: InputDecoration(
                          labelText: AppTranslations.text(
                            'guardian_name',
                            lang,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _guardianPhoneController,
                        decoration: InputDecoration(
                          labelText: AppTranslations.text(
                            'guardian_phone',
                            lang,
                          ),
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _guardianRelationController,
                        decoration: InputDecoration(
                          labelText: AppTranslations.text(
                            'guardian_relation',
                            lang,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _guardianOccupationController,
                        decoration: InputDecoration(
                          labelText: AppTranslations.text('occupation', lang),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Emergency Contact Fields
                Text(
                  AppTranslations.text('emergency_details', lang),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Divider(),
                const SizedBox(height: 8),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _emergencyNameController,
                        decoration: InputDecoration(
                          labelText: AppTranslations.text(
                            'emergency_contact',
                            lang,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _emergencyPhoneController,
                        decoration: InputDecoration(
                          labelText: AppTranslations.text(
                            'emergency_phone',
                            lang,
                          ),
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _emergencyRelationController,
                        decoration: InputDecoration(
                          labelText: AppTranslations.text('relation', lang),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _emergencyOccupationController,
                        decoration: InputDecoration(
                          labelText: AppTranslations.text('occupation', lang),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: Text(AppTranslations.text('cancel', lang)),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _saveStudent,
          child:
              _isSaving
                  ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                  : Text(AppTranslations.text('save', lang)),
        ),
      ],
    );
  }

  Future<void> _saveStudent() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedAcademicYearId == null ||
        _selectedClassId == null ||
        _selectedSectionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Academic Year, Class, and Section are required'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    final roll = int.tryParse(_rollNumberController.text.trim());

    if (widget.existingStudent == null) {
      // Create new admission
      final id = await ref
          .read(studentControllerProvider.notifier)
          .admitStudent(
            name: _nameController.text.trim(),
            gender: _gender,
            academicYearId: _selectedAcademicYearId!,
            classId: _selectedClassId!,
            sectionId: _selectedSectionId!,
            rollNumber: roll,
            admissionDate: _admissionDate,
            dateOfBirth: _dateOfBirth,
            bloodGroup: _bloodGroup,
            address: _addressController.text.trim(),
            photoPath: _photoPath,
            emergencyContactName: _emergencyNameController.text.trim(),
            emergencyContactPhone: _emergencyPhoneController.text.trim(),
            emergencyContactRelation: _emergencyRelationController.text.trim(),
            emergencyContactOccupation:
                _emergencyOccupationController.text.trim(),
            guardianName: _guardianNameController.text.trim(),
            guardianPhone: _guardianPhoneController.text.trim(),
            guardianRelation: _guardianRelationController.text.trim(),
            guardianOccupation: _guardianOccupationController.text.trim(),
            hasTransport: _hasTransport,
            hasHostel: _hasHostel,
            hasLibrary: _hasLibrary,
          );

      if (mounted) {
        setState(() => _isSaving = false);
        if (id != null) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Student admitted successfully!')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to admit student')),
          );
        }
      }
    } else {
      // Update existing student
      final success = await ref
          .read(studentControllerProvider.notifier)
          .updateStudent(
            student: widget.existingStudent!.student,
            academicYearId: _selectedAcademicYearId!,
            classId: _selectedClassId!,
            sectionId: _selectedSectionId!,
            rollNumber: roll,
            name: _nameController.text.trim(),
            gender: _gender,
            dateOfBirth: _dateOfBirth,
            bloodGroup: _bloodGroup,
            address: _addressController.text.trim(),
            phone: widget.existingStudent!.student.phone,
            email: widget.existingStudent!.student.email,
            photoPath: _photoPath,
            emergencyContactName: _emergencyNameController.text.trim(),
            emergencyContactPhone: _emergencyPhoneController.text.trim(),
            emergencyContactRelation: _emergencyRelationController.text.trim(),
            emergencyContactOccupation:
                _emergencyOccupationController.text.trim(),
            guardianName: _guardianNameController.text.trim(),
            guardianPhone: _guardianPhoneController.text.trim(),
            guardianRelation: _guardianRelationController.text.trim(),
            guardianOccupation: _guardianOccupationController.text.trim(),
            hasTransport: _hasTransport,
            hasHostel: _hasHostel,
            hasLibrary: _hasLibrary,
          );

      if (mounted) {
        setState(() => _isSaving = false);
        if (success) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Student profile updated!')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to update student')),
          );
        }
      }
    }
  }
}

// ==============================================================================
// 2. STUDENT PROMOTION DIALOG
// ==============================================================================

class StudentPromotionDialog extends ConsumerStatefulWidget {
  const StudentPromotionDialog({super.key});

  @override
  ConsumerState<StudentPromotionDialog> createState() =>
      _StudentPromotionDialogState();
}

class _StudentPromotionDialogState
    extends ConsumerState<StudentPromotionDialog> {
  int? _sourceYearId;
  int? _sourceClassId;
  int? _sourceSectionId;

  int? _targetYearId;
  int? _targetClassId;
  int? _targetSectionId;

  List<StudentPromotionItem> _promotionList = [];
  bool _isLoadingStudents = false;
  bool _isPromoting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final years = ref.read(academicYearsStreamProvider).value ?? [];
      final classes = ref.read(classesWithSectionsStreamProvider).value ?? [];

      if (years.isNotEmpty) {
        final currentYear =
            years.where((y) => y.isCurrent).firstOrNull ?? years.first;
        _sourceYearId = currentYear.id;

        // Try picking next academic year for target
        final nextYear =
            years
                .where(
                  (y) =>
                      y.id != currentYear.id &&
                      y.startDate.isAfter(currentYear.startDate),
                )
                .firstOrNull ??
            currentYear;
        _targetYearId = nextYear.id;
      }

      if (classes.isNotEmpty) {
        _sourceClassId = classes.first.schoolClass.id;
        _sourceSectionId =
            classes.first.sections.isNotEmpty
                ? classes.first.sections.first.id
                : null;

        // Next class for target
        final nextClass = classes.length > 1 ? classes[1] : classes.first;
        _targetClassId = nextClass.schoolClass.id;
        _targetSectionId =
            nextClass.sections.isNotEmpty ? nextClass.sections.first.id : null;
      }

      _loadSourceStudents();
    });
  }

  Future<void> _loadSourceStudents() async {
    if (_sourceYearId == null ||
        _sourceClassId == null ||
        _sourceSectionId == null) {
      return;
    }

    setState(() => _isLoadingStudents = true);
    final db = ref.read(databaseProvider);
    final enrolled = await db.getEnrolledStudentsForClassSection(
      _sourceYearId!,
      _sourceClassId!,
      _sourceSectionId!,
    );

    int autoRoll = 1;
    final list = <StudentPromotionItem>[];

    for (final e in enrolled) {
      final student =
          await (db.select(db.students)
            ..where((t) => t.id.equals(e.studentId))).getSingleOrNull();

      if (student != null) {
        list.add(
          StudentPromotionItem(
            studentId: student.id,
            studentName: student.name,
            studentCode: student.studentId,
            currentRollNumber: e.rollNumber,
            resultStatus: AcademicResult.passed,
            isPromoted: true,
            targetClassId: _targetClassId ?? _sourceClassId!,
            targetSectionId: _targetSectionId ?? _sourceSectionId!,
            targetRollNumber: autoRoll++,
            remarks: 'Promoted to next grade',
          ),
        );
      }
    }

    if (mounted) {
      setState(() {
        _promotionList = list;
        _isLoadingStudents = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeProvider).locale.languageCode;
    final theme = Theme.of(context);
    final years = ref.watch(academicYearsStreamProvider).value ?? [];
    final classes = ref.watch(classesWithSectionsStreamProvider).value ?? [];

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.upgrade_rounded, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Text(AppTranslations.text('promotion', lang)),
        ],
      ),
      content: SizedBox(
        width: 850,
        height: 600,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Session and Class Selectors (Source vs Target)
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    // SOURCE COLUMN
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.arrow_downward_rounded,
                                size: 16,
                                color: Colors.blue,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                AppTranslations.text('source_class', lang),
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Year
                          AppSearchableSelect<int>(
                            value: _sourceYearId,
                            label: 'Source Year',
                            hint: 'Select Year',
                            items:
                                years
                                    .map(
                                      (y) => SearchableSelectItem<int>(
                                        value: y.id,
                                        label: y.name,
                                      ),
                                    )
                                    .toList(),
                            onChanged: (val) {
                              setState(() => _sourceYearId = val);
                              _loadSourceStudents();
                            },
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: AppSearchableSelect<int>(
                                  value: _sourceClassId,
                                  label: 'Class',
                                  hint: 'Select Class',
                                  items:
                                      classes
                                          .map(
                                            (c) => SearchableSelectItem<int>(
                                              value: c.schoolClass.id,
                                              label: c.schoolClass.displayName,
                                            ),
                                          )
                                          .toList(),
                                  onChanged: (val) {
                                    setState(() {
                                      _sourceClassId = val;
                                      final cur =
                                          classes
                                              .where(
                                                (c) => c.schoolClass.id == val,
                                              )
                                              .firstOrNull;
                                      _sourceSectionId =
                                          cur?.sections.isNotEmpty == true
                                              ? cur!.sections.first.id
                                              : null;
                                    });
                                    _loadSourceStudents();
                                  },
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: AppSearchableSelect<int>(
                                  value: _sourceSectionId,
                                  label: 'Section',
                                  hint: 'Select Section',
                                  items:
                                      (classes
                                                  .where(
                                                    (c) =>
                                                        c.schoolClass.id ==
                                                        _sourceClassId,
                                                  )
                                                  .firstOrNull
                                                  ?.sections ??
                                              [])
                                          .map(
                                            (s) => SearchableSelectItem<int>(
                                              value: s.id,
                                              label: 'Sec ${s.name}',
                                            ),
                                          )
                                          .toList(),
                                  onChanged: (val) {
                                    setState(() => _sourceSectionId = val);
                                    _loadSourceStudents();
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // ARROW DIVIDER
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Icon(Icons.trending_flat_rounded, size: 36),
                    ),

                    // TARGET COLUMN
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.arrow_upward_rounded,
                                size: 16,
                                color: Colors.green,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                AppTranslations.text('target_class', lang),
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Target Year
                          AppSearchableSelect<int>(
                            value: _targetYearId,
                            label: 'Target Year',
                            hint: 'Select Year',
                            items:
                                years
                                    .map(
                                      (y) => SearchableSelectItem<int>(
                                        value: y.id,
                                        label: y.name,
                                      ),
                                    )
                                    .toList(),
                            onChanged: (val) {
                              setState(() => _targetYearId = val);
                            },
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: AppSearchableSelect<int>(
                                  value: _targetClassId,
                                  label: 'Class',
                                  hint: 'Select Class',
                                  items:
                                      classes
                                          .map(
                                            (c) => SearchableSelectItem<int>(
                                              value: c.schoolClass.id,
                                              label: c.schoolClass.displayName,
                                            ),
                                          )
                                          .toList(),
                                  onChanged: (val) {
                                    setState(() {
                                      _targetClassId = val;
                                      final cur =
                                          classes
                                              .where(
                                                (c) => c.schoolClass.id == val,
                                              )
                                              .firstOrNull;
                                      _targetSectionId =
                                          cur?.sections.isNotEmpty == true
                                              ? cur!.sections.first.id
                                              : null;
                                      _updateTargetClassForPromoted();
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: AppSearchableSelect<int>(
                                  value: _targetSectionId,
                                  label: 'Section',
                                  hint: 'Select Section',
                                  items:
                                      (classes
                                                  .where(
                                                    (c) =>
                                                        c.schoolClass.id ==
                                                        _targetClassId,
                                                  )
                                                  .firstOrNull
                                                  ?.sections ??
                                              [])
                                          .map(
                                            (s) => SearchableSelectItem<int>(
                                              value: s.id,
                                              label: 'Sec ${s.name}',
                                            ),
                                          )
                                          .toList(),
                                  onChanged: (val) {
                                    setState(() {
                                      _targetSectionId = val;
                                      _updateTargetClassForPromoted();
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Bulk actions header
            Row(
              children: [
                Text(
                  'Enrolled Students (${_promotionList.length})',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _promotionList =
                          _promotionList
                              .map(
                                (item) => item.copyWith(
                                  resultStatus: AcademicResult.passed,
                                  isPromoted: true,
                                  targetClassId:
                                      _targetClassId ?? item.targetClassId,
                                  targetSectionId:
                                      _targetSectionId ?? item.targetSectionId,
                                ),
                              )
                              .toList();
                    });
                  },
                  icon: const Icon(Icons.done_all, size: 16),
                  label: const Text('Mark All Passed & Promoted'),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Students List
            Expanded(
              child:
                  _isLoadingStudents
                      ? const Center(child: CircularProgressIndicator())
                      : _promotionList.isEmpty
                      ? Center(
                        child: Text(
                          'No students enrolled in source class & section',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                      : ListView.separated(
                        itemCount: _promotionList.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = _promotionList[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                // Roll & Name
                                SizedBox(
                                  width: 40,
                                  child: Text(
                                    '#${item.currentRollNumber ?? index + 1}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.studentName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        item.studentCode,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: theme.colorScheme.outline,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Result Status Dropdown (Passed / Failed)
                                SizedBox(
                                  width: 120,
                                  child: AppSearchableSelect<AcademicResult>(
                                    value: item.resultStatus,
                                    isCompact: true,
                                    hint: 'Result',
                                    items: [
                                      SearchableSelectItem(
                                        value: AcademicResult.passed,
                                        label: AppTranslations.text(
                                          'passed',
                                          lang,
                                        ),
                                        leading: const Icon(
                                          Icons.check_circle,
                                          size: 16,
                                          color: Colors.green,
                                        ),
                                      ),
                                      SearchableSelectItem(
                                        value: AcademicResult.failed,
                                        label: AppTranslations.text(
                                          'failed',
                                          lang,
                                        ),
                                        leading: const Icon(
                                          Icons.cancel,
                                          size: 16,
                                          color: Colors.red,
                                        ),
                                      ),
                                    ],
                                    onChanged: (res) {
                                      if (res != null) {
                                        setState(() {
                                          final shouldPromote =
                                              res == AcademicResult.passed;
                                          _promotionList[index] = item.copyWith(
                                            resultStatus: res,
                                            isPromoted: shouldPromote,
                                            targetClassId:
                                                shouldPromote
                                                    ? (_targetClassId ??
                                                        item.targetClassId)
                                                    : _sourceClassId!,
                                            targetSectionId:
                                                shouldPromote
                                                    ? (_targetSectionId ??
                                                        item.targetSectionId)
                                                    : _sourceSectionId!,
                                          );
                                        });
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 10),

                                // Action Toggle: Promoted vs Retained
                                SizedBox(
                                  width: 130,
                                  child: AppSearchableSelect<bool>(
                                    value: item.isPromoted,
                                    isCompact: true,
                                    hint: 'Action',
                                    items: [
                                      SearchableSelectItem(
                                        value: true,
                                        label: AppTranslations.text(
                                          'promoted',
                                          lang,
                                        ),
                                        leading: const Icon(
                                          Icons.arrow_upward,
                                          size: 16,
                                          color: Colors.blue,
                                        ),
                                      ),
                                      SearchableSelectItem(
                                        value: false,
                                        label: AppTranslations.text(
                                          'retained',
                                          lang,
                                        ),
                                        leading: const Icon(
                                          Icons.replay,
                                          size: 16,
                                          color: Colors.orange,
                                        ),
                                      ),
                                    ],
                                    onChanged: (val) {
                                      if (val != null) {
                                        setState(() {
                                          _promotionList[index] = item.copyWith(
                                            isPromoted: val,
                                            targetClassId:
                                                val
                                                    ? (_targetClassId ??
                                                        item.targetClassId)
                                                    : _sourceClassId!,
                                            targetSectionId:
                                                val
                                                    ? (_targetSectionId ??
                                                        item.targetSectionId)
                                                    : _sourceSectionId!,
                                          );
                                        });
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 10),

                                // Target Roll No.
                                SizedBox(
                                  width: 70,
                                  child: TextFormField(
                                    initialValue:
                                        item.targetRollNumber?.toString() ?? '',
                                    decoration: const InputDecoration(
                                      labelText: 'Roll',
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 8,
                                      ),
                                      border: OutlineInputBorder(),
                                    ),
                                    keyboardType: TextInputType.number,
                                    onChanged: (r) {
                                      _promotionList[index] = item.copyWith(
                                        targetRollNumber: int.tryParse(r),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isPromoting ? null : () => Navigator.of(context).pop(),
          child: Text(AppTranslations.text('cancel', lang)),
        ),
        FilledButton.icon(
          onPressed:
              _isPromoting || _promotionList.isEmpty ? null : _executePromotion,
          icon:
              _isPromoting
                  ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                  : const Icon(Icons.upgrade_rounded, size: 18),
          label: Text(
            'Promote ${_promotionList.where((p) => p.isPromoted).length} Students',
          ),
        ),
      ],
    );
  }

  void _updateTargetClassForPromoted() {
    setState(() {
      _promotionList =
          _promotionList.map((item) {
            if (item.isPromoted) {
              return item.copyWith(
                targetClassId: _targetClassId,
                targetSectionId: _targetSectionId,
              );
            }
            return item;
          }).toList();
    });
  }

  Future<void> _executePromotion() async {
    if (_sourceYearId == null || _targetYearId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select Source and Target Academic Years'),
        ),
      );
      return;
    }

    setState(() => _isPromoting = true);

    final success = await ref
        .read(studentControllerProvider.notifier)
        .promoteStudents(
          sourceAcademicYearId: _sourceYearId!,
          targetAcademicYearId: _targetYearId!,
          items: _promotionList,
        );

    if (mounted) {
      setState(() => _isPromoting = false);
      if (success) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Students promoted successfully!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to complete promotion')),
        );
      }
    }
  }
}

// ==============================================================================
// 3. STUDENT PROFILE & ACADEMIC HISTORY TIMELINE DIALOG
// ==============================================================================

class StudentProfileDialog extends ConsumerWidget {
  final StudentWithDetails student;

  const StudentProfileDialog({super.key, required this.student});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(localeProvider).locale.languageCode;
    final theme = Theme.of(context);
    final historyAsync = ref.watch(studentAcademicHistoryProvider(student.id));
    final contactsAsync = ref.watch(studentContactsStreamProvider(student.id));
    final hasPhoto = ImageStorageHelper.isLocalFile(student.photoPath);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 720,
        height: 620,
        padding: const EdgeInsets.all(20),
        child: DefaultTabController(
          length: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with Profile Picture, Name, ID & Badges
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child:
                        hasPhoto
                            ? Image.file(
                              File(student.photoPath!),
                              width: 72,
                              height: 72,
                              fit: BoxFit.cover,
                            )
                            : Container(
                              width: 72,
                              height: 72,
                              color: theme.colorScheme.primaryContainer,
                              child: Center(
                                child: Text(
                                  student.name.isNotEmpty
                                      ? student.name[0].toUpperCase()
                                      : 'S',
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onPrimaryContainer,
                                  ),
                                ),
                              ),
                            ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              student.name,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    student.isActive
                                        ? Colors.green.withValues(alpha: 0.12)
                                        : Colors.grey.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                student.isActive ? 'Active' : 'Inactive',
                                style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      student.isActive
                                          ? Colors.green.shade800
                                          : Colors.grey.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 10,
                          children: [
                            Text(
                              '${AppTranslations.text("student_id", lang)}: ${student.studentId}',
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '• ${AppTranslations.text("admission_number", lang)}: ${student.admissionNumber}',
                              style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            if (student.bloodGroup != null)
                              Text(
                                '• Blood: ${student.bloodGroup}',
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                          ],
                        ),
                        if (student.hasTransport ||
                            student.hasHostel ||
                            student.hasLibrary) ...[
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              if (student.hasTransport)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: Colors.blue.shade200,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.directions_bus,
                                        size: 12,
                                        color: Colors.blue.shade700,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Transport',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue.shade900,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (student.hasHostel)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade50,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: Colors.orange.shade200,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.hotel,
                                        size: 12,
                                        color: Colors.orange.shade700,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Hostel',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.orange.shade900,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (student.hasLibrary)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.teal.shade50,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: Colors.teal.shade200,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.local_library,
                                        size: 12,
                                        color: Colors.teal.shade700,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Library',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.teal.shade900,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.card_membership, size: 16),
                    label: const Text('Certificates'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder:
                              (_) => Scaffold(
                                appBar: AppBar(
                                  title: Text('Certificates - ${student.name}'),
                                ),
                                body: CertificatesScreen(
                                  preselectedStudentId: student.id,
                                ),
                              ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Tab Bar
              AppUnderlineTabBar(
                tabs: [
                  Tab(
                    icon: const Icon(Icons.timeline_rounded, size: 20),
                    text: AppTranslations.text('academic_history', lang),
                  ),
                  Tab(
                    icon: const Icon(Icons.person_outline_rounded, size: 20),
                    text: AppTranslations.text('student_details', lang),
                  ),
                  Tab(
                    icon: const Icon(Icons.contact_phone_outlined, size: 20),
                    text: AppTranslations.text('contacts', lang),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Tab Views
              Expanded(
                child: TabBarView(
                  children: [
                    // Tab 1: Academic History Timeline
                    historyAsync.when(
                      data: (histories) {
                        if (histories.isEmpty) {
                          return Center(
                            child: Text(
                              AppTranslations.text('no_history', lang),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          );
                        }

                        return ListView.builder(
                          itemCount: histories.length,
                          itemBuilder: (context, index) {
                            final h = histories[index];
                            final isFirst = index == 0;

                            Color statusColor = Colors.blue;
                            if (h.status == AcademicStatus.active) {
                              statusColor = Colors.green;
                            } else if (h.status == AcademicStatus.retained) {
                              statusColor = Colors.orange;
                            }

                            Color resultColor = Colors.grey;
                            if (h.resultStatus == AcademicResult.passed) {
                              resultColor = Colors.green;
                            } else if (h.resultStatus ==
                                AcademicResult.failed) {
                              resultColor = Colors.red;
                            }

                            return IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Timeline Indicator Column
                                  SizedBox(
                                    width: 32,
                                    child: Column(
                                      children: [
                                        Container(
                                          width: 14,
                                          height: 14,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color:
                                                isFirst
                                                    ? theme.colorScheme.primary
                                                    : theme
                                                        .colorScheme
                                                        .outlineVariant,
                                            border: Border.all(
                                              color: theme.colorScheme.surface,
                                              width: 2,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Container(
                                            width: 2,
                                            color: theme
                                                .colorScheme
                                                .outlineVariant
                                                .withValues(alpha: 0.5),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // Timeline Card
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 14,
                                      ),
                                      child: Card(
                                        elevation: 0,
                                        color:
                                            theme
                                                .colorScheme
                                                .surfaceContainerLow,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          side: BorderSide(
                                            color: theme
                                                .colorScheme
                                                .outlineVariant
                                                .withValues(alpha: 0.4),
                                          ),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(12),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Text(
                                                    'Session: ${h.academicYear.name}',
                                                    style: theme
                                                        .textTheme
                                                        .titleSmall
                                                        ?.copyWith(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                  ),
                                                  Row(
                                                    children: [
                                                      // Result Chip
                                                      Container(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 6,
                                                              vertical: 2,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: resultColor
                                                              .withValues(
                                                                alpha: 0.12,
                                                              ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                4,
                                                              ),
                                                        ),
                                                        child: Text(
                                                          h
                                                              .resultStatus
                                                              .displayName,
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            color: resultColor,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 6),
                                                      // Status Chip
                                                      Container(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 6,
                                                              vertical: 2,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: statusColor
                                                              .withValues(
                                                                alpha: 0.12,
                                                              ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                4,
                                                              ),
                                                        ),
                                                        child: Text(
                                                          h.status.displayName,
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            color: statusColor,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                '${h.schoolClass.displayName} - Section ${h.section.name}${h.rollNumber != null ? " • Roll: ${h.rollNumber}" : ""}',
                                                style: theme
                                                    .textTheme
                                                    .bodyMedium
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                              ),
                                              if (h.remarks != null &&
                                                  h.remarks!.isNotEmpty) ...[
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Note: ${h.remarks}',
                                                  style: theme
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color:
                                                            theme
                                                                .colorScheme
                                                                .onSurfaceVariant,
                                                        fontStyle:
                                                            FontStyle.italic,
                                                      ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                      loading:
                          () =>
                              const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(child: Text('Error: $e')),
                    ),

                    // Tab 2: Personal Details
                    SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailRow(
                            'Gender',
                            student.gender,
                            Icons.person_outline,
                          ),
                          _buildDetailRow(
                            'Date of Birth',
                            student.dateOfBirth != null
                                ? DateFormat(
                                  'yyyy-MM-dd',
                                ).format(student.dateOfBirth!)
                                : 'Not specified',
                            Icons.cake_outlined,
                          ),
                          _buildDetailRow(
                            'Blood Group',
                            student.bloodGroup ?? 'Not specified',
                            Icons.bloodtype_outlined,
                          ),
                          _buildDetailRow(
                            'Address',
                            student.address ?? 'Not specified',
                            Icons.location_on_outlined,
                          ),
                          if (student.phone != null &&
                              student.phone!.isNotEmpty)
                            _buildDetailRow(
                              'Phone',
                              student.phone!,
                              Icons.phone_outlined,
                            ),
                          if (student.email != null &&
                              student.email!.isNotEmpty)
                            _buildDetailRow(
                              'Email',
                              student.email!,
                              Icons.email_outlined,
                            ),
                          _buildDetailRow(
                            'Admission Date',
                            DateFormat(
                              'yyyy-MM-dd',
                            ).format(student.admissionDate),
                            Icons.calendar_today_outlined,
                          ),
                        ],
                      ),
                    ),

                    // Tab 3: Contacts & Guardians
                    contactsAsync.when(
                      data: (contacts) {
                        if (contacts.isEmpty) {
                          return Center(
                            child: Text(
                              AppTranslations.text('no_contacts', lang),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          );
                        }

                        return ListView.separated(
                          itemCount: contacts.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final c = contacts[index];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor:
                                    c.isEmergency
                                        ? Colors.red.withValues(alpha: 0.12)
                                        : theme.colorScheme.primaryContainer,
                                child: Icon(
                                  c.isEmergency
                                      ? Icons.warning_amber_rounded
                                      : Icons.person_rounded,
                                  color:
                                      c.isEmergency
                                          ? Colors.red
                                          : theme.colorScheme.primary,
                                  size: 20,
                                ),
                              ),
                              title: Row(
                                children: [
                                  Text(
                                    c.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (c.relation != null) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 1,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            theme
                                                .colorScheme
                                                .surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        c.relation!,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color:
                                              theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              subtitle: Text(
                                '📞 ${c.phone}${c.occupation != null ? " • ${c.occupation}" : ""}',
                              ),
                              trailing:
                                  c.isPrimary
                                      ? Chip(
                                        label: const Text(
                                          'Primary',
                                          style: TextStyle(fontSize: 11),
                                        ),
                                        backgroundColor: Colors.blue.withValues(
                                          alpha: 0.1,
                                        ),
                                      )
                                      : null,
                            );
                          },
                        );
                      },
                      loading:
                          () =>
                              const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(child: Text('Error: $e')),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 12),
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.black87)),
          ),
        ],
      ),
    );
  }
}
