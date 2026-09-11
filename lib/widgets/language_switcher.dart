import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../models/app_language.dart';
import '../providers/locale_provider.dart';

import 'ui/app_segmented_control.dart';

class LanguageSwitcherWidget extends ConsumerWidget {
  final bool compact;

  const LanguageSwitcherWidget({super.key, this.compact = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLang = ref.watch(localeProvider);

    if (compact) {
      return TextButton.icon(
        icon: const Icon(Icons.language, size: 18),
        label: Text(
          currentLang == AppLanguage.english ? 'EN' : 'ने',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        onPressed: () {
          ref.read(localeProvider.notifier).toggleLanguage();
        },
      );
    }

    return AppSegmentedControl<AppLanguage>(
      segments:
          AppLanguage.values.map((lang) {
            return ButtonSegment<AppLanguage>(
              value: lang,
              label: Text(lang.nativeName),
              icon: const Icon(Icons.translate, size: 16),
            );
          }).toList(),
      selected: {currentLang},
      onSelectionChanged: (Set<AppLanguage> newSelection) {
        ref.read(localeProvider.notifier).setLanguage(newSelection.first);
      },
    );
  }
}
