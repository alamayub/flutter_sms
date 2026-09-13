import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../config/enums.dart';
import '../../config/extensions.dart';
import '../../config/responsive.dart';
import '../../config/translations.dart';
import '../../data/app_database.dart';
import '../../providers/calendar_provider.dart';
import '../../providers/employee_provider.dart';
import '../../providers/locale_provider.dart';
import '../../utils/date_time_utils.dart';
import '../../utils/image_storage_helper.dart';
import '../../utils/validators.dart';
import '../../widgets/app_input.dart';
import '../../widgets/dual_date_picker.dart';

class EmployeesScreen extends ConsumerStatefulWidget {
  const EmployeesScreen({super.key});

  @override
  ConsumerState<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends ConsumerState<EmployeesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedDepartment;
  bool? _selectedStatus; // null = all, true = active, false = inactive

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final employeesAsync = ref.watch(employeesStreamProvider);
    final selectedType = ref.watch(selectedEmployeeTypeFilterProvider);
    final currentLang = ref.watch(localeProvider);
    final langCode = currentLang.locale.languageCode;
    final isNepali = langCode == 'ne';
    final calendarMode = ref.watch(calendarProvider);

    return Scaffold(
      body: employeesAsync.when(
        data: (employees) {
          final totalCount = employees.length;
          final activeCount = employees.where((e) => e.isActive).length;
          final teachersCount =
              employees
                  .where((e) => e.employeeType == EmployeeType.teacher)
                  .length;
          final staffCount =
              employees
                  .where((e) => e.employeeType == EmployeeType.staff)
                  .length;

          final departments =
              employees
                  .map((e) => e.department)
                  .where((d) => d != null && d.trim().isNotEmpty)
                  .cast<String>()
                  .toSet()
                  .toList()
                ..sort();

          final filtered =
              employees.where((e) {
                if (_selectedDepartment != null &&
                    e.department != _selectedDepartment) {
                  return false;
                }
                if (_selectedStatus != null && e.isActive != _selectedStatus) {
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
                  // Header Banner & Statistics
                  _buildHeader(
                    context,
                    totalCount: totalCount,
                    activeCount: activeCount,
                    teachersCount: teachersCount,
                    staffCount: staffCount,
                    langCode: langCode,
                  ),
                  const SizedBox(height: 16),

                  // Filter Chips (All, Teachers, Staff) & Search Controls
                  _buildFilterBar(context, selectedType, departments, langCode),
                  const SizedBox(height: 20),

                  // Employees List / Grid
                  if (filtered.isEmpty)
                    _buildEmptyState(context, langCode)
                  else
                    _buildEmployeesGrid(
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
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (err, stack) => Center(
              child: SelectableText.rich(
                TextSpan(
                  text: 'Error loading employees: $err',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEmployeeDialog(context, null, langCode),
        icon: const Icon(Icons.person_add),
        label: Text(AppTranslations.text('add_employee', langCode)),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context, {
    required int totalCount,
    required int activeCount,
    required int teachersCount,
    required int staffCount,
    required String langCode,
  }) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: primaryColor.withAlpha(20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryColor.withAlpha(40)),
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
                    AppTranslations.text('employees', langCode),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    langCode == 'ne'
                        ? 'शिक्षक तथा कर्मचारीहरूको एकीकृत व्यवस्थापन'
                        : 'Unified Faculty & Staff Directory Management',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              FilledButton.icon(
                onPressed: () => _openEmployeeDialog(context, null, langCode),
                icon: const Icon(Icons.add),
                label: Text(AppTranslations.text('add_employee', langCode)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _buildStatChip(
                context,
                Icons.people,
                '${AppTranslations.text('all_employees', langCode)}: $totalCount',
                primaryColor,
              ),
              _buildStatChip(
                context,
                Icons.school,
                '${AppTranslations.text('teachers', langCode)}: $teachersCount',
                Colors.indigo,
              ),
              _buildStatChip(
                context,
                Icons.badge,
                '${AppTranslations.text('staff', langCode)}: $staffCount',
                Colors.teal,
              ),
              _buildStatChip(
                context,
                Icons.check_circle_outline,
                '${AppTranslations.text('active', langCode)}: $activeCount',
                Colors.green,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(
    BuildContext context,
    IconData icon,
    String text,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(
    BuildContext context,
    EmployeeType? selectedType,
    List<String> departments,
    String langCode,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Type filter segmented tabs: All | Teachers | Staff
        Row(
          children: [
            SegmentedButton<EmployeeType?>(
              segments: [
                ButtonSegment<EmployeeType?>(
                  value: null,
                  label: Text(AppTranslations.text('all_employees', langCode)),
                  icon: const Icon(Icons.people_alt_outlined),
                ),
                ButtonSegment<EmployeeType?>(
                  value: EmployeeType.teacher,
                  label: Text(AppTranslations.text('teachers', langCode)),
                  icon: const Icon(Icons.school_outlined),
                ),
                ButtonSegment<EmployeeType?>(
                  value: EmployeeType.staff,
                  label: Text(AppTranslations.text('staff', langCode)),
                  icon: const Icon(Icons.badge_outlined),
                ),
              ],
              selected: {selectedType},
              onSelectionChanged: (newSelection) {
                ref
                    .read(selectedEmployeeTypeFilterProvider.notifier)
                    .setType(newSelection.first);
              },
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Search textfield & Department dropdown
        Row(
          children: [
            Expanded(
              child: AppSearchField(
                controller: _searchController,
                hintText:
                    langCode == 'ne'
                        ? 'नाम, कोड वा फोनबाट खोज्नुहोस्...'
                        : 'Search by name, code, phone, emergency contact...',
                onChanged: (val) {
                  ref.read(employeeSearchQueryProvider.notifier).setQuery(val);
                },
                onClear: () {
                  ref.read(employeeSearchQueryProvider.notifier).setQuery('');
                },
              ),
            ),
            const SizedBox(width: 12),
            if (departments.isNotEmpty) ...[
              SizedBox(
                width: 180,
                child: AppSearchableSelect<String>.filter(
                  value: _selectedDepartment,
                  hint: AppTranslations.text('department', langCode),
                  items:
                      departments
                          .map(
                            (dept) => SearchableSelectItem<String>(
                              value: dept,
                              label: dept,
                            ),
                          )
                          .toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedDepartment = val;
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
            ],
            // Active / Inactive Status filter
            SizedBox(
              width: 160,
              child: AppSearchableSelect<bool>.filter(
                value: _selectedStatus,
                hint: AppTranslations.text('filter', langCode),
                items: [
                  SearchableSelectItem<bool>(
                    value: true,
                    label: AppTranslations.text('active', langCode),
                  ),
                  SearchableSelectItem<bool>(
                    value: false,
                    label: AppTranslations.text('inactive', langCode),
                  ),
                ],
                onChanged: (val) {
                  setState(() {
                    _selectedStatus = val;
                  });
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, String langCode) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              AppTranslations.text('no_employees', langCode),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: () => _openEmployeeDialog(context, null, langCode),
              icon: const Icon(Icons.add),
              label: Text(AppTranslations.text('add_employee', langCode)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmployeesGrid(
    BuildContext context,
    List<Employee> employees,
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
          mainAxisExtent: 380,
        ),
        itemCount: employees.length,
        itemBuilder:
            (context, index) => _buildEmployeeCard(
              context,
              employees[index],
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
          mainAxisExtent: 380,
        ),
        itemCount: employees.length,
        itemBuilder:
            (context, index) => _buildEmployeeCard(
              context,
              employees[index],
              langCode,
              isNepali,
              calendarMode,
            ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: employees.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder:
          (context, index) => _buildEmployeeCard(
            context,
            employees[index],
            langCode,
            isNepali,
            calendarMode,
          ),
    );
  }

  Widget _buildEmployeeCard(
    BuildContext context,
    Employee employee,
    String langCode,
    bool isNepali,
    dynamic calendarMode,
  ) {
    final theme = Theme.of(context);
    final isTeacher = employee.employeeType == EmployeeType.teacher;
    final roleColor = isTeacher ? Colors.indigo : Colors.teal;
    final hasEmergencyContact =
        (employee.emergencyContactName != null &&
            employee.emergencyContactName!.isNotEmpty) ||
        (employee.emergencyContactPhone != null &&
            employee.emergencyContactPhone!.isNotEmpty);

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
            // Top Row: Avatar / Photo, Name, Code, and Status
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAvatar(employee, roleColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              employee.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Active status pill
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  employee.isActive
                                      ? Colors.green.withAlpha(25)
                                      : Colors.grey.withAlpha(25),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              employee.isActive
                                  ? AppTranslations.text('active', langCode)
                                  : AppTranslations.text('inactive', langCode),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color:
                                    employee.isActive
                                        ? Colors.green
                                        : Colors.grey,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          // Type badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: roleColor.withAlpha(25),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isTeacher
                                  ? AppTranslations.text('teachers', langCode)
                                  : AppTranslations.text('staff', langCode),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: roleColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Employee Code Badge
                          if (employee.employeeCode != null &&
                              employee.employeeCode!.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                employee.employeeCode!,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Designation & Department
            Text(
              employee.designation,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (employee.department != null &&
                employee.department!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                employee.department!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 8),

            // Contacts (Phone & Email)
            if (employee.phone != null && employee.phone!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(
                  children: [
                    Icon(
                      Icons.phone_outlined,
                      size: 13,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        employee.phone!,
                        style: theme.textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            if (employee.email != null && employee.email!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(
                  children: [
                    Icon(
                      Icons.email_outlined,
                      size: 13,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        employee.email!,
                        style: theme.textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

            // Emergency Contact Card
            if (hasEmergencyContact) ...[
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.amber.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.withAlpha(60)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.emergency_outlined,
                          size: 13,
                          color: Colors.amber,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          AppTranslations.text('emergency_contact', langCode),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${employee.emergencyContactName ?? "N/A"}${employee.emergencyContactRelation != null ? " (${employee.emergencyContactRelation})" : ""}: ${employee.emergencyContactPhone ?? ""}',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 6),
            // Tags Row: Blood Group, Marital Status, Gender
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (employee.bloodGroup != null)
                  _buildTag(
                    context,
                    Icons.bloodtype_outlined,
                    employee.bloodGroup!,
                    Colors.redAccent,
                  ),
                if (employee.maritalStatus != null)
                  _buildTag(
                    context,
                    Icons.favorite_border,
                    employee.maritalStatus!,
                    Colors.purple,
                  ),
                if (employee.gender != null)
                  _buildTag(
                    context,
                    employee.gender == 'Male'
                        ? Icons.male
                        : employee.gender == 'Female'
                        ? Icons.female
                        : Icons.transgender,
                    employee.gender!,
                    Colors.blueGrey,
                  ),
              ],
            ),

            const Spacer(),
            const Divider(height: 12),

            // Card Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (employee.joiningDate != null)
                  Text(
                    'Joined: ${DateTimeUtils.formatDateByMode(employee.joiningDate!, mode: calendarMode, inNepaliScript: isNepali)}',
                    style: TextStyle(
                      fontSize: 10,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  )
                else
                  const SizedBox(),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      tooltip: AppTranslations.text('edit_employee', langCode),
                      onPressed:
                          () =>
                              _openEmployeeDialog(context, employee, langCode),
                      visualDensity: VisualDensity.compact,
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: theme.colorScheme.error,
                      ),
                      tooltip: AppTranslations.text(
                        'delete_employee',
                        langCode,
                      ),
                      onPressed:
                          () => _confirmDeleteEmployee(
                            context,
                            employee,
                            langCode,
                          ),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(Employee employee, Color roleColor) {
    final photo = employee.photoPath?.trim();
    if (photo != null && photo.isNotEmpty) {
      if (ImageStorageHelper.isLocalFile(photo)) {
        return CircleAvatar(
          radius: 24,
          backgroundImage: FileImage(File(photo)),
          backgroundColor: roleColor.withAlpha(30),
        );
      } else if (photo.startsWith('http')) {
        return CircleAvatar(
          radius: 24,
          backgroundImage: NetworkImage(photo),
          backgroundColor: roleColor.withAlpha(30),
        );
      }
    }

    return CircleAvatar(
      radius: 24,
      backgroundColor: roleColor.withAlpha(30),
      child: Text(
        employee.name.isNotEmpty
            ? employee.name.trim().substring(0, 1).toUpperCase()
            : 'E',
        style: TextStyle(
          color: roleColor,
          fontWeight: FontWeight.bold,
          fontSize: 18,
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
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteEmployee(
    BuildContext context,
    Employee employee,
    String langCode,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(AppTranslations.text('delete_employee', langCode)),
            content: Text(
              langCode == 'ne'
                  ? 'के तपाईं कर्मचारी "${employee.name}" लाई हटाउन निश्चित हुनुहुन्छ?'
                  : 'Are you sure you want to delete employee "${employee.name}"?',
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
          .deleteEmployee(employee.id);
      if (mounted) {
        context.showSnackbar(
          SnackBar(
            content: Text(
              langCode == 'ne'
                  ? 'कर्मचारी सफलतापूर्वक हटाइयो'
                  : 'Employee deleted successfully',
            ),
          ),
        );
      }
    }
  }

  void _openEmployeeDialog(
    BuildContext context,
    Employee? employee,
    String langCode,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => _EmployeeFormDialog(employee: employee, langCode: langCode),
    );
  }
}

class _EmployeeFormDialog extends ConsumerStatefulWidget {
  final Employee? employee;
  final String langCode;

  const _EmployeeFormDialog({required this.employee, required this.langCode});

  @override
  ConsumerState<_EmployeeFormDialog> createState() =>
      _EmployeeFormDialogState();
}

class _EmployeeFormDialogState extends ConsumerState<_EmployeeFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late EmployeeType _employeeType;
  late TextEditingController _nameController;
  late TextEditingController _designationController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _addressController;

  // Auto-generated employee code state
  String _generatedCode = '';
  bool _loadingCode = false;

  // Local photo path state
  String? _photoPath;

  // Emergency contact controllers
  late TextEditingController _emergencyNameController;
  late TextEditingController _emergencyPhoneController;
  String? _emergencyRelation;

  // Personal controllers & state
  String? _gender;
  String? _bloodGroup;
  String? _maritalStatus;
  DateTime? _dob;

  // Professional controllers & state
  late TextEditingController _departmentController;
  late TextEditingController _qualificationController;
  late TextEditingController _salaryController;
  DateTime? _joiningDate;
  bool _isActive = true;

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
  final List<String> _maritalStatuses = [
    'Single',
    'Married',
    'Divorced',
    'Widowed',
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.employee;
    _employeeType = e?.employeeType ?? EmployeeType.teacher;
    _nameController = TextEditingController(text: e?.name ?? '');
    _designationController = TextEditingController(
      text:
          e?.designation ??
          (_employeeType == EmployeeType.teacher ? 'Teacher' : 'Staff'),
    );
    _photoPath = e?.photoPath;
    _phoneController = TextEditingController(text: e?.phone ?? '');
    _emailController = TextEditingController(text: e?.email ?? '');
    _addressController = TextEditingController(text: e?.address ?? '');

    _emergencyNameController = TextEditingController(
      text: e?.emergencyContactName ?? '',
    );
    _emergencyPhoneController = TextEditingController(
      text: e?.emergencyContactPhone ?? '',
    );
    _emergencyRelation = e?.emergencyContactRelation;

    _gender = e?.gender;
    _bloodGroup = e?.bloodGroup;
    _maritalStatus = e?.maritalStatus;
    _dob = e?.dateOfBirth;

    _departmentController = TextEditingController(text: e?.department ?? '');
    _qualificationController = TextEditingController(
      text: e?.qualification ?? '',
    );
    _salaryController = TextEditingController(
      text: e?.basicSalary != null ? e!.basicSalary.toString() : '',
    );
    _joiningDate = e?.joiningDate;
    _isActive = e?.isActive ?? true;

    if (e == null) {
      _loadGeneratedCode(_employeeType);
    }
  }

  Future<void> _loadGeneratedCode(EmployeeType type) async {
    if (widget.employee != null) return;
    setState(() => _loadingCode = true);
    try {
      final code = await ref
          .read(employeeServiceProvider)
          .generateNextEmployeeCode(type);
      if (mounted) {
        setState(() {
          _generatedCode = code;
          _loadingCode = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadingCode = false);
      }
    }
  }

  Future<void> _pickPhoto() async {
    try {
      final path = await ImageStorageHelper.pickAndSaveEmployeePhoto();
      if (path != null && mounted) {
        setState(() {
          _photoPath = path;
        });
      }
    } catch (error) {
      if (mounted) {
        context.showSnackbar('Could not select employee photo: $error');
      }
    }
  }

  void _removePhoto() {
    setState(() {
      _photoPath = null;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _designationController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    _departmentController.dispose();
    _qualificationController.dispose();
    _salaryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.employee != null;
    final langCode = widget.langCode;
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 760),
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
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isEditing
                          ? AppTranslations.text('edit_employee', langCode)
                          : AppTranslations.text('add_employee', langCode),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => context.pop(),
                    ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 8),

                // Scrollable Form
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Employee Type Selection
                        Text(
                          AppTranslations.text('employee_type', langCode),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SegmentedButton<EmployeeType>(
                          segments: [
                            ButtonSegment(
                              value: EmployeeType.teacher,
                              label: Text(
                                AppTranslations.text('teachers', langCode),
                              ),
                              icon: const Icon(Icons.school_outlined),
                            ),
                            ButtonSegment(
                              value: EmployeeType.staff,
                              label: Text(
                                AppTranslations.text('staff', langCode),
                              ),
                              icon: const Icon(Icons.badge_outlined),
                            ),
                          ],
                          selected: {_employeeType},
                          onSelectionChanged: (set) {
                            final newType = set.first;
                            setState(() {
                              _employeeType = newType;
                              if (!isEditing &&
                                  (_designationController.text == 'Teacher' ||
                                      _designationController.text == 'Staff')) {
                                _designationController.text =
                                    _employeeType == EmployeeType.teacher
                                        ? 'Teacher'
                                        : 'Staff';
                              }
                            });
                            if (!isEditing) {
                              _loadGeneratedCode(newType);
                            }
                          },
                        ),
                        const SizedBox(height: 16),

                        // Section 1: Basic Information
                        Text(
                          AppTranslations.text('personal_details', langCode),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Full Name (Required)
                        TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText:
                                '${AppTranslations.text('employee', langCode)} Name *',
                            prefixIcon: const Icon(Icons.person_outline),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Please enter employee name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 10),

                        // Employee Code (Auto-generated, read-only)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest
                                .withAlpha(60),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: theme.dividerColor),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.badge_outlined,
                                size: 20,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    AppTranslations.text(
                                      'employee_code',
                                      langCode,
                                    ),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: theme.textTheme.bodySmall?.color,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isEditing
                                        ? (widget.employee!.employeeCode ?? '-')
                                        : (_loadingCode
                                            ? 'Generating...'
                                            : _generatedCode),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withAlpha(
                                    25,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  isEditing
                                      ? (langCode == 'ne'
                                          ? 'सुरक्षित कोड'
                                          : 'Assigned')
                                      : (langCode == 'ne'
                                          ? 'स्वतः सिर्जना'
                                          : 'Auto-generated'),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Designation & Department
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _designationController,
                                decoration: InputDecoration(
                                  labelText:
                                      '${AppTranslations.text('designation', langCode)} *',
                                  prefixIcon: const Icon(Icons.work_outline),
                                ),
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return 'Please enter designation';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                controller: _departmentController,
                                decoration: InputDecoration(
                                  labelText: AppTranslations.text(
                                    'department',
                                    langCode,
                                  ),
                                  prefixIcon: const Icon(Icons.domain),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Phone & Email
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _phoneController,
                                decoration: const InputDecoration(
                                  labelText: 'Phone',
                                  prefixIcon: Icon(Icons.phone_outlined),
                                ),
                                keyboardType: TextInputType.phone,
                                validator: (val) {
                                  if (val != null && val.trim().isNotEmpty) {
                                    return Validators.validatePhone(val.trim());
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                controller: _emailController,
                                decoration: const InputDecoration(
                                  labelText: 'Email',
                                  prefixIcon: Icon(Icons.email_outlined),
                                ),
                                keyboardType: TextInputType.emailAddress,
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
                        const SizedBox(height: 10),

                        // Photo Selection (Stored locally in app documents)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest
                                .withAlpha(40),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: theme.dividerColor),
                          ),
                          child: Row(
                            children: [
                              // Photo preview thumbnail
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surface,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: theme.dividerColor),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child:
                                    _photoPath != null && _photoPath!.isNotEmpty
                                        ? (ImageStorageHelper.isLocalFile(
                                              _photoPath,
                                            )
                                            ? Image.file(
                                              File(_photoPath!),
                                              fit: BoxFit.cover,
                                            )
                                            : (_photoPath!.startsWith('http')
                                                ? Image.network(
                                                  _photoPath!,
                                                  fit: BoxFit.cover,
                                                )
                                                : const Icon(
                                                  Icons.person,
                                                  size: 32,
                                                )))
                                        : Icon(
                                          Icons.person_outline,
                                          size: 32,
                                          color: theme.colorScheme.primary
                                              .withAlpha(120),
                                        ),
                              ),
                              const SizedBox(width: 14),
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
                                          ? (_photoPath!.split('/').last)
                                          : (langCode == 'ne'
                                              ? 'उपकरणबाट फोटो छान्नुहोस्'
                                              : 'Stored locally in app storage'),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: theme.textTheme.bodySmall?.color,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: _pickPhoto,
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
                                          : 'Select Photo'),
                                ),
                              ),
                              if (_photoPath != null &&
                                  _photoPath!.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.red,
                                    size: 20,
                                  ),
                                  tooltip:
                                      langCode == 'ne'
                                          ? 'हटाउनुहोस्'
                                          : 'Remove Photo',
                                  onPressed: _removePhoto,
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Section 2: Emergency Contact Information
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.amber.withAlpha(20),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.amber.withAlpha(60),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.emergency_outlined,
                                    size: 16,
                                    color: Colors.amber,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    AppTranslations.text(
                                      'emergency_details',
                                      langCode,
                                    ),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.amber,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: TextFormField(
                                      controller: _emergencyNameController,
                                      decoration: InputDecoration(
                                        labelText: AppTranslations.text(
                                          'emergency_contact',
                                          langCode,
                                        ),
                                        prefixIcon: const Icon(
                                          Icons.person_pin,
                                        ),
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    flex: 1,
                                    child: AppSearchableSelect<String>(
                                      value: _emergencyRelation,
                                      label: AppTranslations.text(
                                        'relation',
                                        langCode,
                                      ),
                                      isDense: true,
                                      items: ContactRelationOptions.items,
                                      onChanged: (val) {
                                        setState(() {
                                          _emergencyRelation = val;
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _emergencyPhoneController,
                                decoration: InputDecoration(
                                  labelText: AppTranslations.text(
                                    'emergency_phone',
                                    langCode,
                                  ),
                                  prefixIcon: const Icon(Icons.phone_in_talk),
                                  isDense: true,
                                ),
                                keyboardType: TextInputType.phone,
                                validator: (val) {
                                  if (val != null && val.trim().isNotEmpty) {
                                    return Validators.validatePhone(val.trim());
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Section 3: Personal Information
                        Text(
                          AppTranslations.text('optional_info', langCode),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 10),

                        // DOB & Gender
                        Row(
                          children: [
                            Expanded(
                              child: DualDatePickerField(
                                label: AppTranslations.text(
                                  'date_of_birth',
                                  langCode,
                                ),
                                selectedDate: _dob,
                                onDateSelected: (date) {
                                  setState(() {
                                    _dob = date;
                                  });
                                },
                                lastDate: DateTime.now(),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: AppSearchableSelect<String>(
                                value: _gender,
                                label: AppTranslations.text('gender', langCode),
                                prefixIcon: const Icon(Icons.wc),
                                isClearable: true,
                                items:
                                    _genders
                                        .map(
                                          (g) => SearchableSelectItem<String>(
                                            value: g,
                                            label: g,
                                          ),
                                        )
                                        .toList(),
                                onChanged: (val) {
                                  setState(() {
                                    _gender = val;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Blood Group & Marital Status
                        Row(
                          children: [
                            Expanded(
                              child: AppSearchableSelect<String>(
                                value: _bloodGroup,
                                label: AppTranslations.text(
                                  'blood_group',
                                  langCode,
                                ),
                                prefixIcon: const Icon(
                                  Icons.bloodtype_outlined,
                                ),
                                isClearable: true,
                                items:
                                    _bloodGroups
                                        .map(
                                          (bg) => SearchableSelectItem<String>(
                                            value: bg,
                                            label: bg,
                                          ),
                                        )
                                        .toList(),
                                onChanged: (val) {
                                  setState(() {
                                    _bloodGroup = val;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: AppSearchableSelect<String>(
                                value: _maritalStatus,
                                label: AppTranslations.text(
                                  'marital_status',
                                  langCode,
                                ),
                                prefixIcon: const Icon(Icons.favorite_outline),
                                isClearable: true,
                                items:
                                    _maritalStatuses
                                        .map(
                                          (ms) => SearchableSelectItem<String>(
                                            value: ms,
                                            label: ms,
                                          ),
                                        )
                                        .toList(),
                                onChanged: (val) {
                                  setState(() {
                                    _maritalStatus = val;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Address
                        TextFormField(
                          controller: _addressController,
                          decoration: InputDecoration(
                            labelText: AppTranslations.text(
                              'address',
                              langCode,
                            ),
                            prefixIcon: const Icon(Icons.home_outlined),
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 16),

                        // Section 4: Professional & Employment Details
                        Text(
                          AppTranslations.text(
                            'professional_details',
                            langCode,
                          ),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Qualification & Salary
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _qualificationController,
                                decoration: InputDecoration(
                                  labelText: AppTranslations.text(
                                    'qualification',
                                    langCode,
                                  ),
                                  prefixIcon: const Icon(Icons.school_outlined),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextFormField(
                                controller: _salaryController,
                                decoration: const InputDecoration(
                                  labelText: 'Basic Salary (Rs.)',
                                  prefixIcon: Icon(Icons.attach_money),
                                ),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Joining Date
                        DualDatePickerField(
                          label: AppTranslations.text('joining_date', langCode),
                          selectedDate: _joiningDate,
                          onDateSelected: (date) {
                            setState(() {
                              _joiningDate = date;
                            });
                          },
                        ),
                        const SizedBox(height: 12),

                        // Is Active switch
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(AppTranslations.text('active', langCode)),
                          subtitle: Text(
                            langCode == 'ne'
                                ? 'यस कर्मचारीको खाता सक्रिय राख्ने वा नराख्ने'
                                : 'Whether this employee record is active',
                          ),
                          value: _isActive,
                          onChanged: (val) {
                            setState(() {
                              _isActive = val;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(),

                // Dialog Actions (Cancel & Save)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => context.pop(),
                      child: Text(AppTranslations.text('cancel', langCode)),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _saveEmployee,
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

  Future<void> _saveEmployee() async {
    if (!_formKey.currentState!.validate()) return;

    final isEditing = widget.employee != null;
    final langCode = widget.langCode;
    final errorColor = Theme.of(context).colorScheme.error;

    final double? salary =
        _salaryController.text.trim().isNotEmpty
            ? double.tryParse(_salaryController.text.trim())
            : null;

    try {
      if (isEditing) {
        await ref
            .read(employeeControllerProvider.notifier)
            .updateEmployee(
              id: widget.employee!.id,
              name: _nameController.text.trim(),
              employeeType: _employeeType,
              designation: _designationController.text.trim(),
              employeeCode: widget.employee!.employeeCode,
              photoPath: _photoPath,
              emergencyContactName:
                  _emergencyNameController.text.trim().isEmpty
                      ? null
                      : _emergencyNameController.text.trim(),
              emergencyContactPhone:
                  _emergencyPhoneController.text.trim().isEmpty
                      ? null
                      : _emergencyPhoneController.text.trim(),
              emergencyContactRelation: _emergencyRelation,
              email:
                  _emailController.text.trim().isEmpty
                      ? null
                      : _emailController.text.trim(),
              phone:
                  _phoneController.text.trim().isEmpty
                      ? null
                      : _phoneController.text.trim(),
              dateOfBirth: _dob,
              gender: _gender,
              bloodGroup: _bloodGroup,
              maritalStatus: _maritalStatus,
              address:
                  _addressController.text.trim().isEmpty
                      ? null
                      : _addressController.text.trim(),
              qualification:
                  _qualificationController.text.trim().isEmpty
                      ? null
                      : _qualificationController.text.trim(),
              department:
                  _departmentController.text.trim().isEmpty
                      ? null
                      : _departmentController.text.trim(),
              joiningDate: _joiningDate,
              basicSalary: salary,
              isActive: _isActive,
            );
      } else {
        await ref
            .read(employeeControllerProvider.notifier)
            .createEmployee(
              name: _nameController.text.trim(),
              employeeType: _employeeType,
              designation: _designationController.text.trim(),
              employeeCode: _generatedCode.isNotEmpty ? _generatedCode : null,
              photoPath: _photoPath,
              emergencyContactName:
                  _emergencyNameController.text.trim().isEmpty
                      ? null
                      : _emergencyNameController.text.trim(),
              emergencyContactPhone:
                  _emergencyPhoneController.text.trim().isEmpty
                      ? null
                      : _emergencyPhoneController.text.trim(),
              emergencyContactRelation: _emergencyRelation,
              email:
                  _emailController.text.trim().isEmpty
                      ? null
                      : _emailController.text.trim(),
              phone:
                  _phoneController.text.trim().isEmpty
                      ? null
                      : _phoneController.text.trim(),
              dateOfBirth: _dob,
              gender: _gender,
              bloodGroup: _bloodGroup,
              maritalStatus: _maritalStatus,
              address:
                  _addressController.text.trim().isEmpty
                      ? null
                      : _addressController.text.trim(),
              qualification:
                  _qualificationController.text.trim().isEmpty
                      ? null
                      : _qualificationController.text.trim(),
              department:
                  _departmentController.text.trim().isEmpty
                      ? null
                      : _departmentController.text.trim(),
              joiningDate: _joiningDate,
              basicSalary: salary,
              isActive: _isActive,
            );
      }

      // ignore: use_build_context_synchronously
      context.pop();
      context.showSnackbar(
        SnackBar(
          content: Text(
            isEditing
                ? (langCode == 'ne'
                    ? 'कर्मचारी सफलतापूर्वक अद्यावधिक गरियो'
                    : 'Employee updated successfully')
                : (langCode == 'ne'
                    ? 'नयाँ कर्मचारी सफलतापूर्वक थपियो'
                    : 'Employee created successfully'),
          ),
        ),
      );
    } catch (e) {
      context.showSnackbar(
        SnackBar(content: Text('Error: $e'), backgroundColor: errorColor),
      );
    }
  }
}
