import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:path/path.dart' as p;

import '../config/enums.dart';
import '../config/responsive.dart';
import '../config/translations.dart';
import '../data/app_database.dart';
import '../providers/calendar_provider.dart';
import '../providers/employee_provider.dart';
import '../providers/locale_provider.dart';
import '../services/app_media_service.dart';
import '../utils/date_time_utils.dart';
import '../utils/validators.dart';
import '../widgets/app_input.dart';
import '../widgets/dual_date_picker.dart';
import '../widgets/ui/app_button.dart';
import '../widgets/ui/app_empty_state.dart';
import '../widgets/ui/app_error_view.dart';
import '../widgets/ui/app_skeleton.dart';

class TeachersScreen extends ConsumerStatefulWidget {
  const TeachersScreen({super.key});

  @override
  ConsumerState<TeachersScreen> createState() => _TeachersScreenState();
}

class _TeachersScreenState extends ConsumerState<TeachersScreen> {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedDepartment;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final teachersAsync = ref.watch(teachersStreamProvider);
    final currentLang = ref.watch(localeProvider);
    final langCode = currentLang.locale.languageCode;
    final isNepali = langCode == 'ne';
    final calendarMode = ref.watch(calendarProvider);

    return Scaffold(
      body: teachersAsync.when(
        data: (teachers) {
          final totalCount = teachers.length;
          final activeCount = teachers.where((t) => t.isActive).length;
          final departments =
              teachers
                  .map((t) => t.department)
                  .where((d) => d != null && d.trim().isNotEmpty)
                  .cast<String>()
                  .toSet()
                  .toList()
                ..sort();

          final filtered =
              teachers.where((t) {
                if (_selectedDepartment != null &&
                    t.department != _selectedDepartment) {
                  return false;
                }
                return true;
              }).toList();

          return ResponsiveScaffoldWrapper(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: context.responsive(
                  mobile: 16,
                  tablet: 24,
                  desktop: 32,
                ),
                vertical: 20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  _buildHeader(
                    context,
                    totalCount,
                    activeCount,
                    departments.length,
                    langCode,
                  ),
                  const SizedBox(height: 16),

                  // Search Bar & Department Filter
                  _buildSearchBarAndFilter(context, departments, langCode),
                  const SizedBox(height: 20),

                  // Teacher List / Grid
                  if (filtered.isEmpty)
                    _buildEmptyState(context, langCode)
                  else
                    _buildTeachersGrid(
                      context,
                      filtered,
                      langCode,
                      isNepali,
                      calendarMode,
                    ),
                ],
              ),
            ),
          );
        },
        loading: () => AppSkeleton.cards(count: 6),
        error:
            (err, stack) => Center(
              child: AppErrorView(
                error: err,
                stackTrace: stack,
                onRetry: () => ref.refresh(teachersStreamProvider),
              ),
            ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openTeacherDialog(context, null, langCode),
        icon: const Icon(Icons.person_add),
        label: Text(AppTranslations.text('add_teacher', langCode)),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    int totalCount,
    int activeCount,
    int deptCount,
    String langCode,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withAlpha(20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withAlpha(40),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppTranslations.text('teachers', langCode),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    langCode == 'ne'
                        ? 'शिक्षक विवरण, पद, योग्यता र व्यक्तिगत जानकारी'
                        : 'Faculty management, designations, qualifications & details',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              FilledButton.icon(
                onPressed: () => _openTeacherDialog(context, null, langCode),
                icon: const Icon(Icons.add, size: 18),
                label: Text(AppTranslations.text('add_teacher', langCode)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _buildMetricChip(
                context,
                Icons.people_outline,
                '${AppTranslations.text('teachers', langCode)}: $totalCount',
              ),
              _buildMetricChip(
                context,
                Icons.check_circle_outline,
                '${AppTranslations.text('active', langCode)}: $activeCount',
                color: Colors.green,
              ),
              _buildMetricChip(
                context,
                Icons.category_outlined,
                '${AppTranslations.text('department', langCode)}: $deptCount',
                color: Colors.purple,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricChip(
    BuildContext context,
    IconData icon,
    String label, {
    Color? color,
  }) {
    final effectiveColor = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: effectiveColor.withAlpha(25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: effectiveColor.withAlpha(60)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: effectiveColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: effectiveColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBarAndFilter(
    BuildContext context,
    List<String> departments,
    String langCode,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: AppSearchField(
                controller: _searchController,
                hintText:
                    langCode == 'ne'
                        ? 'शिक्षकको नाम, पद वा कोड खोज्नुहोस्...'
                        : 'Search by teacher name, designation, or code...',
                onChanged: (val) {
                  ref.read(teacherSearchQueryProvider.notifier).setQuery(val);
                },
                onClear: () {
                  ref.read(teacherSearchQueryProvider.notifier).setQuery('');
                },
              ),
            ),
          ],
        ),
        if (departments.isNotEmpty) ...[
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: Text(langCode == 'ne' ? 'सबै विभाग' : 'All Depts'),
                  selected: _selectedDepartment == null,
                  onSelected: (selected) {
                    setState(() {
                      _selectedDepartment = null;
                    });
                  },
                ),
                const SizedBox(width: 8),
                ...departments.map((dept) {
                  final isSelected = _selectedDepartment == dept;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(dept),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _selectedDepartment = selected ? dept : null;
                        });
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, String langCode) {
    if (_searchController.text.trim().isNotEmpty ||
        _selectedDepartment != null) {
      return AppEmptyState.search(
        query: _searchController.text.trim(),
        title: langCode == 'ne' ? 'शिक्षक फेला परेन' : 'No matching teachers',
        onClear: () {
          _searchController.clear();
          setState(() {
            _selectedDepartment = null;
          });
        },
      );
    }
    return AppEmptyState.noData(
      title: AppTranslations.text('no_teachers', langCode),
      subtitle:
          langCode == 'ne'
              ? 'कुनै शिक्षक थपिएका छैनन्। नयाँ शिक्षक थप्न तल क्लिक गर्नुहोस्।'
              : 'No teachers registered in the system yet.',
      icon: Icons.school_outlined,
      action: AppButton.primary(
        onPressed: () => _openTeacherDialog(context, null, langCode),
        leadingIcon: const Icon(Icons.add, size: 16),
        text: AppTranslations.text('add_teacher', langCode),
      ),
    );
  }

  Widget _buildTeachersGrid(
    BuildContext context,
    List<Employee> teachers,
    String langCode,
    bool isNepali,
    dynamic calendarMode,
  ) {
    final isDesktop = context.isDesktop;
    final isTablet = context.isTablet;

    if (isDesktop) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          mainAxisExtent: 310,
        ),
        itemCount: teachers.length,
        itemBuilder:
            (context, index) => _buildTeacherCard(
              context,
              teachers[index],
              langCode,
              isNepali,
              calendarMode,
            ),
      );
    }

    if (isTablet) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          mainAxisExtent: 310,
        ),
        itemCount: teachers.length,
        itemBuilder:
            (context, index) => _buildTeacherCard(
              context,
              teachers[index],
              langCode,
              isNepali,
              calendarMode,
            ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: teachers.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder:
          (context, index) => _buildTeacherCard(
            context,
            teachers[index],
            langCode,
            isNepali,
            calendarMode,
          ),
    );
  }

  Widget _buildTeacherCard(
    BuildContext context,
    Employee teacher,
    String langCode,
    bool isNepali,
    dynamic calendarMode,
  ) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withAlpha(80)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: Avatar, Name, Designation, and Status
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: primaryColor.withAlpha(30),
                  backgroundImage:
                      teacher.photoPath != null &&
                              AppMediaService.isLocalFile(teacher.photoPath)
                          ? FileImage(File(teacher.photoPath!))
                          : null,
                  child:
                      (teacher.photoPath != null &&
                              AppMediaService.isLocalFile(teacher.photoPath))
                          ? null
                          : Text(
                            teacher.name.isNotEmpty
                                ? teacher.name
                                    .trim()
                                    .substring(0, 1)
                                    .toUpperCase()
                                : 'T',
                            style: TextStyle(
                              color: primaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
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
                              teacher.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (teacher.employeeCode != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                teacher.employeeCode!,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: primaryColor.withAlpha(20),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          teacher.designation,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: primaryColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Department & Qualification Badges
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (teacher.department != null)
                  _buildTag(
                    context,
                    Icons.business_outlined,
                    teacher.department!,
                    Colors.indigo,
                  ),
                if (teacher.qualification != null)
                  _buildTag(
                    context,
                    Icons.school_outlined,
                    teacher.qualification!,
                    Colors.teal,
                  ),
                if (teacher.bloodGroup != null)
                  _buildTag(
                    context,
                    Icons.bloodtype,
                    teacher.bloodGroup!,
                    Colors.redAccent,
                  ),
                if (teacher.gender != null)
                  _buildTag(
                    context,
                    Icons.person_outline,
                    teacher.gender!,
                    Colors.blueGrey,
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // Contact Information
            if (teacher.phone != null && teacher.phone!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.phone_outlined,
                      size: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      teacher.phone!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

            if (teacher.email != null && teacher.email!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.email_outlined,
                      size: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        teacher.email!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

            if (teacher.address != null && teacher.address!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        teacher.address!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

            if (teacher.dateOfBirth != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.cake_outlined,
                      size: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'DOB: ${DateTimeUtils.formatDateByMode(teacher.dateOfBirth!, mode: calendarMode, inNepaliScript: isNepali)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

            const Spacer(),
            const Divider(height: 12),

            // Actions Row
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  tooltip: AppTranslations.text('edit_teacher', langCode),
                  onPressed:
                      () => _openTeacherDialog(context, teacher, langCode),
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: theme.colorScheme.error,
                  ),
                  tooltip: AppTranslations.text('delete_teacher', langCode),
                  onPressed:
                      () => _confirmDeleteTeacher(context, teacher, langCode),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(
    BuildContext context,
    IconData icon,
    String text,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteTeacher(
    BuildContext context,
    Employee teacher,
    String langCode,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(AppTranslations.text('delete_teacher', langCode)),
            content: Text(
              langCode == 'ne'
                  ? 'के तपाईं शिक्षक "${teacher.name}" लाई हटाउन निश्चित हुनुहुन्छ?'
                  : 'Are you sure you want to delete teacher "${teacher.name}"?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(AppTranslations.text('cancel', langCode)),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(ctx).colorScheme.error,
                ),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(AppTranslations.text('delete', langCode)),
              ),
            ],
          ),
    );

    if (confirmed == true && mounted) {
      await ref
          .read(employeeControllerProvider.notifier)
          .deleteEmployee(teacher.id);
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              langCode == 'ne'
                  ? 'शिक्षक सफलतापूर्वक हटाइयो'
                  : 'Teacher deleted successfully',
            ),
          ),
        );
      }
    }
  }

  void _openTeacherDialog(
    BuildContext context,
    Employee? teacher,
    String langCode,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => _TeacherFormDialog(teacher: teacher, langCode: langCode),
    );
  }
}

class _TeacherFormDialog extends ConsumerStatefulWidget {
  final Employee? teacher;
  final String langCode;

  const _TeacherFormDialog({required this.teacher, required this.langCode});

  @override
  ConsumerState<_TeacherFormDialog> createState() => _TeacherFormDialogState();
}

class _TeacherFormDialogState extends ConsumerState<_TeacherFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _designationController;
  late TextEditingController _departmentController;
  late TextEditingController _qualificationController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _addressController;

  String? _gender;
  String? _bloodGroup;
  DateTime? _dob;
  DateTime? _joiningDate;
  bool _isActive = true;
  String? _photoPath;

  final List<String> _designationSuggestions = [
    'Senior Mathematics Teacher',
    'English Department Head',
    'Science & Technology Teacher',
    'Nepali Language Specialist',
    'Social Studies Teacher',
    'Computer Science Teacher',
    'Health & PE Teacher',
    'Primary Art & Craft Teacher',
    'Pre-Primary Facilitator',
  ];

  final List<String> _bloodGroups = [
    'A+',
    'A-',
    'B+',
    'B-',
    'O+',
    'O-',
    'AB+',
    'AB-',
  ];

  final List<String> _genders = ['Male', 'Female', 'Other'];

  @override
  void initState() {
    super.initState();
    final t = widget.teacher;
    _nameController = TextEditingController(text: t?.name ?? '');
    _designationController = TextEditingController(
      text: t?.designation ?? 'Subject Teacher',
    );
    _departmentController = TextEditingController(text: t?.department ?? '');
    _qualificationController = TextEditingController(
      text: t?.qualification ?? '',
    );
    _phoneController = TextEditingController(text: t?.phone ?? '');
    _emailController = TextEditingController(text: t?.email ?? '');
    _addressController = TextEditingController(text: t?.address ?? '');
    _gender = t?.gender;
    _bloodGroup = t?.bloodGroup;
    _dob = t?.dateOfBirth;
    _joiningDate = t?.joiningDate;
    _isActive = t?.isActive ?? true;
    _photoPath = t?.photoPath;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _designationController.dispose();
    _departmentController.dispose();
    _qualificationController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.teacher != null;
    final langCode = widget.langCode;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Dialog Title
                Row(
                  children: [
                    Icon(
                      isEditing ? Icons.edit : Icons.person_add,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isEditing
                          ? AppTranslations.text('edit_teacher', langCode)
                          : AppTranslations.text('add_teacher', langCode),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 8),

                // Scrollable Form Fields
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Section 1: Professional Details
                        Text(
                          AppTranslations.text(
                            'professional_details',
                            langCode,
                          ),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Profile Photo Upload
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest.withAlpha(50),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Theme.of(
                                context,
                              ).dividerColor.withAlpha(80),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 70,
                                height: 70,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Theme.of(context).dividerColor,
                                  ),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child:
                                    _photoPath != null &&
                                            AppMediaService.isLocalFile(
                                              _photoPath,
                                            )
                                        ? Image.file(
                                          File(_photoPath!),
                                          fit: BoxFit.cover,
                                        )
                                        : Icon(
                                          Icons.person_outline,
                                          size: 36,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary.withAlpha(120),
                                        ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      AppTranslations.text('photo', langCode),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _photoPath != null &&
                                              _photoPath!.isNotEmpty
                                          ? p.basename(_photoPath!)
                                          : (langCode == 'ne'
                                              ? 'शिक्षकको फोटो छान्नुहोस्'
                                              : 'Stored in sms_media/employees'),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color:
                                            Theme.of(
                                              context,
                                            ).textTheme.bodySmall?.color,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: () async {
                                  final path =
                                      await AppMediaService.pickAndSaveEmployeePhoto(
                                        employeeCode:
                                            widget.teacher?.employeeCode,
                                      );
                                  if (path != null) {
                                    setState(() => _photoPath = path);
                                  }
                                },
                                icon: const Icon(
                                  Icons.photo_camera_outlined,
                                  size: 16,
                                ),
                                label: Text(
                                  _photoPath != null
                                      ? (langCode == 'ne'
                                          ? 'फेर्नुहोस्'
                                          : 'Change')
                                      : (langCode == 'ne'
                                          ? 'फोटो छान्नुहोस्'
                                          : 'Upload Photo'),
                                ),
                              ),
                              if (_photoPath != null &&
                                  _photoPath!.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                IconButton(
                                  tooltip: 'Remove photo',
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.redAccent,
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    setState(() => _photoPath = null);
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),

                        // Name
                        TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText:
                                '${AppTranslations.text('teachers', langCode)} Name *',
                            prefixIcon: const Icon(Icons.person_outline),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Please enter teacher name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        // Designation
                        TextFormField(
                          controller: _designationController,
                          decoration: InputDecoration(
                            labelText:
                                '${AppTranslations.text('designation', langCode)} *',
                            prefixIcon: const Icon(Icons.badge_outlined),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Please enter designation';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 6),

                        // Quick designation chips
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children:
                              _designationSuggestions.take(4).map((d) {
                                return ActionChip(
                                  label: Text(
                                    d,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _designationController.text = d;
                                    });
                                  },
                                );
                              }).toList(),
                        ),
                        const SizedBox(height: 12),

                        // Department
                        TextFormField(
                          controller: _departmentController,
                          decoration: InputDecoration(
                            labelText: AppTranslations.text(
                              'department',
                              langCode,
                            ),
                            hintText: 'e.g. Science, Mathematics',
                            prefixIcon: const Icon(Icons.domain),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Qualification
                        TextFormField(
                          controller: _qualificationController,
                          decoration: InputDecoration(
                            labelText: AppTranslations.text(
                              'qualification',
                              langCode,
                            ),
                            hintText: 'e.g. M.Sc. Physics, B.Ed',
                            prefixIcon: const Icon(Icons.school_outlined),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Section 2: Personal & Contact Information
                        Text(
                          AppTranslations.text('optional_info', langCode),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Phone & Email
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                decoration: InputDecoration(
                                  labelText: AppTranslations.text(
                                    'phone',
                                    langCode,
                                  ),
                                  prefixIcon: const Icon(Icons.phone_outlined),
                                ),
                                validator: (val) {
                                  if (val != null && val.trim().isNotEmpty) {
                                    return Validators.validatePhone(val.trim());
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: InputDecoration(
                                  labelText: AppTranslations.text(
                                    'email',
                                    langCode,
                                  ),
                                  prefixIcon: const Icon(Icons.email_outlined),
                                ),
                                validator: (val) {
                                  if (val != null && val.trim().isNotEmpty) {
                                    return Validators.validateEmail(val.trim());
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Gender & Blood Group
                        Row(
                          children: [
                            Expanded(
                              child: AppSearchableSelect<String>(
                                value: _gender,
                                label: AppTranslations.text('gender', langCode),
                                prefixIcon: const Icon(Icons.person_outline),
                                isClearable: true,
                                hint: 'Not Specified',
                                items:
                                    _genders
                                        .map(
                                          (g) => SearchableSelectItem<String>(
                                            value: g,
                                            label: g,
                                          ),
                                        )
                                        .toList(),
                                onChanged:
                                    (val) => setState(() => _gender = val),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: AppSearchableSelect<String>(
                                value: _bloodGroup,
                                label: AppTranslations.text(
                                  'blood_group',
                                  langCode,
                                ),
                                prefixIcon: const Icon(Icons.bloodtype),
                                isClearable: true,
                                hint: 'Not Specified',
                                items:
                                    _bloodGroups
                                        .map(
                                          (bg) => SearchableSelectItem<String>(
                                            value: bg,
                                            label: bg,
                                          ),
                                        )
                                        .toList(),
                                onChanged:
                                    (val) => setState(() => _bloodGroup = val),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Date of Birth (Dual Date Picker)
                        DualDatePickerField(
                          label: AppTranslations.text(
                            'date_of_birth',
                            langCode,
                          ),
                          selectedDate: _dob,
                          firstDate: DateTime(1950),
                          lastDate: DateTime.now(),
                          onDateSelected: (date) {
                            setState(() {
                              _dob = date;
                            });
                          },
                        ),
                        const SizedBox(height: 12),

                        // Address
                        TextFormField(
                          controller: _addressController,
                          decoration: InputDecoration(
                            labelText: AppTranslations.text(
                              'address',
                              langCode,
                            ),
                            hintText: 'e.g. Kathmandu-10, Baneshwor',
                            prefixIcon: const Icon(Icons.location_on_outlined),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Active status toggle
                        SwitchListTile(
                          title: Text(AppTranslations.text('active', langCode)),
                          value: _isActive,
                          onChanged: (val) => setState(() => _isActive = val),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Dialog Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(AppTranslations.text('cancel', langCode)),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: _saveTeacher,
                      child: Text(AppTranslations.text('save', langCode)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveTeacher() async {
    if (!_formKey.currentState!.validate()) return;

    final controller = ref.read(employeeControllerProvider.notifier);
    final isEditing = widget.teacher != null;

    try {
      if (isEditing) {
        await controller.updateEmployee(
          id: widget.teacher!.id,
          name: _nameController.text.trim(),
          employeeType: EmployeeType.teacher,
          designation: _designationController.text.trim(),
          employeeCode: widget.teacher!.employeeCode,
          department: _departmentController.text.trim(),
          qualification: _qualificationController.text.trim(),
          phone: _phoneController.text.trim(),
          email: _emailController.text.trim(),
          photoPath: _photoPath,
          gender: _gender,
          bloodGroup: _bloodGroup,
          dateOfBirth: _dob,
          address: _addressController.text.trim(),
          joiningDate: _joiningDate,
          isActive: _isActive,
        );
      } else {
        await controller.createEmployee(
          name: _nameController.text.trim(),
          employeeType: EmployeeType.teacher,
          designation: _designationController.text.trim(),
          department: _departmentController.text.trim(),
          qualification: _qualificationController.text.trim(),
          phone: _phoneController.text.trim(),
          email: _emailController.text.trim(),
          photoPath: _photoPath,
          gender: _gender,
          bloodGroup: _bloodGroup,
          dateOfBirth: _dob,
          address: _addressController.text.trim(),
          joiningDate: _joiningDate,
          isActive: _isActive,
        );
      }

      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.of(context).pop();
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              isEditing
                  ? 'Teacher updated successfully'
                  : 'Teacher added successfully',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
