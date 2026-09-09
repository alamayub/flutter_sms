// lib/features/exams/presentation/exam_setup_screen.dart
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../../classes/data/classes_repository.dart';
import '../../subjects/data/subjects_repository.dart';
import '../data/exams_repository.dart';

class ExamSetupScreen extends ConsumerStatefulWidget {
  final String examId;

  const ExamSetupScreen({super.key, required this.examId});

  @override
  ConsumerState<ExamSetupScreen> createState() => _ExamSetupScreenState();
}

class _ExamSetupScreenState extends ConsumerState<ExamSetupScreen> {
  bool _isLoading = true;
  Exam? _exam;
  List<ClassWithSections> _classes = [];
  List<Subject> _allSubjects = [];
  String? _selectedClassId;
  List<ExamSubject> _examSubjects = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
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

    _selectedClassId = classes.isNotEmpty ? classes.first.schoolClass.id : null;
    List<ExamSubject> examSubjects = [];
    if (_selectedClassId != null) {
      examSubjects = await examsRepo.getExamSubjects(
        examId: widget.examId,
        classId: _selectedClassId,
      );
    }

    if (mounted) {
      setState(() {
        _exam = exam;
        _classes = classes;
        _allSubjects = subjects;
        _examSubjects = examSubjects;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadExamSubjects() async {
    if (_selectedClassId == null) return;
    final examsRepo = ref.read(examsRepositoryProvider);
    final examSubjects = await examsRepo.getExamSubjects(
      examId: widget.examId,
      classId: _selectedClassId,
    );
    if (mounted) {
      setState(() => _examSubjects = examSubjects);
    }
  }

  Future<void> _openConfigureSubjectDialog([ExamSubject? existing]) async {
    final school = ref.read(authControllerProvider).currentSchool;
    final user = ref.read(authControllerProvider).currentUser;
    if (school == null || user == null || _selectedClassId == null) return;

    final isEditing = existing != null;
    String subjectId =
        existing?.subjectId ??
        (_allSubjects.isNotEmpty ? _allSubjects.first.id : '');
    final fullMarksController = TextEditingController(
      text: existing?.fullMarks.toString() ?? '100.0',
    );
    final passMarksController = TextEditingController(
      text: existing?.passMarks.toString() ?? '40.0',
    );
    final theoryController = TextEditingController(
      text: existing?.theoryMarks?.toString() ?? '70.0',
    );
    final practicalController = TextEditingController(
      text: existing?.practicalMarks?.toString() ?? '20.0',
    );
    final internalController = TextEditingController(
      text: existing?.internalMarks?.toString() ?? '10.0',
    );
    final creditHoursController = TextEditingController(
      text: existing?.creditHours?.toString() ?? '3.0',
    );

    final result = await showDialog<bool>(
      context: context,
      builder:
          (dialogCtx) => StatefulBuilder(
            builder: (ctx, setDialogState) {
              return AlertDialog(
                title: Text(
                  isEditing ? 'Edit Exam Subject' : 'Add Subject to Exam',
                ),
                content: SingleChildScrollView(
                  child: SizedBox(
                    width: 480,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: subjectId.isNotEmpty ? subjectId : null,
                          decoration: const InputDecoration(
                            labelText: 'Subject *',
                            prefixIcon: Icon(Icons.book_outlined),
                          ),
                          items:
                              _allSubjects.map((s) {
                                return DropdownMenuItem(
                                  value: s.id,
                                  child: Text('${s.name} (${s.code})'),
                                );
                              }).toList(),
                          onChanged:
                              isEditing
                                  ? null
                                  : (val) {
                                    if (val != null) {
                                      setDialogState(() => subjectId = val);
                                    }
                                  },
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: fullMarksController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: const InputDecoration(
                                  labelText: 'Full Marks *',
                                  hintText: '100',
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: passMarksController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: const InputDecoration(
                                  labelText: 'Pass Marks *',
                                  hintText: '40',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Assessment Component Breakdown (Optional)',
                          style: Theme.of(ctx).textTheme.labelMedium?.copyWith(
                            color: Theme.of(ctx).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: theoryController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: const InputDecoration(
                                  labelText: 'Theory Marks',
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: practicalController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: const InputDecoration(
                                  labelText: 'Practical Marks',
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: internalController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: const InputDecoration(
                                  labelText: 'Internal Marks',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: creditHoursController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Credit Hours (for GPA weighting)',
                            hintText: '3.0',
                            prefixIcon: Icon(Icons.stars_outlined),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () async {
                      if (subjectId.isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                            content: Text('Please select a subject'),
                          ),
                        );
                        return;
                      }

                      final fullMarks = double.tryParse(
                        fullMarksController.text,
                      );
                      final passMarks = double.tryParse(
                        passMarksController.text,
                      );
                      if (fullMarks == null || fullMarks <= 0) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter valid full marks'),
                          ),
                        );
                        return;
                      }
                      if (passMarks == null ||
                          passMarks < 0 ||
                          passMarks > fullMarks) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Pass marks must be between 0 and full marks',
                            ),
                          ),
                        );
                        return;
                      }

                      final theory = double.tryParse(theoryController.text);
                      final practical = double.tryParse(
                        practicalController.text,
                      );
                      final internal = double.tryParse(internalController.text);
                      final creditHours = double.tryParse(
                        creditHoursController.text,
                      );

                      final componentsSum =
                          (theory ?? 0) + (practical ?? 0) + (internal ?? 0);
                      if (componentsSum > 0 && componentsSum > fullMarks) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Components sum ($componentsSum) exceeds full marks ($fullMarks)',
                            ),
                          ),
                        );
                        return;
                      }

                      final examsRepo = ref.read(examsRepositoryProvider);
                      await examsRepo.configureExamSubject(
                        schoolId: school.id,
                        examId: widget.examId,
                        classId: _selectedClassId!,
                        subjectId: subjectId,
                        fullMarks: fullMarks,
                        passMarks: passMarks,
                        theoryMarks: theory,
                        practicalMarks: practical,
                        internalMarks: internal,
                        creditHours: creditHours,
                        userId: user.id,
                      );

                      if (ctx.mounted) Navigator.of(ctx).pop(true);
                    },
                    child: Text(isEditing ? 'Save Changes' : 'Add Subject'),
                  ),
                ],
              );
            },
          ),
    );

    if (result == true) {
      _loadExamSubjects();
    }
  }

  Future<void> _deleteSubject(ExamSubject item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Remove Subject from Exam?'),
            content: const Text(
              'Are you sure you want to remove this subject? Entered marks for this subject will be removed.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(ctx).colorScheme.error,
                ),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Remove'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      final user = ref.read(authControllerProvider).currentUser;
      if (user != null) {
        await ref
            .read(examsRepositoryProvider)
            .deleteExamSubject(id: item.id, userId: user.id);
        _loadExamSubjects();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Exam Setup')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_exam == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Exam Setup')),
        body: const EmptyState(
          icon: Icons.error_outline,
          title: 'Exam Not Found',
          message: 'The requested examination could not be loaded.',
        ),
      );
    }

    final subjectMap = {for (final s in _allSubjects) s.id: s};

    return Scaffold(
      appBar: AppBar(
        title: Text('${_exam!.name} - Subjects Setup'),
        actions: [
          if (_selectedClassId != null)
            FilledButton.icon(
              onPressed: () => _openConfigureSubjectDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Add Subject'),
            ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          // Class Selector Bar
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
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedClassId,
                    decoration: const InputDecoration(
                      labelText: 'Select Class',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      prefixIcon: Icon(Icons.class_outlined),
                    ),
                    items:
                        _classes.map((c) {
                          return DropdownMenuItem(
                            value: c.schoolClass.id,
                            child: Text(c.schoolClass.name),
                          );
                        }).toList(),
                    onChanged: (val) {
                      setState(() => _selectedClassId = val);
                      _loadExamSubjects();
                    },
                  ),
                ),
                const SizedBox(width: 16),
                IconButton(
                  tooltip: 'Reload',
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadExamSubjects,
                ),
              ],
            ),
          ),

          // Subjects Table / List
          Expanded(
            child:
                _examSubjects.isEmpty
                    ? EmptyState(
                      icon: Icons.menu_book_outlined,
                      title: 'No Subjects Configured',
                      message:
                          'Add subjects to configure full marks, pass marks, and theory/practical breakdown for this class.',
                      actionLabel: 'Add Subject',
                      onAction: () => _openConfigureSubjectDialog(),
                    )
                    : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _examSubjects.length,
                      separatorBuilder:
                          (ctx, idx) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final item = _examSubjects[index];
                        final subject = subjectMap[item.subjectId];
                        final subjectName = subject?.name ?? 'Unknown Subject';
                        final subjectCode = subject?.code ?? '---';

                        return Card(
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor:
                                      theme.colorScheme.primaryContainer,
                                  child: Text(
                                    subjectCode.isNotEmpty
                                        ? subjectCode.substring(0, 1)
                                        : 'S',
                                    style: TextStyle(
                                      color:
                                          theme.colorScheme.onPrimaryContainer,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  flex: 3,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        subjectName,
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Code: $subjectCode  •  Credits: ${item.creditHours ?? 1.0}',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color:
                                                  theme
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  flex: 4,
                                  child: Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: [
                                      Chip(
                                        label: Text(
                                          'Full: ${item.fullMarks.toInt()}',
                                        ),
                                        padding: EdgeInsets.zero,
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      Chip(
                                        label: Text(
                                          'Pass: ${item.passMarks.toInt()}',
                                        ),
                                        padding: EdgeInsets.zero,
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      if (item.theoryMarks != null)
                                        Chip(
                                          label: Text(
                                            'Theory: ${item.theoryMarks!.toInt()}',
                                          ),
                                          padding: EdgeInsets.zero,
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      if (item.practicalMarks != null)
                                        Chip(
                                          label: Text(
                                            'Practical: ${item.practicalMarks!.toInt()}',
                                          ),
                                          padding: EdgeInsets.zero,
                                          visualDensity: VisualDensity.compact,
                                        ),
                                    ],
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined),
                                      tooltip: 'Edit Subject',
                                      onPressed:
                                          () =>
                                              _openConfigureSubjectDialog(item),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: Colors.red,
                                      ),
                                      tooltip: 'Remove',
                                      onPressed: () => _deleteSubject(item),
                                    ),
                                  ],
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
