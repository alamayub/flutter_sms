import 'package:flutter/gestures.dart' show TapGestureRecognizer;
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart'
    show ConsumerWidget, WidgetRef;

import '../../config/enums.dart' show AuthAction;
import '../../config/theme.dart' show ColorConstants;
import '../../config/typo_config.dart';
import '../../providers/auth_providers.dart' show authProvider;
import '../../widgets/auth/login_widget.dart';
import '../../widgets/auth/register_widget.dart';

class AuthScreen extends ConsumerWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(authProvider.select((state) => state.state));
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child:
                  state == AuthAction.login
                      ? const LoginWidget()
                      : const RegisterWidget(),
            ),
            RichText(
              text: TextSpan(
                text:
                    state == AuthAction.login
                        ? 'Don\'t have an account? '
                        : 'Already have ',
                style: typoConfig.textStyle.smallCaptionSubtitle2.copyWith(
                  color: ColorConstants.textColor,
                ),
                children: [
                  TextSpan(
                    text: state == AuthAction.login ? 'Create One' : 'Login',
                    style: typoConfig.textStyle.smallCaptionSubtitle1.copyWith(
                      color: ColorConstants.primary,
                    ),
                    recognizer:
                        TapGestureRecognizer()
                          ..onTap = () {
                            ref
                                .read(authProvider.notifier)
                                .changeState(
                                  state == AuthAction.login
                                      ? AuthAction.register
                                      : AuthAction.login,
                                );
                          },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
