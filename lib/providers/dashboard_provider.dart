import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../data/app_database.dart';
import '../services/attendance_service.dart';
import 'academic_year_provider.dart';
import 'database_provider.dart';

@immutable
class RecentFeePaymentItem {
  final int paymentId;
  final String receiptNumber;
  final String studentName;
  final String? studentCode;
  final double amount;
  final String paymentMethod;
  final DateTime paymentDate;

  const RecentFeePaymentItem({
    required this.paymentId,
    required this.receiptNumber,
    required this.studentName,
    this.studentCode,
    required this.amount,
    required this.paymentMethod,
    required this.paymentDate,
  });
}

@immutable
class UpcomingExamItem {
  final int examId;
  final String name;
  final String category;
  final DateTime startDate;
  final DateTime endDate;
  final String status;

  const UpcomingExamItem({
    required this.examId,
    required this.name,
    required this.category,
    required this.startDate,
    required this.endDate,
    required this.status,
  });
}

@immutable
class DashboardMetrics {
  final int totalStudents;
  final int activeStudents;
  final int maleStudents;
  final int femaleStudents;
  final int otherGenderStudents;

  final int totalEmployees;
  final int teachersCount;
  final int staffCount;

  final AttendanceSummary studentAttendanceToday;
  final AttendanceSummary employeeAttendanceToday;

  final double feeCollected;
  final double feePending;
  final double totalInvoiced;
  final double expensesTotal;

  final String activeAcademicYearName;
  final int totalClasses;
  final int totalSections;
  final int totalSubjects;

  final Map<String, int> classStudentCounts;
  final List<RecentFeePaymentItem> recentPayments;
  final List<UpcomingExamItem> upcomingExams;

  const DashboardMetrics({
    required this.totalStudents,
    required this.activeStudents,
    required this.maleStudents,
    required this.femaleStudents,
    required this.otherGenderStudents,
    required this.totalEmployees,
    required this.teachersCount,
    required this.staffCount,
    required this.studentAttendanceToday,
    required this.employeeAttendanceToday,
    required this.feeCollected,
    required this.feePending,
    required this.totalInvoiced,
    required this.expensesTotal,
    required this.activeAcademicYearName,
    required this.totalClasses,
    required this.totalSections,
    required this.totalSubjects,
    required this.classStudentCounts,
    required this.recentPayments,
    required this.upcomingExams,
  });

  factory DashboardMetrics.empty() => DashboardMetrics(
    totalStudents: 0,
    activeStudents: 0,
    maleStudents: 0,
    femaleStudents: 0,
    otherGenderStudents: 0,
    totalEmployees: 0,
    teachersCount: 0,
    staffCount: 0,
    studentAttendanceToday: AttendanceSummary.empty(),
    employeeAttendanceToday: AttendanceSummary.empty(),
    feeCollected: 0.0,
    feePending: 0.0,
    totalInvoiced: 0.0,
    expensesTotal: 0.0,
    activeAcademicYearName: 'Current Session',
    totalClasses: 0,
    totalSections: 0,
    totalSubjects: 0,
    classStudentCounts: const {},
    recentPayments: const [],
    upcomingExams: const [],
  );
}

/// Compute all aggregated metrics from database
Future<DashboardMetrics> computeDashboardMetrics(
  AppDatabase db, [
  AcademicYear? activeYear,
]) async {
  // 1. Students
  final allStudents = await db.select(db.students).get();
  final totalStudents = allStudents.length;
  final activeStudents = allStudents.where((s) => s.isActive).length;
  final maleStudents =
      allStudents.where((s) => s.gender.toLowerCase() == 'male').length;
  final femaleStudents =
      allStudents.where((s) => s.gender.toLowerCase() == 'female').length;
  final otherGenderStudents = totalStudents - maleStudents - femaleStudents;

  // 2. Employees
  final allEmployees = await db.select(db.employees).get();
  final totalEmployees = allEmployees.length;
  final teachersCount =
      allEmployees.where((e) => e.employeeType == EmployeeType.teacher).length;
  final staffCount =
      allEmployees.where((e) => e.employeeType == EmployeeType.staff).length;

  // 3. Classes, Sections, Subjects
  final classes = await db.select(db.schoolClasses).get();
  final sections = await db.select(db.sections).get();
  final subjects = await db.select(db.subjects).get();
  final totalClasses = classes.length;
  final totalSections = sections.length;
  final totalSubjects = subjects.length;

  // 4. Class-wise enrollment
  final Map<String, int> classCounts = {};
  for (final c in classes) {
    classCounts[c.displayName.isNotEmpty ? c.displayName : c.name] = 0;
  }
  final activeHistories =
      await (db.select(db.studentAcademicHistories)
        ..where((tbl) => tbl.status.equals(AcademicStatus.active.name))).get();

  for (final h in activeHistories) {
    final matchClass = classes.firstWhere(
      (c) => c.id == h.classId,
      orElse:
          () => SchoolClass(
            id: 0,
            name: '',
            displayName: '',
            orderIndex: 0,
            createdAt: DateTime.now(),
          ),
    );
    if (matchClass.id != 0) {
      final key =
          matchClass.displayName.isNotEmpty
              ? matchClass.displayName
              : matchClass.name;
      classCounts[key] = (classCounts[key] ?? 0) + 1;
    }
  }

  // 5. Today's Attendance
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  // Student Attendance Today
  final studentAtts =
      await (db.select(db.studentAttendances)
        ..where((tbl) => tbl.date.equals(today))).get();
  final sTotal = studentAtts.length;
  final sPresent =
      studentAtts.where((a) => a.status == AttendanceStatus.present).length;
  final sAbsent =
      studentAtts.where((a) => a.status == AttendanceStatus.absent).length;
  final sLate =
      studentAtts.where((a) => a.status == AttendanceStatus.late).length;
  final sHalfDay =
      studentAtts.where((a) => a.status == AttendanceStatus.halfDay).length;
  final sExcused =
      studentAtts
          .where(
            (a) =>
                a.status == AttendanceStatus.onLeave ||
                a.status == AttendanceStatus.excused,
          )
          .length;
  final sPct = sTotal > 0 ? (sPresent / sTotal) * 100.0 : 0.0;

  final studentAttendanceToday = AttendanceSummary(
    total: sTotal > 0 ? sTotal : totalStudents,
    present: sPresent,
    absent: sAbsent,
    late: sLate,
    halfDay: sHalfDay,
    excusedOrLeave: sExcused,
    percentage: sPct,
  );

  // Staff Attendance Today
  final staffAtts =
      await (db.select(db.employeeAttendances)
        ..where((tbl) => tbl.date.equals(today))).get();
  final eTotal = staffAtts.length;
  final ePresent =
      staffAtts.where((a) => a.status == AttendanceStatus.present).length;
  final eAbsent =
      staffAtts.where((a) => a.status == AttendanceStatus.absent).length;
  final eLate =
      staffAtts.where((a) => a.status == AttendanceStatus.late).length;
  final eHalfDay =
      staffAtts.where((a) => a.status == AttendanceStatus.halfDay).length;
  final eExcused =
      staffAtts
          .where(
            (a) =>
                a.status == AttendanceStatus.onLeave ||
                a.status == AttendanceStatus.excused,
          )
          .length;
  final ePct = eTotal > 0 ? (ePresent / eTotal) * 100.0 : 0.0;

  final employeeAttendanceToday = AttendanceSummary(
    total: eTotal > 0 ? eTotal : totalEmployees,
    present: ePresent,
    absent: eAbsent,
    late: eLate,
    halfDay: eHalfDay,
    excusedOrLeave: eExcused,
    percentage: ePct,
  );

  // 6. Financials: Fees & Expenses
  final allPayments = await db.select(db.feePayments).get();
  final double feeCollected = allPayments.fold(
    0.0,
    (sum, p) => sum + p.amount,
  );

  final allFees = await db.select(db.studentFees).get();
  final double totalInvoiced = allFees.fold(
    0.0,
    (sum, f) => sum + (f.totalAmount - f.discountAmount),
  );
  final double feePending =
      (totalInvoiced - feeCollected > 0) ? (totalInvoiced - feeCollected) : 0.0;

  final allExpenses = await db.select(db.expenses).get();
  final double expensesTotal = allExpenses.fold(
    0.0,
    (sum, e) => sum + e.amount,
  );

  // Recent Fee Payments (latest 6)
  allPayments.sort((a, b) => b.paymentDate.compareTo(a.paymentDate));
  final recentPaymentsRaw = allPayments.take(6).toList();

  final List<RecentFeePaymentItem> recentPayments = [];
  for (final p in recentPaymentsRaw) {
    final student = allStudents.firstWhere(
      (s) => s.id == p.studentId,
      orElse:
          () => Student(
            id: p.studentId,
            studentId: 'STU-${p.studentId}',
            admissionNumber: 'ADM-${p.studentId}',
            admissionDate: DateTime.now(),
            name: 'Student #${p.studentId}',
            gender: 'Other',
            hasTransport: false,
            hasHostel: false,
            hasLibrary: false,
            isActive: true,
            createdAt: DateTime.now(),
          ),
    );
    recentPayments.add(
      RecentFeePaymentItem(
        paymentId: p.id,
        receiptNumber: p.receiptNumber,
        studentName: student.name,
        studentCode: student.admissionNumber,
        amount: p.amount,
        paymentMethod: p.paymentMethod,
        paymentDate: p.paymentDate,
      ),
    );
  }

  // 7. Upcoming Exams
  final allExams = await db.select(db.exams).get();
  allExams.sort((a, b) => a.startDate.compareTo(b.startDate));
  final upcomingExams =
      allExams.take(4).map((e) {
        return UpcomingExamItem(
          examId: e.id,
          name: e.name,
          category: e.category,
          startDate: e.startDate,
          endDate: e.endDate,
          status: e.status,
        );
      }).toList();

  return DashboardMetrics(
    totalStudents: totalStudents,
    activeStudents: activeStudents,
    maleStudents: maleStudents,
    femaleStudents: femaleStudents,
    otherGenderStudents: otherGenderStudents,
    totalEmployees: totalEmployees,
    teachersCount: teachersCount,
    staffCount: staffCount,
    studentAttendanceToday: studentAttendanceToday,
    employeeAttendanceToday: employeeAttendanceToday,
    feeCollected: feeCollected,
    feePending: feePending,
    totalInvoiced: totalInvoiced,
    expensesTotal: expensesTotal,
    activeAcademicYearName: activeYear?.name ?? 'Academic Year 2026-2027',
    totalClasses: totalClasses,
    totalSections: totalSections,
    totalSubjects: totalSubjects,
    classStudentCounts: classCounts,
    recentPayments: recentPayments,
    upcomingExams: upcomingExams,
  );
}

/// Reactive StreamProvider delivering up-to-date Dashboard metrics
final dashboardMetricsStreamProvider = StreamProvider<DashboardMetrics>((
  ref,
) async* {
  final db = ref.watch(databaseProvider);
  final activeYear = ref.watch(activeAcademicYearProvider).value;

  // Emit initial metrics
  yield await computeDashboardMetrics(db, activeYear);

  // Watch for mutations across core tables
  final controller = StreamController<void>();
  final s1 = db.select(db.students).watch().listen((_) => controller.add(null));
  final s2 = db.select(db.employees).watch().listen((_) => controller.add(null));
  final s3 = db.select(db.feePayments).watch().listen((_) => controller.add(null));
  final s4 = db.select(db.expenses).watch().listen((_) => controller.add(null));
  final s5 =
      db.select(db.studentAttendances).watch().listen((_) => controller.add(null));
  final s6 =
      db.select(db.employeeAttendances).watch().listen((_) => controller.add(null));

  ref.onDispose(() {
    s1.cancel();
    s2.cancel();
    s3.cancel();
    s4.cancel();
    s5.cancel();
    s6.cancel();
    controller.close();
  });

  await for (final _ in controller.stream) {
    yield await computeDashboardMetrics(db, activeYear);
  }
});
