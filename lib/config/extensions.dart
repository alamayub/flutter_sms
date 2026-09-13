import 'package:flutter/material.dart';

import '../widgets/snackbar_widget.dart';
import 'enums.dart';

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
}

extension OpacityToAlpha on double {
  int get toAlpha => (this * 255).round();
}
