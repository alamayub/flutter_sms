import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../models/calendar_mode.dart';
import '../providers/calendar_provider.dart';
import '../providers/locale_provider.dart';

import 'ui/app_segmented_control.dart';

class CalendarSwitcherWidget extends ConsumerWidget {
  final bool compact;

  const CalendarSwitcherWidget({super.key, this.compact = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentMode = ref.watch(calendarProvider);
    final currentLang = ref.watch(localeProvider);
    final langCode = currentLang.locale.languageCode;

    if (compact) {
      return TextButton.icon(
        icon: const Icon(Icons.calendar_month, size: 18),
        label: Text(
          currentMode.localizedLabel(langCode),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        onPressed: () {
          ref.read(calendarProvider.notifier).toggleCalendarMode();
        },
      );
    }

    return AppSegmentedControl<CalendarMode>(
      segments:
          CalendarMode.values.map((mode) {
            return ButtonSegment<CalendarMode>(
              value: mode,
              label: Text(mode.localizedLabel(langCode)),
              icon: const Icon(Icons.calendar_today, size: 16),
            );
          }).toList(),
      selected: {currentMode},
      onSelectionChanged: (Set<CalendarMode> newSelection) {
        ref.read(calendarProvider.notifier).setCalendarMode(newSelection.first);
      },
    );
  }
}
