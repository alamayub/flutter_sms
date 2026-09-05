import 'package:hooks_riverpod/hooks_riverpod.dart'
    show Ref, StateNotifier, StateNotifierProvider;
import 'package:sms/models/school_model.dart';

import '../config/enums.dart' show AuthAction, MessageType;
import '../services/auth_service.dart' show authServiceProvider;
import '../states/auth_state.dart';
import 'global_provider.dart' show globalProvider;

class AuthNotifier extends StateNotifier<AuthState> {
  final Ref ref;

  AuthNotifier(this.ref) : super(const AuthState());

  void changeState(AuthAction val) {
    state = state.copyWith(state: val);
  }

  // login using username & password
  Future<void> login(String username, String password) async {
    final globalNotifier = ref.read(globalProvider.notifier);
    try {
      globalNotifier.setLoading(true);
      var res = await ref.read(authServiceProvider).login(username, password);
      state = state.copyWith(school: res);
    } catch (e) {
      globalNotifier.setMessage(e.toString());
    } finally {
      globalNotifier.setLoading(false);
    }
  }

  // register school
  Future<void> register(SchoolModel school) async {
    final globalNotifier = ref.read(globalProvider.notifier);
    try {
      globalNotifier.setLoading(true);
      await ref.read(authServiceProvider).registerSchool(school);
      globalNotifier.setMessage(
        'School registered successfully. Please login using username & password!',
        type: MessageType.success,
      );
      state = state.copyWith(state: AuthAction.login);
    } catch (e) {
      globalNotifier.setMessage(e.toString());
    } finally {
      globalNotifier.setLoading(false);
    }
  }

  // register school
  Future<void> update(SchoolModel school) async {
    final globalNotifier = ref.read(globalProvider.notifier);
    try {
      globalNotifier.setLoading(true);
      await ref.read(authServiceProvider).updateSchool(school);
      globalNotifier.setMessage(
        'Info updated successfully!',
        type: MessageType.success,
      );
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
      state = const AuthState();
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
