// lib/features/exams/presentation/marks_entry_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../../classes/data/classes_repository.dart';
import '../../students/data/students_repository.dart';
import '../../subjects/data/subjects_repository.dart';
import '../data/exams_repository.dart';
import '../data/marks_repository.dart';
import '../domain/exam_models.dart';
import '../domain/result_calculator.dart';
import '../services/csv/marks_csv_service.dart';

class MarksEntryScreen extends ConsumerStatefulWidget {
  final String examId;

  const MarksEntryScreen({super.key, required this.examId});

  @override
  ConsumerState<MarksEntryScreen> createState() => _MarksEntryScreenState();
}

class _StudentMarkRowState {
  final EnrolledStudent enrolledStudent;
  Mark? existingMark;
  late TextEditingController theoryController;
  late TextEditingController practicalController;
  late TextEditingController internalController;
  late TextEditingController remarksController;
  MarkStatus status = MarkStatus.present;
  String? validationError;

  _StudentMarkRowState({required this.enrolledStudent, this.existingMark}) {
    status =
        existingMark != null
            ? MarkStatus.fromString(existingMark!.status)
            : MarkStatus.present;
    theoryController = TextEditingController(
      text: existingMark?.theoryMarks?.toString() ?? '',
    );
    practicalController = TextEditingController(
      text: existingMark?.practicalMarks?.toString() ?? '',
    );
    internalController = TextEditingController(
      text: existingMark?.internalMarks?.toString() ?? '',
    );
    remarksController = TextEditingController(
      text: existingMark?.remarks ?? '',
    );
  }

  void dispose() {
    theoryController.dispose();
    practicalController.dispose();
    internalController.dispose();
    remarksController.dispose();
  }

  double? get parsedTheory => double.tryParse(theoryController.text.trim());
  double? get parsedPractical =>
      double.tryParse(practicalController.text.trim());
  double? get parsedInternal => double.tryParse(internalController.text.trim());

  double? calculateTotal() {
    if (status == MarkStatus.absent || status == MarkStatus.notAppeared) {
      return null;
    }
    double total = 0;
    bool hasAny = false;
    if (parsedTheory != null) {
      total += parsedTheory!;
      hasAny = true;
    }
    if (parsedPractical != null) {
      total += parsedPractical!;
      hasAny = true;
    }
    if (parsedInternal != null) {
      total += parsedInternal!;
      hasAny = true;
    }
    return hasAny ? ResultCalculator.round2(total) : null;
  }
}

class _MarksEntryScreenState extends ConsumerState<MarksEntryScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  Exam? _exam;
  List<ClassWithSections> _classes = [];
  List<Subject> _allSubjects = [];
  List<ExamSubject> _examSubjects = [];

  String? _selectedClassId;
  String? _selectedSectionId;
  String? _selectedExamSubjectId;

  List<_StudentMarkRowState> _rowStates = [];
  MarksProgress? _progress;
  bool _isAnyMarkLocked = false;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  @override
  void dispose() {
    for (final r in _rowStates) {
      r.dispose();
    }
    super.dispose();
  }

  Future<void> _loadInitial() async {
    setState(() => _isLoading = true);
    final school = ref.read(authControllerProvider).currentSchool;
    if (school == null) return;

    final examsRepo = ref.read(examsRepositoryProvider);
    final classesRepo = ref.read(classesRepositoryProvider);
    final subjectsRepo = ref.read(subjectsRepositoryProvider);

    final exam = await examsRepo.getExamById(widget.examId);
    if (exam == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final classes = await classesRepo.getClassesWithSections(
      schoolId: school.id,
      academicYearId: exam.academicYearId,
    );

    final subjects = await subjectsRepo.getSubjects(school.id);
    final allExamSubjects = await examsRepo.getExamSubjects(
      examId: widget.examId,
    );

    _selectedClassId = classes.isNotEmpty ? classes.first.schoolClass.id : null;
    if (_selectedClassId != null &&
        classes.isNotEmpty &&
        classes.first.sections.isNotEmpty) {
      _selectedSectionId = classes.first.sections.first.id;
    }

    _exam = exam;
    _classes = classes;
    _allSubjects = subjects;
    _examSubjects = allExamSubjects;

    // Filter exam subjects for current class
    _updateAvailableExamSubjects();

    await _loadStudentsAndMarks();

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _updateAvailableExamSubjects() {
    final forClass =
        _examSubjects.where((es) => es.classId == _selectedClassId).toList();
    if (forClass.isNotEmpty) {
      if (!forClass.any((es) => es.id == _selectedExamSubjectId)) {
        _selectedExamSubjectId = forClass.first.id;
      }
    } else {
      _selectedExamSubjectId = null;
    }
  }

  Future<void> _loadStudentsAndMarks() async {
    for (final r in _rowStates) {
      r.dispose();
    }
    _rowStates = [];

    if (_exam == null ||
        _selectedClassId == null ||
        _selectedSectionId == null) {
      return;
    }

    final studentsRepo = ref.read(studentsRepositoryProvider);
    final marksRepo = ref.read(marksRepositoryProvider);

    final students = await studentsRepo.getEnrolledStudentsForSection(
      academicYearId: _exam!.academicYearId,
      sectionId: _selectedSectionId!,
    );

    List<Mark> existingMarks = [];
    if (_selectedExamSubjectId != null) {
      existingMarks = await marksRepo.getMarksForExamSubject(
        widget.examId,
        _selectedExamSubjectId!,
      );
      _progress = await marksRepo.getMarksProgress(
        examId: widget.examId,
        examSubjectId: _selectedExamSubjectId!,
        classId: _selectedClassId!,
        sectionId: _selectedSectionId,
      );
    }

    final marksMap = {for (final m in existingMarks) m.studentId: m};
    bool anyLocked = false;

    _rowStates =
        students.map((s) {
          final mark = marksMap[s.student.id];
          if (mark?.isLocked == true) anyLocked = true;
          return _StudentMarkRowState(enrolledStudent: s, existingMark: mark);
        }).toList();

    _isAnyMarkLocked = anyLocked;
    if (mounted) setState(() {});
  }

  ExamSubject? get _currentExamSubject {
    if (_selectedExamSubjectId == null) return null;
    try {
      return _examSubjects.firstWhere((es) => es.id == _selectedExamSubjectId);
    } catch (_) {
      return null;
    }
  }

  Subject? get _currentSubject {
    final es = _currentExamSubject;
    if (es == null) return null;
    try {
      return _allSubjects.firstWhere((s) => s.id == es.subjectId);
    } catch (_) {
      return null;
    }
  }

  void _validateRow(_StudentMarkRowState row) {
    final es = _currentExamSubject;
    if (es == null) return;

    if (row.status == MarkStatus.absent ||
        row.status == MarkStatus.notAppeared) {
      row.validationError = null;
      return;
    }

    if (row.parsedTheory != null &&
        (row.parsedTheory! < 0 ||
            (es.theoryMarks != null && row.parsedTheory! > es.theoryMarks!))) {
      row.validationError = 'Theory must be 0 to ${es.theoryMarks}';
      return;
    }

    if (row.parsedPractical != null &&
        (row.parsedPractical! < 0 ||
            (es.practicalMarks != null &&
                row.parsedPractical! > es.practicalMarks!))) {
      row.validationError = 'Practical must be 0 to ${es.practicalMarks}';
      return;
    }

    if (row.parsedInternal != null &&
        (row.parsedInternal! < 0 ||
            (es.internalMarks != null &&
                row.parsedInternal! > es.internalMarks!))) {
      row.validationError = 'Internal must be 0 to ${es.internalMarks}';
      return;
    }

    final total = row.calculateTotal();
    if (total != null && total > es.fullMarks) {
      row.validationError =
          'Total ($total) exceeds full marks (${es.fullMarks})';
      return;
    }

    row.validationError = null;
  }

  Future<void> _saveMarks({
    bool isAdminOverride = false,
    String? reason,
  }) async {
    final school = ref.read(authControllerProvider).currentSchool;
    final user = ref.read(authControllerProvider).currentUser;
    final es = _currentExamSubject;
    if (school == null || user == null || es == null) return;

    // Run validation across all rows
    bool hasErrors = false;
    for (final row in _rowStates) {
      _validateRow(row);
      if (row.validationError != null) {
        hasErrors = true;
      }
    }

    if (hasErrors) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please correct marks validation errors before saving.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    final marksRepo = ref.read(marksRepositoryProvider);

    try {
      final entries =
          _rowStates.map((r) {
            return MarkInputData(
              studentId: r.enrolledStudent.student.id,
              theoryMarks: r.parsedTheory,
              practicalMarks: r.parsedPractical,
              internalMarks: r.parsedInternal,
              status: r.status,
              remarks:
                  r.remarksController.text.trim().isNotEmpty
                      ? r.remarksController.text.trim()
                      : null,
            );
          }).toList();

      if (isAdminOverride && reason != null) {
        for (final entry in entries) {
          await marksRepo.saveMark(
            schoolId: school.id,
            examId: widget.examId,
            examSubjectId: es.id,
            studentId: entry.studentId,
            theoryMarks: entry.theoryMarks,
            practicalMarks: entry.practicalMarks,
            internalMarks: entry.internalMarks,
            status: entry.status,
            remarks: 'Admin Override: $reason',
            userId: user.id,
            isAdminOverride: true,
            correctionReason: reason,
          );
        }
      } else {
        await marksRepo.saveDraftMarksBatch(
          schoolId: school.id,
          examId: widget.examId,
          examSubjectId: es.id,
          entries: entries,
          userId: user.id,
        );
      }

      await _loadStudentsAndMarks();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Marks saved locally and queued for LAN sync ✓'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving marks: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _showAdminCorrectionDialog() async {
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.lock_open, color: Colors.orange),
                SizedBox(width: 8),
                Text('Admin Marks Correction'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'These marks are locked because examination results have already been published. '
                  'Any modifications will be permanently recorded in the administrative audit trail.',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: reasonController,
                  decoration: const InputDecoration(
                    labelText: 'Reason for Correction *',
                    hintText:
                        'e.g., Re-evaluation request #104 approved by Principal',
                    prefixIcon: Icon(Icons.edit_note),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  if (reasonController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter an authorization reason.'),
                      ),
                    );
                    return;
                  }
                  Navigator.of(ctx).pop(true);
                },
                child: const Text('Authorize & Save'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      await _saveMarks(
        isAdminOverride: true,
        reason: reasonController.text.trim(),
      );
    }
  }

  void _exportCsv() {
    final es = _currentExamSubject;
    if (es == null || _rowStates.isEmpty) return;

    final csvService = const MarksCsvService();
    final students = _rowStates.map((r) => r.enrolledStudent.student).toList();
    final marks =
        _rowStates
            .where((r) => r.existingMark != null)
            .map((r) => r.existingMark!)
            .toList();

    final csvString = csvService.exportMarks(
      examSubject: es,
      students: students,
      marks: marks,
    );

    Clipboard.setData(ClipboardData(text: csvString));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Marks CSV exported and copied to clipboard!'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  Future<void> _openImportCsvDialog() async {
    final es = _currentExamSubject;
    if (es == null) return;

    final csvController = TextEditingController();
    final csvService = const MarksCsvService();
    final students = _rowStates.map((r) => r.enrolledStudent.student).toList();

    await showDialog(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder: (dialogCtx, setModalState) {
              CsvPreviewResult? preview;

              return AlertDialog(
                title: const Row(
                  children: [
                    Icon(Icons.file_upload_outlined),
                    SizedBox(width: 8),
                    Text('Import Marks from CSV'),
                  ],
                ),
                content: SizedBox(
                  width: 550,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Paste CSV content containing Student Code, Theory, Practical, Internal, Status columns.',
                        style: TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: csvController,
                        maxLines: 8,
                        decoration: const InputDecoration(
                          hintText:
                              'Student Code,Student Name,Theory,Practical,Internal,Status,Remarks\nSTD001,John Doe,65,18,9,present,Good',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (text) {
                          if (text.trim().isNotEmpty) {
                            final res = csvService.validateAndParseCsv(
                              csvContent: text,
                              examSubject: es,
                              students: students,
                            );
                            setModalState(() => preview = res);
                          }
                        },
                      ),
                      if (preview != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Preview: ${preview!.validRows.length} valid rows, ${preview!.errors.length} errors',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color:
                                preview!.hasErrors ? Colors.red : Colors.green,
                          ),
                        ),
                        if (preview!.hasErrors)
                          Container(
                            margin: const EdgeInsets.only(top: 8),
                            constraints: const BoxConstraints(maxHeight: 100),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: preview!.errors.length,
                              itemBuilder:
                                  (_, i) => Padding(
                                    padding: const EdgeInsets.all(4.0),
                                    child: Text(
                                      preview!.errors[i].toString(),
                                      style: const TextStyle(
                                        color: Colors.red,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed:
                        (preview != null && preview!.validRows.isNotEmpty)
                            ? () {
                              // Apply valid rows to row states
                              for (final valid in preview!.validRows) {
                                final matchingRow =
                                    _rowStates
                                        .where(
                                          (r) =>
                                              r.enrolledStudent.student.id ==
                                              valid.studentId,
                                        )
                                        .firstOrNull;
                                if (matchingRow != null) {
                                  matchingRow.theoryController.text =
                                      valid.theoryMarks?.toString() ?? '';
                                  matchingRow.practicalController.text =
                                      valid.practicalMarks?.toString() ?? '';
                                  matchingRow.internalController.text =
                                      valid.internalMarks?.toString() ?? '';
                                  matchingRow.status = valid.status;
                                  if (valid.remarks != null) {
                                    matchingRow.remarksController.text =
                                        valid.remarks!;
                                  }
                                }
                              }
                              setState(() {});
                              Navigator.of(ctx).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Applied ${preview!.validRows.length} rows from CSV. Press Save to persist.',
                                  ),
                                ),
                              );
                            }
                            : null,
                    child: const Text('Apply Imported Marks'),
                  ),
                ],
              );
            },
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Marks Entry')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_exam == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Marks Entry')),
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
    final availableExamSubjects =
        _examSubjects.where((es) => es.classId == _selectedClassId).toList();
    final currentES = _currentExamSubject;
    final currentSubj = _currentSubject;

    return Scaffold(
      appBar: AppBar(
        title: Text('${_exam!.name} - Marks Entry'),
        actions: [
          IconButton(
            tooltip: 'Export CSV',
            icon: const Icon(Icons.file_download_outlined),
            onPressed: _exportCsv,
          ),
          IconButton(
            tooltip: 'Import CSV',
            icon: const Icon(Icons.file_upload_outlined),
            onPressed: _openImportCsvDialog,
          ),
          const SizedBox(width: 8),
          if (_isAnyMarkLocked)
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.orange.shade800,
              ),
              icon: const Icon(Icons.lock_open, size: 18),
              label: const Text('Admin Unlock'),
              onPressed: _showAdminCorrectionDialog,
            )
          else
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
              label: const Text('Save Marks'),
              onPressed: _isSaving ? null : () => _saveMarks(),
            ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          // Filter / Selection Bar
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
            child: Wrap(
              spacing: 16,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Class Dropdown
                SizedBox(
                  width: 200,
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedClassId,
                    decoration: const InputDecoration(
                      labelText: 'Class',
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
                        _updateAvailableExamSubjects();
                      });
                      _loadStudentsAndMarks();
                    },
                  ),
                ),

                // Section Dropdown
                SizedBox(
                  width: 160,
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedSectionId,
                    decoration: const InputDecoration(
                      labelText: 'Section',
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
                      _loadStudentsAndMarks();
                    },
                  ),
                ),

                // Subject Dropdown
                SizedBox(
                  width: 240,
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedExamSubjectId,
                    decoration: const InputDecoration(
                      labelText: 'Exam Subject',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    items:
                        availableExamSubjects.map((es) {
                          final s =
                              _allSubjects
                                  .where((sub) => sub.id == es.subjectId)
                                  .firstOrNull;
                          return DropdownMenuItem(
                            value: es.id,
                            child: Text(
                              '${s?.name ?? "Subject"} (Full: ${es.fullMarks.toInt()})',
                            ),
                          );
                        }).toList(),
                    onChanged: (val) {
                      setState(() => _selectedExamSubjectId = val);
                      _loadStudentsAndMarks();
                    },
                  ),
                ),

                // Progress Indicator Badge
                if (_progress != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withValues(
                        alpha: 0.5,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Entered: ${_progress!.enteredStudents} / ${_progress!.totalStudents} (${_progress!.percentage.toStringAsFixed(0)}%)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimaryContainer,
                        fontSize: 13,
                      ),
                    ),
                  ),

                if (_isAnyMarkLocked)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock, size: 16, color: Colors.deepOrange),
                        SizedBox(width: 6),
                        Text(
                          'Results Published (Protected)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepOrange,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Main Content Table or Cards
          Expanded(
            child:
                currentES == null
                    ? const EmptyState(
                      icon: Icons.assignment_outlined,
                      title: 'No Subject Selected',
                      message:
                          'Please select an exam subject configured for this class.',
                    )
                    : _rowStates.isEmpty
                    ? const EmptyState(
                      icon: Icons.people_outline,
                      title: 'No Students Enrolled',
                      message:
                          'There are no active enrolled students in this class section.',
                    )
                    : isDesktop
                    ? _buildDesktopTable(theme, currentES, currentSubj)
                    : _buildMobileCards(theme, currentES),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopTable(ThemeData theme, ExamSubject es, Subject? subject) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Table(
        columnWidths: const {
          0: FixedColumnWidth(60), // Roll
          1: FixedColumnWidth(120), // Code
          2: FlexColumnWidth(2.5), // Name
          3: FixedColumnWidth(90), // Theory
          4: FixedColumnWidth(90), // Practical
          5: FixedColumnWidth(90), // Internal
          6: FixedColumnWidth(90), // Total
          7: FixedColumnWidth(130), // Status
          8: FlexColumnWidth(2), // Remarks
        },
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        border: TableBorder.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(8),
        ),
        children: [
          // Header
          TableRow(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.6,
              ),
            ),
            children: [
              _buildHeaderCell('Roll'),
              _buildHeaderCell('Code'),
              _buildHeaderCell('Student Name'),
              _buildHeaderCell(
                es.theoryMarks != null
                    ? 'Theory\n(${es.theoryMarks!.toInt()})'
                    : 'Theory',
              ),
              _buildHeaderCell(
                es.practicalMarks != null
                    ? 'Pract.\n(${es.practicalMarks!.toInt()})'
                    : 'Pract.',
              ),
              _buildHeaderCell(
                es.internalMarks != null
                    ? 'Intern.\n(${es.internalMarks!.toInt()})'
                    : 'Intern.',
              ),
              _buildHeaderCell('Total\n(${es.fullMarks.toInt()})'),
              _buildHeaderCell('Status'),
              _buildHeaderCell('Remarks'),
            ],
          ),

          // Student Rows
          ..._rowStates.map((row) {
            final isAbsent =
                row.status == MarkStatus.absent ||
                row.status == MarkStatus.notAppeared;
            final isLocked = row.existingMark?.isLocked == true;
            final total = row.calculateTotal();

            return TableRow(
              decoration: BoxDecoration(
                color:
                    row.validationError != null
                        ? Colors.red.withValues(alpha: 0.05)
                        : (isAbsent
                            ? Colors.grey.withValues(alpha: 0.08)
                            : null),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  child: Text(
                    row.enrolledStudent.enrollment.rollNumber?.toString() ??
                        '-',
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  child: Text(
                    row.enrolledStudent.student.studentCode,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.enrolledStudent.fullName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if (row.validationError != null)
                        Text(
                          row.validationError!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ),

                // Theory Input
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 4,
                  ),
                  child: TextField(
                    controller: row.theoryController,
                    enabled: !isAbsent && !isLocked,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      border: const OutlineInputBorder(),
                      errorText: null,
                    ),
                    onChanged: (_) {
                      setState(() {
                        _validateRow(row);
                      });
                    },
                  ),
                ),

                // Practical Input
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 4,
                  ),
                  child: TextField(
                    controller: row.practicalController,
                    enabled: !isAbsent && !isLocked,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) {
                      setState(() {
                        _validateRow(row);
                      });
                    },
                  ),
                ),

                // Internal Input
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 4,
                  ),
                  child: TextField(
                    controller: row.internalController,
                    enabled: !isAbsent && !isLocked,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) {
                      setState(() {
                        _validateRow(row);
                      });
                    },
                  ),
                ),

                // Total Display
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  child: Text(
                    isAbsent
                        ? row.status.value.toUpperCase()
                        : (total?.toStringAsFixed(1) ?? '-'),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color:
                          isAbsent
                              ? Colors.red
                              : (total != null && total >= es.passMarks
                                  ? Colors.green.shade800
                                  : Colors.black),
                    ),
                  ),
                ),

                // Status Dropdown
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 4,
                  ),
                  child: DropdownButtonFormField<MarkStatus>(
                    initialValue: row.status,
                    isDense: true,
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 6,
                      ),
                      border: OutlineInputBorder(),
                    ),
                    items:
                        MarkStatus.values.map((st) {
                          return DropdownMenuItem(
                            value: st,
                            child: Text(
                              st.name.toUpperCase(),
                              style: const TextStyle(fontSize: 11),
                            ),
                          );
                        }).toList(),
                    onChanged:
                        isLocked
                            ? null
                            : (newStatus) {
                              if (newStatus != null) {
                                setState(() {
                                  row.status = newStatus;
                                  _validateRow(row);
                                });
                              }
                            },
                  ),
                ),

                // Remarks Input
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 4,
                  ),
                  child: TextField(
                    controller: row.remarksController,
                    enabled: !isLocked,
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }

  Widget _buildMobileCards(ThemeData theme, ExamSubject es) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _rowStates.length,
      itemBuilder: (context, index) {
        final row = _rowStates[index];
        final isAbsent =
            row.status == MarkStatus.absent ||
            row.status == MarkStatus.notAppeared;
        final total = row.calculateTotal();

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      child: Text(
                        row.enrolledStudent.enrollment.rollNumber?.toString() ??
                            '${index + 1}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            row.enrolledStudent.fullName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Code: ${row.enrolledStudent.student.studentCode}',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      isAbsent
                          ? row.status.value.toUpperCase()
                          : (total != null
                              ? '$total / ${es.fullMarks.toInt()}'
                              : '-'),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isAbsent ? Colors.red : Colors.green.shade800,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 16),
                Wrap(
                  spacing: 6,
                  children:
                      [
                        MarkStatus.present,
                        MarkStatus.absent,
                        MarkStatus.medical,
                        MarkStatus.exempt,
                      ].map((s) {
                        final isSelected = row.status == s;
                        return ChoiceChip(
                          label: Text(
                            s.name.toUpperCase(),
                            style: const TextStyle(fontSize: 10),
                          ),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                row.status = s;
                                _validateRow(row);
                              });
                            }
                          },
                        );
                      }).toList(),
                ),
                if (!isAbsent) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (es.theoryMarks != null)
                        Expanded(
                          child: TextField(
                            controller: row.theoryController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Theory (${es.theoryMarks!.toInt()})',
                              isDense: true,
                            ),
                            onChanged: (_) => setState(() => _validateRow(row)),
                          ),
                        ),
                      if (es.practicalMarks != null) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: row.practicalController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText:
                                  'Pract. (${es.practicalMarks!.toInt()})',
                              isDense: true,
                            ),
                            onChanged: (_) => setState(() => _validateRow(row)),
                          ),
                        ),
                      ],
                      if (es.internalMarks != null) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: row.internalController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText:
                                  'Intern. (${es.internalMarks!.toInt()})',
                              isDense: true,
                            ),
                            onChanged: (_) => setState(() => _validateRow(row)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
                if (row.validationError != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    row.validationError!,
                    style: const TextStyle(color: Colors.red, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
