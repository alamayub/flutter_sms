import 'package:flutter/material.dart';

import '../../config/constants.dart' show Strings;
import '../../config/extensions.dart' show DialogText;
import '../../config/theme.dart' show ColorConstants;
import '../buttons/dialog_action_button.dart';

class FormDialog extends StatelessWidget {
  final String title;
  final Widget content;
  final Function() onPressed;
  const FormDialog({
    super.key,
    required this.title,
    required this.content,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: title.dialogTitle,
      content: content,
      actions: [
        DialogActionButton(
          color: Colors.redAccent,
          title: Strings.cancle,
          onPressed: () => Navigator.pop(context),
        ),
        DialogActionButton(
          color: ColorConstants.primary,
          title: Strings.submit,
          onPressed: onPressed,
        ),
      ],
    );
  }
}
