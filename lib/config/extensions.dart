import 'package:flutter/material.dart';

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
}
