import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sms/data/app_database.dart';
import 'package:sms/services/payroll_service.dart';

void main() {
  late AppDatabase db;
  late PayrollService service;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    service = PayrollService(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('Payroll Calculation Math Tests', () {
    test('calculateGrossSalary adds basic and bonus correctly', () {
      expect(PayrollService.calculateGrossSalary(30000, 5000), equals(35000));
      expect(PayrollService.calculateGrossSalary(30000, 0), equals(30000));
      expect(PayrollService.calculateGrossSalary(0, 5000), equals(5000));
      expect(PayrollService.calculateGrossSalary(-10, -5), equals(0));
    });

    test('calculateTotalDeductions sums standard and advance deductions', () {
      expect(PayrollService.calculateTotalDeductions(1200, 3000), equals(4200));
      expect(PayrollService.calculateTotalDeductions(1200, 0), equals(1200));
      expect(PayrollService.calculateTotalDeductions(0, 0), equals(0));
    });

    test('calculateNetSalary subtracts all deductions from gross', () {
      // Basic 30,000 + Bonus 5,000 = Gross 35,000
      // Deductions: 1,500 standard + 3,500 advance = 5,000 total ded
      // Net = 30,000
      expect(
        PayrollService.calculateNetSalary(30000, 5000, 1500, 3500),
        equals(30000),
      );

      // Floor at 0 if deductions exceed gross
      expect(
        PayrollService.calculateNetSalary(10000, 0, 8000, 5000),
        equals(0),
      );
    });
  });

  group('Salary Advance Management Tests', () {
    test('Can give advance and verify outstanding balance', () async {
      final employees = await db.getAllEmployees();
      final emp = employees.first;

      final advanceId = await service.giveSalaryAdvance(
        employeeId: emp.id,
        amount: 8000,
        advanceDate: DateTime.now(),
        paymentMethod: 'Cash',
        reason: 'Emergency home repair',
      );

      expect(advanceId, greaterThan(0));

      final balance = await service.getOutstandingAdvance(emp.id);
      expect(balance, equals(8000));

      final advance = await service.getSalaryAdvances(employeeId: emp.id);
      expect(advance.length, equals(1));
      expect(advance.first.status, equals('pending'));
      expect(advance.first.adjustedAmount, equals(0.0));
      expect(advance.first.remainingAmount, equals(8000.0));
      expect(advance.first.isSettled, isFalse);
    });

    test('Rejects invalid advance amounts or non-existent employee', () async {
      final employees = await db.getAllEmployees();
      final emp = employees.first;

      expect(
        () => service.giveSalaryAdvance(
          employeeId: emp.id,
          amount: 0,
          advanceDate: DateTime.now(),
        ),
        throwsArgumentError,
      );

      expect(
        () => service.giveSalaryAdvance(
          employeeId: 999999,
          amount: 5000,
          advanceDate: DateTime.now(),
        ),
        throwsArgumentError,
      );
    });
  });

  group('Salary Payment & Advance Adjustment Tests', () {
    test('Standard salary disbursement without advance deduction', () async {
      final employees = await db.getAllEmployees();
      final emp = employees.first;

      final paymentId = await service.processSalaryPayment(
        employeeId: emp.id,
        year: 2026,
        month: 5,
        paymentDate: DateTime(2026, 5, 28),
        basicSalary: 30000,
        bonus: 2000,
        bonusReason: 'Performance',
        deduction: 1000,
        deductionReason: 'Tax',
        advanceDeduction: 0,
        paymentMethod: 'Bank Transfer',
        referenceNumber: 'TXN-001',
      );

      expect(paymentId, greaterThan(0));

      final payment = await service.getSalaryPaymentById(paymentId);
      expect(payment, isNotNull);
      expect(payment!.grossSalary, equals(32000));
      expect(payment.totalDeductions, equals(1000));
      expect(payment.netSalary, equals(31000));
      expect(payment.advanceDeduction, equals(0));
    });

    test('Single-term advance adjustment settles full advance', () async {
      final employees = await db.getAllEmployees();
      final emp = employees.first;

      // 1. Give 6,000 advance
      final advanceId = await service.giveSalaryAdvance(
        employeeId: emp.id,
        amount: 6000,
        advanceDate: DateTime(2026, 4, 1),
      );

      expect(await service.getOutstandingAdvance(emp.id), equals(6000));

      // 2. Pay salary and settle full 6,000 in one term
      final paymentId = await service.processSalaryPayment(
        employeeId: emp.id,
        year: 2026,
        month: 4,
        paymentDate: DateTime(2026, 4, 28),
        basicSalary: 30000,
        bonus: 0,
        deduction: 1500,
        advanceDeduction: 6000,
      );

      // Check payment record
      final payment = await service.getSalaryPaymentById(paymentId);
      expect(payment!.grossSalary, equals(30000));
      expect(payment.totalDeductions, equals(7500)); // 1500 + 6000
      expect(payment.netSalary, equals(22500)); // 30000 - 7500

      // Check advance is settled
      final advance = await db.getSalaryAdvanceById(advanceId);
      expect(advance!.status, equals('settled'));
      expect(advance.adjustedAmount, equals(6000));
      expect(await service.getOutstandingAdvance(emp.id), equals(0));

      // Check adjustment audit link
      final adjustments = await db.getAdjustmentsForPayment(paymentId);
      expect(adjustments.length, equals(1));
      expect(adjustments.first.salaryAdvanceId, equals(advanceId));
      expect(adjustments.first.adjustedAmount, equals(6000));
    });

    test('Multi-term advance adjustment across multiple pay periods', () async {
      final employees = await db.getAllEmployees();
      final emp = employees.first;

      // 1. Give 10,000 advance
      final advanceId = await service.giveSalaryAdvance(
        employeeId: emp.id,
        amount: 10000,
        advanceDate: DateTime(2026, 1, 10),
      );

      // Month 1: Deduct 3,000 installment
      final pay1 = await service.processSalaryPayment(
        employeeId: emp.id,
        year: 2026,
        month: 1,
        paymentDate: DateTime(2026, 1, 28),
        basicSalary: 25000,
        advanceDeduction: 3000,
      );
      expect(pay1, greaterThan(0));

      var adv = await db.getSalaryAdvanceById(advanceId);
      expect(adv!.status, equals('partially_adjusted'));
      expect(adv.adjustedAmount, equals(3000));
      expect(await service.getOutstandingAdvance(emp.id), equals(7000));

      // Month 2: Deduct 4,000 installment
      final pay2 = await service.processSalaryPayment(
        employeeId: emp.id,
        year: 2026,
        month: 2,
        paymentDate: DateTime(2026, 2, 28),
        basicSalary: 25000,
        advanceDeduction: 4000,
      );
      expect(pay2, greaterThan(0));

      adv = await db.getSalaryAdvanceById(advanceId);
      expect(adv!.status, equals('partially_adjusted'));
      expect(adv.adjustedAmount, equals(7000));
      expect(await service.getOutstandingAdvance(emp.id), equals(3000));

      // Month 3: Deduct final 3,000 installment -> settles advance
      final pay3 = await service.processSalaryPayment(
        employeeId: emp.id,
        year: 2026,
        month: 3,
        paymentDate: DateTime(2026, 3, 28),
        basicSalary: 25000,
        advanceDeduction: 3000,
      );
      expect(pay3, greaterThan(0));

      adv = await db.getSalaryAdvanceById(advanceId);
      expect(adv!.status, equals('settled'));
      expect(adv.adjustedAmount, equals(10000));
      expect(await service.getOutstandingAdvance(emp.id), equals(0));
    });

    test('FIFO distribution across multiple open advances', () async {
      final employees = await db.getAllEmployees();
      final emp = employees.first;

      // Advance 1: 4,000 on day 1
      final adv1Id = await service.giveSalaryAdvance(
        employeeId: emp.id,
        amount: 4000,
        advanceDate: DateTime(2026, 1, 5),
      );

      // Advance 2: 6,000 on day 10
      final adv2Id = await service.giveSalaryAdvance(
        employeeId: emp.id,
        amount: 6000,
        advanceDate: DateTime(2026, 1, 10),
      );

      expect(await service.getOutstandingAdvance(emp.id), equals(10000));

      // Disburse salary with 7,000 advance deduction:
      // Should exhaust Advance 1 (4,000) and take 3,000 from Advance 2
      final paymentId = await service.processSalaryPayment(
        employeeId: emp.id,
        year: 2026,
        month: 1,
        paymentDate: DateTime(2026, 1, 28),
        basicSalary: 30000,
        advanceDeduction: 7000,
      );

      final adv1 = await db.getSalaryAdvanceById(adv1Id);
      expect(adv1!.status, equals('settled'));
      expect(adv1.adjustedAmount, equals(4000));

      final adv2 = await db.getSalaryAdvanceById(adv2Id);
      expect(adv2!.status, equals('partially_adjusted'));
      expect(adv2.adjustedAmount, equals(3000));

      expect(await service.getOutstandingAdvance(emp.id), equals(3000));

      // Check 2 adjustments were recorded
      final adjustments = await db.getAdjustmentsForPayment(paymentId);
      expect(adjustments.length, equals(2));
    });

    test(
      'Deleting salary payment restores advance balance (Rollback)',
      () async {
        final employees = await db.getAllEmployees();
        final emp = employees.first;

        final advanceId = await service.giveSalaryAdvance(
          employeeId: emp.id,
          amount: 5000,
          advanceDate: DateTime(2026, 2, 1),
        );

        final paymentId = await service.processSalaryPayment(
          employeeId: emp.id,
          year: 2026,
          month: 2,
          paymentDate: DateTime(2026, 2, 28),
          basicSalary: 25000,
          advanceDeduction: 5000,
        );

        var adv = await db.getSalaryAdvanceById(advanceId);
        expect(adv!.status, equals('settled'));
        expect(adv.adjustedAmount, equals(5000));

        // Delete payment
        await service.deleteSalaryPayment(paymentId);

        // Verify payment was deleted
        final deleted = await service.getSalaryPaymentById(paymentId);
        expect(deleted, isNull);

        // Verify advance was restored to pending and 0 adjusted
        adv = await db.getSalaryAdvanceById(advanceId);
        expect(adv!.status, equals('pending'));
        expect(adv.adjustedAmount, equals(0.0));
        expect(await service.getOutstandingAdvance(emp.id), equals(5000));
      },
    );

    test('Validation rejects deduction exceeding advance or gross', () async {
      final employees = await db.getAllEmployees();
      final emp = employees.first;

      await service.giveSalaryAdvance(
        employeeId: emp.id,
        amount: 2000,
        advanceDate: DateTime(2026, 1, 1),
      );

      // Exceeds available advance (asking 3,000 with only 2,000 advance)
      expect(
        () => service.processSalaryPayment(
          employeeId: emp.id,
          year: 2026,
          month: 1,
          paymentDate: DateTime.now(),
          basicSalary: 20000,
          advanceDeduction: 3000,
        ),
        throwsArgumentError,
      );

      // Total deductions exceed gross
      expect(
        () => service.processSalaryPayment(
          employeeId: emp.id,
          year: 2026,
          month: 1,
          paymentDate: DateTime.now(),
          basicSalary: 10000,
          deduction: 12000,
        ),
        throwsArgumentError,
      );
    });
  });

  group('Payroll Seeder & Reporting Integration Tests', () {
    test(
      'DatabaseSeeder.seedPayroll populates records and is idempotent',
      () async {
        final payments = await service.getSalaryPayments();
        expect(payments.length, greaterThanOrEqualTo(2));

        final advances = await service.getSalaryAdvances();
        expect(advances.length, greaterThanOrEqualTo(2));

        // Verify idempotency
        final paymentsAfter = await service.getSalaryPayments();
        expect(paymentsAfter.length, equals(payments.length));

        // Check summary stats
        final stats = await service.getSummaryStats();
        expect(stats.totalNetPaid, greaterThan(0));
        expect(stats.totalPaymentsCount, equals(payments.length));
        expect(stats.totalOutstandingAdvances, greaterThan(0));
      },
    );
  });

  group('Payroll & Academic Year Integration Tests', () {
    test(
      'Automatically assigns active academic year when none provided',
      () async {
        final employees = await db.getAllEmployees();
        final emp = employees.first;

        // Advance
        final advId = await service.giveSalaryAdvance(
          employeeId: emp.id,
          amount: 3000,
          advanceDate: DateTime.now(),
        );
        expect(advId, greaterThan(0));
        final advList = await service.getSalaryAdvances(employeeId: emp.id);
        expect(advList.first.academicYear, isNotNull);
        expect(advList.first.academicYear!.isCurrent, isTrue);

        // Payment
        final paymentId = await service.processSalaryPayment(
          employeeId: emp.id,
          year: 2026,
          month: 6,
          paymentDate: DateTime.now(),
          basicSalary: 25000,
        );
        final payment = await service.getSalaryPaymentById(paymentId);
        expect(payment, isNotNull);
        expect(payment!.academicYearId, isNotNull);

        final paymentsWithDetails = await service.getSalaryPayments();
        final pDetails = paymentsWithDetails.firstWhere(
          (p) => p.payment.id == paymentId,
        );
        expect(pDetails.academicYear, isNotNull);
        expect(pDetails.academicYear!.isCurrent, isTrue);
      },
    );

    test(
      'Filters salary payments, advances, and summary stats by academic year',
      () async {
        final employees = await db.getAllEmployees();
        final emp = employees.first;
        final allYears = await db.getAllAcademicYears();
        final year1 = allYears[0];
        final year2 = allYears[1];

        // Give advance in Year 1
        await service.giveSalaryAdvance(
          employeeId: emp.id,
          amount: 5000,
          advanceDate: DateTime(2025, 5, 1),
          academicYearId: year1.id,
        );

        // Give advance in Year 2
        await service.giveSalaryAdvance(
          employeeId: emp.id,
          amount: 8000,
          advanceDate: DateTime(2026, 5, 1),
          academicYearId: year2.id,
        );

        // Verify advances filtered by year
        final year1Advances = await service.getSalaryAdvances(
          academicYearId: year1.id,
        );
        expect(year1Advances.length, equals(1));
        expect(year1Advances.first.amount, equals(5000));

        final year2Advances = await service.getSalaryAdvances(
          academicYearId: year2.id,
        );
        expect(year2Advances.length, equals(1));
        expect(year2Advances.first.amount, equals(8000));

        // Make payment in Year 1
        await service.processSalaryPayment(
          employeeId: emp.id,
          year: 2025,
          month: 5,
          paymentDate: DateTime(2025, 5, 28),
          basicSalary: 30000,
          academicYearId: year1.id,
        );

        // Make payment in Year 2
        await service.processSalaryPayment(
          employeeId: emp.id,
          year: 2026,
          month: 5,
          paymentDate: DateTime(2026, 5, 28),
          basicSalary: 35000,
          academicYearId: year2.id,
        );

        // Verify payments filtered by year
        final year1Payments = await service.getSalaryPayments(
          academicYearId: year1.id,
        );
        expect(year1Payments.length, equals(1));
        expect(year1Payments.first.basicSalary, equals(30000));

        final year2Payments = await service.getSalaryPayments(
          academicYearId: year2.id,
        );
        expect(year2Payments.length, equals(1));
        expect(year2Payments.first.basicSalary, equals(35000));

        // Verify summary stats filtered by year
        final statsYear1 = await service.getSummaryStats(
          academicYearId: year1.id,
        );
        expect(statsYear1.totalNetPaid, equals(30000));
        expect(statsYear1.totalPaymentsCount, equals(1));
        expect(statsYear1.totalOutstandingAdvances, equals(5000));

        final statsYear2 = await service.getSummaryStats(
          academicYearId: year2.id,
        );
        expect(statsYear2.totalNetPaid, equals(35000));
        expect(statsYear2.totalPaymentsCount, equals(1));
        expect(statsYear2.totalOutstandingAdvances, equals(8000));
      },
    );
  });
}
