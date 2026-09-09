import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../../../core/database/app_database.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../academic_year/data/academic_year_repository.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../../classes/data/classes_repository.dart';
import '../data/exams_repository.dart';
import '../data/results_repository.dart';
import '../domain/result_calculator.dart';
import '../services/pdf/report_card_pdf_service.dart';

class ReportCardsScreen extends ConsumerStatefulWidget {
  final String examId;

  const ReportCardsScreen({super.key, required this.examId});

  @override
  ConsumerState<ReportCardsScreen> createState() => _ReportCardsScreenState();
}

class _ReportCardsScreenState extends ConsumerState<ReportCardsScreen> {
  bool _isLoading = true;
  bool _isGeneratingBulk = false;
  double _bulkProgress = 0.0;
  String _bulkProgressText = '';

  Exam? _exam;
  AcademicYear? _academicYear;
  List<ClassWithSections> _classes = [];
  String? _selectedClassId;
  String? _selectedSectionId;
  List<StudentExamResult> _results = [];

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
    final academicRepo = ref.read(academicYearRepositoryProvider);

    final exam = await examsRepo.getExamById(widget.examId);
    if (exam == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final years = await academicRepo.getAcademicYears(school.id);
    final academicYear =
        years.where((ay) => ay.id == exam.academicYearId).firstOrNull;
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
    _academicYear = academicYear;
    _classes = classes;

    await _loadResults();

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadResults() async {
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
      setState(() => _results = summary.studentResults);
    }
  }

  ReportCardData _buildReportCardData(StudentExamResult res) {
    final school = ref.read(authControllerProvider).currentSchool;
    final activeClass =
        _classes.where((c) => c.schoolClass.id == _selectedClassId).firstOrNull;
    final activeSection =
        activeClass?.sections
            .where((s) => s.id == _selectedSectionId)
            .firstOrNull;

    return ReportCardData(
      schoolName: school?.name ?? 'School Management System',
      schoolAddress: school?.address,
      schoolPhone: school?.phone,
      schoolPrincipal: school?.principalName,
      academicYearName: _academicYear?.name ?? 'Academic Year',
      examName: _exam?.name ?? 'Examination',
      studentName: res.studentName,
      studentCode: res.studentCode,
      rollNumber: res.rollNumber,
      className: activeClass?.schoolClass.name ?? 'Class',
      sectionName: activeSection?.name ?? 'Section',
      result: res,
      attendanceStats: const StudentAttendanceStats(
        totalDays: 120,
        presentDays: 114,
        absentDays: 6,
        percentage: 95.0,
      ),
      issueDate: DateTime.now(),
    );
  }

  void _previewSingleReportCard(StudentExamResult res) {
    final data = _buildReportCardData(res);

    showDialog(
      context: context,
      builder:
          (ctx) => Dialog(
            insetPadding: const EdgeInsets.all(24),
            child: SizedBox(
              width: 850,
              height: 750,
              child: Scaffold(
                appBar: AppBar(
                  title: Text('Report Card - ${res.studentName}'),
                  actions: [
                    IconButton(
                      tooltip: 'Print',
                      icon: const Icon(Icons.print),
                      onPressed: () async {
                        final pdfBytes =
                            await ReportCardPdfService.generateReportCardPdf(
                              data,
                            );
                        await Printing.layoutPdf(
                          onLayout: (format) async => pdfBytes,
                        );
                      },
                    ),
                    IconButton(
                      tooltip: 'Share / Save PDF',
                      icon: const Icon(Icons.share),
                      onPressed: () async {
                        final pdfBytes =
                            await ReportCardPdfService.generateReportCardPdf(
                              data,
                            );
                        await Printing.sharePdf(
                          bytes: pdfBytes,
                          filename:
                              'ReportCard_${res.studentCode ?? res.studentId}.pdf',
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
                body: PdfPreview(
                  build:
                      (format) =>
                          ReportCardPdfService.generateReportCardPdf(data),
                  allowPrinting: false,
                  allowSharing: false,
                  canChangeOrientation: false,
                  canChangePageFormat: false,
                  initialPageFormat: PdfPageFormat.a4,
                ),
              ),
            ),
          ),
    );
  }

  Future<void> _generateBulkReportCards() async {
    if (_results.isEmpty) return;

    setState(() {
      _isGeneratingBulk = true;
      _bulkProgress = 0.0;
      _bulkProgressText = 'Compiling report cards...';
    });

    try {
      final studentsData =
          _results.map((r) => _buildReportCardData(r)).toList();

      final pdfBytes = await ReportCardPdfService.generateBulkReportCardsPdf(
        studentsData: studentsData,
        onProgress: (current, total) {
          if (mounted) {
            setState(() {
              _bulkProgress = current / total;
              _bulkProgressText =
                  'Generating report card $current of $total...';
            });
          }
        },
      );

      if (mounted) {
        setState(() => _isGeneratingBulk = false);
        await Printing.layoutPdf(
          onLayout: (format) async => pdfBytes,
          name: '${_exam?.name ?? "Exam"}_All_Report_Cards',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGeneratingBulk = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating bulk report cards: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Report Cards')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_exam == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Report Cards')),
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

    return Scaffold(
      appBar: AppBar(
        title: Text('${_exam!.name} - Report Cards'),
        actions: [
          if (_results.isNotEmpty)
            FilledButton.icon(
              icon:
                  _isGeneratingBulk
                      ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                      : const Icon(Icons.print, size: 18),
              label: Text(
                _isGeneratingBulk
                    ? 'Compiling...'
                    : 'Generate All Report Cards (${_results.length})',
              ),
              onPressed: _isGeneratingBulk ? null : _generateBulkReportCards,
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
                      _loadResults();
                    },
                  ),
                ),
                const SizedBox(width: 16),
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
                      _loadResults();
                    },
                  ),
                ),
                const SizedBox(width: 16),
                IconButton(
                  tooltip: 'Refresh',
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadResults,
                ),
              ],
            ),
          ),

          // Bulk Progress Banner if running
          if (_isGeneratingBulk)
            Container(
              padding: const EdgeInsets.all(12),
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
              child: Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _bulkProgressText,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${(_bulkProgress * 100).toInt()}%',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),

          // Student List
          Expanded(
            child:
                _results.isEmpty
                    ? const EmptyState(
                      icon: Icons.picture_as_pdf_outlined,
                      title: 'No Report Cards Available',
                      message:
                          'Enter marks and calculate results to generate offline printable report cards.',
                    )
                    : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _results.length,
                      separatorBuilder: (ctx, idx) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final r = _results[index];
                        return Card(
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            leading: CircleAvatar(
                              child: Text(r.rank?.toString() ?? '${index + 1}'),
                            ),
                            title: Text(
                              r.studentName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              'Code: ${r.studentCode ?? "-"}  •  Score: ${r.totalMarksObtained}/${r.totalFullMarks} (${r.percentage.toStringAsFixed(1)}%)  •  Grade: ${r.overallGrade}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                FilledButton.tonalIcon(
                                  icon: const Icon(
                                    Icons.visibility_outlined,
                                    size: 18,
                                  ),
                                  label: const Text('View Report Card'),
                                  onPressed: () => _previewSingleReportCard(r),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  tooltip: 'Print Directly',
                                  icon: const Icon(Icons.print_outlined),
                                  onPressed: () async {
                                    final data = _buildReportCardData(r);
                                    final pdfBytes =
                                        await ReportCardPdfService.generateReportCardPdf(
                                          data,
                                        );
                                    await Printing.layoutPdf(
                                      onLayout: (format) async => pdfBytes,
                                    );
                                  },
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
}
