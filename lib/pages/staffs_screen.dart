import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../config/enums.dart';
import '../config/responsive.dart';
import '../config/translations.dart';
import '../data/app_database.dart';
import '../providers/calendar_provider.dart';
import '../providers/employee_provider.dart';
import '../providers/locale_provider.dart';
import '../utils/date_time_utils.dart';
import '../utils/validators.dart';
import '../widgets/app_input.dart';
import '../widgets/dual_date_picker.dart';

class StaffsScreen extends ConsumerStatefulWidget {
  const StaffsScreen({super.key});

  @override
  ConsumerState<StaffsScreen> createState() => _StaffsScreenState();
}

class _StaffsScreenState extends ConsumerState<StaffsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedRole;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final staffAsync = ref.watch(staffStreamProvider);
    final currentLang = ref.watch(localeProvider);
    final langCode = currentLang.locale.languageCode;
    final isNepali = langCode == 'ne';
    final calendarMode = ref.watch(calendarProvider);

    return Scaffold(
      body: staffAsync.when(
        data: (staffList) {
          final totalCount = staffList.length;
          final activeCount = staffList.where((s) => s.isActive).length;
          final roles =
              staffList
                  .map((s) => s.designation)
                  .where((r) => r.trim().isNotEmpty)
                  .toSet()
                  .toList()
                ..sort();

          final filtered =
              staffList.where((s) {
                if (_selectedRole != null && s.designation != _selectedRole) {
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
                    roles.length,
                    langCode,
                  ),
                  const SizedBox(height: 16),

                  // Search Bar & Role Filter
                  _buildSearchBarAndFilter(context, roles, langCode),
                  const SizedBox(height: 20),

                  // Staff List / Grid
                  if (filtered.isEmpty)
                    _buildEmptyState(context, langCode)
                  else
                    _buildStaffGrid(
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
                  text: 'Error loading staff: $err',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openStaffDialog(context, null, langCode),
        icon: const Icon(Icons.person_add),
        label: Text(AppTranslations.text('add_staff', langCode)),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    int totalCount,
    int activeCount,
    int roleCount,
    String langCode,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.teal.withAlpha(20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.teal.withAlpha(40)),
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
                    AppTranslations.text('staff', langCode),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.teal.shade800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    langCode == 'ne'
                        ? 'प्रशासनिक तथा गैर-शैक्षिक कर्मचारी व्यवस्थापन (लेखापाल, पियन, सुरक्षा गार्ड आदि)'
                        : 'Administrative & non-teaching staff (Accountant, Peon, Guard, etc.)',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: Colors.teal),
                onPressed: () => _openStaffDialog(context, null, langCode),
                icon: const Icon(Icons.add, size: 18),
                label: Text(AppTranslations.text('add_staff', langCode)),
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
                Icons.badge_outlined,
                '${AppTranslations.text('staff', langCode)}: $totalCount',
                color: Colors.teal,
              ),
              _buildMetricChip(
                context,
                Icons.check_circle_outline,
                '${AppTranslations.text('active', langCode)}: $activeCount',
                color: Colors.green,
              ),
              _buildMetricChip(
                context,
                Icons.work_outline,
                '${AppTranslations.text('designation', langCode)}: $roleCount',
                color: Colors.orange,
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
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBarAndFilter(
    BuildContext context,
    List<String> roles,
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
                        ? 'कर्मचारीको नाम, पद (लेखापाल, पियन आदि) खोज्नुहोस्...'
                        : 'Search by staff name, designation (Accountant, Peon)...',
                onChanged: (val) {
                  ref.read(staffSearchQueryProvider.notifier).setQuery(val);
                },
                onClear: () {
                  ref.read(staffSearchQueryProvider.notifier).setQuery('');
                },
              ),
            ),
          ],
        ),
        if (roles.isNotEmpty) ...[
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: Text(langCode == 'ne' ? 'सबै पदहरू' : 'All Roles'),
                  selected: _selectedRole == null,
                  onSelected: (selected) {
                    setState(() {
                      _selectedRole = null;
                    });
                  },
                ),
                const SizedBox(width: 8),
                ...roles.map((role) {
                  final isSelected = _selectedRole == role;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(role),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _selectedRole = selected ? role : null;
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            Icon(
              Icons.badge_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              AppTranslations.text('no_staff', langCode),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => _openStaffDialog(context, null, langCode),
              icon: const Icon(Icons.add),
              label: Text(AppTranslations.text('add_staff', langCode)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStaffGrid(
    BuildContext context,
    List<Employee> staffList,
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
        itemCount: staffList.length,
        itemBuilder:
            (context, index) => _buildStaffCard(
              context,
              staffList[index],
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
        itemCount: staffList.length,
        itemBuilder:
            (context, index) => _buildStaffCard(
              context,
              staffList[index],
              langCode,
              isNepali,
              calendarMode,
            ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: staffList.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder:
          (context, index) => _buildStaffCard(
            context,
            staffList[index],
            langCode,
            isNepali,
            calendarMode,
          ),
    );
  }

  Widget _buildStaffCard(
    BuildContext context,
    Employee staff,
    String langCode,
    bool isNepali,
    dynamic calendarMode,
  ) {
    final theme = Theme.of(context);
    final isPeon = staff.designation.toLowerCase().contains('peon');
    final isAccountant = staff.designation.toLowerCase().contains('account');
    final isSecurity = staff.designation.toLowerCase().contains('security');
    final isLibrarian = staff.designation.toLowerCase().contains('librar');

    Color roleColor = Colors.teal;
    IconData roleIcon = Icons.badge_outlined;

    if (isAccountant) {
      roleColor = Colors.blue;
      roleIcon = Icons.calculate_outlined;
    } else if (isPeon) {
      roleColor = Colors.amber.shade800;
      roleIcon = Icons.support_agent;
    } else if (isSecurity) {
      roleColor = Colors.deepOrange;
      roleIcon = Icons.shield_outlined;
    } else if (isLibrarian) {
      roleColor = Colors.purple;
      roleIcon = Icons.local_library_outlined;
    }

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
            // Top row: Avatar, Name, Designation, and Employee ID
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: roleColor.withAlpha(30),
                  child: Icon(roleIcon, color: roleColor, size: 22),
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
                              staff.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (staff.employeeCode != null)
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
                                staff.employeeCode!,
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
                          color: roleColor.withAlpha(20),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          staff.designation,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: roleColor,
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
                if (staff.department != null)
                  _buildTag(
                    context,
                    Icons.business_outlined,
                    staff.department!,
                    Colors.indigo,
                  ),
                if (staff.qualification != null)
                  _buildTag(
                    context,
                    Icons.school_outlined,
                    staff.qualification!,
                    Colors.teal,
                  ),
                if (staff.bloodGroup != null)
                  _buildTag(
                    context,
                    Icons.bloodtype,
                    staff.bloodGroup!,
                    Colors.redAccent,
                  ),
                if (staff.gender != null)
                  _buildTag(
                    context,
                    Icons.person_outline,
                    staff.gender!,
                    Colors.blueGrey,
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // Contact Information
            if (staff.phone != null && staff.phone!.isNotEmpty)
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
                      staff.phone!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

            if (staff.email != null && staff.email!.isNotEmpty)
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
                        staff.email!,
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

            if (staff.address != null && staff.address!.isNotEmpty)
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
                        staff.address!,
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

            if (staff.dateOfBirth != null)
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
                      'DOB: ${DateTimeUtils.formatDateByMode(staff.dateOfBirth!, mode: calendarMode, inNepaliScript: isNepali)}',
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
                  tooltip: AppTranslations.text('edit_staff', langCode),
                  onPressed: () => _openStaffDialog(context, staff, langCode),
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: theme.colorScheme.error,
                  ),
                  tooltip: AppTranslations.text('delete_staff', langCode),
                  onPressed:
                      () => _confirmDeleteStaff(context, staff, langCode),
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

  Future<void> _confirmDeleteStaff(
    BuildContext context,
    Employee staff,
    String langCode,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(AppTranslations.text('delete_staff', langCode)),
            content: Text(
              langCode == 'ne'
                  ? 'के तपाईं कर्मचारी "${staff.name}" (${staff.designation}) लाई हटाउन निश्चित हुनुहुन्छ?'
                  : 'Are you sure you want to delete staff "${staff.name}" (${staff.designation})?',
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
          .deleteEmployee(staff.id);
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              langCode == 'ne'
                  ? 'कर्मचारी सफलतापूर्वक हटाइयो'
                  : 'Staff member deleted successfully',
            ),
          ),
        );
      }
    }
  }

  void _openStaffDialog(
    BuildContext context,
    Employee? staff,
    String langCode,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _StaffFormDialog(staff: staff, langCode: langCode),
    );
  }
}

class _StaffFormDialog extends ConsumerStatefulWidget {
  final Employee? staff;
  final String langCode;

  const _StaffFormDialog({required this.staff, required this.langCode});

  @override
  ConsumerState<_StaffFormDialog> createState() => _StaffFormDialogState();
}

class _StaffFormDialogState extends ConsumerState<_StaffFormDialog> {
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

  final List<String> _staffDesignationSuggestions = [
    'Senior Accountant',
    'Peon / Office Assistant',
    'Peon / Bell & Support Staff',
    'Librarian',
    'Head Security Guard',
    'Security Guard',
    'Driver',
    'Cook / Kitchen Assistant',
    'Lab Assistant',
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
    final s = widget.staff;
    _nameController = TextEditingController(text: s?.name ?? '');
    _designationController = TextEditingController(
      text: s?.designation ?? 'Peon / Office Assistant',
    );
    _departmentController = TextEditingController(
      text: s?.department ?? 'Administration',
    );
    _qualificationController = TextEditingController(
      text: s?.qualification ?? '',
    );
    _phoneController = TextEditingController(text: s?.phone ?? '');
    _emailController = TextEditingController(text: s?.email ?? '');
    _addressController = TextEditingController(text: s?.address ?? '');
    _gender = s?.gender;
    _bloodGroup = s?.bloodGroup;
    _dob = s?.dateOfBirth;
    _joiningDate = s?.joiningDate;
    _isActive = s?.isActive ?? true;
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
    final isEditing = widget.staff != null;
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
                      color: Colors.teal,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isEditing
                          ? AppTranslations.text('edit_staff', langCode)
                          : AppTranslations.text('add_staff', langCode),
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
                        // Section 1: Role & Staff Details
                        const Text(
                          'Staff Role & Department',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Name
                        TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText:
                                '${AppTranslations.text('staff', langCode)} Name *',
                            prefixIcon: const Icon(Icons.person_outline),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Please enter staff name';
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
                                '${AppTranslations.text('designation', langCode)} (e.g. Peon, Accountant) *',
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

                        // Quick Role Chips
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children:
                              _staffDesignationSuggestions.take(5).map((d) {
                                return ActionChip(
                                  label: Text(
                                    d,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _designationController.text = d;
                                      if (d.contains('Account')) {
                                        _departmentController.text =
                                            'Accounts & Finance';
                                      } else if (d.contains('Peon')) {
                                        _departmentController.text =
                                            'Administration';
                                      } else if (d.contains('Security')) {
                                        _departmentController.text = 'Security';
                                      } else if (d.contains('Librar')) {
                                        _departmentController.text = 'Library';
                                      }
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
                            hintText: 'e.g. Accounts, Maintenance',
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
                            hintText: 'e.g. B.B.S, Under SLC, Basic Literacy',
                            prefixIcon: const Icon(Icons.school_outlined),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Section 2: Personal & Contact Information
                        Text(
                          AppTranslations.text('optional_info', langCode),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal,
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
                            hintText: 'e.g. Lalitpur-12, Lagankhel',
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
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.teal,
                      ),
                      onPressed: _saveStaff,
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

  Future<void> _saveStaff() async {
    if (!_formKey.currentState!.validate()) return;

    final controller = ref.read(employeeControllerProvider.notifier);
    final isEditing = widget.staff != null;

    try {
      if (isEditing) {
        await controller.updateEmployee(
          id: widget.staff!.id,
          name: _nameController.text.trim(),
          employeeType: EmployeeType.staff,
          designation: _designationController.text.trim(),
          employeeCode: widget.staff!.employeeCode,
          department: _departmentController.text.trim(),
          qualification: _qualificationController.text.trim(),
          phone: _phoneController.text.trim(),
          email: _emailController.text.trim(),
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
          employeeType: EmployeeType.staff,
          designation: _designationController.text.trim(),
          department: _departmentController.text.trim(),
          qualification: _qualificationController.text.trim(),
          phone: _phoneController.text.trim(),
          email: _emailController.text.trim(),
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
                  ? 'Staff updated successfully'
                  : 'Staff added successfully',
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
