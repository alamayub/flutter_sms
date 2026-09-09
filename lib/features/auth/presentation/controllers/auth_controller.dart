// lib/features/auth/presentation/controllers/auth_controller.dart
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/errors/app_exceptions.dart';
import '../../../school/data/school_repository.dart';
import '../../data/auth_repository.dart';

enum AuthStatus {
  initial,
  needsSetup, // No school exists yet, show Welcome / Setup wizard
  unauthenticated, // School exists, show Login screen
  authenticated, // Logged in, show main shell
}

class AuthState {
  final AuthStatus status;
  final User? currentUser;
  final School? currentSchool;
  final String? errorMessage;
  final bool isLoading;

  const AuthState({
    this.status = AuthStatus.initial,
    this.currentUser,
    this.currentSchool,
    this.errorMessage,
    this.isLoading = false,
  });

  AuthState copyWith({
    AuthStatus? status,
    User? currentUser,
    School? currentSchool,
    String? errorMessage,
    bool? isLoading,
    bool clearUser = false,
    bool clearError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      currentUser: clearUser ? null : (currentUser ?? this.currentUser),
      currentSchool: currentSchool ?? this.currentSchool,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) {
    final authRepo = ref.watch(authRepositoryProvider);
    final schoolRepo = ref.watch(schoolRepositoryProvider);
    return AuthController(authRepo, schoolRepo);
  },
);

class AuthController extends StateNotifier<AuthState> {
  final AuthRepository _authRepo;
  final SchoolRepository _schoolRepo;

  AuthController(this._authRepo, this._schoolRepo) : super(const AuthState()) {
    checkStatus();
  }

  /// Checks the system initialization status on startup.
  Future<void> checkStatus() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final hasSchool = await _schoolRepo.hasAnySchool();
      if (!hasSchool) {
        state = state.copyWith(
          status: AuthStatus.needsSetup,
          isLoading: false,
          clearUser: true,
        );
        return;
      }

      final activeSchool = await _schoolRepo.getActiveSchool();
      final persistedUser = await _authRepo.getActiveSessionUser();

      if (persistedUser != null) {
        state = state.copyWith(
          status: AuthStatus.authenticated,
          currentUser: persistedUser,
          currentSchool: activeSchool,
          isLoading: false,
        );
      } else {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          currentSchool: activeSchool,
          isLoading: false,
          clearUser: true,
        );
      }
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.needsSetup,
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// Authenticates with local credentials.
  Future<bool> login({
    required String usernameOrEmail,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final user = await _authRepo.login(
        usernameOrEmail: usernameOrEmail,
        password: password,
        schoolId: state.currentSchool?.id,
      );

      final school =
          await _schoolRepo.getSchoolById(user.schoolId) ?? state.currentSchool;

      state = state.copyWith(
        status: AuthStatus.authenticated,
        currentUser: user,
        currentSchool: school,
        isLoading: false,
        clearError: true,
      );
      return true;
    } on AppException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'An unexpected error occurred during login.',
      );
      return false;
    }
  }

  /// Sets up a new school and administrator.
  Future<bool> registerSchoolAndAdmin({
    required String schoolName,
    String? shortName,
    String? address,
    String? phone,
    String? email,
    String? principalName,
    required String adminName,
    required String adminUsername,
    String? adminEmail,
    required String adminPassword,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      // 1. Create School
      final school = await _schoolRepo.createSchool(
        name: schoolName,
        shortName: shortName,
        address: address,
        phone: phone,
        email: email,
        principalName: principalName,
      );

      // 2. Create Administrator User
      final admin = await _authRepo.createAdministrator(
        schoolId: school.id,
        name: adminName,
        username: adminUsername,
        email: adminEmail,
        password: adminPassword,
      );

      // 3. Authenticate and update state
      state = state.copyWith(
        status: AuthStatus.authenticated,
        currentUser: admin,
        currentSchool: school,
        isLoading: false,
        clearError: true,
      );
      return true;
    } on AppException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Setup failed: $e',
      );
      return false;
    }
  }

  /// Logs out of the current session.
  Future<void> logout() async {
    final user = state.currentUser;
    final school = state.currentSchool;
    if (user != null && school != null) {
      await _authRepo.logout(userId: user.id, schoolId: school.id);
    } else {
      await _authRepo.clearActiveSession();
    }
    state = state.copyWith(
      status: AuthStatus.unauthenticated,
      clearUser: true,
      clearError: true,
    );
  }

  /// Switch user session directly (used for quick testing between Admin / Teacher / Accountant roles).
  void switchSession(User user, School school) {
    _authRepo.saveActiveSession(user.id);
    state = state.copyWith(
      status: AuthStatus.authenticated,
      currentUser: user,
      currentSchool: school,
      clearError: true,
    );
  }
}
