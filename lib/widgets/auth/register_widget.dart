import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart'
    show useMemoized, useState, useTextEditingController;
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
    var designations = useState([]);
    return Form(
      key: formKey,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
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
          TextInput(
            labelText: 'Designations*',
            onFieldSubmitted: (e) {
              if (e == null || e.isEmpty || e.trim().isEmpty) return;
              designations.value = [...designations.value, e];
            },
          ),
          if (designations.value.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: List.generate(
                designations.value.length,
                (i) => Chip(
                  label: Text(
                    designations.value[i],
                    style: typoConfig.textStyle.smallSmall,
                  ),
                  // labelPadding: EdgeInsets.zero,
                  // deleteIconBoxConstraints: BoxConstraints(maxWidth: 20),
                  deleteIcon: Icon(Icons.delete, size: 16),
                  deleteIconColor: Colors.red,
                  onDeleted: () {
                    var res = designations.value;
                    res.removeAt(i);
                    designations.value = [...res];
                  },
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
          ],
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
