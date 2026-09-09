// lib/core/database/tables/tables.dart
import 'package:drift/drift.dart';

class Schools extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get shortName => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get website => text().nullable()();
  TextColumn get logo => text().nullable()();
  TextColumn get principalName => text().nullable()();
  TextColumn get currencyCode =>
      text().withDefault(const Constant('NPR'))();
  TextColumn get currencyName =>
      text().withDefault(const Constant('Nepalese Rupee'))();
  TextColumn get currencySymbol =>
      text().withDefault(const Constant('Rs.'))();
  IntColumn get currencyDecimals =>
      integer().withDefault(const Constant(2))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class Users extends Table {
  TextColumn get id => text()();
  TextColumn get schoolId => text()();
  TextColumn get name => text()();
  TextColumn get username => text()();
  TextColumn get email => text().nullable()();
  TextColumn get passwordHash => text()();
  TextColumn get salt => text()();
  TextColumn get role => text()(); // principal, teacher, accountant, admin
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get lastLoginAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {schoolId, username},
  ];
}

class AcademicYears extends Table {
  TextColumn get id => text()();
  TextColumn get schoolId => text()();
  TextColumn get name => text()(); // e.g., '2025/26', '2026/27'
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime()();
  BoolColumn get isCurrent => boolean().withDefault(const Constant(false))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get archivedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {schoolId, name},
  ];
}

@DataClassName('SchoolClass')
class SchoolClasses extends Table {
  TextColumn get id => text()();
  TextColumn get schoolId => text()();
  TextColumn get academicYearId => text()();
  TextColumn get name => text()(); // e.g. Grade 8
  IntColumn get displayOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get archivedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {schoolId, academicYearId, name},
  ];
}

class Sections extends Table {
  TextColumn get id => text()();
  TextColumn get classId => text()();
  TextColumn get name => text()(); // e.g. Section A
  IntColumn get capacity => integer().withDefault(const Constant(40))();
  TextColumn get classTeacherId => text().nullable()();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get archivedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {classId, name},
  ];
}

class Subjects extends Table {
  TextColumn get id => text()();
  TextColumn get schoolId => text()();
  TextColumn get name => text()();
  TextColumn get code => text()();
  TextColumn get description => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get archivedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {schoolId, code},
  ];
}

class ClassSubjects extends Table {
  TextColumn get id => text()();
  TextColumn get classId => text()();
  TextColumn get subjectId => text()();
  TextColumn get teacherId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {classId, subjectId},
  ];
}

class Teachers extends Table {
  TextColumn get id => text()();
  TextColumn get schoolId => text()();
  TextColumn get userId => text().nullable()();
  TextColumn get employeeCode => text()();
  TextColumn get name => text()();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get address => text().nullable()();
  DateTimeColumn get joiningDate => dateTime().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get archivedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {schoolId, employeeCode},
  ];
}

class Students extends Table {
  TextColumn get id => text()();
  TextColumn get schoolId => text()();
  TextColumn get studentCode => text()();
  TextColumn get firstName => text()();
  TextColumn get middleName => text().nullable()();
  TextColumn get lastName => text()();
  DateTimeColumn get dateOfBirth => dateTime().nullable()();
  TextColumn get gender => text().withDefault(const Constant('Other'))();
  TextColumn get phone => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get guardianName => text().nullable()();
  TextColumn get guardianPhone => text().nullable()();
  DateTimeColumn get admissionDate => dateTime().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get archivedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {schoolId, studentCode},
  ];
}

class Enrollments extends Table {
  TextColumn get id => text()();
  TextColumn get schoolId => text()();
  TextColumn get studentId => text()();
  TextColumn get academicYearId => text()();
  TextColumn get classId => text()();
  TextColumn get sectionId => text()();
  IntColumn get rollNumber => integer().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get archivedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {academicYearId, studentId},
  ];
}

class Timetables extends Table {
  TextColumn get id => text()();
  TextColumn get schoolId => text()();
  TextColumn get academicYearId => text()();
  TextColumn get classId => text()();
  TextColumn get sectionId => text()();
  IntColumn get dayOfWeek => integer()(); // 1 = Mon .. 7 = Sun
  IntColumn get period => integer()();
  TextColumn get subjectId => text()();
  TextColumn get teacherId => text().nullable()();
  TextColumn get startTime => text()(); // '09:00'
  TextColumn get endTime => text()(); // '09:45'
  TextColumn get room => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {sectionId, dayOfWeek, period},
  ];
}

class Attendance extends Table {
  TextColumn get id => text()();
  TextColumn get schoolId => text()();
  TextColumn get academicYearId => text()();
  TextColumn get date => text()(); // YYYY-MM-DD
  TextColumn get studentId => text()();
  TextColumn get classId => text()();
  TextColumn get sectionId => text()();
  TextColumn get status => text()(); // present, absent, late, excused
  TextColumn get markedBy => text()(); // userId
  TextColumn get remarks => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {date, studentId, classId, sectionId},
  ];
}

class AuditLogs extends Table {
  TextColumn get id => text()();
  TextColumn get schoolId => text().nullable()();
  TextColumn get userId => text().nullable()();
  TextColumn get action => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text().nullable()();
  TextColumn get metadata => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {key};
}

class SyncDevices extends Table {
  TextColumn get id => text()();
  TextColumn get schoolId => text()();
  TextColumn get deviceName => text()();
  TextColumn get deviceType => text()(); // mobile, desktop, tablet, server
  TextColumn get pairingCode => text().nullable()();
  TextColumn get status =>
      text().withDefault(
        const Constant('pending_approval'),
      )(); // pending_approval, approved, revoked
  DateTimeColumn get registeredAt => dateTime()();
  DateTimeColumn get lastSeenAt => dateTime()();
  BoolColumn get isCurrentDevice =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class SyncEvents extends Table {
  TextColumn get eventId => text()();
  TextColumn get schoolId => text()();
  TextColumn get deviceId => text()();
  TextColumn get userId => text()();
  TextColumn get entityType => text()(); // attendance, etc.
  TextColumn get entityId => text()();
  TextColumn get operation => text()(); // create, update, delete
  IntColumn get version => integer().withDefault(const Constant(1))();
  TextColumn get payload => text()(); // JSON string
  IntColumn get serverSequence => integer().nullable()();
  TextColumn get status =>
      text().withDefault(
        const Constant('pending'),
      )(); // pending, sending, synced, failed
  IntColumn get attemptCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastAttemptAt => dateTime().nullable()();
  TextColumn get errorMessage => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {eventId};
}

class SyncCursors extends Table {
  TextColumn get schoolId => text()();
  TextColumn get serverId => text()();
  IntColumn get lastServerSequence =>
      integer().withDefault(const Constant(0))();
  DateTimeColumn get lastSyncedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {schoolId, serverId};
}

class SyncConflicts extends Table {
  TextColumn get id => text()();
  TextColumn get schoolId => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get localEventId => text().nullable()();
  TextColumn get remoteEventId => text().nullable()();
  TextColumn get localPayload => text()();
  TextColumn get remotePayload => text()();
  DateTimeColumn get detectedAt => dateTime()();
  DateTimeColumn get resolvedAt => dateTime().nullable()();
  TextColumn get resolutionNote => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Exams extends Table {
  TextColumn get id => text()();
  TextColumn get schoolId => text()();
  TextColumn get academicYearId => text()();
  TextColumn get name =>
      text()(); // e.g. 'First Terminal Examination', 'Final Examination 2026'
  TextColumn get description => text().nullable()();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime()();
  TextColumn get status =>
      text().withDefault(
        const Constant('draft'),
      )(); // draft, scheduled, in_progress, marks_entry, verification, published, archived
  RealColumn get weight => real().withDefault(const Constant(1.0))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get archivedAt => dateTime().nullable()();
  TextColumn get createdBy => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class ExamSubjects extends Table {
  TextColumn get id => text()();
  TextColumn get schoolId => text()();
  TextColumn get examId => text()();
  TextColumn get classId => text()();
  TextColumn get subjectId => text()();
  RealColumn get fullMarks => real()();
  RealColumn get passMarks => real()();
  RealColumn get theoryMarks => real().nullable()();
  RealColumn get practicalMarks => real().nullable()();
  RealColumn get internalMarks => real().nullable()();
  RealColumn get creditHours => real().nullable()();
  RealColumn get weight => real().withDefault(const Constant(1.0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {examId, classId, subjectId},
  ];
}

class AssessmentComponents extends Table {
  TextColumn get id => text()();
  TextColumn get examSubjectId => text()();
  TextColumn get name =>
      text()(); // e.g. 'Theory', 'Practical', 'Internal', 'Viva'
  RealColumn get maxMarks => real()();
  RealColumn get passMarks => real().nullable()();
  RealColumn get weight => real().withDefault(const Constant(1.0))();

  @override
  Set<Column> get primaryKey => {id};
}

class Marks extends Table {
  TextColumn get id => text()();
  TextColumn get schoolId => text()();
  TextColumn get examId => text()();
  TextColumn get examSubjectId => text()();
  TextColumn get studentId => text()();
  RealColumn get theoryMarks => real().nullable()();
  RealColumn get practicalMarks => real().nullable()();
  RealColumn get internalMarks => real().nullable()();
  RealColumn get totalMarks => real().nullable()();
  RealColumn get percentage => real().nullable()();
  TextColumn get grade => text().nullable()();
  RealColumn get gradePoint => real().nullable()();
  TextColumn get status =>
      text().withDefault(
        const Constant('present'),
      )(); // present, absent, medical, not_appeared, withheld, exempt
  TextColumn get remarks => text().nullable()();
  TextColumn get enteredBy => text()();
  BoolColumn get isLocked => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {examId, examSubjectId, studentId},
  ];
}

class MarksAudits extends Table {
  TextColumn get id => text()();
  TextColumn get schoolId => text()();
  TextColumn get markId => text()();
  TextColumn get studentId => text()();
  TextColumn get examId => text()();
  TextColumn get subjectId => text()();
  RealColumn get oldMarks => real().nullable()();
  RealColumn get newMarks => real().nullable()();
  TextColumn get oldStatus => text().nullable()();
  TextColumn get newStatus => text().nullable()();
  TextColumn get changedBy => text()();
  TextColumn get deviceId => text()();
  DateTimeColumn get timestamp => dateTime()();
  TextColumn get reason => text()();

  @override
  Set<Column> get primaryKey => {id};
}

class GradeSchemes extends Table {
  TextColumn get id => text()();
  TextColumn get schoolId => text()();
  TextColumn get name => text()(); // e.g. 'Standard Letter Grading (GPA 4.0)'
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  BoolColumn get enableGpa => boolean().withDefault(const Constant(true))();
  TextColumn get passingGrade => text().withDefault(const Constant('D'))();
  BoolColumn get requireAllSubjectsPass =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get enableRanking =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class GradeSchemeRules extends Table {
  TextColumn get id => text()();
  TextColumn get schemeId => text()();
  TextColumn get grade => text()(); // 'A+', 'A', 'B+', 'B', 'C+', 'C', 'D', 'F'
  RealColumn get minPercentage => real()();
  RealColumn get maxPercentage => real()();
  RealColumn get gradePoint => real().nullable()(); // 4.0, 3.6, etc.
  TextColumn get description => text().nullable()();
  BoolColumn get isPassing => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

class Results extends Table {
  TextColumn get id => text()();
  TextColumn get schoolId => text()();
  TextColumn get examId => text()();
  TextColumn get studentId => text()();
  TextColumn get classId => text()();
  TextColumn get sectionId => text()();
  RealColumn get totalMarksObtained => real()();
  RealColumn get totalFullMarks => real()();
  RealColumn get percentage => real()();
  RealColumn get gpa => real().nullable()();
  TextColumn get overallGrade => text().nullable()();
  BoolColumn get isPassed => boolean()();
  IntColumn get rank => integer().nullable()();
  DateTimeColumn get calculatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {examId, studentId},
  ];
}

class ResultPublications extends Table {
  TextColumn get id => text()();
  TextColumn get schoolId => text()();
  TextColumn get examId => text()();
  TextColumn get classId => text()();
  TextColumn get sectionId => text().nullable()();
  DateTimeColumn get publishedAt => dateTime()();
  TextColumn get publishedBy => text()();
  BoolColumn get isPublished => boolean().withDefault(const Constant(true))();
  TextColumn get status =>
      text().withDefault(
        const Constant('published'),
      )(); // published, unpublished

  @override
  Set<Column> get primaryKey => {id};
}

// ==========================================
// Phase 6: Finance & Fee Management Tables
// ==========================================

class FeeCategories extends Table {
  TextColumn get id => text()();
  TextColumn get schoolId => text()();
  TextColumn get name => text()(); // Tuition, Transport, Lab, Exam, Admission, Annual, Uniform, etc.
  TextColumn get description => text().nullable()();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class FeeStructures extends Table {
  TextColumn get id => text()();
  TextColumn get schoolId => text()();
  TextColumn get academicYearId => text()();
  TextColumn get classId => text()();
  TextColumn get sectionId => text().nullable()(); // null means applies to all sections of this class
  TextColumn get categoryId => text()();
  IntColumn get amountCents => integer()(); // Integer minor units (e.g. 150000 = Rs. 1,500.00)
  RealColumn get amount => real()(); // Kept for convenient queries
  TextColumn get frequency => text()(); // oneTime, monthly, quarterly, term, halfYearly, yearly, custom
  DateTimeColumn get dueDate => dateTime().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class FeeDiscounts extends Table {
  TextColumn get id => text()();
  TextColumn get schoolId => text()();
  TextColumn get name => text()(); // e.g. Sibling Discount, Staff Concession, Merit Scholarship
  TextColumn get type => text()(); // fixed, percentage
  RealColumn get value => real()(); // Amount in cents or percentage (e.g., 20.0 for 20%)
  TextColumn get reason => text()(); // scholarship, sibling, staffChild, needBased, earlyPayment, custom
  TextColumn get approvedBy => text().nullable()();
  TextColumn get academicYearId => text()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class StudentFeeAssignments extends Table {
  TextColumn get id => text()();
  TextColumn get schoolId => text()();
  TextColumn get studentId => text()();
  TextColumn get feeStructureId => text()();
  TextColumn get academicYearId => text()();
  IntColumn get customAmountCents => integer().nullable()(); // If overridden for this student
  TextColumn get discountId => text().nullable()(); // Linked discount
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get assignedAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class StudentFees extends Table {
  TextColumn get id => text()();
  TextColumn get schoolId => text()();
  TextColumn get studentId => text()();
  TextColumn get academicYearId => text()();
  TextColumn get classId => text()();
  TextColumn get sectionId => text()();
  TextColumn get feeStructureId => text()();
  TextColumn get categoryId => text()();
  TextColumn get feePeriod => text()(); // e.g. '2026-04' or 'Term 1' or 'One-Time'
  TextColumn get title => text()(); // e.g. 'April 2026 Tuition Fee'
  IntColumn get dueAmountCents => integer()(); // Gross fee in cents
  IntColumn get discountAmountCents => integer().withDefault(const Constant(0))();
  IntColumn get netAmountCents => integer()(); // Gross - Discount
  IntColumn get paidAmountCents => integer().withDefault(const Constant(0))();
  IntColumn get remainingAmountCents => integer()(); // Net - Paid
  DateTimeColumn get dueDate => dateTime()();
  TextColumn get status => text()(); // upcoming, due, overdue, paid, partially_paid, waived
  BoolColumn get isWaived => boolean().withDefault(const Constant(false))();
  TextColumn get waivedBy => text().nullable()();
  TextColumn get waiveReason => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class FeePayments extends Table {
  TextColumn get id => text()();
  TextColumn get schoolId => text()();
  TextColumn get receiptNumber => text()(); // Official sequential: e.g. REC-2026-000001
  TextColumn get offlineReceiptNumber => text().nullable()(); // OFFLINE-DEV1-000001
  TextColumn get studentId => text()();
  TextColumn get academicYearId => text()();
  IntColumn get amountCents => integer()(); // Total paid in cents
  RealColumn get amount => real()();
  TextColumn get paymentMethod => text()(); // cash, bankTransfer, cheque, advanceCredit, other
  TextColumn get reference => text().nullable()(); // Bank ref / cheque number
  DateTimeColumn get paymentDate => dateTime()();
  TextColumn get collectedBy => text()(); // User ID
  TextColumn get deviceId => text()(); // Device that recorded payment
  TextColumn get remarks => text().nullable()();
  BoolColumn get isAdvance => boolean().withDefault(const Constant(false))();
  BoolColumn get isReversed => boolean().withDefault(const Constant(false))();
  DateTimeColumn get reversedAt => dateTime().nullable()();
  TextColumn get reversedBy => text().nullable()();
  TextColumn get reversalReason => text().nullable()();
  BoolColumn get isReconciled => boolean().withDefault(const Constant(false))();
  TextColumn get reconciledReceiptNumber => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class FeePaymentItems extends Table {
  TextColumn get id => text()();
  TextColumn get paymentId => text()();
  TextColumn get studentFeeId => text()();
  IntColumn get amountCents => integer()(); // Portion of payment applied to this fee
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class StudentAdvances extends Table {
  TextColumn get id => text()();
  TextColumn get schoolId => text()();
  TextColumn get studentId => text()();
  IntColumn get amountCents => integer()(); // Total advance credited
  IntColumn get consumedCents => integer().withDefault(const Constant(0))(); // Consumed against dues
  IntColumn get remainingCents => integer()(); // amountCents - consumedCents
  TextColumn get paymentId => text()(); // Source payment
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class SchoolExpenses extends Table {
  TextColumn get id => text()();
  TextColumn get schoolId => text()();
  TextColumn get category => text()(); // utilities, rent, maintenance, salaries, stationery, events, transport, other
  IntColumn get amountCents => integer()();
  RealColumn get amount => real()();
  DateTimeColumn get date => dateTime()();
  TextColumn get description => text()();
  TextColumn get paymentMethod => text()(); // cash, bankTransfer, cheque, other
  TextColumn get reference => text().nullable()();
  TextColumn get recordedBy => text()();
  BoolColumn get isApproved => boolean().withDefault(const Constant(false))();
  TextColumn get approvedBy => text().nullable()();
  DateTimeColumn get approvedAt => dateTime().nullable()();
  BoolColumn get isReversed => boolean().withDefault(const Constant(false))();
  DateTimeColumn get reversedAt => dateTime().nullable()();
  TextColumn get reversedBy => text().nullable()();
  TextColumn get reversalReason => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class SchoolIncomes extends Table {
  TextColumn get id => text()();
  TextColumn get schoolId => text()();
  TextColumn get category => text()(); // donations, grants, canteen, bookStore, uniformStore, facilitiesRent, other
  IntColumn get amountCents => integer()();
  RealColumn get amount => real()();
  DateTimeColumn get date => dateTime()();
  TextColumn get description => text()();
  TextColumn get paymentMethod => text()();
  TextColumn get reference => text().nullable()();
  TextColumn get receivedBy => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class DailyClosings extends Table {
  TextColumn get id => text()();
  TextColumn get schoolId => text()();
  DateTimeColumn get closingDate => dateTime()();
  TextColumn get closedBy => text()();
  TextColumn get deviceId => text()();
  IntColumn get expectedCashCents => integer()();
  IntColumn get actualCashCents => integer()();
  IntColumn get differenceCents => integer()(); // actual - expected
  TextColumn get reason => text().nullable()(); // Required if difference != 0
  TextColumn get notes => text().nullable()();
  DateTimeColumn get closedAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

