import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../models/calendar_mode.dart';
import 'storage_provider.dart';

class CalendarNotifier extends Notifier<CalendarMode> {
  @override
  CalendarMode build() {
    try {
      final storage = ref.read(storageServiceProvider);
      return storage.getCalendarMode();
    } catch (_) {
      return CalendarMode.bs;
    }
  }

  Future<void> setCalendarMode(CalendarMode mode) async {
    state = mode;
    try {
      final storage = ref.read(storageServiceProvider);
      await storage.setCalendarMode(mode);
    } catch (_) {}
  }

  Future<void> toggleCalendarMode() async {
    final next = state == CalendarMode.bs ? CalendarMode.ad : CalendarMode.bs;
    await setCalendarMode(next);
  }
}

final calendarProvider = NotifierProvider<CalendarNotifier, CalendarMode>(
  CalendarNotifier.new,
);
