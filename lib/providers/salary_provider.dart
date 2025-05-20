import 'package:hooks_riverpod/hooks_riverpod.dart'
    show FutureProvider, Ref, StateNotifier, StateNotifierProvider, StateProvider;

import '../models/salary_status.dart';
import '../services/salary_service.dart';
import 'global_provider.dart';

final selectedMonthProvider = StateProvider<DateTime>((ref) => DateTime.now());

final staffSalariesProvider = FutureProvider<List<SalaryStatus>>((ref) async {
  final date = ref.watch(selectedMonthProvider);
  return ref.read(salaryServiceProvider).getStaffSalariesForMonth(date);
});

class SalaryfNotifier extends StateNotifier<void> {
  final Ref ref;

  SalaryfNotifier(this.ref) : super(null);

  Future<void> updateSalaryStatus(SalaryStatus staff) async {
    try {
      final date = ref.watch(selectedMonthProvider);
      await ref
          .read(salaryServiceProvider)
          .updateSalaryForIndividualStaff(selectedDate: date, staff: staff);
    } catch (e) {
      ref.read(globalProvider.notifier).setMessage(e.toString());
    } finally {
      ref.read(globalProvider.notifier).setLoading(false);
      ref.invalidate(staffSalariesProvider);
    }
  }
}

final salaryProvider = StateNotifierProvider<SalaryfNotifier, void>((ref) {
  return SalaryfNotifier(ref);
});
