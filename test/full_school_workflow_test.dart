import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sms/data/app_database.dart';
import 'package:sms/models/school_profile.dart';
import 'package:sms/services/academic_year_service.dart';
import 'package:sms/services/attendance_service.dart';
import 'package:sms/services/certificate_service.dart';
import 'package:sms/services/class_section_service.dart';
import 'package:sms/services/employee_service.dart';
import 'package:sms/services/exam_result_service.dart';
import 'package:sms/services/exam_service.dart';
import 'package:sms/services/fee_service.dart';
import 'package:sms/services/payroll_service.dart';
import 'package:sms/services/student_service.dart';
import 'package:sms/services/subject_service.dart';
import 'package:sms/services/timetable_service.dart';

void main() {
  late AppDatabase db;
  late AcademicYearService academicYearService;
  late ClassSectionService classSectionService;
  late SubjectService subjectService;
  late EmployeeService employeeService;
  late StudentService studentService;
  late AttendanceService attendanceService;
  late FeeService feeService;
  late PayrollService payrollService;
  late ExamService examService;
  late ExamResultService examResultService;
  late TimetableService timetableService;
  late CertificateService certificateService;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    academicYearService = AcademicYearService(db);
    classSectionService = ClassSectionService(db);
    subjectService = SubjectService(db);
    employeeService = EmployeeService(db);
    studentService = StudentService(db);
    attendanceService = AttendanceService(db);
    feeService = FeeService(db);
    payrollService = PayrollService(db);
    examService = ExamService(db);
    examResultService = ExamResultService(db);
    timetableService = TimetableService(db);
    certificateService = CertificateService(db);

    // Clean initial tables for isolated, deterministic testing
    await db.customStatement('DELETE FROM certificates;');
    await db.customStatement('DELETE FROM exam_result_summaries;');
    await db.customStatement('DELETE FROM exam_results;');
    await db.customStatement('DELETE FROM exam_schedules;');
    await db.customStatement('DELETE FROM exams;');
    await db.customStatement('DELETE FROM period_entries;');
    await db.customStatement('DELETE FROM fee_payments;');
    await db.customStatement('DELETE FROM student_fees;');
    await db.customStatement('DELETE FROM fee_categories;');
    await db.customStatement('DELETE FROM salary_advance_adjustments;');
    await db.customStatement('DELETE FROM salary_payments;');
    await db.customStatement('DELETE FROM salary_advances;');
    await db.customStatement('DELETE FROM employee_attendances;');
    await db.customStatement('DELETE FROM student_attendances;');
    await db.customStatement('DELETE FROM contacts;');
    await db.customStatement('DELETE FROM student_academic_histories;');
    await db.customStatement('DELETE FROM students;');
    await db.customStatement('DELETE FROM employees;');
    await db.customStatement('DELETE FROM subjects;');
    await db.customStatement('DELETE FROM sections;');
    await db.customStatement('DELETE FROM school_classes;');
    await db.customStatement('DELETE FROM academic_years;');
  });

  tearDown(() async {
    await db.close();
  });

  group('Full End-to-End School Management Operational Lifecycle', () {
    test(
      'Executes complete operational flow: Account -> Year -> Class -> Student -> Attendance -> Fee -> Payroll -> Exam -> Timetable -> Certificate -> Promotion',
      () async {
        // =====================================================================
        // PHASE 1: School Profile & Dual-Auth Registration
        // =====================================================================
        final schoolProfile = SchoolProfile(
          name: 'Pragyan Model Higher Secondary School',
          code: 'PRAG-2026',
          address: 'Baneshwor, Kathmandu, Nepal',
          phone: '+977-1-4498877',
          email: 'info@pragyan.edu.np',
          website: 'www.pragyan.edu.np',
          principalName: 'Dr. B. K. Shrestha',
          establishedYear: '2055 BS (1998 AD)',
          tagline: 'Knowledge, Character, Excellence',
          adminUsername: 'superadmin',
          adminPasswordHash: SchoolProfile.hashPassword('SuperSecret2026!'),
          adminPinHash: SchoolProfile.hashPassword('8899'),
          isRegistered: true,
          registeredAt: DateTime(2026, 1, 1),
        );

        // Verify password verification
        expect(schoolProfile.verifyPassword('SuperSecret2026!'), isTrue);
        expect(schoolProfile.verifyPassword('WrongPass'), isFalse);

        // Verify PIN verification
        expect(schoolProfile.verifyPin('8899'), isTrue);
        expect(schoolProfile.verifyPin('0000'), isFalse);

        // Verify unified verifyPasswordOrPin
        expect(schoolProfile.verifyPasswordOrPin('SuperSecret2026!'), isTrue);
        expect(schoolProfile.verifyPasswordOrPin('8899'), isTrue);
        expect(schoolProfile.verifyPasswordOrPin('invalid'), isFalse);

        // =====================================================================
        // PHASE 2: Academic Session / Year Initialization
        // =====================================================================
        final yearId = await academicYearService.createAcademicYear(
          name: '2026-2027 (2083 BS)',
          startDate: DateTime(2026, 4, 1),
          endDate: DateTime(2027, 3, 31),
          isCurrent: true,
          description: 'Academic Session 2026-2027',
        );
        expect(yearId, greaterThan(0));

        final activeYear = await academicYearService.getCurrentAcademicYear();
        expect(activeYear, isNotNull);
        expect(activeYear!.id, equals(yearId));
        expect(activeYear.isCurrent, isTrue);

        // =====================================================================
        // PHASE 3: Classes, Sections & Subjects Setup
        // =====================================================================
        final classId = await classSectionService.createClass(
          name: 'Grade 10',
          displayName: 'Class 10',
          orderIndex: 10,
          sections: ['Section A'],
        );
        expect(classId, greaterThan(0));

        final classWithSections = await classSectionService
            .getClassWithSectionsById(classId);
        expect(classWithSections, isNotNull);
        expect(classWithSections!.sections.length, equals(1));
        final sectionA = classWithSections.sections.first;
        expect(sectionA.name, equals('Section A'));
        final sectionId = sectionA.id;

        // Create Subjects
        final englishSubjectId = await subjectService.createSubject(
          code: 'ENG-10',
          name: 'English',
          subjectType: SubjectType.theory,
          fullMarks: 100,
          passMarks: 40,
        );
        expect(englishSubjectId, greaterThan(0));

        final mathSubjectId = await subjectService.createSubject(
          code: 'MTH-10',
          name: 'Compulsory Mathematics',
          subjectType: SubjectType.theory,
          fullMarks: 100,
          passMarks: 40,
        );
        expect(mathSubjectId, greaterThan(0));

        final scienceSubjectId = await subjectService.createSubject(
          code: 'SCI-10',
          name: 'Science & Technology',
          subjectType: SubjectType.both,
          fullMarks: 100,
          passMarks: 40,
          theoryMarks: 75,
          practicalMarks: 25,
        );
        expect(scienceSubjectId, greaterThan(0));

        // =====================================================================
        // PHASE 4: Employee & Teacher Recruitment (HR)
        // =====================================================================
        final teacherId = await employeeService.createEmployee(
          name: 'Hari Prasad Sharma',
          employeeType: EmployeeType.teacher,
          designation: 'Senior Science Teacher',
          email: 'hari.sharma@pragyan.edu.np',
          phone: '9841234567',
          basicSalary: 45000.0,
          department: 'Science Department',
          joiningDate: DateTime(2026, 4, 1),
        );
        expect(teacherId, greaterThan(0));

        final teacher = await employeeService.getEmployeeById(teacherId);
        expect(teacher, isNotNull);
        expect(teacher!.name, equals('Hari Prasad Sharma'));
        expect(teacher.employeeCode, startsWith('TCH-'));

        // =====================================================================
        // PHASE 5: Student Admissions & Contact Linking
        // =====================================================================
        // Admit Student 1 (Aarav Sharma)
        final aaravId = await studentService.admitStudent(
          name: 'Aarav Sharma',
          gender: 'Male',
          academicYearId: yearId,
          classId: classId,
          sectionId: sectionId,
          rollNumber: 1,
          admissionDate: DateTime(2026, 4, 10),
          dateOfBirth: DateTime(2010, 5, 12),
          address: 'Shantinagar, Kathmandu',
          phone: '9801122334',
          email: 'aarav@example.com',
          guardianName: 'Ram Sharma',
          guardianPhone: '9801122334',
          guardianRelation: 'Father',
          emergencyContactName: 'Ram Sharma',
          emergencyContactPhone: '9801122334',
          emergencyContactRelation: 'Father',
        );
        expect(aaravId, greaterThan(0));

        final aarav = await studentService.getStudentById(
          aaravId,
          academicYearId: yearId,
        );
        expect(aarav, isNotNull);
        expect(aarav!.student.studentId, equals('20260001'));
        expect(aarav.student.admissionNumber, equals('ADM-2026-0001'));
        expect(aarav.student.rollNumber, equals(1));

        // Verify Contacts table sync for guardian
        final contacts = await db.getAllContacts();
        expect(
          contacts.any(
            (c) =>
                c.sourceId == aaravId &&
                c.name == 'Ram Sharma' &&
                c.isPrimary == true,
          ),
          isTrue,
        );

        // Admit Student 2 (Priya Adhikari)
        final priyaId = await studentService.admitStudent(
          name: 'Priya Adhikari',
          gender: 'Female',
          academicYearId: yearId,
          classId: classId,
          sectionId: sectionId,
          rollNumber: 2,
          admissionDate: DateTime(2026, 4, 11),
          dateOfBirth: DateTime(2010, 8, 20),
          guardianName: 'Sita Adhikari',
          guardianPhone: '9802233445',
          guardianRelation: 'Mother',
        );
        expect(priyaId, greaterThan(0));

        final priya = await studentService.getStudentById(
          priyaId,
          academicYearId: yearId,
        );
        expect(priya, isNotNull);
        expect(priya!.student.studentId, equals('20260002'));
        expect(priya.student.admissionNumber, equals('ADM-2026-0002'));

        // =====================================================================
        // PHASE 6: Student & Staff Attendance Tracking
        // =====================================================================
        final attendanceDate = DateTime(2026, 4, 15);

        // Get student attendance record items for class & date
        final studentItems = await attendanceService
            .getStudentsWithAttendanceForDate(
              classId: classId,
              sectionId: sectionId,
              date: attendanceDate,
            );
        expect(studentItems.length, equals(2));

        // Mark Aarav Present, Priya Absent
        for (final item in studentItems) {
          if (item.student.id == aaravId) {
            item.status = AttendanceStatus.present;
          } else if (item.student.id == priyaId) {
            item.status = AttendanceStatus.absent;
            item.remarks = 'Sick Leave';
          }
        }

        await attendanceService.saveStudentAttendanceBatch(
          academicYearId: yearId,
          classId: classId,
          sectionId: sectionId,
          date: attendanceDate,
          records: studentItems,
        );

        // Calculate Student Attendance Summary
        final studentSummary = attendanceService.calculateStudentSummary(
          studentItems,
        );
        expect(studentSummary.total, equals(2));
        expect(studentSummary.present, equals(1));
        expect(studentSummary.absent, equals(1));
        expect(studentSummary.percentage, equals(50.0));

        // Get and mark staff attendance
        final staffItems = await attendanceService
            .getStaffWithAttendanceForDate(date: attendanceDate);
        expect(staffItems.length, greaterThanOrEqualTo(1));
        final teacherItem = staffItems.firstWhere(
          (s) => s.employee.id == teacherId,
        );
        teacherItem.status = AttendanceStatus.present;
        teacherItem.checkInTime = '08:45';
        teacherItem.checkOutTime = '16:15';

        await attendanceService.saveStaffAttendanceBatch(
          date: attendanceDate,
          records: staffItems,
        );

        final staffSummary = attendanceService.calculateStaffSummary(
          staffItems,
        );
        expect(staffSummary.present, greaterThanOrEqualTo(1));

        // =====================================================================
        // PHASE 7: Fee Allocation, Partial Collection, Discounts & Receipts
        // =====================================================================
        final tuitionCatId = await feeService.createFeeCategory(
          name: 'Monthly Tuition Fee',
          frequency: 'monthly',
          defaultAmount: 6000.0,
          description: 'Standard monthly tuition',
        );
        expect(tuitionCatId, greaterThan(0));

        // Assign fee to Aarav
        final aaravFeeId = await feeService.assignFeeToStudent(
          studentId: aaravId,
          feeCategoryId: tuitionCatId,
          title: 'Baishakh Monthly Tuition',
          totalAmount: 6000.0,
          academicYearId: yearId,
          dueDate: DateTime(2026, 4, 30),
        );
        expect(aaravFeeId, greaterThan(0));

        // Record partial payment of 4000 with 500 merit discount
        final payment1 = await feeService.recordFeePayment(
          studentFeeId: aaravFeeId,
          amount: 4000.0,
          discountAmount: 500.0,
          discountReason: 'Academic Merit Concession',
          paymentMethod: 'Cash',
          paymentDate: DateTime(2026, 4, 18),
        );
        expect(payment1.amount, equals(4000.0));

        var aaravFee = await db.getStudentFeeById(aaravFeeId);
        expect(aaravFee, isNotNull);
        expect(aaravFee!.paidAmount, equals(4000.0));
        expect(aaravFee.discountAmount, equals(500.0));
        expect(aaravFee.status, equals('partial'));

        // Settle remaining 1500.0 balance (6000 - 500 - 4000 = 1500)
        final payment2 = await feeService.recordFeePayment(
          studentFeeId: aaravFeeId,
          amount: 1500.0,
          paymentMethod: 'eSewa Digital',
          paymentDate: DateTime(2026, 4, 20),
        );
        expect(payment2.amount, equals(1500.0));

        aaravFee = await db.getStudentFeeById(aaravFeeId);
        expect(aaravFee!.status, equals('paid'));
        expect(aaravFee.paidAmount, equals(5500.0));

        // Assign fee to Priya & collect via consolidated multi-payment receipt
        final priyaFeeId = await feeService.assignFeeToStudent(
          studentId: priyaId,
          feeCategoryId: tuitionCatId,
          title: 'Baishakh Monthly Tuition',
          totalAmount: 6000.0,
          academicYearId: yearId,
        );

        final receipt = await feeService.recordMultipleFeePayments(
          studentId: priyaId,
          allocations: [
            FeePaymentAllocation(
              studentFeeId: priyaFeeId,
              amount: 6000.0,
              discountAmount: 0.0,
            ),
          ],
          paymentMethod: 'Bank Deposit',
          paymentDate: DateTime(2026, 4, 22),
        );
        expect(receipt.receiptNumber, startsWith('REC-'));
        expect(receipt.totalPaid, equals(6000.0));

        // Check overall fee collection stats
        final feeStats = await feeService.getFeeCollectionSummary(
          academicYearId: yearId,
        );
        expect(feeStats.totalCollected, equals(11500.0)); // 4000 + 1500 + 6000
        expect(feeStats.totalDiscount, equals(500.0));
        expect(feeStats.paidFeesCount, equals(2));

        // =====================================================================
        // PHASE 8: Salary Advance & Monthly Payroll Execution
        // =====================================================================
        // Give salary advance to Teacher Hari
        final advanceId = await payrollService.giveSalaryAdvance(
          employeeId: teacherId,
          amount: 12000.0,
          advanceDate: DateTime(2026, 4, 5),
          reason: 'Home Relocation Advance',
          academicYearId: yearId,
        );
        expect(advanceId, greaterThan(0));

        var outstandingAdv = await payrollService.getOutstandingAdvance(
          teacherId,
        );
        expect(outstandingAdv, equals(12000.0));

        // Execute April salary payment:
        // Basic: 45000, Bonus: 3000, Tax Deduction: 1500, Advance Deduction: 5000
        // Gross = 48000, Deductions = 6500, Net = 41500
        final payId = await payrollService.processSalaryPayment(
          employeeId: teacherId,
          year: 2026,
          month: 4,
          paymentDate: DateTime(2026, 4, 30),
          basicSalary: 45000.0,
          bonus: 3000.0,
          bonusReason: 'Annual Curriculum Bonus',
          deduction: 1500.0,
          deductionReason: 'Tax & Insurance',
          advanceDeduction: 5000.0,
          academicYearId: yearId,
        );
        expect(payId, greaterThan(0));

        final paymentRec = await payrollService.getSalaryPaymentById(payId);
        expect(paymentRec, isNotNull);
        expect(paymentRec!.grossSalary, equals(48000.0));
        expect(paymentRec.netSalary, equals(41500.0));
        expect(paymentRec.advanceDeduction, equals(5000.0));

        // Outstanding advance should now be 7000.0 (12000 - 5000)
        outstandingAdv = await payrollService.getOutstandingAdvance(teacherId);
        expect(outstandingAdv, equals(7000.0));

        // =====================================================================
        // PHASE 9: Examinations, Scheduling, Marks Entry & Tabulation Ledger
        // =====================================================================
        final examId = await examService.createExam(
          name: 'First Terminal Examination 2026',
          category: 'Terminal Exam 1',
          academicYearId: yearId,
          startDate: DateTime(2026, 5, 1),
          endDate: DateTime(2026, 5, 10),
          status: 'Completed',
          description: 'First Term Exams for Secondary Level',
        );
        expect(examId, greaterThan(0));

        // Schedule exam subjects via saveClassExamSchedule
        await examService.saveClassExamSchedule(
          examId: examId,
          academicYearId: yearId,
          classId: classId,
          items: [
            ExamScheduleItemInput(
              subjectId: englishSubjectId,
              examDate: DateTime(2026, 5, 2),
              startTime: '10:00',
              endTime: '13:00',
              fullMarks: 100,
              passMarks: 40,
            ),
            ExamScheduleItemInput(
              subjectId: mathSubjectId,
              examDate: DateTime(2026, 5, 4),
              startTime: '10:00',
              endTime: '13:00',
              fullMarks: 100,
              passMarks: 40,
            ),
            ExamScheduleItemInput(
              subjectId: scienceSubjectId,
              examDate: DateTime(2026, 5, 6),
              startTime: '10:00',
              endTime: '13:00',
              fullMarks: 100,
              passMarks: 40,
              theoryMarks: 75,
              practicalMarks: 25,
              theoryPassMarks: 30,
              practicalPassMarks: 10,
            ),
          ],
        );

        // Batch save marks for English
        await examResultService.saveSubjectMarksBatch(
          examId: examId,
          academicYearId: yearId,
          classId: classId,
          sectionId: sectionId,
          subjectId: englishSubjectId,
          theoryFullMarks: 100,
          theoryPassMarks: 40,
          entries: [
            SubjectMarksEntryInput(studentId: aaravId, theoryMarks: 85.0),
            SubjectMarksEntryInput(studentId: priyaId, theoryMarks: 65.0),
          ],
        );

        // Batch save marks for Math
        await examResultService.saveSubjectMarksBatch(
          examId: examId,
          academicYearId: yearId,
          classId: classId,
          sectionId: sectionId,
          subjectId: mathSubjectId,
          theoryFullMarks: 100,
          theoryPassMarks: 40,
          entries: [
            SubjectMarksEntryInput(studentId: aaravId, theoryMarks: 95.0),
            SubjectMarksEntryInput(studentId: priyaId, theoryMarks: 70.0),
          ],
        );

        // Batch save marks for Science (Theory + Practical)
        await examResultService.saveSubjectMarksBatch(
          examId: examId,
          academicYearId: yearId,
          classId: classId,
          sectionId: sectionId,
          subjectId: scienceSubjectId,
          theoryFullMarks: 75,
          theoryPassMarks: 30,
          practicalFullMarks: 25,
          practicalPassMarks: 10,
          entries: [
            SubjectMarksEntryInput(
              studentId: aaravId,
              theoryMarks: 68.0,
              practicalMarks: 24.0,
            ), // Total 92.0
            SubjectMarksEntryInput(
              studentId: priyaId,
              theoryMarks: 50.0,
              practicalMarks: 20.0,
            ), // Total 70.0
          ],
        );

        // Verify Tabulation Summaries & Rankings
        final summaries = await examResultService.getExamSummaries(
          examId: examId,
          classId: classId,
          sectionId: sectionId,
        );
        expect(summaries.length, equals(2));

        final aaravSummary = summaries.firstWhere(
          (s) => s.student.id == aaravId,
        );
        final priyaSummary = summaries.firstWhere(
          (s) => s.student.id == priyaId,
        );

        // Aarav: 85 + 95 + 92 = 272 / 300 = 90.67%
        expect(aaravSummary.summary.totalMarksObtained, equals(272.0));
        expect(aaravSummary.summary.rankInClass, equals(1));
        expect(aaravSummary.summary.isPassed, isTrue);

        // Priya: 65 + 70 + 70 = 205 / 300 = 68.33%
        expect(priyaSummary.summary.totalMarksObtained, equals(205.0));
        expect(priyaSummary.summary.rankInClass, equals(2));
        expect(priyaSummary.summary.isPassed, isTrue);

        // =====================================================================
        // PHASE 10: Timetable / Routine Scheduling & Validation
        // =====================================================================
        await timetableService.createPeriod(
          academicYearId: yearId,
          classId: classId,
          sectionId: sectionId,
          dayOfWeek: 'sunday',
          periodNumber: 1,
          startTime: '09:00',
          endTime: '09:45',
          subjectId: mathSubjectId,
          teacherId: teacherId,
          roomNumber: '101',
        );

        await timetableService.createPeriod(
          academicYearId: yearId,
          classId: classId,
          sectionId: sectionId,
          dayOfWeek: 'sunday',
          periodNumber: 2,
          startTime: '09:45',
          endTime: '10:30',
          subjectId: scienceSubjectId,
          teacherId: teacherId,
          roomNumber: '101',
        );

        await timetableService.createPeriod(
          academicYearId: yearId,
          classId: classId,
          sectionId: sectionId,
          dayOfWeek: 'sunday',
          periodNumber: 3,
          startTime: '10:30',
          endTime: '11:00',
          isBreak: true,
          breakTitle: 'Morning Break / Recess',
          roomNumber: 'Ground',
        );

        final sundayPeriods = await timetableService.getAllPeriodsWithDetails(
          academicYearId: yearId,
          classId: classId,
          sectionId: sectionId,
          dayOfWeek: 'sunday',
        );
        expect(sundayPeriods.length, equals(3));
        expect(
          sundayPeriods[0].subject?.name,
          equals('Compulsory Mathematics'),
        );
        expect(sundayPeriods[1].subject?.name, equals('Science & Technology'));
        expect(sundayPeriods[2].period.isBreak, isTrue);

        // Validate time checking: start >= end throws ArgumentError
        expect(
          () => timetableService.createPeriod(
            academicYearId: yearId,
            classId: classId,
            sectionId: sectionId,
            dayOfWeek: 'monday',
            startTime: '10:00',
            endTime: '09:00',
            subjectId: englishSubjectId,
          ),
          throwsA(isA<ArgumentError>()),
        );

        // =====================================================================
        // PHASE 11: Official Certificate Issuance & Student Promotion
        // =====================================================================
        // Issue Transfer Certificate (TC)
        final tcId = await certificateService.issueTransferCertificate(
          studentId: aaravId,
          academicYearId: yearId,
          reason: 'Graduated Secondary Level',
          conduct: 'Excellent',
          classStudying: 'Grade 10',
          promotedToClass: 'Grade 11',
          leavingDate: DateTime(2027, 3, 31),
          remarks: 'Secondary School Completion TC',
        );
        expect(tcId, greaterThan(0));

        final tcCert = await certificateService.getCertificateById(tcId);
        expect(tcCert, isNotNull);
        expect(tcCert!.certificateNumber, startsWith('TC-'));
        expect(tcCert.certificateType, equals('tc'));

        // Issue Character Certificate (CC)
        final ccId = await certificateService.issueCharacterCertificate(
          studentId: aaravId,
          academicYearId: yearId,
          conduct: 'Outstanding',
          remarks: 'Exemplary character and conduct throughout the year',
        );
        expect(ccId, greaterThan(0));

        final ccCert = await certificateService.getCertificateById(ccId);
        expect(ccCert, isNotNull);
        expect(ccCert!.certificateNumber, startsWith('CC-'));

        // Issue Bonafide Certificate
        final bonId = await certificateService.issueBonafideCertificate(
          studentId: aaravId,
          academicYearId: yearId,
          purpose: 'Scholarship Application Verification',
        );
        expect(bonId, greaterThan(0));

        final bonCert = await certificateService.getCertificateById(bonId);
        expect(bonCert, isNotNull);
        expect(bonCert!.certificateNumber, startsWith('BON-'));

        // Promote Student to Next Session: 2027-2028
        final nextYearId = await academicYearService.createAcademicYear(
          name: '2027-2028 (2084 BS)',
          startDate: DateTime(2027, 4, 1),
          endDate: DateTime(2028, 3, 31),
          isCurrent: false,
        );

        final class11Id = await classSectionService.createClass(
          name: 'Grade 11',
          displayName: 'Class 11',
          orderIndex: 11,
          sections: ['Section A'],
        );
        final class11Sections = await classSectionService
            .getClassWithSectionsById(class11Id);
        final section11AId = class11Sections!.sections.first.id;

        await studentService.promoteStudents(
          sourceAcademicYearId: yearId,
          targetAcademicYearId: nextYearId,
          items: [
            StudentPromotionItem(
              studentId: aaravId,
              studentName: 'Aarav Sharma',
              studentCode: '20260001',
              resultStatus: AcademicResult.passed,
              isPromoted: true,
              targetClassId: class11Id,
              targetSectionId: section11AId,
              targetRollNumber: 1,
              remarks: 'Promoted to Grade 11 upon passing Grade 10',
            ),
          ],
        );

        // Verify Student Academic Histories (should now have 2 records)
        final histories = await studentService.getStudentAcademicHistory(
          aaravId,
        );
        expect(histories.length, equals(2));

        final oldEnrollment = histories.firstWhere(
          (h) => h.academicYear.id == yearId,
        );
        final newEnrollment = histories.firstWhere(
          (h) => h.academicYear.id == nextYearId,
        );

        expect(oldEnrollment.history.status, equals(AcademicStatus.promoted));
        expect(
          oldEnrollment.history.resultStatus,
          equals(AcademicResult.passed),
        );

        expect(newEnrollment.history.status, equals(AcademicStatus.active));
        expect(newEnrollment.schoolClass.name, equals('Grade 11'));

        // Verify Student record was updated to the new class & section
        final updatedAarav = await studentService.getStudentById(aaravId);
        expect(updatedAarav!.student.classId, equals(class11Id));
        expect(updatedAarav.student.sectionId, equals(section11AId));

        // =====================================================================
        // PHASE 12: Database Integrity & Table Aggregates Verification
        // =====================================================================
        final allStudents = await db.getAllStudents();
        expect(allStudents.length, equals(2));

        final allEmployees = await db.getAllEmployees();
        expect(allEmployees.length, equals(1));

        final allClassList = await db.getAllClassesWithSections();
        expect(allClassList.length, equals(2)); // Grade 10 & Grade 11

        final allSubjects = await db.getAllSubjects();
        expect(allSubjects.length, equals(3));

        final allExams = await db.getAllExamsWithDetails();
        expect(allExams.length, equals(1));

        final allFees = await feeService.getStudentFees();
        expect(allFees.length, equals(2));

        final allSalaries = await payrollService.getSalaryPayments();
        expect(allSalaries.length, equals(1));

        final allCerts = await certificateService.getAllCertificates();
        expect(allCerts.length, equals(3)); // TC, CC, BON
      },
    );
  });
}
