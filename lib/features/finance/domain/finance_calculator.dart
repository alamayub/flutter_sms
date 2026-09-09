// lib/features/finance/domain/finance_calculator.dart
import 'dart:math';
import 'finance_models.dart';
import 'money.dart';

class PaymentAllocation {
  final String studentFeeId;
  final int allocatedCents;
  final int newPaidAmountCents;
  final int newRemainingAmountCents;
  final FeeStatus newStatus;

  const PaymentAllocation({
    required this.studentFeeId,
    required this.allocatedCents,
    required this.newPaidAmountCents,
    required this.newRemainingAmountCents,
    required this.newStatus,
  });
}

class PaymentDistributionResult {
  final List<PaymentAllocation> allocations;
  final int totalAllocatedCents;
  final int excessAdvanceCents;

  const PaymentDistributionResult({
    required this.allocations,
    required this.totalAllocatedCents,
    required this.excessAdvanceCents,
  });
}

/// Central accounting calculation engine for school fees.
class FinanceCalculator {
  /// Calculates discount amount in cents based on discount type and value.
  static int calculateDiscountCents({
    required int grossAmountCents,
    required DiscountType type,
    required double value,
  }) {
    if (grossAmountCents <= 0 || value <= 0) return 0;

    int discountCents;
    if (type == DiscountType.percentage) {
      discountCents = Money(grossAmountCents).percentage(value).cents;
    } else {
      // Fixed amount discount in normal currency units (e.g. 500.0 -> 50000 cents)
      discountCents = Money.fromDouble(value).cents;
    }

    return min(grossAmountCents, discountCents);
  }

  /// Calculates net amount = max(0, gross - discount).
  static int calculateNetAmountCents({
    required int grossAmountCents,
    required int discountAmountCents,
  }) {
    return max(0, grossAmountCents - discountAmountCents);
  }

  /// Calculates remaining balance = max(0, net - paid).
  static int calculateRemainingAmountCents({
    required int netAmountCents,
    required int paidAmountCents,
  }) {
    return max(0, netAmountCents - paidAmountCents);
  }

  /// Determines the status of a fee item.
  static FeeStatus determineFeeStatus({
    required DateTime dueDate,
    required int netAmountCents,
    required int paidAmountCents,
    bool isWaived = false,
    DateTime? now,
  }) {
    if (isWaived) return FeeStatus.waived;
    if (paidAmountCents >= netAmountCents) return FeeStatus.paid;

    final currentTime = now ?? DateTime.now();
    final isPastDue = currentTime.isAfter(dueDate);

    if (paidAmountCents > 0) {
      return FeeStatus.partially_paid;
    }

    return isPastDue ? FeeStatus.overdue : FeeStatus.due;
  }

  /// Distributes a payment amount across a list of fee dues.
  /// Any remaining amount not consumed by the dues is returned as [excessAdvanceCents].
  static PaymentDistributionResult distributePayment({
    required List<Map<String, dynamic>> dues, // Must contain 'id', 'netAmountCents', 'paidAmountCents', 'dueDate'
    required int paymentAmountCents,
    DateTime? now,
  }) {
    int remainingPayment = paymentAmountCents;
    final allocations = <PaymentAllocation>[];
    int totalAllocated = 0;

    for (final due in dues) {
      if (remainingPayment <= 0) break;

      final feeId = due['id'] as String;
      final netCents = due['netAmountCents'] as int;
      final currentPaidCents = due['paidAmountCents'] as int;
      final dueDate = due['dueDate'] as DateTime;
      final remainingDueCents = max(0, netCents - currentPaidCents);

      if (remainingDueCents <= 0) continue;

      final allocatedCents = min(remainingPayment, remainingDueCents);
      final newPaidCents = currentPaidCents + allocatedCents;
      final newRemainingCents = netCents - newPaidCents;
      final newStatus = determineFeeStatus(
        dueDate: dueDate,
        netAmountCents: netCents,
        paidAmountCents: newPaidCents,
        now: now,
      );

      allocations.add(
        PaymentAllocation(
          studentFeeId: feeId,
          allocatedCents: allocatedCents,
          newPaidAmountCents: newPaidCents,
          newRemainingAmountCents: newRemainingCents,
          newStatus: newStatus,
        ),
      );

      totalAllocated += allocatedCents;
      remainingPayment -= allocatedCents;
    }

    return PaymentDistributionResult(
      allocations: allocations,
      totalAllocatedCents: totalAllocated,
      excessAdvanceCents: remainingPayment,
    );
  }

  /// Computes student outstanding dues summary.
  static int computeTotalOutstandingCents(List<Map<String, dynamic>> feeDues) {
    int sum = 0;
    for (final fee in feeDues) {
      final isWaived = (fee['isWaived'] as bool?) ?? false;
      if (isWaived) continue;
      final netCents = (fee['netAmountCents'] as int?) ?? 0;
      final paidCents = (fee['paidAmountCents'] as int?) ?? 0;
      sum += max(0, netCents - paidCents);
    }
    return sum;
  }
}
