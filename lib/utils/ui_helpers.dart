import 'package:flutter/material.dart';
import '../widgets/ui/app_button.dart';
import '../widgets/ui/app_toast.dart';

class UiHelpers {
  /// Show modern floating toast notification via AppToast
  static void showSnackBar(
    BuildContext context,
    String message, {
    bool isError = false,
    bool isSuccess = false,
    Duration duration = const Duration(seconds: 3),
  }) {
    if (isError) {
      AppToast.showError(context, message, duration: duration);
    } else if (isSuccess) {
      AppToast.showSuccess(context, message, duration: duration);
    } else {
      AppToast.showInfo(context, message, duration: duration);
    }
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
