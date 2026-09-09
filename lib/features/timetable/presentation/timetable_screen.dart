// lib/features/timetable/presentation/timetable_screen.dart
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/database/app_database.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../academic_year/data/academic_year_repository.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../../classes/data/classes_repository.dart';
import '../../subjects/data/subjects_repository.dart';
import '../../teachers/data/teachers_repository.dart';
import '../data/timetable_repository.dart';

class TimetableScreen extends ConsumerStatefulWidget {
  const TimetableScreen({super.key});

  @override
  ConsumerState<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends ConsumerState<TimetableScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  AcademicYear? _currentYear;
  List<ClassWithSections> _classesWithSections = [];
  List<Teacher> _teachers = [];
  List<Subject> _subjects = [];

  String? _selectedClassId;
  String? _selectedSectionId;
  String? _selectedTeacherId;

  List<TimetableEntryDetail> _currentEntries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _loadTimetableEntries();
      }
    });
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    final school = ref.read(authControllerProvider).currentSchool;
    final user = ref.read(authControllerProvider).currentUser;
    if (school == null) return;

    final academicRepo = ref.read(academicYearRepositoryProvider);
    final currentYear = await academicRepo.getCurrentAcademicYear(school.id);

    List<ClassWithSections> classes = [];
    if (currentYear != null) {
      final classesRepo = ref.read(classesRepositoryProvider);
      classes = await classesRepo.getClassesWithSections(
        schoolId: school.id,
        academicYearId: currentYear.id,
      );
    }

    final teachersRepo = ref.read(teachersRepositoryProvider);
    final teachers = await teachersRepo.getTeachers(school.id);

    final subjectsRepo = ref.read(subjectsRepositoryProvider);
    final subjects = await subjectsRepo.getSubjects(school.id);

    Teacher? matchedTeacher;
    if (user?.role == UserRole.teacher) {
      matchedTeacher = teachers.where((t) => t.userId == user!.id).firstOrNull;
    }

    if (mounted) {
      setState(() {
        _currentYear = currentYear;
        _classesWithSections = classes;
        _teachers = teachers;
        _subjects = subjects;

        if (classes.isNotEmpty) {
          _selectedClassId = classes.first.schoolClass.id;
          if (classes.first.sections.isNotEmpty) {
            _selectedSectionId = classes.first.sections.first.id;
          }
        }

        _selectedTeacherId =
            matchedTeacher?.id ??
            (teachers.isNotEmpty ? teachers.first.id : null);
      });

      await _loadTimetableEntries();
    }
  }

  Future<void> _loadTimetableEntries() async {
    final timetableRepo = ref.read(timetableRepositoryProvider);
    List<TimetableEntryDetail> entries = [];

    if (_tabController.index == 0) {
      // Class View
      if (_selectedSectionId != null) {
        entries = await timetableRepo.getTimetableForSection(
          _selectedSectionId!,
        );
      }
    } else {
      // Teacher View
      if (_selectedTeacherId != null && _currentYear != null) {
        entries = await timetableRepo.getTimetableForTeacher(
          _selectedTeacherId!,
          academicYearId: _currentYear!.id,
        );
      }
    }

    if (mounted) {
      setState(() {
        _currentEntries = entries;
        _isLoading = false;
      });
    }
  }

  void _showAddEntryDialog() {
    if (_currentYear == null ||
        _selectedClassId == null ||
        _selectedSectionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a class and section first.'),
        ),
      );
      return;
    }

    int dayOfWeek = DayOfWeek.monday;
    int period = 1;
    String? subjectId = _subjects.isNotEmpty ? _subjects.first.id : null;
    String? teacherId = _teachers.isNotEmpty ? _teachers.first.id : null;
    final startController = TextEditingController(text: '09:00');
    final endController = TextEditingController(text: '09:45');
    final roomController = TextEditingController(text: 'Room 101');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: const Text('Add Timetable Period'),
                  content: Form(
                    key: formKey,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          DropdownButtonFormField<int>(
                            initialValue: dayOfWeek,
                            decoration: const InputDecoration(
                              labelText: 'Day of Week',
                            ),
                            items:
                                DayOfWeek.schoolDays.map((d) {
                                  return DropdownMenuItem(
                                    value: d,
                                    child: Text(DayOfWeek.getName(d)),
                                  );
                                }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setDialogState(() => dayOfWeek = val);
                              }
                            },
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<int>(
                            initialValue: period,
                            decoration: const InputDecoration(
                              labelText: 'Period Number',
                            ),
                            items:
                                List.generate(8, (i) => i + 1).map((p) {
                                  return DropdownMenuItem(
                                    value: p,
                                    child: Text('Period $p'),
                                  );
                                }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setDialogState(() => period = val);
                              }
                            },
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String?>(
                            initialValue: subjectId,
                            decoration: const InputDecoration(
                              labelText: 'Subject *',
                            ),
                            items:
                                _subjects.map((s) {
                                  return DropdownMenuItem(
                                    value: s.id,
                                    child: Text('${s.name} (${s.code})'),
                                  );
                                }).toList(),
                            validator:
                                (v) => v == null ? 'Subject required' : null,
                            onChanged:
                                (val) => setDialogState(() => subjectId = val),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String?>(
                            initialValue: teacherId,
                            decoration: const InputDecoration(
                              labelText: 'Teacher (Optional)',
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text('Unassigned'),
                              ),
                              ..._teachers.map((t) {
                                return DropdownMenuItem(
                                  value: t.id,
                                  child: Text('${t.name} (${t.employeeCode})'),
                                );
                              }),
                            ],
                            onChanged:
                                (val) => setDialogState(() => teacherId = val),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: startController,
                                  decoration: const InputDecoration(
                                    labelText: 'Start Time *',
                                    hintText: '09:00',
                                  ),
                                  validator:
                                      (v) =>
                                          v == null || v.isEmpty
                                              ? 'Required'
                                              : null,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextFormField(
                                  controller: endController,
                                  decoration: const InputDecoration(
                                    labelText: 'End Time *',
                                    hintText: '09:45',
                                  ),
                                  validator:
                                      (v) =>
                                          v == null || v.isEmpty
                                              ? 'Required'
                                              : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: roomController,
                            decoration: const InputDecoration(
                              labelText: 'Room / Location',
                              hintText: 'Room 101 / Science Lab',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) return;
                        final school =
                            ref.read(authControllerProvider).currentSchool;
                        if (school == null || _currentYear == null) return;

                        final timetableRepo = ref.read(
                          timetableRepositoryProvider,
                        );
                        try {
                          await timetableRepo.createEntry(
                            schoolId: school.id,
                            academicYearId: _currentYear!.id,
                            classId: _selectedClassId!,
                            sectionId: _selectedSectionId!,
                            dayOfWeek: dayOfWeek,
                            period: period,
                            subjectId: subjectId!,
                            teacherId: teacherId,
                            startTime: startController.text.trim(),
                            endTime: endController.text.trim(),
                            room:
                                roomController.text.trim().isNotEmpty
                                    ? roomController.text.trim()
                                    : null,
                            currentUserId:
                                ref
                                    .read(authControllerProvider)
                                    .currentUser
                                    ?.id,
                          );

                          await _loadTimetableEntries();
                          if (ctx.mounted) Navigator.pop(ctx);
                        } catch (e) {
                          if (context.mounted) {
                            showDialog(
                              context: context,
                              builder:
                                  (errCtx) => AlertDialog(
                                    title: const Row(
                                      children: [
                                        Icon(
                                          Icons.warning_amber,
                                          color: AppColors.danger,
                                        ),
                                        SizedBox(width: 8),
                                        Text('Schedule Conflict Detected'),
                                      ],
                                    ),
                                    content: Text(
                                      e.toString(),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        height: 1.4,
                                      ),
                                    ),
                                    actions: [
                                      ElevatedButton(
                                        onPressed: () => Navigator.pop(errCtx),
                                        child: const Text('OK'),
                                      ),
                                    ],
                                  ),
                            );
                          }
                        }
                      },
                      child: const Text('Add Period'),
                    ),
                  ],
                ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final school = ref.watch(authControllerProvider).currentSchool;
    if (school == null) {
      return const Scaffold(body: Center(child: Text('No school selected')));
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('School Timetable'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.meeting_room, size: 18), text: 'Class View'),
            Tab(icon: Icon(Icons.badge, size: 18), text: 'Teacher View'),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              onPressed: _showAddEntryDialog,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Period'),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter selector bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            color: Colors.white,
            child:
                _tabController.index == 0
                    ? _buildClassViewFilter()
                    : _buildTeacherViewFilter(),
          ),
          const Divider(height: 1),

          // Timetable Grid by Day
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _buildWeeklyScheduleView(),
          ),
        ],
      ),
    );
  }

  Widget _buildClassViewFilter() {
    final currentClassSections =
        _classesWithSections
            .where((c) => c.schoolClass.id == _selectedClassId)
            .firstOrNull
            ?.sections ??
        [];

    return Row(
      children: [
        const Text('Class: ', style: TextStyle(fontWeight: FontWeight.bold)),
        DropdownButton<String?>(
          value: _selectedClassId,
          underline: const SizedBox.shrink(),
          items:
              _classesWithSections.map((c) {
                return DropdownMenuItem(
                  value: c.schoolClass.id,
                  child: Text(c.schoolClass.name),
                );
              }).toList(),
          onChanged: (val) {
            setState(() {
              _selectedClassId = val;
              final secs =
                  _classesWithSections
                      .where((c) => c.schoolClass.id == val)
                      .firstOrNull
                      ?.sections ??
                  [];
              _selectedSectionId = secs.isNotEmpty ? secs.first.id : null;
            });
            _loadTimetableEntries();
          },
        ),
        const SizedBox(width: 24),
        const Text('Section: ', style: TextStyle(fontWeight: FontWeight.bold)),
        DropdownButton<String?>(
          value: _selectedSectionId,
          underline: const SizedBox.shrink(),
          items:
              currentClassSections.map((s) {
                return DropdownMenuItem(value: s.id, child: Text(s.name));
              }).toList(),
          onChanged: (val) {
            setState(() => _selectedSectionId = val);
            _loadTimetableEntries();
          },
        ),
      ],
    );
  }

  Widget _buildTeacherViewFilter() {
    return Row(
      children: [
        const Text(
          'Select Teacher: ',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        DropdownButton<String?>(
          value: _selectedTeacherId,
          underline: const SizedBox.shrink(),
          items:
              _teachers.map((t) {
                return DropdownMenuItem(
                  value: t.id,
                  child: Text('${t.name} (${t.employeeCode})'),
                );
              }).toList(),
          onChanged: (val) {
            setState(() => _selectedTeacherId = val);
            _loadTimetableEntries();
          },
        ),
      ],
    );
  }

  Widget _buildWeeklyScheduleView() {
    if (_currentEntries.isEmpty) {
      return EmptyState(
        icon: Icons.calendar_today_outlined,
        title: 'No Timetable Entries',
        message:
            'Click "Add Period" to schedule classes, subjects, and teachers for this view.',
        actionLabel: 'Add First Period',
        onAction: _showAddEntryDialog,
      );
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children:
          DayOfWeek.schoolDays.map((day) {
            final dayEntries =
                _currentEntries.where((e) => e.entry.dayOfWeek == day).toList();

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          DayOfWeek.getName(day),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        Text(
                          '${dayEntries.length} Periods',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 18),
                    if (dayEntries.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'No classes scheduled for this day.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textMuted,
                          ),
                        ),
                      )
                    else
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children:
                            dayEntries.map((item) {
                              return Container(
                                width: 240,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceVariant,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary,
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Text(
                                            'Period ${item.entry.period}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.close,
                                            size: 16,
                                            color: AppColors.textMuted,
                                          ),
                                          onPressed: () async {
                                            final timetableRepo = ref.read(
                                              timetableRepositoryProvider,
                                            );
                                            await timetableRepo.deleteEntry(
                                              item.entry.id,
                                            );
                                            await _loadTimetableEntries();
                                          },
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      item.subject.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${item.schoolClass?.name ?? ""} ${item.section?.name ?? ""}'
                                          .trim(),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${item.entry.startTime} - ${item.entry.endTime}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    if (item.teacher != null)
                                      Text(
                                        'Teacher: ${item.teacher!.name}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    if (item.entry.room != null)
                                      Text(
                                        'Room: ${item.entry.room}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            }).toList(),
                      ),
                  ],
                ),
              ),
            );
          }).toList(),
    );
  }
}
