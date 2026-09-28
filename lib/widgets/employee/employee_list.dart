import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../config/extensions.dart';
import '../../config/responsive.dart';
import '../../config/translations.dart';
import '../../data/app_database.dart';
import '../../providers/calendar_provider.dart';
import '../../providers/employee_provider.dart';
import '../../providers/locale_provider.dart';
import '../forms/employee_form.dart';
import 'employee_card.dart';

class EmployeeList extends ConsumerWidget {
  final List<Employee> list;
  const EmployeeList({super.key, required this.list});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(localeProvider);
    final langCode = currentLang.locale.languageCode;
    final isNepali = langCode == 'ne';
    final calendarMode = ref.watch(calendarProvider);

    final isDesktop = context.isDesktop;
    final isTablet = context.isTablet;

    Future<void> confirmDeleteEmployee(Employee employee) async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder:
            (ctx) => AlertDialog(
              title: Text(AppTranslations.text('delete_employee', langCode)),
              content: Text(
                langCode == 'ne'
                    ? 'के तपाईं कर्मचारी "${employee.name}" लाई हटाउन निश्चित हुनुहुन्छ?'
                    : 'Are you sure you want to delete employee "${employee.name}"?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text(AppTranslations.text('cancel', langCode)),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(ctx).colorScheme.error,
                  ),
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: Text(AppTranslations.text('delete', langCode)),
                ),
              ],
            ),
      );

      if (confirmed == true && context.mounted) {
        await ref
            .read(employeeControllerProvider.notifier)
            .deleteEmployee(employee.id);
        if (context.mounted) {
          context.showSnackbar(
            SnackBar(
              content: Text(
                langCode == 'ne'
                    ? 'कर्मचारी सफलतापूर्वक हटाइयो'
                    : 'Employee deleted successfully',
              ),
            ),
          );
        }
      }
    }

    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 48),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.people_outline,
                size: 64,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 16),
              Text(
                AppTranslations.text('no_employees', langCode),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                // onPressed: () => _openEmployeeDialog(context, null, langCode),
                onPressed: () {},
                icon: const Icon(Icons.add),
                label: Text(AppTranslations.text('add_employee', langCode)),
              ),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount:
            isDesktop
                ? 3
                : isTablet
                ? 2
                : 1,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        mainAxisExtent: 240,
      ),
      itemCount: list.length,
      itemBuilder:
          (_, i) => EmployeeCard(
            employee: list[i],
            langCode: langCode,
            isNepali: isNepali,
            calendarMode: calendarMode,
            onDelete: (val) => confirmDeleteEmployee(val),
            onEdit:
                (val) => context.showGenericDialogWithChild(
                  EmployeeForm(employee: val, langCode: langCode),
                ),
          ),
    );
  }
}
