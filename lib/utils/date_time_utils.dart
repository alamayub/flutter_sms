import 'package:intl/intl.dart';
import 'package:nepali_utils/nepali_utils.dart';
import '../models/calendar_mode.dart';

class DateTimeUtils {
  // Month Names
  static const List<String> bsMonthNamesEn = [
    'Baisakh',
    'Jestha',
    'Ashadh',
    'Shrawan',
    'Bhadra',
    'Ashwin',
    'Kartik',
    'Mangsir',
    'Poush',
    'Magh',
    'Falgun',
    'Chaitra',
  ];

  static const List<String> bsMonthNamesNe = [
    'बैशाख',
    'जेठ',
    'असार',
    'साउन',
    'भदौ',
    'असोज',
    'कात्तिक',
    'मंसिर',
    'पुष',
    'माघ',
    'फागुन',
    'चैत',
  ];

  /// Get current Nepali Date (BS)
  static NepaliDateTime get nowBs => NepaliDateTime.now();

  /// Get current Gregorian Date (AD)
  static DateTime get nowAd => DateTime.now();

  /// Convert AD (DateTime) to BS (NepaliDateTime)
  static NepaliDateTime adToBs(DateTime adDate) {
    return adDate.toNepaliDateTime();
  }

  /// Convert BS (NepaliDateTime) to AD (DateTime)
  static DateTime bsToAd(NepaliDateTime bsDate) {
    return bsDate.toDateTime();
  }

  /// Format AD Date
  static String formatAd(DateTime date, {String pattern = 'yyyy-MM-dd'}) {
    return DateFormat(pattern).format(date);
  }

  /// Format BS Date with optional Nepali numerals / language
  static String formatBs(
    NepaliDateTime date, {
    String pattern = 'yyyy-MM-dd',
    bool inNepaliScript = false,
  }) {
    final language = inNepaliScript ? Language.nepali : Language.english;
    return NepaliDateFormat(pattern, language).format(date);
  }

  /// Get dual-calendar formatted string
  /// Example: "2081-01-15 BS (2024-04-28 AD)"
  static String formatDual({
    required DateTime date,
    CalendarMode primary = CalendarMode.bs,
    bool showBoth = true,
    bool inNepaliScript = false,
  }) {
    final bsDate = adToBs(date);
    final bsStr =
        '${formatBs(bsDate, pattern: 'yyyy-MM-dd', inNepaliScript: inNepaliScript)} BS';
    final adStr = '${formatAd(date, pattern: 'yyyy-MM-dd')} AD';

    if (!showBoth) {
      return primary == CalendarMode.bs ? bsStr : adStr;
    }

    return primary == CalendarMode.bs ? '$bsStr ($adStr)' : '$adStr ($bsStr)';
  }

  /// Format Date according to current user preference
  static String formatDateByMode(
    DateTime date, {
    required CalendarMode mode,
    bool inNepaliScript = false,
  }) {
    if (mode == CalendarMode.bs) {
      final bs = adToBs(date);
      return '${formatBs(bs, pattern: 'yyyy-MM-dd', inNepaliScript: inNepaliScript)} BS';
    } else {
      return '${formatAd(date, pattern: 'yyyy-MM-dd')} AD';
    }
  }

  /// Get human-readable month name for BS
  static String getBsMonthName(int month, {bool inNepaliScript = false}) {
    if (month < 1 || month > 12) return '';
    return inNepaliScript
        ? bsMonthNamesNe[month - 1]
        : bsMonthNamesEn[month - 1];
  }

  /// Calculate Academic Year string based on date
  /// In Nepal, academic session usually starts in Baisakh (month 1 of BS)
  static String getAcademicYearBs(NepaliDateTime date) {
    final year = date.year;
    final nextYear = (year + 1) % 100;
    return '$year/${nextYear.toString().padLeft(2, '0')}';
  }

  /// Parse BS Date String in yyyy-MM-dd format
  static NepaliDateTime? tryParseBs(String dateStr) {
    try {
      return NepaliDateTime.parse(dateStr);
    } catch (_) {
      return null;
    }
  }

  /// Parse AD Date String in yyyy-MM-dd format
  static DateTime? tryParseAd(String dateStr) {
    try {
      return DateTime.parse(dateStr);
    } catch (_) {
      return null;
    }
  }

  /// Relative time description (e.g. Today, Yesterday, X days ago)
  static String getRelativeTime(DateTime dateTime, {bool isNepali = false}) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return isNepali ? 'आज' : 'Today';
    } else if (difference.inDays == 1) {
      return isNepali ? 'हिजो' : 'Yesterday';
    } else if (difference.inDays < 7) {
      return isNepali
          ? '${difference.inDays} दिन अघि'
          : '${difference.inDays} days ago';
    } else {
      return DateFormat('MMM d, yyyy').format(dateTime);
    }
  }
}
