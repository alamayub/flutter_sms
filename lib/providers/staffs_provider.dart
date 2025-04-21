import 'package:hooks_riverpod/hooks_riverpod.dart'
    show Ref, StateNotifier, StateNotifierProvider;

import '../modesl/staff_model.dart';
import '../services/staff_service.dart';
import '../states/staff_state.dart';

final staffProvider = StateNotifierProvider<StaffNotifier, StaffState>((ref) {
  return StaffNotifier(ref);
});

class StaffNotifier extends StateNotifier<StaffState> {
  final Ref ref;

  StaffNotifier(this.ref) : super(const StaffState()) {
    _loadStaffs();
  }

  Future<void> _loadStaffs() async {
    try {
      state = state.copyWith(loading: true);
      final students = await ref.read(staffServiceProvider).getAllStaffs();
      state = state.copyWith(staffs: students);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    } finally {
      state = state.copyWith(loading: false);
    }
  }

  Future<void> addStaff(StaffModel staff) async {
    try {
      state = state.copyWith(loading: true);
      await ref.read(staffServiceProvider).addStaff(staff);
      _loadStaffs();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    } finally {
      state = state.copyWith(loading: false);
    }
  }

  Future<void> updateStaff(StaffModel staff) async {
    try {
      state = state.copyWith(loading: true);
      await ref.read(staffServiceProvider).updateStaff(staff);
      _loadStaffs();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    } finally {
      state = state.copyWith(loading: false);
    }
  }

  Future<void> deleteStaff(StaffModel staff) async {
    try {
      state = state.copyWith(loading: true);
      await ref.read(staffServiceProvider).deleteStaff(staff);
      _loadStaffs();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    } finally {
      state = state.copyWith(loading: false);
    }
  }
}
