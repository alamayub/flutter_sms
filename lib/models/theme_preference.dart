import 'package:flutter/material.dart';

enum AppThemeMode {
  system(ThemeMode.system, 'System', 'प्रणाली'),
  light(ThemeMode.light, 'Light', 'उज्यालो'),
  dark(ThemeMode.dark, 'Dark', 'अध्यारो');

  final ThemeMode mode;
  final String labelEn;
  final String labelNe;

  const AppThemeMode(this.mode, this.labelEn, this.labelNe);

  static AppThemeMode fromString(String? val) {
    return switch (val) {
      'light' => AppThemeMode.light,
      'dark' => AppThemeMode.dark,
      _ => AppThemeMode.system,
    };
  }

  String localizedLabel(String langCode) {
    return langCode == 'ne' ? labelNe : labelEn;
  }
}
