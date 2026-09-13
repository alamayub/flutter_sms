part of 'app_database.dart';

@DataClassName('ExpenseCategory')
class ExpenseCategories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100).unique()();
  TextColumn get iconName => text().withDefault(const Constant('category'))();
  IntColumn get colorValue =>
      integer().withDefault(const Constant(0xFF78909C))();
  BoolColumn get isSystem => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('Expense')
class Expenses extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withLength(min: 1, max: 200)();
  IntColumn get categoryId =>
      integer().references(
        ExpenseCategories,
        #id,
        onDelete: KeyAction.cascade,
      )();
  RealColumn get amount => real()();
  DateTimeColumn get expenseDate => dateTime()();
  // 'Cash', 'Bank Transfer', 'Cheque', 'eSewa', 'Khalti', 'Other'
  TextColumn get paymentMethod => text().withDefault(const Constant('Cash'))();
  // Voucher / Bill / Receipt / Txn ID
  TextColumn get referenceNumber => text().nullable()();
  // Vendor / Payee / Landlord / Person
  TextColumn get paidTo => text().nullable()();
  TextColumn get notes => text().nullable()();
  // Local image receipt photo path
  TextColumn get receiptPath => text().nullable()();
  IntColumn get academicYearId =>
      integer().nullable().references(
        AcademicYears,
        #id,
        onDelete: KeyAction.setNull,
      )();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// Composite model linking Expense with its Category and Academic Year
class ExpenseWithCategory {
  final Expense expense;
  final ExpenseCategory category;
  final AcademicYear? academicYear;

  const ExpenseWithCategory({
    required this.expense,
    required this.category,
    this.academicYear,
  });

  int get id => expense.id;
  String get title => expense.title;
  double get amount => expense.amount;
  DateTime get expenseDate => expense.expenseDate;
  String get paymentMethod => expense.paymentMethod;
  String? get referenceNumber => expense.referenceNumber;
  String? get paidTo => expense.paidTo;
  String? get notes => expense.notes;
  String? get receiptPath => expense.receiptPath;
  String get categoryName => category.name;
  String get iconName => category.iconName;
  int get colorValue => category.colorValue;
}

@DataClassName('SalaryAdvance')
class SalaryAdvances extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get employeeId =>
      integer().references(Employees, #id, onDelete: KeyAction.cascade)();
  RealColumn get amount => real()();
  DateTimeColumn get advanceDate => dateTime()();
  RealColumn get adjustedAmount => real().withDefault(const Constant(0.0))();
  TextColumn get paymentMethod => text().withDefault(const Constant('Cash'))();
  TextColumn get referenceNumber => text().nullable()();
  TextColumn get reason => text().nullable()();
  TextColumn get notes => text().nullable()();
  IntColumn get academicYearId =>
      integer().nullable().references(
        AcademicYears,
        #id,
        onDelete: KeyAction.setNull,
      )();
  // 'pending', 'partially_adjusted', 'settled'
  TextColumn get status => text().withDefault(const Constant('pending'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('SalaryPayment')
class SalaryPayments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get employeeId =>
      integer().references(Employees, #id, onDelete: KeyAction.cascade)();
  IntColumn get academicYearId =>
      integer().nullable().references(
        AcademicYears,
        #id,
        onDelete: KeyAction.setNull,
      )();
  IntColumn get year => integer()(); // Pay year (e.g. 2026)
  IntColumn get month => integer()(); // Pay month (1-12)
  DateTimeColumn get paymentDate => dateTime()();
  RealColumn get basicSalary => real()();
  RealColumn get bonus => real().withDefault(const Constant(0.0))();
  TextColumn get bonusReason => text().nullable()();
  RealColumn get deduction => real().withDefault(const Constant(0.0))();
  TextColumn get deductionReason => text().nullable()();
  RealColumn get advanceDeduction => real().withDefault(const Constant(0.0))();
  RealColumn get grossSalary => real()(); // basicSalary + bonus
  RealColumn get totalDeductions => real()(); // deduction + advanceDeduction
  RealColumn get netSalary => real()(); // grossSalary - totalDeductions
  TextColumn get paymentMethod =>
      text().withDefault(const Constant('Bank Transfer'))();
  TextColumn get referenceNumber => text().nullable()();
  // 'paid', 'pending'
  TextColumn get status => text().withDefault(const Constant('paid'))();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('SalaryAdvanceAdjustment')
class SalaryAdvanceAdjustments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get salaryPaymentId =>
      integer().references(SalaryPayments, #id, onDelete: KeyAction.cascade)();
  IntColumn get salaryAdvanceId =>
      integer().references(SalaryAdvances, #id, onDelete: KeyAction.cascade)();
  RealColumn get adjustedAmount => real()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('FeeCategory')
class FeeCategories extends Table {
  IntColumn get id => integer().autoIncrement()();
  // e.g. "Monthly Tuition Fee", "Uniform & Dress", "Admission Fee", "Exam Fee"
  TextColumn get name => text()();
  // 'one_time', 'monthly', 'quarterly', 'half_yearly', 'yearly', 'term_wise'
  TextColumn get frequency => text().withDefault(const Constant('monthly'))();
  RealColumn get defaultAmount => real().withDefault(const Constant(0.0))();
  TextColumn get description => text().nullable()();
  BoolColumn get isSystem => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('StudentFee')
class StudentFees extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get studentId =>
      integer().references(Students, #id, onDelete: KeyAction.cascade)();
  IntColumn get academicYearId =>
      integer().nullable().references(
        AcademicYears,
        #id,
        onDelete: KeyAction.setNull,
      )();
  IntColumn get feeCategoryId =>
      integer().references(FeeCategories, #id, onDelete: KeyAction.cascade)();
  // e.g. "Baishakh Tuition Fee", "Grade 8 Uniform & Dress", "1st Term Exam Fee"
  TextColumn get title => text()();

  RealColumn get totalAmount => real()();
  RealColumn get discountAmount => real().withDefault(const Constant(0.0))();
  RealColumn get paidAmount => real().withDefault(const Constant(0.0))();
  DateTimeColumn get dueDate => dateTime().nullable()();
  // 'pending', 'partial', 'paid'
  TextColumn get status => text().withDefault(const Constant('pending'))();
  IntColumn get academicMonth => integer().nullable()(); // 1-12
  // 'Term 1', 'Term 2', 'Final Term'
  TextColumn get academicTerm => text().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('FeePayment')
class FeePayments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get studentFeeId =>
      integer().references(StudentFees, #id, onDelete: KeyAction.cascade)();
  IntColumn get studentId =>
      integer().references(Students, #id, onDelete: KeyAction.cascade)();
  IntColumn get academicYearId =>
      integer().nullable().references(
        AcademicYears,
        #id,
        onDelete: KeyAction.setNull,
      )();
  TextColumn get receiptNumber => text()();
  RealColumn get amount => real()();
  DateTimeColumn get paymentDate =>
      dateTime().withDefault(currentDateAndTime)();
  // 'Cash', 'Bank Transfer', 'eSewa', 'Khalti', 'Cheque', 'Online'
  TextColumn get paymentMethod => text().withDefault(const Constant('Cash'))();
  TextColumn get referenceNumber => text().nullable()();
  TextColumn get remarks => text().nullable()();
  TextColumn get receivedBy => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Composite model linking StudentFee with Student, FeeCategory, AcademicYear, and Payments
class StudentFeeWithDetails {
  final StudentFee fee;
  final Student student;
  final FeeCategory category;
  final AcademicYear? academicYear;
  final List<FeePayment> payments;

  const StudentFeeWithDetails({
    required this.fee,
    required this.student,
    required this.category,
    this.academicYear,
    this.payments = const [],
  });

  int get id => fee.id;
  int get studentId => fee.studentId;
  String get studentName => student.name;
  String get admissionNumber => student.admissionNumber;
  int? get rollNumber => student.rollNumber;
  int get feeCategoryId => fee.feeCategoryId;
  String get categoryName => category.name;
  String get frequency => category.frequency;
  String get title => fee.title;
  double get totalAmount => fee.totalAmount;
  double get discountAmount => fee.discountAmount;
  double get netAmount {
    final net = totalAmount - discountAmount;
    return net > 0 ? net : 0.0;
  }

  double get paidAmount => fee.paidAmount;
  double get remainingAmount {
    final rem = netAmount - paidAmount;
    return rem > 0 ? rem : 0.0;
  }

  bool get isPaid => remainingAmount <= 0.001;
  bool get isPartial => paidAmount > 0.001 && !isPaid;
  bool get isPending => paidAmount <= 0.001;
  String get status => fee.status;
  DateTime? get dueDate => fee.dueDate;
  int? get academicMonth => fee.academicMonth;
  String? get academicTerm => fee.academicTerm;
  String? get notes => fee.notes;
  DateTime get createdAt => fee.createdAt;
}

/// Composite model linking FeePayment with StudentFee, Student, FeeCategory, and AcademicYear
class FeePaymentWithDetails {
  final FeePayment payment;
  final StudentFee fee;
  final Student student;
  final FeeCategory category;
  final AcademicYear? academicYear;

  const FeePaymentWithDetails({
    required this.payment,
    required this.fee,
    required this.student,
    required this.category,
    this.academicYear,
  });

  int get id => payment.id;
  int get studentFeeId => payment.studentFeeId;
  int get studentId => payment.studentId;
  String get studentName => student.name;
  String get admissionNumber => student.admissionNumber;
  int? get rollNumber => student.rollNumber;
  String get receiptNumber => payment.receiptNumber;
  double get amount => payment.amount;
  DateTime get paymentDate => payment.paymentDate;
  String get paymentMethod => payment.paymentMethod;
  String? get referenceNumber => payment.referenceNumber;
  String? get remarks => payment.remarks;
  String? get receivedBy => payment.receivedBy;
  String get feeTitle => fee.title;
  String get categoryName => category.name;
  String get frequency => category.frequency;
  double get feeTotalAmount => fee.totalAmount;
  double get feeDiscountAmount => fee.discountAmount;
  double get feePaidAmount => fee.paidAmount;
  DateTime get createdAt => payment.createdAt;
}

/// Financial summary for student fee assessment
class StudentFeeFinancialSummary {
  final double totalInvoiced;
  final double totalDiscount;
  final double totalPaid;
  final double totalPending;
  final int totalFeesCount;
  final int paidFeesCount;
  final int partialFeesCount;
  final int pendingFeesCount;

  const StudentFeeFinancialSummary({
    required this.totalInvoiced,
    required this.totalDiscount,
    required this.totalPaid,
    required this.totalPending,
    required this.totalFeesCount,
    required this.paidFeesCount,
    required this.partialFeesCount,
    required this.pendingFeesCount,
  });
}

/// Composite model linking SalaryPayment with Employee, AcademicYear, and Adjustments
class SalaryPaymentWithDetails {
  final SalaryPayment payment;
  final Employee employee;
  final AcademicYear? academicYear;
  final List<SalaryAdvanceAdjustment> adjustments;

  const SalaryPaymentWithDetails({
    required this.payment,
    required this.employee,
    this.academicYear,
    this.adjustments = const [],
  });

  int get id => payment.id;
  int get employeeId => payment.employeeId;
  String get employeeName => employee.name;
  EmployeeType get employeeType => employee.employeeType;
  String get designation => employee.designation;
  int get year => payment.year;
  int get month => payment.month;
  DateTime get paymentDate => payment.paymentDate;
  double get basicSalary => payment.basicSalary;
  double get bonus => payment.bonus;
  String? get bonusReason => payment.bonusReason;
  double get deduction => payment.deduction;
  String? get deductionReason => payment.deductionReason;
  double get advanceDeduction => payment.advanceDeduction;
  double get grossSalary => payment.grossSalary;
  double get totalDeductions => payment.totalDeductions;
  double get netSalary => payment.netSalary;
  String get paymentMethod => payment.paymentMethod;
  String? get referenceNumber => payment.referenceNumber;
  String get status => payment.status;
  String? get notes => payment.notes;
  DateTime get createdAt => payment.createdAt;
}

/// Composite model linking SalaryAdvance with Employee and AcademicYear
class SalaryAdvanceWithEmployee {
  final SalaryAdvance advance;
  final Employee employee;
  final AcademicYear? academicYear;

  const SalaryAdvanceWithEmployee({
    required this.advance,
    required this.employee,
    this.academicYear,
  });

  int get id => advance.id;
  int get employeeId => advance.employeeId;
  String get employeeName => employee.name;
  EmployeeType get employeeType => employee.employeeType;
  String get designation => employee.designation;
  double get amount => advance.amount;
  DateTime get advanceDate => advance.advanceDate;
  double get adjustedAmount => advance.adjustedAmount;
  double get remainingAmount {
    final rem = advance.amount - advance.adjustedAmount;
    return rem > 0 ? rem : 0.0;
  }

  bool get isSettled => remainingAmount <= 0.001;
  String get paymentMethod => advance.paymentMethod;
  String? get referenceNumber => advance.referenceNumber;
  String? get reason => advance.reason;
  String? get notes => advance.notes;
  String get status => advance.status;
  DateTime get createdAt => advance.createdAt;
}
