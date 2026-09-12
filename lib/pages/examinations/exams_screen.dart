import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../config/enums.dart';
import '../../config/responsive.dart';
import '../../config/theme.dart';
import '../../config/translations.dart';
import '../../data/app_database.dart';
import '../../models/calendar_mode.dart';
import '../../providers/academic_year_provider.dart';
import '../../providers/calendar_provider.dart';
import '../../providers/class_section_provider.dart';
import '../../providers/exam_provider.dart';
import '../../providers/locale_provider.dart';
import '../../services/exam_service.dart';
import '../../utils/date_time_utils.dart';
import '../../widgets/app_input.dart';
import '../../widgets/dual_date_picker.dart';

enum _ExamViewMode { routine, list }

class ExamsScreen extends ConsumerStatefulWidget {
  const ExamsScreen({super.key});

  @override
  ConsumerState<ExamsScreen> createState() => _ExamsScreenState();
}

class _ExamsScreenState extends ConsumerState<ExamsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  _ExamViewMode _viewMode = _ExamViewMode.routine;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeProvider).locale.languageCode;
    final calendarMode = ref.watch(calendarProvider);

    final examsAsync = ref.watch(examsStreamProvider);
    final schedulesAsync = ref.watch(examSchedulesStreamProvider);
    final academicYearsAsync = ref.watch(academicYearsStreamProvider);
    final classesAsync = ref.watch(classesWithSectionsStreamProvider);

    final selectedYearId = ref.watch(selectedExamAcademicYearFilterProvider);
    final selectedCategory = ref.watch(selectedExamCategoryFilterProvider);
    final selectedClassId = ref.watch(selectedExamClassFilterProvider);
    final selectedStatus = ref.watch(selectedExamStatusFilterProvider);

    final isCompact = MediaQuery.of(context).size.width < 750;

    return Scaffold(
      body: ResponsiveScaffoldWrapper(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: context.responsive(mobile: 16, tablet: 24, desktop: 32),
            vertical: 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Header & Actions
              _buildHeader(context, lang, isCompact),
              const SizedBox(height: 16),

              // 2. Summary Metric Cards
              _buildMetrics(examsAsync, schedulesAsync, classesAsync, lang),
              const SizedBox(height: 16),

              // 3. Filters Toolbar
              _buildFilterToolbar(
                context,
                lang,
                academicYearsAsync,
                classesAsync,
                selectedYearId,
                selectedCategory,
                selectedClassId,
                selectedStatus,
              ),
              const SizedBox(height: 16),

              // 4. View Mode Segment & Search
              _buildViewModeAndSearch(context, lang, isCompact),
              const SizedBox(height: 16),

              // 5. Main Content: Routine View or List View
              if (_viewMode == _ExamViewMode.routine)
                _buildRoutineView(context, schedulesAsync, lang, calendarMode)
              else
                _buildListView(context, examsAsync, lang, calendarMode),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 1. Header
  // ---------------------------------------------------------------------------
  Widget _buildHeader(BuildContext context, String lang, bool isCompact) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final titleWidget = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppTranslations.text('exam_schedule', lang),
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Manage school exams, terminal routines, and subject schedules',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
          ],
        );

        final actionButtons = ElevatedButton.icon(
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Create Exam'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
          ),
          onPressed: () => _openUnifiedExamDialog(context),
        );

        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [titleWidget, const SizedBox(height: 12), actionButtons],
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [titleWidget, actionButtons],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // 2. Metrics
  // ---------------------------------------------------------------------------
  Widget _buildMetrics(
    AsyncValue<List<ExamWithDetails>> examsAsync,
    AsyncValue<List<ExamScheduleWithDetails>> schedulesAsync,
    AsyncValue<List<ClassWithSections>> classesAsync,
    String lang,
  ) {
    final totalExams = examsAsync.value?.length ?? 0;
    final totalPapers = schedulesAsync.value?.length ?? 0;
    final totalClasses = classesAsync.value?.length ?? 0;
    final distinctScheduledClasses =
        schedulesAsync.value?.map((s) => s.classId).toSet().length ?? 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmall = constraints.maxWidth < 650;
        final countCards = [
          _MetricCard(
            title: 'Total Exams',
            value: totalExams.toString(),
            icon: Icons.quiz_outlined,
            color: Colors.blue,
          ),
          _MetricCard(
            title: 'Scheduled Papers',
            value: totalPapers.toString(),
            icon: Icons.assignment_outlined,
            color: Colors.teal,
          ),
          _MetricCard(
            title: 'Active Classes',
            value: '$distinctScheduledClasses / $totalClasses',
            icon: Icons.class_outlined,
            color: Colors.orange,
          ),
          _MetricCard(
            title: 'Status',
            value: totalExams > 0 ? 'Active' : 'No Exams',
            icon: Icons.event_available_outlined,
            color: Colors.purple,
          ),
        ];

        if (isSmall) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: countCards[0]),
                  const SizedBox(width: 8),
                  Expanded(child: countCards[1]),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: countCards[2]),
                  const SizedBox(width: 8),
                  Expanded(child: countCards[3]),
                ],
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: countCards[0]),
            const SizedBox(width: 12),
            Expanded(child: countCards[1]),
            const SizedBox(width: 12),
            Expanded(child: countCards[2]),
            const SizedBox(width: 12),
            Expanded(child: countCards[3]),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // 3. Filter Toolbar
  // ---------------------------------------------------------------------------
  Widget _buildFilterToolbar(
    BuildContext context,
    String lang,
    AsyncValue<List<AcademicYear>> academicYearsAsync,
    AsyncValue<List<ClassWithSections>> classesAsync,
    int? selectedYearId,
    String? selectedCategory,
    int? selectedClassId,
    String? selectedStatus,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWrap = constraints.maxWidth < 800;

          final yearFilter = academicYearsAsync.when(
            data: (years) {
              return SizedBox(
                width: isWrap ? double.infinity : 200,
                child: AppSearchableSelect<int?>.filter(
                  items: [
                    const SearchableSelectItem<int?>(
                      value: null,
                      label: 'All Academic Years',
                    ),
                    ...years.map(
                      (y) => SearchableSelectItem<int?>(
                        value: y.id,
                        label: y.name + (y.isCurrent ? ' (Active)' : ''),
                      ),
                    ),
                  ],
                  value: selectedYearId,
                  hint: 'Academic Session',
                  prefixIcon: const Icon(Icons.calendar_today, size: 16),
                  onChanged: (val) {
                    ref
                        .read(selectedExamAcademicYearFilterProvider.notifier)
                        .setFilter(val);
                  },
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          );

          final categoryFilter = SizedBox(
            width: isWrap ? double.infinity : 180,
            child: AppSearchableSelect<String?>.filter(
              items: [
                const SearchableSelectItem<String?>(
                  value: null,
                  label: 'All Categories',
                ),
                ...ExamService.defaultCategories.map(
                  (c) => SearchableSelectItem<String?>(value: c, label: c),
                ),
              ],
              value: selectedCategory,
              hint: 'Category',
              prefixIcon: const Icon(Icons.category_outlined, size: 16),
              onChanged: (val) {
                ref
                    .read(selectedExamCategoryFilterProvider.notifier)
                    .setFilter(val);
              },
            ),
          );

          final classFilter = classesAsync.when(
            data: (classList) {
              return SizedBox(
                width: isWrap ? double.infinity : 170,
                child: AppSearchableSelect<int?>.filter(
                  items: [
                    const SearchableSelectItem<int?>(
                      value: null,
                      label: 'All Classes',
                    ),
                    ...classList.map(
                      (c) => SearchableSelectItem<int?>(
                        value: c.id,
                        label:
                            c.displayName.isNotEmpty ? c.displayName : c.name,
                      ),
                    ),
                  ],
                  value: selectedClassId,
                  hint: 'Class',
                  prefixIcon: const Icon(Icons.school_outlined, size: 16),
                  onChanged: (val) {
                    ref
                        .read(selectedExamClassFilterProvider.notifier)
                        .setFilter(val);
                  },
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          );

          final statusFilter = SizedBox(
            width: isWrap ? double.infinity : 150,
            child: AppSearchableSelect<String?>.filter(
              items: [
                const SearchableSelectItem<String?>(
                  value: null,
                  label: 'All Statuses',
                ),
                ...ExamService.statusOptions.map(
                  (s) => SearchableSelectItem<String?>(value: s, label: s),
                ),
              ],
              value: selectedStatus,
              hint: 'Status',
              prefixIcon: const Icon(Icons.flag_outlined, size: 16),
              onChanged: (val) {
                ref
                    .read(selectedExamStatusFilterProvider.notifier)
                    .setFilter(val);
              },
            ),
          );

          if (isWrap) {
            return Column(
              children: [
                yearFilter,
                const SizedBox(height: 8),
                categoryFilter,
                const SizedBox(height: 8),
                classFilter,
                const SizedBox(height: 8),
                statusFilter,
              ],
            );
          }

          return Row(
            children: [
              yearFilter,
              const SizedBox(width: 8),
              categoryFilter,
              const SizedBox(width: 8),
              classFilter,
              const SizedBox(width: 8),
              statusFilter,
            ],
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 4. View Mode & Search
  // ---------------------------------------------------------------------------
  Widget _buildViewModeAndSearch(
    BuildContext context,
    String lang,
    bool isCompact,
  ) {
    final searchWidget = AppSearchField(
      controller: _searchController,
      hintText: 'Search by exam, subject, code, or class...',
      onChanged: (q) => setState(() => _searchQuery = q),
      onClear: () => setState(() => _searchQuery = ''),
    );

    final segmentWidget = SegmentedButton<_ExamViewMode>(
      segments: const [
        ButtonSegment(
          value: _ExamViewMode.routine,
          label: Text('Routine View'),
          icon: Icon(Icons.table_chart_outlined, size: 16),
        ),
        ButtonSegment(
          value: _ExamViewMode.list,
          label: Text('Exams List'),
          icon: Icon(Icons.view_agenda_outlined, size: 16),
        ),
      ],
      selected: {_viewMode},
      onSelectionChanged: (set) {
        setState(() => _viewMode = set.first);
      },
    );

    if (isCompact) {
      return Column(
        children: [
          searchWidget,
          const SizedBox(height: 10),
          Align(alignment: Alignment.centerLeft, child: segmentWidget),
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: searchWidget),
        const SizedBox(width: 12),
        segmentWidget,
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 5. Routine View (Grouped by Class & Exam)
  // ---------------------------------------------------------------------------
  Widget _buildRoutineView(
    BuildContext context,
    AsyncValue<List<ExamScheduleWithDetails>> schedulesAsync,
    String lang,
    CalendarMode calendarMode,
  ) {
    return schedulesAsync.when(
      data: (schedules) {
        final filtered =
            schedules.where((s) {
              if (_searchQuery.isEmpty) return true;
              final q = _searchQuery.toLowerCase();
              return s.examName.toLowerCase().contains(q) ||
                  s.examCategory.toLowerCase().contains(q) ||
                  s.subjectName.toLowerCase().contains(q) ||
                  s.subjectCode.toLowerCase().contains(q) ||
                  s.className.toLowerCase().contains(q);
            }).toList();

        if (filtered.isEmpty) {
          return _buildEmptyState(
            context,
            title: 'No Exam Routines Found',
            subtitle:
                'No subjects have been scheduled for the selected filters. Click "Schedule Class" to build an exam routine.',
            actionLabel: 'Schedule Class Routine',
            onAction: () => _openClassScheduleDialog(context),
          );
        }

        // Group by examId and classId: Map<String, List<ExamScheduleWithDetails>>
        final groups = <String, List<ExamScheduleWithDetails>>{};
        for (final item in filtered) {
          final key = '${item.examId}_${item.classId}';
          groups.putIfAbsent(key, () => []).add(item);
        }

        return Column(
          children:
              groups.entries.map((entry) {
                final items = entry.value;
                final first = items.first;

                return _buildClassRoutineCard(
                  context,
                  first.exam,
                  first.schoolClass,
                  first.academicYear,
                  items,
                  calendarMode,
                  lang,
                );
              }).toList(),
        );
      },
      loading:
          () => const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          ),
      error:
          (e, st) => Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text('Error loading schedules: $e'),
            ),
          ),
    );
  }

  Widget _buildClassRoutineCard(
    BuildContext context,
    Exam exam,
    SchoolClass schoolClass,
    AcademicYear academicYear,
    List<ExamScheduleWithDetails> items,
    CalendarMode calendarMode,
    String lang,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Sort by examDate, orderIndex
    items.sort((a, b) {
      final dateCmp = a.examDate.compareTo(b.examDate);
      if (dateCmp != 0) return dateCmp;
      return a.orderIndex.compareTo(b.orderIndex);
    });

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(
          color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text(
                            schoolClass.displayName.isNotEmpty
                                ? schoolClass.displayName
                                : schoolClass.name,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withValues(
                                alpha: 0.12,
                              ),
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: Text(
                              exam.category,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${exam.name} • ${academicYear.name}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.textTheme.bodySmall?.color,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  tooltip: 'Options',
                  onSelected: (action) {
                    if (action == 'edit') {
                      _openClassScheduleDialog(
                        context,
                        selectedExamId: exam.id,
                        selectedClassId: schoolClass.id,
                      );
                    } else if (action == 'delete') {
                      _confirmDeleteClassSchedule(
                        exam.id,
                        schoolClass.id,
                        exam.name,
                        schoolClass.name,
                      );
                    }
                  },
                  itemBuilder:
                      (ctx) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined, size: 18),
                              SizedBox(width: 8),
                              Text('Edit Routine'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete_outline,
                                size: 18,
                                color: Colors.red,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Delete Routine',
                                style: TextStyle(color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                      ],
                ),
              ],
            ),
            const Divider(height: 24),

            // Routine Table
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 40,
                dataRowMinHeight: 44,
                dataRowMaxHeight: 56,
                horizontalMargin: 12,
                columnSpacing: 20,
                headingTextStyle: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.textTheme.bodySmall?.color,
                ),
                columns: const [
                  DataColumn(label: Text('DATE & DAY')),
                  DataColumn(label: Text('TIME')),
                  DataColumn(label: Text('SUBJECT')),
                  DataColumn(label: Text('TYPE')),
                  DataColumn(label: Text('MARKS (FULL/PASS)')),
                  DataColumn(label: Text('ROOM / HALL')),
                  DataColumn(label: Text('REMARKS')),
                ],
                rows:
                    items.map((item) {
                      final formattedDate = DateTimeUtils.formatDual(
                        date: item.examDate,
                        primary: calendarMode,
                        showBoth: true,
                      );
                      final dayOfWeek = _getDayOfWeekName(
                        item.examDate.weekday,
                      );

                      return DataRow(
                        cells: [
                          DataCell(
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  formattedDate,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  dayOfWeek,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.textTheme.bodySmall?.color,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          DataCell(
                            Row(
                              children: [
                                const Icon(
                                  Icons.access_time,
                                  size: 14,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${item.startTime} - ${item.endTime}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          DataCell(
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.subjectName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  item.subjectCode,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: theme.textTheme.bodySmall?.color,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blueGrey.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                item.subjectType.displayName,
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                          ),
                          DataCell(
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${item.fullMarks} / ${item.passMarks}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (item.subjectType != SubjectType.theory &&
                                    (item.theoryMarks != null ||
                                        item.practicalMarks != null))
                                  Text(
                                    'Th: ${item.theoryMarks ?? '-'}${item.savedTheoryPassMarks != null ? "/${item.savedTheoryPassMarks}" : ""} | Pr: ${item.practicalMarks ?? '-'}${item.savedPracticalPassMarks != null ? "/${item.savedPracticalPassMarks}" : ""}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: theme.textTheme.bodySmall?.color,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          DataCell(
                            Text(
                              item.roomNumber?.isNotEmpty == true
                                  ? item.roomNumber!
                                  : '-',
                            ),
                          ),
                          DataCell(
                            Text(
                              item.formattedRemarks?.isNotEmpty == true
                                  ? item.formattedRemarks!
                                  : (item.remarks?.startsWith('{') == true
                                      ? '-'
                                      : (item.remarks?.isNotEmpty == true
                                          ? item.remarks!
                                          : '-')),
                              style: TextStyle(
                                fontStyle: FontStyle.italic,
                                color: theme.textTheme.bodySmall?.color,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 6. List View (Exams Master List)
  // ---------------------------------------------------------------------------
  Widget _buildListView(
    BuildContext context,
    AsyncValue<List<ExamWithDetails>> examsAsync,
    String lang,
    CalendarMode calendarMode,
  ) {
    return examsAsync.when(
      data: (exams) {
        final filtered =
            exams.where((e) {
              if (_searchQuery.isEmpty) return true;
              final q = _searchQuery.toLowerCase();
              return e.name.toLowerCase().contains(q) ||
                  e.category.toLowerCase().contains(q) ||
                  e.status.toLowerCase().contains(q);
            }).toList();

        if (filtered.isEmpty) {
          return _buildEmptyState(
            context,
            title: 'No Exams Found',
            subtitle:
                'No exams matching the criteria. Click "New Exam" to create an exam master.',
            actionLabel: 'Create New Exam',
            onAction: () => _openExamDialog(context),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final examWithDetails = filtered[index];
            return _buildExamMasterCard(
              context,
              examWithDetails,
              calendarMode,
              lang,
            );
          },
        );
      },
      loading:
          () => const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          ),
      error:
          (e, st) => Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text('Error loading exams: $e'),
            ),
          ),
    );
  }

  Widget _buildExamMasterCard(
    BuildContext context,
    ExamWithDetails item,
    CalendarMode calendarMode,
    String lang,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final startStr = DateTimeUtils.formatDual(
      date: item.startDate,
      primary: calendarMode,
      showBoth: true,
    );
    final endStr = DateTimeUtils.formatDual(
      date: item.endDate,
      primary: calendarMode,
      showBoth: true,
    );

    Color statusColor;
    switch (item.status.toLowerCase()) {
      case 'scheduled':
        statusColor = Colors.blue;
        break;
      case 'ongoing':
        statusColor = Colors.green;
        break;
      case 'completed':
        statusColor = Colors.teal;
        break;
      case 'cancelled':
        statusColor = Colors.red;
        break;
      default:
        statusColor = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(
          color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Title & Actions
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text(
                            item.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withValues(
                                alpha: 0.12,
                              ),
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: Text(
                              item.category,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: Text(
                              item.status,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (item.description?.isNotEmpty == true) ...[
                        const SizedBox(height: 4),
                        Text(
                          item.description!,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  tooltip: 'Actions',
                  onSelected: (action) {
                    if (action == 'edit') {
                      _openExamDialog(context, exam: item.exam);
                    } else if (action == 'schedule') {
                      _openClassScheduleDialog(
                        context,
                        selectedExamId: item.id,
                      );
                    } else if (action == 'delete') {
                      _confirmDeleteExam(item.id, item.name);
                    }
                  },
                  itemBuilder:
                      (ctx) => [
                        const PopupMenuItem(
                          value: 'schedule',
                          child: Row(
                            children: [
                              Icon(Icons.add_task_outlined, size: 18),
                              SizedBox(width: 8),
                              Text('Schedule Class Routine'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined, size: 18),
                              SizedBox(width: 8),
                              Text('Edit Exam'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete_outline,
                                size: 18,
                                color: Colors.red,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Delete Exam',
                                style: TextStyle(color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                      ],
                ),
              ],
            ),
            const Divider(height: 20),

            // Metadata info row
            Wrap(
              spacing: 20,
              runSpacing: 8,
              children: [
                _InfoBadge(
                  icon: Icons.calendar_today_outlined,
                  label: 'Duration',
                  value: '$startStr – $endStr',
                ),
                _InfoBadge(
                  icon: Icons.account_balance_outlined,
                  label: 'Session',
                  value: item.academicYearName,
                ),
                _InfoBadge(
                  icon: Icons.assignment_outlined,
                  label: 'Subjects Scheduled',
                  value: '${item.scheduleCount} papers',
                ),
                _InfoBadge(
                  icon: Icons.class_outlined,
                  label: 'Classes',
                  value: '${item.classCount} classes',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Empty State Helper
  // ---------------------------------------------------------------------------
  Widget _buildEmptyState(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.event_note_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: Text(actionLabel),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
              onPressed: onAction,
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Dialog: Unified Create / Edit Exam & Routine
  // ---------------------------------------------------------------------------
  void _openUnifiedExamDialog(
    BuildContext context, {
    Exam? exam,
    int? selectedExamId,
    int? selectedClassId,
    int? selectedSectionId,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => _UnifiedExamDialog(
            exam: exam,
            initialExamId: selectedExamId,
            initialClassId: selectedClassId,
            initialSectionId: selectedSectionId,
          ),
    );
  }

  void _openExamDialog(BuildContext context, {Exam? exam}) {
    _openUnifiedExamDialog(context, exam: exam);
  }

  void _openClassScheduleDialog(
    BuildContext context, {
    int? selectedExamId,
    int? selectedClassId,
  }) {
    _openUnifiedExamDialog(
      context,
      selectedExamId: selectedExamId,
      selectedClassId: selectedClassId,
    );
  }

  // ---------------------------------------------------------------------------
  // Delete Confirmations
  // ---------------------------------------------------------------------------
  void _confirmDeleteExam(int examId, String name) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Delete Exam'),
            content: Text(
              'Are you sure you want to delete "$name"? All scheduled subject routines under this exam will be permanently removed.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  final success = await ref
                      .read(examControllerProvider.notifier)
                      .deleteExam(examId);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          success
                              ? 'Exam "$name" deleted successfully'
                              : 'Failed to delete exam',
                        ),
                      ),
                    );
                  }
                },
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  void _confirmDeleteClassSchedule(
    int examId,
    int classId,
    String examName,
    String className,
  ) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Delete Class Routine'),
            content: Text(
              'Are you sure you want to delete the scheduled routine for $className in "$examName"?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  final success = await ref
                      .read(examControllerProvider.notifier)
                      .deleteClassSchedule(examId, classId);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          success
                              ? 'Routine for $className deleted'
                              : 'Failed to delete routine',
                        ),
                      ),
                    );
                  }
                },
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  static String _getDayOfWeekName(int weekday) {
    switch (weekday) {
      case DateTime.sunday:
        return 'Sunday';
      case DateTime.monday:
        return 'Monday';
      case DateTime.tuesday:
        return 'Tuesday';
      case DateTime.wednesday:
        return 'Wednesday';
      case DateTime.thursday:
        return 'Thursday';
      case DateTime.friday:
        return 'Friday';
      case DateTime.saturday:
        return 'Saturday';
      default:
        return '';
    }
  }
}

// =============================================================================
// Helper Component: Info Badge
// =============================================================================
class _InfoBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoBadge({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: theme.textTheme.bodySmall?.color),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: theme.textTheme.bodySmall?.color,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ],
    );
  }
}

// =============================================================================
// Helper Component: Metric Card
// =============================================================================
class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.textTheme.bodySmall?.color,
                  ),
                ),
                Text(
                  value,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
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

// =============================================================================
// Dialog: Unified Create / Edit Exam & Routine Dialog
// =============================================================================
class _UnifiedExamDialog extends ConsumerStatefulWidget {
  final Exam? exam;
  final int? initialExamId;
  final int? initialClassId;
  final int? initialSectionId;

  const _UnifiedExamDialog({
    this.exam,
    this.initialExamId,
    this.initialClassId,
    this.initialSectionId,
  });

  @override
  ConsumerState<_UnifiedExamDialog> createState() => _UnifiedExamDialogState();
}

class _EditableRoutineRow {
  final Subject subject;
  DateTime examDate;
  TextEditingController startTimeController;
  TextEditingController endTimeController;
  TextEditingController fullMarksController;
  TextEditingController passMarksController;
  TextEditingController theoryMarksController;
  TextEditingController theoryPassMarksController;
  TextEditingController practicalMarksController;
  TextEditingController practicalPassMarksController;
  TextEditingController roomController;
  TextEditingController remarksController;

  _EditableRoutineRow({
    required this.subject,
    required this.examDate,
    required String startTime,
    required String endTime,
    required int fullMarks,
    required int passMarks,
    int? theoryMarks,
    int? theoryPassMarks,
    int? practicalMarks,
    int? practicalPassMarks,
    String room = '',
    String remarks = '',
  }) : startTimeController = TextEditingController(text: startTime),
       endTimeController = TextEditingController(text: endTime),
       fullMarksController = TextEditingController(text: fullMarks.toString()),
       passMarksController = TextEditingController(text: passMarks.toString()),
       theoryMarksController = TextEditingController(
         text:
             subject.subjectType == SubjectType.practical
                 ? ''
                 : (theoryMarks ??
                         subject.theoryMarks ??
                         (subject.subjectType == SubjectType.both
                             ? 75
                             : fullMarks))
                     .toString(),
       ),
       theoryPassMarksController = TextEditingController(
         text:
             subject.subjectType == SubjectType.practical
                 ? ''
                 : (theoryPassMarks ??
                         (subject.subjectType == SubjectType.both
                             ? (theoryMarks != null
                                 ? (theoryMarks * 0.4).round()
                                 : 30)
                             : passMarks))
                     .toString(),
       ),
       practicalMarksController = TextEditingController(
         text:
             subject.subjectType == SubjectType.theory
                 ? ''
                 : (practicalMarks ??
                         subject.practicalMarks ??
                         (subject.subjectType == SubjectType.both
                             ? 25
                             : fullMarks))
                     .toString(),
       ),
       practicalPassMarksController = TextEditingController(
         text:
             subject.subjectType == SubjectType.theory
                 ? ''
                 : (practicalPassMarks ??
                         (subject.subjectType == SubjectType.both
                             ? (practicalMarks != null
                                 ? (practicalMarks * 0.4).round()
                                 : 10)
                             : passMarks))
                     .toString(),
       ),
       roomController = TextEditingController(text: room),
       remarksController = TextEditingController(text: remarks) {
    updateTotals();
  }

  void updateTotals() {
    final hasTheory = subject.subjectType != SubjectType.practical;
    final hasPractical = subject.subjectType != SubjectType.theory;

    final thFull = int.tryParse(theoryMarksController.text.trim()) ?? 0;
    final thPass = int.tryParse(theoryPassMarksController.text.trim()) ?? 0;
    final prFull = int.tryParse(practicalMarksController.text.trim()) ?? 0;
    final prPass = int.tryParse(practicalPassMarksController.text.trim()) ?? 0;

    int totalFull = 0;
    int totalPass = 0;

    if (hasTheory && hasPractical) {
      totalFull = thFull + prFull;
      totalPass = thPass + prPass;
    } else if (hasTheory) {
      totalFull = thFull;
      totalPass = thPass;
    } else if (hasPractical) {
      totalFull = prFull;
      totalPass = prPass;
    }

    if (totalFull > 0 || (thFull == 0 && prFull == 0)) {
      fullMarksController.text = totalFull.toString();
    }
    if (totalPass > 0 || (thPass == 0 && prPass == 0)) {
      passMarksController.text = totalPass.toString();
    }
  }

  void dispose() {
    startTimeController.dispose();
    endTimeController.dispose();
    fullMarksController.dispose();
    passMarksController.dispose();
    theoryMarksController.dispose();
    theoryPassMarksController.dispose();
    practicalMarksController.dispose();
    practicalPassMarksController.dispose();
    roomController.dispose();
    remarksController.dispose();
  }
}

class _UnifiedExamDialogState extends ConsumerState<_UnifiedExamDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _customCategoryController;
  late TextEditingController _descriptionController;

  String? _selectedCategory;
  int? _selectedAcademicYearId;
  int? _selectedClassId;
  int? _selectedSectionId;
  late DateTime _startDate;
  late DateTime _endDate;
  String _status = 'Scheduled';

  bool _isSubmitting = false;
  bool _isLoadingSubjects = false;

  final List<_EditableRoutineRow> _rows = [];
  List<Subject> _availableSubjects = [];

  // Bulk settings
  final TextEditingController _bulkStartController = TextEditingController(
    text: '10:00 AM',
  );
  final TextEditingController _bulkEndController = TextEditingController(
    text: '01:00 PM',
  );
  final TextEditingController _bulkRoomController = TextEditingController(
    text: '',
  );

  Exam? _loadedExam;

  @override
  void initState() {
    super.initState();
    _loadedExam = widget.exam;
    final e = _loadedExam;
    _nameController = TextEditingController(text: e?.name ?? '');
    _descriptionController = TextEditingController(text: e?.description ?? '');

    final initialCategory = e?.category;
    if (initialCategory != null &&
        ExamService.defaultCategories.contains(initialCategory)) {
      _selectedCategory = initialCategory;
      _customCategoryController = TextEditingController();
    } else if (initialCategory != null) {
      _selectedCategory = 'Other';
      _customCategoryController = TextEditingController(text: initialCategory);
    } else {
      _selectedCategory = 'Terminal Exam 1';
      _customCategoryController = TextEditingController();
    }

    _selectedAcademicYearId = e?.academicYearId;
    _selectedClassId = widget.initialClassId;
    _selectedSectionId = widget.initialSectionId;
    _startDate = e?.startDate ?? DateTime.now();
    _endDate = e?.endDate ?? DateTime.now().add(const Duration(days: 10));
    _status = e?.status ?? 'Scheduled';

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final activeYear = ref.read(activeAcademicYearProvider).value;
      if (_selectedAcademicYearId == null && activeYear != null) {
        setState(() {
          _selectedAcademicYearId = activeYear.id;
        });
      }

      if (_loadedExam == null && widget.initialExamId != null) {
        final examWithDetails = await ref
            .read(examServiceProvider)
            .getExamWithDetailsById(widget.initialExamId!);
        if (examWithDetails != null && mounted) {
          setState(() {
            _loadedExam = examWithDetails.exam;
            _nameController.text = examWithDetails.name;
            _descriptionController.text = examWithDetails.description ?? '';
            _startDate = examWithDetails.startDate;
            _endDate = examWithDetails.endDate;
            _status = examWithDetails.status;
            _selectedAcademicYearId = examWithDetails.academicYearId;
            final cat = examWithDetails.category;
            if (ExamService.defaultCategories.contains(cat)) {
              _selectedCategory = cat;
            } else {
              _selectedCategory = 'Other';
              _customCategoryController.text = cat;
            }
          });
        }
      }

      if (_selectedClassId != null) {
        _loadSubjectsForClass();
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _customCategoryController.dispose();
    _descriptionController.dispose();
    _bulkStartController.dispose();
    _bulkEndController.dispose();
    _bulkRoomController.dispose();
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  Future<void> _loadSubjectsForClass() async {
    if (_selectedClassId == null) {
      setState(() {
        for (final r in _rows) {
          r.dispose();
        }
        _rows.clear();
        _availableSubjects = [];
      });
      return;
    }

    final yearId =
        _selectedAcademicYearId ??
        ref.read(activeAcademicYearProvider).value?.id;
    if (yearId == null) return;

    setState(() => _isLoadingSubjects = true);

    try {
      final examService = ref.read(examServiceProvider);
      final subjects = await examService.getSubjectsForClass(
        classId: _selectedClassId!,
        academicYearId: yearId,
      );

      final examId = _loadedExam?.id ?? widget.initialExamId;
      List<ExamScheduleWithDetails> existingSchedules = [];
      if (examId != null) {
        existingSchedules = await examService.getAllExamSchedulesWithDetails(
          examId: examId,
          classId: _selectedClassId,
          academicYearId: yearId,
        );
      }

      for (final r in _rows) {
        r.dispose();
      }
      _rows.clear();

      final existingMap = {for (var s in existingSchedules) s.subjectId: s};

      for (int i = 0; i < subjects.length; i++) {
        final sub = subjects[i];
        final existing = existingMap[sub.id];

        final DateTime rowDate;
        if (existing != null) {
          rowDate = existing.examDate;
        } else {
          rowDate = _startDate.add(Duration(days: i));
        }

        final fullM = existing?.fullMarks ?? sub.fullMarks;
        final passM = existing?.passMarks ?? sub.passMarks;
        final theoryM = existing?.theoryMarks ?? sub.theoryMarks;
        final pracM = existing?.practicalMarks ?? sub.practicalMarks;
        final theoryPassM = existing?.savedTheoryPassMarks;
        final pracPassM = existing?.savedPracticalPassMarks;
        final loadedRemarks =
            existing?.formattedRemarks ?? (existing?.remarks ?? '');

        _rows.add(
          _EditableRoutineRow(
            subject: sub,
            examDate: rowDate,
            startTime: existing?.startTime ?? _bulkStartController.text,
            endTime: existing?.endTime ?? _bulkEndController.text,
            fullMarks: fullM,
            passMarks: passM,
            theoryMarks: theoryM,
            theoryPassMarks: theoryPassM,
            practicalMarks: pracM,
            practicalPassMarks: pracPassM,
            room: existing?.roomNumber ?? _bulkRoomController.text,
            remarks: loadedRemarks,
          ),
        );
      }

      _availableSubjects = subjects;
    } catch (e) {
      debugPrint('Error loading subjects for class: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingSubjects = false);
      }
    }
  }

  void _addSubjectRow(Subject subject) {
    final nextDate =
        _rows.isEmpty
            ? _startDate
            : _rows.last.examDate.add(const Duration(days: 1));

    setState(() {
      _rows.add(
        _EditableRoutineRow(
          subject: subject,
          examDate: nextDate,
          startTime:
              _bulkStartController.text.trim().isNotEmpty
                  ? _bulkStartController.text.trim()
                  : '10:00 AM',
          endTime:
              _bulkEndController.text.trim().isNotEmpty
                  ? _bulkEndController.text.trim()
                  : '01:00 PM',
          fullMarks: subject.fullMarks,
          passMarks: subject.passMarks,
          theoryMarks: subject.theoryMarks,
          practicalMarks: subject.practicalMarks,
          room: _bulkRoomController.text.trim(),
          remarks: '',
        ),
      );
    });
  }

  void _removeRow(int index) {
    setState(() {
      final removed = _rows.removeAt(index);
      removed.dispose();
    });
  }

  void _applyBulkSettings() {
    final start = _bulkStartController.text.trim();
    final end = _bulkEndController.text.trim();
    final room = _bulkRoomController.text.trim();

    setState(() {
      for (final row in _rows) {
        if (start.isNotEmpty) row.startTimeController.text = start;
        if (end.isNotEmpty) row.endTimeController.text = end;
        if (room.isNotEmpty) row.roomController.text = room;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Applied bulk timings and room to all subject rows'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  Future<void> _selectTime(
    BuildContext context,
    TextEditingController controller,
  ) async {
    TimeOfDay initial = const TimeOfDay(hour: 10, minute: 0);
    final text = controller.text.trim();
    if (text.isNotEmpty) {
      try {
        final parts = text.split(' ');
        final timeParts = parts[0].split(':');
        int hour = int.parse(timeParts[0]);
        final int minute = int.parse(timeParts[1]);
        if (parts.length > 1 && parts[1].toUpperCase() == 'PM' && hour < 12) {
          hour += 12;
        } else if (parts.length > 1 &&
            parts[1].toUpperCase() == 'AM' &&
            hour == 12) {
          hour = 0;
        }
        initial = TimeOfDay(hour: hour, minute: minute);
      } catch (_) {}
    }

    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) {
      final hour = picked.hourOfPeriod == 0 ? 12 : picked.hourOfPeriod;
      final minute = picked.minute.toString().padLeft(2, '0');
      final period = picked.period == DayPeriod.am ? 'AM' : 'PM';
      controller.text = '$hour:$minute $period';
    }
  }

  Widget _buildAddSubjectButton(BuildContext context) {
    return PopupMenuButton<Subject>(
      tooltip: 'Add another subject paper',
      itemBuilder: (ctx) {
        final existingSubjectIds = _rows.map((r) => r.subject.id).toSet();
        final available =
            _availableSubjects
                .where((s) => !existingSubjectIds.contains(s.id))
                .toList();

        if (available.isEmpty) {
          return [
            const PopupMenuItem<Subject>(
              enabled: false,
              child: Text('All subjects are already added'),
            ),
          ];
        }

        return available
            .map(
              (s) => PopupMenuItem<Subject>(
                value: s,
                child: Text('${s.name} (${s.code})'),
              ),
            )
            .toList();
      },
      onSelected: (subject) => _addSubjectRow(subject),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: AppTheme.primaryColor.withValues(alpha: 0.3),
          ),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, size: 16, color: AppTheme.primaryColor),
            SizedBox(width: 5),
            Text(
              'Add Subject Paper',
              style: TextStyle(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveExamAndRoutine() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedClassId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a Class')));
      return;
    }
    if (_startDate.isAfter(_endDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Start date cannot be after end date')),
      );
      return;
    }
    if (_rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please configure at least one subject in the routine'),
        ),
      );
      return;
    }

    final yearId =
        _selectedAcademicYearId ??
        ref.read(activeAcademicYearProvider).value?.id;
    if (yearId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an academic session')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final category =
          _selectedCategory == 'Other'
              ? _customCategoryController.text.trim()
              : (_selectedCategory ?? 'Terminal Exam 1');

      final schedules = <ExamScheduleItemInput>[];
      for (int i = 0; i < _rows.length; i++) {
        final row = _rows[i];
        final fullM =
            int.tryParse(row.fullMarksController.text.trim()) ??
            row.subject.fullMarks;
        final passM =
            int.tryParse(row.passMarksController.text.trim()) ??
            row.subject.passMarks;
        final theoryM = int.tryParse(row.theoryMarksController.text.trim());
        final theoryPassM = int.tryParse(
          row.theoryPassMarksController.text.trim(),
        );
        final practicalM = int.tryParse(
          row.practicalMarksController.text.trim(),
        );
        final practicalPassM = int.tryParse(
          row.practicalPassMarksController.text.trim(),
        );

        schedules.add(
          ExamScheduleItemInput(
            subjectId: row.subject.id,
            examDate: row.examDate,
            startTime:
                row.startTimeController.text.trim().isNotEmpty
                    ? row.startTimeController.text.trim()
                    : '10:00 AM',
            endTime:
                row.endTimeController.text.trim().isNotEmpty
                    ? row.endTimeController.text.trim()
                    : '01:00 PM',
            fullMarks: fullM,
            passMarks: passM,
            theoryMarks: theoryM,
            theoryPassMarks: theoryPassM,
            practicalMarks: practicalM,
            practicalPassMarks: practicalPassM,
            roomNumber:
                row.roomController.text.trim().isEmpty
                    ? null
                    : row.roomController.text.trim(),
            remarks:
                row.remarksController.text.trim().isEmpty
                    ? null
                    : row.remarksController.text.trim(),
            orderIndex: i + 1,
          ),
        );
      }

      await ref
          .read(examControllerProvider.notifier)
          .saveExamWithClassSchedules(
            examId: _loadedExam?.id ?? widget.initialExamId,
            name: _nameController.text.trim(),
            category: category,
            academicYearId: yearId,
            classId: _selectedClassId!,
            sectionId: _selectedSectionId,
            startDate: _startDate,
            endDate: _endDate,
            description:
                _descriptionController.text.trim().isEmpty
                    ? null
                    : _descriptionController.text.trim(),
            status: _status,
            schedules: schedules,
          );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _loadedExam != null
                  ? 'Exam and routine updated successfully'
                  : 'Exam and class routine created successfully',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving exam: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final academicYearsAsync = ref.watch(academicYearsStreamProvider);
    final classesAsync = ref.watch(classesWithSectionsStreamProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEditing = _loadedExam != null || widget.initialExamId != null;

    final selectedClassObj =
        classesAsync.value?.where((c) => c.id == _selectedClassId).firstOrNull;
    final availableSections = selectedClassObj?.sections ?? [];

    final screenSize = MediaQuery.of(context).size;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 1180,
          maxHeight: screenSize.height * 0.94,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEditing
                              ? 'Edit Examination & Routine'
                              : 'Create Examination & Routine',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Configure exam details, academic class, session, and scheduled subject papers in a single view',
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                isDark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 14),

              // 2. Scrollable Body
              Expanded(
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // A. Exam Details Form Card
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color:
                                isDark
                                    ? AppTheme.darkSurface
                                    : AppTheme.lightSurface,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            border: Border.all(
                              color:
                                  isDark
                                      ? AppTheme.darkBorder
                                      : AppTheme.lightBorder,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.assignment_outlined,
                                    size: 18,
                                    color: AppTheme.primaryColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Exam Information',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),

                              // Row 1: Title & Category
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: TextFormField(
                                      controller: _nameController,
                                      decoration: const InputDecoration(
                                        labelText: 'Exam Title *',
                                        hintText:
                                            'e.g. First Terminal Examination 2083',
                                        prefixIcon: Icon(Icons.title, size: 20),
                                        isDense: true,
                                      ),
                                      validator: (val) {
                                        if (val == null || val.trim().isEmpty) {
                                          return 'Exam title is required';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    flex: 2,
                                    child: AppSearchableSelect<String>(
                                      items:
                                          ExamService.defaultCategories
                                              .map(
                                                (cat) => SearchableSelectItem<
                                                  String
                                                >(
                                                  value: cat,
                                                  label: cat,
                                                  leading: const Icon(
                                                    Icons.label_outline,
                                                    size: 18,
                                                  ),
                                                ),
                                              )
                                              .toList(),
                                      value: _selectedCategory,
                                      label: 'Exam Category *',
                                      prefixIcon: const Icon(
                                        Icons.category_outlined,
                                        size: 20,
                                      ),
                                      validator:
                                          (val) =>
                                              val == null
                                                  ? 'Category is required'
                                                  : null,
                                      onChanged: (val) {
                                        setState(() => _selectedCategory = val);
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              if (_selectedCategory == 'Other') ...[
                                const SizedBox(height: 10),
                                TextFormField(
                                  controller: _customCategoryController,
                                  decoration: const InputDecoration(
                                    labelText: 'Custom Category Name *',
                                    hintText:
                                        'e.g. Monthly Assessment, Practical Board',
                                    prefixIcon: Icon(Icons.edit_note, size: 20),
                                    isDense: true,
                                  ),
                                  validator: (val) {
                                    if (_selectedCategory == 'Other' &&
                                        (val == null || val.trim().isEmpty)) {
                                      return 'Please specify the category';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                              const SizedBox(height: 12),

                              // Row 2: Academic Year, Class, Section
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Academic Year
                                  Expanded(
                                    flex: 2,
                                    child: academicYearsAsync.when(
                                      data: (years) {
                                        return AppSearchableSelect<int>(
                                          items:
                                              years
                                                  .map(
                                                    (y) => SearchableSelectItem<
                                                      int
                                                    >(
                                                      value: y.id,
                                                      label:
                                                          y.name +
                                                          (y.isCurrent
                                                              ? ' (Active)'
                                                              : ''),
                                                    ),
                                                  )
                                                  .toList(),
                                          value: _selectedAcademicYearId,
                                          label: 'Academic Session *',
                                          prefixIcon: const Icon(
                                            Icons.calendar_today,
                                            size: 18,
                                          ),
                                          validator:
                                              (val) =>
                                                  val == null
                                                      ? 'Required'
                                                      : null,
                                          onChanged: (val) {
                                            setState(
                                              () =>
                                                  _selectedAcademicYearId = val,
                                            );
                                            if (_selectedClassId != null) {
                                              _loadSubjectsForClass();
                                            }
                                          },
                                        );
                                      },
                                      loading:
                                          () => const LinearProgressIndicator(),
                                      error:
                                          (_, _) => const Text(
                                            'Failed to load sessions',
                                          ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  // Class
                                  Expanded(
                                    flex: 2,
                                    child: classesAsync.when(
                                      data:
                                          (classes) => AppSearchableSelect<int>(
                                            items:
                                                classes
                                                    .map(
                                                      (
                                                        c,
                                                      ) => SearchableSelectItem<
                                                        int
                                                      >(
                                                        value: c.id,
                                                        label:
                                                            c
                                                                    .displayName
                                                                    .isNotEmpty
                                                                ? c.displayName
                                                                : c.name,
                                                      ),
                                                    )
                                                    .toList(),
                                            value: _selectedClassId,
                                            label: 'Class *',
                                            prefixIcon: const Icon(
                                              Icons.class_outlined,
                                              size: 18,
                                            ),
                                            validator:
                                                (val) =>
                                                    val == null
                                                        ? 'Select a class'
                                                        : null,
                                            onChanged: (val) {
                                              if (_selectedClassId != val) {
                                                setState(() {
                                                  _selectedClassId = val;
                                                  _selectedSectionId = null;
                                                });
                                                _loadSubjectsForClass();
                                              }
                                            },
                                          ),
                                      loading:
                                          () => const LinearProgressIndicator(),
                                      error:
                                          (_, _) => const Text(
                                            'Error loading classes',
                                          ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  // Section
                                  Expanded(
                                    flex: 2,
                                    child: AppSearchableSelect<int?>.filter(
                                      items: [
                                        const SearchableSelectItem<int?>(
                                          value: null,
                                          label: 'All Sections (Grade-wide)',
                                        ),
                                        ...availableSections.map(
                                          (s) => SearchableSelectItem<int?>(
                                            value: s.id,
                                            label: 'Section ${s.name}',
                                          ),
                                        ),
                                      ],
                                      value: _selectedSectionId,
                                      hint: 'Section (Optional)',
                                      prefixIcon: const Icon(
                                        Icons.group_outlined,
                                        size: 18,
                                      ),
                                      onChanged: (val) {
                                        setState(
                                          () => _selectedSectionId = val,
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Row 3: Start Date, End Date, Status
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: DualDatePickerField(
                                      label: 'Start Date *',
                                      selectedDate: _startDate,
                                      onDateSelected:
                                          (d) => setState(() => _startDate = d),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    flex: 2,
                                    child: DualDatePickerField(
                                      label: 'End Date *',
                                      selectedDate: _endDate,
                                      onDateSelected:
                                          (d) => setState(() => _endDate = d),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    flex: 2,
                                    child: AppSearchableSelect<String>(
                                      items:
                                          ExamService.statusOptions
                                              .map(
                                                (st) => SearchableSelectItem<
                                                  String
                                                >(value: st, label: st),
                                              )
                                              .toList(),
                                      value: _status,
                                      label: 'Status *',
                                      prefixIcon: const Icon(
                                        Icons.flag_outlined,
                                        size: 18,
                                      ),
                                      onChanged: (val) {
                                        if (val != null) {
                                          setState(() => _status = val);
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Row 4: Description / Notes
                              TextFormField(
                                controller: _descriptionController,
                                maxLines: 2,
                                decoration: const InputDecoration(
                                  labelText: 'Notes / Instructions (Optional)',
                                  hintText:
                                      'e.g. Admit cards are mandatory. 25% weightage for final grade.',
                                  prefixIcon: Icon(
                                    Icons.description_outlined,
                                    size: 20,
                                  ),
                                  isDense: true,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // B. Subject Examination Routine Section Header
                        Row(
                          children: [
                            const Icon(
                              Icons.table_chart_outlined,
                              size: 18,
                              color: AppTheme.primaryColor,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Subject Routine & Marks Configuration',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 10),
                            if (_rows.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withValues(
                                    alpha: 0.12,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${_rows.length} Subjects',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Quick Bulk Settings Toolbar
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color:
                                isDark
                                    ? Colors.grey.shade900
                                    : AppTheme.primaryColor.withValues(
                                      alpha: 0.04,
                                    ),
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            border: Border.all(
                              color:
                                  isDark
                                      ? AppTheme.darkBorder
                                      : AppTheme.primaryColor.withValues(
                                        alpha: 0.15,
                                      ),
                            ),
                          ),
                          child: Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.bolt,
                                    size: 18,
                                    color: Colors.amber.shade700,
                                  ),
                                  const SizedBox(width: 4),
                                  const Text(
                                    'Bulk Fill:',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(
                                width: 110,
                                child: TextFormField(
                                  controller: _bulkStartController,
                                  decoration: const InputDecoration(
                                    labelText: 'Start Time',
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 6,
                                    ),
                                  ),
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              SizedBox(
                                width: 110,
                                child: TextFormField(
                                  controller: _bulkEndController,
                                  decoration: const InputDecoration(
                                    labelText: 'End Time',
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 6,
                                    ),
                                  ),
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              SizedBox(
                                width: 120,
                                child: TextFormField(
                                  controller: _bulkRoomController,
                                  decoration: const InputDecoration(
                                    labelText: 'Room / Hall',
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 6,
                                    ),
                                  ),
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.flash_on, size: 15),
                                label: const Text(
                                  'Apply to All',
                                  style: TextStyle(fontSize: 12),
                                ),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  backgroundColor: AppTheme.primaryColor,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: _applyBulkSettings,
                              ),
                              if (_selectedClassId != null)
                                _buildAddSubjectButton(context),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Tabular Subjects Form
                        if (_isLoadingSubjects)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 40),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (_selectedClassId == null)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 36),
                            decoration: BoxDecoration(
                              color:
                                  isDark
                                      ? Colors.grey.shade900
                                      : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              border: Border.all(
                                color:
                                    isDark
                                        ? AppTheme.darkBorder
                                        : AppTheme.lightBorder,
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.touch_app_outlined,
                                  size: 40,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Please select a Class above to load curriculum subjects and routine',
                                  style: TextStyle(fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          )
                        else if (_rows.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 32),
                            decoration: BoxDecoration(
                              color:
                                  isDark
                                      ? Colors.grey.shade900
                                      : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              border: Border.all(
                                color:
                                    isDark
                                        ? AppTheme.darkBorder
                                        : AppTheme.lightBorder,
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'No curriculum subjects found for this class.',
                                ),
                                const SizedBox(height: 10),
                                _buildAddSubjectButton(context),
                              ],
                            ),
                          )
                        else
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Container(
                              decoration: BoxDecoration(
                                color:
                                    isDark
                                        ? AppTheme.darkSurface
                                        : AppTheme.lightSurface,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.md,
                                ),
                                border: Border.all(
                                  color:
                                      isDark
                                          ? AppTheme.darkBorder
                                          : AppTheme.lightBorder,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Table Header
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          isDark
                                              ? Colors.grey.shade800
                                              : Colors.grey.shade200,
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(AppRadius.md),
                                      ),
                                    ),
                                    child: const Row(
                                      children: [
                                        SizedBox(
                                          width: 32,
                                          child: Text(
                                            '#',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 170,
                                          child: Text(
                                            'Subject',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 190,
                                          child: Text(
                                            'Exam Date (AD / BS)',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 6),
                                        SizedBox(
                                          width: 110,
                                          child: Text(
                                            'Start Time',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 6),
                                        SizedBox(
                                          width: 110,
                                          child: Text(
                                            'End Time',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 6),
                                        SizedBox(
                                          width: 140,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                'Theory Marks',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                ),
                                              ),
                                              Text(
                                                'Full / Pass',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        SizedBox(width: 6),
                                        SizedBox(
                                          width: 140,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                'Practical Marks',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                ),
                                              ),
                                              Text(
                                                'Full / Pass',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        SizedBox(width: 6),
                                        SizedBox(
                                          width: 100,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                'Total Marks',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                ),
                                              ),
                                              Text(
                                                'Full / Pass',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        SizedBox(width: 6),
                                        SizedBox(
                                          width: 100,
                                          child: Text(
                                            'Room / Hall',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 6),
                                        SizedBox(
                                          width: 110,
                                          child: Text(
                                            'Remarks',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 4),
                                        SizedBox(
                                          width: 36,
                                          child: Text(
                                            '',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Table Body Rows
                                  ...List.generate(_rows.length, (index) {
                                    final row = _rows[index];
                                    final isEven = index.isEven;
                                    final rowBg =
                                        isEven
                                            ? (isDark
                                                ? Colors.grey.shade900
                                                : Colors.white)
                                            : (isDark
                                                ? const Color(0xFF1E1E1E)
                                                : Colors.grey.shade50);

                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: rowBg,
                                        border: Border(
                                          bottom: BorderSide(
                                            color:
                                                isDark
                                                    ? AppTheme.darkBorder
                                                    : AppTheme.lightBorder,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          // 1. Index
                                          SizedBox(
                                            width: 32,
                                            child: Text(
                                              '${index + 1}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),

                                          // 2. Subject Name + Code + Badge
                                          SizedBox(
                                            width: 170,
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  row.subject.name,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 2),
                                                Row(
                                                  children: [
                                                    Text(
                                                      row.subject.code,
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color:
                                                            Colors
                                                                .grey
                                                                .shade600,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 5,
                                                            vertical: 1,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color:
                                                            row.subject.subjectType ==
                                                                    SubjectType
                                                                        .theory
                                                                ? Colors.blue
                                                                    .withValues(
                                                                      alpha:
                                                                          0.12,
                                                                    )
                                                                : Colors.purple
                                                                    .withValues(
                                                                      alpha:
                                                                          0.12,
                                                                    ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              4,
                                                            ),
                                                      ),
                                                      child: Text(
                                                        row
                                                            .subject
                                                            .subjectType
                                                            .displayName,
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color:
                                                              row.subject.subjectType ==
                                                                      SubjectType
                                                                          .theory
                                                                  ? Colors
                                                                      .blue
                                                                      .shade700
                                                                  : Colors
                                                                      .purple
                                                                      .shade700,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),

                                          // 3. Exam Date (Dual Calendar Picker)
                                          SizedBox(
                                            width: 190,
                                            child: DualDatePickerField(
                                              label: 'Exam Date',
                                              selectedDate: row.examDate,
                                              onDateSelected: (d) {
                                                setState(
                                                  () => row.examDate = d,
                                                );
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 6),

                                          // 4. Start Time
                                          SizedBox(
                                            width: 110,
                                            child: TextFormField(
                                              controller:
                                                  row.startTimeController,
                                              decoration: InputDecoration(
                                                isDense: true,
                                                contentPadding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 8,
                                                    ),
                                                suffixIcon: IconButton(
                                                  icon: const Icon(
                                                    Icons.access_time,
                                                    size: 16,
                                                  ),
                                                  padding: EdgeInsets.zero,
                                                  constraints:
                                                      const BoxConstraints(),
                                                  onPressed:
                                                      () => _selectTime(
                                                        context,
                                                        row.startTimeController,
                                                      ),
                                                ),
                                              ),
                                              style: const TextStyle(
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),

                                          // 5. End Time
                                          SizedBox(
                                            width: 110,
                                            child: TextFormField(
                                              controller: row.endTimeController,
                                              decoration: InputDecoration(
                                                isDense: true,
                                                contentPadding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 8,
                                                    ),
                                                suffixIcon: IconButton(
                                                  icon: const Icon(
                                                    Icons.access_time,
                                                    size: 16,
                                                  ),
                                                  padding: EdgeInsets.zero,
                                                  constraints:
                                                      const BoxConstraints(),
                                                  onPressed:
                                                      () => _selectTime(
                                                        context,
                                                        row.endTimeController,
                                                      ),
                                                ),
                                              ),
                                              style: const TextStyle(
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),

                                          // 6. Theory Marks (Full / Pass)
                                          SizedBox(
                                            width: 140,
                                            child:
                                                row.subject.subjectType ==
                                                        SubjectType.practical
                                                    ? Center(
                                                      child: Text(
                                                        '—',
                                                        style: TextStyle(
                                                          color:
                                                              Colors
                                                                  .grey
                                                                  .shade400,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    )
                                                    : Row(
                                                      children: [
                                                        Expanded(
                                                          child: TextFormField(
                                                            controller:
                                                                row.theoryMarksController,
                                                            keyboardType:
                                                                TextInputType
                                                                    .number,
                                                            onChanged:
                                                                (_) => setState(
                                                                  () =>
                                                                      row.updateTotals(),
                                                                ),
                                                            decoration: const InputDecoration(
                                                              hintText: 'Full',
                                                              isDense: true,
                                                              contentPadding:
                                                                  EdgeInsets.symmetric(
                                                                    horizontal:
                                                                        6,
                                                                    vertical: 8,
                                                                  ),
                                                            ),
                                                            style:
                                                                const TextStyle(
                                                                  fontSize: 12,
                                                                ),
                                                          ),
                                                        ),
                                                        const Padding(
                                                          padding:
                                                              EdgeInsets.symmetric(
                                                                horizontal: 2,
                                                              ),
                                                          child: Text(
                                                            '/',
                                                            style: TextStyle(
                                                              color:
                                                                  Colors.grey,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                          ),
                                                        ),
                                                        Expanded(
                                                          child: TextFormField(
                                                            controller:
                                                                row.theoryPassMarksController,
                                                            keyboardType:
                                                                TextInputType
                                                                    .number,
                                                            onChanged:
                                                                (_) => setState(
                                                                  () =>
                                                                      row.updateTotals(),
                                                                ),
                                                            decoration: const InputDecoration(
                                                              hintText: 'Pass',
                                                              isDense: true,
                                                              contentPadding:
                                                                  EdgeInsets.symmetric(
                                                                    horizontal:
                                                                        6,
                                                                    vertical: 8,
                                                                  ),
                                                            ),
                                                            style:
                                                                const TextStyle(
                                                                  fontSize: 12,
                                                                ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                          ),
                                          const SizedBox(width: 6),

                                          // 7. Practical Marks (Full / Pass)
                                          SizedBox(
                                            width: 140,
                                            child:
                                                row.subject.subjectType ==
                                                        SubjectType.theory
                                                    ? Center(
                                                      child: Text(
                                                        '—',
                                                        style: TextStyle(
                                                          color:
                                                              Colors
                                                                  .grey
                                                                  .shade400,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    )
                                                    : Row(
                                                      children: [
                                                        Expanded(
                                                          child: TextFormField(
                                                            controller:
                                                                row.practicalMarksController,
                                                            keyboardType:
                                                                TextInputType
                                                                    .number,
                                                            onChanged:
                                                                (_) => setState(
                                                                  () =>
                                                                      row.updateTotals(),
                                                                ),
                                                            decoration: const InputDecoration(
                                                              hintText: 'Full',
                                                              isDense: true,
                                                              contentPadding:
                                                                  EdgeInsets.symmetric(
                                                                    horizontal:
                                                                        6,
                                                                    vertical: 8,
                                                                  ),
                                                            ),
                                                            style:
                                                                const TextStyle(
                                                                  fontSize: 12,
                                                                ),
                                                          ),
                                                        ),
                                                        const Padding(
                                                          padding:
                                                              EdgeInsets.symmetric(
                                                                horizontal: 2,
                                                              ),
                                                          child: Text(
                                                            '/',
                                                            style: TextStyle(
                                                              color:
                                                                  Colors.grey,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                          ),
                                                        ),
                                                        Expanded(
                                                          child: TextFormField(
                                                            controller:
                                                                row.practicalPassMarksController,
                                                            keyboardType:
                                                                TextInputType
                                                                    .number,
                                                            onChanged:
                                                                (_) => setState(
                                                                  () =>
                                                                      row.updateTotals(),
                                                                ),
                                                            decoration: const InputDecoration(
                                                              hintText: 'Pass',
                                                              isDense: true,
                                                              contentPadding:
                                                                  EdgeInsets.symmetric(
                                                                    horizontal:
                                                                        6,
                                                                    vertical: 8,
                                                                  ),
                                                            ),
                                                            style:
                                                                const TextStyle(
                                                                  fontSize: 12,
                                                                ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                          ),
                                          const SizedBox(width: 6),

                                          // 8. Total Marks (Full / Pass)
                                          SizedBox(
                                            width: 100,
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 7,
                                                  ),
                                              decoration: BoxDecoration(
                                                color:
                                                    isDark
                                                        ? Colors.grey.shade800
                                                        : Colors.grey.shade100,
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                border: Border.all(
                                                  color:
                                                      isDark
                                                          ? AppTheme.darkBorder
                                                          : AppTheme
                                                              .lightBorder,
                                                ),
                                              ),
                                              child: Center(
                                                child: Text(
                                                  '${row.fullMarksController.text.isNotEmpty ? row.fullMarksController.text : '0'} / ${row.passMarksController.text.isNotEmpty ? row.passMarksController.text : '0'}',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                    color:
                                                        AppTheme.primaryColor,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),

                                          // 9. Room
                                          SizedBox(
                                            width: 100,
                                            child: TextFormField(
                                              controller: row.roomController,
                                              decoration: const InputDecoration(
                                                hintText: 'Room #',
                                                isDense: true,
                                                contentPadding:
                                                    EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 8,
                                                    ),
                                              ),
                                              style: const TextStyle(
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),

                                          // 10. Remarks
                                          SizedBox(
                                            width: 110,
                                            child: TextFormField(
                                              controller: row.remarksController,
                                              decoration: const InputDecoration(
                                                hintText: 'Notes',
                                                isDense: true,
                                                contentPadding:
                                                    EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 8,
                                                    ),
                                              ),
                                              style: const TextStyle(
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 4),

                                          // 11. Delete Action
                                          SizedBox(
                                            width: 36,
                                            child: IconButton(
                                              icon: const Icon(
                                                Icons.delete_outline,
                                                size: 18,
                                                color: Colors.red,
                                              ),
                                              tooltip: 'Remove subject',
                                              onPressed:
                                                  () => _removeRow(index),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 14),

              // 3. Footer Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _rows.isNotEmpty
                        ? 'Total ${_rows.length} subjects in routine'
                        : '',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color:
                          isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ),
                  Row(
                    children: [
                      TextButton(
                        onPressed:
                            _isSubmitting
                                ? null
                                : () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        icon:
                            _isSubmitting
                                ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                                : const Icon(Icons.check, size: 18),
                        label: Text(
                          isEditing ? 'Save Changes' : 'Create Exam & Routine',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                        ),
                        onPressed: _isSubmitting ? null : _saveExamAndRoutine,
                      ),
                    ],
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
