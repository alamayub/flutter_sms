import 'package:flutter/material.dart';
import '../../config/extensions.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../config/enums.dart';
import '../../config/theme.dart';
import '../../config/translations.dart';
import '../../data/app_database.dart';
import '../../providers/employee_provider.dart';
import '../../providers/locale_provider.dart';
import '../../widgets/app_input.dart';

class EmployeeIdCardScreen extends ConsumerStatefulWidget {
  const EmployeeIdCardScreen({super.key});

  @override
  ConsumerState<EmployeeIdCardScreen> createState() =>
      _EmployeeIdCardScreenState();
}

class _EmployeeIdCardScreenState extends ConsumerState<EmployeeIdCardScreen> {
  final TextEditingController _searchController = TextEditingController();
  final Set<int> _selectedEmployeeIds = {};
  Employee? _previewEmployee;

  // Customization settings
  bool _isVertical = true;
  bool _showBackSide = false;
  Color _cardColor = const Color(0xFF1E3A8A); // Classic Navy
  String _schoolName = 'PRAGYAN ACADEMY';
  String _schoolAddress = 'Kathmandu, Nepal';
  String _schoolPhone = '+977-1-4567890';
  bool _showBarcode = true;
  bool _showBloodGroup = true;
  bool _showEmergencyContact = true;
  bool _showJoiningDate = true;

  // Local filter states
  EmployeeType? _filterType;
  String? _filterDepartment;
  String _searchQuery = '';

  static const List<Color> _colorPresets = [
    Color(0xFF1E3A8A), // Navy
    Color(0xFF065F46), // Forest Green
    Color(0xFF831843), // Deep Maroon
    Color(0xFF581C87), // Royal Purple
    Color(0xFF1E293B), // Dark Slate
    Color(0xFF9A3412), // Rust / Amber
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lang = ref.watch(localeProvider).locale.languageCode;
    final employeesAsync = ref.watch(employeesStreamProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 960;

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              // 1. Header Banner
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withAlpha(25),
                          borderRadius: AppRadius.roundedLg,
                        ),
                        child: Icon(
                          Icons.badge_rounded,
                          size: 28,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppTranslations.text('employee_id_cards', lang),
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              lang == 'ne'
                                  ? 'शिक्षक तथा कर्मचारीहरूको परिचय पत्र निर्माण, ढाँचा चयन तथा प्रिन्ट'
                                  : 'Generate, customize, preview and print official employee & faculty identity cards',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Quick Action Buttons
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            icon: const Icon(Icons.tune, size: 18),
                            label: Text(
                              lang == 'ne' ? 'ढाँचा सेटिङ' : 'Card Design',
                            ),
                            onPressed:
                                () => _showDesignSettingsDialog(context, lang),
                          ),
                          FilledButton.icon(
                            icon: const Icon(Icons.print, size: 18),
                            label: Text(
                              _selectedEmployeeIds.isEmpty
                                  ? (lang == 'ne'
                                      ? 'परिचय पत्र प्रिन्ट'
                                      : 'Print Card')
                                  : '${lang == 'ne' ? 'प्रिन्ट' : 'Print'} (${_selectedEmployeeIds.length})',
                            ),
                            onPressed:
                                () => _handlePrintAction(
                                  context,
                                  employeesAsync,
                                  lang,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // 2. Filter Bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  child: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.roundedLg,
                      side: BorderSide(color: theme.colorScheme.outlineVariant),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: employeesAsync.when(
                        data: (allEmployees) {
                          // Extract unique departments
                          final departments =
                              allEmployees
                                  .map((e) => e.department?.trim())
                                  .where((d) => d != null && d.isNotEmpty)
                                  .cast<String>()
                                  .toSet()
                                  .toList()
                                ..sort();

                          return Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              // Search Box
                              SizedBox(
                                width: 250,
                                child: TextField(
                                  controller: _searchController,
                                  decoration: AppInputDecoration.standard(
                                    context,
                                    hintText:
                                        lang == 'ne'
                                            ? 'नाम, कोड, पद खोज्नुहोस्...'
                                            : 'Search name, code, designation...',
                                    prefixIcon: const Icon(
                                      Icons.search,
                                      size: 20,
                                    ),
                                    isDense: true,
                                  ),
                                  onChanged: (val) {
                                    setState(() {
                                      _searchQuery = val.trim().toLowerCase();
                                    });
                                  },
                                ),
                              ),

                              // Employee Type Filter
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: theme.colorScheme.outlineVariant,
                                  ),
                                  borderRadius: AppRadius.roundedMd,
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<EmployeeType?>(
                                    value: _filterType,
                                    isDense: true,
                                    icon: const Icon(
                                      Icons.arrow_drop_down,
                                      size: 20,
                                    ),
                                    items: [
                                      DropdownMenuItem(
                                        value: null,
                                        child: Text(
                                          lang == 'ne'
                                              ? 'सबै प्रकार (All Types)'
                                              : 'All Employee Types',
                                          style: theme.textTheme.bodyMedium,
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value: EmployeeType.teacher,
                                        child: Text(
                                          lang == 'ne'
                                              ? 'शिक्षक (Teachers)'
                                              : 'Teachers',
                                          style: theme.textTheme.bodyMedium,
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value: EmployeeType.staff,
                                        child: Text(
                                          lang == 'ne'
                                              ? 'कर्मचारी (Staff)'
                                              : 'Support Staff',
                                          style: theme.textTheme.bodyMedium,
                                        ),
                                      ),
                                    ],
                                    onChanged: (type) {
                                      setState(() {
                                        _filterType = type;
                                      });
                                    },
                                  ),
                                ),
                              ),

                              // Department Filter
                              if (departments.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: theme.colorScheme.outlineVariant,
                                    ),
                                    borderRadius: AppRadius.roundedMd,
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String?>(
                                      value: _filterDepartment,
                                      isDense: true,
                                      icon: const Icon(
                                        Icons.arrow_drop_down,
                                        size: 20,
                                      ),
                                      items: [
                                        DropdownMenuItem(
                                          value: null,
                                          child: Text(
                                            lang == 'ne'
                                                ? 'सबै विभाग (All Depts)'
                                                : 'All Departments',
                                            style: theme.textTheme.bodyMedium,
                                          ),
                                        ),
                                        ...departments.map(
                                          (dept) => DropdownMenuItem(
                                            value: dept,
                                            child: Text(
                                              dept,
                                              style: theme.textTheme.bodyMedium,
                                            ),
                                          ),
                                        ),
                                      ],
                                      onChanged: (dept) {
                                        setState(() {
                                          _filterDepartment = dept;
                                        });
                                      },
                                    ),
                                  ),
                                ),

                              // Reset Filters
                              if (_filterType != null ||
                                  _filterDepartment != null ||
                                  _searchQuery.isNotEmpty)
                                TextButton.icon(
                                  icon: const Icon(Icons.clear, size: 16),
                                  label: Text(
                                    lang == 'ne'
                                        ? 'फिल्टर हटाउनुहोस्'
                                        : 'Reset Filters',
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _filterType = null;
                                      _filterDepartment = null;
                                      _searchQuery = '';
                                      _searchController.clear();
                                    });
                                  },
                                ),
                            ],
                          );
                        },
                        loading:
                            () => const SizedBox(
                              height: 40,
                              child: Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                            ),
                        error:
                            (err, _) => Text(
                              'Error loading employees: $err',
                              style: TextStyle(color: theme.colorScheme.error),
                            ),
                      ),
                    ),
                  ),
                ),
              ),

              // 3. Main Workspace: Split View (Left: Employee Selector, Right: Live Interactive Card)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: employeesAsync.when(
                    data: (allEmployees) {
                      // Apply local filters
                      final filteredEmployees =
                          allEmployees.where((emp) {
                            if (_filterType != null &&
                                emp.employeeType != _filterType) {
                              return false;
                            }
                            if (_filterDepartment != null &&
                                emp.department != _filterDepartment) {
                              return false;
                            }
                            if (_searchQuery.isNotEmpty) {
                              final matchName = emp.name.toLowerCase().contains(
                                _searchQuery,
                              );
                              final matchCode = (emp.employeeCode ?? '')
                                  .toLowerCase()
                                  .contains(_searchQuery);
                              final matchDesig = emp.designation
                                  .toLowerCase()
                                  .contains(_searchQuery);
                              final matchPhone = (emp.phone ?? '')
                                  .toLowerCase()
                                  .contains(_searchQuery);
                              if (!matchName &&
                                  !matchCode &&
                                  !matchDesig &&
                                  !matchPhone) {
                                return false;
                              }
                            }
                            return true;
                          }).toList();

                      // Set default preview employee if null
                      if (_previewEmployee == null &&
                          filteredEmployees.isNotEmpty) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) {
                            setState(() {
                              _previewEmployee = filteredEmployees.first;
                            });
                          }
                        });
                      }

                      if (isWide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left: Employee List (60%)
                            Expanded(
                              flex: 6,
                              child: _buildEmployeeListPanel(
                                context,
                                theme,
                                lang,
                                filteredEmployees,
                              ),
                            ),
                            const SizedBox(width: 20),
                            // Right: Card Preview & Controls (40%)
                            Expanded(
                              flex: 4,
                              child: _buildPreviewPanel(
                                context,
                                theme,
                                lang,
                                filteredEmployees,
                              ),
                            ),
                          ],
                        );
                      } else {
                        // Narrow layout: Stacked vertically
                        return Column(
                          children: [
                            _buildPreviewPanel(
                              context,
                              theme,
                              lang,
                              filteredEmployees,
                            ),
                            const SizedBox(height: 20),
                            _buildEmployeeListPanel(
                              context,
                              theme,
                              lang,
                              filteredEmployees,
                            ),
                          ],
                        );
                      }
                    },
                    loading:
                        () => const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: CircularProgressIndicator(),
                          ),
                        ),
                    error:
                        (err, _) => Center(
                          child: Text(
                            'Failed to load employees: $err',
                            style: TextStyle(color: theme.colorScheme.error),
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
  }

  // -------------------------------------------------------------
  // Panel 1: Employee List Panel with Multi-select
  // -------------------------------------------------------------
  Widget _buildEmployeeListPanel(
    BuildContext context,
    ThemeData theme,
    String lang,
    List<Employee> employees,
  ) {
    final allSelected =
        employees.isNotEmpty &&
        employees.every((e) => _selectedEmployeeIds.contains(e.id));

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.roundedLg,
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withAlpha(50),
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppRadius.lg),
              ),
              border: Border(
                bottom: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
            ),
            child: Row(
              children: [
                Checkbox(
                  value:
                      allSelected
                          ? true
                          : (_selectedEmployeeIds.isEmpty ? false : null),
                  tristate: true,
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _selectedEmployeeIds.addAll(employees.map((e) => e.id));
                      } else {
                        _selectedEmployeeIds.clear();
                      }
                    });
                  },
                ),
                Text(
                  lang == 'ne' ? 'कर्मचारी सूची' : 'Employee Roster',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withAlpha(30),
                    borderRadius: AppRadius.roundedFull,
                  ),
                  child: Text(
                    '${employees.length}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const Spacer(),
                if (_selectedEmployeeIds.isNotEmpty) ...[
                  Text(
                    '${_selectedEmployeeIds.length} ${lang == 'ne' ? 'छानियो' : 'selected'}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    tooltip:
                        lang == 'ne'
                            ? 'छनोट खाली गर्नुहोस्'
                            : 'Clear selection',
                    onPressed: () {
                      setState(() {
                        _selectedEmployeeIds.clear();
                      });
                    },
                  ),
                ],
              ],
            ),
          ),

          // List Body
          if (employees.isEmpty)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.badge_outlined,
                      size: 48,
                      color: theme.colorScheme.outline,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      lang == 'ne'
                          ? 'कुनै कर्मचारी फेला परेन'
                          : 'No employees found for the selected criteria',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: employees.length,
              separatorBuilder:
                  (context, index) => Divider(
                    height: 1,
                    color: theme.colorScheme.outlineVariant.withAlpha(100),
                  ),
              itemBuilder: (context, index) {
                final emp = employees[index];
                final isSelected = _selectedEmployeeIds.contains(emp.id);
                final isPreviewing = _previewEmployee?.id == emp.id;

                return InkWell(
                  onTap: () {
                    setState(() {
                      _previewEmployee = emp;
                    });
                  },
                  child: Container(
                    color:
                        isPreviewing
                            ? theme.colorScheme.primary.withAlpha(20)
                            : null,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Checkbox(
                          value: isSelected,
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedEmployeeIds.add(emp.id);
                              } else {
                                _selectedEmployeeIds.remove(emp.id);
                              }
                            });
                          },
                        ),
                        // Avatar
                        CircleAvatar(
                          radius: 20,
                          backgroundColor:
                              emp.employeeType == EmployeeType.teacher
                                  ? const Color(0xFF1E3A8A).withAlpha(30)
                                  : const Color(0xFF065F46).withAlpha(30),
                          child: Text(
                            emp.name.isNotEmpty
                                ? emp.name.characters.first.toUpperCase()
                                : 'E',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color:
                                  emp.employeeType == EmployeeType.teacher
                                      ? const Color(0xFF1E3A8A)
                                      : const Color(0xFF065F46),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      emp.name,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color:
                                                isPreviewing
                                                    ? theme.colorScheme.primary
                                                    : null,
                                          ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          emp.employeeType ==
                                                  EmployeeType.teacher
                                              ? Colors.blue.withAlpha(30)
                                              : Colors.teal.withAlpha(30),
                                      borderRadius: AppRadius.roundedFull,
                                    ),
                                    child: Text(
                                      emp.employeeType == EmployeeType.teacher
                                          ? 'Teacher'
                                          : 'Staff',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color:
                                            emp.employeeType ==
                                                    EmployeeType.teacher
                                                ? Colors.blue.shade800
                                                : Colors.teal.shade800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${emp.designation}${emp.department != null && emp.department!.isNotEmpty ? ' • ${emp.department}' : ''}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Code badge
                        if (emp.employeeCode != null &&
                            emp.employeeCode!.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: AppRadius.roundedSm,
                            ),
                            child: Text(
                              emp.employeeCode!,
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        const SizedBox(width: 8),
                        // Action: Preview button or Single Print
                        IconButton(
                          icon: const Icon(Icons.print_outlined, size: 18),
                          tooltip:
                              lang == 'ne'
                                  ? 'यसको कार्ड प्रिन्ट गर्नुहोस्'
                                  : 'Print single ID card',
                          onPressed: () {
                            _showSinglePrintDialog(context, emp, lang);
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // Panel 2: Live Interactive Preview Panel
  // -------------------------------------------------------------
  Widget _buildPreviewPanel(
    BuildContext context,
    ThemeData theme,
    String lang,
    List<Employee> employees,
  ) {
    final employee =
        _previewEmployee ??
        (employees.isNotEmpty
            ? employees.first
            : Employee(
              id: 0,
              name: 'Dr. Ramesh Sharma',
              employeeCode: 'EMP-2026-001',
              employeeType: EmployeeType.teacher,
              designation: 'Senior Faculty & HOD',
              department: 'Science & Mathematics',
              email: 'ramesh.sharma@pragyan.edu.np',
              phone: '+977-9841234567',
              emergencyContactName: 'Sunita Sharma',
              emergencyContactPhone: '+977-9851234567',
              emergencyContactRelation: 'Spouse',
              bloodGroup: 'B+',
              joiningDate: DateTime(2021, 4, 15),
              isActive: true,
              createdAt: DateTime.now(),
            ));

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.roundedLg,
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Preview Header Toolbar
            Row(
              children: [
                Icon(
                  Icons.remove_red_eye_outlined,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  lang == 'ne' ? 'प्रत्यक्ष अवलोकन' : 'Live Card Preview',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                // Flip Front/Back Button
                IconButton(
                  icon: Icon(
                    _showBackSide
                        ? Icons.flip_to_front_outlined
                        : Icons.flip_to_back_outlined,
                  ),
                  tooltip:
                      _showBackSide
                          ? (lang == 'ne' ? 'अगाडि हेर्नुहोस्' : 'Show Front')
                          : (lang == 'ne' ? 'पछाडि हेर्नुहोस्' : 'Show Back'),
                  onPressed: () {
                    setState(() {
                      _showBackSide = !_showBackSide;
                    });
                  },
                ),
                // Orientation Toggle
                IconButton(
                  icon: Icon(
                    _isVertical
                        ? Icons.crop_portrait_outlined
                        : Icons.crop_landscape_outlined,
                  ),
                  tooltip:
                      _isVertical
                          ? (lang == 'ne'
                              ? 'तेर्सो (Horizontal)'
                              : 'Switch to Horizontal')
                          : (lang == 'ne'
                              ? 'ठाडो (Vertical)'
                              : 'Switch to Vertical'),
                  onPressed: () {
                    setState(() {
                      _isVertical = !_isVertical;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Theme Color Palette Picker Bar
            Row(
              children: [
                Text(
                  lang == 'ne' ? 'रङ:' : 'Theme:',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                ..._colorPresets.map((color) {
                  final isCurrent = _cardColor == color;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _cardColor = color;
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isCurrent ? Colors.white : Colors.transparent,
                          width: 2,
                        ),
                        boxShadow:
                            isCurrent
                                ? [
                                  BoxShadow(
                                    color: color.withAlpha(100),
                                    blurRadius: 4,
                                    spreadRadius: 1,
                                  ),
                                ]
                                : null,
                      ),
                      child:
                          isCurrent
                              ? const Icon(
                                Icons.check,
                                size: 14,
                                color: Colors.white,
                              )
                              : null,
                    ),
                  );
                }),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: AppRadius.roundedSm,
                  ),
                  child: Text(
                    _showBackSide
                        ? (lang == 'ne' ? 'पछाडिको भाग' : 'BACK')
                        : (lang == 'ne' ? 'अगाडिको भाग' : 'FRONT'),
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Card Stage Container
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withAlpha(40),
                borderRadius: AppRadius.roundedLg,
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withAlpha(100),
                ),
              ),
              child: Center(
                child:
                    _isVertical
                        ? (_showBackSide
                            ? _buildVerticalBackCard(employee)
                            : _buildVerticalFrontCard(employee))
                        : (_showBackSide
                            ? _buildHorizontalBackCard(employee)
                            : _buildHorizontalFrontCard(employee)),
              ),
            ),
            const SizedBox(height: 16),

            // Action: Print this preview card directly
            FilledButton.icon(
              icon: const Icon(Icons.print, size: 18),
              label: Text(
                lang == 'ne'
                    ? 'यो परिचय पत्र प्रिन्ट गर्नुहोस्'
                    : 'Print This ID Card',
              ),
              onPressed: () {
                _showSinglePrintDialog(context, employee, lang);
              },
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // Card View: Vertical Front (CR80 portrait: ~220w x ~340h)
  // -------------------------------------------------------------
  Widget _buildVerticalFrontCard(Employee employee) {
    return Container(
      width: 230,
      height: 350,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade300, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Column(
          children: [
            // Top Color Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
              color: _cardColor,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(40),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.account_balance,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          _schoolName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _schoolAddress,
                    style: TextStyle(
                      color: Colors.white.withAlpha(210),
                      fontSize: 8.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            // Accent stripe
            Container(
              height: 3,
              width: double.infinity,
              color: Colors.amber.shade700,
            ),

            const SizedBox(height: 8),

            // Photo Placeholder
            Center(
              child: Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _cardColor.withAlpha(20),
                  border: Border.all(color: _cardColor, width: 2),
                ),
                child: Center(
                  child: Text(
                    employee.name.isNotEmpty
                        ? employee.name.characters.first.toUpperCase()
                        : 'E',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: _cardColor,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 6),

            // Employee Name
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                employee.name,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Designation Badge
            Container(
              margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 12),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _cardColor.withAlpha(25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                employee.designation,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                  color: _cardColor,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Department
            if (employee.department != null && employee.department!.isNotEmpty)
              Text(
                employee.department!,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade700,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

            const SizedBox(height: 6),

            // Details Box
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  _buildDetailRow(
                    'Emp ID:',
                    employee.employeeCode ??
                        'EMP-${employee.id.toString().padLeft(3, '0')}',
                  ),
                  if (_showJoiningDate && employee.joiningDate != null)
                    _buildDetailRow(
                      'Joined:',
                      '${employee.joiningDate!.year}-${employee.joiningDate!.month.toString().padLeft(2, '0')}-${employee.joiningDate!.day.toString().padLeft(2, '0')}',
                    ),
                  if (employee.phone != null && employee.phone!.isNotEmpty)
                    _buildDetailRow('Phone:', employee.phone!),
                  if (_showBloodGroup &&
                      employee.bloodGroup != null &&
                      employee.bloodGroup!.isNotEmpty)
                    _buildDetailRow('Blood Grp:', employee.bloodGroup!),
                ],
              ),
            ),

            const Spacer(),

            // Barcode or Bottom Accent
            if (_showBarcode)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _buildBarcodeGraphic(
                  employee.employeeCode ?? 'EMP${employee.id}',
                ),
              ),

            // Bottom Color Bar
            Container(height: 6, width: double.infinity, color: _cardColor),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // Card View: Vertical Back (CR80 portrait)
  // -------------------------------------------------------------
  Widget _buildVerticalBackCard(Employee employee) {
    return Container(
      width: 230,
      height: 350,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade300, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Column(
          children: [
            // Top Accent Bar
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6),
              color: _cardColor,
              child: const Text(
                'FACULTY & STAFF IDENTITY CARD',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Terms / General Info
                  const Text(
                    'TERMS & CONDITIONS:',
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '1. This card is non-transferable and remains property of $_schoolName.\n'
                    '2. Must be visibly carried while on school premises and official tours.\n'
                    '3. Loss must be reported immediately to school administration.\n'
                    '4. If found, please return to: $_schoolAddress, Phone: $_schoolPhone.',
                    style: TextStyle(
                      fontSize: 7.5,
                      color: Colors.grey.shade700,
                      height: 1.3,
                    ),
                  ),

                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  const SizedBox(height: 8),

                  // Emergency Contact
                  if (_showEmergencyContact &&
                      employee.emergencyContactPhone != null) ...[
                    const Text(
                      'EMERGENCY CONTACT:',
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${employee.emergencyContactName ?? 'Contact'}: ${employee.emergencyContactPhone}'
                      '${employee.emergencyContactRelation != null ? ' (${employee.emergencyContactRelation})' : ''}',
                      style: TextStyle(
                        fontSize: 8,
                        color: Colors.grey.shade800,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],

                  if (employee.email != null && employee.email!.isNotEmpty) ...[
                    Text(
                      'Email: ${employee.email}',
                      style: TextStyle(
                        fontSize: 7.5,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],

                  // Validity
                  Text(
                    'Issued: ${DateTime.now().year} | Valid for Academic Year',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                      color: _cardColor,
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Signature Block
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 70,
                        height: 1,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Cardholder',
                        style: TextStyle(
                          fontSize: 7.5,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      Container(
                        width: 70,
                        height: 1,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Principal / Director',
                        style: TextStyle(
                          fontSize: 7.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Bottom Accent
            Container(height: 5, width: double.infinity, color: _cardColor),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // Card View: Horizontal Front (CR80 landscape: ~350w x ~220h)
  // -------------------------------------------------------------
  Widget _buildHorizontalFrontCard(Employee employee) {
    return Container(
      width: 350,
      height: 220,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade300, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Column(
          children: [
            // Top Bar
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              color: _cardColor,
              child: Row(
                children: [
                  const Icon(
                    Icons.account_balance,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _schoolName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  Text(
                    'FACULTY ID',
                    style: TextStyle(
                      color: Colors.amber.shade300,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // Accent line
            Container(
              height: 2.5,
              width: double.infinity,
              color: Colors.amber.shade700,
            ),

            // Content Area (Row: Left Photo & Code | Right Details)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Left Column: Photo & Barcode
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 65,
                          height: 65,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _cardColor.withAlpha(20),
                            border: Border.all(color: _cardColor, width: 2),
                          ),
                          child: Center(
                            child: Text(
                              employee.name.isNotEmpty
                                  ? employee.name.characters.first.toUpperCase()
                                  : 'E',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: _cardColor,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (_showBarcode)
                          _buildBarcodeGraphic(
                            employee.employeeCode ?? 'EMP${employee.id}',
                            width: 85,
                            height: 20,
                          ),
                      ],
                    ),

                    const SizedBox(width: 14),

                    // Right Column: Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            employee.name,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            employee.designation,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: _cardColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (employee.department != null &&
                              employee.department!.isNotEmpty)
                            Text(
                              employee.department!,
                              style: TextStyle(
                                fontSize: 8.5,
                                color: Colors.grey.shade700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          const SizedBox(height: 6),

                          // Two Column mini-info
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildMiniText(
                                      'ID:',
                                      employee.employeeCode ??
                                          'EMP-${employee.id.toString().padLeft(3, '0')}',
                                    ),
                                    if (employee.phone != null)
                                      _buildMiniText('Phone:', employee.phone!),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (_showJoiningDate &&
                                        employee.joiningDate != null)
                                      _buildMiniText(
                                        'Joined:',
                                        '${employee.joiningDate!.year}-${employee.joiningDate!.month.toString().padLeft(2, '0')}',
                                      ),
                                    if (_showBloodGroup &&
                                        employee.bloodGroup != null)
                                      _buildMiniText(
                                        'Blood:',
                                        employee.bloodGroup!,
                                      ),
                                  ],
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

            // Bottom Bar
            Container(height: 5, width: double.infinity, color: _cardColor),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // Card View: Horizontal Back (CR80 landscape)
  // -------------------------------------------------------------
  Widget _buildHorizontalBackCard(Employee employee) {
    return Container(
      width: 350,
      height: 220,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade300, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Column(
          children: [
            // Top Accent Bar
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6),
              color: _cardColor,
              child: Text(
                '$_schoolName • GENERAL INFORMATION',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    // Instructions & Emergency
                    Expanded(
                      flex: 6,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'RULES & RETURNING INSTRUCTIONS:',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '• This card is institutional property and must be worn on duty.\n'
                            '• If found, return to school office: $_schoolAddress.\n'
                            '• Helpdesk: $_schoolPhone',
                            style: TextStyle(
                              fontSize: 7.5,
                              color: Colors.grey.shade700,
                              height: 1.3,
                            ),
                          ),
                          const Spacer(),
                          if (_showEmergencyContact &&
                              employee.emergencyContactPhone != null) ...[
                            Text(
                              'Emergency: ${employee.emergencyContactName ?? 'Contact'} (${employee.emergencyContactPhone})',
                              style: TextStyle(
                                fontSize: 7.5,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const VerticalDivider(),

                    // Signature Block
                    Expanded(
                      flex: 4,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          const Spacer(),
                          Container(
                            width: 90,
                            height: 1,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Authorized Signature',
                            style: TextStyle(
                              fontSize: 7.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Valid: Academic Session',
                            style: TextStyle(
                              fontSize: 7,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 6),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Accent
            Container(height: 5, width: double.infinity, color: _cardColor),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // Helpers: Detail Row, Mini Text, Barcode Simulation
  // -------------------------------------------------------------
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniText(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Text.rich(
        TextSpan(
          text: '$label ',
          style: TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade600,
          ),
          children: [
            TextSpan(
              text: value,
              style: const TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildBarcodeGraphic(
    String code, {
    double width = 120,
    double height = 24,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: width,
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade300, width: 0.5),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(24, (i) {
              final isBar = (i * 7 + code.hashCode) % 3 != 0;
              final isThick = (i * 3) % 4 == 0;
              return Container(
                width: isThick ? 2.2 : 1.2,
                color: isBar ? Colors.black87 : Colors.transparent,
              );
            }),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          code,
          style: const TextStyle(
            fontSize: 7,
            fontFamily: 'monospace',
            letterSpacing: 1.2,
            color: Colors.black54,
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // Dialog: Card Design & Header Settings
  // -------------------------------------------------------------
  void _showDesignSettingsDialog(BuildContext context, String lang) {
    final schoolNameController = TextEditingController(text: _schoolName);
    final schoolAddrController = TextEditingController(text: _schoolAddress);
    final schoolPhoneController = TextEditingController(text: _schoolPhone);

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final theme = Theme.of(dialogCtx);

            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.tune, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    lang == 'ne'
                        ? 'परिचय पत्र ढाँचा सेटिङ'
                        : 'ID Card Design Settings',
                  ),
                ],
              ),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // School Name
                      TextField(
                        controller: schoolNameController,
                        decoration: AppInputDecoration.standard(
                          dialogCtx,
                          labelText:
                              lang == 'ne'
                                  ? 'विद्यालय/संस्थाको नाम'
                                  : 'Institution Name',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: schoolAddrController,
                        decoration: AppInputDecoration.standard(
                          dialogCtx,
                          labelText: lang == 'ne' ? 'ठेगाना' : 'Address',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: schoolPhoneController,
                        decoration: AppInputDecoration.standard(
                          dialogCtx,
                          labelText:
                              lang == 'ne' ? 'फोन नम्बर' : 'Contact Phone',
                        ),
                      ),
                      const SizedBox(height: 16),

                      Text(
                        lang == 'ne'
                            ? 'कार्डमा देखाइने विवरणहरू:'
                            : 'Display Options:',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      SwitchListTile(
                        title: Text(
                          lang == 'ne' ? 'बारकोड (Barcode)' : 'Show Barcode',
                        ),
                        value: _showBarcode,
                        onChanged: (val) {
                          setDialogState(() => _showBarcode = val);
                          setState(() {});
                        },
                      ),
                      SwitchListTile(
                        title: Text(
                          lang == 'ne'
                              ? 'रक्त समूह (Blood Group)'
                              : 'Show Blood Group',
                        ),
                        value: _showBloodGroup,
                        onChanged: (val) {
                          setDialogState(() => _showBloodGroup = val);
                          setState(() {});
                        },
                      ),
                      SwitchListTile(
                        title: Text(
                          lang == 'ne'
                              ? 'आपतकालीन सम्पर्क (Emergency Contact)'
                              : 'Show Emergency Contact',
                        ),
                        value: _showEmergencyContact,
                        onChanged: (val) {
                          setDialogState(() => _showEmergencyContact = val);
                          setState(() {});
                        },
                      ),
                      SwitchListTile(
                        title: Text(
                          lang == 'ne'
                              ? 'नियुक्ति मिति (Joining Date)'
                              : 'Show Joining Date',
                        ),
                        value: _showJoiningDate,
                        onChanged: (val) {
                          setDialogState(() => _showJoiningDate = val);
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(lang == 'ne' ? 'रद्द' : 'Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    setState(() {
                      _schoolName = schoolNameController.text.trim();
                      _schoolAddress = schoolAddrController.text.trim();
                      _schoolPhone = schoolPhoneController.text.trim();
                    });
                    Navigator.of(ctx).pop();
                  },
                  child: Text(
                    lang == 'ne' ? 'लागू गर्नुहोस्' : 'Apply Settings',
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // -------------------------------------------------------------
  // Printing Handlers
  // -------------------------------------------------------------
  void _handlePrintAction(
    BuildContext context,
    AsyncValue<List<Employee>> employeesAsync,
    String lang,
  ) {
    final allEmployees = employeesAsync.asData?.value ?? [];
    if (allEmployees.isEmpty) return;

    final targetEmployees =
        _selectedEmployeeIds.isEmpty
            ? (_previewEmployee != null
                ? [_previewEmployee!]
                : allEmployees.take(8).toList())
            : allEmployees
                .where((e) => _selectedEmployeeIds.contains(e.id))
                .toList();

    _showPrintBatchDialog(context, targetEmployees, lang);
  }

  void _showSinglePrintDialog(
    BuildContext context,
    Employee employee,
    String lang,
  ) {
    _showPrintBatchDialog(context, [employee], lang);
  }

  void _showPrintBatchDialog(
    BuildContext context,
    List<Employee> employeesToPrint,
    String lang,
  ) {
    showDialog(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);

        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: AppRadius.roundedLg),
          child: Container(
            width: 720,
            constraints: const BoxConstraints(maxHeight: 700),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Modal Title
                Row(
                  children: [
                    Icon(
                      Icons.print,
                      size: 24,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lang == 'ne'
                                ? 'परिचय पत्र प्रिन्ट पूर्वावलोकन'
                                : 'ID Cards Print Preview',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${employeesToPrint.length} ${lang == 'ne' ? 'कर्मचारी छनोट गरियो' : 'employees selected'} • A4 Sheet (8 Cards Layout)',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const Divider(height: 24),

                // Sheet Preview Simulation
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: AppRadius.roundedMd,
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: SingleChildScrollView(
                      child: Center(
                        child: Container(
                          width: 580,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(25),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '$_schoolName — A4 ID Card Print Sheet',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  Text(
                                    'Orientation: ${_isVertical ? 'Portrait' : 'Landscape'}',
                                    style: const TextStyle(
                                      fontSize: 9,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children:
                                    employeesToPrint.map((emp) {
                                      return Transform.scale(
                                        scale: 0.85,
                                        alignment: Alignment.topLeft,
                                        child:
                                            _isVertical
                                                ? _buildVerticalFrontCard(emp)
                                                : _buildHorizontalFrontCard(
                                                  emp,
                                                ),
                                      );
                                    }).toList(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Print Footer Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: Text(lang == 'ne' ? 'बन्द गर्नुहोस्' : 'Close'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      icon: const Icon(Icons.print, size: 18),
                      label: Text(
                        lang == 'ne' ? 'प्रिन्ट पठाउनुहोस्' : 'Send to Printer',
                      ),
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        context.showSnackbar(
                          SnackBar(
                            content: Text(
                              lang == 'ne'
                                  ? '${employeesToPrint.length} वटा परिचय पत्र प्रिन्टिङका लागि पठाइयो।'
                                  : 'Sent ${employeesToPrint.length} ID card(s) to system printer.',
                            ),
                            backgroundColor: Colors.green.shade700,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
