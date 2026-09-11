import 'package:drift/drift.dart';
import '../data/app_database.dart';

/// Predefined reporting periods for fee collection
enum FeePeriodType {
  today,
  week,
  month,
  year,
  allTime,
  custom;

  String get label {
    switch (this) {
      case FeePeriodType.today:
        return 'Today';
      case FeePeriodType.week:
        return 'This Week';
      case FeePeriodType.month:
        return 'This Month';
      case FeePeriodType.year:
        return 'This Year';
      case FeePeriodType.allTime:
        return 'All Time';
      case FeePeriodType.custom:
        return 'Custom Range';
    }
  }
}

/// Aggregated fee statistics for reporting and dashboard widgets
class FeeCollectionSummary {
  final double totalCollected;
  final double totalPending;
  final double totalInvoiced;
  final double totalDiscount;
  final int paymentTransactionsCount;
  final int totalFeesCount;
  final int paidFeesCount;
  final int partialFeesCount;
  final int pendingFeesCount;
  final Map<String, ({double invoiced, double paid, double pending})>
  frequencyBreakdown;

  const FeeCollectionSummary({
    required this.totalCollected,
    required this.totalPending,
    required this.totalInvoiced,
    required this.totalDiscount,
    required this.paymentTransactionsCount,
    required this.totalFeesCount,
    required this.paidFeesCount,
    required this.partialFeesCount,
    required this.pendingFeesCount,
    required this.frequencyBreakdown,
  });

  factory FeeCollectionSummary.empty() => const FeeCollectionSummary(
    totalCollected: 0.0,
    totalPending: 0.0,
    totalInvoiced: 0.0,
    totalDiscount: 0.0,
    paymentTransactionsCount: 0,
    totalFeesCount: 0,
    paidFeesCount: 0,
    partialFeesCount: 0,
    pendingFeesCount: 0,
    frequencyBreakdown: {},
  );
}

/// Allocation of payment to a specific student fee
class FeePaymentAllocation {
  final int studentFeeId;
  final double amount;
  final double? discountAmount;
  final String? discountReason;

  const FeePaymentAllocation({
    required this.studentFeeId,
    required this.amount,
    this.discountAmount,
    this.discountReason,
  });
}

/// Request model to dynamically select or create a fee head and record payment
class CreateAndPayFeeItem {
  final int? existingStudentFeeId; // If paying a previously assigned fee
  final int feeCategoryId;
  final String title;
  final double totalAmount;
  final double discountAmount;
  final String? discountReason;
  final double paymentAmount;
  final int? academicMonth;
  final String? academicTerm;
  final DateTime? dueDate;
  final String? notes;

  const CreateAndPayFeeItem({
    this.existingStudentFeeId,
    required this.feeCategoryId,
    required this.title,
    required this.totalAmount,
    this.discountAmount = 0.0,
    this.discountReason,
    required this.paymentAmount,
    this.academicMonth,
    this.academicTerm,
    this.dueDate,
    this.notes,
  });
}

/// Individual item in a consolidated fee receipt
class FeePaymentReceiptItem {
  final int feeId;
  final String title;
  final String categoryName;
  final String frequency;
  final double totalAmount;
  final double discountAmount;
  final double paidInThisReceipt;
  final double remainingDue;
  final String? notes;

  const FeePaymentReceiptItem({
    required this.feeId,
    required this.title,
    required this.categoryName,
    required this.frequency,
    required this.totalAmount,
    required this.discountAmount,
    required this.paidInThisReceipt,
    required this.remainingDue,
    this.notes,
  });

  bool get isFullyPaid => remainingDue <= 0.001;
  double get netAmount => totalAmount - discountAmount;
}

/// Consolidated fee payment receipt representing multiple fee heads paid in a single transaction
class ConsolidatedFeeReceipt {
  final String receiptNumber;
  final DateTime paymentDate;
  final String paymentMethod;
  final String? referenceNumber;
  final String? remarks;
  final String receivedBy;
  final Student student;
  final AcademicYear? academicYear;
  final List<FeePaymentReceiptItem> items;
  final double totalAssessed;
  final double totalDiscount;
  final double totalPaid;
  final double remainingBalance;

  const ConsolidatedFeeReceipt({
    required this.receiptNumber,
    required this.paymentDate,
    required this.paymentMethod,
    this.referenceNumber,
    this.remarks,
    required this.receivedBy,
    required this.student,
    this.academicYear,
    required this.items,
    required this.totalAssessed,
    required this.totalDiscount,
    required this.totalPaid,
    required this.remainingBalance,
  });

  String get studentName => student.name;
  double get totalNet => totalAssessed - totalDiscount;
}

/// Service managing all school fee collection logic and analytics
class FeeService {
  final AppDatabase _db;

  FeeService(this._db);

  // ==================== FEE CATEGORIES ====================

  /// Stream all fee categories
  Stream<List<FeeCategory>> watchFeeCategories() => _db.watchAllFeeCategories();

  /// Get all fee categories
  Future<List<FeeCategory>> getAllFeeCategories() => _db.getAllFeeCategories();

  /// Create a new fee category
  Future<int> createFeeCategory({
    required String name,
    required String frequency,
    double defaultAmount = 0.0,
    String? description,
    bool isSystem = false,
  }) {
    return _db.insertFeeCategory(
      FeeCategoriesCompanion(
        name: Value(name),
        frequency: Value(frequency),
        defaultAmount: Value(defaultAmount),
        description: Value(description),
        isSystem: Value(isSystem),
      ),
    );
  }

  /// Update an existing fee category
  Future<bool> updateFeeCategory(FeeCategory category) =>
      _db.updateFeeCategory(category);

  /// Delete a fee category
  Future<int> deleteFeeCategory(int id) => _db.deleteFeeCategory(id);

  // ==================== STUDENT FEES ====================

  /// Stream student fees with joined details
  Stream<List<StudentFeeWithDetails>> watchStudentFees({
    int? studentId,
    int? academicYearId,
    String? status,
    String? frequency,
    String? query,
  }) {
    return _db.watchStudentFeesWithDetails(
      studentId: studentId,
      academicYearId: academicYearId,
      status: status,
      frequency: frequency,
      query: query,
    );
  }

  /// Get student fees with joined details
  Future<List<StudentFeeWithDetails>> getStudentFees({
    int? studentId,
    int? academicYearId,
    String? status,
    String? frequency,
    String? query,
  }) {
    return _db.getStudentFeesWithDetails(
      studentId: studentId,
      academicYearId: academicYearId,
      status: status,
      frequency: frequency,
      query: query,
    );
  }

  /// Get student fee summary for a specific student
  Future<StudentFeeFinancialSummary> getStudentFeeSummary(
    int studentId, {
    int? academicYearId,
  }) async {
    final fees = await _db.getStudentFeesWithDetails(
      studentId: studentId,
      academicYearId: academicYearId,
    );

    double totalInvoiced = 0.0;
    double totalDiscount = 0.0;
    double totalPaid = 0.0;
    double totalPending = 0.0;
    int paidCount = 0;
    int partialCount = 0;
    int pendingCount = 0;

    for (final f in fees) {
      totalInvoiced += f.totalAmount;
      totalDiscount += f.discountAmount;
      totalPaid += f.paidAmount;
      totalPending += f.remainingAmount;

      if (f.isPaid) {
        paidCount++;
      } else if (f.isPartial) {
        partialCount++;
      } else {
        pendingCount++;
      }
    }

    return StudentFeeFinancialSummary(
      totalInvoiced: totalInvoiced,
      totalDiscount: totalDiscount,
      totalPaid: totalPaid,
      totalPending: totalPending,
      totalFeesCount: fees.length,
      paidFeesCount: paidCount,
      partialFeesCount: partialCount,
      pendingFeesCount: pendingCount,
    );
  }

  /// Assign a new fee to an individual student
  Future<int> assignFeeToStudent({
    required int studentId,
    required int feeCategoryId,
    required String title,
    required double totalAmount,
    double discountAmount = 0.0,
    DateTime? dueDate,
    int? academicYearId,
    int? academicMonth,
    String? academicTerm,
    String? notes,
  }) async {
    int? yearId = academicYearId;
    if (yearId == null) {
      final activeYear = await _db.getActiveAcademicYear();
      yearId = activeYear?.id;
    }

    return _db.insertStudentFee(
      StudentFeesCompanion(
        studentId: Value(studentId),
        academicYearId: Value(yearId),
        feeCategoryId: Value(feeCategoryId),
        title: Value(title.trim()),
        totalAmount: Value(totalAmount),
        discountAmount: Value(discountAmount),
        paidAmount: const Value(0.0),
        dueDate: Value(dueDate),
        status: const Value('pending'),
        academicMonth: Value(academicMonth),
        academicTerm: Value(academicTerm),
        notes: Value(notes?.trim()),
      ),
    );
  }

  /// Bulk assign a fee to all students in a class (and optionally a section)
  Future<int> bulkAssignFeeToClass({
    required int classId,
    int? sectionId,
    required int feeCategoryId,
    required String title,
    required double totalAmount,
    double discountAmount = 0.0,
    DateTime? dueDate,
    int? academicYearId,
    int? academicMonth,
    String? academicTerm,
    String? notes,
  }) async {
    int? yearId = academicYearId;
    if (yearId == null) {
      final activeYear = await _db.getActiveAcademicYear();
      yearId = activeYear?.id;
    }

    // Get all students enrolled in this class/section for the given academic year
    final query = _db.select(_db.studentAcademicHistories).join([
      innerJoin(
        _db.students,
        _db.students.id.equalsExp(_db.studentAcademicHistories.studentId),
      ),
    ]);
    query.where(_db.studentAcademicHistories.classId.equals(classId));
    if (sectionId != null) {
      query.where(_db.studentAcademicHistories.sectionId.equals(sectionId));
    }
    if (yearId != null) {
      query.where(_db.studentAcademicHistories.academicYearId.equals(yearId));
    }

    final rows = await query.get();
    List<Student> targetStudents =
        rows.map((row) => row.readTable(_db.students)).toList();

    // Fallback: check students table directly where classId matches
    if (targetStudents.isEmpty) {
      final fallbackQuery = _db.select(_db.students)
        ..where((s) => s.classId.equals(classId));
      if (sectionId != null) {
        fallbackQuery.where((s) => s.sectionId.equals(sectionId));
      }
      targetStudents = await fallbackQuery.get();
    }

    int count = 0;
    for (final student in targetStudents) {
      await assignFeeToStudent(
        studentId: student.id,
        feeCategoryId: feeCategoryId,
        title: title,
        totalAmount: totalAmount,
        discountAmount: discountAmount,
        dueDate: dueDate,
        academicYearId: yearId,
        academicMonth: academicMonth,
        academicTerm: academicTerm,
        notes: notes,
      );
      count++;
    }
    return count;
  }

  /// Delete a student fee
  Future<int> deleteStudentFee(int feeId) => _db.deleteStudentFee(feeId);

  // ==================== FEE PAYMENTS & RECEIPTS ====================

  /// Stream fee payments with details
  Stream<List<FeePaymentWithDetails>> watchFeePayments({
    int? studentId,
    int? academicYearId,
    DateTime? startDate,
    DateTime? endDate,
    String? query,
  }) {
    return _db.watchFeePaymentsWithDetails(
      studentId: studentId,
      academicYearId: academicYearId,
      startDate: startDate,
      endDate: endDate,
      query: query,
    );
  }

  /// Get fee payments with details
  Future<List<FeePaymentWithDetails>> getFeePayments({
    int? studentId,
    int? academicYearId,
    DateTime? startDate,
    DateTime? endDate,
    String? query,
  }) {
    return _db.getFeePaymentsWithDetails(
      studentId: studentId,
      academicYearId: academicYearId,
      startDate: startDate,
      endDate: endDate,
      query: query,
    );
  }

  /// Record a fee payment (partial, full, or scholarship waiver) against a student fee,
  /// with optional on-the-fly discount/scholarship application.
  Future<FeePayment> recordFeePayment({
    required int studentFeeId,
    required double amount,
    required String paymentMethod,
    String? referenceNumber,
    String? remarks,
    String? receivedBy,
    DateTime? paymentDate,
    int? academicYearId,
    double? discountAmount,
    String? discountReason,
  }) async {
    final fee = await _db.getStudentFeeById(studentFeeId);
    if (fee == null) {
      throw StateError('Student fee with ID $studentFeeId does not exist.');
    }

    final double effectiveDiscount = discountAmount ?? fee.discountAmount;
    if (effectiveDiscount < 0) {
      throw ArgumentError('Discount amount cannot be negative.');
    }
    if (effectiveDiscount > fee.totalAmount + 0.001) {
      throw ArgumentError('Discount amount cannot exceed total fee amount.');
    }

    final netAmount = fee.totalAmount - effectiveDiscount;
    if (fee.paidAmount > netAmount + 0.01) {
      throw ArgumentError(
        'Discount reduces net fee ($netAmount) below already paid amount (${fee.paidAmount}).',
      );
    }

    final remaining = (netAmount - fee.paidAmount).clamp(0.0, double.infinity);

    // If remaining balance is zero (e.g. 100% scholarship waiver), payment amount can be zero
    if (remaining <= 0.01) {
      if (amount < 0 || amount > 0.01) {
        throw ArgumentError(
          'No remaining due. Payment amount must be 0 for full scholarship/waiver.',
        );
      }
    } else {
      if (amount <= 0) {
        throw ArgumentError('Payment amount must be greater than zero.');
      }
      if (amount > remaining + 0.01) {
        throw ArgumentError(
          'Payment amount ($amount) exceeds remaining balance ($remaining).',
        );
      }
    }

    int? yearId = academicYearId ?? fee.academicYearId;
    if (yearId == null) {
      final activeYear = await _db.getActiveAcademicYear();
      yearId = activeYear?.id;
    }

    final now = paymentDate ?? DateTime.now();

    // Generate unique receipt number
    final allPayments = await _db.select(_db.feePayments).get();
    final receiptNum =
        'REC-${now.year}-${(allPayments.length + 1).toString().padLeft(4, '0')}';

    // Format remarks to preserve scholarship attribution if provided
    String formattedRemarks = remarks?.trim() ?? '';
    if (discountReason != null && discountReason.trim().isNotEmpty) {
      final reasonTag = '[Scholarship/Discount: ${discountReason.trim()}]';
      if (formattedRemarks.isNotEmpty) {
        formattedRemarks = '$reasonTag $formattedRemarks';
      } else {
        formattedRemarks = reasonTag;
      }
    }

    return await _db.transaction(() async {
      // 1. Insert fee payment
      final paymentId = await _db.insertFeePayment(
        FeePaymentsCompanion(
          studentFeeId: Value(fee.id),
          studentId: Value(fee.studentId),
          academicYearId: Value(yearId),
          receiptNumber: Value(receiptNum),
          amount: Value(amount),
          paymentDate: Value(now),
          paymentMethod: Value(
            amount == 0 && (paymentMethod.isEmpty || paymentMethod == 'Cash')
                ? 'Scholarship Waiver'
                : paymentMethod,
          ),
          referenceNumber: Value(referenceNumber?.trim()),
          remarks: Value(formattedRemarks.isEmpty ? null : formattedRemarks),
          receivedBy: Value(receivedBy?.trim() ?? 'Cashier'),
        ),
      );

      // 2. Update StudentFee discount, paidAmount & status
      final newPaidAmount = fee.paidAmount + amount;
      final isFull = newPaidAmount >= netAmount - 0.01;
      final newStatus =
          isFull ? 'paid' : (newPaidAmount > 0 ? 'partial' : 'pending');

      String? updatedNotes = fee.notes;
      if (discountReason != null && discountReason.trim().isNotEmpty) {
        final noteTag = 'Scholarship/Discount: ${discountReason.trim()}';
        if (updatedNotes == null || updatedNotes.isEmpty) {
          updatedNotes = noteTag;
        } else if (!updatedNotes.contains(discountReason.trim())) {
          updatedNotes = '$updatedNotes | $noteTag';
        }
      }

      await _db.updateStudentFeeEntry(
        fee.copyWith(
          discountAmount: effectiveDiscount,
          paidAmount: newPaidAmount,
          status: newStatus,
          notes: Value(updatedNotes),
          updatedAt: DateTime.now(),
        ),
      );

      final created = await _db.getFeePaymentById(paymentId);
      return created!;
    });
  }

  /// Update or apply a scholarship/discount directly on a student fee without cash payment
  Future<void> updateFeeDiscount({
    required int studentFeeId,
    required double discountAmount,
    String? reason,
  }) async {
    final fee = await _db.getStudentFeeById(studentFeeId);
    if (fee == null) {
      throw StateError('Student fee with ID $studentFeeId does not exist.');
    }
    if (discountAmount < 0) {
      throw ArgumentError('Discount amount cannot be negative.');
    }
    if (discountAmount > fee.totalAmount + 0.001) {
      throw ArgumentError('Discount cannot exceed total fee amount.');
    }
    final netAmount = fee.totalAmount - discountAmount;
    if (fee.paidAmount > netAmount + 0.01) {
      throw ArgumentError(
        'Discount reduces net fee ($netAmount) below already paid amount (${fee.paidAmount}).',
      );
    }
    final isFull = fee.paidAmount >= netAmount - 0.01;
    final newStatus =
        isFull ? 'paid' : (fee.paidAmount > 0 ? 'partial' : 'pending');

    String? updatedNotes = fee.notes;
    if (reason != null && reason.trim().isNotEmpty) {
      final noteTag = 'Scholarship/Discount: ${reason.trim()}';
      if (updatedNotes == null || updatedNotes.isEmpty) {
        updatedNotes = noteTag;
      } else if (!updatedNotes.contains(reason.trim())) {
        updatedNotes = '$updatedNotes | $noteTag';
      }
    }

    await _db.updateStudentFeeEntry(
      fee.copyWith(
        discountAmount: discountAmount,
        status: newStatus,
        notes: Value(updatedNotes),
        updatedAt: DateTime.now(),
      ),
    );
  }

  /// Delete / Void a fee payment and roll back student fee paid amount & status
  Future<bool> deleteFeePayment(int paymentId) async {
    final payment = await _db.getFeePaymentById(paymentId);
    if (payment == null) return false;

    final fee = await _db.getStudentFeeById(payment.studentFeeId);
    if (fee == null) {
      await _db.deleteFeePayment(paymentId);
      return true;
    }

    return await _db.transaction(() async {
      // 1. Revert paid amount on fee
      final newPaid = (fee.paidAmount - payment.amount).clamp(
        0.0,
        double.infinity,
      );
      final netAmount = fee.totalAmount - fee.discountAmount;

      String newStatus;
      if (newPaid <= 0.001) {
        newStatus = 'pending';
      } else if (newPaid >= netAmount - 0.01) {
        newStatus = 'paid';
      } else {
        newStatus = 'partial';
      }

      await _db.updateStudentFeeEntry(
        fee.copyWith(
          paidAmount: newPaid,
          status: newStatus,
          updatedAt: DateTime.now(),
        ),
      );

      // 2. Delete payment entry
      await _db.deleteFeePayment(paymentId);
      return true;
    });
  }

  /// Record payment across multiple student fees simultaneously in an atomic transaction
  /// and issue a single consolidated receipt.
  Future<ConsolidatedFeeReceipt> recordMultipleFeePayments({
    required int studentId,
    required List<FeePaymentAllocation> allocations,
    required String paymentMethod,
    String? referenceNumber,
    String? remarks,
    String? receivedBy,
    DateTime? paymentDate,
    int? academicYearId,
  }) async {
    if (allocations.isEmpty) {
      throw ArgumentError('At least one fee allocation is required.');
    }

    final student =
        await (_db.select(_db.students)
          ..where((s) => s.id.equals(studentId))).getSingleOrNull();
    if (student == null) {
      throw StateError('Student with ID $studentId does not exist.');
    }

    int? yearId = academicYearId;
    if (yearId == null) {
      final activeYear = await _db.getActiveAcademicYear();
      yearId = activeYear?.id;
    }
    AcademicYear? academicYearObj;
    if (yearId != null) {
      final allYears = await _db.getAllAcademicYears();
      academicYearObj = allYears.firstWhere(
        (y) => y.id == yearId,
        orElse: () => allYears.first,
      );
    }

    final now = paymentDate ?? DateTime.now();

    // Generate unified receipt number
    final allPayments = await _db.select(_db.feePayments).get();
    final receiptNum =
        'REC-${now.year}-${(allPayments.length + 1).toString().padLeft(4, '0')}';

    return await _db.transaction(() async {
      final List<FeePaymentReceiptItem> receiptItems = [];
      double totalAssessed = 0.0;
      double totalDiscount = 0.0;
      double totalPaid = 0.0;
      double totalRemaining = 0.0;

      for (int i = 0; i < allocations.length; i++) {
        final alloc = allocations[i];
        final fee = await _db.getStudentFeeById(alloc.studentFeeId);
        if (fee == null) {
          throw StateError('Fee with ID ${alloc.studentFeeId} does not exist.');
        }

        final double effectiveDiscount =
            alloc.discountAmount ?? fee.discountAmount;
        if (effectiveDiscount < 0) {
          throw ArgumentError('Discount amount cannot be negative.');
        }
        if (effectiveDiscount > fee.totalAmount + 0.001) {
          throw ArgumentError('Discount cannot exceed fee amount.');
        }

        final netAmount = fee.totalAmount - effectiveDiscount;
        if (fee.paidAmount > netAmount + 0.01) {
          throw ArgumentError(
            'Discount reduces net fee ($netAmount) below already paid (${fee.paidAmount}).',
          );
        }

        final remaining = (netAmount - fee.paidAmount).clamp(
          0.0,
          double.infinity,
        );

        if (remaining <= 0.01) {
          if (alloc.amount < 0 || alloc.amount > 0.01) {
            throw ArgumentError(
              'No remaining due. Payment amount must be 0 for full waiver.',
            );
          }
        } else {
          if (alloc.amount < 0) {
            throw ArgumentError('Payment amount must be >= 0.');
          }
          if (alloc.amount > remaining + 0.01) {
            throw ArgumentError(
              'Payment amount (${alloc.amount}) exceeds remaining balance ($remaining).',
            );
          }
        }

        // Remarks formatting
        String formattedRemarks = remarks?.trim() ?? '';
        if (alloc.discountReason != null &&
            alloc.discountReason!.trim().isNotEmpty) {
          final tag = '[Scholarship: ${alloc.discountReason!.trim()}]';
          formattedRemarks =
              formattedRemarks.isNotEmpty ? '$tag $formattedRemarks' : tag;
        }

        final itemReceiptNum = receiptNum;

        await _db.insertFeePayment(
          FeePaymentsCompanion(
            studentFeeId: Value(fee.id),
            studentId: Value(student.id),
            academicYearId: Value(yearId),
            receiptNumber: Value(itemReceiptNum),
            amount: Value(alloc.amount),
            paymentDate: Value(now),
            paymentMethod: Value(
              alloc.amount == 0 &&
                      (paymentMethod.isEmpty || paymentMethod == 'Cash')
                  ? 'Scholarship Waiver'
                  : paymentMethod,
            ),
            referenceNumber: Value(referenceNumber?.trim()),
            remarks: Value(formattedRemarks.isEmpty ? null : formattedRemarks),
            receivedBy: Value(receivedBy?.trim() ?? 'Cashier'),
          ),
        );

        final newPaid = fee.paidAmount + alloc.amount;
        final isFull = newPaid >= netAmount - 0.01;
        final newStatus =
            isFull ? 'paid' : (newPaid > 0 ? 'partial' : 'pending');

        String? updatedNotes = fee.notes;
        if (alloc.discountReason != null &&
            alloc.discountReason!.trim().isNotEmpty) {
          final tag = 'Scholarship: ${alloc.discountReason!.trim()}';
          if (updatedNotes == null || updatedNotes.isEmpty) {
            updatedNotes = tag;
          } else if (!updatedNotes.contains(alloc.discountReason!.trim())) {
            updatedNotes = '$updatedNotes | $tag';
          }
        }

        await _db.updateStudentFeeEntry(
          fee.copyWith(
            discountAmount: effectiveDiscount,
            paidAmount: newPaid,
            status: newStatus,
            notes: Value(updatedNotes),
            updatedAt: DateTime.now(),
          ),
        );

        final cat = await _db.getFeeCategoryById(fee.feeCategoryId);
        final itemRemaining = (netAmount - newPaid).clamp(0.0, double.infinity);

        totalAssessed += fee.totalAmount;
        totalDiscount += effectiveDiscount;
        totalPaid += alloc.amount;
        totalRemaining += itemRemaining;

        receiptItems.add(
          FeePaymentReceiptItem(
            feeId: fee.id,
            title: fee.title,
            categoryName: cat?.name ?? 'General Fee',
            frequency: cat?.frequency ?? 'one_time',
            totalAmount: fee.totalAmount,
            discountAmount: effectiveDiscount,
            paidInThisReceipt: alloc.amount,
            remainingDue: itemRemaining,
            notes: updatedNotes,
          ),
        );
      }

      return ConsolidatedFeeReceipt(
        receiptNumber: receiptNum,
        paymentDate: now,
        paymentMethod: paymentMethod,
        referenceNumber: referenceNumber,
        remarks: remarks,
        receivedBy: receivedBy?.trim() ?? 'Cashier',
        student: student,
        academicYear: academicYearObj,
        items: receiptItems,
        totalAssessed: totalAssessed,
        totalDiscount: totalDiscount,
        totalPaid: totalPaid,
        remainingBalance: totalRemaining,
      );
    });
  }

  /// Retrieve the full consolidated receipt for a given receipt number (or prefix)
  /// grouping all items paid together in that transaction.
  Future<ConsolidatedFeeReceipt?> getConsolidatedReceiptByNumber(
    String receiptNumber,
  ) async {
    final parts = receiptNumber.split('-');
    // If format is REC-YYYY-XXXX-suffix (more than 3 parts), strip the child suffix
    final cleanNum =
        parts.length > 3 ? parts.sublist(0, 3).join('-') : receiptNumber;

    final payments =
        await (_db.select(_db.feePayments)..where(
          (p) =>
              p.receiptNumber.equals(cleanNum) |
              p.receiptNumber.like('$cleanNum-%'),
        )).get();

    if (payments.isEmpty) return null;

    final firstPay = payments.first;
    final student =
        await (_db.select(_db.students)
          ..where((s) => s.id.equals(firstPay.studentId))).getSingleOrNull();
    if (student == null) return null;

    AcademicYear? academicYearObj;
    if (firstPay.academicYearId != null) {
      final years = await _db.getAllAcademicYears();
      academicYearObj = years.firstWhere(
        (y) => y.id == firstPay.academicYearId,
        orElse: () => years.first,
      );
    }

    final List<FeePaymentReceiptItem> items = [];
    double totalAssessed = 0.0;
    double totalDiscount = 0.0;
    double totalPaid = 0.0;
    double totalRemaining = 0.0;

    for (final pay in payments) {
      final fee = await _db.getStudentFeeById(pay.studentFeeId);
      if (fee != null) {
        final cat = await _db.getFeeCategoryById(fee.feeCategoryId);
        final net = fee.totalAmount - fee.discountAmount;
        final rem = (net - fee.paidAmount).clamp(0.0, double.infinity);

        totalAssessed += fee.totalAmount;
        totalDiscount += fee.discountAmount;
        totalPaid += pay.amount;
        totalRemaining += rem;

        items.add(
          FeePaymentReceiptItem(
            feeId: fee.id,
            title: fee.title,
            categoryName: cat?.name ?? 'Fee',
            frequency: cat?.frequency ?? 'one_time',
            totalAmount: fee.totalAmount,
            discountAmount: fee.discountAmount,
            paidInThisReceipt: pay.amount,
            remainingDue: rem,
            notes: pay.remarks,
          ),
        );
      }
    }

    return ConsolidatedFeeReceipt(
      receiptNumber: cleanNum,
      paymentDate: firstPay.paymentDate,
      paymentMethod: firstPay.paymentMethod,
      referenceNumber: firstPay.referenceNumber,
      remarks: firstPay.remarks,
      receivedBy: firstPay.receivedBy ?? 'Cashier',
      student: student,
      academicYear: academicYearObj,
      items: items,
      totalAssessed: totalAssessed,
      totalDiscount: totalDiscount,
      totalPaid: totalPaid,
      remainingBalance: totalRemaining,
    );
  }

  /// Ensures that standard generic fee categories exist (School Fee, Transport, Hostel, Library, etc.)
  Future<List<FeeCategory>> ensureStandardFeeCategories() async {
    final existing = await getAllFeeCategories();
    final List<
      ({
        String name,
        String frequency,
        double defaultAmount,
        String description,
      })
    >
    standard = [
      (
        name: 'Monthly Tuition / School Fee',
        frequency: 'monthly',
        defaultAmount: 2500.0,
        description: 'Standard monthly class tuition and school fee',
      ),
      (
        name: 'Transport Fee',
        frequency: 'monthly',
        defaultAmount: 1500.0,
        description: 'School bus / van transportation service fee',
      ),
      (
        name: 'Hostel Fee',
        frequency: 'monthly',
        defaultAmount: 4000.0,
        description: 'Boarding and hostel accommodation fee',
      ),
      (
        name: 'Library Fee',
        frequency: 'yearly',
        defaultAmount: 1000.0,
        description: 'Library access, books, and digital catalogue fee',
      ),
      (
        name: 'Admission Fee',
        frequency: 'one_time',
        defaultAmount: 5000.0,
        description: 'One-time admission charge for new students',
      ),
      (
        name: 'Uniform & Dress',
        frequency: 'one_time',
        defaultAmount: 3500.0,
        description: 'School dress, sports kit, and badge',
      ),
      (
        name: 'Book & Stationery Fee',
        frequency: 'yearly',
        defaultAmount: 2500.0,
        description: 'Textbooks, notebooks, and study materials',
      ),
      (
        name: 'Examination Fee',
        frequency: 'term_wise',
        defaultAmount: 800.0,
        description: 'Terminal exam question papers and evaluation',
      ),
      (
        name: 'Computer & Lab Fee',
        frequency: 'yearly',
        defaultAmount: 1200.0,
        description: 'Computer lab and science practical charges',
      ),
      (
        name: 'Sports & Extracurricular',
        frequency: 'yearly',
        defaultAmount: 500.0,
        description: 'Annual sports meet and co-curricular charges',
      ),
    ];

    for (final s in standard) {
      final exists = existing.any(
        (c) => c.name.toLowerCase() == s.name.toLowerCase(),
      );
      if (!exists) {
        await createFeeCategory(
          name: s.name,
          frequency: s.frequency,
          defaultAmount: s.defaultAmount,
          description: s.description,
        );
      }
    }

    return getAllFeeCategories();
  }

  /// Creates multiple student fee heads dynamically and records payments simultaneously
  /// in a single transaction with the exact same receipt number.
  Future<ConsolidatedFeeReceipt> createAndPayStudentFees({
    required int studentId,
    required int academicYearId,
    required List<CreateAndPayFeeItem> feeItems,
    required String paymentMethod,
    String? referenceNumber,
    String? remarks,
    String? receivedBy,
    DateTime? paymentDate,
  }) async {
    if (feeItems.isEmpty) {
      throw ArgumentError('At least one fee item must be provided');
    }

    final payDate = paymentDate ?? DateTime.now();
    final allPayments = await _db.select(_db.feePayments).get();
    final receiptNum =
        'REC-${payDate.year}-${(allPayments.length + 1).toString().padLeft(4, '0')}';

    return _db.transaction(() async {
      final List<FeePaymentReceiptItem> receiptItems = [];
      double totalAssessed = 0.0;
      double totalDiscount = 0.0;
      double totalPaid = 0.0;
      double totalRemaining = 0.0;

      for (final item in feeItems) {
        final netAmount = (item.totalAmount - item.discountAmount).clamp(
          0.0,
          double.infinity,
        );
        final payingAmount = item.paymentAmount.clamp(0.0, netAmount);
        final remAfterPayment = (netAmount - payingAmount).clamp(
          0.0,
          double.infinity,
        );

        int feeId;
        if (item.existingStudentFeeId != null) {
          feeId = item.existingStudentFeeId!;
          final existing = await _db.getStudentFeeById(feeId);
          if (existing != null) {
            final effectiveDiscount =
                item.discountAmount > 0
                    ? item.discountAmount
                    : existing.discountAmount;
            final newPaid = existing.paidAmount + payingAmount;
            final itemNet = (existing.totalAmount - effectiveDiscount).clamp(
              0.0,
              double.infinity,
            );
            final newStatus =
                newPaid >= itemNet
                    ? 'paid'
                    : (newPaid > 0 ? 'partial' : 'pending');
            await _db.updateStudentFeeEntry(
              existing.copyWith(
                discountAmount: effectiveDiscount,
                paidAmount: newPaid,
                status: newStatus,
                updatedAt: DateTime.now(),
              ),
            );
          }
        } else {
          final status =
              payingAmount >= netAmount
                  ? 'paid'
                  : payingAmount > 0
                  ? 'partial'
                  : 'pending';

          feeId = await _db.insertStudentFee(
            StudentFeesCompanion(
              studentId: Value(studentId),
              academicYearId: Value(academicYearId),
              feeCategoryId: Value(item.feeCategoryId),
              title: Value(item.title.trim()),
              totalAmount: Value(item.totalAmount),
              discountAmount: Value(item.discountAmount),
              paidAmount: Value(payingAmount),
              status: Value(status),
              academicMonth: Value(item.academicMonth),
              academicTerm: Value(item.academicTerm),
              dueDate: Value(item.dueDate),
              notes: Value(
                item.discountReason != null &&
                        item.discountReason!.trim().isNotEmpty
                    ? (item.notes != null
                        ? '${item.notes} • Discount: ${item.discountReason}'
                        : 'Discount: ${item.discountReason}')
                    : item.notes,
              ),
            ),
          );
        }

        if (payingAmount > 0) {
          await _db.insertFeePayment(
            FeePaymentsCompanion(
              studentFeeId: Value(feeId),
              studentId: Value(studentId),
              academicYearId: Value(academicYearId),
              receiptNumber: Value(receiptNum),
              amount: Value(payingAmount),
              paymentDate: Value(payDate),
              paymentMethod: Value(paymentMethod),
              referenceNumber: Value(referenceNumber),
              remarks: Value(remarks ?? item.discountReason),
              receivedBy: Value(receivedBy ?? 'Cashier'),
            ),
          );
        }

        final cat = await _db.getFeeCategoryById(item.feeCategoryId);

        totalAssessed += item.totalAmount;
        totalDiscount += item.discountAmount;
        totalPaid += payingAmount;
        totalRemaining += remAfterPayment;

        receiptItems.add(
          FeePaymentReceiptItem(
            feeId: feeId,
            title: item.title,
            categoryName: cat?.name ?? 'Fee',
            frequency: cat?.frequency ?? 'monthly',
            totalAmount: item.totalAmount,
            discountAmount: item.discountAmount,
            paidInThisReceipt: payingAmount,
            remainingDue: remAfterPayment,
            notes: item.discountReason,
          ),
        );
      }

      final student =
          await (_db.select(_db.students)
            ..where((s) => s.id.equals(studentId))).getSingle();
      final years = await _db.getAllAcademicYears();
      final academicYear = years.firstWhere(
        (y) => y.id == academicYearId,
        orElse: () => years.first,
      );

      return ConsolidatedFeeReceipt(
        receiptNumber: receiptNum,
        paymentDate: payDate,
        paymentMethod: paymentMethod,
        referenceNumber: referenceNumber,
        remarks: remarks,
        receivedBy: receivedBy ?? 'Cashier',
        student: student,
        academicYear: academicYear,
        items: receiptItems,
        totalAssessed: totalAssessed,
        totalDiscount: totalDiscount,
        totalPaid: totalPaid,
        remainingBalance: totalRemaining,
      );
    });
  }

  /// Assess standard class fees for a newly admitted or enrolled student
  /// based on generic class fee categories (Admission Fee, Dress Fee, Book Fee, School Fee).
  Future<List<int>> assessAdmissionPackageForStudent({
    required int studentId,
    required int academicYearId,
    String schoolFeeFrequency = 'monthly',
    double? customAdmissionFee,
    double? customDressFee,
    double? customBookFee,
    double? customSchoolFee,
    double defaultDiscount = 0.0,
    DateTime? dueDate,
  }) async {
    final allCats = await getAllFeeCategories();

    // 1. Admission Fee (one_time)
    FeeCategory? admissionCat = allCats.cast<FeeCategory?>().firstWhere(
      (c) => c!.name.toLowerCase().contains('admission'),
      orElse: () => null,
    );
    int admissionCatId =
        admissionCat?.id ??
        await createFeeCategory(
          name: 'Admission Fee',
          frequency: 'one_time',
          defaultAmount: 5000.0,
          description: 'One-time admission charge for new students',
        );
    double admissionAmt =
        customAdmissionFee ?? admissionCat?.defaultAmount ?? 5000.0;

    // 2. Uniform & Dress Fee (one_time)
    FeeCategory? dressCat = allCats.cast<FeeCategory?>().firstWhere(
      (c) =>
          c!.name.toLowerCase().contains('dress') ||
          c.name.toLowerCase().contains('uniform'),
      orElse: () => null,
    );
    int dressCatId =
        dressCat?.id ??
        await createFeeCategory(
          name: 'Uniform & Dress',
          frequency: 'one_time',
          defaultAmount: 3500.0,
          description: 'School dress and uniform set',
        );
    double dressAmt = customDressFee ?? dressCat?.defaultAmount ?? 3500.0;

    // 3. Book & Stationery Fee (one_time or yearly)
    FeeCategory? bookCat = allCats.cast<FeeCategory?>().firstWhere(
      (c) => c!.name.toLowerCase().contains('book'),
      orElse: () => null,
    );
    int bookCatId =
        bookCat?.id ??
        await createFeeCategory(
          name: 'Book & Stationery Fee',
          frequency: 'yearly',
          defaultAmount: 2500.0,
          description: 'Textbooks, notebooks, and materials',
        );
    double bookAmt = customBookFee ?? bookCat?.defaultAmount ?? 2500.0;

    // 4. School / Tuition Fee (frequency chosen)
    FeeCategory? tuitionCat = allCats.cast<FeeCategory?>().firstWhere(
      (c) =>
          c!.name.toLowerCase().contains('tuition') ||
          c.name.toLowerCase().contains('school fee'),
      orElse: () => null,
    );
    int tuitionCatId =
        tuitionCat?.id ??
        await createFeeCategory(
          name: 'Monthly Tuition Fee',
          frequency: 'monthly',
          defaultAmount: 2500.0,
          description: 'Academic tuition and school charges',
        );
    double baseTuition = customSchoolFee ?? tuitionCat?.defaultAmount ?? 2500.0;

    double tuitionTotal;
    String tuitionTitle;
    String tuitionTerm;
    int tuitionMonth = 1;

    switch (schoolFeeFrequency.toLowerCase()) {
      case 'quarterly':
        tuitionTotal = baseTuition * 3;
        tuitionTitle = 'School Fee - Quarter 1 (Months 1-3)';
        tuitionTerm = 'Q1';
        break;
      case 'half_yearly':
        tuitionTotal = baseTuition * 6;
        tuitionTitle = 'School Fee - Half Yearly 1 (Months 1-6)';
        tuitionTerm = 'H1';
        break;
      case 'yearly':
        tuitionTotal = baseTuition * 12;
        tuitionTitle = 'School Fee - Annual (Months 1-12)';
        tuitionTerm = 'Yearly';
        break;
      case 'monthly':
      default:
        tuitionTotal = baseTuition;
        tuitionTitle = 'School Fee - Baishakh (Month 1)';
        tuitionTerm = 'Month 1';
        break;
    }

    final feeIds = <int>[];

    // Create Admission Fee
    feeIds.add(
      await assignFeeToStudent(
        studentId: studentId,
        feeCategoryId: admissionCatId,
        title: 'Admission Fee',
        totalAmount: admissionAmt,
        discountAmount: defaultDiscount,
        dueDate: dueDate,
        academicYearId: academicYearId,
        notes: 'New enrollment admission fee',
      ),
    );

    // Create Dress Fee
    feeIds.add(
      await assignFeeToStudent(
        studentId: studentId,
        feeCategoryId: dressCatId,
        title: 'Uniform & Dress Fee',
        totalAmount: dressAmt,
        dueDate: dueDate,
        academicYearId: academicYearId,
        notes: 'Standard school uniform package',
      ),
    );

    // Create Book Fee
    feeIds.add(
      await assignFeeToStudent(
        studentId: studentId,
        feeCategoryId: bookCatId,
        title: 'Book & Stationery Fee',
        totalAmount: bookAmt,
        dueDate: dueDate,
        academicYearId: academicYearId,
        notes: 'Curriculum books and stationery package',
      ),
    );

    // Create School Fee
    feeIds.add(
      await assignFeeToStudent(
        studentId: studentId,
        feeCategoryId: tuitionCatId,
        title: tuitionTitle,
        totalAmount: tuitionTotal,
        dueDate: dueDate,
        academicYearId: academicYearId,
        academicMonth: tuitionMonth,
        academicTerm: tuitionTerm,
        notes: 'Initial school fee ($schoolFeeFrequency billing)',
      ),
    );

    return feeIds;
  }

  /// Checks whether a student's school fee is already covered/paid for a specific academic month (1-12)
  Future<bool> isStudentSchoolFeeCovered({
    required int studentId,
    required int academicYearId,
    required int academicMonth,
  }) async {
    final fees = await _db.getStudentFeesWithDetails(
      studentId: studentId,
      academicYearId: academicYearId,
    );

    for (final f in fees) {
      if (!f.isPaid) continue;

      final isSchoolFee =
          f.category.name.toLowerCase().contains('tuition') ||
          f.category.name.toLowerCase().contains('school fee') ||
          f.title.toLowerCase().contains('tuition') ||
          f.title.toLowerCase().contains('school fee');

      if (!isSchoolFee) continue;

      final term = (f.fee.academicTerm ?? '').toLowerCase();
      final title = f.title.toLowerCase();
      final freq = f.frequency.toLowerCase();

      // 1. Direct month match
      if (f.fee.academicMonth == academicMonth) {
        return true;
      }

      // 2. Quarterly check (Q1 covers 1..3, Q2 covers 4..6, Q3 covers 7..9, Q4 covers 10..12)
      if (freq == 'quarterly' ||
          term.contains('q1') ||
          term.contains('q2') ||
          term.contains('q3') ||
          term.contains('q4') ||
          title.contains('quarter') ||
          title.contains('q1') ||
          title.contains('q2') ||
          title.contains('q3') ||
          title.contains('q4')) {
        final startM = f.fee.academicMonth ?? 1;
        if (academicMonth >= startM && academicMonth <= startM + 2) {
          return true;
        }
        final qIndex = ((academicMonth - 1) ~/ 3) + 1;
        if (term.contains('q$qIndex') || title.contains('q$qIndex')) {
          return true;
        }
      }

      // 3. Half-Yearly check (H1 covers 1..6, H2 covers 7..12)
      if (freq == 'half_yearly' ||
          term.contains('h1') ||
          term.contains('h2') ||
          term.contains('half') ||
          title.contains('half')) {
        final startM = f.fee.academicMonth ?? 1;
        if (academicMonth >= startM && academicMonth <= startM + 5) {
          return true;
        }
        final hIndex = academicMonth <= 6 ? 1 : 2;
        if (term.contains('h$hIndex') || title.contains('h$hIndex')) {
          return true;
        }
      }

      // 4. Yearly check (covers 1..12)
      if (freq == 'yearly' ||
          term.contains('year') ||
          term.contains('annual') ||
          title.contains('annual') ||
          title.contains('year')) {
        return true;
      }
    }

    return false;
  }

  // ==================== ANALYTICS & SUMMARY ====================

  /// Compute fee collection metrics for any time period (Today, This Week, This Month, This Year, All-Time)
  Future<FeeCollectionSummary> getFeeCollectionSummary({
    int? academicYearId,
    FeePeriodType period = FeePeriodType.allTime,
    int? studentId,
    DateTime? customStart,
    DateTime? customEnd,
  }) async {
    final range = _getDateRangeForPeriod(
      period,
      customStart: customStart,
      customEnd: customEnd,
    );

    // 1. Fetch payments in the date range
    final payments = await _db.getFeePaymentsWithDetails(
      studentId: studentId,
      academicYearId: academicYearId,
      startDate: range.start,
      endDate: range.end,
    );

    double totalCollected = 0.0;
    for (final p in payments) {
      totalCollected += p.amount;
    }

    // 2. Fetch all student fees for receivables and frequency breakdown
    final fees = await _db.getStudentFeesWithDetails(
      studentId: studentId,
      academicYearId: academicYearId,
    );

    double totalInvoiced = 0.0;
    double totalDiscount = 0.0;
    double totalPending = 0.0;
    int paidCount = 0;
    int partialCount = 0;
    int pendingCount = 0;

    final freqMap =
        <String, ({double invoiced, double paid, double pending})>{};

    for (final f in fees) {
      totalInvoiced += f.totalAmount;
      totalDiscount += f.discountAmount;
      totalPending += f.remainingAmount;

      if (f.isPaid) {
        paidCount++;
      } else if (f.isPartial) {
        partialCount++;
      } else {
        pendingCount++;
      }

      final freq = f.frequency;
      final prev = freqMap[freq] ?? (invoiced: 0.0, paid: 0.0, pending: 0.0);
      freqMap[freq] = (
        invoiced: prev.invoiced + f.totalAmount,
        paid: prev.paid + f.paidAmount,
        pending: prev.pending + f.remainingAmount,
      );
    }

    return FeeCollectionSummary(
      totalCollected: totalCollected,
      totalPending: totalPending,
      totalInvoiced: totalInvoiced,
      totalDiscount: totalDiscount,
      paymentTransactionsCount: payments.length,
      totalFeesCount: fees.length,
      paidFeesCount: paidCount,
      partialFeesCount: partialCount,
      pendingFeesCount: pendingCount,
      frequencyBreakdown: freqMap,
    );
  }

  /// Calculates start and end timestamps based on FeePeriodType
  ({DateTime? start, DateTime? end}) _getDateRangeForPeriod(
    FeePeriodType period, {
    DateTime? customStart,
    DateTime? customEnd,
  }) {
    final now = DateTime.now();
    switch (period) {
      case FeePeriodType.today:
        final start = DateTime(now.year, now.month, now.day);
        final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
        return (start: start, end: end);

      case FeePeriodType.week:
        final weekday = now.weekday; // 1 = Monday, 7 = Sunday
        final monday = now.subtract(Duration(days: weekday - 1));
        final start = DateTime(monday.year, monday.month, monday.day);
        final sunday = monday.add(const Duration(days: 6));
        final end = DateTime(
          sunday.year,
          sunday.month,
          sunday.day,
          23,
          59,
          59,
          999,
        );
        return (start: start, end: end);

      case FeePeriodType.month:
        final start = DateTime(now.year, now.month, 1);
        final lastDay = DateTime(now.year, now.month + 1, 0).day;
        final end = DateTime(now.year, now.month, lastDay, 23, 59, 59, 999);
        return (start: start, end: end);

      case FeePeriodType.year:
        final start = DateTime(now.year, 1, 1);
        final end = DateTime(now.year, 12, 31, 23, 59, 59, 999);
        return (start: start, end: end);

      case FeePeriodType.allTime:
        return (start: null, end: null);

      case FeePeriodType.custom:
        return (start: customStart, end: customEnd);
    }
  }
}
