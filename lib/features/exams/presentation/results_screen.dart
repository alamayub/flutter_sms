import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../../classes/data/classes_repository.dart';
import '../data/exams_repository.dart';
import '../data/results_repository.dart';
import '../domain/exam_models.dart';
import '../domain/result_calculator.dart';
import '../services/csv/marks_csv_service.dart';

class ResultsScreen extends ConsumerStatefulWidget {
  final String examId;

  const ResultsScreen({super.key, required this.examId});

  @override
  ConsumerState<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends ConsumerState<ResultsScreen> {
  bool _isLoading = true;
  bool _isActionRunning = false;
  Exam? _exam;
  List<ClassWithSections> _classes = [];
  String? _selectedClassId;
  String? _selectedSectionId;
  ClassResultsSummary? _summary;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    setState(() => _isLoading = true);
    final school = ref.read(authControllerProvider).currentSchool;
    if (school == null) return;

    final examsRepo = ref.read(examsRepositoryProvider);
    final classesRepo = ref.read(classesRepositoryProvider);

    final exam = await examsRepo.getExamById(widget.examId);
    if (exam == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final classes = await classesRepo.getClassesWithSections(
      schoolId: school.id,
      academicYearId: exam.academicYearId,
    );

    _selectedClassId = classes.isNotEmpty ? classes.first.schoolClass.id : null;
    if (_selectedClassId != null &&
        classes.isNotEmpty &&
        classes.first.sections.isNotEmpty) {
      _selectedSectionId = classes.first.sections.first.id;
    }

    _exam = exam;
    _classes = classes;

    await _calculateAndLoadResults();

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _calculateAndLoadResults() async {
    if (_exam == null || _selectedClassId == null) return;

    final school = ref.read(authControllerProvider).currentSchool;
    if (school == null) return;

    final resultsRepo = ref.read(resultsRepositoryProvider);
    final summary = await resultsRepo.getClassResultsSummary(
      schoolId: school.id,
      examId: widget.examId,
      classId: _selectedClassId!,
      sectionId: _selectedSectionId,
    );

    if (mounted) {
      setState(() => _summary = summary);
    }
  }

  Future<void> _publishResults() async {
    final school = ref.read(authControllerProvider).currentSchool;
    final user = ref.read(authControllerProvider).currentUser;
    if (school == null || user == null || _selectedClassId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.published_with_changes, color: Colors.green),
                SizedBox(width: 8),
                Text('Publish Examination Results?'),
              ],
            ),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Publishing results will:\n'
                  '• Finalize and lock all student marks for this class.\n'
                  '• Prevent unauthorized mark modifications across the school LAN.\n'
                  '• Authorize report cards to be generated and issued.\n\n'
                  'Any subsequent mark edits will require administrative authorization and permanent audit logging.',
                  style: TextStyle(fontSize: 13, height: 1.4),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.green.shade800,
                ),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Confirm & Publish'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      setState(() => _isActionRunning = true);
      try {
        final resultsRepo = ref.read(resultsRepositoryProvider);
        await resultsRepo.publishResults(
          schoolId: school.id,
          examId: widget.examId,
          classId: _selectedClassId!,
          sectionId: _selectedSectionId,
          publishedBy: user.id,
        );
        await _calculateAndLoadResults();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Results successfully published and locked! ✓'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error publishing: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isActionRunning = false);
      }
    }
  }

  void _exportResultsCsv() {
    if (_summary == null || _summary!.studentResults.isEmpty || _exam == null) {
      return;
    }

    final csvService = const MarksCsvService();
    final dummyStudents =
        _summary!.studentResults.map((r) {
          final names = r.studentName.split(' ');
          final first = names.first;
          final last = names.length > 1 ? names.sublist(1).join(' ') : '';
          return Student(
            id: r.studentId,
            schoolId: _exam!.schoolId,
            studentCode: r.studentCode ?? 'UNKNOWN',
            firstName: first,
            lastName: last,
            gender: 'Other',
            isActive: true,
            isArchived: false,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
        }).toList();

    final dummyResults =
        _summary!.studentResults.map((r) {
          return Result(
            id: '',
            schoolId: _exam!.schoolId,
            examId: widget.examId,
            studentId: r.studentId,
            classId: _selectedClassId ?? '',
            sectionId: _selectedSectionId ?? '',
            totalMarksObtained: r.totalMarksObtained,
            totalFullMarks: r.totalFullMarks,
            percentage: r.percentage,
            gpa: r.gpa,
            overallGrade: r.overallGrade,
            isPassed: r.isPassed,
            rank: r.rank,
            calculatedAt: DateTime.now(),
          );
        }).toList();

    final csvString = csvService.exportResults(
      exam: _exam!,
      students: dummyStudents,
      results: dummyResults,
      subjects: [],
    );

    Clipboard.setData(ClipboardData(text: csvString));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Results CSV exported and copied to clipboard!'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _showStudentBreakdown(StudentExamResult result) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Row(
              children: [
                CircleAvatar(child: Text(result.rank?.toString() ?? '-')),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        result.studentName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Code: ${result.studentCode}  •  Roll: ${result.rollNumber ?? "-"}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Summary Badges
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(
                          label: Text(
                            'Total: ${result.totalMarksObtained} / ${result.totalFullMarks}',
                          ),
                        ),
                        Chip(
                          label: Text(
                            'Percentage: ${result.percentage.toStringAsFixed(1)}%',
                          ),
                        ),
                        if (result.gpa != null)
                          Chip(
                            label: Text(
                              'GPA: ${result.gpa!.toStringAsFixed(2)}',
                            ),
                          ),
                        Chip(label: Text('Grade: ${result.overallGrade}')),
                        Chip(
                          backgroundColor:
                              result.isPassed
                                  ? Colors.green.shade100
                                  : Colors.red.shade100,
                          label: Text(
                            result.isPassed ? 'PASSED' : 'FAILED',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color:
                                  result.isPassed
                                      ? Colors.green.shade900
                                      : Colors.red.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Subject Breakdown',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ...result.subjectResults.map((sr) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    sr.subjectName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'Full: ${sr.fullMarks.toInt()}  Pass: ${sr.passMarks.toInt()}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                sr.status == MarkStatus.present
                                    ? '${sr.totalMarks ?? 0} (${sr.percentage?.toStringAsFixed(1)}%)'
                                    : sr.status.displayName.toUpperCase(),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color:
                                      sr.isPassed
                                          ? Colors.green.shade800
                                          : Colors.red.shade800,
                                ),
                              ),
                            ),
                            Text(
                              sr.grade,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
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
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Results & Publishing')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_exam == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Results & Publishing')),
        body: const EmptyState(
          icon: Icons.error_outline,
          title: 'Exam Not Found',
          message: 'The requested examination could not be loaded.',
        ),
      );
    }

    final activeClass =
        _classes.where((c) => c.schoolClass.id == _selectedClassId).firstOrNull;
    final availableSections = activeClass?.sections ?? [];
    final isPublished = _summary?.isPublished ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text('${_exam!.name} - Results'),
        actions: [
          IconButton(
            tooltip: 'Export Results CSV',
            icon: const Icon(Icons.file_download_outlined),
            onPressed: _exportResultsCsv,
          ),
          IconButton(
            tooltip: 'Recalculate Results',
            icon: const Icon(Icons.refresh),
            onPressed: _calculateAndLoadResults,
          ),
          const SizedBox(width: 8),
          if (isPublished)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green),
              ),
              child: Row(
                children: [
                  Icon(Icons.verified, size: 18, color: Colors.green.shade800),
                  const SizedBox(width: 6),
                  Text(
                    'Published (Marks Locked)',
                    style: TextStyle(
                      color: Colors.green.shade900,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            )
          else
            FilledButton.icon(
              icon:
                  _isActionRunning
                      ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                      : const Icon(Icons.publish, size: 18),
              label: const Text('Publish Results'),
              onPressed: _isActionRunning ? null : _publishResults,
            ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          // Filter Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(
                bottom: BorderSide(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.5,
                  ),
                ),
              ),
            ),
            child: Row(
              children: [
                // Class Dropdown
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedClassId,
                    decoration: const InputDecoration(
                      labelText: 'Select Class',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    items:
                        _classes.map((c) {
                          return DropdownMenuItem(
                            value: c.schoolClass.id,
                            child: Text(c.schoolClass.name),
                          );
                        }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedClassId = val;
                        final cls =
                            _classes
                                .where((c) => c.schoolClass.id == val)
                                .firstOrNull;
                        _selectedSectionId =
                            cls != null && cls.sections.isNotEmpty
                                ? cls.sections.first.id
                                : null;
                      });
                      _calculateAndLoadResults();
                    },
                  ),
                ),
                const SizedBox(width: 16),

                // Section Dropdown
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedSectionId,
                    decoration: const InputDecoration(
                      labelText: 'Select Section',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    items:
                        availableSections.map((s) {
                          return DropdownMenuItem(
                            value: s.id,
                            child: Text(s.name),
                          );
                        }).toList(),
                    onChanged: (val) {
                      setState(() => _selectedSectionId = val);
                      _calculateAndLoadResults();
                    },
                  ),
                ),
              ],
            ),
          ),

          // Summary KPI Banner
          if (_summary != null && _summary!.totalStudents > 0)
            Container(
              padding: const EdgeInsets.all(16),
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.3,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatCard(
                    'Enrolled',
                    '${_summary!.totalStudents}',
                    Icons.group,
                  ),
                  _buildStatCard(
                    'Passed',
                    '${_summary!.passCount}',
                    Icons.check_circle,
                    color: Colors.green,
                  ),
                  _buildStatCard(
                    'Failed',
                    '${_summary!.failCount}',
                    Icons.cancel,
                    color: Colors.red,
                  ),
                  _buildStatCard(
                    'Pass %',
                    '${(_summary!.passCount / _summary!.totalStudents * 100).toStringAsFixed(1)}%',
                    Icons.trending_up,
                    color: Colors.teal,
                  ),
                  _buildStatCard(
                    'Average',
                    '${_summary!.averagePercentage}%',
                    Icons.bar_chart,
                  ),
                  _buildStatCard(
                    'Highest',
                    '${_summary!.highestPercentage}%',
                    Icons.emoji_events,
                    color: Colors.amber.shade800,
                  ),
                ],
              ),
            ),

          // Results Table / List
          Expanded(
            child:
                _summary == null || _summary!.studentResults.isEmpty
                    ? const EmptyState(
                      icon: Icons.assessment_outlined,
                      title: 'No Results Found',
                      message:
                          'Enter marks for this class to calculate and view examination results.',
                    )
                    : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _summary!.studentResults.length,
                      separatorBuilder: (ctx, idx) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final r = _summary!.studentResults[index];
                        final isPassed = r.isPassed;

                        return Card(
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            onTap: () => _showStudentBreakdown(r),
                            leading: CircleAvatar(
                              backgroundColor:
                                  r.rank == 1
                                      ? Colors.amber.shade200
                                      : (r.rank == 2
                                          ? Colors.grey.shade300
                                          : (r.rank == 3
                                              ? Colors.brown.shade200
                                              : theme
                                                  .colorScheme
                                                  .primaryContainer)),
                              child: Text(
                                r.rank?.toString() ?? '${index + 1}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color:
                                      r.rank == 1
                                          ? Colors.amber.shade900
                                          : theme
                                              .colorScheme
                                              .onPrimaryContainer,
                                ),
                              ),
                            ),
                            title: Text(
                              r.studentName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              'Code: ${r.studentCode}  •  Marks: ${r.totalMarksObtained} / ${r.totalFullMarks}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${r.percentage.toStringAsFixed(1)}%',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    if (r.gpa != null)
                                      Text(
                                        'GPA: ${r.gpa!.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(width: 16),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    r.overallGrade,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        isPassed
                                            ? Colors.green.shade100
                                            : Colors.red.shade100,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    isPassed ? 'PASS' : 'FAIL',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color:
                                          isPassed
                                              ? Colors.green.shade900
                                              : Colors.red.shade900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon, {
    Color? color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: color ?? Colors.grey.shade700),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color ?? Colors.black87,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}
