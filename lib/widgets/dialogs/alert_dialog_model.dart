import 'package:flutter/material.dart';

import '../../config/constants.dart' show Strings;
import '../../config/extensions.dart' show DialogText;
import '../../config/theme.dart' show ColorConstants;
import '../../config/typo_config.dart';
import '../buttons/dialog_action_button.dart';

@immutable
class GenericDialog extends AlertDialogModel<bool> {
  GenericDialog(String title)
    : super(
        title: title,
        message: '${Strings.genericAlertDescription}${title.toLowerCase()}?',
        buttons: {Strings.cancle: false, title: true},
      );
}

@immutable
class AlertDialogModel<T> {
  final String title;
  final String message;
  final Map<String, T> buttons;

  const AlertDialogModel({
    required this.title,
    required this.message,
    required this.buttons,
  });
}

extension Present<T> on AlertDialogModel<T> {
  Future<T?> present(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: title.dialogTitle,
          content: Text(
            message,
            style: typoConfig.textStyle.smallCaptionSubtitle2,
          ),
          actions:
              buttons.entries
                  .map(
                    (entry) => DialogActionButton(
                      color:
                          entry.value == true
                              ? ColorConstants.primary
                              : Colors.redAccent,
                      title: entry.key,
                      onPressed: () => Navigator.of(context).pop(entry.value),
                    ),
                  )
                  .toList(),
        );
      },
    );
  }
}
