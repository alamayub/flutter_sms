import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/database/app_database.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_helpers.dart';
import '../../../shared/widgets/local_mode_badge.dart';
import '../../../shared/widgets/stat_card.dart';
import '../../academic_year/data/academic_year_repository.dart';
import '../../attendance/data/attendance_repository.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../../classes/data/classes_repository.dart';
import '../../students/data/students_repository.dart';
import '../../teachers/data/teachers_repository.dart';
import '../../timetable/data/timetable_repository.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _isLoading = true;
  int _totalStudents = 0;
  int _totalTeachers = 0;
  int _totalClasses = 0;
  String _currentYearName = 'None';
  String? _currentYearId;
  AttendanceSummary _todayAttendance = const AttendanceSummary();
  StreamSubscription<AttendanceSummary>? _attendanceSub;
  List<TimetableEntryDetail> _teacherTodaySchedule = [];
  Teacher? _currentTeacher;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  @override
  void dispose() {
    _attendanceSub?.cancel();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    final authState = ref.read(authControllerProvider);
    final school = authState.currentSchool;
    final user = authState.currentUser;

    if (school == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final academicRepo = ref.read(academicYearRepositoryProvider);
      final currentYear = await academicRepo.getCurrentAcademicYear(school.id);
      _currentYearName = currentYear?.name ?? 'Not configured';
      _currentYearId = currentYear?.id;

      final studentsRepo = ref.read(studentsRepositoryProvider);
      _totalStudents = await studentsRepo.getTotalStudentCount(school.id);

      final teachersRepo = ref.read(teachersRepositoryProvider);
      final teachers = await teachersRepo.getTeachers(school.id);
      _totalTeachers = teachers.length;

      if (_currentYearId != null) {
        final classesRepo = ref.read(classesRepositoryProvider);
        final classes = await classesRepo.getClasses(
          schoolId: school.id,
          academicYearId: _currentYearId!,
        );
        _totalClasses = classes.length;

        final attendanceRepo = ref.read(attendanceRepositoryProvider);
        _todayAttendance = await attendanceRepo.getDailySummary(
          schoolId: school.id,
          date: DateHelpers.todayIsoDate(),
        );

        _attendanceSub?.cancel();
        _attendanceSub = attendanceRepo
            .watchDailySummary(
              schoolId: school.id,
              date: DateHelpers.todayIsoDate(),
            )
            .listen((summary) {
              if (mounted) {
                setState(() => _todayAttendance = summary);
              }
            });

        if (user?.role == UserRole.teacher) {
          _currentTeacher = await teachersRepo.getTeacherByUserId(user!.id);
          if (_currentTeacher != null) {
            final timetableRepo = ref.read(timetableRepositoryProvider);
            final dayOfWeek = DateTime.now().weekday;
            _teacherTodaySchedule = await timetableRepo.getTimetableForTeacher(
              _currentTeacher!.id,
              academicYearId: _currentYearId!,
              dayOfWeek: dayOfWeek,
            );
          }
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final user = authState.currentUser;
    final school = authState.currentSchool;
    final isTeacher = user?.role == UserRole.teacher;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${isTeacher ? 'Teacher' : 'School'} Dashboard',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              'Academic Year: $_currentYearName',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadDashboardData,
          ),
          const SizedBox(width: 8),
          const Padding(
            padding: EdgeInsets.only(right: 16),
            child: LocalModeBadge(compact: true),
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                onRefresh: _loadDashboardData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Welcome Banner
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.primary, AppColors.primaryDark],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Welcome back, ${user?.name ?? 'User'}!',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${school?.name} • ${DateHelpers.formatDisplayDate(DateTime.now())}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.white.withValues(
                                        alpha: 0.85,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: () => context.go('/attendance'),
                              icon: const Icon(Icons.fact_check, size: 18),
                              label: const Text('Mark Attendance'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Metrics Grid
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth > 700;
                          return GridView.count(
                            crossAxisCount: isWide ? 4 : 2,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            childAspectRatio: isWide ? 1.6 : 1.4,
                            children: [
                              StatCard(
                                title: 'Total Students',
                                value: '$_totalStudents',
                                icon: Icons.people,
                                iconColor: AppColors.primary,
                                onTap: () => context.go('/students'),
                              ),
                              StatCard(
                                title: 'Active Teachers',
                                value: '$_totalTeachers',
                                icon: Icons.badge,
                                iconColor: AppColors.secondary,
                                onTap: () => context.go('/teachers'),
                              ),
                              StatCard(
                                title: 'Total Classes',
                                value: '$_totalClasses',
                                icon: Icons.meeting_room,
                                iconColor: const Color(0xFF8B5CF6),
                                onTap: () => context.go('/classes'),
                              ),
                              StatCard(
                                title: "Today's Attendance",
                                value:
                                    '${_todayAttendance.attendancePercentage.toStringAsFixed(1)}%',
                                subtitle:
                                    '${_todayAttendance.presentCount} present, ${_todayAttendance.absentCount} absent',
                                icon: Icons.pie_chart,
                                iconColor: AppColors.success,
                                onTap: () => context.go('/attendance'),
                              ),
                            ],
                          );
                        },
                      ),

                      const SizedBox(height: 24),

                      // Today's Attendance Breakdown Card
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    "Today's Attendance Breakdown",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    DateHelpers.todayIsoDate(),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  _buildStatusIndicator(
                                    'Present',
                                    _todayAttendance.presentCount,
                                    AppColors.present,
                                  ),
                                  _buildStatusIndicator(
                                    'Absent',
                                    _todayAttendance.absentCount,
                                    AppColors.absent,
                                  ),
                                  _buildStatusIndicator(
                                    'Late',
                                    _todayAttendance.lateCount,
                                    AppColors.late,
                                  ),
                                  _buildStatusIndicator(
                                    'Excused',
                                    _todayAttendance.excusedCount,
                                    AppColors.excused,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value:
                                      _todayAttendance.totalCount > 0
                                          ? _todayAttendance.presentCount /
                                              _todayAttendance.totalCount
                                          : 0,
                                  minHeight: 8,
                                  backgroundColor: AppColors.dangerLight,
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                        AppColors.present,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      if (isTeacher && _teacherTodaySchedule.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        const Text(
                          "Today's Teaching Schedule",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _teacherTodaySchedule.length,
                          itemBuilder: (context, idx) {
                            final item = _teacherTodaySchedule[idx];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryLight,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'P${item.entry.period}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  '${item.schoolClass?.name ?? 'Class'} - ${item.section?.name ?? 'Section'} (${item.subject.name})',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  '${item.entry.startTime} - ${item.entry.endTime} • ${item.entry.room ?? 'Main Room'}',
                                ),
                                trailing: ElevatedButton(
                                  onPressed: () => context.go('/attendance'),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                  ),
                                  child: const Text(
                                    'Attendance',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],

                      const SizedBox(height: 24),

                      // Quick Management Actions
                      const Text(
                        'Quick Operations',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _buildActionButton(
                            icon: Icons.person_add,
                            label: 'Enroll Student',
                            onTap: () => context.go('/students'),
                          ),
                          _buildActionButton(
                            icon: Icons.person_add_alt,
                            label: 'Add Teacher',
                            onTap: () => context.go('/teachers'),
                          ),
                          _buildActionButton(
                            icon: Icons.calendar_month,
                            label: 'Timetable',
                            onTap: () => context.go('/timetable'),
                          ),
                          _buildActionButton(
                            icon: Icons.storage,
                            label: 'Database Backup',
                            onTap: () => context.go('/database'),
                          ),
                          _buildActionButton(
                            icon: Icons.history_edu,
                            label: 'Audit Log',
                            onTap: () => context.go('/audit'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
    );
  }

  Widget _buildStatusIndicator(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ActionChip(
      avatar: Icon(icon, size: 16, color: AppColors.primary),
      label: Text(label),
      onPressed: onTap,
      backgroundColor: Colors.white,
      side: const BorderSide(color: AppColors.border),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }
}
