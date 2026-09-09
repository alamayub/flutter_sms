import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/database/app_database.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_helpers.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../academic_year/data/academic_year_repository.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../../classes/data/classes_repository.dart';
import '../../students/data/students_repository.dart';
import '../data/attendance_repository.dart';

class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  AcademicYear? _currentYear;
  List<ClassWithSections> _classesWithSections = [];
  String? _selectedClassId;
  String? _selectedSectionId;
  DateTime _selectedDate = DateTime.now();

  List<EnrolledStudent> _enrolledStudents = [];
  Map<String, String> _statusMap = {}; // studentId -> status
  bool _isLoading = true;
  bool _isSaving = false;
  StreamSubscription? _attendanceSub;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  @override
  void dispose() {
    _attendanceSub?.cancel();
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

    if (mounted) {
      setState(() {
        _currentYear = currentYear;
        _classesWithSections = classes;

        if (classes.isNotEmpty) {
          _selectedClassId = classes.first.schoolClass.id;
          if (classes.first.sections.isNotEmpty) {
            _selectedSectionId = classes.first.sections.first.id;
          }
        }
      });

      await _loadAttendanceData();
    }
  }

  Future<void> _loadAttendanceData() async {
    if (_currentYear == null || _selectedSectionId == null) {
      setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);
    final studentsRepo = ref.read(studentsRepositoryProvider);
    final attendanceRepo = ref.read(attendanceRepositoryProvider);

    final enrolled = await studentsRepo.getEnrolledStudentsForSection(
      academicYearId: _currentYear!.id,
      sectionId: _selectedSectionId!,
    );

    final existingRecords = await attendanceRepo.getSectionAttendanceForDate(
      academicYearId: _currentYear!.id,
      sectionId: _selectedSectionId!,
      date: DateHelpers.toIsoDate(_selectedDate),
    );

    final map = <String, String>{};
    for (final es in enrolled) {
      if (existingRecords.containsKey(es.student.id)) {
        map[es.student.id] = existingRecords[es.student.id]!.status;
      } else {
        // Default to present for speed
        map[es.student.id] = AttendanceStatus.present;
      }
    }

    if (mounted) {
      setState(() {
        _enrolledStudents = enrolled;
        _statusMap = map;
        _isLoading = false;
      });

      _attendanceSub?.cancel();
      _attendanceSub = attendanceRepo
          .watchSectionAttendanceForDate(
            academicYearId: _currentYear!.id,
            sectionId: _selectedSectionId!,
            date: DateHelpers.toIsoDate(_selectedDate),
          )
          .listen((records) {
            if (mounted && !_isSaving) {
              setState(() {
                for (final es in _enrolledStudents) {
                  if (records.containsKey(es.student.id)) {
                    _statusMap[es.student.id] = records[es.student.id]!.status;
                  }
                }
              });
            }
          });
    }
  }

  void _markAll(String status) {
    setState(() {
      for (final es in _enrolledStudents) {
        _statusMap[es.student.id] = status;
      }
    });
  }

  Future<void> _saveAttendance() async {
    final school = ref.read(authControllerProvider).currentSchool;
    final user = ref.read(authControllerProvider).currentUser;

    if (school == null ||
        _currentYear == null ||
        _selectedClassId == null ||
        _selectedSectionId == null ||
        user == null) {
      return;
    }

    setState(() => _isSaving = true);
    final attendanceRepo = ref.read(attendanceRepositoryProvider);

    try {
      await attendanceRepo.saveAttendanceBatch(
        schoolId: school.id,
        academicYearId: _currentYear!.id,
        classId: _selectedClassId!,
        sectionId: _selectedSectionId!,
        date: DateHelpers.toIsoDate(_selectedDate),
        studentStatusMap: _statusMap,
        markedByUserId: user.id,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Attendance saved successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save attendance: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentClassSections =
        _classesWithSections
            .where((c) => c.schoolClass.id == _selectedClassId)
            .firstOrNull
            ?.sections ??
        [];

    int present = 0;
    int absent = 0;
    int late = 0;
    int excused = 0;

    for (final s in _statusMap.values) {
      if (s == AttendanceStatus.present) present++;
      if (s == AttendanceStatus.absent) absent++;
      if (s == AttendanceStatus.late) late++;
      if (s == AttendanceStatus.excused) excused++;
    }

    final total = _enrolledStudents.length;
    final percentage =
        total > 0 ? ((present + late) / total * 100).toStringAsFixed(1) : '0';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Student Attendance'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              onPressed:
                  _enrolledStudents.isEmpty || _isSaving
                      ? null
                      : _saveAttendance,
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
                      : const Icon(Icons.check, size: 18),
              label: const Text('Save Attendance'),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter & Date Selector Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            color: Colors.white,
            child: Wrap(
              spacing: 20,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Class: ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
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
                          _selectedSectionId =
                              secs.isNotEmpty ? secs.first.id : null;
                        });
                        _loadAttendanceData();
                      },
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Section: ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    DropdownButton<String?>(
                      value: _selectedSectionId,
                      underline: const SizedBox.shrink(),
                      items:
                          currentClassSections.map((s) {
                            return DropdownMenuItem(
                              value: s.id,
                              child: Text(s.name),
                            );
                          }).toList(),
                      onChanged: (val) {
                        setState(() => _selectedSectionId = val);
                        _loadAttendanceData();
                      },
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Date: ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(
                            const Duration(days: 30),
                          ),
                        );
                        if (picked != null) {
                          setState(() => _selectedDate = picked);
                          _loadAttendanceData();
                        }
                      },
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text(DateHelpers.formatDisplayDate(_selectedDate)),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    ActionChip(
                      avatar: const Icon(
                        Icons.done_all,
                        size: 16,
                        color: AppColors.present,
                      ),
                      label: const Text('Mark All Present'),
                      onPressed: () => _markAll(AttendanceStatus.present),
                    ),
                    ActionChip(
                      avatar: const Icon(
                        Icons.close,
                        size: 16,
                        color: AppColors.absent,
                      ),
                      label: const Text('Mark All Absent'),
                      onPressed: () => _markAll(AttendanceStatus.absent),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Attendance Summary Pills
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            color: AppColors.surfaceVariant,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryPill('Total', '$total', AppColors.textPrimary),
                _buildSummaryPill('Present', '$present', AppColors.present),
                _buildSummaryPill('Absent', '$absent', AppColors.absent),
                _buildSummaryPill('Late', '$late', AppColors.late),
                _buildSummaryPill('Excused', '$excused', AppColors.excused),
                _buildSummaryPill('Rate', '$percentage%', AppColors.primary),
              ],
            ),
          ),
          const Divider(height: 1),

          // Student List
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _enrolledStudents.isEmpty
                    ? EmptyState(
                      icon: Icons.people_outline,
                      title: 'No Students Enrolled',
                      message:
                          'There are no active students enrolled in this section for the current academic year.',
                      actionLabel: 'Go to Students',
                      onAction: () => Navigator.pop(context),
                    )
                    : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _enrolledStudents.length,
                      itemBuilder: (context, idx) {
                        final item = _enrolledStudents[idx];
                        final studentId = item.student.id;
                        final status =
                            _statusMap[studentId] ?? AttendanceStatus.present;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                // Roll #
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryLight,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${item.enrollment.rollNumber ?? idx + 1}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),

                                // Name & Code
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.fullName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                        ),
                                      ),
                                      Text(
                                        item.student.studentCode,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Status Toggle Buttons (Present, Absent, Late, Excused)
                                Wrap(
                                  spacing: 6,
                                  children: [
                                    _buildStatusButton(
                                      label: 'Present',
                                      icon: Icons.check,
                                      color: AppColors.present,
                                      isSelected:
                                          status == AttendanceStatus.present,
                                      onTap:
                                          () => setState(
                                            () =>
                                                _statusMap[studentId] =
                                                    AttendanceStatus.present,
                                          ),
                                    ),
                                    _buildStatusButton(
                                      label: 'Absent',
                                      icon: Icons.close,
                                      color: AppColors.absent,
                                      isSelected:
                                          status == AttendanceStatus.absent,
                                      onTap:
                                          () => setState(
                                            () =>
                                                _statusMap[studentId] =
                                                    AttendanceStatus.absent,
                                          ),
                                    ),
                                    _buildStatusButton(
                                      label: 'Late',
                                      icon: Icons.access_time,
                                      color: AppColors.late,
                                      isSelected:
                                          status == AttendanceStatus.late,
                                      onTap:
                                          () => setState(
                                            () =>
                                                _statusMap[studentId] =
                                                    AttendanceStatus.late,
                                          ),
                                    ),
                                    _buildStatusButton(
                                      label: 'Excused',
                                      icon: Icons.bookmark_border,
                                      color: AppColors.excused,
                                      isSelected:
                                          status == AttendanceStatus.excused,
                                      onTap:
                                          () => setState(
                                            () =>
                                                _statusMap[studentId] =
                                                    AttendanceStatus.excused,
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

  Widget _buildSummaryPill(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildStatusButton({
    required String label,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? color : AppColors.border,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? Colors.white : color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
