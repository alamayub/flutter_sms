import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../config/responsive.dart';
import '../../config/theme.dart';
import '../../config/translations.dart';
import '../../data/app_database.dart';
import '../../models/calendar_mode.dart';
import '../../providers/academic_year_provider.dart';
import '../../providers/calendar_provider.dart';
import '../../providers/locale_provider.dart';
import '../../utils/date_time_utils.dart';
import '../../utils/ui_helpers.dart';
import '../../utils/validators.dart';
import '../../widgets/app_input.dart';
import '../../widgets/dual_date_picker.dart';

class AcademicYearScreen extends ConsumerStatefulWidget {
  const AcademicYearScreen({super.key});

  @override
  ConsumerState<AcademicYearScreen> createState() => _AcademicYearScreenState();
}

class _AcademicYearScreenState extends ConsumerState<AcademicYearScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final yearsAsync = ref.watch(academicYearsStreamProvider);
    final activeYearAsync = ref.watch(activeAcademicYearProvider);
    final currentLang = ref.watch(localeProvider);
    final calendarMode = ref.watch(calendarProvider);
    final langCode = currentLang.locale.languageCode;
    final isNepali = langCode == 'ne';

    return Scaffold(
      body: yearsAsync.when(
        data: (years) {
          final filtered =
              years.where((y) {
                if (_searchQuery.isEmpty) return true;
                final query = _searchQuery.toLowerCase();
                final startBs = DateTimeUtils.formatBs(
                  DateTimeUtils.adToBs(y.startDate),
                );
                final endBs = DateTimeUtils.formatBs(
                  DateTimeUtils.adToBs(y.endDate),
                );
                final startAd = DateTimeUtils.formatAd(y.startDate);
                final endAd = DateTimeUtils.formatAd(y.endDate);
                return y.name.toLowerCase().contains(query) ||
                    startBs.contains(query) ||
                    endBs.contains(query) ||
                    startAd.contains(query) ||
                    endAd.contains(query) ||
                    (y.description?.toLowerCase().contains(query) ?? false);
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
                  // Header section
                  _buildHeader(context, years.length, langCode),
                  const SizedBox(height: 16),

                  // Active Session Banner
                  _buildActiveSessionBanner(
                    context,
                    activeYearAsync.value,
                    calendarMode,
                    isNepali,
                    langCode,
                  ),
                  const SizedBox(height: 20),

                  // Search and Actions Bar
                  _buildSearchBar(context, langCode),
                  const SizedBox(height: 16),

                  // Content list
                  if (filtered.isEmpty)
                    _buildEmptyState(context, years.isEmpty, langCode)
                  else
                    _buildYearsList(
                      context,
                      filtered,
                      calendarMode,
                      isNepali,
                      langCode,
                    ),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (err, stack) =>
                Center(child: Text('Error loading academic sessions: $err')),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, int totalCount, String langCode) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppTranslations.text('academic_session', langCode),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              langCode == 'ne'
                  ? 'कुल शैक्षिक सत्रहरू: $totalCount'
                  : 'Total Academic Sessions: $totalCount',
              style: TextStyle(
                color: Theme.of(context).textTheme.bodySmall?.color,
                fontSize: 13,
              ),
            ),
          ],
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.add, size: 18),
          label: Text(AppTranslations.text('add', langCode)),
          onPressed: () => _openAddEditDialog(context),
        ),
      ],
    );
  }

  Widget _buildActiveSessionBanner(
    BuildContext context,
    AcademicYear? activeYear,
    CalendarMode mode,
    bool isNepali,
    String langCode,
  ) {
    final theme = Theme.of(context);

    if (activeYear == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.warningColor.withAlpha(20),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.warningColor.withAlpha(60)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: AppTheme.warningColor,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                langCode == 'ne'
                    ? 'कुनै सक्रिय शैक्षिक सत्र सेट गरिएको छैन। कृपया तलबाट एउटा सत्र सक्रिय गर्नुहोस्।'
                    : 'No active academic session is selected. Please activate a session below.',
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final now = DateTime.now();
    final isWithinSession =
        now.isAfter(activeYear.startDate) && now.isBefore(activeYear.endDate);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withAlpha(15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.primary.withAlpha(50)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.school, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      langCode == 'ne' ? 'सक्रिय सत्र: ' : 'Active Session: ',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      activeYear.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isWithinSession
                                ? AppTheme.successColor
                                : AppTheme.warningColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isWithinSession
                            ? (langCode == 'ne' ? 'चालु' : 'Ongoing')
                            : (langCode == 'ne' ? 'नयाँ सत्र' : 'Scheduled'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'BS: ${DateTimeUtils.formatBs(DateTimeUtils.adToBs(activeYear.startDate))} ~ ${DateTimeUtils.formatBs(DateTimeUtils.adToBs(activeYear.endDate))}  |  AD: ${DateTimeUtils.formatAd(activeYear.startDate)} ~ ${DateTimeUtils.formatAd(activeYear.endDate)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.textTheme.bodyMedium?.color?.withAlpha(180),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context, String langCode) {
    return AppSearchField(
      controller: _searchController,
      hintText: AppTranslations.text('search', langCode),
      onChanged: (val) {
        setState(() {
          _searchQuery = val.trim();
        });
      },
      onClear: () {
        setState(() {
          _searchQuery = '';
        });
      },
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    bool isListEmpty,
    String langCode,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              isListEmpty
                  ? (langCode == 'ne'
                      ? 'कुनै शैक्षिक सत्र फेला परेन'
                      : 'No Academic Sessions Yet')
                  : (langCode == 'ne'
                      ? 'खोजी नतिजा भेटिएन'
                      : 'No sessions match your search'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (isListEmpty)
              ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: Text(AppTranslations.text('add', langCode)),
                onPressed: () => _openAddEditDialog(context),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildYearsList(
    BuildContext context,
    List<AcademicYear> list,
    CalendarMode mode,
    bool isNepali,
    String langCode,
  ) {
    final isMobile = context.isMobile;

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: list.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final year = list[index];
        return _buildYearCard(
          context,
          year,
          isMobile,
          mode,
          isNepali,
          langCode,
        );
      },
    );
  }

  Widget _buildYearCard(
    BuildContext context,
    AcademicYear year,
    bool isMobile,
    CalendarMode mode,
    bool isNepali,
    String langCode,
  ) {
    final theme = Theme.of(context);

    return Card(
      elevation: year.isCurrent ? 2 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color:
              year.isCurrent ? theme.colorScheme.primary : theme.dividerColor,
          width: year.isCurrent ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child:
            isMobile
                ? _buildMobileCardContent(
                  context,
                  year,
                  mode,
                  isNepali,
                  langCode,
                )
                : _buildDesktopCardContent(
                  context,
                  year,
                  mode,
                  isNepali,
                  langCode,
                ),
      ),
    );
  }

  Widget _buildDesktopCardContent(
    BuildContext context,
    AcademicYear year,
    CalendarMode mode,
    bool isNepali,
    String langCode,
  ) {
    final theme = Theme.of(context);

    return Row(
      children: [
        // Year Icon / Name
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color:
                year.isCurrent
                    ? theme.colorScheme.primary.withAlpha(20)
                    : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color:
                  year.isCurrent
                      ? theme.colorScheme.primary
                      : theme.dividerColor,
            ),
          ),
          child: Icon(
            Icons.date_range,
            color:
                year.isCurrent
                    ? theme.colorScheme.primary
                    : theme.iconTheme.color,
          ),
        ),
        const SizedBox(width: 16),

        // Title and Status
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    year.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (year.isCurrent) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.successColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        langCode == 'ne' ? 'सक्रिय' : 'Active',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (year.description != null && year.description!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  year.description!,
                  style: TextStyle(
                    color: theme.textTheme.bodySmall?.color,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),

        // Dates (Dual BS & AD)
        Expanded(
          flex: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.event,
                    size: 14,
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'BS: ${DateTimeUtils.formatBs(DateTimeUtils.adToBs(year.startDate))} to ${DateTimeUtils.formatBs(DateTimeUtils.adToBs(year.endDate))}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.schedule, size: 14, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(
                    'AD: ${DateTimeUtils.formatAd(year.startDate)} to ${DateTimeUtils.formatAd(year.endDate)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.textTheme.bodySmall?.color,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Action Buttons
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!year.isCurrent)
              OutlinedButton.icon(
                icon: const Icon(Icons.check, size: 16),
                label: Text(
                  langCode == 'ne' ? 'सक्रिय गर्नुहोस्' : 'Set Active',
                ),
                onPressed: () => _setActive(year),
              ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18),
              tooltip: AppTranslations.text('edit', langCode),
              onPressed: () => _openAddEditDialog(context, year: year),
            ),
            IconButton(
              icon: const Icon(
                Icons.delete_outline,
                color: AppTheme.errorColor,
                size: 18,
              ),
              tooltip: AppTranslations.text('delete', langCode),
              onPressed: () => _confirmDelete(year, langCode),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMobileCardContent(
    BuildContext context,
    AcademicYear year,
    CalendarMode mode,
    bool isNepali,
    String langCode,
  ) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              year.name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            if (year.isCurrent)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.successColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  langCode == 'ne' ? 'सक्रिय' : 'Active',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'BS: ${DateTimeUtils.formatBs(DateTimeUtils.adToBs(year.startDate))} ~ ${DateTimeUtils.formatBs(DateTimeUtils.adToBs(year.endDate))}',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 2),
        Text(
          'AD: ${DateTimeUtils.formatAd(year.startDate)} ~ ${DateTimeUtils.formatAd(year.endDate)}',
          style: TextStyle(
            fontSize: 12,
            color: theme.textTheme.bodySmall?.color,
          ),
        ),
        if (year.description != null && year.description!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            year.description!,
            style: TextStyle(
              fontSize: 12,
              color: theme.textTheme.bodySmall?.color,
            ),
          ),
        ],
        const Divider(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (!year.isCurrent)
              TextButton.icon(
                icon: const Icon(Icons.check, size: 16),
                label: Text(langCode == 'ne' ? 'सक्रिय' : 'Activate'),
                onPressed: () => _setActive(year),
              ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18),
              onPressed: () => _openAddEditDialog(context, year: year),
            ),
            IconButton(
              icon: const Icon(
                Icons.delete_outline,
                color: AppTheme.errorColor,
                size: 18,
              ),
              onPressed: () => _confirmDelete(year, langCode),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _setActive(AcademicYear year) async {
    await ref
        .read(academicYearControllerProvider.notifier)
        .setActiveYear(year.id);
    if (mounted) {
      UiHelpers.showSnackBar(
        context,
        '${year.name} is now the active academic session',
        isSuccess: true,
      );
    }
  }

  Future<void> _confirmDelete(AcademicYear year, String langCode) async {
    final isConfirmed = await UiHelpers.showConfirmationDialog(
      context,
      title:
          langCode == 'ne'
              ? 'शैक्षिक सत्र मेटाउनुहोस्'
              : 'Delete Academic Session',
      message:
          langCode == 'ne'
              ? 'के तपाईं निश्चित हुनुहुन्छ "${year.name}" सत्र हटाउन चाहनुहुन्छ?'
              : 'Are you sure you want to delete session "${year.name}"? This action cannot be undone.',
      confirmText: AppTranslations.text('delete', langCode),
      isDestructive: true,
    );

    if (isConfirmed && mounted) {
      await ref
          .read(academicYearControllerProvider.notifier)
          .deleteYear(year.id);
      if (mounted) {
        UiHelpers.showSnackBar(
          context,
          'Session deleted successfully',
          isSuccess: true,
        );
      }
    }
  }

  void _openAddEditDialog(BuildContext context, {AcademicYear? year}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AcademicYearFormDialog(year: year),
    );
  }
}

class _AcademicYearFormDialog extends ConsumerStatefulWidget {
  final AcademicYear? year;

  const _AcademicYearFormDialog({this.year});

  @override
  ConsumerState<_AcademicYearFormDialog> createState() =>
      _AcademicYearFormDialogState();
}

class _AcademicYearFormDialogState
    extends ConsumerState<_AcademicYearFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descController;
  late DateTime _startDate;
  late DateTime _endDate;
  late bool _isCurrent;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final isEditing = widget.year != null;

    if (isEditing) {
      _nameController = TextEditingController(text: widget.year!.name);
      _descController = TextEditingController(
        text: widget.year!.description ?? '',
      );
      _startDate = widget.year!.startDate;
      _endDate = widget.year!.endDate;
      _isCurrent = widget.year!.isCurrent;
    } else {
      // Default: current Nepali academic session (e.g. 2081/82)
      final nowBs = DateTimeUtils.nowBs;
      final yearStr = DateTimeUtils.getAcademicYearBs(nowBs);
      _nameController = TextEditingController(text: '$yearStr BS');
      _descController = TextEditingController();
      _startDate = DateTime.now();
      _endDate = DateTime.now().add(const Duration(days: 365));
      _isCurrent = true;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.year != null;
    final currentLang = ref.watch(localeProvider);
    final langCode = currentLang.locale.languageCode;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        isEditing
            ? (langCode == 'ne'
                ? 'शैक्षिक सत्र सम्पादन'
                : 'Edit Academic Session')
            : (langCode == 'ne'
                ? 'नयाँ शैक्षिक सत्र थप्नुहोस्'
                : 'New Academic Session'),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name Field
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText:
                        langCode == 'ne' ? 'सत्रको नाम *' : 'Session Name *',
                    hintText: 'e.g. 2081/82 BS',
                    prefixIcon: const Icon(Icons.label_outline),
                  ),
                  validator:
                      (v) => Validators.requiredField(
                        v,
                        'Session name is required',
                      ),
                ),
                const SizedBox(height: 14),

                // Start Date Picker (Dual AD & BS)
                DualDatePickerField(
                  label: langCode == 'ne' ? 'सुरु मिति *' : 'Start Date *',
                  selectedDate: _startDate,
                  onDateSelected: (newDate) {
                    setState(() {
                      _startDate = newDate;
                      if (_endDate.isBefore(_startDate)) {
                        _endDate = _startDate.add(const Duration(days: 365));
                      }
                    });
                  },
                ),
                const SizedBox(height: 14),

                // End Date Picker (Dual AD & BS)
                DualDatePickerField(
                  label: langCode == 'ne' ? 'अन्त्य मिति *' : 'End Date *',
                  selectedDate: _endDate,
                  onDateSelected: (newDate) {
                    setState(() {
                      _endDate = newDate;
                    });
                  },
                ),
                const SizedBox(height: 14),

                // Active Switch
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    langCode == 'ne'
                        ? 'सक्रिय सत्र बनाउनुहोस्'
                        : 'Set as Active Session',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    langCode == 'ne'
                        ? 'यसले अन्य सबै सत्रहरूलाई निष्क्रिय बनाउनेछ'
                        : 'This will automatically deactivate all other sessions',
                    style: const TextStyle(fontSize: 12),
                  ),
                  value: _isCurrent,
                  onChanged: (val) {
                    setState(() {
                      _isCurrent = val;
                    });
                  },
                ),
                const SizedBox(height: 8),

                // Description Field
                TextFormField(
                  controller: _descController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText:
                        langCode == 'ne'
                            ? 'विवरण (ऐच्छिक)'
                            : 'Description (Optional)',
                    hintText: 'Add notes about this academic session...',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: Text(AppTranslations.text('cancel', langCode)),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _save,
          child:
              _isSubmitting
                  ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                  : Text(AppTranslations.text('save', langCode)),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_endDate.isBefore(_startDate)) {
      UiHelpers.showSnackBar(
        context,
        'End date must be after start date',
        isError: true,
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final controller = ref.read(academicYearControllerProvider.notifier);
      final isEditing = widget.year != null;

      if (isEditing) {
        await controller.updateYear(
          id: widget.year!.id,
          name: _nameController.text,
          startDate: _startDate,
          endDate: _endDate,
          isCurrent: _isCurrent,
          description: _descController.text,
        );
      } else {
        await controller.createYear(
          name: _nameController.text,
          startDate: _startDate,
          endDate: _endDate,
          isCurrent: _isCurrent,
          description: _descController.text,
        );
      }

      if (mounted) {
        Navigator.of(context).pop();
        UiHelpers.showSnackBar(
          context,
          isEditing ? 'Academic session updated' : 'Academic session created',
          isSuccess: true,
        );
      }
    } catch (e) {
      if (mounted) {
        UiHelpers.showSnackBar(context, 'Failed to save: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }
}
