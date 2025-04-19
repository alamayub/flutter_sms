import 'package:flutter/foundation.dart' show immutable;
import 'package:hooks_riverpod/hooks_riverpod.dart' show Provider;

@immutable
class AuthService {
  const AuthService();

  // login
  Future<void> login(String username, String password) async {
    try {
      await Future.delayed(const Duration(seconds: 2));
    } catch (e) {
      throw e.toString();
    }
  }
}

final authServiceProvider = Provider((_) => AuthService());
