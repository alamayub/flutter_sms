// lib/features/students/presentation/students_screen.dart
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../academic_year/data/academic_year_repository.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../../classes/data/classes_repository.dart';
import '../data/students_repository.dart';

class StudentsScreen extends ConsumerStatefulWidget {
  const StudentsScreen({super.key});

  @override
  ConsumerState<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends ConsumerState<StudentsScreen> {
  final _searchController = TextEditingController();
  AcademicYear? _currentYear;
  List<ClassWithSections> _classesWithSections = [];
  bool _isLoading = true;
  List<Student> _allStudents = [];

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    setState(() => _isLoading = true);
    final school = ref.read(authControllerProvider).currentSchool;
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

    final studentsRepo = ref.read(studentsRepositoryProvider);
    final students = await studentsRepo.getStudents(school.id);

    if (mounted) {
      setState(() {
        _currentYear = currentYear;
        _classesWithSections = classes;
        _allStudents = students;
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshStudents([String? query]) async {
    final school = ref.read(authControllerProvider).currentSchool;
    if (school == null) return;

    final studentsRepo = ref.read(studentsRepositoryProvider);
    final students = await studentsRepo.getStudents(
      school.id,
      searchQuery: query ?? _searchController.text,
    );

    if (mounted) {
      setState(() => _allStudents = students);
    }
  }

  void _showAddStudentDialog() {
    final codeController = TextEditingController(
      text:
          'STU${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
    );
    final firstController = TextEditingController();
    final middleController = TextEditingController();
    final lastController = TextEditingController();
    final guardianController = TextEditingController();
    final guardianPhoneController = TextEditingController();
    final rollController = TextEditingController();
    String gender = 'Male';
    String? selectedClassId =
        _classesWithSections.isNotEmpty
            ? _classesWithSections.first.schoolClass.id
            : null;
    String? selectedSectionId =
        _classesWithSections.isNotEmpty &&
                _classesWithSections.first.sections.isNotEmpty
            ? _classesWithSections.first.sections.first.id
            : null;

    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder: (context, setDialogState) {
              final currentClassSections =
                  _classesWithSections
                      .where((c) => c.schoolClass.id == selectedClassId)
                      .firstOrNull
                      ?.sections ??
                  [];

              return AlertDialog(
                title: const Text('Register & Enroll Student'),
                content: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Student Information',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: codeController,
                          decoration: const InputDecoration(
                            labelText: 'Student Code *',
                            hintText: 'STU0801',
                          ),
                          validator:
                              (v) =>
                                  v == null || v.trim().isEmpty
                                      ? 'Student code is required'
                                      : null,
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: firstController,
                                decoration: const InputDecoration(
                                  labelText: 'First Name *',
                                ),
                                validator:
                                    (v) =>
                                        v == null || v.trim().isEmpty
                                            ? 'Required'
                                            : null,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: middleController,
                                decoration: const InputDecoration(
                                  labelText: 'Middle Name',
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: lastController,
                                decoration: const InputDecoration(
                                  labelText: 'Last Name *',
                                ),
                                validator:
                                    (v) =>
                                        v == null || v.trim().isEmpty
                                            ? 'Required'
                                            : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          initialValue: gender,
                          decoration: const InputDecoration(
                            labelText: 'Gender',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'Male',
                              child: Text('Male'),
                            ),
                            DropdownMenuItem(
                              value: 'Female',
                              child: Text('Female'),
                            ),
                            DropdownMenuItem(
                              value: 'Other',
                              child: Text('Other'),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) setDialogState(() => gender = val);
                          },
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: guardianController,
                          decoration: const InputDecoration(
                            labelText: 'Guardian Name',
                            hintText: 'Father / Mother / Guardian',
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: guardianPhoneController,
                          decoration: const InputDecoration(
                            labelText: 'Guardian Phone',
                            hintText: '+977-9800000000',
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Divider(),
                        const Text(
                          'Class Enrollment',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String?>(
                                initialValue: selectedClassId,
                                decoration: const InputDecoration(
                                  labelText: 'Class',
                                ),
                                items:
                                    _classesWithSections.map((c) {
                                      return DropdownMenuItem(
                                        value: c.schoolClass.id,
                                        child: Text(c.schoolClass.name),
                                      );
                                    }).toList(),
                                onChanged: (val) {
                                  setDialogState(() {
                                    selectedClassId = val;
                                    final newSecs =
                                        _classesWithSections
                                            .where(
                                              (c) => c.schoolClass.id == val,
                                            )
                                            .firstOrNull
                                            ?.sections ??
                                        [];
                                    selectedSectionId =
                                        newSecs.isNotEmpty
                                            ? newSecs.first.id
                                            : null;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: DropdownButtonFormField<String?>(
                                initialValue: selectedSectionId,
                                decoration: const InputDecoration(
                                  labelText: 'Section',
                                ),
                                items:
                                    currentClassSections.map((s) {
                                      return DropdownMenuItem(
                                        value: s.id,
                                        child: Text(s.name),
                                      );
                                    }).toList(),
                                onChanged: (val) {
                                  setDialogState(() => selectedSectionId = val);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: rollController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Roll Number (Optional)',
                            hintText: '1',
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
                      if (school == null) return;

                      final studentsRepo = ref.read(studentsRepositoryProvider);
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        final student = await studentsRepo.createStudent(
                          schoolId: school.id,
                          studentCode: codeController.text.trim(),
                          firstName: firstController.text.trim(),
                          middleName:
                              middleController.text.trim().isNotEmpty
                                  ? middleController.text.trim()
                                  : null,
                          lastName: lastController.text.trim(),
                          gender: gender,
                          guardianName:
                              guardianController.text.trim().isNotEmpty
                                  ? guardianController.text.trim()
                                  : null,
                          guardianPhone:
                              guardianPhoneController.text.trim().isNotEmpty
                                  ? guardianPhoneController.text.trim()
                                  : null,
                          currentUserId:
                              ref.read(authControllerProvider).currentUser?.id,
                        );

                        if (_currentYear != null &&
                            selectedClassId != null &&
                            selectedSectionId != null) {
                          await studentsRepo.enrollStudent(
                            schoolId: school.id,
                            studentId: student.id,
                            academicYearId: _currentYear!.id,
                            classId: selectedClassId!,
                            sectionId: selectedSectionId!,
                            rollNumber: int.tryParse(rollController.text),
                            currentUserId:
                                ref
                                    .read(authControllerProvider)
                                    .currentUser
                                    ?.id,
                          );
                        }

                        await _refreshStudents();
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (e) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(e.toString()),
                            backgroundColor: AppColors.danger,
                          ),
                        );
                      }
                    },
                    child: const Text('Register & Enroll'),
                  ),
                ],
              );
            },
          ),
    );
  }

  /// Helper to batch-create 30 students in a section (as required by prompt)
  Future<void> _handleBatchAddStudents() async {
    final school = ref.read(authControllerProvider).currentSchool;
    if (school == null || _currentYear == null) return;

    if (_classesWithSections.isEmpty ||
        _classesWithSections.first.sections.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please create a class and section first.'),
        ),
      );
      return;
    }

    final targetClass = _classesWithSections.first.schoolClass;
    final targetSection = _classesWithSections.first.sections.first;

    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Batch Generate 30 Students'),
            content: Text(
              'This will generate 30 students and enroll them into ${targetClass.name} - ${targetSection.name} with roll numbers 1-30.\n\nProceed?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Generate 30 Students'),
              ),
            ],
          ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    final studentsRepo = ref.read(studentsRepositoryProvider);
    final names = [
      'Aarav',
      'Bibek',
      'Chirag',
      'Deepak',
      'Elina',
      'Gita',
      'Ishwor',
      'Kabita',
      'Laxman',
      'Manisha',
      'Nabin',
      'Prashant',
      'Rabin',
      'Sagar',
      'Tara',
      'Ujjwal',
      'Bikash',
      'Dikshya',
      'Hemant',
      'Kiran',
      'Milan',
      'Pooja',
      'Rohan',
      'Sarita',
      'Sunil',
      'Bhawana',
      'Dipen',
      'Kripa',
      'Nirajan',
      'Samir',
    ];
    final lastNames = [
      'Adhikari',
      'Bhandari',
      'Chhetri',
      'Dahal',
      'Gautam',
      'Karki',
      'Khadka',
      'Maharjan',
      'Oli',
      'Pandey',
      'Rai',
      'Shrestha',
      'Tamang',
      'Thapa',
      'Acharya',
      'Bhattarai',
      'Basnet',
      'Giri',
      'Joshi',
      'Koirala',
      'Magar',
      'Neupane',
      'Poudel',
      'Rana',
      'Sapkota',
      'Subedi',
      'Tiwari',
      'Bhatia',
      'Regmi',
      'Upadhyaya',
    ];

    try {
      final prefix = targetClass.name.replaceAll(RegExp(r'[^0-9]'), '');
      final pfx = prefix.isNotEmpty ? prefix : '08';

      for (int i = 0; i < 30; i++) {
        final roll = i + 1;
        final code =
            'STU$pfx${roll.toString().padLeft(2, '0')}-${DateTime.now().millisecond}';
        final student = await studentsRepo.createStudent(
          schoolId: school.id,
          studentCode: code,
          firstName: names[i % names.length],
          lastName: lastNames[i % lastNames.length],
          gender: i % 2 == 0 ? 'Male' : 'Female',
          guardianName: '${lastNames[i % lastNames.length]} Guardian',
          guardianPhone: '+977-98100000$roll',
          currentUserId: ref.read(authControllerProvider).currentUser?.id,
        );

        await studentsRepo.enrollStudent(
          schoolId: school.id,
          studentId: student.id,
          academicYearId: _currentYear!.id,
          classId: targetClass.id,
          sectionId: targetSection.id,
          rollNumber: roll,
          currentUserId: ref.read(authControllerProvider).currentUser?.id,
        );
      }

      await _refreshStudents();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully created and enrolled 30 students in ${targetClass.name} - ${targetSection.name}!',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Students Directory'),
        actions: [
          TextButton.icon(
            onPressed: _handleBatchAddStudents,
            icon: const Icon(Icons.group_add, size: 16),
            label: const Text(
              'Quick Batch 30 Students',
              style: TextStyle(fontSize: 12),
            ),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              onPressed: _showAddStudentDialog,
              icon: const Icon(Icons.person_add, size: 18),
              label: const Text('Register Student'),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by student name or code...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon:
                          _searchController.text.isNotEmpty
                              ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  _refreshStudents();
                                },
                              )
                              : null,
                    ),
                    onChanged: (val) => _refreshStudents(val),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${_allStudents.length} Students',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Students List
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _allStudents.isEmpty
                    ? EmptyState(
                      icon: Icons.people_outline,
                      title: 'No Students Found',
                      message:
                          'Register individual students or use "Quick Batch 30 Students" to generate a full class.',
                      actionLabel: 'Register Student',
                      onAction: _showAddStudentDialog,
                    )
                    : ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: _allStudents.length,
                      itemBuilder: (context, idx) {
                        final s = _allStudents[idx];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            leading: CircleAvatar(
                              backgroundColor: AppColors.primary.withValues(
                                alpha: 0.12,
                              ),
                              child: Text(
                                s.firstName.isNotEmpty
                                    ? s.firstName[0].toUpperCase()
                                    : 'S',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            title: Row(
                              children: [
                                Text(
                                  '${s.firstName} ${s.middleName ?? ""} ${s.lastName}'
                                      .trim(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceVariant,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    s.studentCode,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Text(
                              'Gender: ${s.gender} • Guardian: ${s.guardianName ?? "N/A"} (${s.guardianPhone ?? "No Phone"})',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.archive_outlined,
                                size: 18,
                                color: AppColors.warning,
                              ),
                              tooltip: 'Archive Student',
                              onPressed: () async {
                                final repo = ref.read(
                                  studentsRepositoryProvider,
                                );
                                await repo.archiveStudent(s.id);
                                await _refreshStudents();
                              },
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
