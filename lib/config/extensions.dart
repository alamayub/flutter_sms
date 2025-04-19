// ignore_for_file: unnecessary_this

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import 'typo_config.dart';

extension DialogText on String {
  Widget get dialogTitle => Text(
    this,
    style: typoConfig.textStyle.smallBodyBodyText2.copyWith(
      height: 1,
      fontWeight: FontWeight.w600,
    ),
  );
}

extension ContextExtensions on BuildContext {
  bool get isMobile => MediaQuery.of(this).size.width < 600;
  bool get isTablet => MediaQuery.of(this).size.width >= 600;
  bool get isDesktop => MediaQuery.of(this).size.width >= 1024;
  double get screenWidth => MediaQuery.of(this).size.width;
  double get screenHeight => MediaQuery.of(this).size.height;

  // show snackbbar
  void showSnackbar(
    String message, {
    Duration duration = const Duration(seconds: 4),
  }) {
    final snackBar = SnackBar(content: Text(message), duration: duration);
    ScaffoldMessenger.of(this).showSnackBar(snackBar);
  }

  /// Push to a new screen
  void push(Widget screen) {
    Navigator.push(this, MaterialPageRoute(builder: (context) => screen));
  }

  /// Push and replace current screen
  void pushReplacement(Widget screen) {
    Navigator.pushReplacement(
      this,
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  /// Push and clear all previous screens
  void pushAndRemoveUntil(Widget screen) {
    Navigator.pushAndRemoveUntil(
      this,
      MaterialPageRoute(builder: (context) => screen),
      (route) => false,
    );
  }
}

extension StringExtensions on String {
  String get initialLetters =>
      isNotEmpty
          ? trim().split(' ').map((l) => l[0]).take(2).join().toUpperCase()
          : '';
  String get capitalize {
    return isNotEmpty
        ? trim()
            .split(' ')
            .map(
              (e) =>
                  e.isNotEmpty ? '${e[0].toUpperCase()}${e.substring(1)}' : '',
            )
            .join(' ')
        : '';
  }

  bool get isEmail =>
      RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(this);

  bool get isPhoneNumber => RegExp(r'^\d{10}$').hasMatch(this);

  String toCamelCase() {
    final words = trim().split(RegExp(r'\s+'));
    if (words.isEmpty) return '';

    return words
        .asMap()
        .entries
        .map((entry) {
          final index = entry.key;
          final word = entry.value;
          if (index == 0) {
            return word.toLowerCase();
          }
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        })
        .join('');
  }

  String get removeHtmlTags {
    final regex = RegExp(r'<[^>]+>');
    String content = this.replaceAll(regex, '');
    return content;
  }
}

extension DateTimeExtensions on int {
  String get formattedDate {
    var date = DateTime.fromMillisecondsSinceEpoch(this);
    return DateFormat('yyyy-MM-dd').format(date);
  }

  String get formattedTime {
    var date = DateTime.fromMillisecondsSinceEpoch(this);
    return DateFormat().add_jm().format(date);
  }
}

extension StringTimeExtensions on String? {
  String get formattedTimeFromString {
    if (this != null && this!.isNotEmpty) {
      var res = this!.split(':');
      var hour = int.parse(res[0]);
      var minute = int.parse(res[1]);
      var now = DateTime.now();
      var dateTime = DateTime(now.year, now.month, now.day, hour, minute);
      return DateFormat('hh:mm a').format(dateTime);
    }
    return '--:--';
  }
}

extension DateDifferenceInMinutes on DateTime {
  int getDifferentInMinutes(DateTime otherDate) =>
      otherDate.difference(this).inMinutes;

  // Example: 2024-12-15 00:28:38Z
  String toCustomDateFormat() {
    String isoString = toUtc().toIso8601String().replaceFirst('T', ' ');
    return '${isoString.split('.').first}Z';
  }
}

extension GreetDateTimeExtensions on DateTime {
  bool get isChristmas => month == 12 && day == 25;
  bool get isNewYear => month == 1 && day == 1;
  bool get isWeekend =>
      weekday == DateTime.saturday || weekday == DateTime.sunday;
}

extension DateDifferenceInDays on String {
  String getDifferenceInDays() {
    if (this.isNotEmpty && this.length > 5) {
      var x = DateTime.parse(this);
      var diff = x.difference(DateTime.now());
      if (diff.isNegative) return 'Expired';
      if (diff.inDays == 0) return 'Expires Today';
      return 'Expires in ${diff.inDays} days';
    }
    return '--:--';
  }
}

extension DateHistoryFormat on DateTime {
  String getHistoryDate() {
    var now = DateTime.now();
    if (now.difference(this).inDays == 0) {
      return 'Today';
    } else if (now.difference(this).inDays == 1) {
      return 'Yesterday';
    }
    return DateFormat('yyyy-MM-dd').format(this);
  }
}
