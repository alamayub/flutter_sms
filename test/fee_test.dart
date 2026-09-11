import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sms/data/app_database.dart';
import 'package:sms/data/database_seeder.dart';
import 'package:sms/services/fee_service.dart';

void main() {
  late AppDatabase db;
  late FeeService service;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    service = FeeService(db);
    // Seed prerequisites: academic years, classes, sections, students
    await DatabaseSeeder.seedAcademicYears(db);
    await DatabaseSeeder.seedClassesAndSections(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('Fee Category Tests', () {
    test('Can create fee categories with different frequencies', () async {
      final id1 = await service.createFeeCategory(
        name: 'Tuition Fee',
        frequency: 'monthly',
        defaultAmount: 3000.0,
        description: 'Monthly tuition charges',
      );
      final id2 = await service.createFeeCategory(
        name: 'Admission Fee',
        frequency: 'one_time',
        defaultAmount: 6000.0,
      );
      final id3 = await service.createFeeCategory(
        name: 'Terminal Exam Fee',
        frequency: 'term_wise',
        defaultAmount: 1200.0,
      );

      expect(id1, greaterThan(0));
      expect(id2, greaterThan(0));
      expect(id3, greaterThan(0));

      final allCats = await service.getAllFeeCategories();
      expect(allCats.length, greaterThanOrEqualTo(3));
      expect(
        allCats.any((c) => c.name == 'Tuition Fee' && c.frequency == 'monthly'),
        isTrue,
      );
      expect(
        allCats.any(
          (c) => c.name == 'Admission Fee' && c.frequency == 'one_time',
        ),
        isTrue,
      );
      expect(
        allCats.any(
          (c) => c.name == 'Terminal Exam Fee' && c.frequency == 'term_wise',
        ),
        isTrue,
      );
    });

    test(
      'Seeder populates standard fee categories and sample student fees',
      () async {
        final cats = await service.getAllFeeCategories();
        expect(cats.length, greaterThanOrEqualTo(5));
        expect(cats.any((c) => c.name.contains('Tuition')), isTrue);
        expect(cats.any((c) => c.name.contains('Admission')), isTrue);
        expect(cats.any((c) => c.name.contains('Uniform')), isTrue);
        expect(cats.any((c) => c.name.contains('Exam')), isTrue);

        final fees = await service.getStudentFees();
        expect(fees.isNotEmpty, isTrue);

        final payments = await service.getFeePayments();
        expect(payments.isNotEmpty, isTrue);
      },
    );
  });

  group('Student Fee Allocation & Partial Payments', () {
    late Student testStudent;
    late int tuitionCatId;
    late int dressCatId;
    late AcademicYear activeYear;

    setUp(() async {
      final students = await db.getAllStudents();
      testStudent = students.first;
      final year = await db.getActiveAcademicYear();
      activeYear = year!;

      tuitionCatId = await service.createFeeCategory(
        name: 'Monthly Tuition',
        frequency: 'monthly',
        defaultAmount: 4000.0,
      );
      dressCatId = await service.createFeeCategory(
        name: 'Dress & Uniform',
        frequency: 'one_time',
        defaultAmount: 3500.0,
      );
    });

    test(
      'Assign fee to student initializes pending status and correct remaining balance',
      () async {
        final feeId = await service.assignFeeToStudent(
          studentId: testStudent.id,
          feeCategoryId: tuitionCatId,
          title: 'Baishakh Tuition Fee',
          totalAmount: 4000.0,
          discountAmount: 500.0, // 500 discount
          dueDate: DateTime.now().add(const Duration(days: 15)),
          academicYearId: activeYear.id,
        );

        final feeWithDetails = (await service.getStudentFees(
          studentId: testStudent.id,
        )).firstWhere((f) => f.id == feeId);

        expect(feeWithDetails.totalAmount, equals(4000.0));
        expect(feeWithDetails.discountAmount, equals(500.0));
        expect(feeWithDetails.netAmount, equals(3500.0));
        expect(feeWithDetails.paidAmount, equals(0.0));
        expect(feeWithDetails.remainingAmount, equals(3500.0));
        expect(feeWithDetails.status, equals('pending'));
        expect(feeWithDetails.isPending, isTrue);
        expect(feeWithDetails.isPartial, isFalse);
        expect(feeWithDetails.isPaid, isFalse);
      },
    );

    test(
      'Recording partial payment transitions status to partial and calculates balance',
      () async {
        final feeId = await service.assignFeeToStudent(
          studentId: testStudent.id,
          feeCategoryId: tuitionCatId,
          title: 'Jestha Tuition Fee',
          totalAmount: 5000.0,
          discountAmount: 0.0,
          academicYearId: activeYear.id,
        );

        // Pay 2,000 partially out of 5,000
        final payment1 = await service.recordFeePayment(
          studentFeeId: feeId,
          amount: 2000.0,
          paymentMethod: 'Cash',
          remarks: '1st installment',
        );

        expect(payment1.amount, equals(2000.0));
        expect(payment1.receiptNumber.startsWith('REC-'), isTrue);

        final updatedFee = (await service.getStudentFees(
          studentId: testStudent.id,
        )).firstWhere((f) => f.id == feeId);

        expect(updatedFee.paidAmount, equals(2000.0));
        expect(updatedFee.remainingAmount, equals(3000.0));
        expect(updatedFee.status, equals('partial'));
        expect(updatedFee.isPartial, isTrue);
        expect(updatedFee.isPaid, isFalse);
        expect(updatedFee.payments.length, equals(1));
      },
    );

    test(
      'Subsequent payment settling remainder transitions status to paid',
      () async {
        final feeId = await service.assignFeeToStudent(
          studentId: testStudent.id,
          feeCategoryId: dressCatId,
          title: 'School Blazer & Uniform',
          totalAmount: 3500.0,
          discountAmount: 0.0,
          academicYearId: activeYear.id,
        );

        // Pay 1,500 partially
        await service.recordFeePayment(
          studentFeeId: feeId,
          amount: 1500.0,
          paymentMethod: 'eSewa',
          referenceNumber: 'ESEWA-1234',
        );

        // Settle remaining 2,000
        final payment2 = await service.recordFeePayment(
          studentFeeId: feeId,
          amount: 2000.0,
          paymentMethod: 'Bank Transfer',
          referenceNumber: 'BANK-5678',
        );

        expect(payment2.amount, equals(2000.0));

        final finalFee = (await service.getStudentFees(
          studentId: testStudent.id,
        )).firstWhere((f) => f.id == feeId);

        expect(finalFee.paidAmount, equals(3500.0));
        expect(finalFee.remainingAmount, equals(0.0));
        expect(finalFee.status, equals('paid'));
        expect(finalFee.isPaid, isTrue);
        expect(finalFee.isPartial, isFalse);
        expect(finalFee.payments.length, equals(2));
      },
    );

    test('Payment exceeding remaining balance is rejected', () async {
      final feeId = await service.assignFeeToStudent(
        studentId: testStudent.id,
        feeCategoryId: tuitionCatId,
        title: 'Tuition Fee',
        totalAmount: 3000.0,
        discountAmount: 500.0, // net = 2500
        academicYearId: activeYear.id,
      );

      // Attempting to pay 2,600 when net remaining is 2,500
      expect(
        () => service.recordFeePayment(
          studentFeeId: feeId,
          amount: 2600.0,
          paymentMethod: 'Cash',
        ),
        throwsArgumentError,
      );

      // Zero or negative payment is also rejected
      expect(
        () => service.recordFeePayment(
          studentFeeId: feeId,
          amount: 0.0,
          paymentMethod: 'Cash',
        ),
        throwsArgumentError,
      );
    });

    test(
      'Deleting payment rolls back fee balance and reverts status',
      () async {
        final feeId = await service.assignFeeToStudent(
          studentId: testStudent.id,
          feeCategoryId: tuitionCatId,
          title: 'Tuition Fee',
          totalAmount: 4000.0,
          academicYearId: activeYear.id,
        );

        // Payment 1: 1,500 -> status: partial
        final p1 = await service.recordFeePayment(
          studentFeeId: feeId,
          amount: 1500.0,
          paymentMethod: 'Cash',
        );

        // Payment 2: 2,500 -> status: paid
        final p2 = await service.recordFeePayment(
          studentFeeId: feeId,
          amount: 2500.0,
          paymentMethod: 'Cash',
        );

        var fee = (await service.getStudentFees(
          studentId: testStudent.id,
        )).firstWhere((f) => f.id == feeId);
        expect(fee.status, equals('paid'));

        // Rollback payment 2
        final deletedP2 = await service.deleteFeePayment(p2.id);
        expect(deletedP2, isTrue);

        fee = (await service.getStudentFees(
          studentId: testStudent.id,
        )).firstWhere((f) => f.id == feeId);
        expect(fee.paidAmount, equals(1500.0));
        expect(fee.remainingAmount, equals(2500.0));
        expect(fee.status, equals('partial'));

        // Rollback payment 1
        final deletedP1 = await service.deleteFeePayment(p1.id);
        expect(deletedP1, isTrue);

        fee = (await service.getStudentFees(
          studentId: testStudent.id,
        )).firstWhere((f) => f.id == feeId);
        expect(fee.paidAmount, equals(0.0));
        expect(fee.remainingAmount, equals(4000.0));
        expect(fee.status, equals('pending'));
      },
    );
  });

  group('Fee Reporting & Period Analytics', () {
    test(
      'Calculates accurate metrics across periods and frequencies',
      () async {
        final students = await db.getAllStudents();
        final s1 = students[0];
        final s2 = students.length > 1 ? students[1] : students[0];
        final activeYear = (await db.getActiveAcademicYear())!;

        final tuitionCat = await service.createFeeCategory(
          name: 'Tuition',
          frequency: 'monthly',
          defaultAmount: 3000.0,
        );
        final examCat = await service.createFeeCategory(
          name: 'Exam',
          frequency: 'term_wise',
          defaultAmount: 1000.0,
        );

        // S1: 3000 total, paid 3000 today
        final f1 = await service.assignFeeToStudent(
          studentId: s1.id,
          feeCategoryId: tuitionCat,
          title: 'Month 1 Tuition',
          totalAmount: 3000.0,
          academicYearId: activeYear.id,
        );
        await service.recordFeePayment(
          studentFeeId: f1,
          amount: 3000.0,
          paymentMethod: 'Cash',
          paymentDate: DateTime.now(),
        );

        // S2: 1000 total, paid 500 (partial) today
        final f2 = await service.assignFeeToStudent(
          studentId: s2.id,
          feeCategoryId: examCat,
          title: 'Term 1 Exam',
          totalAmount: 1000.0,
          academicYearId: activeYear.id,
        );
        await service.recordFeePayment(
          studentFeeId: f2,
          amount: 500.0,
          paymentMethod: 'eSewa',
          paymentDate: DateTime.now(),
        );

        // Total invoiced: 4,000
        // Total collected: 3,500 (today and all-time)
        // Total pending: 500 (from f2)

        final summaryToday = await service.getFeeCollectionSummary(
          period: FeePeriodType.today,
          academicYearId: activeYear.id,
        );

        expect(summaryToday.totalCollected, equals(3500.0));
        expect(summaryToday.totalPending, equals(500.0));
        expect(summaryToday.totalInvoiced, equals(4000.0));
        expect(summaryToday.paymentTransactionsCount, equals(2));
        expect(summaryToday.paidFeesCount, equals(1));
        expect(summaryToday.partialFeesCount, equals(1));
        expect(summaryToday.pendingFeesCount, equals(0));

        // Frequency breakdown
        expect(
          summaryToday.frequencyBreakdown['monthly']?.invoiced,
          equals(3000.0),
        );
        expect(
          summaryToday.frequencyBreakdown['monthly']?.paid,
          equals(3000.0),
        );
        expect(
          summaryToday.frequencyBreakdown['monthly']?.pending,
          equals(0.0),
        );

        expect(
          summaryToday.frequencyBreakdown['term_wise']?.invoiced,
          equals(1000.0),
        );
        expect(
          summaryToday.frequencyBreakdown['term_wise']?.paid,
          equals(500.0),
        );
        expect(
          summaryToday.frequencyBreakdown['term_wise']?.pending,
          equals(500.0),
        );

        // Student 1 specific summary
        final s1Summary = await service.getStudentFeeSummary(
          s1.id,
          academicYearId: activeYear.id,
        );
        expect(s1Summary.totalInvoiced, equals(3000.0));
        expect(s1Summary.totalPaid, equals(3000.0));
        expect(s1Summary.totalPending, equals(0.0));
        expect(s1Summary.paidFeesCount, equals(1));

        // Student 2 specific summary
        final s2Summary = await service.getStudentFeeSummary(
          s2.id,
          academicYearId: activeYear.id,
        );
        expect(s2Summary.totalInvoiced, equals(1000.0));
        expect(s2Summary.totalPaid, equals(500.0));
        expect(s2Summary.totalPending, equals(500.0));
        expect(s2Summary.partialFeesCount, equals(1));
      },
    );

    test(
      'Bulk assigns fee to class and isolates summaries by academic year',
      () async {
        final histories = await db.select(db.studentAcademicHistories).get();
        final sampleHistory = histories.first;
        final targetClassId = sampleHistory.classId;
        final year1Id = sampleHistory.academicYearId;
        final academicYears = await db.getAllAcademicYears();
        final year1 = academicYears.firstWhere((y) => y.id == year1Id);
        final year2 = academicYears.firstWhere(
          (y) => y.id != year1.id,
          orElse: () => year1,
        );

        final catId = await service.createFeeCategory(
          name: 'Annual Lab Fee',
          frequency: 'yearly',
          defaultAmount: 2500.0,
        );

        final assignedCount = await service.bulkAssignFeeToClass(
          classId: targetClassId,
          feeCategoryId: catId,
          title: '2081 Lab Fee',
          totalAmount: 2500.0,
          academicYearId: year1.id,
        );

        expect(assignedCount, greaterThan(0));

        final year1Summary = await service.getFeeCollectionSummary(
          academicYearId: year1.id,
        );
        expect(year1Summary.totalInvoiced, greaterThanOrEqualTo(2500.0));

        if (year2.id != year1.id) {
          final year2Summary = await service.getFeeCollectionSummary(
            academicYearId: year2.id,
          );
          expect(
            year2Summary.frequencyBreakdown['yearly']?.invoiced ?? 0.0,
            equals(0.0),
          );
          // Year 2 should not have this fee
          final year2Fees = await service.getStudentFees(
            academicYearId: year2.id,
          );
          expect(year2Fees.any((f) => f.title == '2081 Lab Fee'), isFalse);
        }
      },
    );
  });

  group('Scholarship and Discount on Payment Tests', () {
    late Student student;
    late AcademicYear activeYear;
    late int tuitionCatId;

    setUp(() async {
      final students = await db.getAllStudents();
      student = students.first;
      activeYear = (await db.getActiveAcademicYear())!;
      tuitionCatId = await service.createFeeCategory(
        name: 'Scholarship Tuition Test',
        frequency: 'monthly',
        defaultAmount: 5000.0,
      );
    });

    test(
      'Applying 20% scholarship during fee payment updates discount, remaining balance, and logs reason',
      () async {
        final feeId = await service.assignFeeToStudent(
          studentId: student.id,
          feeCategoryId: tuitionCatId,
          title: 'Kartik Tuition Fee',
          totalAmount: 5000.0,
          discountAmount: 0.0,
          academicYearId: activeYear.id,
        );

        // Student is granted 20% scholarship (Rs. 1,000) during payment, pays Rs. 4,000 to fully clear
        final payment = await service.recordFeePayment(
          studentFeeId: feeId,
          amount: 4000.0,
          paymentMethod: 'Cash',
          discountAmount: 1000.0,
          discountReason: 'Academic Merit Scholarship (20%)',
        );

        expect(payment.amount, equals(4000.0));
        expect(payment.remarks, contains('Academic Merit Scholarship'));

        final fee = (await service.getStudentFees(
          studentId: student.id,
        )).firstWhere((f) => f.id == feeId);
        expect(fee.totalAmount, equals(5000.0));
        expect(fee.discountAmount, equals(1000.0));
        expect(fee.netAmount, equals(4000.0));
        expect(fee.paidAmount, equals(4000.0));
        expect(fee.remainingAmount, equals(0.0));
        expect(fee.isPaid, isTrue);
        expect(fee.fee.notes, contains('Academic Merit Scholarship'));
      },
    );

    test(
      'Applying 100% full scholarship waiver with 0 payment marks fee as paid',
      () async {
        final feeId = await service.assignFeeToStudent(
          studentId: student.id,
          feeCategoryId: tuitionCatId,
          title: 'Mangsir Tuition Fee',
          totalAmount: 5000.0,
          discountAmount: 0.0,
          academicYearId: activeYear.id,
        );

        // 100% full scholarship waiver
        final payment = await service.recordFeePayment(
          studentFeeId: feeId,
          amount: 0.0,
          paymentMethod: 'Scholarship Waiver',
          discountAmount: 5000.0,
          discountReason: 'Full Need-Based Scholarship',
        );

        expect(payment.amount, equals(0.0));
        expect(payment.paymentMethod, equals('Scholarship Waiver'));

        final fee = (await service.getStudentFees(
          studentId: student.id,
        )).firstWhere((f) => f.id == feeId);
        expect(fee.discountAmount, equals(5000.0));
        expect(fee.netAmount, equals(0.0));
        expect(fee.remainingAmount, equals(0.0));
        expect(fee.isPaid, isTrue);
      },
    );

    test(
      'Partial scholarship with partial payment transitions fee status to partial',
      () async {
        final feeId = await service.assignFeeToStudent(
          studentId: student.id,
          feeCategoryId: tuitionCatId,
          title: 'Poush Tuition Fee',
          totalAmount: 6000.0,
          discountAmount: 0.0,
          academicYearId: activeYear.id,
        );

        // Sibling discount of Rs. 1,000 -> net 5,000. Student pays 2,500.
        await service.recordFeePayment(
          studentFeeId: feeId,
          amount: 2500.0,
          paymentMethod: 'Bank Transfer',
          discountAmount: 1000.0,
          discountReason: 'Sibling Concession',
        );

        final fee = (await service.getStudentFees(
          studentId: student.id,
        )).firstWhere((f) => f.id == feeId);
        expect(fee.netAmount, equals(5000.0));
        expect(fee.paidAmount, equals(2500.0));
        expect(fee.remainingAmount, equals(2500.0));
        expect(fee.isPartial, isTrue);
      },
    );

    test(
      'Discount reducing net fee below already paid amount is rejected',
      () async {
        final feeId = await service.assignFeeToStudent(
          studentId: student.id,
          feeCategoryId: tuitionCatId,
          title: 'Magh Tuition Fee',
          totalAmount: 5000.0,
          academicYearId: activeYear.id,
        );

        // First payment of Rs. 3,000
        await service.recordFeePayment(
          studentFeeId: feeId,
          amount: 3000.0,
          paymentMethod: 'Cash',
        );

        // Attempting to apply discount of Rs. 3,000 would make net amount Rs. 2,000,
        // which is less than the already paid Rs. 3,000. Must throw ArgumentError.
        expect(
          () => service.recordFeePayment(
            studentFeeId: feeId,
            amount: 500.0,
            paymentMethod: 'Cash',
            discountAmount: 3000.0,
          ),
          throwsA(isA<ArgumentError>()),
        );

        expect(
          () => service.updateFeeDiscount(
            studentFeeId: feeId,
            discountAmount: 3000.0,
          ),
          throwsA(isA<ArgumentError>()),
        );
      },
    );
  });

  group('Multi-Fee Simultaneous Payments & Consolidated Receipts', () {
    late Student student;
    late AcademicYear activeYear;

    setUp(() async {
      final students = await db.getAllStudents();
      student = students.first;
      final year = await db.getActiveAcademicYear();
      activeYear = year!;
    });

    test(
      'Can record multiple fee payments together in a single transaction',
      () async {
        final catAdmission = await service.createFeeCategory(
          name: 'Admission Fee',
          frequency: 'one_time',
          defaultAmount: 5000.0,
        );
        final catDress = await service.createFeeCategory(
          name: 'Uniform & Dress',
          frequency: 'one_time',
          defaultAmount: 1500.0,
        );
        final catSchool = await service.createFeeCategory(
          name: 'Tuition & School Fee',
          frequency: 'quarterly',
          defaultAmount: 7500.0,
        );

        final fee1 = await service.assignFeeToStudent(
          studentId: student.id,
          feeCategoryId: catAdmission,
          title: 'Admission Fee',
          totalAmount: 5000.0,
          academicYearId: activeYear.id,
        );
        final fee2 = await service.assignFeeToStudent(
          studentId: student.id,
          feeCategoryId: catDress,
          title: 'Uniform Fee',
          totalAmount: 1500.0,
          academicYearId: activeYear.id,
        );
        final fee3 = await service.assignFeeToStudent(
          studentId: student.id,
          feeCategoryId: catSchool,
          title: 'School Fee - Quarter 1',
          totalAmount: 7500.0,
          academicYearId: activeYear.id,
          academicTerm: 'Q1',
        );

        // Student pays all three simultaneously upon admission with a Rs. 500 admission discount
        final receipt = await service.recordMultipleFeePayments(
          studentId: student.id,
          allocations: [
            FeePaymentAllocation(
              studentFeeId: fee1,
              amount: 4500.0,
              discountAmount: 500.0,
              discountReason: 'Early Admission Discount',
            ),
            FeePaymentAllocation(studentFeeId: fee2, amount: 1500.0),
            FeePaymentAllocation(studentFeeId: fee3, amount: 7500.0),
          ],
          paymentMethod: 'Bank Transfer',
          referenceNumber: 'TXN-COMBINED-888',
          remarks: 'Admission package payment',
          academicYearId: activeYear.id,
        );

        expect(receipt.receiptNumber, startsWith('REC-'));
        expect(receipt.items.length, equals(3));
        expect(receipt.totalAssessed, equals(14000.0));
        expect(receipt.totalDiscount, equals(500.0));
        expect(receipt.totalPaid, equals(13500.0));
        expect(receipt.remainingBalance, equals(0.0));

        // Verify individual fees in database are marked as paid
        final allFees = await service.getStudentFees(studentId: student.id);
        final f1 = allFees.firstWhere((f) => f.id == fee1);
        final f2 = allFees.firstWhere((f) => f.id == fee2);
        final f3 = allFees.firstWhere((f) => f.id == fee3);

        expect(f1.isPaid, isTrue);
        expect(f1.discountAmount, equals(500.0));
        expect(f1.paidAmount, equals(4500.0));
        expect(f1.remainingAmount, equals(0.0));

        expect(f2.isPaid, isTrue);
        expect(f2.paidAmount, equals(1500.0));
        expect(f2.remainingAmount, equals(0.0));

        expect(f3.isPaid, isTrue);
        expect(f3.paidAmount, equals(7500.0));
        expect(f3.remainingAmount, equals(0.0));

        // Verify all payment records share the exact same receipt number
        expect(f1.payments.first.receiptNumber, equals(receipt.receiptNumber));
        expect(f2.payments.first.receiptNumber, equals(receipt.receiptNumber));
        expect(f3.payments.first.receiptNumber, equals(receipt.receiptNumber));

        // Verify consolidated receipt can be retrieved by that receipt number
        final fetchedReceipt = await service.getConsolidatedReceiptByNumber(
          receipt.receiptNumber,
        );
        expect(fetchedReceipt, isNotNull);
        expect(fetchedReceipt!.receiptNumber, equals(receipt.receiptNumber));
        expect(fetchedReceipt.items.length, equals(3));
        expect(fetchedReceipt.totalAssessed, equals(14000.0));
        expect(fetchedReceipt.totalDiscount, equals(500.0));
        expect(fetchedReceipt.totalPaid, equals(13500.0));
      },
    );

    test('Multi-fee payment supports partial payments across items', () async {
      final cat = await service.createFeeCategory(
        name: 'General School Fee',
        frequency: 'monthly',
        defaultAmount: 3000.0,
      );

      final feeA = await service.assignFeeToStudent(
        studentId: student.id,
        feeCategoryId: cat,
        title: 'Month 1 Fee',
        totalAmount: 3000.0,
        academicYearId: activeYear.id,
      );
      final feeB = await service.assignFeeToStudent(
        studentId: student.id,
        feeCategoryId: cat,
        title: 'Month 2 Fee',
        totalAmount: 3000.0,
        academicYearId: activeYear.id,
      );

      // Pays Month 1 completely, and pays 1,000 partial on Month 2
      final receipt = await service.recordMultipleFeePayments(
        studentId: student.id,
        allocations: [
          FeePaymentAllocation(studentFeeId: feeA, amount: 3000.0),
          FeePaymentAllocation(studentFeeId: feeB, amount: 1000.0),
        ],
        paymentMethod: 'Cash',
      );

      expect(receipt.totalPaid, equals(4000.0));
      expect(receipt.remainingBalance, equals(2000.0));

      final allFees = await service.getStudentFees(studentId: student.id);
      final fA = allFees.firstWhere((f) => f.id == feeA);
      final fB = allFees.firstWhere((f) => f.id == feeB);

      expect(fA.isPaid, isTrue);
      expect(fB.isPartial, isTrue);
      expect(fB.paidAmount, equals(1000.0));
      expect(fB.remainingAmount, equals(2000.0));
    });
  });

  group('Periodic School Fee Coverage (Quarterly, Half-Yearly, Yearly)', () {
    late Student student;
    late AcademicYear activeYear;

    setUp(() async {
      final students = await db.getAllStudents();
      student = students.first;
      final year = await db.getActiveAcademicYear();
      activeYear = year!;
    });

    test(
      'Quarterly school fee covers 3 academic months and excludes them from pending',
      () async {
        final catTuition = await service.createFeeCategory(
          name: 'School Fee',
          frequency: 'quarterly',
          defaultAmount: 7500.0,
        );

        final q1FeeId = await service.assignFeeToStudent(
          studentId: student.id,
          feeCategoryId: catTuition,
          title: 'School Fee - Quarter 1 (Months 1-3)',
          totalAmount: 7500.0,
          academicYearId: activeYear.id,
          academicMonth: 1,
          academicTerm: 'Q1',
        );

        // Before paying, fee is pending -> not covered
        var coveredM1 = await service.isStudentSchoolFeeCovered(
          studentId: student.id,
          academicYearId: activeYear.id,
          academicMonth: 1,
        );
        expect(coveredM1, isFalse);

        // Student pays Q1 fee in full
        await service.recordFeePayment(
          studentFeeId: q1FeeId,
          amount: 7500.0,
          paymentMethod: 'eSewa',
        );

        // Now Month 1, Month 2, Month 3 are covered
        expect(
          await service.isStudentSchoolFeeCovered(
            studentId: student.id,
            academicYearId: activeYear.id,
            academicMonth: 1,
          ),
          isTrue,
        );
        expect(
          await service.isStudentSchoolFeeCovered(
            studentId: student.id,
            academicYearId: activeYear.id,
            academicMonth: 2,
          ),
          isTrue,
        );
        expect(
          await service.isStudentSchoolFeeCovered(
            studentId: student.id,
            academicYearId: activeYear.id,
            academicMonth: 3,
          ),
          isTrue,
        );

        // Month 4 (Quarter 2) is NOT covered yet
        expect(
          await service.isStudentSchoolFeeCovered(
            studentId: student.id,
            academicYearId: activeYear.id,
            academicMonth: 4,
          ),
          isFalse,
        );
      },
    );

    test('Monthly school fee only covers the specific month paid', () async {
      final catTuition = await service.createFeeCategory(
        name: 'School Fee',
        frequency: 'monthly',
        defaultAmount: 2500.0,
      );

      final m1Fee = await service.assignFeeToStudent(
        studentId: student.id,
        feeCategoryId: catTuition,
        title: 'School Fee - Baishakh (Month 1)',
        totalAmount: 2500.0,
        academicYearId: activeYear.id,
        academicMonth: 1,
        academicTerm: 'Month 1',
      );

      await service.recordFeePayment(
        studentFeeId: m1Fee,
        amount: 2500.0,
        paymentMethod: 'Cash',
      );

      expect(
        await service.isStudentSchoolFeeCovered(
          studentId: student.id,
          academicYearId: activeYear.id,
          academicMonth: 1,
        ),
        isTrue,
      );
      expect(
        await service.isStudentSchoolFeeCovered(
          studentId: student.id,
          academicYearId: activeYear.id,
          academicMonth: 2,
        ),
        isFalse,
      );
    });

    test('Annual yearly fee covers all 12 months', () async {
      final catTuition = await service.createFeeCategory(
        name: 'School Fee',
        frequency: 'yearly',
        defaultAmount: 30000.0,
      );

      final annualFee = await service.assignFeeToStudent(
        studentId: student.id,
        feeCategoryId: catTuition,
        title: 'School Fee - Annual (Months 1-12)',
        totalAmount: 30000.0,
        academicYearId: activeYear.id,
        academicMonth: 1,
        academicTerm: 'Yearly',
      );

      await service.recordFeePayment(
        studentFeeId: annualFee,
        amount: 30000.0,
        paymentMethod: 'Bank Transfer',
      );

      for (int m = 1; m <= 12; m++) {
        expect(
          await service.isStudentSchoolFeeCovered(
            studentId: student.id,
            academicYearId: activeYear.id,
            academicMonth: m,
          ),
          isTrue,
        );
      }
    });
  });

  group('Admission Package Assessment', () {
    late Student student;
    late AcademicYear activeYear;

    setUp(() async {
      final students = await db.getAllStudents();
      student = students.first;
      final year = await db.getActiveAcademicYear();
      activeYear = year!;
    });

    test(
      'assessAdmissionPackageForStudent creates 4 standard fee heads',
      () async {
        final feeIds = await service.assessAdmissionPackageForStudent(
          studentId: student.id,
          academicYearId: activeYear.id,
          schoolFeeFrequency: 'quarterly',
          customAdmissionFee: 5000.0,
          customDressFee: 1500.0,
          customBookFee: 2000.0,
          customSchoolFee: 2500.0, // Quarterly = 2500 * 3 = 7500
          defaultDiscount: 500.0,
        );

        expect(feeIds.length, equals(4));

        final fees = await service.getStudentFees(studentId: student.id);
        final admissionFee = fees.firstWhere((f) => f.title == 'Admission Fee');
        final dressFee = fees.firstWhere(
          (f) => f.title == 'Uniform & Dress Fee',
        );
        final bookFee = fees.firstWhere(
          (f) => f.title == 'Book & Stationery Fee',
        );
        final schoolFee = fees.firstWhere((f) => f.title.contains('Quarter 1'));

        expect(admissionFee.totalAmount, equals(5000.0));
        expect(admissionFee.discountAmount, equals(500.0));
        expect(admissionFee.remainingAmount, equals(4500.0));

        expect(dressFee.totalAmount, equals(1500.0));
        expect(bookFee.totalAmount, equals(2000.0));
        expect(schoolFee.totalAmount, equals(7500.0)); // 2500 * 3
      },
    );
  });

  group('Generic Fee Structure, Student Facilities & Multi-Fee Payment', () {
    late Student student;
    late AcademicYear activeYear;

    setUp(() async {
      final students = await db.getAllStudents();
      student = students.first;
      final year = await db.getActiveAcademicYear();
      activeYear = year!;
    });

    test(
      'Student facility flags (transport, hostel, library) update correctly',
      () async {
        // Update student with facilities
        await (db.update(db.students)
          ..where((s) => s.id.equals(student.id))).write(
          const StudentsCompanion(
            hasTransport: Value(true),
            hasHostel: Value(false),
            hasLibrary: Value(true),
          ),
        );

        final updatedStudent =
            await (db.select(db.students)
              ..where((s) => s.id.equals(student.id))).getSingle();

        expect(updatedStudent.hasTransport, isTrue);
        expect(updatedStudent.hasHostel, isFalse);
        expect(updatedStudent.hasLibrary, isTrue);
      },
    );

    test(
      'ensureStandardFeeCategories populates default categories without duplicates',
      () async {
        final cats1 = await service.ensureStandardFeeCategories();
        expect(cats1.length, greaterThanOrEqualTo(8));
        expect(
          cats1.any((c) => c.name.toLowerCase().contains('tuition')),
          isTrue,
        );
        expect(
          cats1.any((c) => c.name.toLowerCase().contains('transport')),
          isTrue,
        );
        expect(
          cats1.any((c) => c.name.toLowerCase().contains('hostel')),
          isTrue,
        );
        expect(
          cats1.any((c) => c.name.toLowerCase().contains('library')),
          isTrue,
        );
        expect(
          cats1.any((c) => c.name.toLowerCase().contains('admission')),
          isTrue,
        );

        // Call again to verify idempotency
        final cats2 = await service.ensureStandardFeeCategories();
        expect(cats2.length, equals(cats1.length));
      },
    );

    test(
      'createAndPayStudentFees pays multiple fee types with scholarships and 1 receipt',
      () async {
        final categories = await service.ensureStandardFeeCategories();
        final tuitionCat = categories.firstWhere(
          (c) => c.name.toLowerCase().contains('tuition'),
        );
        final transportCat = categories.firstWhere(
          (c) => c.name.toLowerCase().contains('transport'),
        );
        final libraryCat = categories.firstWhere(
          (c) => c.name.toLowerCase().contains('library'),
        );

        final items = [
          CreateAndPayFeeItem(
            feeCategoryId: tuitionCat.id,
            title: 'Monthly Tuition - Baishakh',
            totalAmount: 3000.0,
            discountAmount: 500.0, // 500 scholarship
            discountReason: 'Merit scholarship',
            paymentAmount: 2500.0,
            academicMonth: 1,
          ),
          CreateAndPayFeeItem(
            feeCategoryId: transportCat.id,
            title: 'Bus Transport Fee - Route A',
            totalAmount: 1500.0,
            discountAmount: 0.0,
            paymentAmount: 1500.0,
            academicMonth: 1,
          ),
          CreateAndPayFeeItem(
            feeCategoryId: libraryCat.id,
            title: 'Library Access Fee',
            totalAmount: 1000.0,
            discountAmount: 200.0, // 200 discount
            discountReason: 'Special concession',
            paymentAmount: 800.0,
          ),
        ];

        final receipt = await service.createAndPayStudentFees(
          studentId: student.id,
          academicYearId: activeYear.id,
          feeItems: items,
          paymentMethod: 'eSewa',
          referenceNumber: 'ESEWA-MULTI-999',
          remarks: 'Baishakh composite fee payment',
        );

        // Verify consolidated receipt
        expect(receipt.receiptNumber.startsWith('REC-'), isTrue);
        expect(receipt.studentName, equals(student.name));
        expect(receipt.paymentMethod, equals('eSewa'));
        expect(receipt.referenceNumber, equals('ESEWA-MULTI-999'));
        expect(receipt.remarks, equals('Baishakh composite fee payment'));
        expect(receipt.items.length, equals(3));

        // Check totals: 3000 + 1500 + 1000 = 5500 total assessed
        expect(receipt.totalAssessed, equals(5500.0));
        // Discounts: 500 + 200 = 700
        expect(receipt.totalDiscount, equals(700.0));
        // Net: 5500 - 700 = 4800
        expect(receipt.totalNet, equals(4800.0));
        // Total Paid: 2500 + 1500 + 800 = 4800
        expect(receipt.totalPaid, equals(4800.0));

        // Verify item details in receipt
        final tuitionItem = receipt.items.firstWhere(
          (i) => i.categoryName.toLowerCase().contains('tuition'),
        );
        expect(tuitionItem.totalAmount, equals(3000.0));
        expect(tuitionItem.discountAmount, equals(500.0));
        expect(tuitionItem.paidInThisReceipt, equals(2500.0));
        expect(tuitionItem.isFullyPaid, isTrue);

        final transportItem = receipt.items.firstWhere(
          (i) => i.categoryName.toLowerCase().contains('transport'),
        );
        expect(transportItem.totalAmount, equals(1500.0));
        expect(transportItem.paidInThisReceipt, equals(1500.0));
        expect(transportItem.isFullyPaid, isTrue);

        final libraryItem = receipt.items.firstWhere(
          (i) => i.categoryName.toLowerCase().contains('library'),
        );
        expect(libraryItem.totalAmount, equals(1000.0));
        expect(libraryItem.discountAmount, equals(200.0));
        expect(libraryItem.paidInThisReceipt, equals(800.0));
        expect(libraryItem.isFullyPaid, isTrue);

        // Verify each underlying payment shares the EXACT same receipt number
        final payments = await service.getFeePayments(studentId: student.id);
        final multiPayments =
            payments
                .where((p) => p.receiptNumber == receipt.receiptNumber)
                .toList();
        expect(multiPayments.length, equals(3));
        for (final p in multiPayments) {
          expect(p.receiptNumber, equals(receipt.receiptNumber));
          expect(p.paymentMethod, equals('eSewa'));
          expect(p.referenceNumber, equals('ESEWA-MULTI-999'));
        }

        // Verify retrieval by receipt number
        final retrievedReceipt = await service.getConsolidatedReceiptByNumber(
          receipt.receiptNumber,
        );
        expect(retrievedReceipt, isNotNull);
        expect(retrievedReceipt!.receiptNumber, equals(receipt.receiptNumber));
        expect(retrievedReceipt.items.length, equals(3));
        expect(retrievedReceipt.totalPaid, equals(4800.0));
      },
    );
  });
}
