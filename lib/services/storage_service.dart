import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/constants.dart';
import '../models/app_language.dart';
import '../models/calendar_mode.dart';
import '../models/school_profile.dart';
import '../models/theme_preference.dart';

class StorageService {
  static const String keySchoolProfile = 'sms_school_profile';
  static const String keySessionActive = 'sms_session_active';

  final SharedPreferences _prefs;

  StorageService(this._prefs);

  static Future<StorageService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return StorageService(prefs);
  }

  // Theme Mode
  AppThemeMode getThemeMode() {
    final val = _prefs.getString(AppConstants.keyThemeMode);
    return AppThemeMode.fromString(val);
  }

  Future<bool> setThemeMode(AppThemeMode mode) {
    return _prefs.setString(AppConstants.keyThemeMode, mode.name);
  }

  // Language
  AppLanguage getLanguage() {
    final code = _prefs.getString(AppConstants.keyLanguage);
    return AppLanguage.fromCode(code);
  }

  Future<bool> setLanguage(AppLanguage language) {
    return _prefs.setString(
      AppConstants.keyLanguage,
      language.locale.languageCode,
    );
  }

  // Calendar Mode (AD / BS)
  CalendarMode getCalendarMode() {
    final val = _prefs.getString(AppConstants.keyCalendarMode);
    if (val == 'ad') return CalendarMode.ad;
    return CalendarMode.bs; // Default to Bikram Sambat in Nepal
  }

  Future<bool> setCalendarMode(CalendarMode mode) {
    return _prefs.setString(AppConstants.keyCalendarMode, mode.name);
  }

  // Active Academic Year ID
  int? getActiveAcademicYearId() {
    return _prefs.getInt(AppConstants.keyActiveYearId);
  }

  Future<bool> setActiveAcademicYearId(int id) {
    return _prefs.setInt(AppConstants.keyActiveYearId, id);
  }

  // School Profile & Registration
  SchoolProfile getSchoolProfile() {
    final raw = _prefs.getString(keySchoolProfile);
    if (raw == null || raw.isEmpty) {
      return SchoolProfile.initial();
    }
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return SchoolProfile.fromJson(map);
    } catch (_) {
      return SchoolProfile.initial();
    }
  }

  Future<bool> saveSchoolProfile(SchoolProfile profile) {
    return _prefs.setString(keySchoolProfile, jsonEncode(profile.toJson()));
  }

  bool isSchoolRegistered() {
    return getSchoolProfile().isRegistered;
  }

  // Active Login Session
  bool isSessionActive() {
    return _prefs.getBool(keySessionActive) ?? false;
  }

  Future<bool> setSessionActive(bool active) {
    return _prefs.setBool(keySessionActive, active);
  }
}
