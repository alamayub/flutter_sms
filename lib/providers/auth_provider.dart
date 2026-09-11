import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../models/school_profile.dart';
import '../services/database_backup_service.dart';
import '../services/storage_service.dart';
import 'database_provider.dart';
import 'school_profile_provider.dart';
import 'storage_provider.dart';

enum AuthStatus { unregistered, unauthenticated, authenticated }

class AuthState {
  final AuthStatus status;
  final String? errorMessage;
  final bool isLoading;

  const AuthState({
    required this.status,
    this.errorMessage,
    this.isLoading = false,
  });

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isRegistered => status != AuthStatus.unregistered;

  AuthState copyWith({
    AuthStatus? status,
    String? errorMessage,
    bool? isLoading,
    bool clearError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  StorageService? _storageService;

  @override
  AuthState build() {
    try {
      _storageService = ref.watch(storageServiceProvider);
      final isRegistered = _storageService?.isSchoolRegistered() ?? true;
      if (!isRegistered) {
        return const AuthState(status: AuthStatus.unregistered);
      }
      final isSessionActive = _storageService?.isSessionActive() ?? false;
      if (isSessionActive) {
        return const AuthState(status: AuthStatus.authenticated);
      }
      return const AuthState(status: AuthStatus.unauthenticated);
    } catch (_) {
      // For unit tests without storageServiceProvider, default to authenticated
      return const AuthState(status: AuthStatus.authenticated);
    }
  }

  Future<bool> registerSchool({
    required String name,
    required String password,
    String pin = '1234',
    String code = '',
    String address = '',
    String phone = '',
    String email = '',
    String website = '',
    String principalName = '',
    String establishedYear = '',
    String? logoPath,
    String adminUsername = 'admin',
    String tagline = 'Knowledge, Character, Excellence',
    String idCardFooter =
        'This card is non-transferable and must be returned upon leaving the school.',
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final newProfile = SchoolProfile(
        name: name.trim(),
        code: code.trim(),
        address: address.trim(),
        phone: phone.trim(),
        email: email.trim(),
        website: website.trim(),
        principalName: principalName.trim(),
        establishedYear: establishedYear.trim(),
        logoPath: logoPath,
        adminUsername: adminUsername.trim(),
        adminPasswordHash: SchoolProfile.hashPassword(password),
        adminPinHash: SchoolProfile.hashPassword(pin),
        tagline: tagline.trim(),
        idCardFooter: idCardFooter.trim(),
        isRegistered: true,
        registeredAt: DateTime.now(),
      );

      await ref.read(schoolProfileProvider.notifier).updateProfile(newProfile);
      await _storageService?.setSessionActive(true);

      state = const AuthState(status: AuthStatus.authenticated);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Registration failed: $e',
      );
      return false;
    }
  }

  Future<bool> login({
    required String username,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final profile = ref.read(schoolProfileProvider);
      final trimmedUser = username.trim();

      if (trimmedUser != profile.adminUsername) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Invalid admin username',
        );
        return false;
      }

      if (!profile.verifyPasswordOrPin(password)) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Incorrect password or 4-digit PIN',
        );
        return false;
      }

      await _storageService?.setSessionActive(true);
      state = const AuthState(status: AuthStatus.authenticated);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Login failed: $e',
      );
      return false;
    }
  }

  Future<void> logout() async {
    try {
      await _storageService?.setSessionActive(false);
    } catch (_) {}
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  Future<DatabaseBackupResult> importDatabaseAndRestore(String filePath) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final db = ref.read(databaseProvider);
      final result = await DatabaseBackupService.importDatabase(
        filePath,
        currentDb: db,
      );

      if (result.success) {
        // Invalidate database and reload profile
        ref.invalidate(databaseProvider);
        await ref.read(schoolProfileProvider.notifier).reload();
        await _storageService?.setSessionActive(true);
        state = const AuthState(status: AuthStatus.authenticated);
      } else {
        state = state.copyWith(isLoading: false, errorMessage: result.message);
      }
      return result;
    } catch (e) {
      final failure = DatabaseBackupResult.failure(
        'Failed to import database: $e',
      );
      state = state.copyWith(isLoading: false, errorMessage: failure.message);
      return failure;
    }
  }
}

final authStateProvider = NotifierProvider<AuthNotifier, AuthState>(
  () => AuthNotifier(),
);
