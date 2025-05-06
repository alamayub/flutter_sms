import 'package:hooks_riverpod/hooks_riverpod.dart'
    show FutureProvider, Ref, StateNotifier, StateNotifierProvider;
    
import 'global_provider.dart' show globalProvider;
import '../models/staff_model.dart';
import '../services/staff_service.dart';

final staffListProvider = FutureProvider<List<StaffModel>>((ref) {
  return ref.read(staffServiceProvider).getAllStaffs();
});

final staffProvider = StateNotifierProvider<StaffNotifier, void>((ref) {
  return StaffNotifier(ref);
});

class StaffNotifier extends StateNotifier<void> {
  final Ref ref;

  StaffNotifier(this.ref) : super(null) ;

  Future<void> addStaff(StaffModel staff) async {
    try {
      ref.read(globalProvider.notifier).setLoading(true);
      await ref.read(staffServiceProvider).addStaff(staff);
    } catch (e) {
      ref.read(globalProvider.notifier).setMessage(e.toString());
    } finally {
      ref.read(globalProvider.notifier).setLoading(false);
      ref.invalidate(staffListProvider);
    }
  }

  Future<void> updateStaff(StaffModel staff) async {
    try {
      ref.read(globalProvider.notifier).setLoading(true);
      await ref.read(staffServiceProvider).updateStaff(staff);
    } catch (e) {
      ref.read(globalProvider.notifier).setMessage(e.toString());
    } finally {
      ref.read(globalProvider.notifier).setLoading(false);
      ref.invalidate(staffListProvider);
    }
  }

  Future<void> deleteStaff(StaffModel staff) async {
    try {
      ref.read(globalProvider.notifier).setLoading(true);
      await ref.read(staffServiceProvider).deleteStaff(staff);
    } catch (e) {
      ref.read(globalProvider.notifier).setMessage(e.toString());
    } finally {
      ref.read(globalProvider.notifier).setLoading(false);
      ref.invalidate(staffListProvider);
    }
  }
}
