import 'package:hooks_riverpod/hooks_riverpod.dart'
    show Ref, StateNotifier, StateNotifierProvider;

import '../config/enums.dart' show AuthAction;
import '../services/auth_service.dart' show authServiceProvider;
import '../states/auth_state.dart';
import 'global_provider.dart' show globalProvider;

class AuthNotifier extends StateNotifier<AuthState> {
  final Ref ref;

  AuthNotifier(this.ref) : super(const AuthState());

  changeState(AuthAction val) {
    state = state.copyWith(state: val);
  }

  // login using username & password
  Future<void> login(String username, String password) async {
    final globalNotifier = ref.read(globalProvider.notifier);
    try {
      globalNotifier.setLoading(true);
      await ref.read(authServiceProvider).login(username, password);
    } catch (e) {
      globalNotifier.setMessage(e.toString());
    } finally {
      globalNotifier.setLoading(false);
    }
  }

  // logout
  Future<void> logout() async {
    final globalNotifier = ref.read(globalProvider.notifier);
    try {
      globalNotifier.setLoading(true);
      await Future.delayed(const Duration(seconds: 2));
    } catch (e) {
      globalNotifier.setMessage(e.toString());
    } finally {
      globalNotifier.setLoading(false);
    }
  }
}

/// Provide AuthNotifier as a global state
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  ref.keepAlive();
  return AuthNotifier(ref);
});
