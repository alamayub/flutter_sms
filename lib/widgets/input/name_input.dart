import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/theme.dart' show ColorConstants, textDecorationTextStyle;

class NameInput extends StatelessWidget {
  final String labeltext;
  final TextEditingController controller;
  final bool enabled;
  final bool required;

  const NameInput({
    super.key,
    required this.controller,
    required this.labeltext,
    this.enabled = true,
    this.required = true,
  });

  bool _isValidName(String? name) {
    if (name == null || name.trim().isEmpty) return false;
    final nameRegex = RegExp(r"^[A-Za-z]+$");
    return nameRegex.hasMatch(name);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: TextFormField(
        enabled: enabled,
        controller: controller,
        keyboardType: TextInputType.name,
        textCapitalization: TextCapitalization.words,
        style: textDecorationTextStyle(ColorConstants.textColor),
        decoration: InputDecoration(labelText: labeltext, hintText: 'John Deo'),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
          TextInputFormatter.withFunction((oldValue, newValue) {
            final text = newValue.text;
            return newValue.copyWith(
              text: text.replaceAllMapped(
                RegExp(r'\b\w'),
                (match) => match.group(0)!.toUpperCase(),
              ),
            );
          }),
        ],
        validator: required ? (val) => _isValidName(val) ? null : '' : null,
      ),
    );
  }
}
