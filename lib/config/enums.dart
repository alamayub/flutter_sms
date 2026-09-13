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

enum EmployeeType { teacher, staff }

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

enum MessageType { neutral, error, success, warning }