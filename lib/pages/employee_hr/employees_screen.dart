import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../config/enums.dart';
import '../../config/extensions.dart';
import '../../config/responsive.dart';
import '../../config/translations.dart';
import '../../providers/employee_provider.dart';
import '../../providers/locale_provider.dart';
import '../../widgets/app_input.dart';
import '../../widgets/employee/employee_list.dart';
import '../../widgets/forms/employee_form.dart';

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
                mainAxisSize: MainAxisSize.min,
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
                  EmployeeList(list: filtered),
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
        onPressed:
            () =>
                () => context.showGenericDialogWithChild(
                  EmployeeForm(langCode: langCode),
                ),
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
                onPressed:
                    () => context.showGenericDialogWithChild(
                      EmployeeForm(langCode: langCode),
                    ),
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
}
