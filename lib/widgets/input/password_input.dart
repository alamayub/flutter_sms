import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart' show HookWidget, useState;

import '../../config/theme.dart' show ColorConstants, textDecorationTextStyle;

class PasswordInputWidget extends HookWidget {
  final TextEditingController controller;
  final String labelText;

  const PasswordInputWidget({
    super.key,
    required this.controller,
    this.labelText = 'Enter Password*',
  });

  @override
  Widget build(BuildContext context) {
    final hide = useState(true);

    return SizedBox(
      height: 36,
      child: TextFormField(
        obscureText: hide.value,
        autocorrect: false,
        enableSuggestions: false,
        obscuringCharacter: '*',
        style: textDecorationTextStyle(ColorConstants.textColor),
        decoration: InputDecoration(
          isDense: true,
          hintText: '******',
          labelText: labelText,
          suffixIconConstraints: const BoxConstraints(maxHeight: 36),
          suffixIcon: Container(
            margin: const EdgeInsets.only(left: 10, right: 16),
            child: GestureDetector(
              onTap: () => hide.value = !hide.value,
              child: Icon(
                hide.value ? Icons.visibility : Icons.visibility_off,
                size: 16,
                color: ColorConstants.textColor,
              ),
            ),
          ),
        ),
        controller: controller,
        keyboardType: TextInputType.visiblePassword,
        validator: (val) => val != null && val.length < 6 ? '' : null,
      ),
    );
  }
}
