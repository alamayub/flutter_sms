import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart'
    show useMemoized, useTextEditingController;
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../config/typo_config.dart';
import '../../providers/auth_providers.dart' show authProvider;
import '../input/text_input.dart';
import '../input/password_input.dart';

class LoginWidget extends HookConsumerWidget {
  const LoginWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var formKey = useMemoized(() => GlobalKey<FormState>());
    var username = useTextEditingController(text: 'admin');
    var password = useTextEditingController(text: 'password');
    return Form(
      key: formKey,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextInput(controller: username, labelText: 'Username*'),
          const SizedBox(height: 12),
          PasswordInputWidget(controller: password),
          const SizedBox(height: 12),
          SizedBox(
            height: 36,
            width: double.infinity,
            child: TextButton(
              onPressed: () {
                try {
                  if (formKey.currentState!.validate()) {
                    FocusScope.of(context).unfocus();
                    ref
                        .read(authProvider.notifier)
                        .login(username.text.trim(), password.text.trim());
                  }
                } catch (_) {}
              },
              child: Text(
                'Login',
                style: typoConfig.textStyle.smallCaptionSubtitle2.copyWith(
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
