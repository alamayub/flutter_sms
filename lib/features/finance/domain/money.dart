// lib/features/finance/domain/money.dart
import 'package:intl/intl.dart';

/// Immutable value object representing money in integer minor units (cents / paisa).
/// Ensures zero floating-point arithmetic errors across all financial operations.
class Money implements Comparable<Money> {
  final int cents;

  const Money(this.cents);

  static const Money zero = Money(0);

  /// Factory constructor to create Money from a double amount (e.g. 150.75 -> 15075 cents).
  factory Money.fromDouble(double amount) {
    return Money((amount * 100).round());
  }

  /// Converts the integer cents to double for display or compatibility.
  double get toDouble => cents / 100.0;

  Money operator +(Money other) => Money(cents + other.cents);

  Money operator -(Money other) => Money(cents - other.cents);

  Money operator *(num factor) => Money((cents * factor).round());

  Money operator -() => Money(-cents);

  bool operator <(Money other) => cents < other.cents;

  bool operator <=(Money other) => cents <= other.cents;

  bool operator >(Money other) => cents > other.cents;

  bool operator >=(Money other) => cents >= other.cents;

  @override
  int compareTo(Money other) => cents.compareTo(other.cents);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Money && runtimeType == other.runtimeType && cents == other.cents;

  @override
  int get hashCode => cents.hashCode;

  /// Calculates a percentage of this money, rounded to the nearest cent.
  /// E.g. Money(10000).percentage(15.0) -> Money(1500) (15% of 100.00 = 15.00).
  Money percentage(double percent) {
    return Money(((cents * percent) / 100.0).round());
  }

  /// Formats the money with a dynamic currency symbol and decimal places.
  /// Examples:
  /// - Money(150000).format(symbol: 'Rs.') -> 'Rs. 1,500.00'
  /// - Money(5000).format(symbol: '$') -> '$ 50.00'
  /// - Money(-2500).format(symbol: 'Rs.') -> '-Rs. 25.00'
  String format({
    String symbol = 'Rs.',
    int decimals = 2,
    bool showSymbol = true,
  }) {
    final isNegative = cents < 0;
    final absCents = cents.abs();

    final whole = absCents ~/ 100;
    final fraction = absCents % 100;

    final formatter = NumberFormat('#,##0');
    final formattedWhole = formatter.format(whole);

    String formattedNumber;
    if (decimals == 0) {
      formattedNumber = formattedWhole;
    } else if (decimals == 2) {
      formattedNumber = '$formattedWhole.${fraction.toString().padLeft(2, '0')}';
    } else {
      final fractionStr = fraction.toString().padLeft(2, '0');
      if (decimals > 2) {
        formattedNumber = '$formattedWhole.${fractionStr.padRight(decimals, '0')}';
      } else {
        formattedNumber = '$formattedWhole.${fractionStr.substring(0, decimals)}';
      }
    }

    final sign = isNegative ? '-' : '';
    if (showSymbol && symbol.isNotEmpty) {
      return '$sign$symbol $formattedNumber';
    }
    return '$sign$formattedNumber';
  }

  @override
  String toString() => format();
}
