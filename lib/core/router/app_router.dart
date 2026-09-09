// lib/core/router/app_router.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../features/academic_year/presentation/academic_years_screen.dart';
import '../../features/attendance/presentation/attendance_screen.dart';
import '../../features/audit/presentation/audit_screen.dart';
import '../../features/auth/presentation/controllers/auth_controller.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/classes/presentation/classes_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/database_management/presentation/database_screen.dart';
import '../../features/school/presentation/registration_wizard_screen.dart';
import '../../features/students/presentation/students_screen.dart';
import '../../features/subjects/presentation/subjects_screen.dart';
import '../../features/sync/presentation/sync_settings_screen.dart';
import '../../features/teachers/presentation/teachers_screen.dart';
import '../../features/timetable/presentation/timetable_screen.dart';
import '../../features/exams/presentation/exams_screen.dart';
import '../../features/exams/presentation/exam_setup_screen.dart';
import '../../features/exams/presentation/marks_entry_screen.dart';
import '../../features/exams/presentation/results_screen.dart';
import '../../features/exams/presentation/report_cards_screen.dart';
import '../../shared/widgets/app_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/dashboard',
    refreshListenable: _AuthListenable(ref),
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final isWelcome = state.uri.toString() == '/welcome';
      final isLogin = state.uri.toString() == '/login';

      if (auth.status == AuthStatus.initial) {
        return null;
      }

      if (auth.status == AuthStatus.needsSetup) {
        return isWelcome ? null : '/welcome';
      }

      if (auth.status == AuthStatus.unauthenticated) {
        return isLogin ? null : '/login';
      }

      if (auth.status == AuthStatus.authenticated) {
        if (isWelcome || isLogin) {
          return '/dashboard';
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const RegistrationWizardScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/academic-years',
            builder: (context, state) => const AcademicYearsScreen(),
          ),
          GoRoute(
            path: '/classes',
            builder: (context, state) => const ClassesScreen(),
          ),
          GoRoute(
            path: '/subjects',
            builder: (context, state) => const SubjectsScreen(),
          ),
          GoRoute(
            path: '/teachers',
            builder: (context, state) => const TeachersScreen(),
          ),
          GoRoute(
            path: '/students',
            builder: (context, state) => const StudentsScreen(),
          ),
          GoRoute(
            path: '/timetable',
            builder: (context, state) => const TimetableScreen(),
          ),
          GoRoute(
            path: '/attendance',
            builder: (context, state) => const AttendanceScreen(),
          ),
          GoRoute(
            path: '/exams',
            builder: (context, state) => const ExamsScreen(),
          ),
          GoRoute(
            path: '/exam-setup',
            builder:
                (context, state) => ExamSetupScreen(
                  examId: state.uri.queryParameters['examId'] ?? '',
                ),
          ),
          GoRoute(
            path: '/marks-entry',
            builder:
                (context, state) => MarksEntryScreen(
                  examId: state.uri.queryParameters['examId'] ?? '',
                ),
          ),
          GoRoute(
            path: '/results',
            builder:
                (context, state) => ResultsScreen(
                  examId: state.uri.queryParameters['examId'] ?? '',
                ),
          ),
          GoRoute(
            path: '/report-cards',
            builder:
                (context, state) => ReportCardsScreen(
                  examId: state.uri.queryParameters['examId'] ?? '',
                ),
          ),
          GoRoute(
            path: '/database',
            builder: (context, state) => const DatabaseScreen(),
          ),
          GoRoute(
            path: '/audit',
            builder: (context, state) => const AuditScreen(),
          ),
          GoRoute(
            path: '/sync-settings',
            builder: (context, state) => const SyncSettingsScreen(),
          ),
        ],
      ),
    ],
  );
});

class _AuthListenable extends ChangeNotifier {
  _AuthListenable(Ref ref) {
    ref.listen(authControllerProvider, (_, _) {
      notifyListeners();
    });
  }
}
