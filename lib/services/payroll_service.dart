import 'dart:math';

import 'package:drift/drift.dart';

import '../data/app_database.dart';

/// Summary statistics for payroll reporting
class PayrollSummaryStats {
  final double totalGross;
  final double totalBonus;
  final double totalStandardDeductions;
  final double totalAdvanceDeductions;
  final double totalNetPaid;
  final int totalPaymentsCount;
  final double totalOutstandingAdvances;
  final int activeAdvancesCount;

  const PayrollSummaryStats({
    required this.totalGross,
    required this.totalBonus,
    required this.totalStandardDeductions,
    required this.totalAdvanceDeductions,
    required this.totalNetPaid,
    required this.totalPaymentsCount,
    required this.totalOutstandingAdvances,
    required this.activeAdvancesCount,
  });

  factory PayrollSummaryStats.empty() {
    return const PayrollSummaryStats(
      totalGross: 0,
      totalBonus: 0,
      totalStandardDeductions: 0,
      totalAdvanceDeductions: 0,
      totalNetPaid: 0,
      totalPaymentsCount: 0,
      totalOutstandingAdvances: 0,
      activeAdvancesCount: 0,
    );
  }
}

class PayrollService {
  final AppDatabase _db;

  PayrollService(this._db);

  // ==========================================
  // SALARY CALCULATION HELPERS
  // ==========================================

  /// Calculate Gross Salary: Basic Salary + Bonus
  static double calculateGrossSalary(double basicSalary, double bonus) {
    return (basicSalary > 0 ? basicSalary : 0.0) + (bonus > 0 ? bonus : 0.0);
  }

  /// Calculate Total Deductions: Standard Deductions + Advance Deductions
  static double calculateTotalDeductions(
    double deduction,
    double advanceDeduction,
  ) {
    return (deduction > 0 ? deduction : 0.0) +
        (advanceDeduction > 0 ? advanceDeduction : 0.0);
  }

  /// Calculate Net Payable Salary: Gross Salary - Total Deductions
  static double calculateNetSalary(
    double basicSalary,
    double bonus,
    double deduction,
    double advanceDeduction,
  ) {
    final gross = calculateGrossSalary(basicSalary, bonus);
    final totalDed = calculateTotalDeductions(deduction, advanceDeduction);
    final net = gross - totalDed;
    return net > 0 ? net : 0.0;
  }

  // ==========================================
  // SALARY PAYMENTS QUERIES
  // ==========================================

  Stream<List<SalaryPaymentWithDetails>> watchSalaryPayments({
    int? year,
    int? month,
    EmployeeType? employeeType,
    String? query,
    int? academicYearId,
  }) {
    return _db.watchSalaryPaymentsWithDetails(
      year: year,
      month: month,
      employeeType: employeeType,
      query: query,
      academicYearId: academicYearId,
    );
  }

  Future<List<SalaryPaymentWithDetails>> getSalaryPayments({
    int? year,
    int? month,
    EmployeeType? employeeType,
    String? query,
    int? academicYearId,
  }) {
    return _db.getSalaryPaymentsWithDetails(
      year: year,
      month: month,
      employeeType: employeeType,
      query: query,
      academicYearId: academicYearId,
    );
  }

  Future<SalaryPayment?> getSalaryPaymentById(int id) {
    return _db.getSalaryPaymentById(id);
  }

  // ==========================================
  // SALARY ADVANCES QUERIES
  // ==========================================

  Stream<List<SalaryAdvanceWithEmployee>> watchSalaryAdvances({
    int? employeeId,
    String? status,
    String? query,
    int? academicYearId,
  }) {
    return _db.watchSalaryAdvancesWithEmployee(
      employeeId: employeeId,
      status: status,
      query: query,
      academicYearId: academicYearId,
    );
  }

  Future<List<SalaryAdvanceWithEmployee>> getSalaryAdvances({
    int? employeeId,
    String? status,
    String? query,
    int? academicYearId,
  }) {
    return _db.getSalaryAdvancesWithEmployee(
      employeeId: employeeId,
      status: status,
      query: query,
      academicYearId: academicYearId,
    );
  }

  /// Get total outstanding advance balance for an employee
  Future<double> getOutstandingAdvance(int employeeId) async {
    final advances = await _db.getPendingAdvancesForEmployee(employeeId);
    double total = 0.0;
    for (final adv in advances) {
      final rem = adv.amount - adv.adjustedAmount;
      if (rem > 0) {
        total += rem;
      }
    }
    return total;
  }

  // ==========================================
  // ADVANCE RECORDING
  // ==========================================

  /// Give salary advance to an employee
  Future<int> giveSalaryAdvance({
    required int employeeId,
    required double amount,
    required DateTime advanceDate,
    String paymentMethod = 'Cash',
    String? referenceNumber,
    String? reason,
    String? notes,
    int? academicYearId,
  }) async {
    if (amount <= 0) {
      throw ArgumentError('Advance amount must be greater than zero');
    }

    final emp = await _db.getEmployeeById(employeeId);
    if (emp == null) {
      throw ArgumentError('Employee with ID $employeeId not found');
    }

    int? resolvedYearId = academicYearId;
    if (resolvedYearId == null) {
      final years = await _db.getAllAcademicYears();
      if (years.isNotEmpty) {
        resolvedYearId =
            years.firstWhere((y) => y.isCurrent, orElse: () => years.first).id;
      }
    }

    return _db.insertSalaryAdvance(
      SalaryAdvancesCompanion(
        employeeId: Value(employeeId),
        amount: Value(amount),
        advanceDate: Value(advanceDate),
        adjustedAmount: const Value(0.0),
        paymentMethod: Value(paymentMethod),
        referenceNumber: Value(referenceNumber),
        reason: Value(reason),
        notes: Value(notes),
        academicYearId: Value(resolvedYearId),
        status: const Value('pending'),
      ),
    );
  }

  // ==========================================
  // SALARY PAYMENT & ADVANCE ADJUSTMENT TRANSACTION
  // ==========================================

  /// Process salary disbursement with automatic multi-term or single-term advance adjustment
  Future<int> processSalaryPayment({
    required int employeeId,
    required int year,
    required int month,
    required DateTime paymentDate,
    required double basicSalary,
    double bonus = 0.0,
    String? bonusReason,
    double deduction = 0.0,
    String? deductionReason,
    double advanceDeduction = 0.0,
    String paymentMethod = 'Bank Transfer',
    String? referenceNumber,
    String status = 'paid',
    String? notes,
    int? academicYearId,
  }) async {
    if (basicSalary <= 0) {
      throw ArgumentError('Basic salary must be greater than zero');
    }
    if (bonus < 0) {
      throw ArgumentError('Bonus cannot be negative');
    }
    if (deduction < 0) {
      throw ArgumentError('Deduction cannot be negative');
    }
    if (advanceDeduction < 0) {
      throw ArgumentError('Advance deduction cannot be negative');
    }

    final grossSalary = calculateGrossSalary(basicSalary, bonus);
    final totalDeductions = calculateTotalDeductions(
      deduction,
      advanceDeduction,
    );
    final netSalary = grossSalary - totalDeductions;

    if (netSalary < 0) {
      throw ArgumentError(
        'Total deductions (standard + advance) cannot exceed gross salary',
      );
    }

    return _db.transaction(() async {
      // 1. Verify and distribute advance deduction if applicable
      final List<Map<String, dynamic>> adjustmentsToRecord = [];

      if (advanceDeduction > 0) {
        final pendingAdvances = await _db.getPendingAdvancesForEmployee(
          employeeId,
        );
        final totalAvailable = pendingAdvances.fold<double>(
          0.0,
          (sum, adv) => sum + max(0.0, adv.amount - adv.adjustedAmount),
        );

        if (advanceDeduction > (totalAvailable + 0.001)) {
          throw ArgumentError(
            'Advance deduction ($advanceDeduction) exceeds total available advance balance ($totalAvailable)',
          );
        }

        double remainingToDeduct = advanceDeduction;

        for (final adv in pendingAdvances) {
          if (remainingToDeduct <= 0.001) break;

          final advRemaining = max(0.0, adv.amount - adv.adjustedAmount);
          if (advRemaining <= 0.001) continue;

          final portion = min(remainingToDeduct, advRemaining);
          final newAdjusted = adv.adjustedAmount + portion;
          final isNowSettled = (adv.amount - newAdjusted) <= 0.001;

          // Update advance status & adjustedAmount
          await _db.updateSalaryAdvanceEntry(
            adv.copyWith(
              adjustedAmount: newAdjusted,
              status: isNowSettled ? 'settled' : 'partially_adjusted',
            ),
          );

          adjustmentsToRecord.add({'advanceId': adv.id, 'amount': portion});

          remainingToDeduct -= portion;
        }
      }

      // 2. Insert SalaryPayment row
      int? resolvedYearId = academicYearId;
      if (resolvedYearId == null) {
        final years = await _db.getAllAcademicYears();
        if (years.isNotEmpty) {
          resolvedYearId =
              years
                  .firstWhere((y) => y.isCurrent, orElse: () => years.first)
                  .id;
        }
      }

      final paymentId = await _db.insertSalaryPayment(
        SalaryPaymentsCompanion(
          employeeId: Value(employeeId),
          academicYearId: Value(resolvedYearId),
          year: Value(year),
          month: Value(month),
          paymentDate: Value(paymentDate),
          basicSalary: Value(basicSalary),
          bonus: Value(bonus),
          bonusReason: Value(bonusReason),
          deduction: Value(deduction),
          deductionReason: Value(deductionReason),
          advanceDeduction: Value(advanceDeduction),
          grossSalary: Value(grossSalary),
          totalDeductions: Value(totalDeductions),
          netSalary: Value(netSalary),
          paymentMethod: Value(paymentMethod),
          referenceNumber: Value(referenceNumber),
          status: Value(status),
          notes: Value(notes),
        ),
      );

      // 3. Record adjustments audit links
      for (final adj in adjustmentsToRecord) {
        await _db.insertSalaryAdvanceAdjustment(
          SalaryAdvanceAdjustmentsCompanion(
            salaryPaymentId: Value(paymentId),
            salaryAdvanceId: Value(adj['advanceId'] as int),
            adjustedAmount: Value(adj['amount'] as double),
          ),
        );
      }

      return paymentId;
    });
  }

  // ==========================================
  // SALARY PAYMENT ROLLBACK / DELETION
  // ==========================================

  /// Delete a salary payment and restore any advance deductions back to the advances
  Future<void> deleteSalaryPayment(int paymentId) async {
    return _db.transaction(() async {
      final adjustments = await _db.getAdjustmentsForPayment(paymentId);

      for (final adj in adjustments) {
        final advance = await _db.getSalaryAdvanceById(adj.salaryAdvanceId);
        if (advance != null) {
          final revertedAdjusted = max(
            0.0,
            advance.adjustedAmount - adj.adjustedAmount,
          );
          final revertedStatus =
              revertedAdjusted <= 0.001 ? 'pending' : 'partially_adjusted';

          await _db.updateSalaryAdvanceEntry(
            advance.copyWith(
              adjustedAmount: revertedAdjusted,
              status: revertedStatus,
            ),
          );
        }
      }

      await _db.deleteAdjustmentsForPayment(paymentId);
      await _db.deleteSalaryPayment(paymentId);
    });
  }

  // ==========================================
  // PAYROLL SUMMARY & STATS
  // ==========================================

  Future<PayrollSummaryStats> getSummaryStats({
    int? year,
    int? month,
    EmployeeType? employeeType,
    int? academicYearId,
  }) async {
    final payments = await _db.getSalaryPaymentsWithDetails(
      year: year,
      month: month,
      employeeType: employeeType,
      academicYearId: academicYearId,
    );

    double gross = 0.0;
    double bonus = 0.0;
    double stdDed = 0.0;
    double advDed = 0.0;
    double net = 0.0;

    for (final p in payments) {
      gross += p.grossSalary;
      bonus += p.bonus;
      stdDed += p.deduction;
      advDed += p.advanceDeduction;
      net += p.netSalary;
    }

    final advances = await _db.getSalaryAdvancesWithEmployee(
      academicYearId: academicYearId,
    );
    double outstanding = 0.0;
    int activeCount = 0;

    for (final a in advances) {
      if (!a.isSettled) {
        outstanding += a.remainingAmount;
        activeCount++;
      }
    }

    return PayrollSummaryStats(
      totalGross: gross,
      totalBonus: bonus,
      totalStandardDeductions: stdDed,
      totalAdvanceDeductions: advDed,
      totalNetPaid: net,
      totalPaymentsCount: payments.length,
      totalOutstandingAdvances: outstanding,
      activeAdvancesCount: activeCount,
    );
  }
}
