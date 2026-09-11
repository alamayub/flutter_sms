import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nepali_utils/nepali_utils.dart';

import '../config/theme.dart';
import '../config/translations.dart';
import '../data/app_database.dart';
import '../models/calendar_mode.dart';
import '../providers/academic_year_provider.dart';
import '../providers/attendance_provider.dart';
import '../providers/calendar_provider.dart';
import '../providers/class_section_provider.dart';
import '../providers/locale_provider.dart';
import '../services/attendance_service.dart';
import '../utils/date_time_utils.dart';

class AttendanceScreen extends ConsumerStatefulWidget {
  final int? fixedTab;
  const AttendanceScreen({super.key, this.fixedTab});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class StudentAttendanceScreen extends StatelessWidget {
  const StudentAttendanceScreen({super.key});

  @override
  Widget build(BuildContext context) => const AttendanceScreen(fixedTab: 0);
}

class EmployeeAttendanceScreen extends StatelessWidget {
  const EmployeeAttendanceScreen({super.key});

  @override
  Widget build(BuildContext context) => const AttendanceScreen(fixedTab: 1);
}

class AttendanceReportScreen extends StatelessWidget {
  const AttendanceReportScreen({super.key});

  @override
  Widget build(BuildContext context) => const AttendanceScreen(fixedTab: 2);
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _studentSearchController =
      TextEditingController();
  final TextEditingController _staffSearchController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.fixedTab ?? 0,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _studentSearchController.dispose();
    _staffSearchController.dispose();
    super.dispose();
  }

  String _formatDateDual(DateTime date, CalendarMode mode, String lang) {
    final adStr = DateFormat('yyyy-MM-dd (EEE)').format(date);
    final bs = date.toNepaliDateTime();
    final bsMonth =
        lang == 'ne'
            ? DateTimeUtils.bsMonthNamesNe[bs.month - 1]
            : DateTimeUtils.bsMonthNamesEn[bs.month - 1];
    final bsStr = '${bs.year} $bsMonth ${bs.day}';

    if (mode == CalendarMode.bs) {
      return '$bsStr BS  •  $adStr AD';
    } else {
      return '$adStr AD  •  $bsStr BS';
    }
  }

  Future<void> _pickDate(
    BuildContext context,
    DateTime currentDate,
    void Function(DateTime) onSelected,
  ) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: currentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      onSelected(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lang = ref.watch(localeProvider).locale.languageCode;
    final calendarMode = ref.watch(calendarProvider);

    final isStandalone = widget.fixedTab != null;
    final standaloneIndex = widget.fixedTab ?? 0;

    IconData headerIcon;
    String headerTitle;
    String headerSubtitle;

    if (isStandalone) {
      switch (standaloneIndex) {
        case 0:
          headerIcon = Icons.school_rounded;
          headerTitle = AppTranslations.text('student_attendance', lang);
          headerSubtitle =
              lang == 'ne'
                  ? 'कक्षा र सेक्सन अनुसार विद्यार्थीहरूको दैनिक रोल कल तथा हाजिरी'
                  : 'Daily roll call and attendance tracking for students by class & section';
          break;
        case 1:
          headerIcon = Icons.badge_rounded;
          headerTitle = AppTranslations.text('employee_attendance', lang);
          headerSubtitle =
              lang == 'ne'
                  ? 'कर्मचारीहरूको दैनिक हाजिरी, आगमन र प्रस्थान समय'
                  : 'Track daily attendance, shift timings, and leaves for employees';
          break;
        default:
          headerIcon = Icons.calendar_month_rounded;
          headerTitle = AppTranslations.text('attendance_register', lang);
          headerSubtitle =
              lang == 'ne'
                  ? 'विद्यार्थी तथा कर्मचारीहरूको मासिक हाजिरी अभिलेख र प्रतिवेदन'
                  : 'Monthly attendance registers, calendars, and performance reports';
          break;
      }
    } else {
      headerIcon = Icons.how_to_reg_rounded;
      headerTitle = AppTranslations.text('attendance', lang);
      headerSubtitle =
          lang == 'ne'
              ? 'विद्यार्थी तथा कर्मचारीहरूको दैनिक हाजिरी र मासिक अभिलेख'
              : 'Track and manage daily attendance and monthly registers for students & employees';
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // 1. Top Header Banner
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
                      headerIcon,
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
                          headerTitle,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          headerSubtitle,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. Segmented Tab Bar (only shown when not in standalone mode)
          if (!isStandalone)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withAlpha(
                      80,
                    ),
                    borderRadius: AppRadius.roundedXl,
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicator: BoxDecoration(
                      borderRadius: AppRadius.roundedXl,
                      color: theme.colorScheme.primary,
                    ),
                    labelColor: theme.colorScheme.onPrimary,
                    unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    tabs: [
                      Tab(
                        icon: const Icon(Icons.school_outlined, size: 20),
                        text: AppTranslations.text('student_attendance', lang),
                      ),
                      Tab(
                        icon: const Icon(Icons.badge_outlined, size: 20),
                        text: AppTranslations.text('employee_attendance', lang),
                      ),
                      Tab(
                        icon: const Icon(
                          Icons.calendar_month_outlined,
                          size: 20,
                        ),
                        text: AppTranslations.text('attendance_register', lang),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 3. Content View
          SliverFillRemaining(
            child:
                isStandalone
                    ? (standaloneIndex == 0
                        ? _buildStudentAttendanceTab(
                          context,
                          theme,
                          lang,
                          calendarMode,
                        )
                        : standaloneIndex == 1
                        ? _buildStaffAttendanceTab(
                          context,
                          theme,
                          lang,
                          calendarMode,
                        )
                        : _buildAttendanceRegisterTab(
                          context,
                          theme,
                          lang,
                          calendarMode,
                        ))
                    : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildStudentAttendanceTab(
                          context,
                          theme,
                          lang,
                          calendarMode,
                        ),
                        _buildStaffAttendanceTab(
                          context,
                          theme,
                          lang,
                          calendarMode,
                        ),
                        _buildAttendanceRegisterTab(
                          context,
                          theme,
                          lang,
                          calendarMode,
                        ),
                      ],
                    ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 1: STUDENT ATTENDANCE
  // ===========================================================================

  Widget _buildStudentAttendanceTab(
    BuildContext context,
    ThemeData theme,
    String lang,
    CalendarMode calendarMode,
  ) {
    final classesAsync = ref.watch(classesWithSectionsStreamProvider);
    final activeYearAsync = ref.watch(activeAcademicYearProvider);
    final selectedClassId = ref.watch(studentAttendanceClassIdProvider);
    final selectedSectionId = ref.watch(studentAttendanceSectionIdProvider);
    final selectedDate = ref.watch(studentAttendanceDateProvider);
    final searchQuery = ref.watch(studentAttendanceSearchProvider);
    final attendanceState = ref.watch(studentAttendanceControllerProvider);
    final summary = ref.watch(studentDailySummaryProvider);

    return classesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (classes) {
        if (classes.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.class_outlined,
                  size: 48,
                  color: theme.colorScheme.outline,
                ),
                const SizedBox(height: 12),
                Text(
                  lang == 'ne' ? 'कुनै कक्षा उपलब्ध छैन' : 'No classes found',
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
          );
        }

        // Auto-select first class if none selected
        if (selectedClassId == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref
                .read(studentAttendanceClassIdProvider.notifier)
                .setClassId(classes.first.id);
            ref
                .read(studentAttendanceControllerProvider.notifier)
                .load(classId: classes.first.id, date: selectedDate);
          });
        }

        final currentClass = classes.firstWhere(
          (c) => c.id == selectedClassId,
          orElse: () => classes.first,
        );

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          children: [
            // Filter Bar Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: AppRadius.roundedXl,
                side: BorderSide(
                  color: theme.colorScheme.outlineVariant.withAlpha(100),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    // Class & Section Pickers
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Class Dropdown
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: theme.colorScheme.outlineVariant,
                            ),
                            borderRadius: AppRadius.roundedMd,
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: currentClass.id,
                              hint: Text(AppTranslations.text('class', lang)),
                              items:
                                  classes.map((c) {
                                    return DropdownMenuItem<int>(
                                      value: c.id,
                                      child: Text(
                                        c.displayName.isNotEmpty
                                            ? c.displayName
                                            : c.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                              onChanged: (newClassId) {
                                if (newClassId != null) {
                                  ref
                                      .read(
                                        studentAttendanceClassIdProvider
                                            .notifier,
                                      )
                                      .setClassId(newClassId);
                                  ref
                                      .read(
                                        studentAttendanceSectionIdProvider
                                            .notifier,
                                      )
                                      .setSectionId(null);
                                  ref
                                      .read(
                                        studentAttendanceControllerProvider
                                            .notifier,
                                      )
                                      .load(
                                        classId: newClassId,
                                        date: selectedDate,
                                      );
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Section Dropdown (if class has sections)
                        if (currentClass.sections.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: theme.colorScheme.outlineVariant,
                              ),
                              borderRadius: AppRadius.roundedMd,
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int?>(
                                value: selectedSectionId,
                                items: [
                                  DropdownMenuItem<int?>(
                                    value: null,
                                    child: Text(
                                      lang == 'ne'
                                          ? 'सबै सेक्सन'
                                          : 'All Sections',
                                    ),
                                  ),
                                  ...currentClass.sections.map((sec) {
                                    return DropdownMenuItem<int?>(
                                      value: sec.id,
                                      child: Text(
                                        '${AppTranslations.text('section', lang)} ${sec.name}',
                                      ),
                                    );
                                  }),
                                ],
                                onChanged: (newSecId) {
                                  ref
                                      .read(
                                        studentAttendanceSectionIdProvider
                                            .notifier,
                                      )
                                      .setSectionId(newSecId);
                                  ref
                                      .read(
                                        studentAttendanceControllerProvider
                                            .notifier,
                                      )
                                      .load(
                                        classId: currentClass.id,
                                        sectionId: newSecId,
                                        date: selectedDate,
                                      );
                                },
                              ),
                            ),
                          ),
                      ],
                    ),

                    // Date Navigator: < Prev | Date Picker Button | Next >
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withAlpha(90),
                        borderRadius: AppRadius.roundedLg,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left, size: 20),
                            tooltip: 'Previous Day',
                            onPressed: () {
                              final prevDay = selectedDate.subtract(
                                const Duration(days: 1),
                              );
                              ref
                                  .read(studentAttendanceDateProvider.notifier)
                                  .setDate(prevDay);
                              ref
                                  .read(
                                    studentAttendanceControllerProvider
                                        .notifier,
                                  )
                                  .load(
                                    classId: currentClass.id,
                                    sectionId: selectedSectionId,
                                    date: prevDay,
                                  );
                            },
                          ),
                          InkWell(
                            onTap:
                                () => _pickDate(context, selectedDate, (
                                  newDate,
                                ) {
                                  ref
                                      .read(
                                        studentAttendanceDateProvider.notifier,
                                      )
                                      .setDate(newDate);
                                  ref
                                      .read(
                                        studentAttendanceControllerProvider
                                            .notifier,
                                      )
                                      .load(
                                        classId: currentClass.id,
                                        sectionId: selectedSectionId,
                                        date: newDate,
                                      );
                                }),
                            borderRadius: AppRadius.roundedMd,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today_outlined,
                                    size: 16,
                                    color: theme.colorScheme.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _formatDateDual(
                                      selectedDate,
                                      calendarMode,
                                      lang,
                                    ),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right, size: 20),
                            tooltip: 'Next Day',
                            onPressed: () {
                              final nextDay = selectedDate.add(
                                const Duration(days: 1),
                              );
                              ref
                                  .read(studentAttendanceDateProvider.notifier)
                                  .setDate(nextDay);
                              ref
                                  .read(
                                    studentAttendanceControllerProvider
                                        .notifier,
                                  )
                                  .load(
                                    classId: currentClass.id,
                                    sectionId: selectedSectionId,
                                    date: nextDay,
                                  );
                            },
                          ),
                          TextButton(
                            onPressed: () {
                              final today = DateTime.now();
                              ref
                                  .read(studentAttendanceDateProvider.notifier)
                                  .setDate(today);
                              ref
                                  .read(
                                    studentAttendanceControllerProvider
                                        .notifier,
                                  )
                                  .load(
                                    classId: currentClass.id,
                                    sectionId: selectedSectionId,
                                    date: today,
                                  );
                            },
                            child: Text(lang == 'ne' ? 'आज' : 'Today'),
                          ),
                        ],
                      ),
                    ),

                    // Search input
                    SizedBox(
                      width: 220,
                      height: 40,
                      child: TextField(
                        controller: _studentSearchController,
                        decoration: InputDecoration(
                          hintText: AppTranslations.text('search', lang),
                          prefixIcon: const Icon(Icons.search, size: 18),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 0,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: AppRadius.roundedMd,
                            borderSide: BorderSide(
                              color: theme.colorScheme.outlineVariant,
                            ),
                          ),
                          suffixIcon:
                              _studentSearchController.text.isNotEmpty
                                  ? IconButton(
                                    icon: const Icon(Icons.clear, size: 16),
                                    onPressed: () {
                                      _studentSearchController.clear();
                                      ref
                                          .read(
                                            studentAttendanceSearchProvider
                                                .notifier,
                                          )
                                          .setSearch('');
                                    },
                                  )
                                  : null,
                        ),
                        onChanged:
                            (val) => ref
                                .read(studentAttendanceSearchProvider.notifier)
                                .setSearch(val),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Summary KPI Cards Row
            _buildKpiRow(
              context: context,
              theme: theme,
              lang: lang,
              summary: summary,
              excusedLabel: AppTranslations.text('excused', lang),
            ),
            const SizedBox(height: AppSpacing.md),

            // Bulk Actions Toolbar
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerHighest.withAlpha(50),
              shape: RoundedRectangleBorder(
                borderRadius: AppRadius.roundedLg,
                side: BorderSide(
                  color: theme.colorScheme.outlineVariant.withAlpha(80),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Text(
                      lang == 'ne' ? 'द्रुत कार्यहरू:' : 'Quick Actions:',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.tonalIcon(
                      icon: const Icon(
                        Icons.check_circle_outline,
                        size: 16,
                        color: Color(0xFF10B981),
                      ),
                      label: Text(
                        AppTranslations.text('mark_all_present', lang),
                        style: const TextStyle(
                          color: Color(0xFF047857),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFD1FAE5),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      onPressed: () {
                        ref
                            .read(studentAttendanceControllerProvider.notifier)
                            .markAll(AttendanceStatus.present);
                      },
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonalIcon(
                      icon: const Icon(
                        Icons.cancel_outlined,
                        size: 16,
                        color: Color(0xFFEF4444),
                      ),
                      label: Text(
                        AppTranslations.text('mark_all_absent', lang),
                        style: const TextStyle(
                          color: Color(0xFFB91C1C),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFEE2E2),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      onPressed: () {
                        ref
                            .read(studentAttendanceControllerProvider.notifier)
                            .markAll(AttendanceStatus.absent);
                      },
                    ),
                    const Spacer(),

                    // Save Button
                    FilledButton.icon(
                      icon:
                          _isSaving
                              ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                              : const Icon(Icons.save_outlined, size: 18),
                      label: Text(
                        AppTranslations.text('save_attendance', lang),
                      ),
                      onPressed:
                          _isSaving
                              ? null
                              : () async {
                                final activeYear =
                                    activeYearAsync.asData?.value;
                                if (activeYear == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'No active academic year found.',
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                setState(() => _isSaving = true);
                                final success = await ref
                                    .read(
                                      studentAttendanceControllerProvider
                                          .notifier,
                                    )
                                    .save(
                                      academicYearId: activeYear.id,
                                      classId: currentClass.id,
                                      sectionId: selectedSectionId,
                                      date: selectedDate,
                                    );
                                setState(() => _isSaving = false);

                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        success
                                            ? (lang == 'ne'
                                                ? 'हाजिरी सफलतापूर्वक सुरक्षित गरियो!'
                                                : 'Attendance saved successfully!')
                                            : 'Failed to save attendance.',
                                      ),
                                      backgroundColor:
                                          success
                                              ? const Color(0xFF10B981)
                                              : const Color(0xFFEF4444),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                }
                              },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Students Attendance Table
            attendanceState.when(
              loading:
                  () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ),
                  ),
              error:
                  (e, _) => Center(child: Text('Error loading attendance: $e')),
              data: (items) {
                // Apply search filtering
                final filtered =
                    items.where((item) {
                      if (searchQuery.trim().isEmpty) return true;
                      final query = searchQuery.toLowerCase();
                      final nameMatch = item.student.name
                          .toLowerCase()
                          .contains(query);
                      final rollMatch =
                          item.student.rollNumber?.toString().contains(query) ??
                          false;
                      final codeMatch = item.student.studentId
                          .toLowerCase()
                          .contains(query);
                      return nameMatch || rollMatch || codeMatch;
                    }).toList();

                if (filtered.isEmpty) {
                  return Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.roundedLg,
                      side: BorderSide(color: theme.colorScheme.outlineVariant),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Text(
                          items.isEmpty
                              ? (lang == 'ne'
                                  ? 'यस कक्षामा कुनै विद्यार्थी भर्ना भएका छैनन्।'
                                  : 'No students enrolled in this class.')
                              : (lang == 'ne'
                                  ? 'खोजिएको कुनै विद्यार्थी भेटिएन।'
                                  : 'No matching students found.'),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ),
                    ),
                  );
                }

                return Card(
                  elevation: 0,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.roundedXl,
                    side: BorderSide(
                      color: theme.colorScheme.outlineVariant.withAlpha(100),
                    ),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(
                        theme.colorScheme.surfaceContainerHighest.withAlpha(
                          120,
                        ),
                      ),
                      dataRowMinHeight: 52,
                      dataRowMaxHeight: 56,
                      columnSpacing: 24,
                      columns: [
                        DataColumn(
                          label: Text(
                            lang == 'ne' ? 'रोल नं' : 'Roll',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            lang == 'ne' ? 'विद्यार्थीको नाम' : 'Student Name',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            AppTranslations.text('attendance', lang),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            AppTranslations.text('remarks', lang),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                      rows:
                          filtered.map((item) {
                            return DataRow(
                              cells: [
                                // Roll No
                                DataCell(
                                  Container(
                                    width: 32,
                                    height: 32,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary
                                          .withAlpha(20),
                                      borderRadius: AppRadius.roundedSm,
                                    ),
                                    child: Text(
                                      item.student.rollNumber?.toString() ??
                                          '-',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                ),

                                // Student Name & ID
                                DataCell(
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 16,
                                        backgroundColor: theme
                                            .colorScheme
                                            .secondary
                                            .withAlpha(30),
                                        child: Text(
                                          item.student.name.isNotEmpty
                                              ? item.student.name[0]
                                                  .toUpperCase()
                                              : '?',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: theme.colorScheme.secondary,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            item.student.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                            ),
                                          ),
                                          Text(
                                            item.student.studentId,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: theme.colorScheme.outline,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                // Status Toggle Pills
                                DataCell(
                                  _buildStudentStatusSelector(
                                    currentStatus: item.status,
                                    onStatusChanged: (newStatus) {
                                      ref
                                          .read(
                                            studentAttendanceControllerProvider
                                                .notifier,
                                          )
                                          .updateStatus(
                                            item.student.id,
                                            newStatus,
                                          );
                                    },
                                  ),
                                ),

                                // Remarks Field
                                DataCell(
                                  SizedBox(
                                    width: 180,
                                    height: 36,
                                    child: TextField(
                                      controller: TextEditingController(
                                          text: item.remarks ?? '',
                                        )
                                        ..selection = TextSelection.collapsed(
                                          offset: (item.remarks ?? '').length,
                                        ),
                                      decoration: InputDecoration(
                                        hintText:
                                            lang == 'ne'
                                                ? 'कैफियत थप्नुहोस्'
                                                : 'Add note...',
                                        hintStyle: TextStyle(
                                          fontSize: 12,
                                          color: theme.colorScheme.outline,
                                        ),
                                        isDense: true,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 8,
                                            ),
                                        border: OutlineInputBorder(
                                          borderRadius: AppRadius.roundedSm,
                                          borderSide: BorderSide(
                                            color: theme
                                                .colorScheme
                                                .outlineVariant
                                                .withAlpha(120),
                                          ),
                                        ),
                                      ),
                                      style: const TextStyle(fontSize: 12),
                                      onSubmitted: (val) {
                                        ref
                                            .read(
                                              studentAttendanceControllerProvider
                                                  .notifier,
                                            )
                                            .updateRemarks(
                                              item.student.id,
                                              val,
                                            );
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
          ],
        );
      },
    );
  }

  Widget _buildStudentStatusSelector({
    required AttendanceStatus currentStatus,
    required void Function(AttendanceStatus) onStatusChanged,
  }) {
    final statuses = [
      AttendanceStatus.present,
      AttendanceStatus.absent,
      AttendanceStatus.late,
      AttendanceStatus.halfDay,
      AttendanceStatus.excused,
    ];

    return Row(
      mainAxisSize: MainAxisSize.min,
      children:
          statuses.map((status) {
            final isSelected = currentStatus == status;
            Color baseColor;
            String label;

            switch (status) {
              case AttendanceStatus.present:
                baseColor = const Color(0xFF10B981);
                label = 'P';
                break;
              case AttendanceStatus.absent:
                baseColor = const Color(0xFFEF4444);
                label = 'A';
                break;
              case AttendanceStatus.late:
                baseColor = const Color(0xFFF59E0B);
                label = 'L';
                break;
              case AttendanceStatus.halfDay:
                baseColor = const Color(0xFF8B5CF6);
                label = 'HD';
                break;
              case AttendanceStatus.excused:
              case AttendanceStatus.onLeave:
                baseColor = const Color(0xFF06B6D4);
                label = 'EX';
                break;
            }

            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: InkWell(
                onTap: () => onStatusChanged(status),
                borderRadius: AppRadius.roundedFull,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? baseColor : baseColor.withAlpha(20),
                    borderRadius: AppRadius.roundedFull,
                    border: Border.all(
                      color: isSelected ? baseColor : baseColor.withAlpha(80),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : baseColor,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
    );
  }

  // ===========================================================================
  // TAB 2: STAFF & TEACHER ATTENDANCE
  // ===========================================================================

  Widget _buildStaffAttendanceTab(
    BuildContext context,
    ThemeData theme,
    String lang,
    CalendarMode calendarMode,
  ) {
    final selectedDate = ref.watch(staffAttendanceDateProvider);
    final selectedDept = ref.watch(staffAttendanceDepartmentProvider);
    final selectedType = ref.watch(staffAttendanceTypeProvider);
    final searchQuery = ref.watch(staffAttendanceSearchProvider);
    final staffState = ref.watch(staffAttendanceControllerProvider);
    final summary = ref.watch(staffDailySummaryProvider);

    // Initial load for staff
    ref.listen(staffAttendanceDateProvider, (prev, next) {
      ref
          .read(staffAttendanceControllerProvider.notifier)
          .load(
            date: next,
            department: selectedDept,
            employeeType: selectedType,
          );
    });

    if (staffState is AsyncData && staffState.value!.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(staffAttendanceControllerProvider.notifier)
            .load(
              date: selectedDate,
              department: selectedDept,
              employeeType: selectedType,
            );
      });
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      children: [
        // Filter Bar Card
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.roundedXl,
            side: BorderSide(
              color: theme.colorScheme.outlineVariant.withAlpha(100),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 16,
              runSpacing: 16,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                // Date Navigator
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withAlpha(
                      90,
                    ),
                    borderRadius: AppRadius.roundedLg,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left, size: 20),
                        tooltip: 'Previous Day',
                        onPressed: () {
                          final prevDay = selectedDate.subtract(
                            const Duration(days: 1),
                          );
                          ref
                              .read(staffAttendanceDateProvider.notifier)
                              .setDate(prevDay);
                          ref
                              .read(staffAttendanceControllerProvider.notifier)
                              .load(
                                date: prevDay,
                                department: selectedDept,
                                employeeType: selectedType,
                              );
                        },
                      ),
                      InkWell(
                        onTap:
                            () => _pickDate(context, selectedDate, (newDate) {
                              ref
                                  .read(staffAttendanceDateProvider.notifier)
                                  .setDate(newDate);
                              ref
                                  .read(
                                    staffAttendanceControllerProvider.notifier,
                                  )
                                  .load(
                                    date: newDate,
                                    department: selectedDept,
                                    employeeType: selectedType,
                                  );
                            }),
                        borderRadius: AppRadius.roundedMd,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_today_outlined,
                                size: 16,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _formatDateDual(
                                  selectedDate,
                                  calendarMode,
                                  lang,
                                ),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right, size: 20),
                        tooltip: 'Next Day',
                        onPressed: () {
                          final nextDay = selectedDate.add(
                            const Duration(days: 1),
                          );
                          ref
                              .read(staffAttendanceDateProvider.notifier)
                              .setDate(nextDay);
                          ref
                              .read(staffAttendanceControllerProvider.notifier)
                              .load(
                                date: nextDay,
                                department: selectedDept,
                                employeeType: selectedType,
                              );
                        },
                      ),
                      TextButton(
                        onPressed: () {
                          final today = DateTime.now();
                          ref
                              .read(staffAttendanceDateProvider.notifier)
                              .setDate(today);
                          ref
                              .read(staffAttendanceControllerProvider.notifier)
                              .load(
                                date: today,
                                department: selectedDept,
                                employeeType: selectedType,
                              );
                        },
                        child: Text(lang == 'ne' ? 'आज' : 'Today'),
                      ),
                    ],
                  ),
                ),

                // Role Selector (Teacher vs Staff)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant,
                        ),
                        borderRadius: AppRadius.roundedMd,
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<EmployeeType?>(
                          value: selectedType,
                          items: [
                            DropdownMenuItem<EmployeeType?>(
                              value: null,
                              child: Text(
                                lang == 'ne' ? 'सबै कर्मचारी' : 'All Employees',
                              ),
                            ),
                            DropdownMenuItem<EmployeeType?>(
                              value: EmployeeType.teacher,
                              child: Text(
                                lang == 'ne' ? 'शिक्षक मात्र' : 'Teachers Only',
                              ),
                            ),
                            DropdownMenuItem<EmployeeType?>(
                              value: EmployeeType.staff,
                              child: Text(
                                lang == 'ne'
                                    ? 'कर्मचारी मात्र'
                                    : 'Support Staff Only',
                              ),
                            ),
                          ],
                          onChanged: (newType) {
                            ref
                                .read(staffAttendanceTypeProvider.notifier)
                                .setType(newType);
                            ref
                                .read(
                                  staffAttendanceControllerProvider.notifier,
                                )
                                .load(
                                  date: selectedDate,
                                  department: selectedDept,
                                  employeeType: newType,
                                );
                          },
                        ),
                      ),
                    ),
                  ],
                ),

                // Search input
                SizedBox(
                  width: 220,
                  height: 40,
                  child: TextField(
                    controller: _staffSearchController,
                    decoration: InputDecoration(
                      hintText: AppTranslations.text('search', lang),
                      prefixIcon: const Icon(Icons.search, size: 18),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 0,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: AppRadius.roundedMd,
                        borderSide: BorderSide(
                          color: theme.colorScheme.outlineVariant,
                        ),
                      ),
                      suffixIcon:
                          _staffSearchController.text.isNotEmpty
                              ? IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                onPressed: () {
                                  _staffSearchController.clear();
                                  ref
                                      .read(
                                        staffAttendanceSearchProvider.notifier,
                                      )
                                      .setSearch('');
                                },
                              )
                              : null,
                    ),
                    onChanged:
                        (val) => ref
                            .read(staffAttendanceSearchProvider.notifier)
                            .setSearch(val),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // KPI Summary Cards Row
        _buildKpiRow(
          context: context,
          theme: theme,
          lang: lang,
          summary: summary,
          excusedLabel: AppTranslations.text('on_leave', lang),
        ),
        const SizedBox(height: AppSpacing.md),

        // Bulk Actions Toolbar
        Card(
          elevation: 0,
          color: theme.colorScheme.surfaceContainerHighest.withAlpha(50),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.roundedLg,
            side: BorderSide(
              color: theme.colorScheme.outlineVariant.withAlpha(80),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Text(
                  lang == 'ne' ? 'द्रुत कार्यहरू:' : 'Quick Actions:',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.tonalIcon(
                  icon: const Icon(
                    Icons.check_circle_outline,
                    size: 16,
                    color: Color(0xFF10B981),
                  ),
                  label: Text(
                    AppTranslations.text('mark_all_present', lang),
                    style: const TextStyle(
                      color: Color(0xFF047857),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFD1FAE5),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  onPressed: () {
                    ref
                        .read(staffAttendanceControllerProvider.notifier)
                        .markAll(AttendanceStatus.present);
                  },
                ),
                const Spacer(),

                // Save Button
                FilledButton.icon(
                  icon:
                      _isSaving
                          ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                          : const Icon(Icons.save_outlined, size: 18),
                  label: Text(AppTranslations.text('save_attendance', lang)),
                  onPressed:
                      _isSaving
                          ? null
                          : () async {
                            setState(() => _isSaving = true);
                            final success = await ref
                                .read(
                                  staffAttendanceControllerProvider.notifier,
                                )
                                .save(date: selectedDate);
                            setState(() => _isSaving = false);

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    success
                                        ? (lang == 'ne'
                                            ? 'कर्मचारी हाजिरी सफलतापूर्वक सुरक्षित गरियो!'
                                            : 'Employee attendance saved successfully!')
                                        : (lang == 'ne'
                                            ? 'कर्मचारी हाजिरी सुरक्षित गर्न सकिएन।'
                                            : 'Failed to save employee attendance.'),
                                  ),
                                  backgroundColor:
                                      success
                                          ? const Color(0xFF10B981)
                                          : const Color(0xFFEF4444),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Staff Attendance Table
        staffState.when(
          loading:
              () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              ),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (items) {
            final filtered =
                items.where((item) {
                  if (searchQuery.trim().isEmpty) return true;
                  final query = searchQuery.toLowerCase();
                  final nameMatch = item.employee.name.toLowerCase().contains(
                    query,
                  );
                  final codeMatch =
                      item.employee.employeeCode?.toLowerCase().contains(
                        query,
                      ) ??
                      false;
                  final deptMatch =
                      item.employee.department?.toLowerCase().contains(query) ??
                      false;
                  return nameMatch || codeMatch || deptMatch;
                }).toList();

            if (filtered.isEmpty) {
              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.roundedLg,
                  side: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Text(
                      lang == 'ne'
                          ? 'कुनै कर्मचारी भेटिएन।'
                          : 'No employees found.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ),
                ),
              );
            }

            return Card(
              elevation: 0,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: AppRadius.roundedXl,
                side: BorderSide(
                  color: theme.colorScheme.outlineVariant.withAlpha(100),
                ),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(
                    theme.colorScheme.surfaceContainerHighest.withAlpha(120),
                  ),
                  dataRowMinHeight: 56,
                  dataRowMaxHeight: 60,
                  columnSpacing: 20,
                  columns: [
                    DataColumn(
                      label: Text(
                        lang == 'ne' ? 'कर्मचारी कोड / नाम' : 'Employee',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        lang == 'ne' ? 'पद तथा शाखा' : 'Role & Dept',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        AppTranslations.text('attendance', lang),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        AppTranslations.text('check_in', lang),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        AppTranslations.text('check_out', lang),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        AppTranslations.text('remarks', lang),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                  rows:
                      filtered.map((item) {
                        return DataRow(
                          cells: [
                            // Name & Code
                            DataCell(
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: theme.colorScheme.primary
                                        .withAlpha(30),
                                    child: Text(
                                      item.employee.name.isNotEmpty
                                          ? item.employee.name[0].toUpperCase()
                                          : '?',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        item.employee.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                      Text(
                                        item.employee.employeeCode ??
                                            'EMP-${item.employee.id}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: theme.colorScheme.outline,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Role & Dept
                            DataCell(
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    item.employee.designation,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  if (item.employee.department != null)
                                    Text(
                                      item.employee.department!,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: theme.colorScheme.outline,
                                      ),
                                    ),
                                ],
                              ),
                            ),

                            // Status Selector
                            DataCell(
                              _buildStaffStatusSelector(
                                currentStatus: item.status,
                                onStatusChanged: (newStatus) {
                                  ref
                                      .read(
                                        staffAttendanceControllerProvider
                                            .notifier,
                                      )
                                      .updateStatus(
                                        item.employee.id,
                                        newStatus,
                                      );
                                },
                              ),
                            ),

                            // Check-in Time
                            DataCell(
                              SizedBox(
                                width: 100,
                                height: 36,
                                child: TextField(
                                  controller: TextEditingController(
                                      text: item.checkInTime ?? '',
                                    )
                                    ..selection = TextSelection.collapsed(
                                      offset: (item.checkInTime ?? '').length,
                                    ),
                                  decoration: InputDecoration(
                                    hintText: '09:00 AM',
                                    hintStyle: TextStyle(
                                      fontSize: 11,
                                      color: theme.colorScheme.outline,
                                    ),
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 8,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: AppRadius.roundedSm,
                                      borderSide: BorderSide(
                                        color: theme.colorScheme.outlineVariant
                                            .withAlpha(120),
                                      ),
                                    ),
                                  ),
                                  style: const TextStyle(fontSize: 12),
                                  onSubmitted: (val) {
                                    ref
                                        .read(
                                          staffAttendanceControllerProvider
                                              .notifier,
                                        )
                                        .updateCheckInTime(
                                          item.employee.id,
                                          val,
                                        );
                                  },
                                ),
                              ),
                            ),

                            // Check-out Time
                            DataCell(
                              SizedBox(
                                width: 100,
                                height: 36,
                                child: TextField(
                                  controller: TextEditingController(
                                      text: item.checkOutTime ?? '',
                                    )
                                    ..selection = TextSelection.collapsed(
                                      offset: (item.checkOutTime ?? '').length,
                                    ),
                                  decoration: InputDecoration(
                                    hintText: '04:30 PM',
                                    hintStyle: TextStyle(
                                      fontSize: 11,
                                      color: theme.colorScheme.outline,
                                    ),
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 8,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: AppRadius.roundedSm,
                                      borderSide: BorderSide(
                                        color: theme.colorScheme.outlineVariant
                                            .withAlpha(120),
                                      ),
                                    ),
                                  ),
                                  style: const TextStyle(fontSize: 12),
                                  onSubmitted: (val) {
                                    ref
                                        .read(
                                          staffAttendanceControllerProvider
                                              .notifier,
                                        )
                                        .updateCheckOutTime(
                                          item.employee.id,
                                          val,
                                        );
                                  },
                                ),
                              ),
                            ),

                            // Remarks
                            DataCell(
                              SizedBox(
                                width: 160,
                                height: 36,
                                child: TextField(
                                  controller: TextEditingController(
                                      text: item.remarks ?? '',
                                    )
                                    ..selection = TextSelection.collapsed(
                                      offset: (item.remarks ?? '').length,
                                    ),
                                  decoration: InputDecoration(
                                    hintText:
                                        lang == 'ne'
                                            ? 'कैफियत / बिदाको कारण'
                                            : 'Leave note...',
                                    hintStyle: TextStyle(
                                      fontSize: 11,
                                      color: theme.colorScheme.outline,
                                    ),
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 8,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: AppRadius.roundedSm,
                                      borderSide: BorderSide(
                                        color: theme.colorScheme.outlineVariant
                                            .withAlpha(120),
                                      ),
                                    ),
                                  ),
                                  style: const TextStyle(fontSize: 12),
                                  onSubmitted: (val) {
                                    ref
                                        .read(
                                          staffAttendanceControllerProvider
                                              .notifier,
                                        )
                                        .updateRemarks(item.employee.id, val);
                                  },
                                ),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildStaffStatusSelector({
    required AttendanceStatus currentStatus,
    required void Function(AttendanceStatus) onStatusChanged,
  }) {
    final statuses = [
      AttendanceStatus.present,
      AttendanceStatus.absent,
      AttendanceStatus.late,
      AttendanceStatus.halfDay,
      AttendanceStatus.onLeave,
    ];

    return Row(
      mainAxisSize: MainAxisSize.min,
      children:
          statuses.map((status) {
            final isSelected = currentStatus == status;
            Color baseColor;
            String label;

            switch (status) {
              case AttendanceStatus.present:
                baseColor = const Color(0xFF10B981);
                label = 'P';
                break;
              case AttendanceStatus.absent:
                baseColor = const Color(0xFFEF4444);
                label = 'A';
                break;
              case AttendanceStatus.late:
                baseColor = const Color(0xFFF59E0B);
                label = 'L';
                break;
              case AttendanceStatus.halfDay:
                baseColor = const Color(0xFF8B5CF6);
                label = 'HD';
                break;
              case AttendanceStatus.onLeave:
              case AttendanceStatus.excused:
                baseColor = const Color(0xFF3B82F6);
                label = 'LV';
                break;
            }

            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: InkWell(
                onTap: () => onStatusChanged(status),
                borderRadius: AppRadius.roundedFull,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? baseColor : baseColor.withAlpha(20),
                    borderRadius: AppRadius.roundedFull,
                    border: Border.all(
                      color: isSelected ? baseColor : baseColor.withAlpha(80),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : baseColor,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
    );
  }

  // ===========================================================================
  // TAB 3: ATTENDANCE REGISTER & REPORTS
  // ===========================================================================

  Widget _buildAttendanceRegisterTab(
    BuildContext context,
    ThemeData theme,
    String lang,
    CalendarMode calendarMode,
  ) {
    final isStudentMode = ref.watch(attendanceRegisterModeProvider);
    final monthDate = ref.watch(attendanceRegisterMonthProvider);
    final classesAsync = ref.watch(classesWithSectionsStreamProvider);
    final selectedClassId = ref.watch(studentAttendanceClassIdProvider);
    final selectedSectionId = ref.watch(studentAttendanceSectionIdProvider);

    final monthName = DateFormat('MMMM yyyy').format(monthDate);
    final bsMonth = monthDate.toNepaliDateTime();
    final bsMonthName =
        lang == 'ne'
            ? DateTimeUtils.bsMonthNamesNe[bsMonth.month - 1]
            : DateTimeUtils.bsMonthNamesEn[bsMonth.month - 1];
    final dualMonthStr = '$monthName  /  $bsMonthName ${bsMonth.year} BS';

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      children: [
        // Register Filter Card
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.roundedXl,
            side: BorderSide(
              color: theme.colorScheme.outlineVariant.withAlpha(100),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 16,
              runSpacing: 16,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                // View Mode Segmented Pill
                SegmentedButton<bool>(
                  segments: [
                    ButtonSegment<bool>(
                      value: true,
                      label: Text(
                        AppTranslations.text('student_attendance', lang),
                      ),
                      icon: const Icon(Icons.school, size: 16),
                    ),
                    ButtonSegment<bool>(
                      value: false,
                      label: Text(
                        AppTranslations.text('employee_attendance', lang),
                      ),
                      icon: const Icon(Icons.badge, size: 16),
                    ),
                  ],
                  selected: {isStudentMode},
                  onSelectionChanged: (set) {
                    ref
                        .read(attendanceRegisterModeProvider.notifier)
                        .setMode(set.first);
                  },
                ),

                // Class/Section (if student mode)
                if (isStudentMode)
                  classesAsync.when(
                    data: (classes) {
                      if (classes.isEmpty) return const SizedBox.shrink();
                      final currentClass = classes.firstWhere(
                        (c) => c.id == selectedClassId,
                        orElse: () => classes.first,
                      );
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: theme.colorScheme.outlineVariant,
                              ),
                              borderRadius: AppRadius.roundedMd,
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                value: currentClass.id,
                                items:
                                    classes.map((c) {
                                      return DropdownMenuItem<int>(
                                        value: c.id,
                                        child: Text(
                                          c.displayName.isNotEmpty
                                              ? c.displayName
                                              : c.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                onChanged: (newId) {
                                  if (newId != null) {
                                    ref
                                        .read(
                                          studentAttendanceClassIdProvider
                                              .notifier,
                                        )
                                        .setClassId(newId);
                                  }
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (currentClass.sections.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: theme.colorScheme.outlineVariant,
                                ),
                                borderRadius: AppRadius.roundedMd,
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<int?>(
                                  value: selectedSectionId,
                                  items: [
                                    DropdownMenuItem<int?>(
                                      value: null,
                                      child: Text(
                                        lang == 'ne'
                                            ? 'सबै सेक्सन'
                                            : 'All Sections',
                                      ),
                                    ),
                                    ...currentClass.sections.map((sec) {
                                      return DropdownMenuItem<int?>(
                                        value: sec.id,
                                        child: Text(
                                          '${AppTranslations.text('section', lang)} ${sec.name}',
                                        ),
                                      );
                                    }),
                                  ],
                                  onChanged: (newSecId) {
                                    ref
                                        .read(
                                          studentAttendanceSectionIdProvider
                                              .notifier,
                                        )
                                        .setSectionId(newSecId);
                                  },
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                  ),

                // Month Navigator: < Prev | Month Name | Next >
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withAlpha(
                      90,
                    ),
                    borderRadius: AppRadius.roundedLg,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left, size: 20),
                        tooltip: 'Previous Month',
                        onPressed: () {
                          final prevMonth = DateTime(
                            monthDate.year,
                            monthDate.month - 1,
                            1,
                          );
                          ref
                              .read(attendanceRegisterMonthProvider.notifier)
                              .setMonth(prevMonth);
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        child: Text(
                          dualMonthStr,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right, size: 20),
                        tooltip: 'Next Month',
                        onPressed: () {
                          final nextMonth = DateTime(
                            monthDate.year,
                            monthDate.month + 1,
                            1,
                          );
                          ref
                              .read(attendanceRegisterMonthProvider.notifier)
                              .setMonth(nextMonth);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Legend row
        Card(
          elevation: 0,
          color: theme.colorScheme.surfaceContainerHighest.withAlpha(40),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.roundedLg,
            side: BorderSide(
              color: theme.colorScheme.outlineVariant.withAlpha(60),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Wrap(
              spacing: 20,
              runSpacing: 8,
              children: [
                _buildLegendItem(
                  'P',
                  const Color(0xFF10B981),
                  AppTranslations.text('present', lang),
                ),
                _buildLegendItem(
                  'A',
                  const Color(0xFFEF4444),
                  AppTranslations.text('absent_status', lang),
                ),
                _buildLegendItem(
                  'L',
                  const Color(0xFFF59E0B),
                  AppTranslations.text('late', lang),
                ),
                _buildLegendItem(
                  'HD',
                  const Color(0xFF8B5CF6),
                  AppTranslations.text('half_day', lang),
                ),
                _buildLegendItem(
                  'LV/EX',
                  const Color(0xFF3B82F6),
                  isStudentMode
                      ? AppTranslations.text('excused', lang)
                      : AppTranslations.text('on_leave', lang),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Register Matrix Data Table
        if (isStudentMode)
          _buildStudentRegisterMatrix(context, theme, lang, monthDate)
        else
          _buildStaffRegisterMatrix(context, theme, lang, monthDate),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildLegendItem(String code, Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Text(
            code,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildStudentRegisterMatrix(
    BuildContext context,
    ThemeData theme,
    String lang,
    DateTime monthDate,
  ) {
    final registerAsync = ref.watch(studentMonthlyRegisterFutureProvider);
    final daysInMonth = DateTime(monthDate.year, monthDate.month + 1, 0).day;

    return registerAsync.when(
      loading:
          () => const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          ),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (rows) {
        if (rows.isEmpty) {
          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: AppRadius.roundedLg,
              side: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text(
                  lang == 'ne'
                      ? 'कुनै विद्यार्थीको अभिलेख भेटिएन।'
                      : 'No student records found.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ),
            ),
          );
        }

        return Card(
          elevation: 0,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.roundedXl,
            side: BorderSide(
              color: theme.colorScheme.outlineVariant.withAlpha(100),
            ),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(
                theme.colorScheme.surfaceContainerHighest.withAlpha(120),
              ),
              columnSpacing: 10,
              dataRowMinHeight: 44,
              dataRowMaxHeight: 48,
              columns: [
                DataColumn(
                  label: Text(
                    lang == 'ne' ? 'रोल' : 'Roll',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataColumn(
                  label: Text(
                    lang == 'ne' ? 'विद्यार्थी' : 'Student',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                // Days 1..31
                for (int d = 1; d <= daysInMonth; d++)
                  DataColumn(label: _buildDayColumnHeader(monthDate, d, theme)),
                DataColumn(
                  label: Text(
                    lang == 'ne' ? 'उपस्थित' : 'Present',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataColumn(
                  label: Text(
                    lang == 'ne' ? 'अनुपस्थित' : 'Absent',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const DataColumn(
                  label: Text(
                    '%',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
              rows:
                  rows.map((row) {
                    return DataRow(
                      cells: [
                        DataCell(
                          Text(
                            row.student.rollNumber?.toString() ?? '-',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        DataCell(
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 140),
                            child: Text(
                              row.student.name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                        for (int d = 1; d <= daysInMonth; d++)
                          DataCell(_buildStatusCell(row.dayStatusMap[d])),
                        DataCell(
                          Text(
                            '${row.presentDays}',
                            style: const TextStyle(
                              color: Color(0xFF10B981),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            '${row.absentDays}',
                            style: const TextStyle(
                              color: Color(0xFFEF4444),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _getPercentageColor(
                                row.attendancePercentage,
                              ).withAlpha(25),
                              borderRadius: AppRadius.roundedSm,
                            ),
                            child: Text(
                              '${row.attendancePercentage}%',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _getPercentageColor(
                                  row.attendancePercentage,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStaffRegisterMatrix(
    BuildContext context,
    ThemeData theme,
    String lang,
    DateTime monthDate,
  ) {
    final registerAsync = ref.watch(staffMonthlyRegisterFutureProvider);
    final daysInMonth = DateTime(monthDate.year, monthDate.month + 1, 0).day;

    return registerAsync.when(
      loading:
          () => const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          ),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (rows) {
        if (rows.isEmpty) {
          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: AppRadius.roundedLg,
              side: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text(
                  lang == 'ne'
                      ? 'कुनै कर्मचारीको अभिलेख भेटिएन।'
                      : 'No employee records found.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ),
            ),
          );
        }

        return Card(
          elevation: 0,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.roundedXl,
            side: BorderSide(
              color: theme.colorScheme.outlineVariant.withAlpha(100),
            ),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(
                theme.colorScheme.surfaceContainerHighest.withAlpha(120),
              ),
              columnSpacing: 10,
              dataRowMinHeight: 44,
              dataRowMaxHeight: 48,
              columns: [
                DataColumn(
                  label: Text(
                    lang == 'ne' ? 'कर्मचारी' : 'Employee',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataColumn(
                  label: Text(
                    lang == 'ne' ? 'पद' : 'Role',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                for (int d = 1; d <= daysInMonth; d++)
                  DataColumn(label: _buildDayColumnHeader(monthDate, d, theme)),
                DataColumn(
                  label: Text(
                    lang == 'ne' ? 'उपस्थित' : 'Present',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataColumn(
                  label: Text(
                    lang == 'ne' ? 'बिदा' : 'Leave',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const DataColumn(
                  label: Text(
                    '%',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
              rows:
                  rows.map((row) {
                    return DataRow(
                      cells: [
                        DataCell(
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 150),
                            child: Text(
                              row.employee.name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            row.employee.designation,
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.outline,
                            ),
                          ),
                        ),
                        for (int d = 1; d <= daysInMonth; d++)
                          DataCell(_buildStatusCell(row.dayStatusMap[d])),
                        DataCell(
                          Text(
                            '${row.presentDays}',
                            style: const TextStyle(
                              color: Color(0xFF10B981),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            '${row.leaveDays}',
                            style: const TextStyle(
                              color: Color(0xFF3B82F6),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _getPercentageColor(
                                row.attendancePercentage,
                              ).withAlpha(25),
                              borderRadius: AppRadius.roundedSm,
                            ),
                            child: Text(
                              '${row.attendancePercentage}%',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _getPercentageColor(
                                  row.attendancePercentage,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDayColumnHeader(DateTime monthDate, int day, ThemeData theme) {
    final date = DateTime(monthDate.year, monthDate.month, day);
    final isWeekend =
        date.weekday == DateTime.saturday; // Saturday holiday in Nepal
    final weekdayStr = DateFormat('E').format(date)[0];

    return Container(
      width: 24,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$day',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color:
                  isWeekend
                      ? const Color(0xFFEF4444)
                      : theme.colorScheme.onSurface,
            ),
          ),
          Text(
            weekdayStr,
            style: TextStyle(
              fontSize: 9,
              color:
                  isWeekend
                      ? const Color(0xFFEF4444).withAlpha(160)
                      : theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCell(AttendanceStatus? status) {
    if (status == null) {
      return const Center(
        child: Text('-', style: TextStyle(color: Colors.grey, fontSize: 11)),
      );
    }

    Color color;
    String text;

    switch (status) {
      case AttendanceStatus.present:
        color = const Color(0xFF10B981);
        text = 'P';
        break;
      case AttendanceStatus.absent:
        color = const Color(0xFFEF4444);
        text = 'A';
        break;
      case AttendanceStatus.late:
        color = const Color(0xFFF59E0B);
        text = 'L';
        break;
      case AttendanceStatus.halfDay:
        color = const Color(0xFF8B5CF6);
        text = 'HD';
        break;
      case AttendanceStatus.onLeave:
        color = const Color(0xFF3B82F6);
        text = 'LV';
        break;
      case AttendanceStatus.excused:
        color = const Color(0xFF06B6D4);
        text = 'EX';
        break;
    }

    return Center(
      child: Container(
        width: 22,
        height: 22,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withAlpha(30),
          border: Border.all(color: color.withAlpha(120), width: 1),
          shape: BoxShape.circle,
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }

  Color _getPercentageColor(double pct) {
    if (pct >= 85) return const Color(0xFF10B981);
    if (pct >= 70) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  // ===========================================================================
  // COMMON KPI ROW
  // ===========================================================================

  Widget _buildKpiRow({
    required BuildContext context,
    required ThemeData theme,
    required String lang,
    required AttendanceSummary summary,
    required String excusedLabel,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth =
            constraints.maxWidth > 800
                ? (constraints.maxWidth - 5 * 12) / 6
                : (constraints.maxWidth - 2 * 12) / 3;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildKpiCard(
              width: cardWidth,
              title: AppTranslations.text('total', lang),
              value: '${summary.total}',
              icon: Icons.groups_outlined,
              color: theme.colorScheme.primary,
            ),
            _buildKpiCard(
              width: cardWidth,
              title: AppTranslations.text('present', lang),
              value: '${summary.present}',
              icon: Icons.check_circle_outline,
              color: const Color(0xFF10B981),
            ),
            _buildKpiCard(
              width: cardWidth,
              title: AppTranslations.text('absent_status', lang),
              value: '${summary.absent}',
              icon: Icons.cancel_outlined,
              color: const Color(0xFFEF4444),
            ),
            _buildKpiCard(
              width: cardWidth,
              title: AppTranslations.text('late', lang),
              value: '${summary.late}',
              icon: Icons.access_time_outlined,
              color: const Color(0xFFF59E0B),
            ),
            _buildKpiCard(
              width: cardWidth,
              title: excusedLabel,
              value: '${summary.excusedOrLeave}',
              icon: Icons.event_busy_outlined,
              color: const Color(0xFF3B82F6),
            ),
            _buildKpiCard(
              width: cardWidth,
              title: AppTranslations.text('attendance_percentage', lang),
              value: '${summary.percentage}%',
              icon: Icons.trending_up_rounded,
              color: _getPercentageColor(summary.percentage),
            ),
          ],
        );
      },
    );
  }

  Widget _buildKpiCard({
    required double width,
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: AppRadius.roundedLg,
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withAlpha(25),
              borderRadius: AppRadius.roundedMd,
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: color.withAlpha(220),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
