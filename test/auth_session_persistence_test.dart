// test/auth_session_persistence_test.dart
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sms/core/constants/app_constants.dart';
import 'package:sms/core/database/app_database.dart';
import 'package:sms/features/audit/data/audit_repository.dart';
import 'package:sms/features/auth/data/auth_repository.dart';
import 'package:sms/features/school/data/school_repository.dart';

void main() {
  late Directory tempDir;
  late File dbFile;
  late AppDatabase db;
  late AuditRepository auditRepo;
  late SchoolRepository schoolRepo;
  late AuthRepository authRepo;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sms_auth_session_test_');
    dbFile = File('${tempDir.path}/session_test.sqlite');
    db = AppDatabase(NativeDatabase(dbFile));
    auditRepo = AuditRepository(db);
    schoolRepo = SchoolRepository(db, auditRepo);
    authRepo = AuthRepository(db, auditRepo);
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'Session persists across app restart, clears on logout, and handles user switching',
    () async {
      // 1. Setup school & users
      final school = await schoolRepo.createSchool(
        name: 'Session Academy',
        shortName: 'SA',
      );
      final adminUser = await authRepo.createUser(
        schoolId: school.id,
        name: 'Principal Skinner',
        username: 'principal',
        password: 'password123',
        role: UserRole.principal,
      );

      final teacherUser = await authRepo.createUser(
        schoolId: school.id,
        name: 'Edna Krabappel',
        username: 'teacher1',
        password: 'password456',
        role: UserRole.teacher,
      );

      // Initial state: no active session
      var initialSessionUser = await authRepo.getActiveSessionUser();
      expect(initialSessionUser, isNull);

      // 2. Admin logs in
      final loggedInAdmin = await authRepo.login(
        usernameOrEmail: 'principal',
        password: 'password123',
        schoolId: school.id,
      );
      expect(loggedInAdmin.id, adminUser.id);

      // Verify session user
      final currentSession = await authRepo.getActiveSessionUser();
      expect(currentSession, isNotNull);
      expect(currentSession!.id, adminUser.id);
      expect(currentSession.name, 'Principal Skinner');

      // 3. Simulate App Restart: create brand new AuthRepository instance with same database
      final rebootedAuthRepo = AuthRepository(db, auditRepo);
      final restoredUser = await rebootedAuthRepo.getActiveSessionUser();
      expect(restoredUser, isNotNull);
      expect(restoredUser!.id, adminUser.id);
      expect(restoredUser.username, 'principal');

      // 4. Switch Session: Teacher logs in
      await rebootedAuthRepo.login(
        usernameOrEmail: 'teacher1',
        password: 'password456',
        schoolId: school.id,
      );
      final switchedSession = await rebootedAuthRepo.getActiveSessionUser();
      expect(switchedSession, isNotNull);
      expect(switchedSession!.id, teacherUser.id);
      expect(switchedSession.name, 'Edna Krabappel');

      // 5. Logout
      await rebootedAuthRepo.logout(
        userId: teacherUser.id,
        schoolId: school.id,
      );
      final sessionAfterLogout = await rebootedAuthRepo.getActiveSessionUser();
      expect(sessionAfterLogout, isNull);

      // 6. Simulate another App Restart: ensure session remains cleared
      final postLogoutAuthRepo = AuthRepository(db, auditRepo);
      expect(await postLogoutAuthRepo.getActiveSessionUser(), isNull);
    },
  );
}
