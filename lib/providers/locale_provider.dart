import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../models/app_language.dart';
import 'storage_provider.dart';

class LocaleNotifier extends Notifier<AppLanguage> {
  @override
  AppLanguage build() {
    try {
      final storage = ref.read(storageServiceProvider);
      return storage.getLanguage();
    } catch (_) {
      return AppLanguage.english;
    }
  }

  Future<void> setLanguage(AppLanguage language) async {
    state = language;
    try {
      final storage = ref.read(storageServiceProvider);
      await storage.setLanguage(language);
    } catch (_) {}
  }

  Future<void> toggleLanguage() async {
    final next =
        state == AppLanguage.english ? AppLanguage.nepali : AppLanguage.english;
    await setLanguage(next);
  }
}

final localeProvider = NotifierProvider<LocaleNotifier, AppLanguage>(
  LocaleNotifier.new,
);

final currentLocaleProvider = Provider<Locale>((ref) {
  final appLang = ref.watch(localeProvider);
  return appLang.locale;
});
