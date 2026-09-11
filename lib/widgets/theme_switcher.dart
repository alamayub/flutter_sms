import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../models/theme_preference.dart';
import '../providers/locale_provider.dart';
import '../providers/theme_provider.dart';

import 'ui/app_segmented_control.dart';

class ThemeSwitcherWidget extends ConsumerWidget {
  final bool compact;

  const ThemeSwitcherWidget({super.key, this.compact = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTheme = ref.watch(themeProvider);
    final currentLang = ref.watch(localeProvider);
    final langCode = currentLang.locale.languageCode;

    if (compact) {
      return IconButton(
        icon: Icon(
          currentTheme == AppThemeMode.dark
              ? Icons.dark_mode
              : (currentTheme == AppThemeMode.light
                  ? Icons.light_mode
                  : Icons.brightness_auto),
          size: 20,
        ),
        tooltip: currentTheme.localizedLabel(langCode),
        onPressed: () {
          ref.read(themeProvider.notifier).toggleTheme();
        },
      );
    }

    return AppSegmentedControl<AppThemeMode>(
      segments:
          AppThemeMode.values.map((mode) {
            return ButtonSegment<AppThemeMode>(
              value: mode,
              label: Text(mode.localizedLabel(langCode)),
              icon: Icon(switch (mode) {
                AppThemeMode.light => Icons.light_mode,
                AppThemeMode.dark => Icons.dark_mode,
                AppThemeMode.system => Icons.brightness_auto,
              }, size: 18),
            );
          }).toList(),
      selected: {currentTheme},
      onSelectionChanged: (Set<AppThemeMode> newSelection) {
        ref.read(themeProvider.notifier).setTheme(newSelection.first);
      },
    );
  }
}
