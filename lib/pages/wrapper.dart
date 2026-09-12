import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../providers/auth_provider.dart';
import 'auth/auth_screen.dart';
import 'root_screen.dart';

class Wrapper extends ConsumerWidget {
  const Wrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    if (authState.status == AuthStatus.authenticated) {
      return const RootScreen();
    }

    return AuthScreen(
      initialIsRegister: authState.status == AuthStatus.unregistered,
    );
  }
}
