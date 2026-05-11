import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../config/typo_config.dart';
import '../../models/school_model.dart';
import '../../providers/auth_providers.dart';
import '../../widgets/input/text_input.dart';

class ProfileScreen extends HookConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(authProvider.select((state) => state.school));
    if (data == null) return Container();
    var formKey = useMemoized(() => GlobalKey<FormState>());
    var name = useTextEditingController(text: data.name);
    var address = useTextEditingController(text: data.address);
    var username = useTextEditingController(text: data.username);
    // var password = useTextEditingController();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextInput(controller: name, labelText: 'School Name*'),
            const SizedBox(height: 12),
            TextInput(controller: address, labelText: 'Address*'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextInput(
                    enabled: false,
                    controller: username,
                    labelText: 'Username*',
                  ),
                ),
                // const SizedBox(width: 12),
                // Expanded(child: PasswordInputWidget(controller: password)),
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
                            ..address = address.text.trim();
                      ref.read(authProvider.notifier).update(school);
                    }
                  } catch (_) {}
                },
                child: Text(
                  'Update Profile',
                  style: typoConfig.textStyle.smallCaptionSubtitle2.copyWith(
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
