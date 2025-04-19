import 'dart:developer' show log;

import 'package:hooks_riverpod/hooks_riverpod.dart'
    show FutureProvider, StateNotifier, StateNotifierProvider;

import '../services/isar_service.dart' show isarServiceProvider;
import '../config/enums.dart' show MessageType;
import '../states/global_state.dart';

final globalProvider = StateNotifierProvider<GlobalStateNotifier, GlobalState>(
  (_) => GlobalStateNotifier(),
);

// Step 3: Create a StateNotifier to manage loading and error
class GlobalStateNotifier extends StateNotifier<GlobalState> {
  GlobalStateNotifier() : super(GlobalState.initial());
  void setLoading(bool isLoading) => state = state.copyWith(loading: isLoading);
  void setMessage(String? err, {MessageType type = MessageType.error}) =>
      state = state.copyWith(type: type, error: err);
  void reset() => state = GlobalState.initial();
}

/// APP STARTUP PROVIDER
final appStartupProvider = FutureProvider<void>((ref) async {
  try {
    log('Initializing app dependencies...');
    await ref.read(isarServiceProvider).init();
    log('App dependencies initialized successfully!');
  } catch (e) {
    ref.read(globalProvider.notifier).setMessage(e.toString());
  }
});
