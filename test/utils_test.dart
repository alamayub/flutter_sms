import 'package:flutter_test/flutter_test.dart';
import 'package:sms/config/constants.dart';
import 'package:sms/config/translations.dart';
import 'package:sms/models/calendar_mode.dart';
import 'package:sms/utils/date_time_utils.dart';
import 'package:sms/utils/formatters.dart';
import 'package:sms/utils/validators.dart';

void main() {
  group('DateTimeUtils & Nepali Calendar Tests', () {
    test('AD to BS conversion works properly', () {
      // 2024-04-13 is approx 2081-01-01 BS (Nepali New Year)
      final adDate = DateTime(2024, 4, 13);
      final bsDate = DateTimeUtils.adToBs(adDate);
      expect(bsDate.year, 2081);
      expect(bsDate.month, 1);
      expect(bsDate.day, 1);
    });

    test('BS Month names in English and Nepali', () {
      expect(DateTimeUtils.getBsMonthName(1), 'Baisakh');
      expect(DateTimeUtils.getBsMonthName(1, inNepaliScript: true), 'बैशाख');
      expect(DateTimeUtils.getBsMonthName(12), 'Chaitra');
      expect(DateTimeUtils.getBsMonthName(12, inNepaliScript: true), 'चैत');
    });

    test('Dual Date formatting displays both systems', () {
      final date = DateTime(2024, 4, 13);
      final dual = DateTimeUtils.formatDual(
        date: date,
        primary: CalendarMode.bs,
        showBoth: true,
      );
      expect(dual, contains('2081-01-01 BS'));
      expect(dual, contains('2024-04-13 AD'));
    });
  });

  group('Formatters Tests', () {
    test('Converts English digits to Nepali Devanagari numerals', () {
      expect(Formatters.toNepaliNumerals('1234567890'), '१२३४५६७८९०');
      expect(Formatters.toEnglishNumerals('१२३४५६७८९०'), '1234567890');
    });

    test('Formats currency with lakhs and crores system', () {
      final formattedEn = Formatters.formatCurrency(
        150000,
        isNepali: false,
        showDecimal: false,
      );
      expect(formattedEn, 'Rs. 1,50,000');

      final formattedNe = Formatters.formatCurrency(
        150000,
        isNepali: true,
        showDecimal: false,
      );
      expect(formattedNe, 'रू १,५०,०००');
    });

    test('Formats phone number with hyphen', () {
      expect(Formatters.formatPhoneNumber('9841234567'), '9841-234567');
    });
  });

  group('Validators Tests', () {
    test('Validates required fields', () {
      expect(Validators.requiredField(''), isNotNull);
      expect(Validators.requiredField(null), isNotNull);
      expect(Validators.requiredField('Valid Text'), isNull);
    });

    test('Validates Nepali mobile numbers (98/97)', () {
      expect(Validators.nepaliPhone('9841234567'), isNull);
      expect(Validators.nepaliPhone('9741234567'), isNull);
      expect(Validators.nepaliPhone('1234567890'), isNotNull);
      expect(Validators.nepaliPhone('984123'), isNotNull);
    });
  });

  group('Translations & Constants', () {
    test('Retrieves correct bilingual strings', () {
      expect(AppTranslations.text('dashboard', 'en'), 'Dashboard');
      expect(AppTranslations.text('dashboard', 'ne'), 'ड्यासबोर्ड');
      expect(AppTranslations.text('students', 'en'), 'Students');
      expect(AppTranslations.text('students', 'ne'), 'विद्यार्थीहरू');
    });

    test('AppConstants values are correct', () {
      expect(AppConstants.mobileBreakpoint, 650.0);
      expect(AppConstants.tabletBreakpoint, 1100.0);
    });
  });
}
