import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../config/theme.dart';
import '../models/app_language.dart';
import '../models/calendar_mode.dart';
import '../providers/calendar_provider.dart';
import '../providers/locale_provider.dart';
import '../utils/date_time_utils.dart';

class DualDatePickerField extends ConsumerWidget {
  final String label;
  final DateTime? selectedDate;
  final ValueChanged<DateTime> onDateSelected;
  final DateTime? firstDate;
  final DateTime? lastDate;

  const DualDatePickerField({
    super.key,
    required this.label,
    required this.selectedDate,
    required this.onDateSelected,
    this.firstDate,
    this.lastDate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calendarMode = ref.watch(calendarProvider);
    final locale = ref.watch(localeProvider);
    final isNepali = locale == AppLanguage.nepali;

    final effectiveDate = selectedDate ?? DateTime.now();
    final displayText = DateTimeUtils.formatDual(
      date: effectiveDate,
      primary: calendarMode,
      showBoth: true,
      inNepaliScript: isNepali,
    );

    return InkWell(
      onTap: () => _pickDate(context, effectiveDate, calendarMode),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_month),
        ),
        child: Text(
          selectedDate != null ? displayText : 'Select Date',
          style: TextStyle(
            color:
                selectedDate != null
                    ? Theme.of(context).textTheme.bodyLarge?.color
                    : Theme.of(context).hintColor,
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate(
    BuildContext context,
    DateTime initial,
    CalendarMode mode,
  ) async {
    // Standard picker with AD date
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate ?? DateTime(1990),
      lastDate: lastDate ?? DateTime(2100),
      helpText: 'Select Date (${mode.labelEn})',
    );

    if (picked != null) {
      onDateSelected(picked);
    }
  }
}
