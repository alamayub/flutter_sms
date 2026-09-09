// lib/features/exams/presentation/exams_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/database/app_database.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../academic_year/data/academic_year_repository.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../data/exams_repository.dart';
import '../domain/exam_models.dart';

class ExamsScreen extends ConsumerStatefulWidget {
  const ExamsScreen({super.key});

  @override
  ConsumerState<ExamsScreen> createState() => _ExamsScreenState();
}

class _ExamsScreenState extends ConsumerState<ExamsScreen> {
  bool _isLoading = true;
  List<Exam> _exams = [];
  List<AcademicYear> _academicYears = [];
  String? _selectedYearId;
  ExamStatus? _selectedStatus;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final school = ref.read(authControllerProvider).currentSchool;
    if (school == null) return;

    final academicRepo = ref.read(academicYearRepositoryProvider);
    final examsRepo = ref.read(examsRepositoryProvider);

    final years = await academicRepo.getAcademicYears(school.id);
    final currentYear = await academicRepo.getCurrentAcademicYear(school.id);

    _selectedYearId ??=
        currentYear?.id ?? (years.isNotEmpty ? years.first.id : null);
    var exams = await examsRepo.getExams(
      schoolId: school.id,
      academicYearId: _selectedYearId,
    );

    if (_selectedStatus != null) {
      exams = exams.where((e) => e.status == _selectedStatus!.value).toList();
    }

    if (mounted) {
      setState(() {
        _academicYears = years;
        _exams = exams;
        _isLoading = false;
      });
    }
  }

  Future<void> _openCreateOrEditExamDialog([Exam? exam]) async {
    final school = ref.read(authControllerProvider).currentSchool;
    final currentUser = ref.read(authControllerProvider).currentUser;
    if (school == null || currentUser == null) return;

    final isEditing = exam != null;
    final nameController = TextEditingController(text: exam?.name ?? '');
    final descController = TextEditingController(text: exam?.description ?? '');
    final weightController = TextEditingController(
      text: exam?.weight.toString() ?? '1.0',
    );

    String academicYearId =
        exam?.academicYearId ??
        _selectedYearId ??
        (_academicYears.isNotEmpty ? _academicYears.first.id : '');
    ExamStatus status =
        exam != null ? ExamStatus.fromString(exam.status) : ExamStatus.draft;
    DateTime startDate = exam?.startDate ?? DateTime.now();
    DateTime endDate =
        exam?.endDate ?? DateTime.now().add(const Duration(days: 7));

    final result = await showDialog<bool>(
      context: context,
      builder:
          (dialogCtx) => StatefulBuilder(
            builder: (ctx, setDialogState) {
              return AlertDialog(
                title: Text(
                  isEditing ? 'Edit Examination' : 'Create Examination',
                ),
                content: SingleChildScrollView(
                  child: SizedBox(
                    width: 480,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: nameController,
                          decoration: const InputDecoration(
                            labelText: 'Examination Name *',
                            hintText: 'e.g., First Term Examination 2026',
                            prefixIcon: Icon(Icons.edit_document),
                          ),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue:
                              academicYearId.isNotEmpty ? academicYearId : null,
                          decoration: const InputDecoration(
                            labelText: 'Academic Year *',
                            prefixIcon: Icon(Icons.calendar_today),
                          ),
                          items:
                              _academicYears.map((ay) {
                                return DropdownMenuItem(
                                  value: ay.id,
                                  child: Text(ay.name),
                                );
                              }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() => academicYearId = val);
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: ctx,
                                    initialDate: startDate,
                                    firstDate: DateTime(2000),
                                    lastDate: DateTime(2100),
                                  );
                                  if (picked != null) {
                                    setDialogState(() => startDate = picked);
                                  }
                                },
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                    labelText: 'Start Date *',
                                    prefixIcon: Icon(Icons.date_range),
                                  ),
                                  child: Text(
                                    DateFormat.yMMMd().format(startDate),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: InkWell(
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: ctx,
                                    initialDate:
                                        endDate.isBefore(startDate)
                                            ? startDate
                                            : endDate,
                                    firstDate: startDate,
                                    lastDate: DateTime(2100),
                                  );
                                  if (picked != null) {
                                    setDialogState(() => endDate = picked);
                                  }
                                },
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                    labelText: 'End Date *',
                                    prefixIcon: Icon(Icons.event),
                                  ),
                                  child: Text(
                                    DateFormat.yMMMd().format(endDate),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: weightController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: const InputDecoration(
                                  labelText: 'Term Weight',
                                  hintText: '1.0',
                                  prefixIcon: Icon(Icons.scale),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<ExamStatus>(
                                initialValue: status,
                                decoration: const InputDecoration(
                                  labelText: 'Status',
                                  prefixIcon: Icon(Icons.flag_outlined),
                                ),
                                items:
                                    ExamStatus.values.map((s) {
                                      return DropdownMenuItem(
                                        value: s,
                                        child: Text(s.displayName),
                                      );
                                    }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setDialogState(() => status = val);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: descController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Description / Remarks',
                            hintText: 'Optional instructions or guidelines',
                            prefixIcon: Icon(Icons.notes),
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
                      final name = nameController.text.trim();
                      if (name.isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter an exam name'),
                          ),
                        );
                        return;
                      }
                      if (academicYearId.isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                            content: Text('Please select an academic year'),
                          ),
                        );
                        return;
                      }

                      final weight =
                          double.tryParse(weightController.text) ?? 1.0;
                      final examsRepo = ref.read(examsRepositoryProvider);

                      if (isEditing) {
                        await examsRepo.updateExam(
                          examId: exam.id,
                          name: name,
                          description: descController.text.trim(),
                          startDate: startDate,
                          endDate: endDate,
                          status: status,
                          weight: weight,
                          userId: currentUser.id,
                        );
                      } else {
                        await examsRepo.createExam(
                          schoolId: school.id,
                          academicYearId: academicYearId,
                          name: name,
                          description: descController.text.trim(),
                          startDate: startDate,
                          endDate: endDate,
                          status: status,
                          weight: weight,
                          userId: currentUser.id,
                        );
                      }

                      if (ctx.mounted) Navigator.of(ctx).pop(true);
                    },
                    child: Text(isEditing ? 'Save Changes' : 'Create Exam'),
                  ),
                ],
              );
            },
          ),
    );

    if (result == true) {
      _loadData();
    }
  }

  Future<void> _deleteExam(Exam exam) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Delete Examination?'),
            content: Text(
              'Are you sure you want to delete "${exam.name}"? All associated marks and results will be archived.',
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
                child: const Text('Delete'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      final user = ref.read(authControllerProvider).currentUser;
      if (user != null) {
        await ref
            .read(examsRepositoryProvider)
            .archiveExam(examId: exam.id, userId: user.id);
        _loadData();
      }
    }
  }

  Color _getStatusColor(ExamStatus status) {
    switch (status) {
      case ExamStatus.draft:
        return Colors.grey.shade600;
      case ExamStatus.scheduled:
        return Colors.blue.shade700;
      case ExamStatus.inProgress:
        return Colors.orange.shade700;
      case ExamStatus.marksEntry:
        return Colors.amber.shade800;
      case ExamStatus.verification:
        return Colors.purple.shade700;
      case ExamStatus.published:
        return Colors.green.shade700;
      case ExamStatus.archived:
        return Colors.red.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Examinations'),
        actions: [
          FilledButton.icon(
            onPressed: () => _openCreateOrEditExamDialog(),
            icon: const Icon(Icons.add),
            label: const Text('New Exam'),
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
                  flex: 2,
                  child: DropdownButtonFormField<String?>(
                    initialValue: _selectedYearId,
                    decoration: const InputDecoration(
                      labelText: 'Academic Year',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('All Academic Years'),
                      ),
                      ..._academicYears.map(
                        (ay) => DropdownMenuItem(
                          value: ay.id,
                          child: Text(ay.name),
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      setState(() => _selectedYearId = val);
                      _loadData();
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<ExamStatus?>(
                    initialValue: _selectedStatus,
                    decoration: const InputDecoration(
                      labelText: 'Status Filter',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('All Statuses'),
                      ),
                      ...ExamStatus.values.map(
                        (s) => DropdownMenuItem(
                          value: s,
                          child: Text(s.displayName),
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      setState(() => _selectedStatus = val);
                      _loadData();
                    },
                  ),
                ),
                const SizedBox(width: 16),
                IconButton(
                  tooltip: 'Refresh',
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadData,
                ),
              ],
            ),
          ),

          // Main List / Cards
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _exams.isEmpty
                    ? const EmptyState(
                      icon: Icons.quiz_outlined,
                      title: 'No Examinations Found',
                      message:
                          'Create an examination to configure subjects, record marks, and publish reports.',
                    )
                    : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _exams.length,
                      itemBuilder: (context, index) {
                        final exam = _exams[index];
                        final status = ExamStatus.fromString(exam.status);
                        final statusColor = _getStatusColor(status);
                        final ayName =
                            _academicYears
                                .firstWhere(
                                  (ay) => ay.id == exam.academicYearId,
                                  orElse:
                                      () => AcademicYear(
                                        id: '',
                                        schoolId: '',
                                        name: 'Unknown Year',
                                        startDate: DateTime.now(),
                                        endDate: DateTime.now(),
                                        isCurrent: false,
                                        isArchived: false,
                                        createdAt: DateTime.now(),
                                        updatedAt: DateTime.now(),
                                      ),
                                )
                                .name;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          elevation: 1.5,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CircleAvatar(
                                      radius: 24,
                                      backgroundColor: statusColor.withValues(
                                        alpha: 0.12,
                                      ),
                                      child: Icon(
                                        Icons.assignment,
                                        color: statusColor,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  exam.name,
                                                  style: theme
                                                      .textTheme
                                                      .titleMedium
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                ),
                                              ),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: statusColor.withValues(
                                                    alpha: 0.12,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                  border: Border.all(
                                                    color: statusColor
                                                        .withValues(alpha: 0.3),
                                                  ),
                                                ),
                                                child: Text(
                                                  status.displayName
                                                      .toUpperCase(),
                                                  style: TextStyle(
                                                    color: statusColor,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              PopupMenuButton<String>(
                                                onSelected: (val) {
                                                  if (val == 'edit') {
                                                    _openCreateOrEditExamDialog(
                                                      exam,
                                                    );
                                                  } else if (val == 'delete') {
                                                    _deleteExam(exam);
                                                  }
                                                },
                                                itemBuilder:
                                                    (ctx) => [
                                                      const PopupMenuItem(
                                                        value: 'edit',
                                                        child: Row(
                                                          children: [
                                                            Icon(
                                                              Icons
                                                                  .edit_outlined,
                                                              size: 20,
                                                            ),
                                                            SizedBox(width: 8),
                                                            Text(
                                                              'Edit Details',
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      const PopupMenuItem(
                                                        value: 'delete',
                                                        child: Row(
                                                          children: [
                                                            Icon(
                                                              Icons
                                                                  .delete_outline,
                                                              color: Colors.red,
                                                              size: 20,
                                                            ),
                                                            SizedBox(width: 8),
                                                            Text(
                                                              'Delete Exam',
                                                              style: TextStyle(
                                                                color:
                                                                    Colors.red,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            '$ayName  •  ${DateFormat.yMMMd().format(exam.startDate)} - ${DateFormat.yMMMd().format(exam.endDate)}  •  Weight: ${exam.weight}x',
                                            style: theme.textTheme.bodyMedium
                                                ?.copyWith(
                                                  color:
                                                      theme
                                                          .colorScheme
                                                          .onSurfaceVariant,
                                                ),
                                          ),
                                          if (exam.description != null &&
                                              exam.description!.isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              exam.description!,
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                    fontStyle: FontStyle.italic,
                                                  ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 24),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: [
                                    OutlinedButton.icon(
                                      icon: const Icon(
                                        Icons.settings_outlined,
                                        size: 18,
                                      ),
                                      label: const Text('Setup Subjects'),
                                      onPressed:
                                          () => context.push(
                                            '/exam-setup?examId=${exam.id}',
                                          ),
                                    ),
                                    FilledButton.tonalIcon(
                                      icon: const Icon(
                                        Icons.edit_note,
                                        size: 18,
                                      ),
                                      label: const Text('Marks Entry'),
                                      onPressed:
                                          () => context.push(
                                            '/marks-entry?examId=${exam.id}',
                                          ),
                                    ),
                                    FilledButton.icon(
                                      icon: const Icon(
                                        Icons.insights,
                                        size: 18,
                                      ),
                                      label: const Text('Results & Publishing'),
                                      onPressed:
                                          () => context.push(
                                            '/results?examId=${exam.id}',
                                          ),
                                    ),
                                    IconButton.outlined(
                                      tooltip: 'Generate Report Cards',
                                      icon: const Icon(
                                        Icons.picture_as_pdf_outlined,
                                      ),
                                      onPressed:
                                          () => context.push(
                                            '/report-cards?examId=${exam.id}',
                                          ),
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
