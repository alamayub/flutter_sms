// lib/core/utils/password_hasher.dart
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

class HashedPassword {
  final String hash;
  final String salt;

  const HashedPassword({required this.hash, required this.salt});
}

class PasswordHasher {
  static final Random _secureRandom = Random.secure();

  /// Generates a cryptographically secure random 16-byte salt as a hex string.
  static String generateSalt([int length = 16]) {
    final values = List<int>.generate(
      length,
      (_) => _secureRandom.nextInt(256),
    );
    return values.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Hashes a password with the provided salt using SHA-256.
  static String hashPassword(String password, String salt) {
    final bytes = utf8.encode('$salt:$password');
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Creates a new salt and hashes the password.
  static HashedPassword createHash(String password) {
    final salt = generateSalt();
    final hash = hashPassword(password, salt);
    return HashedPassword(hash: hash, salt: salt);
  }

  /// Verifies a candidate password against the stored hash and salt.
  static bool verifyPassword({
    required String candidatePassword,
    required String storedHash,
    required String storedSalt,
  }) {
    final candidateHash = hashPassword(candidatePassword, storedSalt);
    return candidateHash == storedHash;
  }
}
