// lib/features/classes/presentation/classes_screen.dart
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../academic_year/data/academic_year_repository.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../../teachers/data/teachers_repository.dart';
import '../data/classes_repository.dart';

class ClassesScreen extends ConsumerStatefulWidget {
  const ClassesScreen({super.key});

  @override
  ConsumerState<ClassesScreen> createState() => _ClassesScreenState();
}

class _ClassesScreenState extends ConsumerState<ClassesScreen> {
  AcademicYear? _selectedYear;
  List<Teacher> _teachers = [];

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    final school = ref.read(authControllerProvider).currentSchool;
    if (school == null) return;

    final academicRepo = ref.read(academicYearRepositoryProvider);
    final currentYear = await academicRepo.getCurrentAcademicYear(school.id);

    final teachersRepo = ref.read(teachersRepositoryProvider);
    final teachers = await teachersRepo.getTeachers(school.id);

    if (mounted) {
      setState(() {
        _selectedYear = currentYear;
        _teachers = teachers;
      });
    }
  }

  void _showAddClassDialog() {
    final nameController = TextEditingController();
    final orderController = TextEditingController(text: '0');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('New Class / Grade'),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Class Name *',
                      hintText: 'e.g., Grade 8',
                    ),
                    validator:
                        (v) =>
                            v == null || v.trim().isEmpty
                                ? 'Name is required'
                                : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: orderController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Display Order',
                      hintText: '8',
                    ),
                  ),
                ],
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
                  final school = ref.read(authControllerProvider).currentSchool;
                  if (school == null || _selectedYear == null) return;

                  final repo = ref.read(classesRepositoryProvider);
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    await repo.createClass(
                      schoolId: school.id,
                      academicYearId: _selectedYear!.id,
                      name: nameController.text.trim(),
                      displayOrder: int.tryParse(orderController.text) ?? 0,
                      currentUserId:
                          ref.read(authControllerProvider).currentUser?.id,
                    );
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
                child: const Text('Create Class'),
              ),
            ],
          ),
    );
  }

  void _showAddSectionDialog(SchoolClass schoolClass) {
    final nameController = TextEditingController(text: 'Section A');
    final capacityController = TextEditingController(text: '40');
    String? selectedTeacherId;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: Text('Add Section to ${schoolClass.name}'),
                  content: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: nameController,
                          decoration: const InputDecoration(
                            labelText: 'Section Name *',
                            hintText: 'e.g., Section A',
                          ),
                          validator:
                              (v) =>
                                  v == null || v.trim().isEmpty
                                      ? 'Name is required'
                                      : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: capacityController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Capacity',
                            hintText: '40',
                          ),
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String?>(
                          initialValue: selectedTeacherId,
                          decoration: const InputDecoration(
                            labelText: 'Class Teacher (Optional)',
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('No Class Teacher'),
                            ),
                            ..._teachers.map(
                              (t) => DropdownMenuItem(
                                value: t.id,
                                child: Text('${t.name} (${t.employeeCode})'),
                              ),
                            ),
                          ],
                          onChanged: (val) {
                            setDialogState(() => selectedTeacherId = val);
                          },
                        ),
                      ],
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
                        final repo = ref.read(classesRepositoryProvider);
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          await repo.createSection(
                            classId: schoolClass.id,
                            name: nameController.text.trim(),
                            capacity:
                                int.tryParse(capacityController.text) ?? 40,
                            classTeacherId: selectedTeacherId,
                            currentUserId:
                                ref
                                    .read(authControllerProvider)
                                    .currentUser
                                    ?.id,
                          );
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
                      child: const Text('Add Section'),
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

    final repo = ref.watch(classesRepositoryProvider);
    final academicRepo = ref.watch(academicYearRepositoryProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Classes & Sections'),
        actions: [
          // Year Selector
          StreamBuilder<List<AcademicYear>>(
            stream: academicRepo.watchAcademicYears(school.id),
            builder: (context, snapshot) {
              final years = snapshot.data ?? [];
              if (years.isEmpty) return const SizedBox.shrink();

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: DropdownButton<String>(
                  value:
                      _selectedYear?.id ??
                      (years.isNotEmpty ? years.first.id : null),
                  underline: const SizedBox.shrink(),
                  items:
                      years.map((y) {
                        return DropdownMenuItem(
                          value: y.id,
                          child: Text(
                            'Year: ${y.name}${y.isCurrent ? ' (Current)' : ''}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedYear = years.firstWhere((y) => y.id == val);
                      });
                    }
                  },
                ),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              onPressed: _selectedYear == null ? null : _showAddClassDialog,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Class'),
            ),
          ),
        ],
      ),
      body:
          _selectedYear == null
              ? const Center(
                child: Text('Please select or create an academic year.'),
              )
              : StreamBuilder<List<SchoolClass>>(
                stream: repo.watchClasses(
                  schoolId: school.id,
                  academicYearId: _selectedYear!.id,
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final classes = snapshot.data ?? [];
                  if (classes.isEmpty) {
                    return EmptyState(
                      icon: Icons.meeting_room_outlined,
                      title: 'No Classes in ${_selectedYear!.name}',
                      message:
                          'Create classes (e.g. Grade 8, Grade 9) and add sections.',
                      actionLabel: 'Create First Class',
                      onAction: _showAddClassDialog,
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: classes.length,
                    itemBuilder: (context, idx) {
                      final schoolClass = classes[idx];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryLight,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          'Order ${schoolClass.displayOrder}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        schoolClass.name,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      OutlinedButton.icon(
                                        onPressed:
                                            () => _showAddSectionDialog(
                                              schoolClass,
                                            ),
                                        icon: const Icon(Icons.add, size: 16),
                                        label: const Text(
                                          'Add Section',
                                          style: TextStyle(fontSize: 12),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.archive_outlined,
                                          size: 18,
                                          color: AppColors.warning,
                                        ),
                                        tooltip: 'Archive Class',
                                        onPressed: () async {
                                          await repo.archiveClass(
                                            schoolClass.id,
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const Divider(height: 20),

                              // Sections Stream for this class
                              StreamBuilder<List<Section>>(
                                stream: repo.watchSections(schoolClass.id),
                                builder: (context, sectionSnap) {
                                  final sections = sectionSnap.data ?? [];
                                  if (sections.isEmpty) {
                                    return const Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 8,
                                      ),
                                      child: Text(
                                        'No sections yet. Click "Add Section" above.',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                    );
                                  }

                                  return Wrap(
                                    spacing: 12,
                                    runSpacing: 12,
                                    children:
                                        sections.map((sec) {
                                          final teacher =
                                              _teachers
                                                  .where(
                                                    (t) =>
                                                        t.id ==
                                                        sec.classTeacherId,
                                                  )
                                                  .firstOrNull;

                                          return Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 10,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.surfaceVariant,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color: AppColors.border,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      sec.name,
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 14,
                                                        color:
                                                            AppColors
                                                                .textPrimary,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      'Cap: ${sec.capacity} • Teacher: ${teacher?.name ?? "None"}',
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        color:
                                                            AppColors
                                                                .textSecondary,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(width: 8),
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.close,
                                                    size: 16,
                                                    color: AppColors.textMuted,
                                                  ),
                                                  tooltip: 'Archive Section',
                                                  onPressed: () async {
                                                    await repo.archiveSection(
                                                      sec.id,
                                                    );
                                                  },
                                                ),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
    );
  }
}
