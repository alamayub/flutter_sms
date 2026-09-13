import 'package:flutter/material.dart';

import '../../config/extensions.dart';

class AppFormDialog extends StatelessWidget {
  final String title;
  final Widget content;
  final String cancelText;
  final String actionText;
  final VoidCallback? onCancel;
  final VoidCallback? onAction;
  final bool isSubmitting;
  final double width;

  const AppFormDialog({
    super.key,
    required this.title,
    required this.content,
    required this.cancelText,
    required this.actionText,
    required this.onAction,
    this.onCancel,
    this.isSubmitting = false,
    this.width = 500,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      content: SizedBox(width: width, child: content),
      actions: [
        TextButton(
          onPressed: isSubmitting ? null : onCancel ?? () => context.pop(),
          child: Text(cancelText),
        ),
        ElevatedButton(
          onPressed: isSubmitting ? null : onAction,
          child:
              isSubmitting
                  ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                  : Text(actionText),
        ),
      ],
    );
  }
}
