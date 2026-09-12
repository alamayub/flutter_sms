import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../config/enums.dart';
import '../../config/extensions.dart';
import '../../config/responsive.dart';
import '../../config/theme.dart';
import '../../config/translations.dart';
import '../../data/app_database.dart';
import '../../providers/academic_year_provider.dart';
import '../../providers/class_section_provider.dart';
import '../../providers/exam_provider.dart';
import '../../providers/exam_result_provider.dart';
import '../../providers/locale_provider.dart';
import '../../services/exam_result_service.dart';
import '../../utils/exam_grading_utils.dart';
import '../../widgets/app_input.dart';

enum _ResultViewMode { subjectEntry, studentMarksheet, tabulationLedger }

class ExamResultsScreen extends ConsumerStatefulWidget {
  const ExamResultsScreen({super.key});

  @override
  ConsumerState<ExamResultsScreen> createState() => _ExamResultsScreenState();
}

class _ExamResultsScreenState extends ConsumerState<ExamResultsScreen> {
  _ResultViewMode _viewMode = _ResultViewMode.subjectEntry;
  final TextEditingController _searchController = TextEditingController();

  // Local state for Subject Batch Entry
  final Map<int, TextEditingController> _theoryControllers = {};
  final Map<int, TextEditingController> _practicalControllers = {};
  final Map<int, TextEditingController> _remarksControllers = {};
  final Map<int, bool> _absentMap = {};
  bool _isSavingSubjectBatch = false;

  // Local state for Student Marksheet Entry
  final Map<int, TextEditingController> _studentTheoryControllers = {};
  final Map<int, TextEditingController> _studentPracticalControllers = {};
  final Map<int, TextEditingController> _studentRemarksControllers = {};
  final Map<int, bool> _studentAbsentMap = {};
  bool _isSavingStudentMarksheet = false;

  @override
  void dispose() {
    _searchController.dispose();
    _disposeControllers(_theoryControllers);
    _disposeControllers(_practicalControllers);
    _disposeControllers(_remarksControllers);
    _disposeControllers(_studentTheoryControllers);
    _disposeControllers(_studentPracticalControllers);
    _disposeControllers(_studentRemarksControllers);
    super.dispose();
  }

  void _disposeControllers(Map<int, TextEditingController> map) {
    for (final c in map.values) {
      c.dispose();
    }
    map.clear();
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeProvider).locale.languageCode;
    final examsAsync = ref.watch(examsStreamProvider);
    final classesAsync = ref.watch(classesWithSectionsStreamProvider);
    final academicYearsAsync = ref.watch(academicYearsStreamProvider);

    final selectedExamId = ref.watch(selectedResultExamIdProvider);
    final selectedClassId = ref.watch(selectedResultClassIdProvider);
    final selectedSectionId = ref.watch(selectedResultSectionIdProvider);
    final selectedSubjectId = ref.watch(selectedResultSubjectIdProvider);
    final selectedStudentId = ref.watch(selectedResultStudentIdProvider);
    final searchQuery = ref.watch(selectedResultSearchProvider);

    // Auto-select first exam and class if not yet set
    examsAsync.whenData((exams) {
      if (selectedExamId == null && exams.isNotEmpty) {
        Future.microtask(() {
          ref
              .read(selectedResultExamIdProvider.notifier)
              .setExam(exams.first.id);
        });
      }
    });

    classesAsync.whenData((classes) {
      if (selectedClassId == null && classes.isNotEmpty) {
        Future.microtask(() {
          ref
              .read(selectedResultClassIdProvider.notifier)
              .setClass(classes.first.id);
        });
      }
    });

    final currentAcademicYearId =
        academicYearsAsync.value
            ?.firstWhere(
              (y) => y.isCurrent,
              orElse: () => academicYearsAsync.value!.first,
            )
            .id;

    final summariesAsync = ref.watch(examSummariesStreamProvider);

    return Scaffold(
      body: ResponsiveScaffoldWrapper(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Header & View Mode Switcher
              _buildHeader(context, lang),
              const SizedBox(height: 16),

              // 2. Metric Cards
              _buildMetrics(summariesAsync, lang),
              const SizedBox(height: 16),

              // 3. Centralized Filter Bar
              _buildFilterBar(
                context,
                examsAsync,
                classesAsync,
                selectedExamId,
                selectedClassId,
                selectedSectionId,
                selectedSubjectId,
                selectedStudentId,
              ),
              const SizedBox(height: 20),

              // 4. Main Dynamic View Content
              if (selectedExamId == null || selectedClassId == null)
                _buildEmptyState('Please select an Exam and Class to proceed.')
              else
                switch (_viewMode) {
                  _ResultViewMode.subjectEntry => _buildSubjectMarksEntryView(
                    context,
                    selectedExamId,
                    selectedClassId,
                    selectedSectionId,
                    selectedSubjectId,
                    currentAcademicYearId ?? 1,
                    searchQuery,
                  ),
                  _ResultViewMode.studentMarksheet =>
                    _buildStudentMarksheetView(
                      context,
                      selectedExamId,
                      selectedClassId,
                      selectedSectionId,
                      selectedStudentId,
                      currentAcademicYearId ?? 1,
                    ),
                  _ResultViewMode.tabulationLedger =>
                    _buildTabulationLedgerView(
                      context,
                      selectedExamId,
                      selectedClassId,
                      selectedSectionId,
                      currentAcademicYearId ?? 1,
                      searchQuery,
                    ),
                },
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 1. Header & Segmented Switcher
  // ===========================================================================
  Widget _buildHeader(BuildContext context, String lang) {
    final theme = Theme.of(context);
    final isCompact = MediaQuery.of(context).size.width < 750;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppTranslations.text('exam_results', lang),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Enter marks, calculate grades & GPA, and generate tabulation ledgers',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),
        // Segmented buttons
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<_ResultViewMode>(
            segments: [
              ButtonSegment(
                value: _ResultViewMode.subjectEntry,
                icon: const Icon(Icons.edit_note_outlined, size: 18),
                label: Text(
                  isCompact
                      ? 'Subject'
                      : AppTranslations.text('subject_marks_entry', lang),
                ),
              ),
              ButtonSegment(
                value: _ResultViewMode.studentMarksheet,
                icon: const Icon(Icons.person_outline, size: 18),
                label: Text(
                  isCompact
                      ? 'Student'
                      : AppTranslations.text('student_marksheet', lang),
                ),
              ),
              ButtonSegment(
                value: _ResultViewMode.tabulationLedger,
                icon: const Icon(Icons.table_chart_outlined, size: 18),
                label: Text(
                  isCompact
                      ? 'Ledger'
                      : AppTranslations.text('tabulation_ledger', lang),
                ),
              ),
            ],
            selected: {_viewMode},
            onSelectionChanged: (set) {
              setState(() {
                _viewMode = set.first;
              });
            },
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // 2. Metrics Bar
  // ===========================================================================
  Widget _buildMetrics(
    AsyncValue<List<StudentExamSummaryWithDetails>> summariesAsync,
    String lang,
  ) {
    final summaries = summariesAsync.value ?? [];

    final totalEvaluated = summaries.length;
    final passedCount = summaries.where((s) => s.isPassed).length;
    final failedCount = totalEvaluated - passedCount;

    double avgGpa = 0.0;
    if (summaries.isNotEmpty) {
      final sumGpa = summaries.fold<double>(
        0.0,
        (acc, s) => acc + s.overallGpa,
      );
      avgGpa = sumGpa / summaries.length;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWrap = constraints.maxWidth < 650;
        final cards = [
          _MetricCard(
            title: 'Evaluated Students',
            value: '$totalEvaluated',
            icon: Icons.people_alt_outlined,
            color: AppTheme.primaryColor,
          ),
          _MetricCard(
            title: 'Passed (All Subjects)',
            value: '$passedCount',
            icon: Icons.check_circle_outline,
            color: Colors.green,
          ),
          _MetricCard(
            title: 'Failed / Needs Remedial',
            value: '$failedCount',
            icon: Icons.cancel_outlined,
            color: Colors.red,
          ),
          _MetricCard(
            title: 'Class Average GPA',
            value: avgGpa.toStringAsFixed(2),
            icon: Icons.stars_outlined,
            color: Colors.teal,
          ),
        ];

        if (isWrap) {
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children:
                cards
                    .map(
                      (c) => SizedBox(
                        width: (constraints.maxWidth - 12) / 2,
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
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: c,
                      ),
                    ),
                  )
                  .toList(),
        );
      },
    );
  }

  // ===========================================================================
  // 3. Centralized Filter Bar
  // ===========================================================================
  Widget _buildFilterBar(
    BuildContext context,
    AsyncValue<List<ExamWithDetails>> examsAsync,
    AsyncValue<List<ClassWithSections>> classesAsync,
    int? selectedExamId,
    int? selectedClassId,
    int? selectedSectionId,
    int? selectedSubjectId,
    int? selectedStudentId,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(
          color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // 1. Exam Selector
            SizedBox(
              width: 220,
              child: examsAsync.when(
                data:
                    (exams) => AppSearchableSelect<int?>.filter(
                      items:
                          exams
                              .map(
                                (e) => SearchableSelectItem<int?>(
                                  value: e.id,
                                  label: e.name,
                                ),
                              )
                              .toList(),
                      value: selectedExamId,
                      hint: 'Select Exam',
                      prefixIcon: const Icon(
                        Icons.assignment_outlined,
                        size: 16,
                      ),
                      onChanged: (val) {
                        ref
                            .read(selectedResultExamIdProvider.notifier)
                            .setExam(val);
                      },
                    ),
                loading: () => const LinearProgressIndicator(),
                error: (_, _) => const Text('Error loading exams'),
              ),
            ),

            // 2. Class Selector
            SizedBox(
              width: 170,
              child: classesAsync.when(
                data:
                    (classes) => AppSearchableSelect<int?>.filter(
                      items:
                          classes
                              .map(
                                (c) => SearchableSelectItem<int?>(
                                  value: c.id,
                                  label:
                                      c.displayName.isNotEmpty
                                          ? c.displayName
                                          : c.name,
                                ),
                              )
                              .toList(),
                      value: selectedClassId,
                      hint: 'Select Class',
                      prefixIcon: const Icon(Icons.school_outlined, size: 16),
                      onChanged: (val) {
                        ref
                            .read(selectedResultClassIdProvider.notifier)
                            .setClass(val);
                        ref
                            .read(selectedResultSectionIdProvider.notifier)
                            .setSection(null);
                        ref
                            .read(selectedResultSubjectIdProvider.notifier)
                            .setSubject(null);
                      },
                    ),
                loading: () => const LinearProgressIndicator(),
                error: (_, _) => const Text('Error loading classes'),
              ),
            ),

            // 3. Section Selector
            if (selectedClassId != null)
              SizedBox(
                width: 150,
                child: classesAsync.when(
                  data: (classes) {
                    final cls =
                        classes
                            .where((c) => c.id == selectedClassId)
                            .firstOrNull;
                    final sections = cls?.sections ?? [];
                    return AppSearchableSelect<int?>.filter(
                      items: [
                        const SearchableSelectItem<int?>(
                          value: null,
                          label: 'All Sections',
                        ),
                        ...sections.map(
                          (s) => SearchableSelectItem<int?>(
                            value: s.id,
                            label: 'Section ${s.name}',
                          ),
                        ),
                      ],
                      value: selectedSectionId,
                      hint: 'Section',
                      prefixIcon: const Icon(Icons.group_outlined, size: 16),
                      onChanged: (val) {
                        ref
                            .read(selectedResultSectionIdProvider.notifier)
                            .setSection(val);
                      },
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                ),
              ),

            // 4. Search Filter Input
            SizedBox(
              width: 180,
              child: AppSearchField(
                controller: _searchController,
                hintText: 'Search student...',
                onChanged: (val) {
                  ref
                      .read(selectedResultSearchProvider.notifier)
                      .setSearch(val.trim());
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // 4. Mode 1: Subject Marks Entry View (Bulk Students)
  // ===========================================================================
  Widget _buildSubjectMarksEntryView(
    BuildContext context,
    int examId,
    int classId,
    int? sectionId,
    int? selectedSubjectId,
    int academicYearId,
    String searchQuery,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Fetch subjects for this class
    return FutureBuilder<List<Subject>>(
      future: ref
          .read(examServiceProvider)
          .getSubjectsForClass(
            classId: classId,
            academicYearId: academicYearId,
          ),
      builder: (context, subjectsSnap) {
        if (subjectsSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final subjects = subjectsSnap.data ?? [];
        if (subjects.isEmpty) {
          return _buildEmptyState('No subjects found for this class.');
        }

        // Auto-select first subject if not selected
        final currentSubjectId = selectedSubjectId ?? subjects.first.id;
        final selectedSubject = subjects.firstWhere(
          (s) => s.id == currentSubjectId,
          orElse: () => subjects.first,
        );

        return FutureBuilder<SubjectExamMarksConfig?>(
          future: ref
              .read(examResultServiceProvider)
              .getSubjectMarksConfig(
                examId: examId,
                classId: classId,
                subjectId: selectedSubject.id,
              ),
          builder: (context, configSnap) {
            final config = configSnap.data;
            if (config == null) {
              return const Center(child: CircularProgressIndicator());
            }

            final hasPractical = config.subjectType != SubjectType.theory;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Subject selection tabs
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children:
                        subjects.map((sub) {
                          final isSelected = sub.id == currentSubjectId;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: ChoiceChip(
                              selected: isSelected,
                              label: Text(sub.name),
                              avatar: Icon(
                                sub.subjectType == SubjectType.theory
                                    ? Icons.menu_book_outlined
                                    : (sub.subjectType == SubjectType.practical
                                        ? Icons.science_outlined
                                        : Icons.auto_stories_outlined),
                                size: 16,
                              ),
                              onSelected: (selected) {
                                if (selected) {
                                  ref
                                      .read(
                                        selectedResultSubjectIdProvider
                                            .notifier,
                                      )
                                      .setSubject(sub.id);
                                }
                              },
                            ),
                          );
                        }).toList(),
                  ),
                ),
                const SizedBox(height: 12),

                // Subject details & Quick toolbar card
                Card(
                  elevation: 0.5,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    side: BorderSide(
                      color:
                          isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Wrap(
                          spacing: 12,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              '${config.subjectName} (${config.subjectCode})',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Chip(
                              label: Text(
                                config.subjectType.displayName,
                                style: const TextStyle(fontSize: 11),
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                            Text(
                              'Theory: ${config.theoryFullMarks.toInt()} / Pass: ${config.theoryPassMarks.toInt()}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            if (hasPractical)
                              Text(
                                'Practical: ${config.practicalFullMarks?.toInt()} / Pass: ${config.practicalPassMarks?.toInt()}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            Text(
                              'Total: ${config.totalFullMarks.toInt()}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ],
                        ),
                        // Quick Bulk Actions
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                          ),
                          onPressed:
                              _isSavingSubjectBatch
                                  ? null
                                  : () => _openSubjectMarksPreview(
                                    examId: examId,
                                    academicYearId: academicYearId,
                                    classId: classId,
                                    sectionId: sectionId,
                                    config: config,
                                  ),
                          icon:
                              _isSavingSubjectBatch
                                  ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                  : const Icon(
                                    Icons.preview_outlined,
                                    size: 18,
                                  ),
                          label: const Text('Preview & Save Marks'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Students Marks Entry Table
                Consumer(
                  builder: (context, ref, child) {
                    final studentsAsync = ref.watch(
                      enrolledStudentsForExamProvider((
                        classId: classId,
                        sectionId: sectionId,
                        academicYearId: academicYearId,
                      )),
                    );

                    final existingResultsAsync = ref.watch(
                      examResultsStreamProvider,
                    );

                    return studentsAsync.when(
                      data: (students) {
                        if (students.isEmpty) {
                          return _buildEmptyState(
                            'No students enrolled in this class/section.',
                          );
                        }

                        // Filter by search
                        final filteredStudents =
                            searchQuery.isEmpty
                                ? students
                                : students.where((s) {
                                  final q = searchQuery.toLowerCase();
                                  return s.name.toLowerCase().contains(q) ||
                                      (s.rollNumber?.toString() ?? '')
                                          .toLowerCase()
                                          .contains(q) ||
                                      s.studentId.toLowerCase().contains(q);
                                }).toList();

                        // Initialize controllers from existing results
                        final existingResults =
                            existingResultsAsync.value ?? [];
                        for (final s in students) {
                          final match =
                              existingResults
                                  .where(
                                    (r) =>
                                        r.studentId == s.id &&
                                        r.subjectId == config.subjectId,
                                  )
                                  .firstOrNull;

                          if (!_theoryControllers.containsKey(s.id)) {
                            _theoryControllers[s.id] = TextEditingController(
                              text:
                                  match != null
                                      ? match.theoryMarksObtained.toString()
                                      : '',
                            );
                            _practicalControllers[s.id] = TextEditingController(
                              text:
                                  match?.practicalMarksObtained != null
                                      ? match!.practicalMarksObtained.toString()
                                      : '',
                            );
                            _remarksControllers[s.id] = TextEditingController(
                              text: match?.remarks ?? '',
                            );
                            _absentMap[s.id] = match?.isAbsent ?? false;
                          }
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Card(
                              elevation: 0.5,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.lg,
                                ),
                                side: BorderSide(
                                  color:
                                      isDark
                                          ? AppTheme.darkBorder
                                          : AppTheme.lightBorder,
                                ),
                              ),
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  headingRowHeight: 44,
                                  dataRowMinHeight: 52,
                                  dataRowMaxHeight: 56,
                                  columns: [
                                    const DataColumn(label: Text('Roll')),
                                    const DataColumn(label: Text('Student')),
                                    const DataColumn(label: Text('Absent')),
                                    DataColumn(
                                      label: Text(
                                        'Theory (${config.theoryFullMarks.toInt()})',
                                      ),
                                    ),
                                    if (hasPractical)
                                      DataColumn(
                                        label: Text(
                                          'Practical (${config.practicalFullMarks?.toInt()})',
                                        ),
                                      ),
                                    const DataColumn(label: Text('Total')),
                                    const DataColumn(label: Text('Percentage')),
                                    const DataColumn(label: Text('GPA')),
                                    const DataColumn(label: Text('Grade')),
                                    const DataColumn(label: Text('Status')),
                                    const DataColumn(label: Text('Remarks')),
                                  ],
                                  rows:
                                      filteredStudents.map((student) {
                                        final isAbsent =
                                            _absentMap[student.id] ?? false;
                                        final theoryText =
                                            _theoryControllers[student.id]
                                                ?.text ??
                                            '0';
                                        final practicalText =
                                            _practicalControllers[student.id]
                                                ?.text ??
                                            '0';

                                        final theoryVal =
                                            double.tryParse(theoryText) ?? 0.0;
                                        final practicalVal =
                                            hasPractical
                                                ? (double.tryParse(
                                                      practicalText,
                                                    ) ??
                                                    0.0)
                                                : null;

                                        final calc =
                                            ExamGradingUtils.calculateSubjectResult(
                                              theoryMarksObtained: theoryVal,
                                              theoryFullMarks:
                                                  config.theoryFullMarks,
                                              theoryPassMarks:
                                                  config.theoryPassMarks,
                                              practicalMarksObtained:
                                                  practicalVal,
                                              practicalFullMarks:
                                                  config.practicalFullMarks,
                                              practicalPassMarks:
                                                  config.practicalPassMarks,
                                              isAbsent: isAbsent,
                                            );

                                        return DataRow(
                                          cells: [
                                            DataCell(
                                              Text(
                                                student.rollNumber
                                                        ?.toString() ??
                                                    '-',
                                              ),
                                            ),
                                            DataCell(
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  CircleAvatar(
                                                    radius: 14,
                                                    backgroundColor: AppTheme
                                                        .primaryColor
                                                        .withValues(
                                                          alpha: 0.12,
                                                        ),
                                                    child: Text(
                                                      student.name.isNotEmpty
                                                          ? student.name[0]
                                                          : 'S',
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Text(
                                                        student.name,
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          fontSize: 13,
                                                        ),
                                                      ),
                                                      Text(
                                                        student.admissionNumber,
                                                        style: const TextStyle(
                                                          fontSize: 11,
                                                          color: Colors.grey,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            DataCell(
                                              Checkbox(
                                                value: isAbsent,
                                                onChanged: (val) {
                                                  setState(() {
                                                    _absentMap[student.id] =
                                                        val ?? false;
                                                  });
                                                },
                                              ),
                                            ),
                                            DataCell(
                                              SizedBox(
                                                width: 80,
                                                child: TextFormField(
                                                  controller:
                                                      _theoryControllers[student
                                                          .id],
                                                  keyboardType:
                                                      TextInputType.number,
                                                  enabled: !isAbsent,
                                                  decoration: InputDecoration(
                                                    isDense: true,
                                                    hintText: '0',
                                                    contentPadding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 8,
                                                        ),
                                                    border: OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            AppRadius.sm,
                                                          ),
                                                    ),
                                                  ),
                                                  onChanged: (val) {
                                                    setState(() {});
                                                  },
                                                ),
                                              ),
                                            ),
                                            if (hasPractical)
                                              DataCell(
                                                SizedBox(
                                                  width: 80,
                                                  child: TextFormField(
                                                    controller:
                                                        _practicalControllers[student
                                                            .id],
                                                    keyboardType:
                                                        TextInputType.number,
                                                    enabled: !isAbsent,
                                                    decoration: InputDecoration(
                                                      isDense: true,
                                                      hintText: '0',
                                                      contentPadding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 8,
                                                            vertical: 8,
                                                          ),
                                                      border: OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              AppRadius.sm,
                                                            ),
                                                      ),
                                                    ),
                                                    onChanged: (val) {
                                                      setState(() {});
                                                    },
                                                  ),
                                                ),
                                              ),
                                            DataCell(
                                              Text(
                                                isAbsent
                                                    ? '0.0'
                                                    : calc.totalMarksObtained
                                                        .toStringAsFixed(1),
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            DataCell(
                                              Text(
                                                isAbsent
                                                    ? '0.0%'
                                                    : '${calc.percentage.toStringAsFixed(1)}%',
                                              ),
                                            ),
                                            DataCell(
                                              Text(
                                                isAbsent
                                                    ? '0.00'
                                                    : calc.gradePoint
                                                        .toStringAsFixed(2),
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color:
                                                      isAbsent
                                                          ? Colors.grey
                                                          : calc.color,
                                                ),
                                              ),
                                            ),
                                            DataCell(
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: (isAbsent
                                                          ? Colors.grey
                                                          : calc.color)
                                                      .withValues(alpha: 0.12),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  isAbsent
                                                      ? 'AB'
                                                      : calc.letterGrade,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 11,
                                                    color:
                                                        isAbsent
                                                            ? Colors.grey
                                                            : calc.color,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            DataCell(
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: (isAbsent
                                                          ? Colors.grey
                                                          : (calc.isPassed
                                                              ? Colors.green
                                                              : Colors.red))
                                                      .withValues(alpha: 0.12),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  isAbsent
                                                      ? 'ABSENT'
                                                      : (calc.isPassed
                                                          ? 'PASS'
                                                          : 'FAIL'),
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 10,
                                                    color:
                                                        isAbsent
                                                            ? Colors.grey
                                                            : (calc.isPassed
                                                                ? Colors.green
                                                                : Colors.red),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            DataCell(
                                              SizedBox(
                                                width: 110,
                                                child: TextFormField(
                                                  controller:
                                                      _remarksControllers[student
                                                          .id],
                                                  decoration: InputDecoration(
                                                    isDense: true,
                                                    hintText: 'Note',
                                                    contentPadding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                          vertical: 6,
                                                        ),
                                                    border: OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            AppRadius.sm,
                                                          ),
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
                            ),
                            const SizedBox(height: 10),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Showing ${filteredStudents.length} of ${students.length} students',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: Colors.grey,
                                    ),
                                  ),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryColor,
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed:
                                        _isSavingSubjectBatch
                                            ? null
                                            : () => _openSubjectMarksPreview(
                                              examId: examId,
                                              academicYearId: academicYearId,
                                              classId: classId,
                                              sectionId: sectionId,
                                              config: config,
                                              studentList: students,
                                            ),
                                    icon:
                                        _isSavingSubjectBatch
                                            ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                            : const Icon(
                                              Icons.preview_outlined,
                                              size: 18,
                                            ),
                                    label: const Text('Preview & Save Marks'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                      loading:
                          () =>
                              const Center(child: CircularProgressIndicator()),
                      error: (err, _) => Text('Error loading students: $err'),
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _openSubjectMarksPreview({
    required int examId,
    required int academicYearId,
    required int classId,
    required int? sectionId,
    required SubjectExamMarksConfig config,
    List<Student>? studentList,
  }) async {
    List<Student> students = studentList ?? [];
    if (students.isEmpty) {
      final studentsAsync = ref.read(
        enrolledStudentsForExamProvider((
          classId: classId,
          sectionId: sectionId,
          academicYearId: academicYearId,
        )),
      );
      students = studentsAsync.asData?.value ?? [];
    }

    if (students.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No students found to save marks for.')),
      );
      return;
    }

    final hasPractical = config.subjectType != SubjectType.theory;
    final items = <_SubjectMarksPreviewItem>[];

    for (final student in students) {
      final isAbsent = _absentMap[student.id] ?? false;
      final tText = _theoryControllers[student.id]?.text.trim() ?? '';
      final pText = _practicalControllers[student.id]?.text.trim() ?? '';
      final tVal = double.tryParse(tText) ?? 0.0;
      final pVal = hasPractical ? (double.tryParse(pText) ?? 0.0) : null;
      final rem = _remarksControllers[student.id]?.text.trim();

      String? valError;
      if (!isAbsent) {
        if (tVal < 0) {
          valError = 'Theory marks cannot be negative';
        } else if (tVal > config.theoryFullMarks) {
          valError =
              'Theory marks ($tVal) exceeds full marks (${config.theoryFullMarks.toInt()})';
        } else if (hasPractical && pVal != null) {
          if (pVal < 0) {
            valError = 'Practical marks cannot be negative';
          } else if (pVal > (config.practicalFullMarks ?? 0)) {
            valError =
                'Practical marks ($pVal) exceeds full marks (${config.practicalFullMarks?.toInt() ?? 0})';
          }
        }
      }

      final calc = ExamGradingUtils.calculateSubjectResult(
        theoryMarksObtained: isAbsent ? 0 : tVal,
        theoryFullMarks: config.theoryFullMarks,
        theoryPassMarks: config.theoryPassMarks,
        practicalMarksObtained: (hasPractical && !isAbsent) ? pVal : null,
        practicalFullMarks: config.practicalFullMarks,
        practicalPassMarks: config.practicalPassMarks,
        isAbsent: isAbsent,
      );

      items.add(
        _SubjectMarksPreviewItem(
          student: student,
          isAbsent: isAbsent,
          theoryMarks: tVal,
          practicalMarks: pVal,
          remarks: rem,
          result: calc,
          validationError: valError,
        ),
      );
    }

    final exams = ref.read(examsStreamProvider).asData?.value ?? [];
    final exam = exams.where((e) => e.id == examId).firstOrNull;
    final classes =
        ref.read(classesWithSectionsStreamProvider).asData?.value ?? [];
    final cls = classes.where((c) => c.id == classId).firstOrNull;
    final sectionName =
        sectionId != null
            ? cls?.sections.where((s) => s.id == sectionId).firstOrNull?.name
            : null;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => _SubjectMarksPreviewDialog(
            examName: exam?.name ?? 'Exam #$examId',
            className: cls?.name ?? 'Class #$classId',
            sectionName: sectionName,
            config: config,
            items: items,
          ),
    );

    if (confirmed == true && mounted) {
      await _executeSaveSubjectMarksBatch(
        examId: examId,
        academicYearId: academicYearId,
        classId: classId,
        sectionId: sectionId,
        config: config,
        items: items,
      );
    }
  }

  Future<void> _executeSaveSubjectMarksBatch({
    required int examId,
    required int academicYearId,
    required int classId,
    required int? sectionId,
    required SubjectExamMarksConfig config,
    required List<_SubjectMarksPreviewItem> items,
  }) async {
    setState(() => _isSavingSubjectBatch = true);

    try {
      final entries =
          items.map((item) {
            return SubjectMarksEntryInput(
              studentId: item.student.id,
              theoryMarks: item.theoryMarks,
              practicalMarks: item.practicalMarks,
              isAbsent: item.isAbsent,
              remarks: item.remarks,
            );
          }).toList();

      final success = await ref
          .read(examResultControllerProvider.notifier)
          .saveSubjectMarksBatch(
            examId: examId,
            academicYearId: academicYearId,
            classId: classId,
            sectionId: sectionId,
            subjectId: config.subjectId,
            examScheduleId: config.examScheduleId,
            theoryFullMarks: config.theoryFullMarks,
            theoryPassMarks: config.theoryPassMarks,
            practicalFullMarks: config.practicalFullMarks,
            practicalPassMarks: config.practicalPassMarks,
            entries: entries,
          );

      if (mounted) {
        setState(() => _isSavingSubjectBatch = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Marks for "${config.subjectName}" saved & ledger updated successfully!'
                  : 'Failed to save marks',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSavingSubjectBatch = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving marks: $e')));
      }
    }
  }

  // ===========================================================================
  // 5. Mode 2: Student Marksheet Entry View
  // ===========================================================================
  Widget _buildStudentMarksheetView(
    BuildContext context,
    int examId,
    int classId,
    int? sectionId,
    int? selectedStudentId,
    int academicYearId,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final studentsAsync = ref.watch(
      enrolledStudentsForExamProvider((
        classId: classId,
        sectionId: sectionId,
        academicYearId: academicYearId,
      )),
    );

    return studentsAsync.when(
      data: (students) {
        if (students.isEmpty) {
          return _buildEmptyState('No students found in this class/section.');
        }

        final currentStudentId = selectedStudentId ?? students.first.id;
        final selectedStudent = students.firstWhere(
          (s) => s.id == currentStudentId,
          orElse: () => students.first,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Student Selection Row
            Row(
              children: [
                Expanded(
                  child: AppSearchableSelect<int?>.filter(
                    items:
                        students
                            .map(
                              (s) => SearchableSelectItem<int?>(
                                value: s.id,
                                label:
                                    '${s.rollNumber?.toString() ?? '-'} • ${s.name} (${s.studentId})',
                              ),
                            )
                            .toList(),
                    value: currentStudentId,
                    hint: 'Choose Student for Marksheet Entry',
                    prefixIcon: const Icon(Icons.person_outline, size: 18),
                    onChanged: (val) {
                      if (val != null) {
                        ref
                            .read(selectedResultStudentIdProvider.notifier)
                            .setStudent(val);
                        _disposeControllers(_studentTheoryControllers);
                        _disposeControllers(_studentPracticalControllers);
                        _disposeControllers(_studentRemarksControllers);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Subject entries for this student
            FutureBuilder<List<Subject>>(
              future: ref
                  .read(examServiceProvider)
                  .getSubjectsForClass(
                    classId: classId,
                    academicYearId: academicYearId,
                  ),
              builder: (context, subjectsSnap) {
                if (subjectsSnap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final subjects = subjectsSnap.data ?? [];
                if (subjects.isEmpty) {
                  return _buildEmptyState('No subjects found for this class.');
                }

                return FutureBuilder<List<ExamResultWithDetails>>(
                  future: ref
                      .read(examResultServiceProvider)
                      .getExamResults(
                        examId: examId,
                        studentId: selectedStudent.id,
                      ),
                  builder: (context, resultsSnap) {
                    final existingResults = resultsSnap.data ?? [];

                    // Setup controllers for this student's subjects
                    for (final sub in subjects) {
                      final match =
                          existingResults
                              .where((r) => r.subjectId == sub.id)
                              .firstOrNull;

                      if (!_studentTheoryControllers.containsKey(sub.id)) {
                        _studentTheoryControllers[sub
                            .id] = TextEditingController(
                          text:
                              match != null
                                  ? match.theoryMarksObtained.toString()
                                  : '',
                        );
                        _studentPracticalControllers[sub
                            .id] = TextEditingController(
                          text:
                              match?.practicalMarksObtained != null
                                  ? match!.practicalMarksObtained.toString()
                                  : '',
                        );
                        _studentRemarksControllers[sub.id] =
                            TextEditingController(text: match?.remarks ?? '');
                        _studentAbsentMap[sub.id] = match?.isAbsent ?? false;
                      }
                    }

                    // Compute live totals across all subjects
                    final subjectResultsList = <SubjectGradeResult>[];
                    for (final sub in subjects) {
                      final hasPractical =
                          sub.subjectType != SubjectType.theory;
                      final theoryFull =
                          (hasPractical
                                  ? (sub.theoryMarks ?? 75)
                                  : sub.fullMarks)
                              .toDouble();
                      final theoryPass =
                          (hasPractical
                                  ? (sub.theoryMarks != null
                                      ? (sub.theoryMarks! * 0.4).round()
                                      : 30)
                                  : sub.passMarks)
                              .toDouble();
                      final practicalFull =
                          hasPractical
                              ? (sub.practicalMarks ?? 25).toDouble()
                              : null;
                      final practicalPass =
                          hasPractical
                              ? (practicalFull! * 0.4).toDouble()
                              : null;

                      final isAbsent = _studentAbsentMap[sub.id] ?? false;
                      final tVal =
                          double.tryParse(
                            _studentTheoryControllers[sub.id]?.text ?? '0',
                          ) ??
                          0.0;
                      final pVal =
                          hasPractical
                              ? (double.tryParse(
                                    _studentPracticalControllers[sub.id]
                                            ?.text ??
                                        '0',
                                  ) ??
                                  0.0)
                              : null;

                      subjectResultsList.add(
                        ExamGradingUtils.calculateSubjectResult(
                          theoryMarksObtained: tVal,
                          theoryFullMarks: theoryFull,
                          theoryPassMarks: theoryPass,
                          practicalMarksObtained: pVal,
                          practicalFullMarks: practicalFull,
                          practicalPassMarks: practicalPass,
                          isAbsent: isAbsent,
                        ),
                      );
                    }

                    final overall = ExamGradingUtils.calculateOverallResult(
                      subjectResultsList,
                    );

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Live Performance Banner
                        Card(
                          elevation: 1,
                          color: isDark ? AppTheme.darkSurface : Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            side: BorderSide(
                              color:
                                  overall.isPassed
                                      ? Colors.green.withValues(alpha: 0.3)
                                      : Colors.red.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 26,
                                  backgroundColor: overall.color.withValues(
                                    alpha: 0.14,
                                  ),
                                  child: Text(
                                    overall.letterGrade,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: overall.color,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Overall Performance: ${overall.description}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: overall.color,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Total Marks: ${overall.totalMarksObtained.toStringAsFixed(1)} / ${overall.totalFullMarks.toInt()} • Percentage: ${overall.percentage.toStringAsFixed(1)}% • GPA: ${overall.gpa.toStringAsFixed(2)}',
                                        style: theme.textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryColor,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed:
                                      _isSavingStudentMarksheet
                                          ? null
                                          : () => _openStudentMarksheetPreview(
                                            examId: examId,
                                            academicYearId: academicYearId,
                                            classId: classId,
                                            sectionId: sectionId,
                                            student: selectedStudent,
                                            subjects: subjects,
                                          ),
                                  icon:
                                      _isSavingStudentMarksheet
                                          ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                          : const Icon(
                                            Icons.preview_outlined,
                                            size: 18,
                                          ),
                                  label: const Text('Preview & Save Marksheet'),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Subject Entries Card
                        Card(
                          elevation: 0.5,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            side: BorderSide(
                              color:
                                  isDark
                                      ? AppTheme.darkBorder
                                      : AppTheme.lightBorder,
                            ),
                          ),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              headingRowHeight: 44,
                              columns: const [
                                DataColumn(label: Text('Subject')),
                                DataColumn(label: Text('Type')),
                                DataColumn(label: Text('Absent')),
                                DataColumn(label: Text('Theory Marks')),
                                DataColumn(label: Text('Practical Marks')),
                                DataColumn(label: Text('Total')),
                                DataColumn(label: Text('Percentage')),
                                DataColumn(label: Text('GPA')),
                                DataColumn(label: Text('Grade')),
                                DataColumn(label: Text('Status')),
                                DataColumn(label: Text('Remarks')),
                              ],
                              rows: List.generate(subjects.length, (index) {
                                final sub = subjects[index];
                                final res = subjectResultsList[index];
                                final hasPractical =
                                    sub.subjectType != SubjectType.theory;
                                final isAbsent =
                                    _studentAbsentMap[sub.id] ?? false;

                                return DataRow(
                                  cells: [
                                    DataCell(
                                      Text(
                                        sub.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Chip(
                                        label: Text(
                                          sub.subjectType.displayName,
                                          style: const TextStyle(fontSize: 10),
                                        ),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ),
                                    DataCell(
                                      Checkbox(
                                        value: isAbsent,
                                        onChanged: (val) {
                                          setState(() {
                                            _studentAbsentMap[sub.id] =
                                                val ?? false;
                                          });
                                        },
                                      ),
                                    ),
                                    DataCell(
                                      SizedBox(
                                        width: 80,
                                        child: TextFormField(
                                          controller:
                                              _studentTheoryControllers[sub.id],
                                          enabled: !isAbsent,
                                          keyboardType:
                                              const TextInputType.numberWithOptions(
                                                decimal: true,
                                              ),
                                          decoration: InputDecoration(
                                            isDense: true,
                                            hintText:
                                                'Max ${res.theoryFullMarks.toInt()}',
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 8,
                                                ),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    AppRadius.sm,
                                                  ),
                                            ),
                                          ),
                                          onChanged: (_) => setState(() {}),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      hasPractical
                                          ? SizedBox(
                                            width: 80,
                                            child: TextFormField(
                                              controller:
                                                  _studentPracticalControllers[sub
                                                      .id],
                                              enabled: !isAbsent,
                                              keyboardType:
                                                  const TextInputType.numberWithOptions(
                                                    decimal: true,
                                                  ),
                                              decoration: InputDecoration(
                                                isDense: true,
                                                hintText:
                                                    'Max ${res.practicalFullMarks?.toInt()}',
                                                contentPadding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 8,
                                                    ),
                                                border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        AppRadius.sm,
                                                      ),
                                                ),
                                              ),
                                              onChanged: (_) => setState(() {}),
                                            ),
                                          )
                                          : const Text(
                                            '-',
                                            style: TextStyle(
                                              color: Colors.grey,
                                            ),
                                          ),
                                    ),
                                    DataCell(
                                      Text(
                                        isAbsent
                                            ? 'AB'
                                            : res.totalMarksObtained
                                                .toStringAsFixed(1),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        isAbsent
                                            ? '0.0%'
                                            : '${res.percentage.toStringAsFixed(1)}%',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        isAbsent
                                            ? '0.00'
                                            : res.gradePoint.toStringAsFixed(2),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: res.color,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: res.color.withValues(
                                            alpha: 0.14,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          res.letterGrade,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: res.color,
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Chip(
                                        label: Text(
                                          isAbsent
                                              ? 'Absent'
                                              : (res.isPassed
                                                  ? 'Pass'
                                                  : 'Fail'),
                                          style: TextStyle(
                                            fontSize: 10,
                                            color:
                                                isAbsent
                                                    ? Colors.grey
                                                    : (res.isPassed
                                                        ? Colors.green
                                                        : Colors.red),
                                          ),
                                        ),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ),
                                    DataCell(
                                      SizedBox(
                                        width: 100,
                                        child: TextFormField(
                                          controller:
                                              _studentRemarksControllers[sub
                                                  .id],
                                          decoration: InputDecoration(
                                            isDense: true,
                                            hintText: 'Note',
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 6,
                                                  vertical: 6,
                                                ),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    AppRadius.sm,
                                                  ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${subjects.length} Subjects configured for class',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.grey,
                                ),
                              ),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryColor,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed:
                                    _isSavingStudentMarksheet
                                        ? null
                                        : () => _openStudentMarksheetPreview(
                                          examId: examId,
                                          academicYearId: academicYearId,
                                          classId: classId,
                                          sectionId: sectionId,
                                          student: selectedStudent,
                                          subjects: subjects,
                                        ),
                                icon:
                                    _isSavingStudentMarksheet
                                        ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                        : const Icon(
                                          Icons.preview_outlined,
                                          size: 18,
                                        ),
                                label: const Text('Preview & Save Marksheet'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Text('Error: $err'),
    );
  }

  Future<void> _openStudentMarksheetPreview({
    required int examId,
    required int academicYearId,
    required int classId,
    required int? sectionId,
    required Student student,
    required List<Subject> subjects,
  }) async {
    final items = <_StudentMarksheetPreviewItem>[];

    for (final sub in subjects) {
      final hasPractical = sub.subjectType != SubjectType.theory;
      final theoryFull =
          (hasPractical ? (sub.theoryMarks ?? 75) : sub.fullMarks).toDouble();
      final theoryPass =
          (hasPractical
                  ? (sub.theoryMarks != null
                      ? (sub.theoryMarks! * 0.4).round()
                      : 30)
                  : sub.passMarks)
              .toDouble();
      final practicalFull =
          hasPractical ? (sub.practicalMarks ?? 25).toDouble() : null;
      final practicalPass =
          hasPractical ? (practicalFull! * 0.4).toDouble() : null;

      final isAbsent = _studentAbsentMap[sub.id] ?? false;
      final tVal =
          double.tryParse(
            _studentTheoryControllers[sub.id]?.text.trim() ?? '0',
          ) ??
          0.0;
      final pVal =
          hasPractical
              ? (double.tryParse(
                    _studentPracticalControllers[sub.id]?.text.trim() ?? '0',
                  ) ??
                  0.0)
              : null;
      final rem = _studentRemarksControllers[sub.id]?.text.trim();

      String? valError;
      if (!isAbsent) {
        if (tVal < 0) {
          valError = 'Theory marks cannot be negative';
        } else if (tVal > theoryFull) {
          valError =
              'Theory marks ($tVal) exceeds full marks (${theoryFull.toInt()})';
        } else if (hasPractical && pVal != null) {
          if (pVal < 0) {
            valError = 'Practical marks cannot be negative';
          } else if (pVal > (practicalFull ?? 0)) {
            valError =
                'Practical marks ($pVal) exceeds full marks (${practicalFull?.toInt() ?? 0})';
          }
        }
      }

      final calc = ExamGradingUtils.calculateSubjectResult(
        theoryMarksObtained: isAbsent ? 0 : tVal,
        theoryFullMarks: theoryFull,
        theoryPassMarks: theoryPass,
        practicalMarksObtained: (hasPractical && !isAbsent) ? pVal : null,
        practicalFullMarks: practicalFull,
        practicalPassMarks: practicalPass,
        isAbsent: isAbsent,
      );

      items.add(
        _StudentMarksheetPreviewItem(
          subject: sub,
          isAbsent: isAbsent,
          theoryMarks: tVal,
          theoryFullMarks: theoryFull,
          theoryPassMarks: theoryPass,
          practicalMarks: pVal,
          practicalFullMarks: practicalFull,
          practicalPassMarks: practicalPass,
          remarks: rem,
          result: calc,
          validationError: valError,
        ),
      );
    }

    final overall = ExamGradingUtils.calculateOverallResult(
      items.map((i) => i.result).toList(),
    );

    final exams = ref.read(examsStreamProvider).asData?.value ?? [];
    final exam = exams.where((e) => e.id == examId).firstOrNull;
    final classes =
        ref.read(classesWithSectionsStreamProvider).asData?.value ?? [];
    final cls = classes.where((c) => c.id == classId).firstOrNull;
    final sectionName =
        sectionId != null
            ? cls?.sections.where((s) => s.id == sectionId).firstOrNull?.name
            : null;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => _StudentMarksheetPreviewDialog(
            examName: exam?.name ?? 'Exam #$examId',
            className: cls?.name ?? 'Class #$classId',
            sectionName: sectionName,
            student: student,
            items: items,
            overall: overall,
          ),
    );

    if (confirmed == true && mounted) {
      await _executeSaveStudentMarksheet(
        examId: examId,
        academicYearId: academicYearId,
        classId: classId,
        sectionId: sectionId,
        studentId: student.id,
        items: items,
      );
    }
  }

  Future<void> _executeSaveStudentMarksheet({
    required int examId,
    required int academicYearId,
    required int classId,
    required int? sectionId,
    required int studentId,
    required List<_StudentMarksheetPreviewItem> items,
  }) async {
    setState(() => _isSavingStudentMarksheet = true);

    try {
      final entries =
          items.map((item) {
            return StudentSubjectMarksEntryInput(
              subjectId: item.subject.id,
              theoryMarks: item.theoryMarks,
              theoryFullMarks: item.theoryFullMarks,
              theoryPassMarks: item.theoryPassMarks,
              practicalMarks: item.practicalMarks,
              practicalFullMarks: item.practicalFullMarks,
              practicalPassMarks: item.practicalPassMarks,
              isAbsent: item.isAbsent,
              remarks: item.remarks,
            );
          }).toList();

      final success = await ref
          .read(examResultControllerProvider.notifier)
          .saveStudentMarksheetBatch(
            examId: examId,
            academicYearId: academicYearId,
            classId: classId,
            sectionId: sectionId,
            studentId: studentId,
            entries: entries,
          );

      if (mounted) {
        setState(() => _isSavingStudentMarksheet = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Student marksheet saved successfully!'
                  : 'Failed to save student marksheet',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSavingStudentMarksheet = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving marksheet: $e')));
      }
    }
  }

  // ===========================================================================
  // 6. Mode 3: Tabulation Ledger View & Grade Sheet
  // ===========================================================================
  Widget _buildTabulationLedgerView(
    BuildContext context,
    int examId,
    int classId,
    int? sectionId,
    int academicYearId,
    String searchQuery,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final summariesAsync = ref.watch(examSummariesStreamProvider);
    final resultsAsync = ref.watch(examResultsStreamProvider);

    return summariesAsync.when(
      data: (summaries) {
        if (summaries.isEmpty) {
          return _buildEmptyState(
            'No results entered yet for this exam and class. Switch to "Subject Marks Entry" to start recording marks.',
          );
        }

        // Filter summaries
        final filteredSummaries =
            searchQuery.isEmpty
                ? summaries
                : summaries.where((s) {
                  final q = searchQuery.toLowerCase();
                  return s.studentName.toLowerCase().contains(q) ||
                      s.studentRollNumber.toLowerCase().contains(q) ||
                      s.studentCode.toLowerCase().contains(q);
                }).toList();

        final allResults = resultsAsync.value ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ledger Action Toolbar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Class Tabulation Ledger (${filteredSummaries.length} Students)',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    ref
                        .read(examResultControllerProvider.notifier)
                        .recalculateSummaries(
                          examId: examId,
                          academicYearId: academicYearId,
                          classId: classId,
                          sectionId: sectionId,
                        );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Ledger recalculation complete!'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Recalculate Ranks'),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Ledger Matrix Card
            Card(
              elevation: 0.5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                side: BorderSide(
                  color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                ),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowHeight: 46,
                  columns: const [
                    DataColumn(label: Text('Rank')),
                    DataColumn(label: Text('Roll')),
                    DataColumn(label: Text('Student Name')),
                    DataColumn(label: Text('Total Marks')),
                    DataColumn(label: Text('Percentage')),
                    DataColumn(label: Text('GPA')),
                    DataColumn(label: Text('Grade')),
                    DataColumn(label: Text('Result')),
                    DataColumn(label: Text('Report Card')),
                  ],
                  rows:
                      filteredSummaries.map((s) {
                        final gradeColor =
                            ExamGradingUtils.getGradeFromPercentage(
                              s.overallPercentage,
                            ).color;
                        final studentResults =
                            allResults
                                .where((r) => r.studentId == s.studentId)
                                .toList();

                        return DataRow(
                          cells: [
                            DataCell(
                              CircleAvatar(
                                radius: 12,
                                backgroundColor:
                                    s.rankInClass != null
                                        ? AppTheme.primaryColor.withValues(
                                          alpha: 0.12,
                                        )
                                        : Colors.grey.withValues(alpha: 0.12),
                                child: Text(
                                  s.rankInClass?.toString() ?? '-',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        s.rankInClass != null
                                            ? AppTheme.primaryColor
                                            : Colors.grey,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                s.studentRollNumber.isNotEmpty
                                    ? s.studentRollNumber
                                    : '-',
                              ),
                            ),
                            DataCell(
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    s.studentName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    s.studentCode,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            DataCell(
                              Text(
                                '${s.totalMarksObtained.toStringAsFixed(1)} / ${s.totalFullMarks.toInt()}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                '${s.overallPercentage.toStringAsFixed(1)}%',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                s.overallGpa.toStringAsFixed(2),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: gradeColor,
                                ),
                              ),
                            ),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: gradeColor.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  s.overallGrade,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: gradeColor,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              Chip(
                                label: Text(
                                  s.isPassed ? 'Passed' : 'Failed',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color:
                                        s.isPassed ? Colors.green : Colors.red,
                                  ),
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                            DataCell(
                              IconButton(
                                icon: const Icon(
                                  Icons.receipt_long_outlined,
                                  size: 20,
                                ),
                                tooltip: 'View Report Card',
                                onPressed:
                                    () => _showStudentReportCardDialog(
                                      context,
                                      s,
                                      studentResults,
                                    ),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Text('Error: $err'),
    );
  }

  // ===========================================================================
  // 7. Student Report Card Dialog
  // ===========================================================================
  void _showStudentReportCardDialog(
    BuildContext context,
    StudentExamSummaryWithDetails summary,
    List<ExamResultWithDetails> results,
  ) {
    showDialog(
      context: context,
      builder:
          (ctx) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 24,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800, maxHeight: 720),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Report Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'STUDENT PROGRESS REPORT / MARKSHEET',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              summary.examName,
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                    const Divider(height: 20),

                    // Student Metadata Card
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  summary.studentName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  'Student ID: ${summary.studentCode} • Roll: ${summary.studentRollNumber}',
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Class: ${summary.className}${summary.sectionName != null ? ' (${summary.sectionName})' : ''}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                'Rank: ${summary.rankInClass != null ? 'Top #${summary.rankInClass}' : 'N/A'}',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Subject Scores Table
                    Expanded(
                      child: SingleChildScrollView(
                        child: DataTable(
                          headingRowHeight: 40,
                          dataRowMinHeight: 44,
                          dataRowMaxHeight: 48,
                          columns: const [
                            DataColumn(label: Text('Subject')),
                            DataColumn(label: Text('Theory')),
                            DataColumn(label: Text('Practical')),
                            DataColumn(label: Text('Total')),
                            DataColumn(label: Text('%')),
                            DataColumn(label: Text('GPA')),
                            DataColumn(label: Text('Grade')),
                            DataColumn(label: Text('Status')),
                          ],
                          rows:
                              results.map((r) {
                                final gradeColor =
                                    ExamGradingUtils.getGradeFromPercentage(
                                      r.percentage,
                                    ).color;
                                return DataRow(
                                  cells: [
                                    DataCell(Text(r.subjectName)),
                                    DataCell(
                                      Text(
                                        r.isAbsent
                                            ? 'AB'
                                            : '${r.theoryMarksObtained.toInt()} / ${r.theoryFullMarks.toInt()}',
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        r.practicalFullMarks != null
                                            ? (r.isAbsent
                                                ? 'AB'
                                                : '${r.practicalMarksObtained?.toInt() ?? 0} / ${r.practicalFullMarks!.toInt()}')
                                            : '-',
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        r.isAbsent
                                            ? 'AB'
                                            : '${r.totalMarksObtained.toInt()} / ${r.totalFullMarks.toInt()}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        '${r.percentage.toStringAsFixed(1)}%',
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        r.gradePoint.toStringAsFixed(2),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: gradeColor,
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
                                          color: gradeColor.withValues(
                                            alpha: 0.14,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          r.letterGrade,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                            color: gradeColor,
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        r.isPassed ? 'P' : 'F',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color:
                                              r.isPassed
                                                  ? Colors.green
                                                  : Colors.red,
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Overall Totals Footer
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color:
                            summary.isPassed
                                ? Colors.green.withValues(alpha: 0.08)
                                : Colors.red.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color:
                              summary.isPassed
                                  ? Colors.green.withValues(alpha: 0.25)
                                  : Colors.red.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              const Text(
                                'Total Marks',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                '${summary.totalMarksObtained.toStringAsFixed(1)} / ${summary.totalFullMarks.toInt()}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              const Text(
                                'Percentage',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                '${summary.overallPercentage.toStringAsFixed(1)}%',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              const Text(
                                'Overall GPA',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                summary.overallGpa.toStringAsFixed(2),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      summary.isPassed
                                          ? Colors.green
                                          : Colors.red,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              const Text(
                                'Overall Grade',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                summary.overallGrade,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      summary.isPassed
                                          ? Colors.green
                                          : Colors.red,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              const Text(
                                'Final Result',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                summary.isPassed ? 'PASSED' : 'FAILED',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      summary.isPassed
                                          ? Colors.green
                                          : Colors.red,
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
          ),
    );
  }

  // Helper empty state
  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            const Icon(Icons.info_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              message,
              style: const TextStyle(color: Colors.grey, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// Simple Metric Card Widget
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(
          color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                    value,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// 8. Preview & Verification Models and Dialogs
// =============================================================================

class _SubjectMarksPreviewItem {
  final Student student;
  final bool isAbsent;
  final double theoryMarks;
  final double? practicalMarks;
  final String? remarks;
  final SubjectGradeResult result;
  final String? validationError;

  bool get isValid => validationError == null;

  const _SubjectMarksPreviewItem({
    required this.student,
    required this.isAbsent,
    required this.theoryMarks,
    this.practicalMarks,
    this.remarks,
    required this.result,
    this.validationError,
  });
}

class _SubjectMarksPreviewDialog extends StatefulWidget {
  final String examName;
  final String className;
  final String? sectionName;
  final SubjectExamMarksConfig config;
  final List<_SubjectMarksPreviewItem> items;

  const _SubjectMarksPreviewDialog({
    required this.examName,
    required this.className,
    this.sectionName,
    required this.config,
    required this.items,
  });

  @override
  State<_SubjectMarksPreviewDialog> createState() =>
      _SubjectMarksPreviewDialogState();
}

class _SubjectMarksPreviewDialogState
    extends State<_SubjectMarksPreviewDialog> {
  String _filter = 'all'; // 'all', 'passed', 'failed', 'absent', 'invalid'
  String _search = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hasPractical = widget.config.subjectType != SubjectType.theory;

    final total = widget.items.length;
    final absentCount = widget.items.where((i) => i.isAbsent).length;
    final evaluatedCount = total - absentCount;
    final passedCount =
        widget.items.where((i) => !i.isAbsent && i.result.isPassed).length;
    final failedCount =
        widget.items.where((i) => !i.isAbsent && !i.result.isPassed).length;
    final invalidCount = widget.items.where((i) => !i.isValid).length;

    final passPercentage =
        evaluatedCount > 0 ? (passedCount / evaluatedCount) * 100 : 0.0;
    final totalMarksObtained = widget.items
        .where((i) => !i.isAbsent)
        .fold(0.0, (sum, i) => sum + i.result.totalMarksObtained);
    final totalFullPossible = evaluatedCount * widget.config.totalFullMarks;
    final avgPercentage =
        totalFullPossible > 0
            ? (totalMarksObtained / totalFullPossible) * 100
            : 0.0;
    final totalGpa = widget.items
        .where((i) => !i.isAbsent)
        .fold(0.0, (sum, i) => sum + i.result.gradePoint);
    final avgGpa = evaluatedCount > 0 ? totalGpa / evaluatedCount : 0.0;

    // Filter items
    final filtered =
        widget.items.where((item) {
          // Status filter
          if (_filter == 'passed' && (item.isAbsent || !item.result.isPassed)) {
            return false;
          }
          if (_filter == 'failed' && (item.isAbsent || item.result.isPassed)) {
            return false;
          }
          if (_filter == 'absent' && !item.isAbsent) {
            return false;
          }
          if (_filter == 'invalid' && item.isValid) {
            return false;
          }

          // Search filter
          if (_search.isNotEmpty) {
            final q = _search.toLowerCase();
            final nameMatch = item.student.name.toLowerCase().contains(q);
            final rollMatch = (item.student.rollNumber?.toString() ?? '')
                .toLowerCase()
                .contains(q);
            final codeMatch = item.student.admissionNumber
                .toLowerCase()
                .contains(q);
            if (!nameMatch && !rollMatch && !codeMatch) return false;
          }

          return true;
        }).toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1050, maxHeight: 780),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.fact_check_outlined,
                      color: AppTheme.primaryColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'PREVIEW & VERIFY SUBJECT MARKS',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.examName} • ${widget.className}${widget.sectionName != null ? ' (${widget.sectionName})' : ''} • ${widget.config.subjectName} (${widget.config.subjectCode})',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            _buildInfoBadge(
                              'Theory: ${widget.config.theoryFullMarks.toInt()} (Pass: ${widget.config.theoryPassMarks.toInt()})',
                              Colors.blue,
                            ),
                            if (hasPractical)
                              _buildInfoBadge(
                                'Practical: ${widget.config.practicalFullMarks?.toInt() ?? 0} (Pass: ${widget.config.practicalPassMarks?.toInt() ?? 0})',
                                Colors.purple,
                              ),
                            _buildInfoBadge(
                              'Total Full Marks: ${widget.config.totalFullMarks.toInt()}',
                              Colors.teal,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => context.pop(false),
                  ),
                ],
              ),
              const Divider(height: 18),

              // Validation Error Banner (if any)
              if (invalidCount > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.red.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.red,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Validation Error: $invalidCount student mark entry(ies) exceed maximum full marks or are negative. Correct them before saving.',
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],

              // Metric Summary Cards
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildPreviewMetric(
                    'Total Students',
                    '$total',
                    Icons.group_outlined,
                    Colors.blue,
                  ),
                  _buildPreviewMetric(
                    'Passed',
                    '$passedCount (${passPercentage.toStringAsFixed(0)}%)',
                    Icons.check_circle_outline,
                    Colors.green,
                  ),
                  _buildPreviewMetric(
                    'Failed',
                    '$failedCount',
                    Icons.cancel_outlined,
                    Colors.red,
                  ),
                  _buildPreviewMetric(
                    'Absent',
                    '$absentCount',
                    Icons.person_off_outlined,
                    Colors.grey,
                  ),
                  _buildPreviewMetric(
                    'Class Average',
                    '${avgPercentage.toStringAsFixed(1)}% (${avgGpa.toStringAsFixed(2)} GPA)',
                    Icons.analytics_outlined,
                    Colors.teal,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Filter & Search Toolbar
              Row(
                children: [
                  // Filter Chips
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip('all', 'All ($total)'),
                          const SizedBox(width: 6),
                          _buildFilterChip(
                            'passed',
                            'Passed ($passedCount)',
                            color: Colors.green,
                          ),
                          const SizedBox(width: 6),
                          _buildFilterChip(
                            'failed',
                            'Failed ($failedCount)',
                            color: Colors.red,
                          ),
                          const SizedBox(width: 6),
                          _buildFilterChip(
                            'absent',
                            'Absent ($absentCount)',
                            color: Colors.grey,
                          ),
                          if (invalidCount > 0) ...[
                            const SizedBox(width: 6),
                            _buildFilterChip(
                              'invalid',
                              'Invalid ($invalidCount)',
                              color: Colors.red,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Search
                  SizedBox(
                    width: 220,
                    height: 36,
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Search student...',
                        hintStyle: const TextStyle(fontSize: 12),
                        prefixIcon: const Icon(Icons.search, size: 16),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onChanged: (v) => setState(() => _search = v.trim()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Table
              Expanded(
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color:
                          isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowHeight: 40,
                        dataRowMinHeight: 44,
                        dataRowMaxHeight: 48,
                        columns: [
                          const DataColumn(label: Text('Roll')),
                          const DataColumn(label: Text('Student')),
                          const DataColumn(label: Text('Status')),
                          DataColumn(
                            label: Text(
                              'Theory (${widget.config.theoryFullMarks.toInt()})',
                            ),
                          ),
                          if (hasPractical)
                            DataColumn(
                              label: Text(
                                'Practical (${widget.config.practicalFullMarks?.toInt() ?? 0})',
                              ),
                            ),
                          const DataColumn(label: Text('Total')),
                          const DataColumn(label: Text('Percentage')),
                          const DataColumn(label: Text('GPA')),
                          const DataColumn(label: Text('Grade')),
                          const DataColumn(label: Text('Remarks')),
                        ],
                        rows:
                            filtered.map((item) {
                              final res = item.result;
                              final isInvalid = !item.isValid;
                              return DataRow(
                                color:
                                    isInvalid
                                        ? WidgetStateProperty.all(
                                          Colors.red.withValues(alpha: 0.08),
                                        )
                                        : null,
                                cells: [
                                  DataCell(
                                    Text(
                                      item.student.rollNumber?.toString() ??
                                          '-',
                                    ),
                                  ),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        CircleAvatar(
                                          radius: 13,
                                          backgroundColor: AppTheme.primaryColor
                                              .withValues(alpha: 0.12),
                                          child: Text(
                                            item.student.name.isNotEmpty
                                                ? item.student.name[0]
                                                : 'S',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          item.student.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  DataCell(
                                    isInvalid
                                        ? Tooltip(
                                          message:
                                              item.validationError ??
                                              'Invalid mark entry',
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.red.withValues(
                                                alpha: 0.15,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                              border: Border.all(
                                                color: Colors.red.withValues(
                                                  alpha: 0.4,
                                                ),
                                              ),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.error,
                                                  size: 12,
                                                  color: Colors.red,
                                                ),
                                                SizedBox(width: 3),
                                                Text(
                                                  'INVALID',
                                                  style: TextStyle(
                                                    color: Colors.red,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        )
                                        : Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: res.color.withValues(
                                              alpha: 0.14,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Text(
                                            res.isAbsent
                                                ? 'ABSENT'
                                                : (res.isPassed
                                                    ? 'PASS'
                                                    : 'FAIL'),
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                              color: res.color,
                                            ),
                                          ),
                                        ),
                                  ),
                                  DataCell(
                                    Text(
                                      item.isAbsent
                                          ? 'AB'
                                          : item.theoryMarks.toString(),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color:
                                            (item.theoryMarks >
                                                        widget
                                                            .config
                                                            .theoryFullMarks ||
                                                    item.theoryMarks < 0)
                                                ? Colors.red
                                                : null,
                                      ),
                                    ),
                                  ),
                                  if (hasPractical)
                                    DataCell(
                                      Text(
                                        item.isAbsent
                                            ? 'AB'
                                            : (item.practicalMarks
                                                    ?.toString() ??
                                                '-'),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color:
                                              (item.practicalMarks != null &&
                                                      (item.practicalMarks! >
                                                              (widget
                                                                      .config
                                                                      .practicalFullMarks ??
                                                                  0) ||
                                                          item.practicalMarks! <
                                                              0))
                                                  ? Colors.red
                                                  : null,
                                        ),
                                      ),
                                    ),
                                  DataCell(
                                    Text(
                                      item.isAbsent
                                          ? 'AB'
                                          : res.totalMarksObtained
                                              .toStringAsFixed(1),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      item.isAbsent
                                          ? '-'
                                          : '${res.percentage.toStringAsFixed(1)}%',
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      item.isAbsent
                                          ? '-'
                                          : res.gradePoint.toStringAsFixed(2),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: res.color,
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
                                        color: res.color.withValues(
                                          alpha: 0.12,
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        res.letterGrade,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                          color: res.color,
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      item.remarks?.isNotEmpty == true
                                          ? item.remarks!
                                          : '-',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Footer Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Showing ${filtered.length} of $total student records',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.arrow_back, size: 16),
                        label: const Text('Back to Edit'),
                        onPressed: () => context.pop(false),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                        ),
                        icon: const Icon(Icons.check_circle_outline, size: 18),
                        label: const Text('Confirm & Save Marks'),
                        onPressed:
                            invalidCount > 0 ? null : () => context.pop(true),
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

  Widget _buildPreviewMetric(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: color,
                ),
              ),
              Text(
                title,
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label, {Color? color}) {
    final isSelected = _filter == key;
    return ChoiceChip(
      selected: isSelected,
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: 11,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? Colors.white : color,
      ),
      selectedColor: color ?? AppTheme.primaryColor,
      onSelected: (selected) {
        if (selected) setState(() => _filter = key);
      },
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildInfoBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _StudentMarksheetPreviewItem {
  final Subject subject;
  final bool isAbsent;
  final double theoryMarks;
  final double theoryFullMarks;
  final double theoryPassMarks;
  final double? practicalMarks;
  final double? practicalFullMarks;
  final double? practicalPassMarks;
  final String? remarks;
  final SubjectGradeResult result;
  final String? validationError;

  bool get isValid => validationError == null;

  const _StudentMarksheetPreviewItem({
    required this.subject,
    required this.isAbsent,
    required this.theoryMarks,
    required this.theoryFullMarks,
    required this.theoryPassMarks,
    this.practicalMarks,
    this.practicalFullMarks,
    this.practicalPassMarks,
    this.remarks,
    required this.result,
    this.validationError,
  });
}

class _StudentMarksheetPreviewDialog extends StatelessWidget {
  final String examName;
  final String className;
  final String? sectionName;
  final Student student;
  final List<_StudentMarksheetPreviewItem> items;
  final OverallGradeResult overall;

  const _StudentMarksheetPreviewDialog({
    required this.examName,
    required this.className,
    this.sectionName,
    required this.student,
    required this.items,
    required this.overall,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final invalidCount = items.where((i) => !i.isValid).length;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960, maxHeight: 760),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.fact_check_outlined,
                      color: AppTheme.primaryColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'PREVIEW & VERIFY STUDENT MARKSHEET',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$examName • $className${sectionName != null ? ' ($sectionName)' : ''}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => context.pop(false),
                  ),
                ],
              ),
              const Divider(height: 18),

              // Student & Overall Performance Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkSurface : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color:
                        overall.isPassed
                            ? Colors.green.withValues(alpha: 0.3)
                            : Colors.red.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: overall.color.withValues(alpha: 0.14),
                      child: Text(
                        overall.letterGrade,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: overall.color,
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
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
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
                                      overall.isPassed
                                          ? Colors.green.withValues(alpha: 0.14)
                                          : Colors.red.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  overall.isPassed ? 'PASSED' : 'FAILED',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                    color:
                                        overall.isPassed
                                            ? Colors.green
                                            : Colors.red,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Roll: ${student.rollNumber ?? '-'} • Admission No: ${student.admissionNumber} • Class: $className${sectionName != null ? ' ($sectionName)' : ''}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Total Marks: ${overall.totalMarksObtained.toStringAsFixed(1)} / ${overall.totalFullMarks.toInt()} • Percentage: ${overall.percentage.toStringAsFixed(1)}% • Overall GPA: ${overall.gpa.toStringAsFixed(2)} • Passed ${overall.passedSubjects} of ${overall.totalSubjects} subjects',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: overall.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Validation Error Banner (if any)
              if (invalidCount > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.red.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.red,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Validation Error: $invalidCount subject entry(ies) exceed maximum full marks or are negative. Correct them before saving.',
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],

              // Subjects Table
              Expanded(
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color:
                          isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowHeight: 40,
                        dataRowMinHeight: 44,
                        dataRowMaxHeight: 48,
                        columns: const [
                          DataColumn(label: Text('Subject')),
                          DataColumn(label: Text('Type')),
                          DataColumn(label: Text('Status')),
                          DataColumn(label: Text('Theory')),
                          DataColumn(label: Text('Practical')),
                          DataColumn(label: Text('Total')),
                          DataColumn(label: Text('Percentage')),
                          DataColumn(label: Text('GPA')),
                          DataColumn(label: Text('Grade')),
                          DataColumn(label: Text('Remarks')),
                        ],
                        rows:
                            items.map((item) {
                              final res = item.result;
                              final isInvalid = !item.isValid;
                              final hasPractical =
                                  item.subject.subjectType !=
                                  SubjectType.theory;

                              return DataRow(
                                color:
                                    isInvalid
                                        ? WidgetStateProperty.all(
                                          Colors.red.withValues(alpha: 0.08),
                                        )
                                        : null,
                                cells: [
                                  DataCell(
                                    Text(
                                      '${item.subject.name} (${item.subject.code})',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      item.subject.subjectType.displayName,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  DataCell(
                                    isInvalid
                                        ? Tooltip(
                                          message:
                                              item.validationError ??
                                              'Invalid mark entry',
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.red.withValues(
                                                alpha: 0.15,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                              border: Border.all(
                                                color: Colors.red.withValues(
                                                  alpha: 0.4,
                                                ),
                                              ),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.error,
                                                  size: 12,
                                                  color: Colors.red,
                                                ),
                                                SizedBox(width: 3),
                                                Text(
                                                  'INVALID',
                                                  style: TextStyle(
                                                    color: Colors.red,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        )
                                        : Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: res.color.withValues(
                                              alpha: 0.14,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Text(
                                            res.isAbsent
                                                ? 'ABSENT'
                                                : (res.isPassed
                                                    ? 'PASS'
                                                    : 'FAIL'),
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                              color: res.color,
                                            ),
                                          ),
                                        ),
                                  ),
                                  DataCell(
                                    Text(
                                      item.isAbsent
                                          ? 'AB'
                                          : '${item.theoryMarks.toString()} / ${item.theoryFullMarks.toInt()}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color:
                                            (item.theoryMarks >
                                                        item.theoryFullMarks ||
                                                    item.theoryMarks < 0)
                                                ? Colors.red
                                                : null,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      hasPractical
                                          ? (item.isAbsent
                                              ? 'AB'
                                              : '${item.practicalMarks?.toString() ?? '-'} / ${item.practicalFullMarks?.toInt() ?? 0}')
                                          : '-',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color:
                                            (item.practicalMarks != null &&
                                                    (item.practicalMarks! >
                                                            (item.practicalFullMarks ??
                                                                0) ||
                                                        item.practicalMarks! <
                                                            0))
                                                ? Colors.red
                                                : null,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      item.isAbsent
                                          ? 'AB'
                                          : '${res.totalMarksObtained.toStringAsFixed(1)} / ${res.totalFullMarks.toInt()}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      item.isAbsent
                                          ? '-'
                                          : '${res.percentage.toStringAsFixed(1)}%',
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      item.isAbsent
                                          ? '-'
                                          : res.gradePoint.toStringAsFixed(2),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: res.color,
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
                                        color: res.color.withValues(
                                          alpha: 0.12,
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        res.letterGrade,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                          color: res.color,
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      item.remarks?.isNotEmpty == true
                                          ? item.remarks!
                                          : '-',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Footer Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${items.length} Subjects evaluated',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.arrow_back, size: 16),
                        label: const Text('Back to Edit'),
                        onPressed: () => context.pop(false),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                        ),
                        icon: const Icon(Icons.check_circle_outline, size: 18),
                        label: const Text('Confirm & Save Marksheet'),
                        onPressed:
                            invalidCount > 0 ? null : () => context.pop(true),
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
