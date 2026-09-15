// ignore_for_file: deprecated_member_use
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../../config/enums.dart';
import '../../config/extensions.dart';
import '../../config/responsive.dart';
import '../../config/translations.dart';
import '../../data/app_database.dart';
import '../../providers/academic_year_provider.dart';
import '../../providers/class_section_provider.dart';
import '../../providers/database_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/student_provider.dart';
import '../../services/student_service.dart';
import '../../utils/image_storage_helper.dart';
import 'certificates_screen.dart';
import '../../widgets/app_input.dart';
import '../../widgets/forms/student_admission.dart';
import '../../widgets/students/students_list.dart';
import '../../widgets/ui/app_tabs.dart';

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
                          onPressed: () => _openAdmissionPage(context),
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

            StudentsList(
              studentsAsync: studentsAsync,
              languageCode: lang,
              onAddStudent: () => _openAdmissionPage(context),
              onOpenProfile:
                  (student) => _showStudentProfileDialog(context, student),
              onEditStudent:
                  (student) =>
                      _openAdmissionPage(context, existingStudent: student),
              onDeleteStudent:
                  (student) => _confirmDeleteStudent(context, student),
              onOpenCertificates: (student) {
                context.push(
                  Scaffold(
                    appBar: AppBar(
                      title: Text('Certificates - ${student.name}'),
                    ),
                    body: CertificatesScreen(preselectedStudentId: student.id),
                  ),
                );
              },
              onRetry: () => ref.refresh(studentsListStreamProvider),
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

  void _openAdmissionPage(
    BuildContext context, {
    StudentWithDetails? existingStudent,
  }) async {
    final result = await Navigator.of(context).push<AdmissionCompletedData>(
      MaterialPageRoute(
        builder: (_) => StudentAdmissionPage(existingStudent: existingStudent),
      ),
    );
    if (result != null && context.mounted) {
      _showAdmissionFeeReceiptDialog(context, result);
    }
  }

  void _showAdmissionFeeReceiptDialog(
    BuildContext context,
    AdmissionCompletedData result,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        final total = result.plans.fold<double>(
          0,
          (sum, plan) =>
              sum + plan.amount * _admissionFeePeriodCount(plan.frequency),
        );
        final discount = result.plans.fold<double>(
          0,
          (sum, plan) => sum + plan.discountAmount,
        );

        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.receipt_long, color: Colors.indigo),
              SizedBox(width: 8),
              Text('Admission Fee Receipt'),
            ],
          ),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Student: ${result.studentName}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text('Student ID: ${result.studentId}'),
                  Text('Admission No: ${result.admissionNumber}'),
                  const SizedBox(height: 14),
                  const Text(
                    'Assigned fee schedule',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  if (result.plans.isEmpty)
                    const Text('No fee schedule was assigned.'),
                  ...result.plans.map(
                    (plan) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(plan.title),
                      subtitle: Text(
                        '${plan.frequency.replaceAll('_', ' ')} • ${_admissionFeePeriodCount(plan.frequency)} record(s) • Pending',
                      ),
                      trailing: Text(
                        _formatAdmissionCurrency(
                          plan.amount *
                              _admissionFeePeriodCount(plan.frequency),
                        ),
                      ),
                    ),
                  ),
                  const Divider(),
                  _admissionTotalRow('Total assessed', total),
                  if (discount > 0)
                    _admissionTotalRow('Scholarship / discount', -discount),
                  _admissionTotalRow('Net payable', total - discount),
                  if (result.feeError != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Fee assignment warning: ${result.feeError}',
                      style: const TextStyle(color: Colors.orange),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.print),
              label: const Text('Print Fee Receipt'),
              onPressed: () {
                Navigator.pop(dialogContext);
                context.showSnackbar(
                  'Admission fee receipt for ${result.studentName} sent to printer.',
                  type: MessageType.success,
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _admissionTotalRow(String label, double amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label), Text(_formatAdmissionCurrency(amount))],
      ),
    );
  }

  String _formatAdmissionCurrency(double amount) {
    return 'Rs. ${NumberFormat('#,##0.00').format(amount)}';
  }

  int _admissionFeePeriodCount(String frequency) {
    switch (frequency.toLowerCase()) {
      case 'one_time':
      case 'yearly':
        return 1;
      case 'quarterly':
        return 4;
      case 'half_yearly':
        return 2;
      case 'term_wise':
        return 3;
      case 'monthly':
      default:
        return 12;
    }
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
                onPressed: () => context.pop(),
                child: Text(AppTranslations.text('cancel', lang)),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () async {
                  context.pop();
                  final success = await ref
                      .read(studentControllerProvider.notifier)
                      .deleteStudent(student.id);
                  if (context.mounted) {
                    context.showSnackbar(
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
          onPressed: _isPromoting ? null : () => context.pop(),
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
      context.showSnackbar(
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
        context.pop();
        context.showSnackbar(
          const SnackBar(content: Text('Students promoted successfully!')),
        );
      } else {
        context.showSnackbar(
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
                      context.push(
                        Scaffold(
                          appBar: AppBar(
                            title: Text('Certificates - ${student.name}'),
                          ),
                          body: CertificatesScreen(
                            preselectedStudentId: student.id,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => context.pop(),
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
