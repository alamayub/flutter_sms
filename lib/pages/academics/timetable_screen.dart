import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../config/extensions.dart';
import '../../config/responsive.dart';
import '../../config/theme.dart';
import '../../config/translations.dart';
import '../../data/app_database.dart';
import '../../providers/academic_year_provider.dart';
import '../../providers/class_section_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/subject_provider.dart';
import '../../providers/teacher_provider.dart';
import '../../providers/timetable_provider.dart';
import '../../utils/ui_helpers.dart';
import '../../widgets/weekly_timetable_editor.dart';
import '../../widgets/searchable_select.dart';

class TimetableScreen extends ConsumerStatefulWidget {
  const TimetableScreen({super.key});

  @override
  ConsumerState<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends ConsumerState<TimetableScreen> {
  // Day of week definitions as lowercase day strings
  static const List<String> _schoolDays = [
    'sunday',
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
  ];

  static String _getDayKey(String day) => day.toLowerCase();

  static String _getDayShortName(String day, String langCode) {
    if (langCode == 'ne') {
      switch (day.toLowerCase()) {
        case 'sunday':
          return 'आइत';
        case 'monday':
          return 'सोम';
        case 'tuesday':
          return 'मङ्गल';
        case 'wednesday':
          return 'बुध';
        case 'thursday':
          return 'बिही';
        case 'friday':
          return 'शुक्र';
        case 'saturday':
          return 'शनि';
        default:
          return '';
      }
    }
    switch (day.toLowerCase()) {
      case 'sunday':
        return 'Sun';
      case 'monday':
        return 'Mon';
      case 'tuesday':
        return 'Tue';
      case 'wednesday':
        return 'Wed';
      case 'thursday':
        return 'Thu';
      case 'friday':
        return 'Fri';
      case 'saturday':
        return 'Sat';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final classesAsync = ref.watch(classesWithSectionsStreamProvider);
    final selectedClassId = ref.watch(selectedTimetableClassProvider);
    final selectedSectionId = ref.watch(selectedTimetableSectionProvider);
    final selectedDay = ref.watch(selectedTimetableDayProvider);
    final viewMode = ref.watch(timetableCalendarModeProvider);

    final academicYearsAsync = ref.watch(academicYearsStreamProvider);
    final selectedYearId = ref.watch(selectedTimetableAcademicYearProvider);

    final weeklyPeriodsAsync = ref.watch(weeklyPeriodsStreamProvider);
    final dayPeriodsAsync = ref.watch(dayPeriodsStreamProvider);

    final currentLang = ref.watch(localeProvider);
    final langCode = currentLang.locale.languageCode;

    return Scaffold(
      body: classesAsync.when(
        data: (classes) {
          if (classes.isEmpty) {
            return Center(
              child: Text(AppTranslations.text('no_classes', langCode)),
            );
          }

          // Academic years resolution
          final academicYears = academicYearsAsync.value ?? [];
          final activeYear =
              academicYears.where((y) => y.isCurrent).firstOrNull ??
              academicYears.firstOrNull;
          final effectiveYearId = selectedYearId ?? activeYear?.id ?? 1;
          final currentYear =
              academicYears.where((y) => y.id == effectiveYearId).firstOrNull ??
              activeYear;

          // Auto-select first class if none selected
          final effectiveClassId = selectedClassId ?? classes.first.id;
          final currentClass = classes.firstWhere(
            (c) => c.id == effectiveClassId,
            orElse: () => classes.first,
          );

          // Sections for selected class
          final sections = currentClass.sections;

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
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header with Filters & Actions
                  _buildHeader(
                    context,
                    classes: classes,
                    selectedClassId: effectiveClassId,
                    sections: sections,
                    selectedSectionId: selectedSectionId,
                    academicYears: academicYears,
                    selectedYearId: effectiveYearId,
                    currentYearName: currentYear?.name,
                    viewMode: viewMode,
                    langCode: langCode,
                  ),
                  const SizedBox(height: 16),

                  // Day of Week Selector Bar
                  _buildDaySelectorBar(
                    context,
                    selectedDay: selectedDay,
                    weeklyPeriods: weeklyPeriodsAsync.value ?? [],
                    langCode: langCode,
                  ),
                  const SizedBox(height: 20),

                  // Content view (Weekly Calendar Grid or Day Timeline)
                  if (viewMode == TimetableCalendarMode.weeklyGrid)
                    weeklyPeriodsAsync.when(
                      data:
                          (periods) => _buildWeeklyCalendarGrid(
                            context,
                            periods: periods,
                            classes: classes,
                            selectedClassId: effectiveClassId,
                            selectedSectionId: selectedSectionId,
                            academicYearId: effectiveYearId,
                            academicYearName: currentYear?.name,
                            langCode: langCode,
                          ),
                      loading:
                          () => const Center(
                            child: Padding(
                              padding: EdgeInsets.all(40),
                              child: CircularProgressIndicator(),
                            ),
                          ),
                      error:
                          (err, _) => Center(
                            child: Text('Error loading timetable: $err'),
                          ),
                    )
                  else
                    dayPeriodsAsync.when(
                      data:
                          (periods) => _buildDayTimelineView(
                            context,
                            periods: periods,
                            selectedDay: selectedDay,
                            classes: classes,
                            selectedClassId: effectiveClassId,
                            selectedSectionId: selectedSectionId,
                            academicYearId: effectiveYearId,
                            academicYearName: currentYear?.name,
                            langCode: langCode,
                          ),
                      loading:
                          () => const Center(
                            child: Padding(
                              padding: EdgeInsets.all(40),
                              child: CircularProgressIndicator(),
                            ),
                          ),
                      error:
                          (err, _) => Center(
                            child: Text('Error loading timetable: $err'),
                          ),
                    ),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading classes: $err')),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context, {
    required List<ClassWithSections> classes,
    required int selectedClassId,
    required List<Section> sections,
    required int? selectedSectionId,
    required List<AcademicYear> academicYears,
    required int selectedYearId,
    required String? currentYearName,
    required TimetableCalendarMode viewMode,
    required String langCode,
  }) {
    final theme = Theme.of(context);

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Title & Class / Section Pickers
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppTranslations.text('timetable', langCode),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  langCode == 'ne'
                      ? 'कक्षा अनुसार साप्ताहिक तालिका'
                      : 'Class Weekly Schedule & Periods',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.textTheme.bodySmall?.color,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),

            // Academic Year Dropdown
            if (academicYears.isNotEmpty)
              SizedBox(
                width: 180,
                child: AppSearchableSelect<int>.filter(
                  value: selectedYearId,
                  isClearable: false,
                  items:
                      academicYears.map((y) {
                        return SearchableSelectItem<int>(
                          value: y.id,
                          label:
                              y.name +
                              (y.isCurrent
                                  ? (langCode == 'ne' ? ' (चालु)' : ' (Active)')
                                  : ''),
                          leading: Icon(
                            Icons.calendar_today,
                            size: 14,
                            color: theme.colorScheme.primary,
                          ),
                        );
                      }).toList(),
                  onChanged: (newYearId) {
                    if (newYearId != null) {
                      ref
                          .read(selectedTimetableAcademicYearProvider.notifier)
                          .setAcademicYear(newYearId);
                    }
                  },
                ),
              ),

            // Class Dropdown
            SizedBox(
              width: 160,
              child: AppSearchableSelect<int>.filter(
                value: selectedClassId,
                isClearable: false,
                items:
                    classes.map((c) {
                      return SearchableSelectItem<int>(
                        value: c.id,
                        label:
                            c.displayName.isNotEmpty ? c.displayName : c.name,
                      );
                    }).toList(),
                onChanged: (newId) {
                  if (newId != null) {
                    ref
                        .read(selectedTimetableClassProvider.notifier)
                        .setClass(newId);
                    // Reset section filter when class changes
                    ref
                        .read(selectedTimetableSectionProvider.notifier)
                        .setSection(null);
                  }
                },
              ),
            ),

            // Section Dropdown
            if (sections.isNotEmpty)
              SizedBox(
                width: 140,
                child: AppSearchableSelect<int?>.filter(
                  value: selectedSectionId,
                  hint: langCode == 'ne' ? 'सबै सेक्सन' : 'All Sections',
                  isClearable: true,
                  items:
                      sections.map((s) {
                        return SearchableSelectItem<int?>(
                          value: s.id,
                          label: 'Sec ${s.name}',
                        );
                      }).toList(),
                  onChanged: (newSecId) {
                    ref
                        .read(selectedTimetableSectionProvider.notifier)
                        .setSection(newSecId);
                  },
                ),
              ),
          ],
        ),

        // View Mode Switcher & Add Period Button
        Wrap(
          spacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SegmentedButton<TimetableCalendarMode>(
              segments: [
                ButtonSegment(
                  value: TimetableCalendarMode.weeklyGrid,
                  icon: const Icon(Icons.grid_view, size: 16),
                  label: Text(AppTranslations.text('weekly_view', langCode)),
                ),
                ButtonSegment(
                  value: TimetableCalendarMode.dayTimeline,
                  icon: const Icon(Icons.view_agenda_outlined, size: 16),
                  label: Text(AppTranslations.text('day_view', langCode)),
                ),
              ],
              selected: {viewMode},
              onSelectionChanged: (set) {
                ref
                    .read(timetableCalendarModeProvider.notifier)
                    .setMode(set.first);
              },
            ),
            if (academicYears.length > 1)
              OutlinedButton.icon(
                icon: const Icon(Icons.copy_all, size: 18),
                label: Text(langCode == 'ne' ? 'तालिका कपी' : 'Copy Schedule'),
                onPressed: () {
                  _showCopyTimetableDialog(
                    context,
                    academicYears: academicYears,
                    currentYearId: selectedYearId,
                    classes: classes,
                    selectedClassId: selectedClassId,
                    selectedSectionId: selectedSectionId,
                    langCode: langCode,
                  );
                },
              ),
            FilledButton.icon(
              icon: const Icon(Icons.calendar_month, size: 18),
              label: Text(
                AppTranslations.text('edit_weekly_timetable', langCode),
              ),
              onPressed: () {
                final currentClass = classes.firstWhere(
                  (c) => c.id == selectedClassId,
                  orElse: () => classes.first,
                );
                final currentSection =
                    sections
                        .where((s) => s.id == selectedSectionId)
                        .firstOrNull;
                _openWeeklyEditor(
                  context,
                  academicYearId: selectedYearId,
                  academicYearName: currentYearName,
                  classId: currentClass.id,
                  sectionId: selectedSectionId,
                  className:
                      currentClass.displayName.isNotEmpty
                          ? currentClass.displayName
                          : currentClass.name,
                  sectionName: currentSection?.name,
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  void _showCopyTimetableDialog(
    BuildContext context, {
    required List<AcademicYear> academicYears,
    required int currentYearId,
    required List<ClassWithSections> classes,
    required int selectedClassId,
    required int? selectedSectionId,
    required String langCode,
  }) {
    final otherYears =
        academicYears.where((y) => y.id != currentYearId).toList();
    if (otherYears.isEmpty) {
      context.showSnackbar(
        SnackBar(
          content: Text(
            langCode == 'ne'
                ? 'प्रतिलिपि गर्नका लागि अर्को शैक्षिक सत्र उपलब्ध छैन।'
                : 'No other academic session available to copy schedule from.',
          ),
        ),
      );
      return;
    }

    int sourceYearId = otherYears.first.id;
    bool copyOnlyCurrentClass = true;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final theme = Theme.of(ctx);
            final targetYear = academicYears.firstWhere(
              (y) => y.id == currentYearId,
              orElse: () => academicYears.first,
            );
            final selectedClass = classes.firstWhere(
              (c) => c.id == selectedClassId,
              orElse: () => classes.first,
            );

            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.copy_all, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    langCode == 'ne'
                        ? 'तालिका प्रतिलिपि गर्नुहोस्'
                        : 'Copy Schedule from Session',
                    style: const TextStyle(fontSize: 18),
                  ),
                ],
              ),
              content: SizedBox(
                width: 440,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      langCode == 'ne'
                          ? 'अर्को शैक्षिक सत्रबाट यस शैक्षिक सत्र (${targetYear.name}) मा तालिका प्रतिलिपि गर्नुहोस्।'
                          : 'Copy class timetable and periods from another academic session into the current session (${targetYear.name}).',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      langCode == 'ne'
                          ? 'स्रोत शैक्षिक सत्र (कहाँबाट):'
                          : 'Source Academic Session (Copy from):',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    AppSearchableSelect<int>(
                      value: sourceYearId,
                      isDense: true,
                      items:
                          otherYears.map((y) {
                            return SearchableSelectItem<int>(
                              value: y.id,
                              label: y.name,
                            );
                          }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => sourceYearId = val);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        langCode == 'ne'
                            ? 'हालको कक्षा मात्र प्रतिलिपि गर्नुहोस्'
                            : 'Copy only for selected class',
                      ),
                      subtitle: Text(
                        selectedClass.displayName.isNotEmpty
                            ? selectedClass.displayName
                            : selectedClass.name,
                      ),
                      value: copyOnlyCurrentClass,
                      onChanged: (val) {
                        setDialogState(
                          () => copyOnlyCurrentClass = val ?? true,
                        );
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(AppTranslations.text('cancel', langCode)),
                ),
                FilledButton.icon(
                  icon: const Icon(Icons.copy, size: 16),
                  label: Text(
                    langCode == 'ne' ? 'प्रतिलिपि गर्नुहोस्' : 'Copy Schedule',
                  ),
                  onPressed: () async {
                    Navigator.pop(dialogContext);
                    try {
                      final count = await ref
                          .read(timetableControllerProvider.notifier)
                          .copyTimetableFromYear(
                            sourceAcademicYearId: sourceYearId,
                            targetAcademicYearId: currentYearId,
                            classId:
                                copyOnlyCurrentClass ? selectedClassId : null,
                            sectionId:
                                copyOnlyCurrentClass ? selectedSectionId : null,
                          );
                      context.showSnackbar(
                        SnackBar(
                          content: Text(
                            langCode == 'ne'
                                ? '$count पिरियड तालिका सफलतापूर्वक प्रतिलिपि गरियो।'
                                : 'Successfully copied $count timetable slots.',
                          ),
                          backgroundColor: Colors.green.shade700,
                        ),
                      );
                    } catch (e) {
                      context.showSnackbar(
                        SnackBar(
                          content: Text('Failed to copy schedule: $e'),
                          backgroundColor: Colors.red.shade700,
                        ),
                      );
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDaySelectorBar(
    BuildContext context, {
    required String selectedDay,
    required List<PeriodWithDetails> weeklyPeriods,
    required String langCode,
  }) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children:
            _schoolDays.map((day) {
              final isSelected = day == selectedDay;
              final dayName = AppTranslations.text(_getDayKey(day), langCode);
              final periodsCount =
                  weeklyPeriods
                      .where((p) => p.dayOfWeek.toLowerCase() == day)
                      .length;

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  selected: isSelected,
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        dayName,
                        style: TextStyle(
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
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
                              isSelected
                                  ? theme.colorScheme.onPrimary.withAlpha(50)
                                  : theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$periodsCount',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color:
                                isSelected
                                    ? theme.colorScheme.onPrimary
                                    : theme.textTheme.bodySmall?.color,
                          ),
                        ),
                      ),
                    ],
                  ),
                  onSelected: (_) {
                    ref.read(selectedTimetableDayProvider.notifier).setDay(day);
                  },
                ),
              );
            }).toList(),
      ),
    );
  }

  // ================= WEEKLY CALENDAR GRID =================

  Widget _buildWeeklyCalendarGrid(
    BuildContext context, {
    required List<PeriodWithDetails> periods,
    required List<ClassWithSections> classes,
    required int selectedClassId,
    required int? selectedSectionId,
    required int academicYearId,
    String? academicYearName,
    required String langCode,
  }) {
    final theme = Theme.of(context);

    if (periods.isEmpty) {
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
                AppTranslations.text('no_periods', langCode),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                icon: const Icon(Icons.calendar_month),
                label: Text(
                  AppTranslations.text('create_weekly_timetable', langCode),
                ),
                onPressed: () {
                  final currentClass = classes.firstWhere(
                    (c) => c.id == selectedClassId,
                    orElse: () => classes.first,
                  );
                  final currentSection =
                      classes
                          .expand((c) => c.sections)
                          .where((s) => s.id == selectedSectionId)
                          .firstOrNull;
                  _openWeeklyEditor(
                    context,
                    academicYearId: academicYearId,
                    academicYearName: academicYearName,
                    classId: currentClass.id,
                    sectionId: selectedSectionId,
                    className:
                        currentClass.displayName.isNotEmpty
                            ? currentClass.displayName
                            : currentClass.name,
                    sectionName: currentSection?.name,
                  );
                },
              ),
            ],
          ),
        ),
      );
    }

    // Extract unique time slots across the week, sorted by start time
    final timeSlotsMap = <String, String>{};
    for (final p in periods) {
      timeSlotsMap[p.startTime] = p.endTime;
    }
    final sortedStartTimes = timeSlotsMap.keys.toList()..sort();

    // Map of dayOfWeek -> startTime -> PeriodWithDetails
    final gridData = <String, Map<String, PeriodWithDetails>>{};
    for (final p in periods) {
      gridData.putIfAbsent(p.dayOfWeek.toLowerCase(), () => {})[p.startTime] =
          p;
    }

    const gridDays = [
      'sunday',
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
    ];

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, contatrains) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: contatrains.minWidth),
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(
                  theme.colorScheme.surfaceContainerHighest.withAlpha(80),
                ),
                dataRowMinHeight: 76,
                dataRowMaxHeight: 92,
                columnSpacing: 14,
                horizontalMargin: 16,
                columns: [
                  DataColumn(
                    label: Text(
                      langCode == 'ne' ? 'समय / घण्टी' : 'Time / Slot',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  // Sunday through Friday standard school days
                  ...gridDays.map((day) {
                    return DataColumn(
                      label: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _getDayShortName(day, langCode),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              AppTranslations.text(_getDayKey(day), langCode),
                              style: TextStyle(
                                fontSize: 10,
                                color: theme.textTheme.bodySmall?.color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
                rows:
                    sortedStartTimes.map((startTime) {
                      final endTime = timeSlotsMap[startTime] ?? '';

                      return DataRow(
                        cells: [
                          // Time Column
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest
                                    .withAlpha(50),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    startTime,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'to $endTime',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: theme.textTheme.bodySmall?.color,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Day Columns (Sunday .. Friday)
                          ...gridDays.map((day) {
                            final period = gridData[day]?[startTime];
                            if (period == null) {
                              return DataCell(
                                InkWell(
                                  onTap: () {
                                    final currentClass = classes.firstWhere(
                                      (c) => c.id == selectedClassId,
                                      orElse: () => classes.first,
                                    );
                                    final currentSection =
                                        classes
                                            .expand((c) => c.sections)
                                            .where(
                                              (s) => s.id == selectedSectionId,
                                            )
                                            .firstOrNull;
                                    _openWeeklyEditor(
                                      context,
                                      academicYearId: academicYearId,
                                      academicYearName: academicYearName,
                                      classId: currentClass.id,
                                      sectionId: selectedSectionId,
                                      className:
                                          currentClass.displayName.isNotEmpty
                                              ? currentClass.displayName
                                              : currentClass.name,
                                      sectionName: currentSection?.name,
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    alignment: Alignment.center,
                                    child: Icon(
                                      Icons.add,
                                      size: 16,
                                      color: theme.dividerColor,
                                    ),
                                  ),
                                ),
                              );
                            }

                            return DataCell(
                              _buildGridPeriodCard(
                                context,
                                period: period,
                                langCode: langCode,
                                onTap: () {
                                  final currentClass = classes.firstWhere(
                                    (c) => c.id == selectedClassId,
                                    orElse: () => classes.first,
                                  );
                                  final currentSection =
                                      classes
                                          .expand((c) => c.sections)
                                          .where(
                                            (s) => s.id == selectedSectionId,
                                          )
                                          .firstOrNull;
                                  _openWeeklyEditor(
                                    context,
                                    academicYearId: academicYearId,
                                    academicYearName: academicYearName,
                                    classId: currentClass.id,
                                    sectionId: selectedSectionId,
                                    className:
                                        currentClass.displayName.isNotEmpty
                                            ? currentClass.displayName
                                            : currentClass.name,
                                    sectionName: currentSection?.name,
                                  );
                                },
                              ),
                            );
                          }),
                        ],
                      );
                    }).toList(),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGridPeriodCard(
    BuildContext context, {
    required PeriodWithDetails period,
    required String langCode,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    if (period.isBreak) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 130,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.warningColor.withAlpha(20),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.warningColor.withAlpha(60)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.restaurant_outlined,
                size: 16,
                color: AppTheme.warningColor,
              ),
              const SizedBox(height: 2),
              Text(
                period.breakTitle ?? 'Break',
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.warningColor,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 130,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    period.subject?.name ?? 'Subject',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (period.subject != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withAlpha(25),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      period.subject!.code,
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            if (period.teacher != null)
              Row(
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 11,
                    color: theme.textTheme.bodySmall?.color,
                  ),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Text(
                      period.teacher!.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        color: theme.textTheme.bodySmall?.color,
                      ),
                    ),
                  ),
                ],
              ),
            if (period.roomNumber != null && period.roomNumber!.isNotEmpty)
              Text(
                period.roomNumber!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.secondary,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ================= DAY TIMELINE VIEW =================

  Widget _buildDayTimelineView(
    BuildContext context, {
    required List<PeriodWithDetails> periods,
    required String selectedDay,
    required List<ClassWithSections> classes,
    required int selectedClassId,
    required int? selectedSectionId,
    required int academicYearId,
    String? academicYearName,
    required String langCode,
  }) {
    if (periods.isEmpty) {
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
                '${AppTranslations.text(_getDayKey(selectedDay), langCode)}: ${AppTranslations.text('no_periods', langCode)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                icon: const Icon(Icons.calendar_month),
                label: Text(
                  AppTranslations.text('create_weekly_timetable', langCode),
                ),
                onPressed: () {
                  final currentClass = classes.firstWhere(
                    (c) => c.id == selectedClassId,
                    orElse: () => classes.first,
                  );
                  final currentSection =
                      classes
                          .expand((c) => c.sections)
                          .where((s) => s.id == selectedSectionId)
                          .firstOrNull;
                  _openWeeklyEditor(
                    context,
                    academicYearId: academicYearId,
                    academicYearName: academicYearName,
                    classId: currentClass.id,
                    sectionId: selectedSectionId,
                    className:
                        currentClass.displayName.isNotEmpty
                            ? currentClass.displayName
                            : currentClass.name,
                    sectionName: currentSection?.name,
                  );
                },
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: periods.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = periods[index];
        return _buildTimelinePeriodCard(
          context,
          item: item,
          langCode: langCode,
        );
      },
    );
  }

  Widget _buildTimelinePeriodCard(
    BuildContext context, {
    required PeriodWithDetails item,
    required String langCode,
  }) {
    final theme = Theme.of(context);

    if (item.isBreak) {
      return Card(
        elevation: 0,
        color: AppTheme.warningColor.withAlpha(15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AppTheme.warningColor.withAlpha(50)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Time & Break Icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.warningColor.withAlpha(30),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.coffee_outlined,
                  color: AppTheme.warningColor,
                ),
              ),
              const SizedBox(width: 14),

              // Break Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.breakTitle ?? 'Break / Recess',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.warningColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item.startTime}  –  ${item.endTime}${item.roomNumber != null ? '  |  ${item.roomNumber}' : ''}',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.textTheme.bodySmall?.color,
                      ),
                    ),
                  ],
                ),
              ),

              // Actions
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18),
                tooltip: AppTranslations.text('edit_period', langCode),
                onPressed:
                    () => _openPeriodFormDialog(
                      context,
                      academicYearId: item.academicYearId,
                      period: item,
                    ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  color: AppTheme.errorColor,
                  size: 18,
                ),
                tooltip: AppTranslations.text('delete_period', langCode),
                onPressed: () => _confirmDeletePeriod(item, langCode),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Period Number Badge
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: theme.colorScheme.primary.withAlpha(60),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'P${item.periodNumber}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  Text(
                    item.startTime,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),

            // Subject & Teacher Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        item.subject?.name ?? 'Subject',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (item.subject != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            item.subject!.code,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: theme.textTheme.bodySmall?.color,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      // Time range
                      Icon(
                        Icons.access_time,
                        size: 13,
                        color: theme.textTheme.bodySmall?.color,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${item.startTime} – ${item.endTime}',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.textTheme.bodySmall?.color,
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Teacher
                      if (item.teacher != null) ...[
                        Icon(
                          Icons.person_outline,
                          size: 13,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          item.teacher!.name,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],

                      // Room
                      if (item.roomNumber != null &&
                          item.roomNumber!.isNotEmpty) ...[
                        Icon(
                          Icons.room_outlined,
                          size: 13,
                          color: theme.textTheme.bodySmall?.color,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          item.roomNumber!,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.textTheme.bodySmall?.color,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Actions
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18),
              tooltip: AppTranslations.text('edit_period', langCode),
              onPressed:
                  () => _openPeriodFormDialog(
                    context,
                    academicYearId: item.academicYearId,
                    period: item,
                  ),
            ),
            IconButton(
              icon: const Icon(
                Icons.delete_outline,
                color: AppTheme.errorColor,
                size: 18,
              ),
              tooltip: AppTranslations.text('delete_period', langCode),
              onPressed: () => _confirmDeletePeriod(item, langCode),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeletePeriod(
    PeriodWithDetails item,
    String langCode,
  ) async {
    final title =
        item.isBreak
            ? (item.breakTitle ?? 'Break')
            : (item.subject?.name ?? 'Period');

    final isConfirmed = await UiHelpers.showConfirmationDialog(
      context,
      title: AppTranslations.text('delete_period', langCode),
      message:
          langCode == 'ne'
              ? 'के तपाईं "$title (${item.startTime} - ${item.endTime})" पिरियड तालिकाबाट हटाउन चाहनुहुन्छ?'
              : 'Are you sure you want to delete period "$title" (${item.startTime} - ${item.endTime})?',
      confirmText: AppTranslations.text('delete', langCode),
      isDestructive: true,
    );

    if (isConfirmed && mounted) {
      await ref
          .read(timetableControllerProvider.notifier)
          .deletePeriod(item.id);
      if (mounted) {
        UiHelpers.showSnackBar(
          context,
          'Period deleted successfully',
          isSuccess: true,
        );
      }
    }
  }

  void _openPeriodFormDialog(
    BuildContext context, {
    required int academicYearId,
    PeriodWithDetails? period,
    int? classId,
    int? sectionId,
    String? dayOfWeek,
    String? defaultStartTime,
    String? defaultEndTime,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => _PeriodFormDialog(
            academicYearId: academicYearId,
            period: period,
            initialClassId: classId,
            initialSectionId: sectionId,
            initialDayOfWeek: dayOfWeek,
            defaultStartTime: defaultStartTime,
            defaultEndTime: defaultEndTime,
          ),
    );
  }

  void _openWeeklyEditor(
    BuildContext context, {
    required int academicYearId,
    String? academicYearName,
    required int classId,
    int? sectionId,
    required String className,
    String? sectionName,
  }) {
    final langCode = ref.read(localeProvider).locale.languageCode;
    WeeklyTimetableEditorDialog.show(
      context,
      academicYearId: academicYearId,
      academicYearName: academicYearName,
      classId: classId,
      sectionId: sectionId,
      className: className,
      sectionName: sectionName,
      langCode: langCode,
    );
  }
}

/// Modal Dialog for Creating or Editing a Period
class _PeriodFormDialog extends ConsumerStatefulWidget {
  final int academicYearId;
  final PeriodWithDetails? period;
  final int? initialClassId;
  final int? initialSectionId;
  final String? initialDayOfWeek;
  final String? defaultStartTime;
  final String? defaultEndTime;

  const _PeriodFormDialog({
    required this.academicYearId,
    this.period,
    this.initialClassId,
    this.initialSectionId,
    this.initialDayOfWeek,
    this.defaultStartTime,
    this.defaultEndTime,
  });

  @override
  ConsumerState<_PeriodFormDialog> createState() => _PeriodFormDialogState();
}

class _PeriodFormDialogState extends ConsumerState<_PeriodFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late int _classId;
  int? _sectionId;
  late String _dayOfWeek;
  late int _periodNumber;
  late TextEditingController _startTimeController;
  late TextEditingController _endTimeController;
  late TextEditingController _breakTitleController;
  late TextEditingController _roomController;

  bool _isBreak = false;
  int? _subjectId;
  int? _teacherId;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final p = widget.period;

    if (p != null) {
      _classId = p.classId;
      _sectionId = p.sectionId;
      _dayOfWeek = p.dayOfWeek.toLowerCase();
      _periodNumber = p.periodNumber;
      _startTimeController = TextEditingController(text: p.startTime);
      _endTimeController = TextEditingController(text: p.endTime);
      _isBreak = p.isBreak;
      _breakTitleController = TextEditingController(text: p.breakTitle ?? '');
      _subjectId = p.subjectId;
      _teacherId = p.teacherId;
      _roomController = TextEditingController(text: p.roomNumber ?? '');
    } else {
      _classId = widget.initialClassId ?? 1;
      _sectionId = widget.initialSectionId;
      final initialDay = widget.initialDayOfWeek;
      _dayOfWeek =
          initialDay != null
              ? initialDay.toLowerCase()
              : ref.read(selectedTimetableDayProvider);
      _periodNumber = 1;
      _startTimeController = TextEditingController(
        text: widget.defaultStartTime ?? '10:00',
      );
      _endTimeController = TextEditingController(
        text: widget.defaultEndTime ?? '10:45',
      );
      _isBreak = false;
      _breakTitleController = TextEditingController();
      _subjectId = null;
      _teacherId = null;
      _roomController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _startTimeController.dispose();
    _endTimeController.dispose();
    _breakTitleController.dispose();
    _roomController.dispose();
    super.dispose();
  }

  Future<void> _pickTime(
    TextEditingController controller,
    String initialText,
  ) async {
    final parts = initialText.split(':');
    int initialHour = 10;
    int initialMinute = 0;
    if (parts.length == 2) {
      initialHour = int.tryParse(parts[0]) ?? 10;
      initialMinute = int.tryParse(parts[1]) ?? 0;
    }

    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initialHour, minute: initialMinute),
    );

    if (picked != null) {
      final hourStr = picked.hour.toString().padLeft(2, '0');
      final minStr = picked.minute.toString().padLeft(2, '0');
      controller.text = '$hourStr:$minStr';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.period != null;
    final classesAsync = ref.watch(classesWithSectionsStreamProvider);
    final subjectsAsync = ref.watch(subjectsStreamProvider);
    final teachersAsync = ref.watch(teachersStreamProvider);

    final currentLang = ref.watch(localeProvider);
    final langCode = currentLang.locale.languageCode;

    final classes = classesAsync.value ?? [];
    final subjects = subjectsAsync.value ?? [];
    final teachers = teachersAsync.value ?? [];

    // Ensure _classId matches one of the classes
    if (classes.isNotEmpty && !classes.any((c) => c.id == _classId)) {
      _classId = classes.first.id;
    }

    final selectedClass = classes.firstWhere(
      (c) => c.id == _classId,
      orElse: () => classes.first,
    );

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        isEditing
            ? AppTranslations.text('edit_period', langCode)
            : AppTranslations.text('add_period', langCode),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Class & Section Pickers
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: AppSearchableSelect<int>(
                        value: _classId,
                        label: AppTranslations.text('class', langCode),
                        prefixIcon: const Icon(Icons.school_outlined),
                        items:
                            classes.map((c) {
                              return SearchableSelectItem<int>(
                                value: c.id,
                                label:
                                    c.displayName.isNotEmpty
                                        ? c.displayName
                                        : c.name,
                              );
                            }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _classId = val;
                              _sectionId = null;
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 1,
                      child: AppSearchableSelect<int?>(
                        value: _sectionId,
                        label: AppTranslations.text('section', langCode),
                        isClearable: true,
                        hint: langCode == 'ne' ? 'सबै' : 'All',
                        items:
                            selectedClass.sections.map((s) {
                              return SearchableSelectItem<int?>(
                                value: s.id,
                                label: 'Sec ${s.name}',
                              );
                            }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _sectionId = val;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Day of Week & Period Number
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: AppSearchableSelect<String>(
                        value: _dayOfWeek,
                        label: langCode == 'ne' ? 'दिन' : 'Day of Week',
                        prefixIcon: const Icon(Icons.calendar_today_outlined),
                        items:
                            _TimetableScreenState._schoolDays.map((day) {
                              return SearchableSelectItem<String>(
                                value: day,
                                label: AppTranslations.text(
                                  _TimetableScreenState._getDayKey(day),
                                  langCode,
                                ),
                              );
                            }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _dayOfWeek = val;
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 1,
                      child: TextFormField(
                        initialValue: _periodNumber.toString(),
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: AppTranslations.text('period', langCode),
                          hintText: '1, 2...',
                        ),
                        onChanged: (v) {
                          _periodNumber = int.tryParse(v) ?? 1;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Start Time & End Time
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _startTimeController,
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: AppTranslations.text(
                            'start_time',
                            langCode,
                          ),
                          prefixIcon: const Icon(Icons.access_time),
                        ),
                        onTap:
                            () => _pickTime(
                              _startTimeController,
                              _startTimeController.text,
                            ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _endTimeController,
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: AppTranslations.text('end_time', langCode),
                          prefixIcon: const Icon(Icons.access_time_filled),
                        ),
                        onTap:
                            () => _pickTime(
                              _endTimeController,
                              _endTimeController.text,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Break / Recess Switch
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    AppTranslations.text('is_break', langCode),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    langCode == 'ne'
                        ? 'प्रार्थना सभा, खाजा वा विश्राम समय'
                        : 'Recess, lunch, assembly or non-academic interval',
                    style: const TextStyle(fontSize: 12),
                  ),
                  value: _isBreak,
                  onChanged: (val) {
                    setState(() {
                      _isBreak = val;
                      if (_isBreak && _breakTitleController.text.isEmpty) {
                        _breakTitleController.text = 'Lunch & Tiffin Break';
                      }
                    });
                  },
                ),
                const SizedBox(height: 8),

                // Break Title (if break)
                if (_isBreak) ...[
                  TextFormField(
                    controller: _breakTitleController,
                    decoration: InputDecoration(
                      labelText: AppTranslations.text('break_title', langCode),
                      hintText: 'e.g. Lunch & Tiffin Break, Morning Assembly',
                      prefixIcon: const Icon(Icons.coffee_outlined),
                    ),
                    validator: (v) {
                      if (_isBreak && (v == null || v.trim().isEmpty)) {
                        return 'Break title is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 6),
                  // Quick suggestion chips
                  Wrap(
                    spacing: 6,
                    children:
                        [
                          'Lunch & Tiffin Break',
                          'Morning Assembly',
                          'Short Break',
                        ].map((title) {
                          return ActionChip(
                            label: Text(
                              title,
                              style: const TextStyle(fontSize: 11),
                            ),
                            onPressed: () {
                              setState(() {
                                _breakTitleController.text = title;
                              });
                            },
                          );
                        }).toList(),
                  ),
                  const SizedBox(height: 12),
                ] else ...[
                  // Subject Dropdown
                  AppSearchableSelect<int>(
                    value: _subjectId,
                    label: AppTranslations.text('subject', langCode),
                    prefixIcon: const Icon(Icons.menu_book_outlined),
                    items:
                        subjects.map((s) {
                          return SearchableSelectItem<int>(
                            value: s.id,
                            label: '${s.name} (${s.code})',
                          );
                        }).toList(),
                    validator: (v) {
                      if (!_isBreak && v == null) {
                        return 'Please select a subject';
                      }
                      return null;
                    },
                    onChanged: (val) {
                      setState(() {
                        _subjectId = val;
                      });
                    },
                  ),
                  const SizedBox(height: 12),

                  // Teacher Dropdown
                  AppSearchableSelect<int?>(
                    value: _teacherId,
                    label: AppTranslations.text('teacher', langCode),
                    prefixIcon: const Icon(Icons.person_outline),
                    isClearable: true,
                    hint:
                        langCode == 'ne' ? 'तोकिएको छैन' : 'None / Unassigned',
                    items:
                        teachers.map((t) {
                          return SearchableSelectItem<int?>(
                            value: t.id,
                            label:
                                '${t.name}${t.designation.isNotEmpty ? ' (${t.designation})' : ''}',
                          );
                        }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _teacherId = val;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                ],

                // Room Number
                TextFormField(
                  controller: _roomController,
                  decoration: InputDecoration(
                    labelText: AppTranslations.text('room_number', langCode),
                    hintText: 'e.g. Room 101, Science Lab, Ground',
                    prefixIcon: const Icon(Icons.room_outlined),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => context.pop(),
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

    final startTime = _startTimeController.text.trim();
    final endTime = _endTimeController.text.trim();

    setState(() {
      _isSubmitting = true;
    });

    try {
      final controller = ref.read(timetableControllerProvider.notifier);
      final isEditing = widget.period != null;

      if (isEditing) {
        await controller.updatePeriod(
          id: widget.period!.id,
          academicYearId: widget.period!.academicYearId,
          classId: _classId,
          sectionId: _sectionId,
          dayOfWeek: _dayOfWeek,
          periodNumber: _periodNumber,
          startTime: startTime,
          endTime: endTime,
          isBreak: _isBreak,
          breakTitle: _breakTitleController.text.trim(),
          subjectId: _isBreak ? null : _subjectId,
          teacherId: _isBreak ? null : _teacherId,
          roomNumber: _roomController.text.trim(),
        );
      } else {
        await controller.createPeriod(
          academicYearId: widget.academicYearId,
          classId: _classId,
          sectionId: _sectionId,
          dayOfWeek: _dayOfWeek,
          periodNumber: _periodNumber,
          startTime: startTime,
          endTime: endTime,
          isBreak: _isBreak,
          breakTitle: _breakTitleController.text.trim(),
          subjectId: _isBreak ? null : _subjectId,
          teacherId: _isBreak ? null : _teacherId,
          roomNumber: _roomController.text.trim(),
        );
      }

      if (mounted) {
        context.pop();
        UiHelpers.showSnackBar(
          context,
          isEditing
              ? 'Period updated successfully'
              : 'Period created successfully',
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
