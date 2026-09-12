import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sms/pages/attendance/attendance_screen.dart';
import 'package:sms/pages/employee_hr/employee_id_card_screen.dart';
import 'package:sms/pages/finance_account/expenses_screen.dart';
import 'package:sms/pages/employee_hr/payroll_screen.dart';
import 'package:sms/pages/students/student_id_card_screen.dart';
import 'package:sms/providers/nav_providers.dart';

void main() {
  group('Navigation Structure Tests', () {
    test('navGroupsProvider contains all expected groups and hierarchy', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final groups = container.read(navGroupsProvider);
      expect(groups.isNotEmpty, isTrue);

      final groupIds = groups.map((g) => g.id).toList();
      expect(
        groupIds,
        containsAll([
          'overview',
          'attendance',
          'academics',
          'students',
          'examinations',
          'employees_hr',
          'finance',
        ]),
      );

      // Verify Attendance Group contains the 3 separate menu items
      final attendanceGroup = groups.firstWhere((g) => g.id == 'attendance');
      expect(attendanceGroup.items.length, 3);
      expect(attendanceGroup.items[0].id, 'student_attendance');
      expect(attendanceGroup.items[0].widget, isA<StudentAttendanceScreen>());
      expect(attendanceGroup.items[1].id, 'employee_attendance');
      expect(attendanceGroup.items[1].widget, isA<EmployeeAttendanceScreen>());
      expect(attendanceGroup.items[2].id, 'attendance_report');
      expect(attendanceGroup.items[2].widget, isA<AttendanceReportScreen>());

      // Verify Students Group contains student_id_cards
      final studentsGroup = groups.firstWhere((g) => g.id == 'students');
      expect(
        studentsGroup.items.map((it) => it.id),
        containsAll(['students', 'student_id_cards', 'certificates']),
      );
      final idCardItem = studentsGroup.items.firstWhere(
        (it) => it.id == 'student_id_cards',
      );
      expect(idCardItem.widget, isA<StudentIdCardScreen>());

      // Verify Employees & HR contains Employee ID Cards, Salary Payments & Advances
      final hrGroup = groups.firstWhere((g) => g.id == 'employees_hr');
      expect(
        hrGroup.items.map((it) => it.id),
        containsAll([
          'employees',
          'employee_id_cards',
          'contacts',
          'salary_payments',
          'salary_advances',
        ]),
      );
      final employeeIdCard = hrGroup.items.firstWhere(
        (it) => it.id == 'employee_id_cards',
      );
      expect(employeeIdCard.widget, isA<EmployeeIdCardScreen>());
      final salaryPayments = hrGroup.items.firstWhere(
        (it) => it.id == 'salary_payments',
      );
      expect(salaryPayments.widget, isA<SalaryPaymentsScreen>());
      final salaryAdvances = hrGroup.items.firstWhere(
        (it) => it.id == 'salary_advances',
      );
      expect(salaryAdvances.widget, isA<SalaryAdvancesScreen>());

      // Verify Finance contains Expenses List & Expense Report
      final financeGroup = groups.firstWhere((g) => g.id == 'finance');
      expect(
        financeGroup.items.map((it) => it.id),
        containsAll(['fee_collection', 'expense_records', 'expense_report']),
      );
      final expenseRecords = financeGroup.items.firstWhere(
        (it) => it.id == 'expense_records',
      );
      expect(expenseRecords.widget, isA<ExpensesListScreen>());
      final expenseReport = financeGroup.items.firstWhere(
        (it) => it.id == 'expense_report',
      );
      expect(expenseReport.widget, isA<ExpenseReportScreen>());
    });

    test(
      'flatNavItemsProvider correctly aggregates items and preserves uniqueness',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final groups = container.read(navGroupsProvider);
        final flatItems = container.read(flatNavItemsProvider);

        int totalGroupItems = 0;
        for (final g in groups) {
          totalGroupItems += g.items.length;
        }
        expect(flatItems.length, totalGroupItems);

        // Verify unique IDs across all items
        final itemIds = flatItems.map((it) => it.id).toSet();
        expect(itemIds.length, flatItems.length);
      },
    );

    test(
      'SelectedMenuIndexNotifier and activeMenuItemProvider work seamlessly',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        expect(container.read(selectedMenuIndexProvider), 0);
        expect(container.read(activeMenuItemProvider).id, 'dashboard');

        // Change index to student_attendance
        final flatItems = container.read(flatNavItemsProvider);
        final studentAttIndex = flatItems.indexWhere(
          (it) => it.id == 'student_attendance',
        );
        expect(studentAttIndex, greaterThan(0));

        container
            .read(selectedMenuIndexProvider.notifier)
            .setIndex(studentAttIndex);
        expect(container.read(selectedMenuIndexProvider), studentAttIndex);
        expect(container.read(activeMenuItemProvider).id, 'student_attendance');

        // Select by ID
        container
            .read(selectedMenuIndexProvider.notifier)
            .selectById(flatItems, 'employee_attendance');
        expect(
          container.read(activeMenuItemProvider).id,
          'employee_attendance',
        );
      },
    );
  });
}
