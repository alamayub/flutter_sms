// lib/features/auth/data/auth_repository.dart
import 'package:drift/drift.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_service.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/utils/password_hasher.dart';
import '../../../core/utils/uuid_generator.dart';
import '../../audit/data/audit_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final audit = ref.watch(auditRepositoryProvider);
  return AuthRepository(db, audit);
});

class AuthRepository {
  final AppDatabase _db;
  final AuditRepository _audit;

  AuthRepository(this._db, this._audit);

  /// Authenticates a user against the local database with salted SHA-256 verification.
  Future<User> login({
    required String usernameOrEmail,
    required String password,
    String? schoolId,
  }) async {
    final query = _db.select(_db.users);
    if (schoolId != null) {
      query.where(
        (u) =>
            u.schoolId.equals(schoolId) &
            (u.username.equals(usernameOrEmail.trim().toLowerCase()) |
                u.email.equals(usernameOrEmail.trim().toLowerCase())),
      );
    } else {
      query.where(
        (u) =>
            u.username.equals(usernameOrEmail.trim().toLowerCase()) |
            u.email.equals(usernameOrEmail.trim().toLowerCase()),
      );
    }

    final user = await query.getSingleOrNull();

    if (user == null) {
      throw const AuthException('Invalid username/email or password.');
    }

    if (!user.isActive) {
      throw const AuthException(
        'This account has been deactivated. Please contact your administrator.',
      );
    }

    final isPasswordValid = PasswordHasher.verifyPassword(
      candidatePassword: password,
      storedHash: user.passwordHash,
      storedSalt: user.salt,
    );

    if (!isPasswordValid) {
      throw const AuthException('Invalid username/email or password.');
    }

    final now = DateTime.now();

    await _db.transaction(() async {
      // Update lastLoginAt
      await (_db.update(_db.users)..where(
        (u) => u.id.equals(user.id),
      )).write(UsersCompanion(lastLoginAt: Value(now)));

      // Persist active session
      await saveActiveSession(user.id);

      // Audit log
      await _audit.log(
        schoolId: user.schoolId,
        userId: user.id,
        action: AuditAction.login,
        entityType: 'User',
        entityId: user.id,
        metadata: {'username': user.username, 'role': user.role},
      );
    });

    return user;
  }

  static const String sessionKey = 'active_session_user_id';

  /// Saves the active user session in AppSettings.
  Future<void> saveActiveSession(String userId) async {
    final now = DateTime.now();
    await _db
        .into(_db.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion.insert(
            key: sessionKey,
            value: userId,
            updatedAt: now,
          ),
        );
  }

  /// Restores the active session user if present, active, and valid.
  Future<User?> getActiveSessionUser() async {
    final setting =
        await (_db.select(_db.appSettings)
          ..where((s) => s.key.equals(sessionKey))).getSingleOrNull();

    if (setting == null || setting.value.trim().isEmpty) {
      return null;
    }

    final user =
        await (_db.select(_db.users)
          ..where((u) => u.id.equals(setting.value))).getSingleOrNull();

    if (user == null || !user.isActive) {
      await clearActiveSession();
      return null;
    }

    return user;
  }

  /// Clears the active session from AppSettings.
  Future<void> clearActiveSession() async {
    await (_db.delete(_db.appSettings)
      ..where((s) => s.key.equals(sessionKey))).go();
  }

  /// Logs out the user.
  Future<void> logout({
    required String userId,
    required String schoolId,
  }) async {
    await _db.transaction(() async {
      await clearActiveSession();
      await _audit.log(
        schoolId: schoolId,
        userId: userId,
        action: AuditAction.logout,
        entityType: 'User',
        entityId: userId,
      );
    });
  }

  /// Creates an administrator/principal user.
  Future<User> createAdministrator({
    required String schoolId,
    required String name,
    required String username,
    String? email,
    required String password,
    String role = UserRole.admin,
  }) async {
    if (password.length < 6) {
      throw const ValidationException(
        'Password must be at least 6 characters long.',
      );
    }

    final normalizedUsername = username.trim().toLowerCase();
    final normalizedEmail = email?.trim().toLowerCase();

    // Check uniqueness within the school
    final existingUser =
        await (_db.select(_db.users)..where(
          (u) =>
              u.schoolId.equals(schoolId) &
              u.username.equals(normalizedUsername),
        )).getSingleOrNull();

    if (existingUser != null) {
      throw const ConflictException(
        'A user with this username already exists in this school.',
      );
    }

    final hashed = PasswordHasher.createHash(password);
    final now = DateTime.now();
    final id = UuidGenerator.v4();

    final companion = UsersCompanion.insert(
      id: id,
      schoolId: schoolId,
      name: name.trim(),
      username: normalizedUsername,
      email: Value(normalizedEmail),
      passwordHash: hashed.hash,
      salt: hashed.salt,
      role: role,
      isActive: const Value(true),
      createdAt: now,
      updatedAt: now,
    );

    await _db.into(_db.users).insert(companion);

    return (await getUserById(id))!;
  }

  /// Creates a standard user (Teacher, Accountant, etc.).
  Future<User> createUser({
    required String schoolId,
    required String name,
    required String username,
    String? email,
    required String password,
    required String role,
    String? createdByUserId,
  }) async {
    final normalizedUsername = username.trim().toLowerCase();

    final existingUser =
        await (_db.select(_db.users)..where(
          (u) =>
              u.schoolId.equals(schoolId) &
              u.username.equals(normalizedUsername),
        )).getSingleOrNull();

    if (existingUser != null) {
      throw const ConflictException('Username is already taken.');
    }

    final hashed = PasswordHasher.createHash(password);
    final now = DateTime.now();
    final id = UuidGenerator.v4();

    final companion = UsersCompanion.insert(
      id: id,
      schoolId: schoolId,
      name: name.trim(),
      username: normalizedUsername,
      email: Value(email?.trim().toLowerCase()),
      passwordHash: hashed.hash,
      salt: hashed.salt,
      role: role,
      isActive: const Value(true),
      createdAt: now,
      updatedAt: now,
    );

    await _db.into(_db.users).insert(companion);
    return (await getUserById(id))!;
  }

  /// Gets a user by ID.
  Future<User?> getUserById(String id) async {
    return await (_db.select(_db.users)
      ..where((u) => u.id.equals(id))).getSingleOrNull();
  }

  /// Lists all users for a school.
  Future<List<User>> getUsersBySchool(String schoolId) async {
    return await (_db.select(_db.users)
      ..where((u) => u.schoolId.equals(schoolId))).get();
  }
}
