import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../../config/theme.dart' show ColorConstants, textDecorationTextStyle;

class DateInput extends HookWidget {
  final String hintText;
  final TextEditingController controller;
  final Function(String?) onTap;
  final String? firstDate;
  const DateInput({
    super.key,
    required this.controller,
    this.hintText = 'DOB*',
    required this.onTap,
    this.firstDate,
  });

  @override
  Widget build(BuildContext context) {
    var now = useState<DateTime>(DateTime.now());
    return SizedBox(
      height: 36,
      child: TextFormField(
        controller: controller,
        style: textDecorationTextStyle(ColorConstants.textColor),
        decoration: InputDecoration(
          labelText: '04/04/1999',
          hintText: hintText,
        ),
        textInputAction: TextInputAction.next,
        keyboardType: TextInputType.text,
        validator: (val) => val == null || val.isEmpty ? '' : null,
        onTap:
            () => showDatePicker(
              context: context,
              firstDate: DateTime(now.value.year - 20),
              lastDate: now.value,
            ).then((x) {
              if (x != null) {
                onTap(x.toString().split(' ').first);
              }
            }),
      ),
    );
  }
}
