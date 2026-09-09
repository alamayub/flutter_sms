// lib/core/utils/date_helpers.dart
import 'package:intl/intl.dart';

class DateHelpers {
  static final DateFormat _isoDateFormat = DateFormat('yyyy-MM-dd');
  static final DateFormat _displayDateFormat = DateFormat('MMM dd, yyyy');
  static final DateFormat _displayDateTimeFormat =
      DateFormat('MMM dd, yyyy hh:mm a');

  /// Formats DateTime as 'YYYY-MM-DD'.
  static String toIsoDate(DateTime date) => _isoDateFormat.format(date);

  /// Formats today as 'YYYY-MM-DD'.
  static String todayIsoDate() => toIsoDate(DateTime.now());

  /// Parses 'YYYY-MM-DD' into a normalized DateTime (at 00:00:00).
  static DateTime parseIsoDate(String isoDate) => _isoDateFormat.parse(isoDate);

  /// Displays date nicely (e.g., 'Sep 09, 2026').
  static String formatDisplayDate(DateTime date) =>
      _displayDateFormat.format(date);

  /// Displays ISO date string nicely.
  static String formatIsoDisplayDate(String isoDate) {
    try {
      return formatDisplayDate(parseIsoDate(isoDate));
    } catch (_) {
      return isoDate;
    }
  }

  /// Displays DateTime nicely with time (e.g. 'Sep 09, 2026 10:30 AM').
  static String formatDisplayDateTime(DateTime dateTime) =>
      _displayDateTimeFormat.format(dateTime);

  /// Converts 'HH:mm' time string into minutes since midnight (e.g. '09:45' -> 585).
  static int timeStringToMinutes(String timeStr) {
    final parts = timeStr.trim().split(':');
    if (parts.length != 2) return 0;
    final hours = int.tryParse(parts[0]) ?? 0;
    final minutes = int.tryParse(parts[1]) ?? 0;
    return hours * 60 + minutes;
  }

  /// Checks whether two time intervals [startA, endA) and [startB, endB) overlap.
  static bool doTimeIntervalsOverlap({
    required String startA,
    required String endA,
    required String startB,
    required String endB,
  }) {
    final aStart = timeStringToMinutes(startA);
    final aEnd = timeStringToMinutes(endA);
    final bStart = timeStringToMinutes(startB);
    final bEnd = timeStringToMinutes(endB);

    return aStart < bEnd && bStart < aEnd;
  }
}

