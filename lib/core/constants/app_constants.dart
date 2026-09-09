// lib/core/constants/app_constants.dart

class UserRole {
  static const String principal = 'principal';
  static const String admin = 'admin';
  static const String teacher = 'teacher';
  static const String accountant = 'accountant';

  static const List<String> all = [principal, admin, teacher, accountant];

  static bool isPrincipalOrAdmin(String role) =>
      role == principal || role == admin;
}

class AttendanceStatus {
  static const String present = 'present';
  static const String absent = 'absent';
  static const String late = 'late';
  static const String excused = 'excused';

  static const List<String> all = [present, absent, late, excused];
}

class DayOfWeek {
  static const int monday = 1;
  static const int tuesday = 2;
  static const int wednesday = 3;
  static const int thursday = 4;
  static const int friday = 5;
  static const int saturday = 6;
  static const int sunday = 7;

  static String getName(int day) {
    switch (day) {
      case monday:
        return 'Monday';
      case tuesday:
        return 'Tuesday';
      case wednesday:
        return 'Wednesday';
      case thursday:
        return 'Thursday';
      case friday:
        return 'Friday';
      case saturday:
        return 'Saturday';
      case sunday:
        return 'Sunday';
      default:
        return 'Unknown';
    }
  }

  static const List<int> schoolDays = [
    monday,
    tuesday,
    wednesday,
    thursday,
    friday,
    saturday,
  ];
}

class AuditAction {
  static const String login = 'LOGIN';
  static const String logout = 'LOGOUT';
  static const String schoolCreated = 'SCHOOL_CREATED';
  static const String schoolUpdated = 'SCHOOL_UPDATED';
  static const String academicYearCreated = 'ACADEMIC_YEAR_CREATED';
  static const String academicYearUpdated = 'ACADEMIC_YEAR_UPDATED';
  static const String academicYearArchived = 'ACADEMIC_YEAR_ARCHIVED';
  static const String classCreated = 'CLASS_CREATED';
  static const String classUpdated = 'CLASS_UPDATED';
  static const String classArchived = 'CLASS_ARCHIVED';
  static const String sectionCreated = 'SECTION_CREATED';
  static const String sectionUpdated = 'SECTION_UPDATED';
  static const String sectionArchived = 'SECTION_ARCHIVED';
  static const String subjectCreated = 'SUBJECT_CREATED';
  static const String subjectUpdated = 'SUBJECT_UPDATED';
  static const String subjectArchived = 'SUBJECT_ARCHIVED';
  static const String teacherCreated = 'TEACHER_CREATED';
  static const String teacherUpdated = 'TEACHER_UPDATED';
  static const String teacherArchived = 'TEACHER_ARCHIVED';
  static const String studentCreated = 'STUDENT_CREATED';
  static const String studentUpdated = 'STUDENT_UPDATED';
  static const String studentEnrolled = 'STUDENT_ENROLLED';
  static const String studentArchived = 'STUDENT_ARCHIVED';
  static const String studentRestored = 'STUDENT_RESTORED';
  static const String attendanceMarked = 'ATTENDANCE_MARKED';
  static const String timetableCreated = 'TIMETABLE_CREATED';
  static const String timetableUpdated = 'TIMETABLE_UPDATED';
  static const String timetableDeleted = 'TIMETABLE_DELETED';
  static const String databaseExported = 'DATABASE_EXPORTED';
  static const String databaseImported = 'DATABASE_IMPORTED';
  static const String demoDataSeeded = 'DEMO_DATA_SEEDED';
  static const String deviceRegistered = 'DEVICE_REGISTERED';
  static const String deviceApproved = 'DEVICE_APPROVED';
  static const String deviceRevoked = 'DEVICE_REVOKED';
  static const String syncEventSent = 'SYNC_EVENT_SENT';
  static const String syncEventReceived = 'SYNC_EVENT_RECEIVED';
  static const String syncEventFailed = 'SYNC_EVENT_FAILED';
  static const String syncConflictDetected = 'SYNC_CONFLICT_DETECTED';
  static const String feeCategoryCreated = 'FEE_CATEGORY_CREATED';
  static const String feeStructureCreated = 'FEE_STRUCTURE_CREATED';
  static const String feeDiscountCreated = 'FEE_DISCOUNT_CREATED';
  static const String studentFeesGenerated = 'STUDENT_FEES_GENERATED';
  static const String feePaymentCollected = 'FEE_PAYMENT_COLLECTED';
  static const String feePaymentReversed = 'FEE_PAYMENT_REVERSED';
  static const String feeReceiptReprinted = 'FEE_RECEIPT_REPRINTED';
  static const String feeWaived = 'FEE_WAIVED';
  static const String expenseRecorded = 'EXPENSE_RECORDED';
  static const String expenseApproved = 'EXPENSE_APPROVED';
  static const String expenseReversed = 'EXPENSE_REVERSED';
  static const String incomeRecorded = 'INCOME_RECORDED';
  static const String dailyClosingCompleted = 'DAILY_CLOSING_COMPLETED';
}

class DeviceStatus {
  static const String pendingApproval = 'pending_approval';
  static const String approved = 'approved';
  static const String revoked = 'revoked';
}

class SyncEventStatus {
  static const String pending = 'pending';
  static const String sending = 'sending';
  static const String synced = 'synced';
  static const String failed = 'failed';
}

class SyncOperation {
  static const String create = 'create';
  static const String update = 'update';
  static const String delete = 'delete';
}

class SyncEntityType {
  static const String school = 'school';
  static const String academicYear = 'academic_year';
  static const String schoolClass = 'school_class';
  static const String section = 'section';
  static const String subject = 'subject';
  static const String teacher = 'teacher';
  static const String student = 'student';
  static const String enrollment = 'enrollment';
  static const String timetable = 'timetable';
  static const String attendance = 'attendance';
  static const String exam = 'exam';
  static const String examSubject = 'exam_subject';
  static const String assessmentComponent = 'assessment_component';
  static const String marks = 'marks';
  static const String gradeScheme = 'grade_scheme';
  static const String result = 'result';
  static const String resultPublication = 'result_publication';
  static const String feeCategory = 'fee_category';
  static const String feeStructure = 'fee_structure';
  static const String feeDiscount = 'fee_discount';
  static const String studentFeeAssignment = 'student_fee_assignment';
  static const String studentFee = 'student_fee';
  static const String feePayment = 'fee_payment';
  static const String feePaymentItem = 'fee_payment_item';
  static const String studentAdvance = 'student_advance';
  static const String schoolExpense = 'school_expense';
  static const String schoolIncome = 'school_income';
  static const String dailyClosing = 'daily_closing';

  static const List<String> all = [
    school,
    academicYear,
    schoolClass,
    section,
    subject,
    teacher,
    student,
    enrollment,
    timetable,
    attendance,
    exam,
    examSubject,
    assessmentComponent,
    marks,
    gradeScheme,
    result,
    resultPublication,
    feeCategory,
    feeStructure,
    feeDiscount,
    studentFeeAssignment,
    studentFee,
    feePayment,
    feePaymentItem,
    studentAdvance,
    schoolExpense,
    schoolIncome,
    dailyClosing,
  ];
}

class SyncConflictStatus {
  static const String pending = 'pending';
  static const String resolved = 'resolved';
  static const String ignored = 'ignored';
}

class ConflictResolutionType {
  static const String keepLocal = 'keep_local';
  static const String keepRemote = 'keep_remote';
  static const String merged = 'merged';
}
