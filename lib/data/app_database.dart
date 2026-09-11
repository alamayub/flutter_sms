import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'database_seeder.dart';

part 'app_database.g.dart';

/// Academic enrollment status in a given academic session
enum AcademicStatus {
  active,
  promoted,
  retained,
  transferred,
  graduated;

  String get displayName {
    switch (this) {
      case AcademicStatus.active:
        return 'Active';
      case AcademicStatus.promoted:
        return 'Promoted';
      case AcademicStatus.retained:
        return 'Retained';
      case AcademicStatus.transferred:
        return 'Transferred';
      case AcademicStatus.graduated:
        return 'Graduated';
    }
  }
}

/// Academic outcome/result status
enum AcademicResult {
  pending,
  passed,
  failed;

  String get displayName {
    switch (this) {
      case AcademicResult.pending:
        return 'Pending';
      case AcademicResult.passed:
        return 'Passed';
      case AcademicResult.failed:
        return 'Failed';
    }
  }
}

/// Attendance status for students and staff
enum AttendanceStatus {
  present,
  absent,
  late,
  halfDay,
  onLeave,
  excused;

  String get displayName {
    switch (this) {
      case AttendanceStatus.present:
        return 'Present';
      case AttendanceStatus.absent:
        return 'Absent';
      case AttendanceStatus.late:
        return 'Late';
      case AttendanceStatus.halfDay:
        return 'Half Day';
      case AttendanceStatus.onLeave:
        return 'On Leave';
      case AttendanceStatus.excused:
        return 'Excused';
    }
  }

  String get shortCode {
    switch (this) {
      case AttendanceStatus.present:
        return 'P';
      case AttendanceStatus.absent:
        return 'A';
      case AttendanceStatus.late:
        return 'L';
      case AttendanceStatus.halfDay:
        return 'HD';
      case AttendanceStatus.onLeave:
        return 'LV';
      case AttendanceStatus.excused:
        return 'EX';
    }
  }
}

@DataClassName('Student')
class Students extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get studentId => text().unique().withLength(min: 1, max: 20)();
  TextColumn get admissionNumber =>
      text().unique().withLength(min: 1, max: 30)();
  DateTimeColumn get admissionDate => dateTime()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get gender => text().withLength(min: 1, max: 20)();
  // 'Male', 'Female', 'Other'
  DateTimeColumn get dateOfBirth => dateTime().nullable()();
  TextColumn get bloodGroup => text().nullable()();
  // 'A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'
  TextColumn get address => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get photoPath => text().nullable()();

  // Emergency contact fields (denormalized for rapid access)
  TextColumn get emergencyContactName => text().nullable()();
  TextColumn get emergencyContactPhone => text().nullable()();
  TextColumn get emergencyContactRelation => text().nullable()();

  // Current enrolled reference (cached for quick lookups & backwards compatibility)
  IntColumn get classId =>
      integer().nullable().references(
        SchoolClasses,
        #id,
        onDelete: KeyAction.setNull,
      )();
  IntColumn get sectionId =>
      integer().nullable().references(
        Sections,
        #id,
        onDelete: KeyAction.setNull,
      )();
  IntColumn get rollNumber => integer().nullable()();

  // Facility Opt-in flags
  BoolColumn get hasTransport => boolean().withDefault(const Constant(false))();
  BoolColumn get hasHostel => boolean().withDefault(const Constant(false))();
  BoolColumn get hasLibrary => boolean().withDefault(const Constant(false))();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('StudentAcademicHistory')
class StudentAcademicHistories extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get studentId =>
      integer().references(Students, #id, onDelete: KeyAction.cascade)();
  IntColumn get academicYearId =>
      integer().references(AcademicYears, #id, onDelete: KeyAction.cascade)();
  IntColumn get classId =>
      integer().references(SchoolClasses, #id, onDelete: KeyAction.cascade)();
  IntColumn get sectionId =>
      integer().references(Sections, #id, onDelete: KeyAction.cascade)();
  IntColumn get rollNumber => integer().nullable()();
  TextColumn get status =>
      textEnum<AcademicStatus>().withDefault(
        Constant(AcademicStatus.active.name),
      )();
  TextColumn get resultStatus =>
      textEnum<AcademicResult>().withDefault(
        Constant(AcademicResult.pending.name),
      )();
  TextColumn get remarks => text().nullable()();
  DateTimeColumn get enrolledAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
    {studentId, academicYearId},
  ];
}

/// Composite model representing a student with full current enrollment details
class StudentWithDetails {
  final Student student;
  final SchoolClass? currentClass;
  final Section? currentSection;
  final StudentAcademicHistory? currentEnrollment;
  final AcademicYear? currentAcademicYear;

  const StudentWithDetails({
    required this.student,
    this.currentClass,
    this.currentSection,
    this.currentEnrollment,
    this.currentAcademicYear,
  });

  int get id => student.id;
  String get name => student.name;
  String get studentId => student.studentId;
  String get admissionNumber => student.admissionNumber;
  DateTime get admissionDate => student.admissionDate;
  String get gender => student.gender;
  DateTime? get dateOfBirth => student.dateOfBirth;
  String? get bloodGroup => student.bloodGroup;
  String? get address => student.address;
  String? get phone => student.phone;
  String? get email => student.email;
  String? get photoPath => student.photoPath;
  String? get emergencyContactName => student.emergencyContactName;
  String? get emergencyContactPhone => student.emergencyContactPhone;
  String? get emergencyContactRelation => student.emergencyContactRelation;
  int? get classId => student.classId;
  int? get sectionId => student.sectionId;
  int? get rollNumber => currentEnrollment?.rollNumber ?? student.rollNumber;
  bool get hasTransport => student.hasTransport;
  bool get hasHostel => student.hasHostel;
  bool get hasLibrary => student.hasLibrary;
  bool get isActive => student.isActive;
}

/// Composite model representing a single academic history record with year, class, and section
class StudentAcademicHistoryWithDetails {
  final StudentAcademicHistory history;
  final AcademicYear academicYear;
  final SchoolClass schoolClass;
  final Section section;

  const StudentAcademicHistoryWithDetails({
    required this.history,
    required this.academicYear,
    required this.schoolClass,
    required this.section,
  });

  int get id => history.id;
  int get studentId => history.studentId;
  int get academicYearId => history.academicYearId;
  int get classId => history.classId;
  int get sectionId => history.sectionId;
  int? get rollNumber => history.rollNumber;
  AcademicStatus get status => history.status;
  AcademicResult get resultStatus => history.resultStatus;
  String? get remarks => history.remarks;
  DateTime get enrolledAt => history.enrolledAt;
}

class AcademicYears extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime()();
  BoolColumn get isCurrent => boolean().withDefault(const Constant(false))();
  TextColumn get description => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('SchoolClass')
class SchoolClasses extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 50)();
  TextColumn get displayName => text().withLength(min: 1, max: 100)();
  IntColumn get orderIndex => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('Section')
class Sections extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get classId =>
      integer().references(SchoolClasses, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text().withLength(min: 1, max: 50)();
  TextColumn get roomNumber => text().nullable()();
  IntColumn get capacity => integer().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Composite model representing a class along with all its sections
class ClassWithSections {
  final SchoolClass schoolClass;
  final List<Section> sections;

  const ClassWithSections({required this.schoolClass, required this.sections});

  int get id => schoolClass.id;
  String get name => schoolClass.name;
  String get displayName => schoolClass.displayName;
  int get orderIndex => schoolClass.orderIndex;

  ClassWithSections copyWith({
    SchoolClass? schoolClass,
    List<Section>? sections,
  }) {
    return ClassWithSections(
      schoolClass: schoolClass ?? this.schoolClass,
      sections: sections ?? this.sections,
    );
  }
}

/// Subject delivery type: theory, practical, or both
enum SubjectType {
  theory,
  practical,
  both;

  String get displayName {
    switch (this) {
      case SubjectType.theory:
        return 'Theory';
      case SubjectType.practical:
        return 'Practical';
      case SubjectType.both:
        return 'Theory & Practical';
    }
  }
}

@DataClassName('Subject')
class Subjects extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get code => text().withLength(min: 1, max: 30)();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get subjectType => textEnum<SubjectType>()();
  BoolColumn get isOptional => boolean().withDefault(const Constant(false))();
  IntColumn get fullMarks => integer().withDefault(const Constant(100))();
  IntColumn get passMarks => integer().withDefault(const Constant(40))();
  IntColumn get theoryMarks => integer().nullable()();
  IntColumn get practicalMarks => integer().nullable()();
  TextColumn get description => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

enum EmployeeType { teacher, staff }

@DataClassName('Employee')
class Employees extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get employeeCode =>
      text().nullable()(); // e.g. "EMP-2026-001", "TCH-001"
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get employeeType =>
      textEnum<EmployeeType>()(); // 'teacher' or 'staff'
  TextColumn get designation =>
      text().withLength(
        min: 1,
        max: 100,
      )(); // 'Teacher', 'Peon', 'Accountant', etc.
  TextColumn get email => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get photoPath =>
      text().nullable()(); // Local image path or avatar URI

  // Emergency Contact Details
  TextColumn get emergencyContactName => text().nullable()();
  TextColumn get emergencyContactPhone => text().nullable()();
  TextColumn get emergencyContactRelation =>
      text().nullable()(); // Spouse, Parent, Sibling, Relative, etc.

  // Optional biographical & personal information
  DateTimeColumn get dateOfBirth =>
      dateTime().nullable()(); // AD date only, converted to BS for display
  TextColumn get gender => text().nullable()(); // 'Male', 'Female', 'Other'
  TextColumn get bloodGroup => text().nullable()(); // 'A+', 'B+', 'O+', etc.
  TextColumn get maritalStatus =>
      text().nullable()(); // 'Single', 'Married', etc.
  TextColumn get address => text().nullable()();

  // Optional professional details
  TextColumn get qualification =>
      text().nullable()(); // e.g. 'M.Sc. B.Ed', 'B.B.S', 'Under SLC'
  TextColumn get department =>
      text().nullable()(); // e.g. 'Mathematics', 'Accounts', 'Administration'
  DateTimeColumn get joiningDate => dateTime().nullable()();
  RealColumn get basicSalary => real().nullable()();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

typedef Teacher = Employee;

@DataClassName('PeriodEntry')
class PeriodEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get academicYearId =>
      integer().references(AcademicYears, #id, onDelete: KeyAction.cascade)();
  IntColumn get classId =>
      integer().references(SchoolClasses, #id, onDelete: KeyAction.cascade)();
  IntColumn get sectionId =>
      integer().nullable().references(
        Sections,
        #id,
        onDelete: KeyAction.cascade,
      )();
  TextColumn get dayOfWeek =>
      text()(); // 'sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'
  IntColumn get periodNumber => integer().withDefault(const Constant(1))();
  TextColumn get startTime => text()(); // e.g. "10:15"
  TextColumn get endTime => text()(); // e.g. "11:00"
  BoolColumn get isBreak => boolean().withDefault(const Constant(false))();
  TextColumn get breakTitle => text().nullable()(); // e.g. "Lunch Break"
  IntColumn get subjectId =>
      integer().nullable().references(
        Subjects,
        #id,
        onDelete: KeyAction.setNull,
      )();
  IntColumn get teacherId =>
      integer().nullable().references(
        Employees,
        #id,
        onDelete: KeyAction.setNull,
      )();
  TextColumn get roomNumber => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Composite model for Period with its joined subject, teacher, class, section, and academic year
class PeriodWithDetails {
  final PeriodEntry period;
  final Subject? subject;
  final Employee? teacher;
  final SchoolClass? schoolClass;
  final Section? section;
  final AcademicYear? academicYear;

  const PeriodWithDetails({
    required this.period,
    this.subject,
    this.teacher,
    this.schoolClass,
    this.section,
    this.academicYear,
  });

  int get id => period.id;
  int get academicYearId => period.academicYearId;
  int get classId => period.classId;
  int? get sectionId => period.sectionId;
  String get dayOfWeek => period.dayOfWeek;
  int get periodNumber => period.periodNumber;
  String get startTime => period.startTime;
  String get endTime => period.endTime;
  bool get isBreak => period.isBreak;
  String? get breakTitle => period.breakTitle;
  int? get subjectId => period.subjectId;
  int? get teacherId => period.teacherId;
  String? get roomNumber => period.roomNumber;

  AcademicYear? get academicYearObj => academicYear;
  SchoolClass? get schoolClassObj => schoolClass;
  Section? get sectionObj => section;
  Subject? get subjectObj => subject;
  Employee? get teacherObj => teacher;

  String get displayName {
    if (isBreak) {
      return breakTitle ?? 'Break';
    }
    return subject?.name ?? 'No Subject';
  }
}

/// Source entity type for contacts
enum ContactSourceType {
  student,
  employee,
  other;

  String get displayName {
    switch (this) {
      case ContactSourceType.student:
        return 'Student';
      case ContactSourceType.employee:
        return 'Employee';
      case ContactSourceType.other:
        return 'Other';
    }
  }
}

@DataClassName('Contact')
class Contacts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get sourceType =>
      textEnum<ContactSourceType>()(); // 'student', 'employee', 'other'
  IntColumn get sourceId =>
      integer()
          .nullable()(); // Student ID or Employee ID (or null for general/other contacts)
  TextColumn get sourceName =>
      text()
          .nullable()(); // Denormalized name of the student/employee for fast display & search
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get phone => text().withLength(min: 1, max: 25)();
  TextColumn get relation =>
      text()
          .nullable()(); // 'Father', 'Mother', 'Guardian', 'Spouse', 'Sibling', 'Doctor', etc.
  TextColumn get email => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get occupation => text().nullable()();
  BoolColumn get isEmergency => boolean().withDefault(const Constant(false))();
  BoolColumn get isPrimary => boolean().withDefault(const Constant(false))();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

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
  TextColumn get paymentMethod =>
      text().withDefault(
        const Constant('Cash'),
      )(); // 'Cash', 'Bank Transfer', 'Cheque', 'eSewa', 'Khalti', 'Other'
  TextColumn get referenceNumber =>
      text().nullable()(); // Voucher / Bill / Receipt / Txn ID
  TextColumn get paidTo =>
      text().nullable()(); // Vendor / Payee / Landlord / Person
  TextColumn get notes => text().nullable()();
  TextColumn get receiptPath =>
      text().nullable()(); // Local image receipt photo path
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
  TextColumn get status =>
      text().withDefault(
        const Constant('pending'),
      )(); // 'pending', 'partially_adjusted', 'settled'
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
  TextColumn get status =>
      text().withDefault(const Constant('paid'))(); // 'paid', 'pending'
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
  TextColumn get name =>
      text()(); // e.g. "Monthly Tuition Fee", "Uniform & Dress", "Admission Fee", "Exam Fee"
  TextColumn get frequency =>
      text().withDefault(
        const Constant('monthly'),
      )(); // 'one_time', 'monthly', 'quarterly', 'half_yearly', 'yearly', 'term_wise'
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
  TextColumn get title => text()();
  // e.g. "Baishakh Tuition Fee", "Grade 8 Uniform & Dress", "1st Term Exam Fee"
  RealColumn get totalAmount => real()();
  RealColumn get discountAmount => real().withDefault(const Constant(0.0))();
  RealColumn get paidAmount => real().withDefault(const Constant(0.0))();
  DateTimeColumn get dueDate => dateTime().nullable()();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  // 'pending', 'partial', 'paid'
  IntColumn get academicMonth => integer().nullable()(); // 1-12
  TextColumn get academicTerm =>
      text().nullable()(); // 'Term 1', 'Term 2', 'Final Term'
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
  TextColumn get paymentMethod =>
      text().withDefault(
        const Constant('Cash'),
      )(); // 'Cash', 'Bank Transfer', 'eSewa', 'Khalti', 'Cheque', 'Online'
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

@DataClassName('Certificate')
class Certificates extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get certificateNumber =>
      text().unique().withLength(min: 1, max: 60)();
  IntColumn get studentId =>
      integer().references(Students, #id, onDelete: KeyAction.cascade)();
  IntColumn get academicYearId =>
      integer().nullable().references(
        AcademicYears,
        #id,
        onDelete: KeyAction.setNull,
      )();
  TextColumn get certificateType => text()();
  // 'tc', 'cc', 'bonafide', 'marksheet', 'custom'
  TextColumn get title => text().withLength(min: 1, max: 150)();
  // e.g. "Transfer Certificate", "Character Certificate"
  DateTimeColumn get issueDate => dateTime()();
  TextColumn get status => text().withDefault(const Constant('issued'))();
  // 'issued', 'draft', 'revoked'
  TextColumn get reason =>
      text().nullable()(); // e.g. Reason for leaving, purpose of bonafide
  TextColumn get conduct =>
      text().nullable()(); // e.g. "Good", "Exemplary", "Very Good"
  BoolColumn get duesCleared => boolean().withDefault(const Constant(true))();
  TextColumn get remarks => text().nullable()();
  TextColumn get issuedBy => text().nullable()();
  TextColumn get dataJson =>
      text()
          .nullable()(); // JSON payload for Mark Sheet / TC / CC / Bonafide / Custom specifics
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class CertificateWithDetails {
  final Certificate certificate;
  final Student student;
  final SchoolClass? schoolClass;
  final Section? section;
  final AcademicYear? academicYear;

  const CertificateWithDetails({
    required this.certificate,
    required this.student,
    this.schoolClass,
    this.section,
    this.academicYear,
  });

  int get id => certificate.id;
  String get certificateNumber => certificate.certificateNumber;
  String get certificateType => certificate.certificateType;
  String get title => certificate.title;
  DateTime get issueDate => certificate.issueDate;
  String get status => certificate.status;
  String? get reason => certificate.reason;
  String? get conduct => certificate.conduct;
  bool get duesCleared => certificate.duesCleared;
  String? get remarks => certificate.remarks;
  String? get issuedBy => certificate.issuedBy;
  String? get dataJson => certificate.dataJson;
  DateTime get createdAt => certificate.createdAt;

  String get studentName => student.name;
  String get admissionNumber => student.admissionNumber;
  int? get rollNumber => student.rollNumber;
  String? get className => schoolClass?.name;
  String? get sectionName => section?.name;
  String? get academicYearName => academicYear?.name;
}

/// Exam Master Table (e.g. First Terminal Exam, Unit Test 1, Half Yearly, Final Exam)
@DataClassName('Exam')
class Exams extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 150)();
  TextColumn get category => text().withLength(min: 1, max: 80)();
  IntColumn get academicYearId =>
      integer().references(AcademicYears, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime()();
  TextColumn get description => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('Scheduled'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Exam Subject Routine / Timetable per Class
@DataClassName('ExamSchedule')
class ExamSchedules extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get examId =>
      integer().references(Exams, #id, onDelete: KeyAction.cascade)();
  IntColumn get academicYearId =>
      integer().references(AcademicYears, #id, onDelete: KeyAction.cascade)();
  IntColumn get classId =>
      integer().references(SchoolClasses, #id, onDelete: KeyAction.cascade)();
  IntColumn get subjectId =>
      integer().references(Subjects, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get examDate => dateTime()();
  TextColumn get startTime => text().withLength(min: 1, max: 30)();
  TextColumn get endTime => text().withLength(min: 1, max: 30)();
  IntColumn get fullMarks => integer().withDefault(const Constant(100))();
  IntColumn get passMarks => integer().withDefault(const Constant(40))();
  IntColumn get theoryMarks => integer().nullable()();
  IntColumn get practicalMarks => integer().nullable()();
  TextColumn get roomNumber => text().nullable()();
  TextColumn get remarks => text().nullable()();
  IntColumn get orderIndex => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('ExamResult')
class ExamResults extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get examId =>
      integer().references(Exams, #id, onDelete: KeyAction.cascade)();
  IntColumn get academicYearId =>
      integer().references(AcademicYears, #id, onDelete: KeyAction.cascade)();
  IntColumn get classId =>
      integer().references(SchoolClasses, #id, onDelete: KeyAction.cascade)();
  IntColumn get sectionId =>
      integer().nullable().references(
        Sections,
        #id,
        onDelete: KeyAction.setNull,
      )();
  IntColumn get studentId =>
      integer().references(Students, #id, onDelete: KeyAction.cascade)();
  IntColumn get subjectId =>
      integer().references(Subjects, #id, onDelete: KeyAction.cascade)();
  IntColumn get examScheduleId =>
      integer().nullable().references(
        ExamSchedules,
        #id,
        onDelete: KeyAction.setNull,
      )();

  // Theory marks
  RealColumn get theoryMarksObtained =>
      real().withDefault(const Constant(0.0))();
  RealColumn get theoryFullMarks => real().withDefault(const Constant(100.0))();
  RealColumn get theoryPassMarks => real().withDefault(const Constant(40.0))();

  // Practical marks (nullable for subjects without practical)
  RealColumn get practicalMarksObtained => real().nullable()();
  RealColumn get practicalFullMarks => real().nullable()();
  RealColumn get practicalPassMarks => real().nullable()();

  // Aggregate Subject Marks
  RealColumn get totalMarksObtained =>
      real().withDefault(const Constant(0.0))();
  RealColumn get totalFullMarks => real().withDefault(const Constant(100.0))();
  RealColumn get totalPassMarks => real().withDefault(const Constant(40.0))();

  // Both Percentage and Grading stored persistently
  RealColumn get percentage => real().withDefault(const Constant(0.0))();
  RealColumn get gradePoint => real().withDefault(const Constant(0.0))();
  TextColumn get letterGrade =>
      text().withLength(min: 1, max: 10).withDefault(const Constant('F'))();
  BoolColumn get isPassed => boolean().withDefault(const Constant(false))();
  BoolColumn get isAbsent => boolean().withDefault(const Constant(false))();

  TextColumn get remarks => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
    {examId, studentId, subjectId},
  ];
}

@DataClassName('ExamResultSummary')
class ExamResultSummaries extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get examId =>
      integer().references(Exams, #id, onDelete: KeyAction.cascade)();
  IntColumn get academicYearId =>
      integer().references(AcademicYears, #id, onDelete: KeyAction.cascade)();
  IntColumn get classId =>
      integer().references(SchoolClasses, #id, onDelete: KeyAction.cascade)();
  IntColumn get sectionId =>
      integer().nullable().references(
        Sections,
        #id,
        onDelete: KeyAction.setNull,
      )();
  IntColumn get studentId =>
      integer().references(Students, #id, onDelete: KeyAction.cascade)();

  RealColumn get totalMarksObtained =>
      real().withDefault(const Constant(0.0))();
  RealColumn get totalFullMarks => real().withDefault(const Constant(0.0))();
  RealColumn get overallPercentage => real().withDefault(const Constant(0.0))();
  RealColumn get overallGpa => real().withDefault(const Constant(0.0))();
  TextColumn get overallGrade =>
      text().withLength(min: 1, max: 10).withDefault(const Constant('F'))();

  IntColumn get totalSubjects => integer().withDefault(const Constant(0))();
  IntColumn get passedSubjects => integer().withDefault(const Constant(0))();
  IntColumn get failedSubjects => integer().withDefault(const Constant(0))();
  BoolColumn get isPassed => boolean().withDefault(const Constant(false))();
  IntColumn get rankInClass => integer().nullable()();
  IntColumn get rankInSection => integer().nullable()();

  TextColumn get remarks => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
    {examId, studentId},
  ];
}

/// Composite model for Exam with academic year and schedule counts
class ExamWithDetails {
  final Exam exam;
  final AcademicYear academicYear;
  final int scheduleCount;
  final int classCount;

  const ExamWithDetails({
    required this.exam,
    required this.academicYear,
    this.scheduleCount = 0,
    this.classCount = 0,
  });

  int get id => exam.id;
  String get name => exam.name;
  String get category => exam.category;
  int get academicYearId => exam.academicYearId;
  DateTime get startDate => exam.startDate;
  DateTime get endDate => exam.endDate;
  String? get description => exam.description;
  String get status => exam.status;
  DateTime get createdAt => exam.createdAt;
  String get academicYearName => academicYear.name;
}

/// Composite model for an ExamSchedule item with joined details
class ExamScheduleWithDetails {
  final ExamSchedule schedule;
  final Exam exam;
  final AcademicYear academicYear;
  final SchoolClass schoolClass;
  final Subject subject;

  const ExamScheduleWithDetails({
    required this.schedule,
    required this.exam,
    required this.academicYear,
    required this.schoolClass,
    required this.subject,
  });

  int get id => schedule.id;
  int get examId => schedule.examId;
  int get academicYearId => schedule.academicYearId;
  int get classId => schedule.classId;
  int get subjectId => schedule.subjectId;
  DateTime get examDate => schedule.examDate;
  String get startTime => schedule.startTime;
  String get endTime => schedule.endTime;
  int get fullMarks => schedule.fullMarks;
  int get passMarks => schedule.passMarks;
  int? get theoryMarks => schedule.theoryMarks;
  int? get practicalMarks => schedule.practicalMarks;
  String? get roomNumber => schedule.roomNumber;
  String? get remarks => schedule.remarks;
  int get orderIndex => schedule.orderIndex;

  int? get savedTheoryPassMarks {
    if (remarks != null && remarks!.startsWith('{') && remarks!.endsWith('}')) {
      try {
        final decoded = jsonDecode(remarks!);
        if (decoded is Map && decoded.containsKey('theoryPass')) {
          return decoded['theoryPass'] as int?;
        }
      } catch (_) {}
    }
    return null;
  }

  int? get savedPracticalPassMarks {
    if (remarks != null && remarks!.startsWith('{') && remarks!.endsWith('}')) {
      try {
        final decoded = jsonDecode(remarks!);
        if (decoded is Map && decoded.containsKey('practicalPass')) {
          return decoded['practicalPass'] as int?;
        }
      } catch (_) {}
    }
    return null;
  }

  String? get formattedRemarks {
    if (remarks == null || remarks!.isEmpty) return null;
    if (remarks!.startsWith('{') && remarks!.endsWith('}')) {
      try {
        final decoded = jsonDecode(remarks!);
        if (decoded is Map && decoded.containsKey('note')) {
          final note = decoded['note'] as String?;
          return (note != null && note.isNotEmpty) ? note : null;
        }
        return null;
      } catch (_) {}
    }
    return remarks;
  }

  String get examName => exam.name;
  String get examCategory => exam.category;
  String get academicYearName => academicYear.name;
  String get className => schoolClass.name;
  String get classDisplayName => schoolClass.displayName;
  String get subjectName => subject.name;
  String get subjectCode => subject.code;
  SubjectType get subjectType => subject.subjectType;
}

/// Composite model for an individual student subject exam result with all related entities joined
class ExamResultWithDetails {
  final ExamResult result;
  final Exam exam;
  final AcademicYear academicYear;
  final SchoolClass schoolClass;
  final Section? section;
  final Student student;
  final Subject subject;
  final ExamSchedule? schedule;

  const ExamResultWithDetails({
    required this.result,
    required this.exam,
    required this.academicYear,
    required this.schoolClass,
    this.section,
    required this.student,
    required this.subject,
    this.schedule,
  });

  int get id => result.id;
  int get examId => result.examId;
  int get studentId => result.studentId;
  int get subjectId => result.subjectId;
  int get classId => result.classId;
  int? get sectionId => result.sectionId;
  int get academicYearId => result.academicYearId;

  double get theoryMarksObtained => result.theoryMarksObtained;
  double get theoryFullMarks => result.theoryFullMarks;
  double get theoryPassMarks => result.theoryPassMarks;
  double? get practicalMarksObtained => result.practicalMarksObtained;
  double? get practicalFullMarks => result.practicalFullMarks;
  double? get practicalPassMarks => result.practicalPassMarks;
  double get totalMarksObtained => result.totalMarksObtained;
  double get totalFullMarks => result.totalFullMarks;
  double get totalPassMarks => result.totalPassMarks;
  double get percentage => result.percentage;
  double get gradePoint => result.gradePoint;
  String get letterGrade => result.letterGrade;
  bool get isPassed => result.isPassed;
  bool get isAbsent => result.isAbsent;
  String? get remarks => result.remarks;

  String get studentName => student.name;
  String get studentRollNumber => student.rollNumber?.toString() ?? '';
  String get studentCode => student.studentId;
  String? get studentPhotoPath => student.photoPath;
  String get subjectName => subject.name;
  String get subjectCode => subject.code;
  SubjectType get subjectType => subject.subjectType;
  String get className => schoolClass.name;
  String get classDisplayName => schoolClass.displayName;
  String? get sectionName => section?.name;
  String get examName => exam.name;
  String get examCategory => exam.category;
}

/// Composite model for a student's aggregate exam result summary
class StudentExamSummaryWithDetails {
  final ExamResultSummary summary;
  final Exam exam;
  final AcademicYear academicYear;
  final SchoolClass schoolClass;
  final Section? section;
  final Student student;

  const StudentExamSummaryWithDetails({
    required this.summary,
    required this.exam,
    required this.academicYear,
    required this.schoolClass,
    this.section,
    required this.student,
  });

  int get id => summary.id;
  int get examId => summary.examId;
  int get studentId => summary.studentId;
  int get classId => summary.classId;
  int? get sectionId => summary.sectionId;
  double get totalMarksObtained => summary.totalMarksObtained;
  double get totalFullMarks => summary.totalFullMarks;
  double get overallPercentage => summary.overallPercentage;
  double get overallGpa => summary.overallGpa;
  String get overallGrade => summary.overallGrade;
  int get totalSubjects => summary.totalSubjects;
  int get passedSubjects => summary.passedSubjects;
  int get failedSubjects => summary.failedSubjects;
  bool get isPassed => summary.isPassed;
  int? get rankInClass => summary.rankInClass;
  int? get rankInSection => summary.rankInSection;
  String? get remarks => summary.remarks;

  String get studentName => student.name;
  String get studentRollNumber => student.rollNumber?.toString() ?? '';
  String get studentCode => student.studentId;
  String? get studentPhotoPath => student.photoPath;
  String get className => schoolClass.name;
  String? get sectionName => section?.name;
  String get examName => exam.name;
}

@DataClassName('StudentAttendance')
class StudentAttendances extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get studentId =>
      integer().references(Students, #id, onDelete: KeyAction.cascade)();
  IntColumn get academicYearId =>
      integer().references(AcademicYears, #id, onDelete: KeyAction.cascade)();
  IntColumn get classId =>
      integer().references(SchoolClasses, #id, onDelete: KeyAction.cascade)();
  IntColumn get sectionId =>
      integer().nullable().references(
        Sections,
        #id,
        onDelete: KeyAction.setNull,
      )();
  DateTimeColumn get date => dateTime()();
  TextColumn get status => textEnum<AttendanceStatus>()();
  TextColumn get remarks => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
    {studentId, date},
  ];
}

@DataClassName('EmployeeAttendance')
class EmployeeAttendances extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get employeeId =>
      integer().references(Employees, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get date => dateTime()();
  TextColumn get status => textEnum<AttendanceStatus>()();
  TextColumn get checkInTime => text().nullable()();
  TextColumn get checkOutTime => text().nullable()();
  TextColumn get remarks => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
    {employeeId, date},
  ];
}

class StudentAttendanceWithStudent {
  final StudentAttendance attendance;
  final Student student;

  const StudentAttendanceWithStudent({
    required this.attendance,
    required this.student,
  });
}

class EmployeeAttendanceWithEmployee {
  final EmployeeAttendance attendance;
  final Employee employee;

  const EmployeeAttendanceWithEmployee({
    required this.attendance,
    required this.employee,
  });
}

@DriftDatabase(
  tables: [
    AcademicYears,
    SchoolClasses,
    Sections,
    Subjects,
    Employees,
    PeriodEntries,
    Students,
    StudentAcademicHistories,
    Contacts,
    ExpenseCategories,
    Expenses,
    SalaryAdvances,
    SalaryPayments,
    SalaryAdvanceAdjustments,
    FeeCategories,
    StudentFees,
    FeePayments,
    Certificates,
    Exams,
    ExamSchedules,
    ExamResults,
    ExamResultSummaries,
    StudentAttendances,
    EmployeeAttendances,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? _openConnection());

  @override
  int get schemaVersion => 19;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
      await DatabaseSeeder.seedAcademicYears(this);
      await DatabaseSeeder.seedClassesAndSections(this);
      await DatabaseSeeder.seedSubjects(this);
      await DatabaseSeeder.seedEmployees(this);
      await DatabaseSeeder.seedTimetable(this);
      await DatabaseSeeder.seedStudents(this);
      await DatabaseSeeder.seedContacts(this);
      await DatabaseSeeder.seedExpenseCategories(this);
      await DatabaseSeeder.seedExpenses(this);
      await DatabaseSeeder.seedPayroll(this);
      await DatabaseSeeder.seedFees(this);
      await DatabaseSeeder.seedExams(this);
      await DatabaseSeeder.seedExamResults(this);
      await DatabaseSeeder.seedAttendance(this);
    },
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 2) {
        await m.createTable(schoolClasses);
        await m.createTable(sections);
        await DatabaseSeeder.seedClassesAndSections(this);
      }
      if (from < 3) {
        await m.createTable(subjects);
        await DatabaseSeeder.seedSubjects(this);
      }
      if (from < 4) {
        await m.createTable(periodEntries);
      }
      if (from < 5) {
        await m.createTable(employees);
        await DatabaseSeeder.seedEmployees(this);
        await DatabaseSeeder.seedTimetable(this);
      }
      if (from < 6) {
        await m.addColumn(employees, employees.employeeCode);
        await m.addColumn(employees, employees.photoPath);
        await m.addColumn(employees, employees.emergencyContactName);
        await m.addColumn(employees, employees.emergencyContactPhone);
        await m.addColumn(employees, employees.emergencyContactRelation);
        await m.addColumn(employees, employees.maritalStatus);
      }
      if (from < 7) {
        await m.drop(periodEntries);
        await m.createTable(periodEntries);
        await DatabaseSeeder.seedTimetable(this);
      }
      if (from < 8) {
        await m.drop(periodEntries);
        await m.drop(employees);
        await m.createTable(employees);
        await m.createTable(periodEntries);
        await DatabaseSeeder.seedEmployees(this);
        await DatabaseSeeder.seedTimetable(this);
      }
      if (from < 9) {
        await m.createTable(students);
        await m.createTable(contacts);
        await DatabaseSeeder.seedContacts(this);
      }
      if (from < 10) {
        await m.drop(periodEntries);
        await m.createTable(periodEntries);
        await DatabaseSeeder.seedTimetable(this);
      }
      if (from < 11) {
        await m.drop(students);
        await m.createTable(students);
        await m.createTable(studentAcademicHistories);
        await DatabaseSeeder.seedStudents(this);
      }
      if (from < 12) {
        await m.createTable(expenseCategories);
        await m.createTable(expenses);
        await DatabaseSeeder.seedExpenseCategories(this);
        await DatabaseSeeder.seedExpenses(this);
      }
      if (from < 13) {
        await m.createTable(salaryAdvances);
        await m.createTable(salaryPayments);
        await m.createTable(salaryAdvanceAdjustments);
        await DatabaseSeeder.seedPayroll(this);
      }
      if (from < 14) {
        await m.createTable(feeCategories);
        await m.createTable(studentFees);
        await m.createTable(feePayments);
        await DatabaseSeeder.seedFees(this);
      }
      if (from < 15) {
        try {
          await m.addColumn(students, students.hasTransport);
        } catch (_) {}
        try {
          await m.addColumn(students, students.hasHostel);
        } catch (_) {}
        try {
          await m.addColumn(students, students.hasLibrary);
        } catch (_) {}
      }
      if (from < 16) {
        try {
          await m.createTable(certificates);
        } catch (_) {}
      }
      if (from < 17) {
        try {
          await m.createTable(exams);
          await m.createTable(examSchedules);
          await DatabaseSeeder.seedExams(this);
        } catch (_) {}
      }
      if (from < 18) {
        try {
          await m.createTable(examResults);
          await m.createTable(examResultSummaries);
          await DatabaseSeeder.seedExamResults(this);
        } catch (_) {}
      }
      if (from < 19) {
        try {
          await m.createTable(studentAttendances);
          await m.createTable(employeeAttendances);
          await DatabaseSeeder.seedAttendance(this);
        } catch (_) {}
      }
    },
    beforeOpen: (details) async {
      // Ensure facility columns exist on students table regardless of migration history
      try {
        await customStatement(
          'ALTER TABLE students ADD COLUMN has_transport INTEGER NOT NULL DEFAULT 0;',
        );
      } catch (_) {}
      try {
        await customStatement(
          'ALTER TABLE students ADD COLUMN has_hostel INTEGER NOT NULL DEFAULT 0;',
        );
      } catch (_) {}
      try {
        await customStatement(
          'ALTER TABLE students ADD COLUMN has_library INTEGER NOT NULL DEFAULT 0;',
        );
      } catch (_) {}
      try {
        await customStatement('''
          CREATE TABLE IF NOT EXISTS certificates (
            id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
            certificate_number TEXT NOT NULL UNIQUE,
            student_id INTEGER NOT NULL REFERENCES students (id) ON DELETE CASCADE,
            academic_year_id INTEGER REFERENCES academic_years (id) ON DELETE SET NULL,
            certificate_type TEXT NOT NULL,
            title TEXT NOT NULL,
            issue_date INTEGER NOT NULL,
            status TEXT NOT NULL DEFAULT 'issued',
            reason TEXT,
            conduct TEXT,
            dues_cleared INTEGER NOT NULL DEFAULT 1,
            remarks TEXT,
            issued_by TEXT,
            data_json TEXT,
            created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
          );
        ''');
      } catch (_) {}
    },
  );

  /// Stream all academic years sorted descending by start date
  Stream<List<AcademicYear>> watchAllAcademicYears() {
    return (select(academicYears)..orderBy([
      (t) => OrderingTerm(expression: t.startDate, mode: OrderingMode.desc),
    ])).watch();
  }

  /// Get all academic years as future
  Future<List<AcademicYear>> getAllAcademicYears() {
    return (select(academicYears)..orderBy([
      (t) => OrderingTerm(expression: t.startDate, mode: OrderingMode.desc),
    ])).get();
  }

  /// Get current active academic year
  Future<AcademicYear?> getCurrentAcademicYear() {
    return (select(academicYears)
      ..where((t) => t.isCurrent.equals(true))).getSingleOrNull();
  }

  /// Alias for getCurrentAcademicYear
  Future<AcademicYear?> getActiveAcademicYear() => getCurrentAcademicYear();

  /// Watch current active academic year reactively
  Stream<AcademicYear?> watchCurrentAcademicYear() {
    return (select(academicYears)
      ..where((t) => t.isCurrent.equals(true))).watchSingleOrNull();
  }

  /// Insert academic year with atomic constraint: if isCurrent is true, unset other years
  Future<int> insertAcademicYear(AcademicYearsCompanion companion) {
    return transaction(() async {
      if (companion.isCurrent.present && companion.isCurrent.value == true) {
        await update(
          academicYears,
        ).write(const AcademicYearsCompanion(isCurrent: Value(false)));
      }
      return into(academicYears).insert(companion);
    });
  }

  /// Update academic year with atomic constraint: if isCurrent is true, unset other years
  Future<bool> updateAcademicYearEntry(AcademicYear entry) {
    return transaction(() async {
      if (entry.isCurrent) {
        await (update(academicYears)..where(
          (t) => t.id.isNotValue(entry.id),
        )).write(const AcademicYearsCompanion(isCurrent: Value(false)));
      }
      return update(academicYears).replace(entry);
    });
  }

  /// Set specified academic year as active and deactivate all others
  Future<void> setActiveAcademicYear(int id) {
    return transaction(() async {
      await update(
        academicYears,
      ).write(const AcademicYearsCompanion(isCurrent: Value(false)));
      await (update(academicYears)..where(
        (t) => t.id.equals(id),
      )).write(const AcademicYearsCompanion(isCurrent: Value(true)));
    });
  }

  /// Delete academic year
  Future<int> deleteAcademicYear(int id) {
    return (delete(academicYears)..where((t) => t.id.equals(id))).go();
  }

  /// Get academic year by ID
  Future<AcademicYear?> getAcademicYearById(int id) {
    return (select(academicYears)
      ..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  // ================= CLASSES & SECTIONS =================

  /// Stream all classes with their respective sections
  Stream<List<ClassWithSections>> watchClassesWithSections() {
    final query = select(schoolClasses).join([
      leftOuterJoin(sections, sections.classId.equalsExp(schoolClasses.id)),
    ])..orderBy([
      OrderingTerm(
        expression: schoolClasses.orderIndex,
        mode: OrderingMode.asc,
      ),
      OrderingTerm(expression: schoolClasses.id, mode: OrderingMode.asc),
    ]);

    return query.watch().map((rows) {
      final Map<int, SchoolClass> classMap = {};
      final Map<int, List<Section>> sectionsMap = {};

      for (final row in rows) {
        final sc = row.readTable(schoolClasses);
        classMap.putIfAbsent(sc.id, () => sc);
        sectionsMap.putIfAbsent(sc.id, () => []);

        final sec = row.readTableOrNull(sections);
        if (sec != null) {
          if (!sectionsMap[sc.id]!.any((s) => s.id == sec.id)) {
            sectionsMap[sc.id]!.add(sec);
          }
        }
      }

      return classMap.values.map((sc) {
        final secList = sectionsMap[sc.id] ?? [];
        secList.sort((a, b) => a.name.compareTo(b.name));
        return ClassWithSections(schoolClass: sc, sections: secList);
      }).toList();
    });
  }

  /// Get all classes with their respective sections as a Future
  Future<List<ClassWithSections>> getAllClassesWithSections() async {
    final query = select(schoolClasses).join([
      leftOuterJoin(sections, sections.classId.equalsExp(schoolClasses.id)),
    ])..orderBy([
      OrderingTerm(
        expression: schoolClasses.orderIndex,
        mode: OrderingMode.asc,
      ),
      OrderingTerm(expression: schoolClasses.id, mode: OrderingMode.asc),
    ]);

    final rows = await query.get();
    final Map<int, SchoolClass> classMap = {};
    final Map<int, List<Section>> sectionsMap = {};

    for (final row in rows) {
      final sc = row.readTable(schoolClasses);
      classMap.putIfAbsent(sc.id, () => sc);
      sectionsMap.putIfAbsent(sc.id, () => []);

      final sec = row.readTableOrNull(sections);
      if (sec != null) {
        if (!sectionsMap[sc.id]!.any((s) => s.id == sec.id)) {
          sectionsMap[sc.id]!.add(sec);
        }
      }
    }

    return classMap.values.map((sc) {
      final secList = sectionsMap[sc.id] ?? [];
      secList.sort((a, b) => a.name.compareTo(b.name));
      return ClassWithSections(schoolClass: sc, sections: secList);
    }).toList();
  }

  /// Get a single class with its sections by ID
  Future<ClassWithSections?> getClassWithSectionsById(int id) async {
    final sc =
        await (select(schoolClasses)
          ..where((c) => c.id.equals(id))).getSingleOrNull();
    if (sc == null) return null;
    final secList =
        await (select(sections)
              ..where((s) => s.classId.equals(id))
              ..orderBy([
                (s) => OrderingTerm(expression: s.name, mode: OrderingMode.asc),
              ]))
            .get();
    return ClassWithSections(schoolClass: sc, sections: secList);
  }

  /// Insert a class and optionally its sections
  Future<int> insertClassWithSections({
    required SchoolClassesCompanion classCompanion,
    List<String> sectionNames = const [],
  }) {
    return transaction(() async {
      final classId = await into(schoolClasses).insert(classCompanion);
      for (final name in sectionNames) {
        final trimmed = name.trim();
        if (trimmed.isNotEmpty) {
          await into(sections).insert(
            SectionsCompanion(classId: Value(classId), name: Value(trimmed)),
          );
        }
      }
      return classId;
    });
  }

  /// Update class and synchronize section names
  Future<void> updateClassWithSections({
    required SchoolClass updatedClass,
    required List<String> sectionNames,
  }) {
    return transaction(() async {
      await update(schoolClasses).replace(updatedClass);

      final currentSections =
          await (select(sections)
            ..where((s) => s.classId.equals(updatedClass.id))).get();
      final currentNames = currentSections.map((s) => s.name).toSet();
      final newNames =
          sectionNames.map((s) => s.trim()).where((s) => s.isNotEmpty).toSet();

      // Delete sections that are removed
      for (final sec in currentSections) {
        if (!newNames.contains(sec.name)) {
          await (delete(sections)..where((s) => s.id.equals(sec.id))).go();
        }
      }

      // Insert newly added sections
      for (final name in newNames) {
        if (!currentNames.contains(name)) {
          await into(sections).insert(
            SectionsCompanion(
              classId: Value(updatedClass.id),
              name: Value(name),
            ),
          );
        }
      }
    });
  }

  /// Delete a class and all associated sections
  Future<int> deleteClass(int classId) {
    return transaction(() async {
      await (delete(sections)..where((s) => s.classId.equals(classId))).go();
      return (delete(schoolClasses)..where((c) => c.id.equals(classId))).go();
    });
  }

  /// Add a single section to a class
  Future<int> addSection({
    required int classId,
    required String name,
    String? roomNumber,
    int? capacity,
  }) {
    return into(sections).insert(
      SectionsCompanion(
        classId: Value(classId),
        name: Value(name.trim()),
        roomNumber: Value(roomNumber?.trim()),
        capacity: Value(capacity),
      ),
    );
  }

  /// Delete a single section by ID
  Future<int> deleteSection(int sectionId) {
    return (delete(sections)..where((s) => s.id.equals(sectionId))).go();
  }

  // ================= SUBJECTS =================

  /// Stream all generic subjects with optional filtering by subjectType and isOptional
  Stream<List<Subject>> watchSubjects({SubjectType? type, bool? isOptional}) {
    var query = select(subjects);

    if (type != null) {
      query = query..where((t) => t.subjectType.equals(type.name));
    }
    if (isOptional != null) {
      query = query..where((t) => t.isOptional.equals(isOptional));
    }

    query =
        query..orderBy([
          (t) => OrderingTerm(expression: t.name, mode: OrderingMode.asc),
        ]);

    return query.watch();
  }

  /// Get all generic subjects as a Future
  Future<List<Subject>> getAllSubjects() {
    return (select(subjects)..orderBy([
      (t) => OrderingTerm(expression: t.name, mode: OrderingMode.asc),
    ])).get();
  }

  /// Get single subject by ID
  Future<Subject?> getSubjectById(int id) {
    return (select(subjects)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Insert subject
  Future<int> insertSubject(SubjectsCompanion companion) {
    return into(subjects).insert(companion);
  }

  /// Update subject
  Future<bool> updateSubjectEntry(Subject entry) {
    return update(subjects).replace(entry);
  }

  /// Delete subject
  Future<int> deleteSubject(int id) {
    return (delete(subjects)..where((s) => s.id.equals(id))).go();
  }

  // ================= EMPLOYEES (TEACHERS & STAFF) =================

  /// Watch employees with optional type, search query, and active status filters
  Stream<List<Employee>> watchEmployees({
    EmployeeType? type,
    String? searchQuery,
    bool? isActive,
  }) {
    final query = select(employees);
    if (type != null) {
      query.where((t) => t.employeeType.equals(type.name));
    }
    if (isActive != null) {
      query.where((t) => t.isActive.equals(isActive));
    }
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final term = '%${searchQuery.trim().toLowerCase()}%';
      query.where(
        (t) =>
            t.name.lower().like(term) |
            t.designation.lower().like(term) |
            t.department.lower().like(term) |
            t.employeeCode.lower().like(term) |
            t.emergencyContactName.lower().like(term) |
            t.emergencyContactPhone.lower().like(term),
      );
    }
    query.orderBy([
      (t) => OrderingTerm(expression: t.name, mode: OrderingMode.asc),
    ]);
    return query.watch();
  }

  /// Get all employees with optional filters
  Future<List<Employee>> getAllEmployees({
    EmployeeType? type,
    String? searchQuery,
    bool? isActive,
  }) {
    final query = select(employees);
    if (type != null) {
      query.where((t) => t.employeeType.equals(type.name));
    }
    if (isActive != null) {
      query.where((t) => t.isActive.equals(isActive));
    }
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final term = '%${searchQuery.trim().toLowerCase()}%';
      query.where(
        (t) =>
            t.name.lower().like(term) |
            t.designation.lower().like(term) |
            t.department.lower().like(term) |
            t.employeeCode.lower().like(term) |
            t.emergencyContactName.lower().like(term) |
            t.emergencyContactPhone.lower().like(term),
      );
    }
    query.orderBy([
      (t) => OrderingTerm(expression: t.name, mode: OrderingMode.asc),
    ]);
    return query.get();
  }

  /// Get single employee by ID
  Future<Employee?> getEmployeeById(int id) {
    return (select(employees)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Insert employee
  Future<int> insertEmployee(EmployeesCompanion companion) {
    return into(employees).insert(companion);
  }

  /// Update employee
  Future<bool> updateEmployeeEntry(Employee entry) {
    return update(employees).replace(entry);
  }

  /// Delete employee
  Future<int> deleteEmployee(int id) {
    return (delete(employees)..where((t) => t.id.equals(id))).go();
  }

  // Backward-compatible teacher query methods
  Stream<List<Employee>> watchAllTeachers() =>
      watchEmployees(type: EmployeeType.teacher, isActive: true);

  Future<List<Employee>> getAllTeachers() =>
      getAllEmployees(type: EmployeeType.teacher, isActive: true);

  Future<Employee?> getTeacherById(int id) => getEmployeeById(id);

  Future<int> insertTeacher(EmployeesCompanion companion) =>
      insertEmployee(companion);

  Future<bool> updateTeacherEntry(Employee entry) => updateEmployeeEntry(entry);

  Future<int> deleteTeacher(int id) => deleteEmployee(id);

  // ================= TIMETABLE & PERIODS =================

  static const _dayOrderExp = CustomExpression<int>(
    'CASE LOWER(period_entries.day_of_week) '
    "WHEN 'sunday' THEN 1 "
    "WHEN 'monday' THEN 2 "
    "WHEN 'tuesday' THEN 3 "
    "WHEN 'wednesday' THEN 4 "
    "WHEN 'thursday' THEN 5 "
    "WHEN 'friday' THEN 6 "
    "WHEN 'saturday' THEN 7 "
    'ELSE 8 END',
  );

  /// Watch periods with full details (class, section, subject, teacher, academicYear)
  Stream<List<PeriodWithDetails>> watchPeriodsWithDetails({
    int? academicYearId,
    int? classId,
    int? sectionId,
    String? dayOfWeek,
  }) {
    final query = select(periodEntries).join([
      leftOuterJoin(
        academicYears,
        academicYears.id.equalsExp(periodEntries.academicYearId),
      ),
      leftOuterJoin(
        schoolClasses,
        schoolClasses.id.equalsExp(periodEntries.classId),
      ),
      leftOuterJoin(sections, sections.id.equalsExp(periodEntries.sectionId)),
      leftOuterJoin(subjects, subjects.id.equalsExp(periodEntries.subjectId)),
      leftOuterJoin(employees, employees.id.equalsExp(periodEntries.teacherId)),
    ]);

    if (academicYearId != null) {
      query.where(periodEntries.academicYearId.equals(academicYearId));
    }
    if (classId != null) {
      query.where(periodEntries.classId.equals(classId));
    }
    if (sectionId != null) {
      query.where(periodEntries.sectionId.equals(sectionId));
    }
    if (dayOfWeek != null && dayOfWeek.trim().isNotEmpty) {
      query.where(
        periodEntries.dayOfWeek.equals(dayOfWeek.trim().toLowerCase()),
      );
    }

    query.orderBy([
      OrderingTerm(expression: _dayOrderExp, mode: OrderingMode.asc),
      OrderingTerm(expression: periodEntries.startTime, mode: OrderingMode.asc),
      OrderingTerm(
        expression: periodEntries.periodNumber,
        mode: OrderingMode.asc,
      ),
    ]);

    return query.watch().map((rows) {
      return rows.map((row) {
        return PeriodWithDetails(
          period: row.readTable(periodEntries),
          schoolClass: row.readTableOrNull(schoolClasses),
          section: row.readTableOrNull(sections),
          subject: row.readTableOrNull(subjects),
          teacher: row.readTableOrNull(employees),
          academicYear: row.readTableOrNull(academicYears),
        );
      }).toList();
    });
  }

  /// Get all periods with details
  Future<List<PeriodWithDetails>> getAllPeriodsWithDetails({
    int? academicYearId,
    int? classId,
    int? sectionId,
    String? dayOfWeek,
  }) {
    final query = select(periodEntries).join([
      leftOuterJoin(
        academicYears,
        academicYears.id.equalsExp(periodEntries.academicYearId),
      ),
      leftOuterJoin(
        schoolClasses,
        schoolClasses.id.equalsExp(periodEntries.classId),
      ),
      leftOuterJoin(sections, sections.id.equalsExp(periodEntries.sectionId)),
      leftOuterJoin(subjects, subjects.id.equalsExp(periodEntries.subjectId)),
      leftOuterJoin(employees, employees.id.equalsExp(periodEntries.teacherId)),
    ]);

    if (academicYearId != null) {
      query.where(periodEntries.academicYearId.equals(academicYearId));
    }
    if (classId != null) {
      query.where(periodEntries.classId.equals(classId));
    }
    if (sectionId != null) {
      query.where(periodEntries.sectionId.equals(sectionId));
    }
    if (dayOfWeek != null && dayOfWeek.trim().isNotEmpty) {
      query.where(
        periodEntries.dayOfWeek.equals(dayOfWeek.trim().toLowerCase()),
      );
    }

    query.orderBy([
      OrderingTerm(expression: _dayOrderExp, mode: OrderingMode.asc),
      OrderingTerm(expression: periodEntries.startTime, mode: OrderingMode.asc),
      OrderingTerm(
        expression: periodEntries.periodNumber,
        mode: OrderingMode.asc,
      ),
    ]);

    return query.get().then((rows) {
      return rows.map((row) {
        return PeriodWithDetails(
          period: row.readTable(periodEntries),
          schoolClass: row.readTableOrNull(schoolClasses),
          section: row.readTableOrNull(sections),
          subject: row.readTableOrNull(subjects),
          teacher: row.readTableOrNull(employees),
          academicYear: row.readTableOrNull(academicYears),
        );
      }).toList();
    });
  }

  /// Get single period with details by ID
  Future<PeriodWithDetails?> getPeriodWithDetailsById(int id) {
    final query = (select(periodEntries)..where((t) => t.id.equals(id))).join([
      leftOuterJoin(
        academicYears,
        academicYears.id.equalsExp(periodEntries.academicYearId),
      ),
      leftOuterJoin(
        schoolClasses,
        schoolClasses.id.equalsExp(periodEntries.classId),
      ),
      leftOuterJoin(sections, sections.id.equalsExp(periodEntries.sectionId)),
      leftOuterJoin(subjects, subjects.id.equalsExp(periodEntries.subjectId)),
      leftOuterJoin(employees, employees.id.equalsExp(periodEntries.teacherId)),
    ]);

    return query.getSingleOrNull().then((row) {
      if (row == null) return null;
      return PeriodWithDetails(
        period: row.readTable(periodEntries),
        schoolClass: row.readTableOrNull(schoolClasses),
        section: row.readTableOrNull(sections),
        subject: row.readTableOrNull(subjects),
        teacher: row.readTableOrNull(employees),
        academicYear: row.readTableOrNull(academicYears),
      );
    });
  }

  /// Insert period
  Future<int> insertPeriod(PeriodEntriesCompanion companion) {
    return into(periodEntries).insert(companion);
  }

  /// Update period
  Future<bool> updatePeriodEntry(PeriodEntry entry) {
    return update(periodEntries).replace(entry);
  }

  /// Delete period
  Future<int> deletePeriod(int id) {
    return (delete(periodEntries)..where((t) => t.id.equals(id))).go();
  }

  /// Atomically replaces the entire weekly timetable for a class and section in an academic year
  Future<void> replaceWeeklyTimetable({
    required int academicYearId,
    required int classId,
    int? sectionId,
    required List<PeriodEntriesCompanion> periods,
  }) {
    return transaction(() async {
      // 1. Delete existing periods for this academic year, class, and section
      final del = delete(periodEntries)..where(
        (t) =>
            t.academicYearId.equals(academicYearId) & t.classId.equals(classId),
      );
      if (sectionId != null) {
        del.where((t) => t.sectionId.equals(sectionId));
      } else {
        del.where((t) => t.sectionId.isNull());
      }
      await del.go();

      // 2. Insert new periods in batch
      if (periods.isNotEmpty) {
        await batch((b) {
          b.insertAll(periodEntries, periods);
        });
      }
    });
  }

  /// Delete all periods for a specific class and optional section in an academic year
  Future<int> clearWeeklyTimetable({
    required int academicYearId,
    required int classId,
    int? sectionId,
  }) {
    final del = delete(periodEntries)..where(
      (t) =>
          t.academicYearId.equals(academicYearId) & t.classId.equals(classId),
    );
    if (sectionId != null) {
      del.where((t) => t.sectionId.equals(sectionId));
    } else {
      del.where((t) => t.sectionId.isNull());
    }
    return del.go();
  }

  // ==================== Contacts Operations ====================

  /// Stream all contacts ordered by name
  Stream<List<Contact>> watchAllContacts() {
    return (select(contacts)
      ..orderBy([(t) => OrderingTerm(expression: t.name)])).watch();
  }

  /// Get all contacts ordered by name
  Future<List<Contact>> getAllContacts() {
    return (select(contacts)
      ..orderBy([(t) => OrderingTerm(expression: t.name)])).get();
  }

  /// Watch contacts for a specific source (e.g. employee ID or student ID)
  Stream<List<Contact>> watchContactsBySource(
    ContactSourceType sourceType,
    int? sourceId,
  ) {
    final query = select(contacts)
      ..where((t) => t.sourceType.equals(sourceType.name));
    if (sourceId != null) {
      query.where((t) => t.sourceId.equals(sourceId));
    }
    query.orderBy([
      (t) => OrderingTerm(expression: t.isPrimary, mode: OrderingMode.desc),
      (t) => OrderingTerm(expression: t.name),
    ]);
    return query.watch();
  }

  /// Get contacts for a specific source
  Future<List<Contact>> getContactsBySource(
    ContactSourceType sourceType,
    int? sourceId,
  ) {
    final query = select(contacts)
      ..where((t) => t.sourceType.equals(sourceType.name));
    if (sourceId != null) {
      query.where((t) => t.sourceId.equals(sourceId));
    }
    query.orderBy([
      (t) => OrderingTerm(expression: t.isPrimary, mode: OrderingMode.desc),
      (t) => OrderingTerm(expression: t.name),
    ]);
    return query.get();
  }

  /// Stream emergency contacts
  Stream<List<Contact>> watchEmergencyContacts() {
    return (select(contacts)
          ..where((t) => t.isEmergency.equals(true))
          ..orderBy([(t) => OrderingTerm(expression: t.name)]))
        .watch();
  }

  /// Search contacts by query
  Future<List<Contact>> searchContacts(String query) {
    final q = '%${query.toLowerCase()}%';
    return (select(contacts)
          ..where(
            (t) =>
                t.name.lower().like(q) |
                t.phone.like(q) |
                t.relation.lower().like(q) |
                t.sourceName.lower().like(q),
          )
          ..orderBy([(t) => OrderingTerm(expression: t.name)]))
        .get();
  }

  /// Insert new contact
  Future<int> insertContact(ContactsCompanion companion) {
    return into(contacts).insert(companion);
  }

  /// Update contact
  Future<bool> updateContactEntry(Contact entry) {
    return update(contacts).replace(entry);
  }

  /// Delete contact
  Future<int> deleteContactEntry(int id) {
    return (delete(contacts)..where((t) => t.id.equals(id))).go();
  }

  /// Delete all contacts for a specific source
  Future<int> deleteContactsBySource(
    ContactSourceType sourceType,
    int sourceId,
  ) {
    return (delete(contacts)..where(
      (t) => t.sourceType.equals(sourceType.name) & t.sourceId.equals(sourceId),
    )).go();
  }

  // ==================== Students Operations ====================

  /// Stream students with full details (class, section, enrollment, academic year)
  Stream<List<StudentWithDetails>> watchStudentsWithDetails({
    int? academicYearId,
    int? classId,
    int? sectionId,
    String? search,
  }) {
    if (academicYearId != null) {
      final query = select(students).join([
        innerJoin(
          studentAcademicHistories,
          studentAcademicHistories.studentId.equalsExp(students.id) &
              studentAcademicHistories.academicYearId.equals(academicYearId),
        ),
        leftOuterJoin(
          schoolClasses,
          schoolClasses.id.equalsExp(studentAcademicHistories.classId),
        ),
        leftOuterJoin(
          sections,
          sections.id.equalsExp(studentAcademicHistories.sectionId),
        ),
        leftOuterJoin(
          academicYears,
          academicYears.id.equalsExp(studentAcademicHistories.academicYearId),
        ),
      ]);
      if (classId != null) {
        query.where(studentAcademicHistories.classId.equals(classId));
      }
      if (sectionId != null) {
        query.where(studentAcademicHistories.sectionId.equals(sectionId));
      }
      if (search != null && search.trim().isNotEmpty) {
        final q = '%${search.trim().toLowerCase()}%';
        query.where(
          students.name.lower().like(q) |
              students.studentId.lower().like(q) |
              students.admissionNumber.lower().like(q) |
              students.phone.like(q),
        );
      }
      query.orderBy([
        OrderingTerm(
          expression: studentAcademicHistories.rollNumber,
          mode: OrderingMode.asc,
        ),
        OrderingTerm(expression: students.name, mode: OrderingMode.asc),
      ]);
      return query.watch().map((rows) {
        return rows.map((row) {
          return StudentWithDetails(
            student: row.readTable(students),
            currentClass: row.readTableOrNull(schoolClasses),
            currentSection: row.readTableOrNull(sections),
            currentEnrollment: row.readTableOrNull(studentAcademicHistories),
            currentAcademicYear: row.readTableOrNull(academicYears),
          );
        }).toList();
      });
    } else {
      final query = select(students).join([
        leftOuterJoin(
          schoolClasses,
          schoolClasses.id.equalsExp(students.classId),
        ),
        leftOuterJoin(sections, sections.id.equalsExp(students.sectionId)),
      ]);
      if (classId != null) {
        query.where(students.classId.equals(classId));
      }
      if (sectionId != null) {
        query.where(students.sectionId.equals(sectionId));
      }
      if (search != null && search.trim().isNotEmpty) {
        final q = '%${search.trim().toLowerCase()}%';
        query.where(
          students.name.lower().like(q) |
              students.studentId.lower().like(q) |
              students.admissionNumber.lower().like(q) |
              students.phone.like(q),
        );
      }
      query.orderBy([
        OrderingTerm(expression: students.rollNumber, mode: OrderingMode.asc),
        OrderingTerm(expression: students.name, mode: OrderingMode.asc),
      ]);
      return query.watch().map((rows) {
        return rows.map((row) {
          return StudentWithDetails(
            student: row.readTable(students),
            currentClass: row.readTableOrNull(schoolClasses),
            currentSection: row.readTableOrNull(sections),
            currentEnrollment: null,
            currentAcademicYear: null,
          );
        }).toList();
      });
    }
  }

  /// Get students with full details as future
  Future<List<StudentWithDetails>> getStudentsWithDetails({
    int? academicYearId,
    int? classId,
    int? sectionId,
    String? search,
  }) async {
    if (academicYearId != null) {
      final query = select(students).join([
        innerJoin(
          studentAcademicHistories,
          studentAcademicHistories.studentId.equalsExp(students.id) &
              studentAcademicHistories.academicYearId.equals(academicYearId),
        ),
        leftOuterJoin(
          schoolClasses,
          schoolClasses.id.equalsExp(studentAcademicHistories.classId),
        ),
        leftOuterJoin(
          sections,
          sections.id.equalsExp(studentAcademicHistories.sectionId),
        ),
        leftOuterJoin(
          academicYears,
          academicYears.id.equalsExp(studentAcademicHistories.academicYearId),
        ),
      ]);
      if (classId != null) {
        query.where(studentAcademicHistories.classId.equals(classId));
      }
      if (sectionId != null) {
        query.where(studentAcademicHistories.sectionId.equals(sectionId));
      }
      if (search != null && search.trim().isNotEmpty) {
        final q = '%${search.trim().toLowerCase()}%';
        query.where(
          students.name.lower().like(q) |
              students.studentId.lower().like(q) |
              students.admissionNumber.lower().like(q) |
              students.phone.like(q),
        );
      }
      query.orderBy([
        OrderingTerm(
          expression: studentAcademicHistories.rollNumber,
          mode: OrderingMode.asc,
        ),
        OrderingTerm(expression: students.name, mode: OrderingMode.asc),
      ]);
      final rows = await query.get();
      return rows.map((row) {
        return StudentWithDetails(
          student: row.readTable(students),
          currentClass: row.readTableOrNull(schoolClasses),
          currentSection: row.readTableOrNull(sections),
          currentEnrollment: row.readTableOrNull(studentAcademicHistories),
          currentAcademicYear: row.readTableOrNull(academicYears),
        );
      }).toList();
    } else {
      final query = select(students).join([
        leftOuterJoin(
          schoolClasses,
          schoolClasses.id.equalsExp(students.classId),
        ),
        leftOuterJoin(sections, sections.id.equalsExp(students.sectionId)),
      ]);
      if (classId != null) {
        query.where(students.classId.equals(classId));
      }
      if (sectionId != null) {
        query.where(students.sectionId.equals(sectionId));
      }
      if (search != null && search.trim().isNotEmpty) {
        final q = '%${search.trim().toLowerCase()}%';
        query.where(
          students.name.lower().like(q) |
              students.studentId.lower().like(q) |
              students.admissionNumber.lower().like(q) |
              students.phone.like(q),
        );
      }
      query.orderBy([
        OrderingTerm(expression: students.rollNumber, mode: OrderingMode.asc),
        OrderingTerm(expression: students.name, mode: OrderingMode.asc),
      ]);
      final rows = await query.get();
      return rows.map((row) {
        return StudentWithDetails(
          student: row.readTable(students),
          currentClass: row.readTableOrNull(schoolClasses),
          currentSection: row.readTableOrNull(sections),
          currentEnrollment: null,
          currentAcademicYear: null,
        );
      }).toList();
    }
  }

  /// Get student with full details by student ID
  Future<StudentWithDetails?> getStudentWithDetailsById(
    int id, {
    int? academicYearId,
  }) async {
    final student =
        await (select(students)
          ..where((t) => t.id.equals(id))).getSingleOrNull();
    if (student == null) return null;

    SchoolClass? currentClass;
    Section? currentSection;
    StudentAcademicHistory? currentEnrollment;
    AcademicYear? currentYear;

    if (academicYearId != null) {
      currentEnrollment =
          await (select(studentAcademicHistories)..where(
            (t) =>
                t.studentId.equals(id) &
                t.academicYearId.equals(academicYearId),
          )).getSingleOrNull();
      if (currentEnrollment != null) {
        currentClass =
            await (select(schoolClasses)..where(
              (t) => t.id.equals(currentEnrollment!.classId),
            )).getSingleOrNull();
        currentSection =
            await (select(sections)..where(
              (t) => t.id.equals(currentEnrollment!.sectionId),
            )).getSingleOrNull();
        currentYear =
            await (select(academicYears)
              ..where((t) => t.id.equals(academicYearId))).getSingleOrNull();
      }
    }

    if (currentClass == null && student.classId != null) {
      currentClass =
          await (select(schoolClasses)
            ..where((t) => t.id.equals(student.classId!))).getSingleOrNull();
    }
    if (currentSection == null && student.sectionId != null) {
      currentSection =
          await (select(sections)
            ..where((t) => t.id.equals(student.sectionId!))).getSingleOrNull();
    }

    return StudentWithDetails(
      student: student,
      currentClass: currentClass,
      currentSection: currentSection,
      currentEnrollment: currentEnrollment,
      currentAcademicYear: currentYear,
    );
  }

  /// Stream all raw students
  Stream<List<Student>> watchAllStudents() {
    return (select(students)
      ..orderBy([(t) => OrderingTerm(expression: t.name)])).watch();
  }

  /// Get all raw students
  Future<List<Student>> getAllStudents() {
    return (select(students)
      ..orderBy([(t) => OrderingTerm(expression: t.name)])).get();
  }

  /// Insert student
  Future<int> insertStudent(StudentsCompanion companion) {
    return into(students).insert(companion);
  }

  /// Update student entry
  Future<bool> updateStudentEntry(Student entry) {
    return update(students).replace(entry);
  }

  /// Delete student entry and cascade
  Future<int> deleteStudentEntry(int id) {
    return (delete(students)..where((t) => t.id.equals(id))).go();
  }

  // ==================== Student Academic History Operations ====================

  /// Watch academic history of a student sorted descending by academic year
  Stream<List<StudentAcademicHistoryWithDetails>> watchStudentAcademicHistory(
    int studentId,
  ) {
    final query =
        select(studentAcademicHistories).join([
            innerJoin(
              academicYears,
              academicYears.id.equalsExp(
                studentAcademicHistories.academicYearId,
              ),
            ),
            innerJoin(
              schoolClasses,
              schoolClasses.id.equalsExp(studentAcademicHistories.classId),
            ),
            innerJoin(
              sections,
              sections.id.equalsExp(studentAcademicHistories.sectionId),
            ),
          ])
          ..where(studentAcademicHistories.studentId.equals(studentId))
          ..orderBy([
            OrderingTerm(
              expression: academicYears.startDate,
              mode: OrderingMode.desc,
            ),
          ]);

    return query.watch().map((rows) {
      return rows.map((row) {
        return StudentAcademicHistoryWithDetails(
          history: row.readTable(studentAcademicHistories),
          academicYear: row.readTable(academicYears),
          schoolClass: row.readTable(schoolClasses),
          section: row.readTable(sections),
        );
      }).toList();
    });
  }

  /// Get academic history of a student sorted descending by academic year
  Future<List<StudentAcademicHistoryWithDetails>> getStudentAcademicHistory(
    int studentId,
  ) async {
    final query =
        select(studentAcademicHistories).join([
            innerJoin(
              academicYears,
              academicYears.id.equalsExp(
                studentAcademicHistories.academicYearId,
              ),
            ),
            innerJoin(
              schoolClasses,
              schoolClasses.id.equalsExp(studentAcademicHistories.classId),
            ),
            innerJoin(
              sections,
              sections.id.equalsExp(studentAcademicHistories.sectionId),
            ),
          ])
          ..where(studentAcademicHistories.studentId.equals(studentId))
          ..orderBy([
            OrderingTerm(
              expression: academicYears.startDate,
              mode: OrderingMode.desc,
            ),
          ]);

    final rows = await query.get();
    return rows.map((row) {
      return StudentAcademicHistoryWithDetails(
        history: row.readTable(studentAcademicHistories),
        academicYear: row.readTable(academicYears),
        schoolClass: row.readTable(schoolClasses),
        section: row.readTable(sections),
      );
    }).toList();
  }

  /// Insert academic history entry
  Future<int> insertAcademicHistory(
    StudentAcademicHistoriesCompanion companion, {
    InsertMode mode = InsertMode.insertOrReplace,
  }) {
    return into(studentAcademicHistories).insert(companion, mode: mode);
  }

  /// Update academic history entry
  Future<bool> updateAcademicHistoryEntry(StudentAcademicHistory entry) {
    return update(studentAcademicHistories).replace(entry);
  }

  /// Get academic history entry for specific student and academic year
  Future<StudentAcademicHistory?> getStudentAcademicHistoryForYear(
    int studentId,
    int academicYearId,
  ) {
    return (select(studentAcademicHistories)..where(
      (t) =>
          t.studentId.equals(studentId) &
          t.academicYearId.equals(academicYearId),
    )).getSingleOrNull();
  }

  /// Get all enrolled students in an academic year, class, and section
  Future<List<StudentAcademicHistoryWithDetails>>
  getEnrolledStudentsForClassSection(
    int academicYearId,
    int classId,
    int sectionId,
  ) async {
    final query =
        select(studentAcademicHistories).join([
            innerJoin(
              academicYears,
              academicYears.id.equalsExp(
                studentAcademicHistories.academicYearId,
              ),
            ),
            innerJoin(
              schoolClasses,
              schoolClasses.id.equalsExp(studentAcademicHistories.classId),
            ),
            innerJoin(
              sections,
              sections.id.equalsExp(studentAcademicHistories.sectionId),
            ),
            innerJoin(
              students,
              students.id.equalsExp(studentAcademicHistories.studentId),
            ),
          ])
          ..where(
            studentAcademicHistories.academicYearId.equals(academicYearId) &
                studentAcademicHistories.classId.equals(classId) &
                studentAcademicHistories.sectionId.equals(sectionId),
          )
          ..orderBy([
            OrderingTerm(
              expression: studentAcademicHistories.rollNumber,
              mode: OrderingMode.asc,
            ),
            OrderingTerm(expression: students.name, mode: OrderingMode.asc),
          ]);

    final rows = await query.get();
    return rows.map((row) {
      return StudentAcademicHistoryWithDetails(
        history: row.readTable(studentAcademicHistories),
        academicYear: row.readTable(academicYears),
        schoolClass: row.readTable(schoolClasses),
        section: row.readTable(sections),
      );
    }).toList();
  }

  /// Query latest student ID for a given year prefix to generate sequential IDs (e.g. '20260001')
  Future<String?> getLatestStudentIdForYear(int year) async {
    final prefix = '$year%';
    final query =
        select(students)
          ..where((t) => t.studentId.like(prefix))
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.studentId, mode: OrderingMode.desc),
          ])
          ..limit(1);
    final result = await query.getSingleOrNull();
    return result?.studentId;
  }

  /// Query latest admission number for a given year prefix (e.g. 'ADM-2026-0001')
  Future<String?> getLatestAdmissionNumberForYear(int year) async {
    final prefix = 'ADM-$year-%';
    final query =
        select(students)
          ..where((t) => t.admissionNumber.like(prefix))
          ..orderBy([
            (t) => OrderingTerm(
              expression: t.admissionNumber,
              mode: OrderingMode.desc,
            ),
          ])
          ..limit(1);
    final result = await query.getSingleOrNull();
    return result?.admissionNumber;
  }

  // ================= EXPENSE CATEGORIES DAO =================

  /// Stream all expense categories sorted by name
  Stream<List<ExpenseCategory>> watchAllExpenseCategories() {
    return (select(expenseCategories)
      ..orderBy([(t) => OrderingTerm(expression: t.name)])).watch();
  }

  /// Get all expense categories as future
  Future<List<ExpenseCategory>> getAllExpenseCategories() {
    return (select(expenseCategories)
      ..orderBy([(t) => OrderingTerm(expression: t.name)])).get();
  }

  /// Insert a new expense category
  Future<int> insertExpenseCategory(
    ExpenseCategoriesCompanion companion, {
    InsertMode mode = InsertMode.insertOrReplace,
  }) {
    return into(expenseCategories).insert(companion, mode: mode);
  }

  /// Update an existing expense category
  Future<bool> updateExpenseCategory(ExpenseCategory category) {
    return update(expenseCategories).replace(category);
  }

  /// Delete an expense category by ID
  Future<int> deleteExpenseCategory(int id) {
    return (delete(expenseCategories)..where((t) => t.id.equals(id))).go();
  }

  /// Get an expense category by ID
  Future<ExpenseCategory?> getExpenseCategoryById(int id) {
    return (select(expenseCategories)
      ..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  // ================= EXPENSES DAO =================

  /// Reactive stream of expenses joined with their categories and academic years
  Stream<List<ExpenseWithCategory>> watchExpensesWithCategory({
    DateTime? startDate,
    DateTime? endDate,
    int? categoryId,
    String? query,
    int? academicYearId,
  }) {
    final q = select(expenses).join([
      innerJoin(
        expenseCategories,
        expenseCategories.id.equalsExp(expenses.categoryId),
      ),
      leftOuterJoin(
        academicYears,
        academicYears.id.equalsExp(expenses.academicYearId),
      ),
    ]);

    if (academicYearId != null) {
      q.where(expenses.academicYearId.equals(academicYearId));
    }
    if (startDate != null) {
      q.where(expenses.expenseDate.isBiggerOrEqualValue(startDate));
    }
    if (endDate != null) {
      q.where(expenses.expenseDate.isSmallerOrEqualValue(endDate));
    }
    if (categoryId != null) {
      q.where(expenses.categoryId.equals(categoryId));
    }
    if (query != null && query.trim().isNotEmpty) {
      final term = '%${query.trim().toLowerCase()}%';
      q.where(
        expenses.title.lower().like(term) |
            expenses.paidTo.lower().like(term) |
            expenses.referenceNumber.lower().like(term) |
            expenses.paymentMethod.lower().like(term) |
            expenseCategories.name.lower().like(term),
      );
    }

    q.orderBy([
      OrderingTerm(expression: expenses.expenseDate, mode: OrderingMode.desc),
      OrderingTerm(expression: expenses.id, mode: OrderingMode.desc),
    ]);

    return q.watch().map((rows) {
      return rows.map((row) {
        return ExpenseWithCategory(
          expense: row.readTable(expenses),
          category: row.readTable(expenseCategories),
          academicYear: row.readTableOrNull(academicYears),
        );
      }).toList();
    });
  }

  /// Get expenses joined with categories as Future
  Future<List<ExpenseWithCategory>> getExpensesWithCategory({
    DateTime? startDate,
    DateTime? endDate,
    int? categoryId,
    String? query,
    int? academicYearId,
  }) {
    final q = select(expenses).join([
      innerJoin(
        expenseCategories,
        expenseCategories.id.equalsExp(expenses.categoryId),
      ),
      leftOuterJoin(
        academicYears,
        academicYears.id.equalsExp(expenses.academicYearId),
      ),
    ]);

    if (academicYearId != null) {
      q.where(expenses.academicYearId.equals(academicYearId));
    }
    if (startDate != null) {
      q.where(expenses.expenseDate.isBiggerOrEqualValue(startDate));
    }
    if (endDate != null) {
      q.where(expenses.expenseDate.isSmallerOrEqualValue(endDate));
    }
    if (categoryId != null) {
      q.where(expenses.categoryId.equals(categoryId));
    }
    if (query != null && query.trim().isNotEmpty) {
      final term = '%${query.trim().toLowerCase()}%';
      q.where(
        expenses.title.lower().like(term) |
            expenses.paidTo.lower().like(term) |
            expenses.referenceNumber.lower().like(term) |
            expenses.paymentMethod.lower().like(term) |
            expenseCategories.name.lower().like(term),
      );
    }

    q.orderBy([
      OrderingTerm(expression: expenses.expenseDate, mode: OrderingMode.desc),
      OrderingTerm(expression: expenses.id, mode: OrderingMode.desc),
    ]);

    return q.get().then((rows) {
      return rows.map((row) {
        return ExpenseWithCategory(
          expense: row.readTable(expenses),
          category: row.readTable(expenseCategories),
          academicYear: row.readTableOrNull(academicYears),
        );
      }).toList();
    });
  }

  /// Insert a new expense
  Future<int> insertExpense(ExpensesCompanion companion) {
    return into(expenses).insert(companion);
  }

  /// Update an existing expense
  Future<bool> updateExpenseEntry(Expense expense) {
    return update(expenses).replace(expense);
  }

  /// Delete an expense by ID
  Future<int> deleteExpense(int id) {
    return (delete(expenses)..where((t) => t.id.equals(id))).go();
  }

  /// Get an expense by ID
  Future<Expense?> getExpenseById(int id) {
    return (select(expenses)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  // ==========================================
  // EMPLOYEE PAYROLL & SALARY ADVANCES DAO
  // ==========================================

  /// Watch salary payments with joined employee and academic year
  Stream<List<SalaryPaymentWithDetails>> watchSalaryPaymentsWithDetails({
    int? year,
    int? month,
    EmployeeType? employeeType,
    String? query,
    int? academicYearId,
  }) {
    final q = select(salaryPayments).join([
      innerJoin(employees, employees.id.equalsExp(salaryPayments.employeeId)),
      leftOuterJoin(
        academicYears,
        academicYears.id.equalsExp(salaryPayments.academicYearId),
      ),
    ]);

    if (academicYearId != null) {
      q.where(salaryPayments.academicYearId.equals(academicYearId));
    }
    if (year != null) {
      q.where(salaryPayments.year.equals(year));
    }
    if (month != null) {
      q.where(salaryPayments.month.equals(month));
    }
    if (employeeType != null) {
      q.where(employees.employeeType.equals(employeeType.name));
    }
    if (query != null && query.trim().isNotEmpty) {
      final term = '%${query.trim().toLowerCase()}%';
      q.where(
        employees.name.lower().like(term) |
            employees.designation.lower().like(term) |
            salaryPayments.referenceNumber.lower().like(term) |
            salaryPayments.paymentMethod.lower().like(term),
      );
    }

    q.orderBy([
      OrderingTerm(
        expression: salaryPayments.paymentDate,
        mode: OrderingMode.desc,
      ),
      OrderingTerm(expression: salaryPayments.id, mode: OrderingMode.desc),
    ]);

    return q.watch().asyncMap((rows) async {
      final result = <SalaryPaymentWithDetails>[];
      for (final row in rows) {
        final payment = row.readTable(salaryPayments);
        final adjustments =
            await (select(salaryAdvanceAdjustments)
              ..where((t) => t.salaryPaymentId.equals(payment.id))).get();
        result.add(
          SalaryPaymentWithDetails(
            payment: payment,
            employee: row.readTable(employees),
            academicYear: row.readTableOrNull(academicYears),
            adjustments: adjustments,
          ),
        );
      }
      return result;
    });
  }

  /// Get salary payments with joined employee and academic year
  Future<List<SalaryPaymentWithDetails>> getSalaryPaymentsWithDetails({
    int? year,
    int? month,
    EmployeeType? employeeType,
    String? query,
    int? academicYearId,
  }) async {
    final q = select(salaryPayments).join([
      innerJoin(employees, employees.id.equalsExp(salaryPayments.employeeId)),
      leftOuterJoin(
        academicYears,
        academicYears.id.equalsExp(salaryPayments.academicYearId),
      ),
    ]);

    if (academicYearId != null) {
      q.where(salaryPayments.academicYearId.equals(academicYearId));
    }
    if (year != null) {
      q.where(salaryPayments.year.equals(year));
    }
    if (month != null) {
      q.where(salaryPayments.month.equals(month));
    }
    if (employeeType != null) {
      q.where(employees.employeeType.equals(employeeType.name));
    }
    if (query != null && query.trim().isNotEmpty) {
      final term = '%${query.trim().toLowerCase()}%';
      q.where(
        employees.name.lower().like(term) |
            employees.designation.lower().like(term) |
            salaryPayments.referenceNumber.lower().like(term) |
            salaryPayments.paymentMethod.lower().like(term),
      );
    }

    q.orderBy([
      OrderingTerm(
        expression: salaryPayments.paymentDate,
        mode: OrderingMode.desc,
      ),
      OrderingTerm(expression: salaryPayments.id, mode: OrderingMode.desc),
    ]);

    final rows = await q.get();
    final result = <SalaryPaymentWithDetails>[];
    for (final row in rows) {
      final payment = row.readTable(salaryPayments);
      final adjustments =
          await (select(salaryAdvanceAdjustments)
            ..where((t) => t.salaryPaymentId.equals(payment.id))).get();
      result.add(
        SalaryPaymentWithDetails(
          payment: payment,
          employee: row.readTable(employees),
          academicYear: row.readTableOrNull(academicYears),
          adjustments: adjustments,
        ),
      );
    }
    return result;
  }

  /// Insert a salary payment
  Future<int> insertSalaryPayment(SalaryPaymentsCompanion companion) {
    return into(salaryPayments).insert(companion);
  }

  /// Update salary payment
  Future<bool> updateSalaryPaymentEntry(SalaryPayment payment) {
    return update(salaryPayments).replace(payment);
  }

  /// Delete salary payment
  Future<int> deleteSalaryPayment(int id) {
    return (delete(salaryPayments)..where((t) => t.id.equals(id))).go();
  }

  /// Get salary payment by ID
  Future<SalaryPayment?> getSalaryPaymentById(int id) {
    return (select(salaryPayments)
      ..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Watch salary advances with joined employee
  Stream<List<SalaryAdvanceWithEmployee>> watchSalaryAdvancesWithEmployee({
    int? employeeId,
    String? status,
    String? query,
    int? academicYearId,
  }) {
    final q = select(salaryAdvances).join([
      innerJoin(employees, employees.id.equalsExp(salaryAdvances.employeeId)),
      leftOuterJoin(
        academicYears,
        academicYears.id.equalsExp(salaryAdvances.academicYearId),
      ),
    ]);

    if (academicYearId != null) {
      q.where(salaryAdvances.academicYearId.equals(academicYearId));
    }
    if (employeeId != null) {
      q.where(salaryAdvances.employeeId.equals(employeeId));
    }
    if (status != null && status != 'all') {
      if (status == 'settled') {
        q.where(salaryAdvances.status.equals('settled'));
      } else if (status == 'active' || status == 'pending') {
        q.where(salaryAdvances.status.isNotValue('settled'));
      }
    }
    if (query != null && query.trim().isNotEmpty) {
      final term = '%${query.trim().toLowerCase()}%';
      q.where(
        employees.name.lower().like(term) |
            employees.designation.lower().like(term) |
            salaryAdvances.reason.lower().like(term) |
            salaryAdvances.referenceNumber.lower().like(term),
      );
    }

    q.orderBy([
      OrderingTerm(
        expression: salaryAdvances.advanceDate,
        mode: OrderingMode.desc,
      ),
      OrderingTerm(expression: salaryAdvances.id, mode: OrderingMode.desc),
    ]);

    return q.watch().map((rows) {
      return rows.map((row) {
        return SalaryAdvanceWithEmployee(
          advance: row.readTable(salaryAdvances),
          employee: row.readTable(employees),
          academicYear: row.readTableOrNull(academicYears),
        );
      }).toList();
    });
  }

  /// Get salary advances with joined employee
  Future<List<SalaryAdvanceWithEmployee>> getSalaryAdvancesWithEmployee({
    int? employeeId,
    String? status,
    String? query,
    int? academicYearId,
  }) {
    final q = select(salaryAdvances).join([
      innerJoin(employees, employees.id.equalsExp(salaryAdvances.employeeId)),
      leftOuterJoin(
        academicYears,
        academicYears.id.equalsExp(salaryAdvances.academicYearId),
      ),
    ]);

    if (academicYearId != null) {
      q.where(salaryAdvances.academicYearId.equals(academicYearId));
    }
    if (employeeId != null) {
      q.where(salaryAdvances.employeeId.equals(employeeId));
    }
    if (status != null && status != 'all') {
      if (status == 'settled') {
        q.where(salaryAdvances.status.equals('settled'));
      } else if (status == 'active' || status == 'pending') {
        q.where(salaryAdvances.status.isNotValue('settled'));
      }
    }
    if (query != null && query.trim().isNotEmpty) {
      final term = '%${query.trim().toLowerCase()}%';
      q.where(
        employees.name.lower().like(term) |
            employees.designation.lower().like(term) |
            salaryAdvances.reason.lower().like(term) |
            salaryAdvances.referenceNumber.lower().like(term),
      );
    }

    q.orderBy([
      OrderingTerm(
        expression: salaryAdvances.advanceDate,
        mode: OrderingMode.desc,
      ),
      OrderingTerm(expression: salaryAdvances.id, mode: OrderingMode.desc),
    ]);

    return q.get().then((rows) {
      return rows.map((row) {
        return SalaryAdvanceWithEmployee(
          advance: row.readTable(salaryAdvances),
          employee: row.readTable(employees),
          academicYear: row.readTableOrNull(academicYears),
        );
      }).toList();
    });
  }

  /// Get all pending/partially settled advances for an employee (ordered chronologically FIFO)
  Future<List<SalaryAdvance>> getPendingAdvancesForEmployee(int employeeId) {
    return (select(salaryAdvances)
          ..where(
            (t) =>
                t.employeeId.equals(employeeId) &
                t.status.isNotValue('settled'),
          )
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.advanceDate, mode: OrderingMode.asc),
          ]))
        .get();
  }

  /// Insert salary advance
  Future<int> insertSalaryAdvance(SalaryAdvancesCompanion companion) {
    return into(salaryAdvances).insert(companion);
  }

  /// Update salary advance
  Future<bool> updateSalaryAdvanceEntry(SalaryAdvance advance) {
    return update(salaryAdvances).replace(advance);
  }

  /// Delete salary advance
  Future<int> deleteSalaryAdvance(int id) {
    return (delete(salaryAdvances)..where((t) => t.id.equals(id))).go();
  }

  /// Get salary advance by ID
  Future<SalaryAdvance?> getSalaryAdvanceById(int id) {
    return (select(salaryAdvances)
      ..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Insert advance adjustment link
  Future<int> insertSalaryAdvanceAdjustment(
    SalaryAdvanceAdjustmentsCompanion companion,
  ) {
    return into(salaryAdvanceAdjustments).insert(companion);
  }

  /// Get adjustments for a payment
  Future<List<SalaryAdvanceAdjustment>> getAdjustmentsForPayment(
    int paymentId,
  ) {
    return (select(salaryAdvanceAdjustments)
      ..where((t) => t.salaryPaymentId.equals(paymentId))).get();
  }

  /// Delete adjustments for a payment
  Future<int> deleteAdjustmentsForPayment(int paymentId) {
    return (delete(salaryAdvanceAdjustments)
      ..where((t) => t.salaryPaymentId.equals(paymentId))).go();
  }

  // ==================== FEE MANAGEMENT ====================

  /// Stream all fee categories
  Stream<List<FeeCategory>> watchAllFeeCategories() {
    return (select(feeCategories)..orderBy([
      (t) => OrderingTerm(expression: t.name, mode: OrderingMode.asc),
    ])).watch();
  }

  /// Get all fee categories
  Future<List<FeeCategory>> getAllFeeCategories() {
    return (select(feeCategories)..orderBy([
      (t) => OrderingTerm(expression: t.name, mode: OrderingMode.asc),
    ])).get();
  }

  /// Insert fee category
  Future<int> insertFeeCategory(FeeCategoriesCompanion companion) {
    return into(feeCategories).insert(companion);
  }

  /// Update fee category
  Future<bool> updateFeeCategory(FeeCategory category) {
    return update(feeCategories).replace(category);
  }

  /// Delete fee category
  Future<int> deleteFeeCategory(int id) {
    return (delete(feeCategories)..where((t) => t.id.equals(id))).go();
  }

  /// Get fee category by ID
  Future<FeeCategory?> getFeeCategoryById(int id) {
    return (select(feeCategories)
      ..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Watch student fees with joined student, category, and academic year
  Stream<List<StudentFeeWithDetails>> watchStudentFeesWithDetails({
    int? studentId,
    int? academicYearId,
    String? status,
    String? frequency,
    String? query,
  }) {
    final q = select(studentFees).join([
      innerJoin(students, students.id.equalsExp(studentFees.studentId)),
      innerJoin(
        feeCategories,
        feeCategories.id.equalsExp(studentFees.feeCategoryId),
      ),
      leftOuterJoin(
        academicYears,
        academicYears.id.equalsExp(studentFees.academicYearId),
      ),
    ]);

    if (studentId != null) {
      q.where(studentFees.studentId.equals(studentId));
    }
    if (academicYearId != null) {
      q.where(studentFees.academicYearId.equals(academicYearId));
    }
    if (status != null && status != 'all') {
      q.where(studentFees.status.equals(status));
    }
    if (frequency != null && frequency != 'all') {
      q.where(feeCategories.frequency.equals(frequency));
    }
    if (query != null && query.trim().isNotEmpty) {
      final term = '%${query.trim().toLowerCase()}%';
      q.where(
        students.name.lower().like(term) |
            students.admissionNumber.lower().like(term) |
            studentFees.title.lower().like(term) |
            feeCategories.name.lower().like(term),
      );
    }

    q.orderBy([
      OrderingTerm(expression: studentFees.dueDate, mode: OrderingMode.desc),
      OrderingTerm(expression: studentFees.id, mode: OrderingMode.desc),
    ]);

    return q.watch().asyncMap((rows) async {
      final result = <StudentFeeWithDetails>[];
      for (final row in rows) {
        final fee = row.readTable(studentFees);
        final payments =
            await (select(feePayments)
                  ..where((t) => t.studentFeeId.equals(fee.id))
                  ..orderBy([
                    (t) => OrderingTerm(
                      expression: t.paymentDate,
                      mode: OrderingMode.desc,
                    ),
                  ]))
                .get();
        result.add(
          StudentFeeWithDetails(
            fee: fee,
            student: row.readTable(students),
            category: row.readTable(feeCategories),
            academicYear: row.readTableOrNull(academicYears),
            payments: payments,
          ),
        );
      }
      return result;
    });
  }

  /// Get student fees with joined student, category, and academic year
  Future<List<StudentFeeWithDetails>> getStudentFeesWithDetails({
    int? studentId,
    int? academicYearId,
    String? status,
    String? frequency,
    String? query,
  }) async {
    final q = select(studentFees).join([
      innerJoin(students, students.id.equalsExp(studentFees.studentId)),
      innerJoin(
        feeCategories,
        feeCategories.id.equalsExp(studentFees.feeCategoryId),
      ),
      leftOuterJoin(
        academicYears,
        academicYears.id.equalsExp(studentFees.academicYearId),
      ),
    ]);

    if (studentId != null) {
      q.where(studentFees.studentId.equals(studentId));
    }
    if (academicYearId != null) {
      q.where(studentFees.academicYearId.equals(academicYearId));
    }
    if (status != null && status != 'all') {
      q.where(studentFees.status.equals(status));
    }
    if (frequency != null && frequency != 'all') {
      q.where(feeCategories.frequency.equals(frequency));
    }
    if (query != null && query.trim().isNotEmpty) {
      final term = '%${query.trim().toLowerCase()}%';
      q.where(
        students.name.lower().like(term) |
            students.admissionNumber.lower().like(term) |
            studentFees.title.lower().like(term) |
            feeCategories.name.lower().like(term),
      );
    }

    q.orderBy([
      OrderingTerm(expression: studentFees.dueDate, mode: OrderingMode.desc),
      OrderingTerm(expression: studentFees.id, mode: OrderingMode.desc),
    ]);

    final rows = await q.get();
    final result = <StudentFeeWithDetails>[];
    for (final row in rows) {
      final fee = row.readTable(studentFees);
      final payments =
          await (select(feePayments)
                ..where((t) => t.studentFeeId.equals(fee.id))
                ..orderBy([
                  (t) => OrderingTerm(
                    expression: t.paymentDate,
                    mode: OrderingMode.desc,
                  ),
                ]))
              .get();
      result.add(
        StudentFeeWithDetails(
          fee: fee,
          student: row.readTable(students),
          category: row.readTable(feeCategories),
          academicYear: row.readTableOrNull(academicYears),
          payments: payments,
        ),
      );
    }
    return result;
  }

  /// Insert student fee
  Future<int> insertStudentFee(StudentFeesCompanion companion) {
    return into(studentFees).insert(companion);
  }

  /// Update student fee
  Future<bool> updateStudentFeeEntry(StudentFee fee) {
    return update(studentFees).replace(fee);
  }

  /// Delete student fee
  Future<int> deleteStudentFee(int id) {
    return (delete(studentFees)..where((t) => t.id.equals(id))).go();
  }

  /// Get student fee by ID
  Future<StudentFee?> getStudentFeeById(int id) {
    return (select(studentFees)
      ..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Watch fee payments with details
  Stream<List<FeePaymentWithDetails>> watchFeePaymentsWithDetails({
    int? studentId,
    int? academicYearId,
    DateTime? startDate,
    DateTime? endDate,
    String? query,
  }) {
    final q = select(feePayments).join([
      innerJoin(
        studentFees,
        studentFees.id.equalsExp(feePayments.studentFeeId),
      ),
      innerJoin(students, students.id.equalsExp(feePayments.studentId)),
      innerJoin(
        feeCategories,
        feeCategories.id.equalsExp(studentFees.feeCategoryId),
      ),
      leftOuterJoin(
        academicYears,
        academicYears.id.equalsExp(feePayments.academicYearId),
      ),
    ]);

    if (studentId != null) {
      q.where(feePayments.studentId.equals(studentId));
    }
    if (academicYearId != null) {
      q.where(feePayments.academicYearId.equals(academicYearId));
    }
    if (startDate != null) {
      q.where(feePayments.paymentDate.isBiggerOrEqualValue(startDate));
    }
    if (endDate != null) {
      q.where(feePayments.paymentDate.isSmallerOrEqualValue(endDate));
    }
    if (query != null && query.trim().isNotEmpty) {
      final term = '%${query.trim().toLowerCase()}%';
      q.where(
        students.name.lower().like(term) |
            students.admissionNumber.lower().like(term) |
            feePayments.receiptNumber.lower().like(term) |
            studentFees.title.lower().like(term) |
            feePayments.paymentMethod.lower().like(term),
      );
    }

    q.orderBy([
      OrderingTerm(
        expression: feePayments.paymentDate,
        mode: OrderingMode.desc,
      ),
      OrderingTerm(expression: feePayments.id, mode: OrderingMode.desc),
    ]);

    return q.watch().map((rows) {
      return rows.map((row) {
        return FeePaymentWithDetails(
          payment: row.readTable(feePayments),
          fee: row.readTable(studentFees),
          student: row.readTable(students),
          category: row.readTable(feeCategories),
          academicYear: row.readTableOrNull(academicYears),
        );
      }).toList();
    });
  }

  /// Get fee payments with details
  Future<List<FeePaymentWithDetails>> getFeePaymentsWithDetails({
    int? studentId,
    int? academicYearId,
    DateTime? startDate,
    DateTime? endDate,
    String? query,
  }) async {
    final q = select(feePayments).join([
      innerJoin(
        studentFees,
        studentFees.id.equalsExp(feePayments.studentFeeId),
      ),
      innerJoin(students, students.id.equalsExp(feePayments.studentId)),
      innerJoin(
        feeCategories,
        feeCategories.id.equalsExp(studentFees.feeCategoryId),
      ),
      leftOuterJoin(
        academicYears,
        academicYears.id.equalsExp(feePayments.academicYearId),
      ),
    ]);

    if (studentId != null) {
      q.where(feePayments.studentId.equals(studentId));
    }
    if (academicYearId != null) {
      q.where(feePayments.academicYearId.equals(academicYearId));
    }
    if (startDate != null) {
      q.where(feePayments.paymentDate.isBiggerOrEqualValue(startDate));
    }
    if (endDate != null) {
      q.where(feePayments.paymentDate.isSmallerOrEqualValue(endDate));
    }
    if (query != null && query.trim().isNotEmpty) {
      final term = '%${query.trim().toLowerCase()}%';
      q.where(
        students.name.lower().like(term) |
            students.admissionNumber.lower().like(term) |
            feePayments.receiptNumber.lower().like(term) |
            studentFees.title.lower().like(term) |
            feePayments.paymentMethod.lower().like(term),
      );
    }

    q.orderBy([
      OrderingTerm(
        expression: feePayments.paymentDate,
        mode: OrderingMode.desc,
      ),
      OrderingTerm(expression: feePayments.id, mode: OrderingMode.desc),
    ]);

    final rows = await q.get();
    return rows.map((row) {
      return FeePaymentWithDetails(
        payment: row.readTable(feePayments),
        fee: row.readTable(studentFees),
        student: row.readTable(students),
        category: row.readTable(feeCategories),
        academicYear: row.readTableOrNull(academicYears),
      );
    }).toList();
  }

  /// Get payments for a specific student fee
  Future<List<FeePayment>> getFeePaymentsForStudentFee(int studentFeeId) {
    return (select(feePayments)
          ..where((t) => t.studentFeeId.equals(studentFeeId))
          ..orderBy([
            (t) => OrderingTerm(
              expression: t.paymentDate,
              mode: OrderingMode.desc,
            ),
          ]))
        .get();
  }

  /// Insert fee payment
  Future<int> insertFeePayment(FeePaymentsCompanion companion) {
    return into(feePayments).insert(companion);
  }

  /// Delete fee payment
  Future<int> deleteFeePayment(int id) {
    return (delete(feePayments)..where((t) => t.id.equals(id))).go();
  }

  /// Get fee payment by ID
  Future<FeePayment?> getFeePaymentById(int id) {
    return (select(feePayments)
      ..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  // ==================== CERTIFICATES ====================

  /// Watch all certificates with joined student, class, section, academic year
  Stream<List<CertificateWithDetails>> watchCertificatesWithDetails({
    String? certificateType,
    int? studentId,
    int? classId,
    int? academicYearId,
    String? query,
    String? status,
  }) {
    final q = select(certificates).join([
      innerJoin(students, students.id.equalsExp(certificates.studentId)),
      leftOuterJoin(
        schoolClasses,
        schoolClasses.id.equalsExp(students.classId),
      ),
      leftOuterJoin(sections, sections.id.equalsExp(students.sectionId)),
      leftOuterJoin(
        academicYears,
        academicYears.id.equalsExp(certificates.academicYearId),
      ),
    ]);

    if (certificateType != null && certificateType != 'all') {
      q.where(certificates.certificateType.equals(certificateType));
    }
    if (studentId != null) {
      q.where(certificates.studentId.equals(studentId));
    }
    if (classId != null) {
      q.where(students.classId.equals(classId));
    }
    if (academicYearId != null) {
      q.where(certificates.academicYearId.equals(academicYearId));
    }
    if (status != null && status != 'all') {
      q.where(certificates.status.equals(status));
    }
    if (query != null && query.trim().isNotEmpty) {
      final term = '%${query.trim()}%';
      q.where(
        certificates.certificateNumber.like(term) |
            students.name.like(term) |
            students.admissionNumber.like(term) |
            certificates.title.like(term),
      );
    }

    q.orderBy([
      OrderingTerm(expression: certificates.issueDate, mode: OrderingMode.desc),
      OrderingTerm(expression: certificates.id, mode: OrderingMode.desc),
    ]);

    return q.watch().map((rows) {
      return rows.map((row) {
        return CertificateWithDetails(
          certificate: row.readTable(certificates),
          student: row.readTable(students),
          schoolClass: row.readTableOrNull(schoolClasses),
          section: row.readTableOrNull(sections),
          academicYear: row.readTableOrNull(academicYears),
        );
      }).toList();
    });
  }

  /// Get certificates with details as future
  Future<List<CertificateWithDetails>> getCertificatesWithDetails({
    String? certificateType,
    int? studentId,
    int? classId,
    int? academicYearId,
    String? query,
    String? status,
  }) {
    final q = select(certificates).join([
      innerJoin(students, students.id.equalsExp(certificates.studentId)),
      leftOuterJoin(
        schoolClasses,
        schoolClasses.id.equalsExp(students.classId),
      ),
      leftOuterJoin(sections, sections.id.equalsExp(students.sectionId)),
      leftOuterJoin(
        academicYears,
        academicYears.id.equalsExp(certificates.academicYearId),
      ),
    ]);

    if (certificateType != null && certificateType != 'all') {
      q.where(certificates.certificateType.equals(certificateType));
    }
    if (studentId != null) {
      q.where(certificates.studentId.equals(studentId));
    }
    if (classId != null) {
      q.where(students.classId.equals(classId));
    }
    if (academicYearId != null) {
      q.where(certificates.academicYearId.equals(academicYearId));
    }
    if (status != null && status != 'all') {
      q.where(certificates.status.equals(status));
    }
    if (query != null && query.trim().isNotEmpty) {
      final term = '%${query.trim()}%';
      q.where(
        certificates.certificateNumber.like(term) |
            students.name.like(term) |
            students.admissionNumber.like(term) |
            certificates.title.like(term),
      );
    }

    q.orderBy([
      OrderingTerm(expression: certificates.issueDate, mode: OrderingMode.desc),
      OrderingTerm(expression: certificates.id, mode: OrderingMode.desc),
    ]);

    return q.get().then((rows) {
      return rows.map((row) {
        return CertificateWithDetails(
          certificate: row.readTable(certificates),
          student: row.readTable(students),
          schoolClass: row.readTableOrNull(schoolClasses),
          section: row.readTableOrNull(sections),
          academicYear: row.readTableOrNull(academicYears),
        );
      }).toList();
    });
  }

  /// Get single certificate with details by ID
  Future<CertificateWithDetails?> getCertificateWithDetailsById(int id) {
    final q = select(certificates).join([
      innerJoin(students, students.id.equalsExp(certificates.studentId)),
      leftOuterJoin(
        schoolClasses,
        schoolClasses.id.equalsExp(students.classId),
      ),
      leftOuterJoin(sections, sections.id.equalsExp(students.sectionId)),
      leftOuterJoin(
        academicYears,
        academicYears.id.equalsExp(certificates.academicYearId),
      ),
    ])..where(certificates.id.equals(id));

    return q.getSingleOrNull().then((row) {
      if (row == null) return null;
      return CertificateWithDetails(
        certificate: row.readTable(certificates),
        student: row.readTable(students),
        schoolClass: row.readTableOrNull(schoolClasses),
        section: row.readTableOrNull(sections),
        academicYear: row.readTableOrNull(academicYears),
      );
    });
  }

  /// Insert a certificate
  Future<int> insertCertificate(CertificatesCompanion companion) {
    return into(certificates).insert(companion);
  }

  /// Update a certificate
  Future<bool> updateCertificate(Insertable<Certificate> companion) {
    return update(certificates).replace(companion);
  }

  /// Delete a certificate
  Future<int> deleteCertificate(int id) {
    return (delete(certificates)..where((t) => t.id.equals(id))).go();
  }

  /// Count certificates
  Future<int> countCertificates({String? certificateType}) {
    final countExp = certificates.id.count();
    final q = selectOnly(certificates)..addColumns([countExp]);
    if (certificateType != null) {
      q.where(certificates.certificateType.equals(certificateType));
    }
    return q.map((r) => r.read(countExp) ?? 0).getSingle();
  }

  // ==========================================
  // EXAMS & EXAM SCHEDULES
  // ==========================================

  /// Watch reactive list of exams with details
  Stream<List<ExamWithDetails>> watchExamsWithDetails({
    int? academicYearId,
    String? category,
    String? status,
  }) {
    final query = select(exams).join([
      innerJoin(
        academicYears,
        academicYears.id.equalsExp(exams.academicYearId),
      ),
    ]);

    if (academicYearId != null) {
      query.where(exams.academicYearId.equals(academicYearId));
    }
    if (category != null && category.trim().isNotEmpty) {
      query.where(exams.category.equals(category.trim()));
    }
    if (status != null && status.trim().isNotEmpty) {
      query.where(exams.status.equals(status.trim()));
    }

    query.orderBy([
      OrderingTerm(expression: exams.startDate, mode: OrderingMode.desc),
    ]);

    return query.watch().asyncMap((rows) async {
      final result = <ExamWithDetails>[];
      for (final row in rows) {
        final examRow = row.readTable(exams);
        final yearRow = row.readTable(academicYears);

        // Count schedules and distinct classes
        final scheduleCountExp = examSchedules.id.count();
        final classCountExp = examSchedules.classId.count(distinct: true);
        final countQuery =
            selectOnly(examSchedules)
              ..addColumns([scheduleCountExp, classCountExp])
              ..where(examSchedules.examId.equals(examRow.id));
        final countRow = await countQuery.getSingleOrNull();

        result.add(
          ExamWithDetails(
            exam: examRow,
            academicYear: yearRow,
            scheduleCount: countRow?.read(scheduleCountExp) ?? 0,
            classCount: countRow?.read(classCountExp) ?? 0,
          ),
        );
      }
      return result;
    });
  }

  /// Get all exams with details
  Future<List<ExamWithDetails>> getAllExamsWithDetails({
    int? academicYearId,
    String? category,
    String? status,
  }) async {
    final query = select(exams).join([
      innerJoin(
        academicYears,
        academicYears.id.equalsExp(exams.academicYearId),
      ),
    ]);

    if (academicYearId != null) {
      query.where(exams.academicYearId.equals(academicYearId));
    }
    if (category != null && category.trim().isNotEmpty) {
      query.where(exams.category.equals(category.trim()));
    }
    if (status != null && status.trim().isNotEmpty) {
      query.where(exams.status.equals(status.trim()));
    }

    query.orderBy([
      OrderingTerm(expression: exams.startDate, mode: OrderingMode.desc),
    ]);

    final rows = await query.get();
    final result = <ExamWithDetails>[];
    for (final row in rows) {
      final examRow = row.readTable(exams);
      final yearRow = row.readTable(academicYears);

      final scheduleCountExp = examSchedules.id.count();
      final classCountExp = examSchedules.classId.count(distinct: true);
      final countQuery =
          selectOnly(examSchedules)
            ..addColumns([scheduleCountExp, classCountExp])
            ..where(examSchedules.examId.equals(examRow.id));
      final countRow = await countQuery.getSingleOrNull();

      result.add(
        ExamWithDetails(
          exam: examRow,
          academicYear: yearRow,
          scheduleCount: countRow?.read(scheduleCountExp) ?? 0,
          classCount: countRow?.read(classCountExp) ?? 0,
        ),
      );
    }
    return result;
  }

  /// Get exam with details by ID
  Future<ExamWithDetails?> getExamWithDetailsById(int id) async {
    final query = select(exams).join([
      innerJoin(
        academicYears,
        academicYears.id.equalsExp(exams.academicYearId),
      ),
    ])..where(exams.id.equals(id));

    final row = await query.getSingleOrNull();
    if (row == null) return null;

    final examRow = row.readTable(exams);
    final yearRow = row.readTable(academicYears);

    final scheduleCountExp = examSchedules.id.count();
    final classCountExp = examSchedules.classId.count(distinct: true);
    final countQuery =
        selectOnly(examSchedules)
          ..addColumns([scheduleCountExp, classCountExp])
          ..where(examSchedules.examId.equals(examRow.id));
    final countRow = await countQuery.getSingleOrNull();

    return ExamWithDetails(
      exam: examRow,
      academicYear: yearRow,
      scheduleCount: countRow?.read(scheduleCountExp) ?? 0,
      classCount: countRow?.read(classCountExp) ?? 0,
    );
  }

  /// Insert exam
  Future<int> insertExam(ExamsCompanion companion) {
    return into(exams).insert(companion);
  }

  /// Update exam
  Future<bool> updateExam(Insertable<Exam> companion) {
    return update(exams).replace(companion);
  }

  /// Delete exam (cascades to examSchedules)
  Future<int> deleteExam(int id) {
    return (delete(exams)..where((t) => t.id.equals(id))).go();
  }

  /// Watch reactive list of exam schedules with details
  Stream<List<ExamScheduleWithDetails>> watchExamSchedulesWithDetails({
    int? examId,
    int? classId,
    int? academicYearId,
    int? subjectId,
  }) {
    final query = select(examSchedules).join([
      innerJoin(exams, exams.id.equalsExp(examSchedules.examId)),
      innerJoin(
        academicYears,
        academicYears.id.equalsExp(examSchedules.academicYearId),
      ),
      innerJoin(
        schoolClasses,
        schoolClasses.id.equalsExp(examSchedules.classId),
      ),
      innerJoin(subjects, subjects.id.equalsExp(examSchedules.subjectId)),
    ]);

    if (examId != null) {
      query.where(examSchedules.examId.equals(examId));
    }
    if (classId != null) {
      query.where(examSchedules.classId.equals(classId));
    }
    if (academicYearId != null) {
      query.where(examSchedules.academicYearId.equals(academicYearId));
    }
    if (subjectId != null) {
      query.where(examSchedules.subjectId.equals(subjectId));
    }

    query.orderBy([
      OrderingTerm(expression: examSchedules.examDate, mode: OrderingMode.asc),
      OrderingTerm(
        expression: examSchedules.orderIndex,
        mode: OrderingMode.asc,
      ),
      OrderingTerm(expression: examSchedules.startTime, mode: OrderingMode.asc),
    ]);

    return query.watch().map((rows) {
      return rows.map((row) {
        return ExamScheduleWithDetails(
          schedule: row.readTable(examSchedules),
          exam: row.readTable(exams),
          academicYear: row.readTable(academicYears),
          schoolClass: row.readTable(schoolClasses),
          subject: row.readTable(subjects),
        );
      }).toList();
    });
  }

  /// Get all exam schedules with details
  Future<List<ExamScheduleWithDetails>> getAllExamSchedulesWithDetails({
    int? examId,
    int? classId,
    int? academicYearId,
    int? subjectId,
  }) {
    final query = select(examSchedules).join([
      innerJoin(exams, exams.id.equalsExp(examSchedules.examId)),
      innerJoin(
        academicYears,
        academicYears.id.equalsExp(examSchedules.academicYearId),
      ),
      innerJoin(
        schoolClasses,
        schoolClasses.id.equalsExp(examSchedules.classId),
      ),
      innerJoin(subjects, subjects.id.equalsExp(examSchedules.subjectId)),
    ]);

    if (examId != null) {
      query.where(examSchedules.examId.equals(examId));
    }
    if (classId != null) {
      query.where(examSchedules.classId.equals(classId));
    }
    if (academicYearId != null) {
      query.where(examSchedules.academicYearId.equals(academicYearId));
    }
    if (subjectId != null) {
      query.where(examSchedules.subjectId.equals(subjectId));
    }

    query.orderBy([
      OrderingTerm(expression: examSchedules.examDate, mode: OrderingMode.asc),
      OrderingTerm(
        expression: examSchedules.orderIndex,
        mode: OrderingMode.asc,
      ),
      OrderingTerm(expression: examSchedules.startTime, mode: OrderingMode.asc),
    ]);

    return query.map((row) {
      return ExamScheduleWithDetails(
        schedule: row.readTable(examSchedules),
        exam: row.readTable(exams),
        academicYear: row.readTable(academicYears),
        schoolClass: row.readTable(schoolClasses),
        subject: row.readTable(subjects),
      );
    }).get();
  }

  /// Insert single exam schedule
  Future<int> insertExamSchedule(ExamSchedulesCompanion companion) {
    return into(examSchedules).insert(companion);
  }

  /// Update single exam schedule
  Future<bool> updateExamSchedule(Insertable<ExamSchedule> companion) {
    return update(examSchedules).replace(companion);
  }

  /// Delete single exam schedule
  Future<int> deleteExamSchedule(int id) {
    return (delete(examSchedules)..where((t) => t.id.equals(id))).go();
  }

  /// Delete all schedules for a class within an exam
  Future<int> deleteExamSchedulesForClass(int examId, int classId) {
    return (delete(examSchedules)
      ..where((t) => t.examId.equals(examId) & t.classId.equals(classId))).go();
  }

  /// Replace all subject schedules for a given class in an exam (atomic transaction)
  Future<void> replaceClassExamSchedules(
    int examId,
    int classId,
    List<ExamSchedulesCompanion> companions,
  ) {
    return transaction(() async {
      await (delete(examSchedules)..where(
        (t) => t.examId.equals(examId) & t.classId.equals(classId),
      )).go();
      for (final companion in companions) {
        await into(examSchedules).insert(companion);
      }
    });
  }

  // ===========================================================================
  // Exam Results & Marks Operations
  // ===========================================================================

  /// Watch reactive stream of exam results with joined details
  Stream<List<ExamResultWithDetails>> watchExamResultsWithDetails({
    int? examId,
    int? classId,
    int? sectionId,
    int? subjectId,
    int? studentId,
    int? academicYearId,
  }) {
    final query = select(examResults).join([
      innerJoin(exams, exams.id.equalsExp(examResults.examId)),
      innerJoin(
        academicYears,
        academicYears.id.equalsExp(examResults.academicYearId),
      ),
      innerJoin(schoolClasses, schoolClasses.id.equalsExp(examResults.classId)),
      leftOuterJoin(sections, sections.id.equalsExp(examResults.sectionId)),
      innerJoin(students, students.id.equalsExp(examResults.studentId)),
      innerJoin(subjects, subjects.id.equalsExp(examResults.subjectId)),
      leftOuterJoin(
        examSchedules,
        examSchedules.id.equalsExp(examResults.examScheduleId),
      ),
    ]);

    if (examId != null) {
      query.where(examResults.examId.equals(examId));
    }
    if (classId != null) {
      query.where(examResults.classId.equals(classId));
    }
    if (sectionId != null) {
      query.where(examResults.sectionId.equals(sectionId));
    }
    if (subjectId != null) {
      query.where(examResults.subjectId.equals(subjectId));
    }
    if (studentId != null) {
      query.where(examResults.studentId.equals(studentId));
    }
    if (academicYearId != null) {
      query.where(examResults.academicYearId.equals(academicYearId));
    }

    query.orderBy([
      OrderingTerm(expression: students.rollNumber, mode: OrderingMode.asc),
      OrderingTerm(expression: students.name, mode: OrderingMode.asc),
    ]);

    return query.watch().map((rows) {
      return rows.map((row) {
        return ExamResultWithDetails(
          result: row.readTable(examResults),
          exam: row.readTable(exams),
          academicYear: row.readTable(academicYears),
          schoolClass: row.readTable(schoolClasses),
          section: row.readTableOrNull(sections),
          student: row.readTable(students),
          subject: row.readTable(subjects),
          schedule: row.readTableOrNull(examSchedules),
        );
      }).toList();
    });
  }

  /// Get exam results with joined details
  Future<List<ExamResultWithDetails>> getExamResultsWithDetails({
    int? examId,
    int? classId,
    int? sectionId,
    int? subjectId,
    int? studentId,
    int? academicYearId,
  }) {
    final query = select(examResults).join([
      innerJoin(exams, exams.id.equalsExp(examResults.examId)),
      innerJoin(
        academicYears,
        academicYears.id.equalsExp(examResults.academicYearId),
      ),
      innerJoin(schoolClasses, schoolClasses.id.equalsExp(examResults.classId)),
      leftOuterJoin(sections, sections.id.equalsExp(examResults.sectionId)),
      innerJoin(students, students.id.equalsExp(examResults.studentId)),
      innerJoin(subjects, subjects.id.equalsExp(examResults.subjectId)),
      leftOuterJoin(
        examSchedules,
        examSchedules.id.equalsExp(examResults.examScheduleId),
      ),
    ]);

    if (examId != null) {
      query.where(examResults.examId.equals(examId));
    }
    if (classId != null) {
      query.where(examResults.classId.equals(classId));
    }
    if (sectionId != null) {
      query.where(examResults.sectionId.equals(sectionId));
    }
    if (subjectId != null) {
      query.where(examResults.subjectId.equals(subjectId));
    }
    if (studentId != null) {
      query.where(examResults.studentId.equals(studentId));
    }
    if (academicYearId != null) {
      query.where(examResults.academicYearId.equals(academicYearId));
    }

    query.orderBy([
      OrderingTerm(expression: students.rollNumber, mode: OrderingMode.asc),
      OrderingTerm(expression: students.name, mode: OrderingMode.asc),
    ]);

    return query.map((row) {
      return ExamResultWithDetails(
        result: row.readTable(examResults),
        exam: row.readTable(exams),
        academicYear: row.readTable(academicYears),
        schoolClass: row.readTable(schoolClasses),
        section: row.readTableOrNull(sections),
        student: row.readTable(students),
        subject: row.readTable(subjects),
        schedule: row.readTableOrNull(examSchedules),
      );
    }).get();
  }

  /// Upsert single exam result
  Future<int> upsertExamResult(ExamResultsCompanion companion) {
    return into(
      examResults,
    ).insert(companion, mode: InsertMode.insertOrReplace);
  }

  /// Batch upsert exam results (fast bulk save)
  Future<void> batchUpsertExamResults(List<ExamResultsCompanion> companions) {
    return batch((b) {
      b.insertAll(examResults, companions, mode: InsertMode.insertOrReplace);
    });
  }

  /// Delete exam result by ID
  Future<int> deleteExamResult(int id) {
    return (delete(examResults)..where((t) => t.id.equals(id))).go();
  }

  /// Delete all exam results for an exam and class
  Future<int> deleteExamResultsForExamAndClass(
    int examId,
    int classId, {
    int? sectionId,
    int? subjectId,
  }) {
    var q = delete(examResults)
      ..where((t) => t.examId.equals(examId) & t.classId.equals(classId));
    if (sectionId != null) {
      q = delete(examResults)..where(
        (t) =>
            t.examId.equals(examId) &
            t.classId.equals(classId) &
            t.sectionId.equals(sectionId),
      );
    }
    if (subjectId != null) {
      q = delete(examResults)..where(
        (t) =>
            t.examId.equals(examId) &
            t.classId.equals(classId) &
            t.subjectId.equals(subjectId),
      );
    }
    return q.go();
  }

  /// Watch reactive stream of student exam summaries
  Stream<List<StudentExamSummaryWithDetails>>
  watchExamResultSummariesWithDetails({
    required int examId,
    int? classId,
    int? sectionId,
  }) {
    final query = select(examResultSummaries).join([
      innerJoin(exams, exams.id.equalsExp(examResultSummaries.examId)),
      innerJoin(
        academicYears,
        academicYears.id.equalsExp(examResultSummaries.academicYearId),
      ),
      innerJoin(
        schoolClasses,
        schoolClasses.id.equalsExp(examResultSummaries.classId),
      ),
      leftOuterJoin(
        sections,
        sections.id.equalsExp(examResultSummaries.sectionId),
      ),
      innerJoin(students, students.id.equalsExp(examResultSummaries.studentId)),
    ])..where(examResultSummaries.examId.equals(examId));

    if (classId != null) {
      query.where(examResultSummaries.classId.equals(classId));
    }
    if (sectionId != null) {
      query.where(examResultSummaries.sectionId.equals(sectionId));
    }

    query.orderBy([
      OrderingTerm(
        expression: examResultSummaries.overallGpa,
        mode: OrderingMode.desc,
      ),
      OrderingTerm(
        expression: examResultSummaries.overallPercentage,
        mode: OrderingMode.desc,
      ),
      OrderingTerm(expression: students.rollNumber, mode: OrderingMode.asc),
    ]);

    return query.watch().map((rows) {
      return rows.map((row) {
        return StudentExamSummaryWithDetails(
          summary: row.readTable(examResultSummaries),
          exam: row.readTable(exams),
          academicYear: row.readTable(academicYears),
          schoolClass: row.readTable(schoolClasses),
          section: row.readTableOrNull(sections),
          student: row.readTable(students),
        );
      }).toList();
    });
  }

  /// Get student exam summaries with joined details
  Future<List<StudentExamSummaryWithDetails>>
  getExamResultSummariesWithDetails({
    required int examId,
    int? classId,
    int? sectionId,
  }) {
    final query = select(examResultSummaries).join([
      innerJoin(exams, exams.id.equalsExp(examResultSummaries.examId)),
      innerJoin(
        academicYears,
        academicYears.id.equalsExp(examResultSummaries.academicYearId),
      ),
      innerJoin(
        schoolClasses,
        schoolClasses.id.equalsExp(examResultSummaries.classId),
      ),
      leftOuterJoin(
        sections,
        sections.id.equalsExp(examResultSummaries.sectionId),
      ),
      innerJoin(students, students.id.equalsExp(examResultSummaries.studentId)),
    ])..where(examResultSummaries.examId.equals(examId));

    if (classId != null) {
      query.where(examResultSummaries.classId.equals(classId));
    }
    if (sectionId != null) {
      query.where(examResultSummaries.sectionId.equals(sectionId));
    }

    query.orderBy([
      OrderingTerm(
        expression: examResultSummaries.overallGpa,
        mode: OrderingMode.desc,
      ),
      OrderingTerm(
        expression: examResultSummaries.overallPercentage,
        mode: OrderingMode.desc,
      ),
      OrderingTerm(expression: students.rollNumber, mode: OrderingMode.asc),
    ]);

    return query.map((row) {
      return StudentExamSummaryWithDetails(
        summary: row.readTable(examResultSummaries),
        exam: row.readTable(exams),
        academicYear: row.readTable(academicYears),
        schoolClass: row.readTable(schoolClasses),
        section: row.readTableOrNull(sections),
        student: row.readTable(students),
      );
    }).get();
  }

  /// Batch upsert student exam summaries
  Future<void> batchUpsertExamResultSummaries(
    List<ExamResultSummariesCompanion> companions,
  ) {
    return batch((b) {
      b.insertAll(
        examResultSummaries,
        companions,
        mode: InsertMode.insertOrReplace,
      );
    });
  }

  // ==================== ATTENDANCE METHODS ====================

  /// Insert or replace a student attendance record
  Future<int> upsertStudentAttendance(StudentAttendancesCompanion companion) {
    return into(studentAttendances).insertOnConflictUpdate(companion);
  }

  /// Batch insert or replace student attendance records
  Future<void> batchUpsertStudentAttendances(
    List<StudentAttendancesCompanion> companions,
  ) {
    return batch((b) {
      b.insertAll(
        studentAttendances,
        companions,
        mode: InsertMode.insertOrReplace,
      );
    });
  }

  /// Get student attendance records for a specific class, optional section, and date
  Future<List<StudentAttendanceWithStudent>>
  getStudentAttendancesForClassAndDate({
    required int classId,
    int? sectionId,
    required DateTime date,
  }) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final nextDate = normalizedDate.add(const Duration(days: 1));

    final query = select(studentAttendances).join([
      innerJoin(students, students.id.equalsExp(studentAttendances.studentId)),
    ])..where(
      studentAttendances.classId.equals(classId) &
          studentAttendances.date.isBiggerOrEqualValue(normalizedDate) &
          studentAttendances.date.isSmallerThanValue(nextDate),
    );

    if (sectionId != null) {
      query.where(studentAttendances.sectionId.equals(sectionId));
    }

    query.orderBy([
      OrderingTerm(expression: students.rollNumber, mode: OrderingMode.asc),
      OrderingTerm(expression: students.name, mode: OrderingMode.asc),
    ]);

    return query.map((row) {
      return StudentAttendanceWithStudent(
        attendance: row.readTable(studentAttendances),
        student: row.readTable(students),
      );
    }).get();
  }

  /// Stream of student attendance for a class, section, and date
  Stream<List<StudentAttendanceWithStudent>>
  watchStudentAttendancesForClassAndDate({
    required int classId,
    int? sectionId,
    required DateTime date,
  }) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final nextDate = normalizedDate.add(const Duration(days: 1));

    final query = select(studentAttendances).join([
      innerJoin(students, students.id.equalsExp(studentAttendances.studentId)),
    ])..where(
      studentAttendances.classId.equals(classId) &
          studentAttendances.date.isBiggerOrEqualValue(normalizedDate) &
          studentAttendances.date.isSmallerThanValue(nextDate),
    );

    if (sectionId != null) {
      query.where(studentAttendances.sectionId.equals(sectionId));
    }

    query.orderBy([
      OrderingTerm(expression: students.rollNumber, mode: OrderingMode.asc),
      OrderingTerm(expression: students.name, mode: OrderingMode.asc),
    ]);

    return query.map((row) {
      return StudentAttendanceWithStudent(
        attendance: row.readTable(studentAttendances),
        student: row.readTable(students),
      );
    }).watch();
  }

  /// Get student attendances within a date range (for monthly register)
  Future<List<StudentAttendance>> getStudentAttendancesInRange({
    required int classId,
    int? sectionId,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final query = select(studentAttendances)..where(
      (t) =>
          t.classId.equals(classId) &
          t.date.isBiggerOrEqualValue(startDate) &
          t.date.isSmallerOrEqualValue(endDate),
    );
    if (sectionId != null) {
      query.where((t) => t.sectionId.equals(sectionId));
    }
    return query.get();
  }

  /// Insert or replace employee attendance record
  Future<int> upsertEmployeeAttendance(EmployeeAttendancesCompanion companion) {
    return into(employeeAttendances).insertOnConflictUpdate(companion);
  }

  /// Batch insert or replace employee attendance records
  Future<void> batchUpsertEmployeeAttendances(
    List<EmployeeAttendancesCompanion> companions,
  ) {
    return batch((b) {
      b.insertAll(
        employeeAttendances,
        companions,
        mode: InsertMode.insertOrReplace,
      );
    });
  }

  /// Get employee attendance for a specific date with optional filters
  Future<List<EmployeeAttendanceWithEmployee>> getEmployeeAttendancesForDate({
    required DateTime date,
    String? department,
    EmployeeType? employeeType,
  }) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final nextDate = normalizedDate.add(const Duration(days: 1));

    final query = select(employeeAttendances).join([
      innerJoin(
        employees,
        employees.id.equalsExp(employeeAttendances.employeeId),
      ),
    ])..where(
      employeeAttendances.date.isBiggerOrEqualValue(normalizedDate) &
          employeeAttendances.date.isSmallerThanValue(nextDate),
    );

    if (department != null && department.isNotEmpty && department != 'All') {
      query.where(employees.department.equals(department));
    }
    if (employeeType != null) {
      query.where(employees.employeeType.equals(employeeType.name));
    }

    query.orderBy([
      OrderingTerm(expression: employees.name, mode: OrderingMode.asc),
    ]);

    return query.map((row) {
      return EmployeeAttendanceWithEmployee(
        attendance: row.readTable(employeeAttendances),
        employee: row.readTable(employees),
      );
    }).get();
  }

  /// Watch employee attendance for a specific date
  Stream<List<EmployeeAttendanceWithEmployee>> watchEmployeeAttendancesForDate({
    required DateTime date,
    String? department,
    EmployeeType? employeeType,
  }) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final nextDate = normalizedDate.add(const Duration(days: 1));

    final query = select(employeeAttendances).join([
      innerJoin(
        employees,
        employees.id.equalsExp(employeeAttendances.employeeId),
      ),
    ])..where(
      employeeAttendances.date.isBiggerOrEqualValue(normalizedDate) &
          employeeAttendances.date.isSmallerThanValue(nextDate),
    );

    if (department != null && department.isNotEmpty && department != 'All') {
      query.where(employees.department.equals(department));
    }
    if (employeeType != null) {
      query.where(employees.employeeType.equals(employeeType.name));
    }

    query.orderBy([
      OrderingTerm(expression: employees.name, mode: OrderingMode.asc),
    ]);

    return query.map((row) {
      return EmployeeAttendanceWithEmployee(
        attendance: row.readTable(employeeAttendances),
        employee: row.readTable(employees),
      );
    }).watch();
  }

  /// Get employee attendances within a date range (for staff monthly register)
  Future<List<EmployeeAttendance>> getEmployeeAttendancesInRange({
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final query = select(employeeAttendances)..where(
      (t) =>
          t.date.isBiggerOrEqualValue(startDate) &
          t.date.isSmallerOrEqualValue(endDate),
    );
    return query.get();
  }
}

LazyDatabase _openConnection() => LazyDatabase(() async {
  final dbFolder = await getApplicationDocumentsDirectory();
  final file = File(p.join(dbFolder.path, 'app.db'));
  return NativeDatabase(file);
});
