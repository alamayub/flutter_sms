import 'package:flutter/material.dart';

import '../../config/theme.dart' show ColorConstants, textDecorationTextStyle;

class TextInput extends StatelessWidget {
  final TextEditingController? controller;
  final String labelText;
  final bool enabled;
  final Function(String?)? onChanged;
  final Function(String?)? onFieldSubmitted;

  const TextInput({
    super.key,
    this.controller,
    required this.labelText,
    this.enabled = true,
    this.onChanged,
    this.onFieldSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: TextFormField(
        enabled: enabled,
        controller: controller,
        onChanged: onChanged,
        keyboardType: TextInputType.name,
        style: textDecorationTextStyle(ColorConstants.textColor),
        decoration: InputDecoration(labelText: labelText),
        validator: (x) => x == null || x.isEmpty ? '' : null,
        onFieldSubmitted: onFieldSubmitted,
      ),
    );
  }
}
