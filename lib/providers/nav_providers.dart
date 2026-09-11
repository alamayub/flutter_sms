import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../pages/academic_year.dart';
import '../pages/attendance_screen.dart';
import '../pages/certificates_screen.dart';
import '../pages/classes_sections_screen.dart';
import '../pages/contacts_screen.dart';
import '../pages/dashboard_screen.dart';
import '../pages/employee_id_card_screen.dart';
import '../pages/employees_screen.dart';
import '../pages/exam_results_screen.dart';
import '../pages/exams_screen.dart';
import '../pages/expenses_screen.dart';
import '../pages/fee_collection.dart';
import '../pages/payroll_screen.dart';
import '../pages/student_id_card_screen.dart';
import '../pages/school_profile_screen.dart';
import '../pages/students_screen.dart';
import '../pages/subjects_screen.dart';
import '../pages/timetable_screen.dart';

class MenuGroup {
  final String id;
  final String titleKey;
  final String defaultTitle;
  final IconData? icon;
  final List<MenuItem> items;

  const MenuGroup({
    required this.id,
    required this.titleKey,
    required this.defaultTitle,
    this.icon,
    required this.items,
  });
}

class MenuItem {
  final String id;
  final String titleKey;
  final String defaultTitle;
  final IconData icon;
  final Widget widget;

  MenuItem({
    required this.id,
    required this.titleKey,
    required this.defaultTitle,
    required this.icon,
    required this.widget,
  });

  /// Backward-compatibility getter
  String get title => defaultTitle;
}

final navGroupsProvider = Provider<List<MenuGroup>>(
  (_) => [
    // 1. OVERVIEW
    MenuGroup(
      id: 'overview',
      titleKey: 'group_overview',
      defaultTitle: 'Overview',
      icon: Icons.dashboard_outlined,
      items: [
        MenuItem(
          id: 'dashboard',
          titleKey: 'dashboard',
          defaultTitle: 'Dashboard',
          icon: Icons.dashboard,
          widget: const DashboardScreen(),
        ),
        MenuItem(
          id: 'school_profile',
          titleKey: 'school_profile',
          defaultTitle: 'School Profile',
          icon: Icons.account_balance_outlined,
          widget: const SchoolProfileScreen(),
        ),
      ],
    ),

    // 2. ATTENDANCE
    MenuGroup(
      id: 'attendance',
      titleKey: 'group_attendance',
      defaultTitle: 'Attendance',
      icon: Icons.how_to_reg_outlined,
      items: [
        MenuItem(
          id: 'student_attendance',
          titleKey: 'student_attendance',
          defaultTitle: 'Student Attendance',
          icon: Icons.school_outlined,
          widget: const StudentAttendanceScreen(),
        ),
        MenuItem(
          id: 'employee_attendance',
          titleKey: 'employee_attendance',
          defaultTitle: 'Employee Attendance',
          icon: Icons.badge_outlined,
          widget: const EmployeeAttendanceScreen(),
        ),
        MenuItem(
          id: 'attendance_report',
          titleKey: 'attendance_report',
          defaultTitle: 'Attendance Report',
          icon: Icons.calendar_month_outlined,
          widget: const AttendanceReportScreen(),
        ),
      ],
    ),

    // 3. ACADEMICS
    MenuGroup(
      id: 'academics',
      titleKey: 'group_academics',
      defaultTitle: 'Academics',
      icon: Icons.school_outlined,
      items: [
        MenuItem(
          id: 'academic_session',
          titleKey: 'academic_session',
          defaultTitle: 'Academic Session',
          icon: Icons.calendar_today,
          widget: const AcademicYearScreen(),
        ),
        MenuItem(
          id: 'classes_sections',
          titleKey: 'classes_sections',
          defaultTitle: 'Classes & Sections',
          icon: Icons.class_,
          widget: const ClassesSectionsScreen(),
        ),
        MenuItem(
          id: 'subjects',
          titleKey: 'subjects',
          defaultTitle: 'Subjects',
          icon: Icons.book,
          widget: const SubjectsScreen(),
        ),
        MenuItem(
          id: 'timetable',
          titleKey: 'timetable',
          defaultTitle: 'Timetable',
          icon: Icons.schedule,
          widget: const TimetableScreen(),
        ),
      ],
    ),

    // 4. STUDENTS
    MenuGroup(
      id: 'students',
      titleKey: 'group_students',
      defaultTitle: 'Students',
      icon: Icons.people_outline,
      items: [
        MenuItem(
          id: 'students',
          titleKey: 'students',
          defaultTitle: 'Students',
          icon: Icons.school,
          widget: const StudentsScreen(),
        ),
        MenuItem(
          id: 'student_id_cards',
          titleKey: 'student_id_cards',
          defaultTitle: 'Student ID Cards',
          icon: Icons.badge,
          widget: const StudentIdCardScreen(),
        ),
        MenuItem(
          id: 'certificates',
          titleKey: 'certificates',
          defaultTitle: 'Certificates',
          icon: Icons.card_membership,
          widget: const CertificatesScreen(),
        ),
      ],
    ),

    // 5. EXAMINATIONS
    MenuGroup(
      id: 'examinations',
      titleKey: 'group_examinations',
      defaultTitle: 'Examinations',
      icon: Icons.assignment_outlined,
      items: [
        MenuItem(
          id: 'exam_schedule',
          titleKey: 'exams',
          defaultTitle: 'Exam Schedule',
          icon: Icons.assignment_outlined,
          widget: const ExamsScreen(),
        ),
        MenuItem(
          id: 'exam_results',
          titleKey: 'results',
          defaultTitle: 'Exam Results',
          icon: Icons.grade_outlined,
          widget: const ExamResultsScreen(),
        ),
      ],
    ),

    // 6. EMPLOYEES & HR
    MenuGroup(
      id: 'employees_hr',
      titleKey: 'group_hr',
      defaultTitle: 'Employees & HR',
      icon: Icons.badge_outlined,
      items: [
        MenuItem(
          id: 'employees',
          titleKey: 'employees',
          defaultTitle: 'Employees',
          icon: Icons.badge,
          widget: const EmployeesScreen(),
        ),
        MenuItem(
          id: 'employee_id_cards',
          titleKey: 'employee_id_cards',
          defaultTitle: 'Employee ID Cards',
          icon: Icons.badge_outlined,
          widget: const EmployeeIdCardScreen(),
        ),
        MenuItem(
          id: 'contacts',
          titleKey: 'contacts',
          defaultTitle: 'Contacts',
          icon: Icons.contacts_rounded,
          widget: const ContactsScreen(),
        ),
        MenuItem(
          id: 'salary_payments',
          titleKey: 'salary_payments',
          defaultTitle: 'Salary Payments',
          icon: Icons.payments_outlined,
          widget: const SalaryPaymentsScreen(),
        ),
        MenuItem(
          id: 'salary_advances',
          titleKey: 'salary_advances',
          defaultTitle: 'Salary Advances',
          icon: Icons.monetization_on_outlined,
          widget: const SalaryAdvancesScreen(),
        ),
      ],
    ),

    // 7. FINANCE & ACCOUNTS
    MenuGroup(
      id: 'finance',
      titleKey: 'group_finance',
      defaultTitle: 'Finance & Accounts',
      icon: Icons.account_balance_wallet_outlined,
      items: [
        MenuItem(
          id: 'fee_collection',
          titleKey: 'fees',
          defaultTitle: 'Fee Collection',
          icon: Icons.receipt_long,
          widget: const FeeCollectionScreen(),
        ),
        MenuItem(
          id: 'expense_records',
          titleKey: 'expense_records',
          defaultTitle: 'Expenses List',
          icon: Icons.account_balance_wallet,
          widget: const ExpensesListScreen(),
        ),
        MenuItem(
          id: 'expense_report',
          titleKey: 'expense_report',
          defaultTitle: 'Expense Report',
          icon: Icons.pie_chart_outline,
          widget: const ExpenseReportScreen(),
        ),
      ],
    ),
  ],
);

/// Flat list of all navigation menu items across groups
final flatNavItemsProvider = Provider<List<MenuItem>>((ref) {
  final groups = ref.watch(navGroupsProvider);
  return [for (final group in groups) ...group.items];
});

/// Alias for backward compatibility
final navProviders = flatNavItemsProvider;

class SelectedMenuIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setIndex(int index) => state = index;

  void selectById(List<MenuItem> items, String id) {
    final idx = items.indexWhere((it) => it.id == id);
    if (idx != -1) state = idx;
  }
}

final selectedMenuIndexProvider =
    NotifierProvider<SelectedMenuIndexNotifier, int>(
      SelectedMenuIndexNotifier.new,
    );

final activeMenuItemProvider = Provider<MenuItem>((ref) {
  final items = ref.watch(flatNavItemsProvider);
  final index = ref.watch(selectedMenuIndexProvider);
  if (index >= 0 && index < items.length) {
    return items[index];
  }
  return items.first;
});
