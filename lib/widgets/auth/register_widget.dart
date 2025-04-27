import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart'
    show useMemoized, useTextEditingController;
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../models/school_model.dart';
import '../../providers/auth_providers.dart' show authProvider;
import '../../config/typo_config.dart';
import '../input/text_input.dart';
import '../input/password_input.dart';

class RegisterWidget extends HookConsumerWidget {
  const RegisterWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var formKey = useMemoized(() => GlobalKey<FormState>());
    var name = useTextEditingController();
    var address = useTextEditingController();
    var username = useTextEditingController();
    var password = useTextEditingController();
    return Form(
      key: formKey,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextInput(controller: name, labelText: 'School Name*'),
          const SizedBox(height: 12),
          TextInput(controller: address, labelText: 'Address*'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextInput(controller: username, labelText: 'Username*'),
              ),
              const SizedBox(width: 12),
              Expanded(child: PasswordInputWidget(controller: password)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 36,
            width: double.infinity,
            child: TextButton(
              onPressed: () {
                try {
                  if (formKey.currentState!.validate()) {
                    FocusScope.of(context).unfocus();
                    final school =
                        SchoolModel()
                          ..name = name.text.trim()
                          ..address = address.text.trim()
                          ..username = username.text.trim()
                          ..password = password.text.trim();
                    ref.read(authProvider.notifier).register(school);
                  }
                } catch (_) {}
              },
              child: Text(
                'Submit',
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
