// lib/features/finance/domain/finance_models.dart
import 'money.dart';

enum FeeFrequency {
  oneTime,
  monthly,
  quarterly,
  term,
  halfYearly,
  yearly,
  custom;

  String get displayName {
    switch (this) {
      case FeeFrequency.oneTime:
        return 'One-Time';
      case FeeFrequency.monthly:
        return 'Monthly';
      case FeeFrequency.quarterly:
        return 'Quarterly';
      case FeeFrequency.term:
        return 'Per Term';
      case FeeFrequency.halfYearly:
        return 'Half-Yearly';
      case FeeFrequency.yearly:
        return 'Yearly';
      case FeeFrequency.custom:
        return 'Custom';
    }
  }

  static FeeFrequency fromString(String value) {
    return FeeFrequency.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => FeeFrequency.monthly,
    );
  }
}

enum FeeStatus {
  upcoming,
  due,
  overdue,
  paid,
  partially_paid,
  waived;

  String get displayName {
    switch (this) {
      case FeeStatus.upcoming:
        return 'Upcoming';
      case FeeStatus.due:
        return 'Due';
      case FeeStatus.overdue:
        return 'Overdue';
      case FeeStatus.paid:
        return 'Paid';
      case FeeStatus.partially_paid:
        return 'Partially Paid';
      case FeeStatus.waived:
        return 'Waived';
    }
  }

  static FeeStatus fromString(String value) {
    return FeeStatus.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => FeeStatus.due,
    );
  }
}

enum PaymentMethod {
  cash,
  bankTransfer,
  cheque,
  advanceCredit,
  other;

  String get displayName {
    switch (this) {
      case PaymentMethod.cash:
        return 'Cash';
      case PaymentMethod.bankTransfer:
        return 'Bank Transfer';
      case PaymentMethod.cheque:
        return 'Cheque';
      case PaymentMethod.advanceCredit:
        return 'Advance Credit';
      case PaymentMethod.other:
        return 'Other';
    }
  }

  static PaymentMethod fromString(String value) {
    return PaymentMethod.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => PaymentMethod.cash,
    );
  }
}

enum DiscountType {
  fixed,
  percentage;

  String get displayName => this == fixed ? 'Fixed Amount' : 'Percentage (%)';

  static DiscountType fromString(String value) {
    return DiscountType.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => DiscountType.fixed,
    );
  }
}

enum DiscountReason {
  scholarship,
  sibling,
  staffChild,
  needBased,
  earlyPayment,
  custom;

  String get displayName {
    switch (this) {
      case DiscountReason.scholarship:
        return 'Merit Scholarship';
      case DiscountReason.sibling:
        return 'Sibling Concession';
      case DiscountReason.staffChild:
        return 'Staff Child';
      case DiscountReason.needBased:
        return 'Need-based Aid';
      case DiscountReason.earlyPayment:
        return 'Early Payment Discount';
      case DiscountReason.custom:
        return 'Custom';
    }
  }

  static DiscountReason fromString(String value) {
    return DiscountReason.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => DiscountReason.custom,
    );
  }
}

enum ExpenseCategory {
  utilities,
  rent,
  maintenance,
  salaries,
  stationery,
  events,
  transport,
  other;

  String get displayName {
    switch (this) {
      case ExpenseCategory.utilities:
        return 'Utilities';
      case ExpenseCategory.rent:
        return 'Rent';
      case ExpenseCategory.maintenance:
        return 'Maintenance & Repairs';
      case ExpenseCategory.salaries:
        return 'Salaries & Wages';
      case ExpenseCategory.stationery:
        return 'Books & Stationery';
      case ExpenseCategory.events:
        return 'Sports & Events';
      case ExpenseCategory.transport:
        return 'Transport & Fuel';
      case ExpenseCategory.other:
        return 'Other Expense';
    }
  }

  static ExpenseCategory fromString(String value) {
    return ExpenseCategory.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => ExpenseCategory.other,
    );
  }
}

enum IncomeCategory {
  donations,
  grants,
  canteen,
  bookStore,
  uniformStore,
  facilitiesRent,
  other;

  String get displayName {
    switch (this) {
      case IncomeCategory.donations:
        return 'Donations';
      case IncomeCategory.grants:
        return 'Government Grants';
      case IncomeCategory.canteen:
        return 'Canteen / Cafeteria';
      case IncomeCategory.bookStore:
        return 'Book Store';
      case IncomeCategory.uniformStore:
        return 'Uniform Store';
      case IncomeCategory.facilitiesRent:
        return 'Hall / Facilities Rental';
      case IncomeCategory.other:
        return 'Other Income';
    }
  }

  static IncomeCategory fromString(String value) {
    return IncomeCategory.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () => IncomeCategory.other,
    );
  }
}

/// Ledger Entry for Student statement
enum LedgerEntryType {
  invoice,
  payment,
  advanceCredit,
  waiver,
  reversal;

  String get displayName {
    switch (this) {
      case LedgerEntryType.invoice:
        return 'Fee Invoiced';
      case LedgerEntryType.payment:
        return 'Payment Received';
      case LedgerEntryType.advanceCredit:
        return 'Advance Credited';
      case LedgerEntryType.waiver:
        return 'Fee Waived';
      case LedgerEntryType.reversal:
        return 'Payment Reversed';
    }
  }
}

class StudentLedgerEntry {
  final DateTime date;
  final LedgerEntryType type;
  final String referenceId;
  final String description;
  final Money debit; // Invoiced charge or reversed payment
  final Money credit; // Payment or waiver or advance credit
  final Money runningBalance; // Positive = student owes money, Negative = excess/advance

  const StudentLedgerEntry({
    required this.date,
    required this.type,
    required this.referenceId,
    required this.description,
    required this.debit,
    required this.credit,
    required this.runningBalance,
  });
}

class ReceiptItem {
  final String feeTitle;
  final String period;
  final Money amount;

  const ReceiptItem({
    required this.feeTitle,
    required this.period,
    required this.amount,
  });
}

class ReceiptModel {
  final String receiptNumber;
  final String? offlineReceiptNumber;
  final DateTime date;
  final String studentId;
  final String studentName;
  final String? rollNumber;
  final String className;
  final String? sectionName;
  final List<ReceiptItem> items;
  final Money totalAmount;
  final Money paidAmount;
  final Money remainingBalance;
  final PaymentMethod paymentMethod;
  final String? reference;
  final String collectedByName;
  final String? remarks;
  final bool isReprint;
  final bool isReversed;
  final bool isAdvance;
  final String schoolName;
  final String? schoolAddress;
  final String? schoolPhone;
  final String currencySymbol;

  const ReceiptModel({
    required this.receiptNumber,
    this.offlineReceiptNumber,
    required this.date,
    required this.studentId,
    required this.studentName,
    this.rollNumber,
    required this.className,
    this.sectionName,
    required this.items,
    required this.totalAmount,
    required this.paidAmount,
    required this.remainingBalance,
    required this.paymentMethod,
    this.reference,
    required this.collectedByName,
    this.remarks,
    this.isReprint = false,
    this.isReversed = false,
    this.isAdvance = false,
    required this.schoolName,
    this.schoolAddress,
    this.schoolPhone,
    this.currencySymbol = 'Rs.',
  });
}
