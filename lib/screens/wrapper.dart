import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart'
    show HookConsumerWidget, WidgetRef;

import '../providers/auth_providers.dart' show authProvider;
import '../providers/global_provider.dart' show globalProvider;
import '../states/global_state.dart';
import 'auth/auth_screen.dart';
import 'helper/loading_screen.dart';
import 'helper/message_screen.dart';
import 'root/root_screen.dart';

class Wrapper extends HookConsumerWidget {
  const Wrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Listen for global loading indicator
    ref.listen<GlobalState>(globalProvider, (previous, next) {
      if (previous?.loading != next.loading) {
        if (next.loading) {
          LoadingScreen.instance().show(context: context);
        } else {
          LoadingScreen.instance().hide();
        }
      }
      if (previous?.error != next.error) {
        if (next.error != null) {
          MessageScreen.instance().show(
            context: context,
            global: next,
            ref: ref,
          );
        } else {
          MessageScreen.instance().hide();
        }
      }
    });
    var user = ref.watch(authProvider);
    // return user.user != null ? const RootScreen() : const AuthScreen();
    return const RootScreen();
  }
}
