import 'package:intl/intl.dart';

class Formatters {
  // Digit mapping
  static const Map<String, String> _enToNeDigits = {
    '0': '०',
    '1': '१',
    '2': '२',
    '3': '३',
    '4': '४',
    '5': '५',
    '6': '६',
    '7': '७',
    '8': '८',
    '9': '९',
  };

  static const Map<String, String> _neToEnDigits = {
    '०': '0',
    '१': '1',
    '२': '2',
    '३': '3',
    '४': '4',
    '५': '5',
    '६': '6',
    '७': '7',
    '८': '8',
    '९': '9',
  };

  /// Convert English digits to Nepali Devanagari numerals
  /// e.g. "12345" -> "१२३४५"
  static String toNepaliNumerals(dynamic input) {
    if (input == null) return '';
    final str = input.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      final char = str[i];
      buffer.write(_enToNeDigits[char] ?? char);
    }
    return buffer.toString();
  }

  /// Convert Nepali Devanagari numerals to English digits
  /// e.g. "१२३४५" -> "12345"
  static String toEnglishNumerals(String input) {
    final buffer = StringBuffer();
    for (int i = 0; i < input.length; i++) {
      final char = input[i];
      buffer.write(_neToEnDigits[char] ?? char);
    }
    return buffer.toString();
  }

  /// Format Currency (Supports South Asian / Nepali numbering system: lakhs and crores)
  /// Example: 1500000 -> "Rs. 15,00,000.00" or "रू १५,००,०००.००"
  static String formatCurrency(
    num amount, {
    bool isNepali = false,
    bool showDecimal = true,
  }) {
    // en_IN / ne_NP format groups 3 digits, then 2 digits (e.g. 1,00,000)
    final pattern = showDecimal ? '#,##,##0.00' : '#,##,##0';
    final formatter = NumberFormat(pattern, 'en_IN');
    final formatted = formatter.format(amount);

    if (isNepali) {
      return 'रू ${toNepaliNumerals(formatted)}';
    } else {
      return 'Rs. $formatted';
    }
  }

  /// Format Fee amount with simple notation
  static String formatFee(num amount, {bool isNepali = false}) {
    return formatCurrency(amount, isNepali: isNepali, showDecimal: false);
  }

  /// Format percentage
  static String formatPercentage(double percent, {bool isNepali = false}) {
    final formatted = percent.toStringAsFixed(1);
    if (isNepali) {
      return '${toNepaliNumerals(formatted)}%';
    }
    return '$formatted%';
  }

  /// Format Nepali mobile numbers (e.g. 9841234567 -> 9841-234567)
  static String formatPhoneNumber(String phone) {
    final clean = phone.replaceAll(RegExp(r'\D'), '');
    if (clean.length == 10) {
      return '${clean.substring(0, 4)}-${clean.substring(4)}';
    }
    return phone;
  }

  /// Format file size for offline backups / PDF downloads
  static String formatBytes(int bytes, {int decimals = 1}) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double count = bytes.toDouble();
    while (count >= 1024 && i < suffixes.length - 1) {
      count /= 1024;
      i++;
    }
    return '${count.toStringAsFixed(decimals)} ${suffixes[i]}';
  }
}
