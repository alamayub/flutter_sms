class AppConstants {
  static const String appName = 'School Management System';
  static const String appShortName = 'SMS';
  static const String appVersion = '1.0.0';

  // Storage Keys for SharedPreferences
  static const String keyThemeMode = 'sms_theme_mode';
  static const String keyLanguage = 'sms_language';
  static const String keyCalendarMode = 'sms_calendar_mode';
  static const String keyActiveYearId = 'sms_active_academic_year';

  // Breakpoints
  static const double mobileBreakpoint = 650.0;
  static const double tabletBreakpoint = 1100.0;

  // Defaults
  static const String defaultCurrency = 'NPR';
  static const String defaultCurrencySymbol = 'Rs. ';
  static const String nepaliCurrencySymbol = 'रू ';

  // Nepal Phone Regex (98XXXXXXXX, 97XXXXXXXX)
  static const String nepaliMobileRegex = r'^(98|97)[0-9]{8}$';
}
