import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../models/theme_preference.dart';
import 'storage_provider.dart';

class ThemeNotifier extends Notifier<AppThemeMode> {
  @override
  AppThemeMode build() {
    try {
      final storage = ref.read(storageServiceProvider);
      return storage.getThemeMode();
    } catch (_) {
      return AppThemeMode.system;
    }
  }

  Future<void> setTheme(AppThemeMode mode) async {
    state = mode;
    try {
      final storage = ref.read(storageServiceProvider);
      await storage.setThemeMode(mode);
    } catch (_) {}
  }

  Future<void> toggleTheme() async {
    final next =
        state == AppThemeMode.dark ? AppThemeMode.light : AppThemeMode.dark;
    await setTheme(next);
  }
}

final themeProvider = NotifierProvider<ThemeNotifier, AppThemeMode>(
  ThemeNotifier.new,
);

final themeModeProvider = Provider<ThemeMode>((ref) {
  final appThemeMode = ref.watch(themeProvider);
  return appThemeMode.mode;
});
