import 'package:flutter/material.dart';
import '../config/enums.dart';
import '../config/extensions.dart';
import '../widgets/ui/app_button.dart';

class UiHelpers {
  /// Show the app-wide floating snackbar notification.
  static void showSnackBar(
    BuildContext context,
    String message, {
    bool isError = false,
    bool isSuccess = false,
    Duration duration = const Duration(seconds: 3),
  }) {
    context.showSnackbar(
      message,
      type:
          isError
              ? MessageType.error
              : isSuccess
              ? MessageType.success
              : MessageType.neutral,
      duration: duration,
    );
  }

  /// Show standard confirmation dialog
  static Future<bool> showConfirmationDialog(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    bool isDestructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            content: Text(message),
            actions: [
              AppButton.ghost(
                onPressed: () => Navigator.of(ctx).pop(false),
                text: cancelText,
              ),
              if (isDestructive)
                AppButton.destructive(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  text: confirmText,
                )
              else
                AppButton.primary(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  text: confirmText,
                ),
            ],
          ),
    );

    return result ?? false;
  }
}

typedef UIHelpers = UiHelpers;
