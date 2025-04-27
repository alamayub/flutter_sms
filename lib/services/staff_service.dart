import 'package:flutter/foundation.dart' show immutable;
import 'package:hooks_riverpod/hooks_riverpod.dart' show Provider;
import 'package:isar/isar.dart' show Isar, QueryExecute;

import '../models/staff_model.dart';
import 'isar_service.dart' show isarServiceProvider;

@immutable
class StaffService {
  final Isar isar;
  const StaffService(this.isar);

  // get all staffs
  Future<List<StaffModel>> getAllStaffs() async {
    try {
      final staffs = await isar.staffModels.where().findAll();
      return staffs;
    } catch (e) {
      throw e.toString();
    }
  }

  // add staff
  Future<void> addStaff(StaffModel staff) async {
    try {
      await isar.writeTxn(() async {
        await isar.staffModels.put(staff);
      });
    } catch (e) {
      throw e.toString();
    }
  }

  // update staff
  Future<void> updateStaff(StaffModel staff) async {
    try {
      await isar.writeTxn(() async {
        await isar.staffModels.put(staff);
      });
    } catch (e) {
      throw e.toString();
    }
  }

  // delete staffs
  Future<void> deleteStaff(StaffModel staff) async {
    try {
      await isar.writeTxn(() async {
        await isar.staffModels.delete(staff.id);
      });
    } catch (e) {
      throw e.toString();
    }
  }
}

final staffServiceProvider = Provider((ref) {
  final isar = ref.read(isarServiceProvider).instance;
  return StaffService(isar);
});
