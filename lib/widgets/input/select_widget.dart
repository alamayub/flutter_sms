import 'package:flutter/material.dart';

import '../../config/extensions.dart' show StringExtensions;
import '../../config/theme.dart' show ColorConstants, textDecorationTextStyle;
import '../../config/typo_config.dart';

class SelectWidget extends StatelessWidget {
  final List<String> lists;
  final String labelText;
  final String? value;
  final Function(String?)? onChanged;

  const SelectWidget({
    super.key,
    required this.lists,
    required this.labelText,
    this.value,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: DropdownButtonFormField<String>(
        value: value,
        items:
            lists
                .map(
                  (val) => DropdownMenuItem<String>(
                    value: val,
                    child: Text(
                      val.split('_').join(' ').capitalize,
                      style: textDecorationTextStyle(ColorConstants.textColor),
                    ),
                  ),
                )
                .toList(),
        onChanged: onChanged,
        style: typoConfig.textStyle.smallCaptionSubtitle2.copyWith(
          color: ColorConstants.textColor,
        ),
        iconSize: 16,
        decoration: InputDecoration(labelText: labelText),
        validator: (x) => x == null ? '' : null,
      ),
    );
  }
}
