import 'package:flutter/foundation.dart' show immutable;
import 'package:hooks_riverpod/hooks_riverpod.dart' show Provider;
import 'package:intl/intl.dart' show DateFormat;
import 'package:isar/isar.dart' show Isar, QueryExecute;

import '../models/salary_model.dart';
import '../models/salary_status.dart';
import '../models/staff_model.dart';
import 'isar_service.dart' show isarServiceProvider;

@immutable
class SalaryService {
  final Isar isar;
  const SalaryService(this.isar);

  /// get all staff salaries for a given month
  Future<List<SalaryStatus>> getStaffSalariesForMonth(DateTime data) async {
    try {
      final salaryMonth = DateFormat('yyyy-MM').format(data);
      final staffList = await isar.staffModels.where().findAll();

      final List<SalaryStatus> result = [];

      for (final staff in staffList) {
        final salaryEntry =
            await isar.salaryModels
                .filter()
                .staffIdEqualTo(staff.id)
                .salaryMonthEqualTo(salaryMonth)
                .findFirst();

        result.add(
          SalaryStatus(
            fullName: staff.fullName,
            phoneNumber: staff.phoneNumber,
            salary: staff.salary,
            isPaid: salaryEntry?.isPaid ?? false,
            paymentDate: salaryEntry?.paymentDate,
          ),
        );
      }

      return result;
    } catch (e) {
      throw e.toString();
    }
  }

  /// update salary for individual staff
  Future<void> updateSalaryForIndividualStaff({
    required SalaryStatus staff,
    required DateTime selectedDate,
  }) async {
    try {
      final salaryMonth = DateFormat('yyyy-MM').format(selectedDate);

      final staffRecord =
          await isar.staffModels
              .filter()
              .phoneNumberEqualTo(staff.phoneNumber)
              .findFirst();

      if (staffRecord != null) {
        await isar.writeTxn(() async {
          final salaryEntry =
              await isar.salaryModels
                  .filter()
                  .staffIdEqualTo(staffRecord.id)
                  .salaryMonthEqualTo(salaryMonth)
                  .findFirst();

          if (salaryEntry != null) {
            salaryEntry
              ..isPaid = true
              ..paymentDate = DateTime.now().toIso8601String()
              ..updatedBy = 1
              ..updatedAt = DateTime.now().toIso8601String();
            await isar.salaryModels.put(salaryEntry);
          } else {
            final newSalary =
                SalaryModel()
                  ..staffId = staffRecord.id
                  ..salaryMonth = salaryMonth
                  ..amountPaid = staff.salary
                  ..isPaid = true
                  ..paymentDate = DateTime.now().toIso8601String()
                  ..createdBy = 1
                  ..createdAt = DateTime.now().toIso8601String();
            await isar.salaryModels.put(newSalary);
          }
        });
      }
    } catch (e) {
      throw e.toString();
    }
  }
}

final salaryServiceProvider = Provider((ref) {
  final isar = ref.read(isarServiceProvider).instance;
  return SalaryService(isar);
});
