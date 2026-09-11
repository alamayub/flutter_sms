import 'package:flutter/material.dart';

enum AppLanguage {
  english('English', 'English', Locale('en', 'US')),
  nepali('Nepali', 'नेपाली', Locale('ne', 'NP'));

  final String nameEn;
  final String nativeName;
  final Locale locale;

  const AppLanguage(this.nameEn, this.nativeName, this.locale);

  static AppLanguage fromCode(String? code) {
    if (code == 'ne') return AppLanguage.nepali;
    return AppLanguage.english;
  }
}
