import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show FilteringTextInputFormatter, TextInputType;

import '../../config/theme.dart' show ColorConstants, textDecorationTextStyle;

class NumberInput extends StatelessWidget {
  final TextEditingController controller;
  final String labelText;
  final bool enabled;
  final int maxLength;

  const NumberInput({
    super.key,
    required this.controller,
    required this.labelText,
    this.enabled = true,
    required this.maxLength,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: TextFormField(
        enabled: enabled,
        controller: controller,
        maxLength: maxLength,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: textDecorationTextStyle(ColorConstants.textColor),
        decoration: InputDecoration(
          isDense: true,
          counterText: '',
          labelText: labelText,
        ),
        validator: (x) => x != null && x.isNotEmpty ? null : '',
      ),
    );
  }
}
