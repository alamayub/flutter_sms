import 'dart:math' show Random;

import 'package:flutter/material.dart';
import '../widgets/loader_widget.dart';

import '../widgets/snackbar_widget.dart';
import 'enums.dart';

extension LightColorExtension on Color {
  static Color randomLight() {
    final random = Random();
    int red = 200 + random.nextInt(56);
    int green = 200 + random.nextInt(56);
    int blue = 200 + random.nextInt(56);
    return Color.fromARGB(255, red, green, blue);
  }
}

extension NavigationExtension on BuildContext {
  bool get canPop => Navigator.of(this).canPop();

  void pop<T>([T? result]) {
    if (canPop) {
      Navigator.of(this).pop<T>(result);
    }
  }

  Future<T?> push<T>(Widget page) {
    return Navigator.of(this).push<T>(MaterialPageRoute(builder: (_) => page));
  }

  Future<T?> pushReplacementFade<T, TO>(
    Widget target, {
    Duration duration = const Duration(milliseconds: 400),
  }) {
    return Navigator.of(this).pushReplacement<T, TO>(
      PageRouteBuilder<T>(
        pageBuilder: (_, animation, _) => target,
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: duration,
      ),
    );
  }

  Future<T?> pushAndRemoveUntil<T>(Widget page) {
    return Navigator.of(this).pushAndRemoveUntil<T>(
      MaterialPageRoute(builder: (_) => page),
      (_) => false,
    );
  }

  // show snackbbar
  void showSnackbar(
    Object message, {
    MessageType type = MessageType.success,
    Duration duration = const Duration(seconds: 5),
  }) {
    final resolvedMessage = switch (message) {
      String value => value,
      SnackBar snackBar when snackBar.content is Text =>
        (snackBar.content as Text).data ?? '',
      _ => message.toString(),
    };

    final overlay = Overlay.of(this);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder:
          (_) => SnackbarWidget(
            message: resolvedMessage,
            type: type,
            duration: duration,
            onDismiss: () => entry.remove(),
          ),
    );

    overlay.insert(entry);
  }

  Future<bool?> showGenericDialog({
    required String title,
    required dynamic content,
    String cancelText = 'Cancel',
    String submitText = 'Submit',
    Function()? onSubmit,
    bool loading = false,
    bool showActions = true,
  }) => showDialog<bool>(
    context: this,
    builder:
        (_) => AlertDialog(
          title: Text(title),
          content: content is String ? Text(content) : content,
          actions:
              showActions
                  ? <Widget>[
                    TextButton(
                      child: Text(cancelText),
                      onPressed: () => Navigator.of(this).pop(false),
                    ),
                    ElevatedButton(
                      onPressed:
                          loading
                              ? null
                              : () async {
                                await onSubmit?.call();
                                Navigator.of(this).pop(true);
                              },
                      child: loading ? const LoaderWidget() : Text(submitText),
                    ),
                  ]
                  : [],
        ),
  );

  void showAppBottomSheet<T>(Widget child, {bool isScrollControlled = true}) {
    showModalBottomSheet<T>(
      context: this,
      isScrollControlled: isScrollControlled,
      backgroundColor: const Color(0xFFF5F5F5),
      builder:
          (context) => Padding(
            padding: EdgeInsets.only(
              top: 24,
              left: 24,
              right: 24,
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: SafeArea(child: child),
          ),
    );
  }

  /// Returns the widget so you can place it anywhere in the UI.
  Widget popupMenuButton<T>({
    required Map<T, String> items,
    required ValueChanged<T> onSelected,
    Color? popupBackgroundColor,
    Color? buttonBackgroundColor,
    double menuItemHeight = 32,
    double menuIconSize = 30,
    Widget? icon,
  }) => Container(
    width: menuIconSize,
    height: menuIconSize,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: popupBackgroundColor ?? Colors.transparent,
    ),
    child: PopupMenuButton<T>(
      icon: icon ?? const Icon(Icons.more_vert, size: 18),
      onSelected: onSelected,
      color: buttonBackgroundColor,
      padding: EdgeInsetsGeometry.all(6),
      menuPadding: EdgeInsets.symmetric(vertical: 8),
      itemBuilder: (context) {
        return items.entries
            .map(
              (e) => PopupMenuItem<T>(
                value: e.key,
                height: menuItemHeight,
                child: Text(
                  e.value,
                  style: Theme.of(
                    this,
                  ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            )
            .toList();
      },
    ),
  );
}

extension OpacityToAlpha on double {
  int get toAlpha => (this * 255).round();
}
