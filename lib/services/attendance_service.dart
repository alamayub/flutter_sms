import 'package:drift/drift.dart';
import '../config/enums.dart';
import '../data/app_database.dart';

/// Summary statistics for daily or monthly attendance
class AttendanceSummary {
  final int total;
  final int present;
  final int absent;
  final int late;
  final int halfDay;
  final int excusedOrLeave;
  final double percentage;

  const AttendanceSummary({
    required this.total,
    required this.present,
    required this.absent,
    required this.late,
    required this.halfDay,
    required this.excusedOrLeave,
    required this.percentage,
  });

  factory AttendanceSummary.empty() => const AttendanceSummary(
    total: 0,
    present: 0,
    absent: 0,
    late: 0,
    halfDay: 0,
    excusedOrLeave: 0,
    percentage: 0.0,
  );
}

/// Editable item for a student on a specific date
class StudentAttendanceRecordItem {
  final Student student;
  final StudentAttendance? attendance;
  AttendanceStatus status;
  String? remarks;

  StudentAttendanceRecordItem({
    required this.student,
    this.attendance,
    required this.status,
    this.remarks,
  });

  StudentAttendanceRecordItem copyWith({
    AttendanceStatus? status,
    String? remarks,
  }) {
    return StudentAttendanceRecordItem(
      student: student,
      attendance: attendance,
      status: status ?? this.status,
      remarks: remarks ?? this.remarks,
    );
  }
}

/// Editable item for a staff member on a specific date
class StaffAttendanceRecordItem {
  final Employee employee;
  final EmployeeAttendance? attendance;
  AttendanceStatus status;
  String? checkInTime;
  String? checkOutTime;
  String? remarks;

  StaffAttendanceRecordItem({
    required this.employee,
    this.attendance,
    required this.status,
    this.checkInTime,
    this.checkOutTime,
    this.remarks,
  });

  StaffAttendanceRecordItem copyWith({
    AttendanceStatus? status,
    String? checkInTime,
    String? checkOutTime,
    String? remarks,
  }) {
    return StaffAttendanceRecordItem(
      employee: employee,
      attendance: attendance,
      status: status ?? this.status,
      checkInTime: checkInTime ?? this.checkInTime,
      checkOutTime: checkOutTime ?? this.checkOutTime,
      remarks: remarks ?? this.remarks,
    );
  }
}

/// Student row representation in a monthly register matrix
class StudentMonthlyRegisterRow {
  final Student student;
  final Map<int, AttendanceStatus?> dayStatusMap;
  final int totalWorkingDays;
  final int presentDays;
  final int absentDays;
  final int lateDays;
  final int halfDays;
  final int excusedDays;
  final double attendancePercentage;

  const StudentMonthlyRegisterRow({
    required this.student,
    required this.dayStatusMap,
    required this.totalWorkingDays,
    required this.presentDays,
    required this.absentDays,
    required this.lateDays,
    required this.halfDays,
    required this.excusedDays,
    required this.attendancePercentage,
  });
}

/// Staff row representation in a monthly register matrix
class StaffMonthlyRegisterRow {
  final Employee employee;
  final Map<int, AttendanceStatus?> dayStatusMap;
  final int totalWorkingDays;
  final int presentDays;
  final int absentDays;
  final int lateDays;
  final int halfDays;
  final int leaveDays;
  final double attendancePercentage;

  const StaffMonthlyRegisterRow({
    required this.employee,
    required this.dayStatusMap,
    required this.totalWorkingDays,
    required this.presentDays,
    required this.absentDays,
    required this.lateDays,
    required this.halfDays,
    required this.leaveDays,
    required this.attendancePercentage,
  });
}

/// Service providing business logic for student and staff attendance
class AttendanceService {
  final AppDatabase _db;

  AttendanceService(this._db);

  // ==================== STUDENT ATTENDANCE ====================

  /// Normalize date to midnight (00:00:00)
  static DateTime normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  /// Fetch active students for a class and section, paired with attendance on the given date
  Future<List<StudentAttendanceRecordItem>> getStudentsWithAttendanceForDate({
    required int classId,
    int? sectionId,
    required DateTime date,
  }) async {
    final normalized = normalizeDate(date);

    // 1. Fetch active students in class & section
    final allStudents = await _db.getAllStudents();
    final classStudents =
        allStudents.where((s) {
          if (!s.isActive || s.classId != classId) return false;
          if (sectionId != null && s.sectionId != sectionId) return false;
          return true;
        }).toList();

    // Sort by roll number, then name
    classStudents.sort((a, b) {
      final rollA = a.rollNumber ?? 999999;
      final rollB = b.rollNumber ?? 999999;
      final cmp = rollA.compareTo(rollB);
      if (cmp != 0) return cmp;
      return a.name.compareTo(b.name);
    });

    // 2. Fetch recorded attendances on date
    final existingRecords = await _db.getStudentAttendancesForClassAndDate(
      classId: classId,
      sectionId: sectionId,
      date: normalized,
    );
    final recordMap = {
      for (final r in existingRecords) r.attendance.studentId: r.attendance,
    };

    // 3. Merge: if not recorded yet, default to present
    return classStudents.map((student) {
      final record = recordMap[student.id];
      return StudentAttendanceRecordItem(
        student: student,
        attendance: record,
        status: record?.status ?? AttendanceStatus.present,
        remarks: record?.remarks,
      );
    }).toList();
  }

  /// Save or update a batch of student attendance records
  Future<void> saveStudentAttendanceBatch({
    required int academicYearId,
    required int classId,
    int? sectionId,
    required DateTime date,
    required List<StudentAttendanceRecordItem> records,
  }) async {
    final normalized = normalizeDate(date);
    final now = DateTime.now();

    final companions =
        records.map((item) {
          return StudentAttendancesCompanion(
            id:
                item.attendance != null
                    ? Value(item.attendance!.id)
                    : const Value.absent(),
            studentId: Value(item.student.id),
            academicYearId: Value(academicYearId),
            classId: Value(classId),
            sectionId: Value(sectionId ?? item.student.sectionId),
            date: Value(normalized),
            status: Value(item.status),
            remarks: Value(item.remarks),
            createdAt: Value(item.attendance?.createdAt ?? now),
          );
        }).toList();

    await _db.batchUpsertStudentAttendances(companions);
  }

  /// Calculate summary statistics for student attendance on a specific date
  AttendanceSummary calculateStudentSummary(
    List<StudentAttendanceRecordItem> items,
  ) {
    if (items.isEmpty) return AttendanceSummary.empty();

    int present = 0;
    int absent = 0;
    int late = 0;
    int halfDay = 0;
    int excused = 0;

    for (final item in items) {
      switch (item.status) {
        case AttendanceStatus.present:
          present++;
          break;
        case AttendanceStatus.absent:
          absent++;
          break;
        case AttendanceStatus.late:
          late++;
          break;
        case AttendanceStatus.halfDay:
          halfDay++;
          break;
        case AttendanceStatus.excused:
        case AttendanceStatus.onLeave:
          excused++;
          break;
      }
    }

    final total = items.length;
    // Late and present count as attended; half-day counts as 0.5
    final effectiveAttended = present + late + (halfDay * 0.5);
    final percentage = total > 0 ? (effectiveAttended / total * 100) : 0.0;

    return AttendanceSummary(
      total: total,
      present: present,
      absent: absent,
      late: late,
      halfDay: halfDay,
      excusedOrLeave: excused,
      percentage: double.parse(percentage.toStringAsFixed(1)),
    );
  }

  /// Get student monthly attendance register
  Future<List<StudentMonthlyRegisterRow>> getStudentMonthlyRegister({
    required int classId,
    int? sectionId,
    required int year,
    required int month,
  }) async {
    final allStudents = await _db.getAllStudents();
    final classStudents =
        allStudents.where((s) {
          if (!s.isActive || s.classId != classId) return false;
          if (sectionId != null && s.sectionId != sectionId) return false;
          return true;
        }).toList();

    classStudents.sort((a, b) {
      final rollA = a.rollNumber ?? 999999;
      final rollB = b.rollNumber ?? 999999;
      final cmp = rollA.compareTo(rollB);
      if (cmp != 0) return cmp;
      return a.name.compareTo(b.name);
    });

    final startDate = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final endDate = DateTime(year, month, daysInMonth, 23, 59, 59);

    final attendances = await _db.getStudentAttendancesInRange(
      classId: classId,
      sectionId: sectionId,
      startDate: startDate,
      endDate: endDate,
    );

    // Group attendances by studentId -> day -> status
    final studentDayMap = <int, Map<int, AttendanceStatus>>{};
    for (final att in attendances) {
      final day = att.date.day;
      studentDayMap.putIfAbsent(att.studentId, () => {})[day] = att.status;
    }

    return classStudents.map((student) {
      final dayMap = studentDayMap[student.id] ?? {};
      final fullDayMap = <int, AttendanceStatus?>{};
      int present = 0;
      int absent = 0;
      int late = 0;
      int halfDay = 0;
      int excused = 0;

      for (int d = 1; d <= daysInMonth; d++) {
        final status = dayMap[d];
        fullDayMap[d] = status;
        if (status != null) {
          switch (status) {
            case AttendanceStatus.present:
              present++;
              break;
            case AttendanceStatus.absent:
              absent++;
              break;
            case AttendanceStatus.late:
              late++;
              break;
            case AttendanceStatus.halfDay:
              halfDay++;
              break;
            case AttendanceStatus.excused:
            case AttendanceStatus.onLeave:
              excused++;
              break;
          }
        }
      }

      final recordedDays = present + absent + late + halfDay + excused;
      final effectiveAttended = present + late + (halfDay * 0.5);
      final percentage =
          recordedDays > 0 ? (effectiveAttended / recordedDays * 100) : 0.0;

      return StudentMonthlyRegisterRow(
        student: student,
        dayStatusMap: fullDayMap,
        totalWorkingDays: recordedDays,
        presentDays: present,
        absentDays: absent,
        lateDays: late,
        halfDays: halfDay,
        excusedDays: excused,
        attendancePercentage: double.parse(percentage.toStringAsFixed(1)),
      );
    }).toList();
  }

  // ==================== STAFF ATTENDANCE ====================

  /// Fetch active staff/teachers paired with attendance on the given date
  Future<List<StaffAttendanceRecordItem>> getStaffWithAttendanceForDate({
    required DateTime date,
    String? department,
    EmployeeType? employeeType,
  }) async {
    final normalized = normalizeDate(date);
    final allEmployees = await _db.getAllEmployees();

    final filteredEmployees =
        allEmployees.where((e) {
          if (!e.isActive) return false;
          if (department != null &&
              department.isNotEmpty &&
              department != 'All' &&
              e.department != department) {
            return false;
          }
          if (employeeType != null && e.employeeType != employeeType) {
            return false;
          }
          return true;
        }).toList();

    filteredEmployees.sort((a, b) => a.name.compareTo(b.name));

    final existingRecords = await _db.getEmployeeAttendancesForDate(
      date: normalized,
      department: department,
      employeeType: employeeType,
    );
    final recordMap = {
      for (final r in existingRecords) r.attendance.employeeId: r.attendance,
    };

    return filteredEmployees.map((emp) {
      final record = recordMap[emp.id];
      return StaffAttendanceRecordItem(
        employee: emp,
        attendance: record,
        status: record?.status ?? AttendanceStatus.present,
        checkInTime:
            record?.checkInTime ?? (record == null ? '09:00 AM' : null),
        checkOutTime:
            record?.checkOutTime ?? (record == null ? '04:30 PM' : null),
        remarks: record?.remarks,
      );
    }).toList();
  }

  /// Save or update a batch of staff attendance records
  Future<void> saveStaffAttendanceBatch({
    required DateTime date,
    required List<StaffAttendanceRecordItem> records,
  }) async {
    final normalized = normalizeDate(date);
    final now = DateTime.now();

    final companions =
        records.map((item) {
          return EmployeeAttendancesCompanion(
            id:
                item.attendance != null
                    ? Value(item.attendance!.id)
                    : const Value.absent(),
            employeeId: Value(item.employee.id),
            date: Value(normalized),
            status: Value(item.status),
            checkInTime: Value(item.checkInTime),
            checkOutTime: Value(item.checkOutTime),
            remarks: Value(item.remarks),
            createdAt: Value(item.attendance?.createdAt ?? now),
          );
        }).toList();

    await _db.batchUpsertEmployeeAttendances(companions);
  }

  /// Calculate summary statistics for staff attendance on a specific date
  AttendanceSummary calculateStaffSummary(
    List<StaffAttendanceRecordItem> items,
  ) {
    if (items.isEmpty) return AttendanceSummary.empty();

    int present = 0;
    int absent = 0;
    int late = 0;
    int halfDay = 0;
    int onLeave = 0;

    for (final item in items) {
      switch (item.status) {
        case AttendanceStatus.present:
          present++;
          break;
        case AttendanceStatus.absent:
          absent++;
          break;
        case AttendanceStatus.late:
          late++;
          break;
        case AttendanceStatus.halfDay:
          halfDay++;
          break;
        case AttendanceStatus.onLeave:
        case AttendanceStatus.excused:
          onLeave++;
          break;
      }
    }

    final total = items.length;
    final effectiveAttended = present + late + (halfDay * 0.5);
    final percentage = total > 0 ? (effectiveAttended / total * 100) : 0.0;

    return AttendanceSummary(
      total: total,
      present: present,
      absent: absent,
      late: late,
      halfDay: halfDay,
      excusedOrLeave: onLeave,
      percentage: double.parse(percentage.toStringAsFixed(1)),
    );
  }

  /// Get staff monthly attendance register
  Future<List<StaffMonthlyRegisterRow>> getStaffMonthlyRegister({
    required int year,
    required int month,
    String? department,
  }) async {
    final allEmployees = await _db.getAllEmployees();
    final filteredEmployees =
        allEmployees.where((e) {
          if (!e.isActive) return false;
          if (department != null &&
              department.isNotEmpty &&
              department != 'All' &&
              e.department != department) {
            return false;
          }
          return true;
        }).toList();

    filteredEmployees.sort((a, b) => a.name.compareTo(b.name));

    final startDate = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final endDate = DateTime(year, month, daysInMonth, 23, 59, 59);

    final attendances = await _db.getEmployeeAttendancesInRange(
      startDate: startDate,
      endDate: endDate,
    );

    final empDayMap = <int, Map<int, AttendanceStatus>>{};
    for (final att in attendances) {
      final day = att.date.day;
      empDayMap.putIfAbsent(att.employeeId, () => {})[day] = att.status;
    }

    return filteredEmployees.map((emp) {
      final dayMap = empDayMap[emp.id] ?? {};
      final fullDayMap = <int, AttendanceStatus?>{};
      int present = 0;
      int absent = 0;
      int late = 0;
      int halfDay = 0;
      int leave = 0;

      for (int d = 1; d <= daysInMonth; d++) {
        final status = dayMap[d];
        fullDayMap[d] = status;
        if (status != null) {
          switch (status) {
            case AttendanceStatus.present:
              present++;
              break;
            case AttendanceStatus.absent:
              absent++;
              break;
            case AttendanceStatus.late:
              late++;
              break;
            case AttendanceStatus.halfDay:
              halfDay++;
              break;
            case AttendanceStatus.onLeave:
            case AttendanceStatus.excused:
              leave++;
              break;
          }
        }
      }

      final recordedDays = present + absent + late + halfDay + leave;
      final effectiveAttended = present + late + (halfDay * 0.5);
      final percentage =
          recordedDays > 0 ? (effectiveAttended / recordedDays * 100) : 0.0;

      return StaffMonthlyRegisterRow(
        employee: emp,
        dayStatusMap: fullDayMap,
        totalWorkingDays: recordedDays,
        presentDays: present,
        absentDays: absent,
        lateDays: late,
        halfDays: halfDay,
        leaveDays: leave,
        attendancePercentage: double.parse(percentage.toStringAsFixed(1)),
      );
    }).toList();
  }
}
