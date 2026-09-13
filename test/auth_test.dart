import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sms/models/school_profile.dart';
import 'package:sms/providers/auth_provider.dart';
import 'package:sms/providers/school_profile_provider.dart';
import 'package:sms/providers/storage_provider.dart';
import 'package:sms/services/database_backup_service.dart';
import 'package:sms/services/storage_service.dart';

void main() {
  group('SchoolProfile Model & Security Tests', () {
    test('Default initial profile has empty registration', () {
      final profile = SchoolProfile.initial();
      expect(profile.isRegistered, isFalse);
      expect(profile.name, 'Pragyan Academy');
      expect(profile.adminUsername, 'admin');
    });

    test('Password hashing and verification with salt', () {
      const password = 'AdminPassword123!';
      final hash = SchoolProfile.hashPassword(password);
      expect(hash.isNotEmpty, isTrue);

      final profile = SchoolProfile(
        name: 'Test Academy',
        isRegistered: true,
        adminUsername: 'admin',
        adminPasswordHash: hash,
      );

      // Correct password
      expect(profile.verifyPassword(password), isTrue);

      // Wrong passwords
      expect(profile.verifyPassword('WrongPassword'), isFalse);
      expect(profile.verifyPassword(''), isFalse);
      expect(profile.verifyPassword('adminpassword123!'), isFalse);
    });

    test('4-Digit Security PIN hashing, verification, and combined auth', () {
      const pin = '8821';
      final pinHash = SchoolProfile.hashPassword(pin);
      final passwordHash = SchoolProfile.hashPassword('SuperSecret123');

      final profile = SchoolProfile(
        name: 'PIN Secured Academy',
        isRegistered: true,
        adminUsername: 'admin',
        adminPasswordHash: passwordHash,
        adminPinHash: pinHash,
      );

      // Verify PIN directly
      expect(profile.verifyPin('8821'), isTrue);
      expect(profile.verifyPin('0000'), isFalse);
      expect(profile.verifyPin('1234'), isFalse);

      // Verify combined verifyPasswordOrPin
      expect(profile.verifyPasswordOrPin('SuperSecret123'), isTrue);
      expect(profile.verifyPasswordOrPin('8821'), isTrue);
      expect(profile.verifyPasswordOrPin('WrongCreds'), isFalse);
    });

    test('JSON serialization and deserialization roundtrip', () {
      final original = SchoolProfile(
        name: 'Apex Modern School',
        code: 'AFF-8821',
        address: 'Kathmandu, Nepal',
        phone: '+977-1-4433221',
        email: 'info@apexschool.edu.np',
        website: 'https://apexschool.edu.np',
        principalName: 'Dr. Hari Sharma',
        establishedYear: '2055',
        tagline: 'Knowledge is Power',
        idCardFooter: 'If found, please return to office',
        isRegistered: true,
        adminUsername: 'superadmin',
        adminPasswordHash: SchoolProfile.hashPassword('SecretPass123'),
        registeredAt: DateTime(2026, 9, 11, 10, 0),
      );

      final json = original.toJson();
      final restored = SchoolProfile.fromJson(json);

      expect(restored.name, original.name);
      expect(restored.code, original.code);
      expect(restored.address, original.address);
      expect(restored.phone, original.phone);
      expect(restored.email, original.email);
      expect(restored.website, original.website);
      expect(restored.principalName, original.principalName);
      expect(restored.establishedYear, original.establishedYear);
      expect(restored.tagline, original.tagline);
      expect(restored.idCardFooter, original.idCardFooter);
      expect(restored.isRegistered, isTrue);
      expect(restored.adminUsername, original.adminUsername);
      expect(restored.adminPasswordHash, original.adminPasswordHash);
      expect(restored.registeredAt, original.registeredAt);
    });

    test('copyWith properly overrides specified attributes', () {
      final base = SchoolProfile.initial();
      final updated = base.copyWith(
        name: 'Updated School Name',
        isRegistered: true,
        adminUsername: 'newadmin',
      );

      expect(updated.name, 'Updated School Name');
      expect(updated.isRegistered, isTrue);
      expect(updated.adminUsername, 'newadmin');
      expect(updated.email, base.email);
    });
  });

  group('DatabaseBackupService Validation Tests', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('sms_backup_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('Validates authentic SQLite header (SQLite format 3)', () async {
      final validDbFile = File('${tempDir.path}/valid.db');
      // Minimal 100-byte SQLite header
      final headerBytes = Uint8List(100);
      final magic = 'SQLite format 3\u0000'.codeUnits;
      for (int i = 0; i < magic.length; i++) {
        headerBytes[i] = magic[i];
      }
      await validDbFile.writeAsBytes(headerBytes);

      final isValid = await DatabaseBackupService.validateDatabaseFile(
        validDbFile,
      );
      expect(isValid, isTrue);
    });

    test('Rejects invalid or corrupted non-SQLite files', () async {
      final invalidFile = File('${tempDir.path}/invalid.db');
      await invalidFile.writeAsString(
        'This is plain text and not a SQLite database file',
      );

      final isValid = await DatabaseBackupService.validateDatabaseFile(
        invalidFile,
      );
      expect(isValid, isFalse);

      final nonExistent = await DatabaseBackupService.validateDatabaseFile(
        File('${tempDir.path}/does_not_exist.db'),
      );
      expect(nonExistent, isFalse);
    });
  });

  group('AuthNotifier & Storage Integration Tests', () {
    late StorageService storageService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      storageService = StorageService(prefs);
    });

    test('Initial unconfigured state is unregistered and unauthenticated', () {
      final container = ProviderContainer(
        overrides: [storageServiceProvider.overrideWithValue(storageService)],
      );
      addTearDown(container.dispose);

      final state = container.read(authStateProvider);
      expect(state.isRegistered, isFalse);
      expect(state.isAuthenticated, isFalse);
    });

    test(
      'First-time registration sets school profile and authenticates',
      () async {
        final container = ProviderContainer(
          overrides: [storageServiceProvider.overrideWithValue(storageService)],
        );
        addTearDown(container.dispose);

        final authState = container.read(authStateProvider);
        expect(authState.isRegistered, isTrue);
        expect(authState.isAuthenticated, isTrue);

        final school = container.read(schoolProfileProvider);
        expect(school.name, 'Pragyan International School');
        expect(school.adminUsername, 'admin');

        // Verify persisted in storage
        expect(storageService.isSchoolRegistered(), isTrue);
        final storedProfile = storageService.getSchoolProfile();
        expect(storedProfile.name, 'Pragyan International School');
        expect(storedProfile.verifyPassword('Password#2026'), isTrue);
      },
    );

    test(
      'Login handles correct, incorrect, and edge-case credentials',
      () async {
        final container = ProviderContainer(
          overrides: [storageServiceProvider.overrideWithValue(storageService)],
        );
        addTearDown(container.dispose);

        // Log out
        await container.read(authStateProvider.notifier).logout();
        expect(container.read(authStateProvider).isAuthenticated, isFalse);

        // Wrong password
        final wrongPassResult = await container
            .read(authStateProvider.notifier)
            .login(username: 'principal', password: 'WrongPassword');
        expect(wrongPassResult, isFalse);
        expect(container.read(authStateProvider).isAuthenticated, isFalse);
        expect(
          container.read(authStateProvider).errorMessage,
          contains('Incorrect password'),
        );

        // Wrong username
        final wrongUserResult = await container
            .read(authStateProvider.notifier)
            .login(username: 'intruder', password: 'SecretPin123');
        expect(wrongUserResult, isFalse);
        expect(container.read(authStateProvider).isAuthenticated, isFalse);
        expect(
          container.read(authStateProvider).errorMessage,
          contains('Invalid admin username'),
        );

        // Correct credentials
        final correctResult = await container
            .read(authStateProvider.notifier)
            .login(username: 'principal', password: 'SecretPin123');
        expect(correctResult, isTrue);
        expect(container.read(authStateProvider).isAuthenticated, isTrue);
        expect(container.read(authStateProvider).errorMessage, isNull);
      },
    );

    test(
      'Registration stores PIN, logoPath, and allows authentication via 4-digit PIN',
      () async {
        final container = ProviderContainer(
          overrides: [storageServiceProvider.overrideWithValue(storageService)],
        );
        addTearDown(container.dispose);

        final registered = await container
            .read(authStateProvider.notifier)
            .registerSchool(
              name: 'Himalayan Academy',
              code: 'HA-2026',
              address: 'Lalitpur, Nepal',
              phone: '01-5000000',
              email: 'admin@himalayan.edu.np',
              website: 'https://himalayan.edu.np',
              principalName: 'Sita Sharma',
              establishedYear: '2010',
              tagline: 'Empowering Minds',
              idCardFooter: 'Valid for current academic session only',
              adminUsername: 'himalayan_admin',
              password: 'StrongPassword99',
              pin: '9876',
              logoPath: '/dummy/logo.png',
            );

        expect(registered, isTrue);

        final profile = container.read(schoolProfileProvider);
        expect(profile.establishedYear, '2010');
        expect(profile.principalName, 'Sita Sharma');
        expect(profile.logoPath, '/dummy/logo.png');
        expect(profile.idCardFooter, 'Valid for current academic session only');
        expect(profile.verifyPin('9876'), isTrue);

        // Logout
        await container.read(authStateProvider.notifier).logout();
        expect(container.read(authStateProvider).isAuthenticated, isFalse);

        // Login using 4-digit PIN instead of password
        final pinLoginResult = await container
            .read(authStateProvider.notifier)
            .login(username: 'himalayan_admin', password: '9876');
        expect(pinLoginResult, isTrue);
        expect(container.read(authStateProvider).isAuthenticated, isTrue);
      },
    );
  });
}
