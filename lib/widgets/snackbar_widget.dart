import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../../config/enums.dart';
import '../../config/extensions.dart';

class SnackbarStyle {
  final Color background;
  final Color text;
  final IconData icon;

  const SnackbarStyle({
    required this.background,
    required this.text,
    required this.icon,
  });
}

const _snackbarStyles = {
  MessageType.success: SnackbarStyle(
    background: Color(0xFF2ECC71),
    text: Colors.white,
    icon: Icons.check_circle,
  ),
  MessageType.error: SnackbarStyle(
    background: Color(0xFFE74C3C),
    text: Colors.white,
    icon: Icons.error,
  ),
  MessageType.warning: SnackbarStyle(
    background: Color(0xFFF39C12),
    text: Colors.black,
    icon: Icons.warning,
  ),
};

class SnackbarWidget extends HookWidget {
  final String message;
  final MessageType type;
  final Duration duration;
  final VoidCallback onDismiss;

  const SnackbarWidget({
    super.key,
    required this.message,
    required this.type,
    required this.duration,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final controller = useAnimationController(
      duration: const Duration(milliseconds: 350),
    );

    final scaleX = useMemoized(
      () => CurvedAnimation(parent: controller, curve: Curves.easeOutBack),
      [controller],
    );

    final opacity = useMemoized(
      () => Tween<double>(
        begin: 0,
        end: 1,
      ).animate(CurvedAnimation(parent: controller, curve: Curves.easeIn)),
      [controller],
    );

    final style = _snackbarStyles[type]!;

    useEffect(() {
      controller.forward();

      Future.delayed(duration, () async {
        await controller.reverse();
        onDismiss();
      });

      return null;
    }, const []);

    return Positioned(
      bottom: 80,
      left: 16,
      right: 16,
      child: Center(
        child: FadeTransition(
          opacity: opacity,
          child: AnimatedBuilder(
            animation: scaleX,
            builder: (_, child) {
              return Transform.scale(
                scaleX: scaleX.value,
                scaleY: 1,
                alignment: Alignment.center,
                child: child,
              );
            },
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 15,
                      spreadRadius: 5,
                      offset: Offset(0, 4),
                      color: Colors.black.withAlpha(0.15.toAlpha),
                    ),
                  ],
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: style.background,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Row(
                    spacing: 8,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(style.icon, color: style.text, size: 16),
                      Flexible(
                        child: Text(
                          message,
                          style: TextStyle(
                            height: 1.25,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: style.text,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
