import 'package:flutter/material.dart';
import '../../config/theme.dart';

enum AppBadgeVariant { primary, success, warning, error, info, neutral }

enum AppBadgeSize { sm, md }

/// A modern SaaS-grade status badge / chip with soft tinted backgrounds and micro-borders
class AppBadge extends StatefulWidget {
  final String label;
  final AppBadgeVariant variant;
  final IconData? icon;
  final bool showPulse;
  final AppBadgeSize size;
  final bool outlined;
  final VoidCallback? onTap;

  const AppBadge({
    super.key,
    required this.label,
    this.variant = AppBadgeVariant.neutral,
    this.icon,
    this.showPulse = false,
    this.size = AppBadgeSize.md,
    this.outlined = false,
    this.onTap,
  });

  /// Shorthand constructor for active / success status
  const AppBadge.success(
    this.label, {
    super.key,
    this.icon,
    this.showPulse = false,
    this.size = AppBadgeSize.md,
    this.outlined = false,
    this.onTap,
  }) : variant = AppBadgeVariant.success;

  /// Shorthand constructor for warning status
  const AppBadge.warning(
    this.label, {
    super.key,
    this.icon,
    this.showPulse = false,
    this.size = AppBadgeSize.md,
    this.outlined = false,
    this.onTap,
  }) : variant = AppBadgeVariant.warning;

  /// Shorthand constructor for error status
  const AppBadge.error(
    this.label, {
    super.key,
    this.icon,
    this.showPulse = false,
    this.size = AppBadgeSize.md,
    this.outlined = false,
    this.onTap,
  }) : variant = AppBadgeVariant.error;

  /// Shorthand constructor for info status
  const AppBadge.info(
    this.label, {
    super.key,
    this.icon,
    this.showPulse = false,
    this.size = AppBadgeSize.md,
    this.outlined = false,
    this.onTap,
  }) : variant = AppBadgeVariant.info;

  /// Shorthand constructor for neutral status
  const AppBadge.neutral(
    this.label, {
    super.key,
    this.icon,
    this.showPulse = false,
    this.size = AppBadgeSize.md,
    this.outlined = false,
    this.onTap,
  }) : variant = AppBadgeVariant.neutral;

  /// Shorthand constructor for primary status
  const AppBadge.primary(
    this.label, {
    super.key,
    this.icon,
    this.showPulse = false,
    this.size = AppBadgeSize.md,
    this.outlined = false,
    this.onTap,
  }) : variant = AppBadgeVariant.primary;

  @override
  State<AppBadge> createState() => _AppBadgeState();
}

class _AppBadgeState extends State<AppBadge>
    with SingleTickerProviderStateMixin {
  AnimationController? _pulseController;
  Animation<double>? _pulseAnimation;

  @override
  void initState() {
    super.initState();
    if (widget.showPulse) {
      _pulseController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1400),
      )..repeat(reverse: true);
      _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
        CurvedAnimation(parent: _pulseController!, curve: Curves.easeInOut),
      );
    }
  }

  @override
  void didUpdateWidget(AppBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showPulse && _pulseController == null) {
      _pulseController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1400),
      )..repeat(reverse: true);
      _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
        CurvedAnimation(parent: _pulseController!, curve: Curves.easeInOut),
      );
    } else if (!widget.showPulse && _pulseController != null) {
      _pulseController?.dispose();
      _pulseController = null;
      _pulseAnimation = null;
    }
  }

  @override
  void dispose() {
    _pulseController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    Color baseColor;
    switch (widget.variant) {
      case AppBadgeVariant.primary:
        baseColor = theme.colorScheme.primary;
        break;
      case AppBadgeVariant.success:
        baseColor = const Color(0xFF10B981);
        break;
      case AppBadgeVariant.warning:
        baseColor = const Color(0xFFF59E0B);
        break;
      case AppBadgeVariant.error:
        baseColor = const Color(0xFFEF4444);
        break;
      case AppBadgeVariant.info:
        baseColor = const Color(0xFF0EA5E9);
        break;
      case AppBadgeVariant.neutral:
        baseColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
        break;
    }

    final bgColor =
        isDark
            ? baseColor.withAlpha(widget.outlined ? 25 : 38)
            : baseColor.withAlpha(widget.outlined ? 18 : 28);

    final borderColor =
        isDark
            ? baseColor.withAlpha(widget.outlined ? 120 : 60)
            : baseColor.withAlpha(widget.outlined ? 100 : 45);

    final textColor = isDark ? baseColor : baseColor;

    final isSm = widget.size == AppBadgeSize.sm;
    final padH = isSm ? 7.0 : 10.0;
    final padV = isSm ? 2.5 : 4.5;
    final fontSize = isSm ? 11.0 : 12.0;
    final iconSize = isSm ? 11.0 : 13.0;
    final dotSize = isSm ? 5.0 : 6.5;

    Widget badgeContent = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (widget.showPulse) ...[
          if (_pulseAnimation != null && !reduceMotion)
            AnimatedBuilder(
              animation: _pulseAnimation!,
              builder: (context, child) {
                return Opacity(
                  opacity: _pulseAnimation!.value,
                  child: Container(
                    width: dotSize,
                    height: dotSize,
                    decoration: BoxDecoration(
                      color: baseColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: baseColor.withAlpha(120),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                );
              },
            )
          else
            Container(
              width: dotSize,
              height: dotSize,
              decoration: BoxDecoration(
                color: baseColor,
                shape: BoxShape.circle,
              ),
            ),
          SizedBox(width: isSm ? 4 : 6),
        ],
        if (widget.icon != null) ...[
          Icon(widget.icon, size: iconSize, color: textColor),
          SizedBox(width: isSm ? 3 : 5),
        ],
        Text(
          widget.label,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            color: textColor,
            letterSpacing: 0.1,
            height: 1.15,
          ),
        ),
      ],
    );

    Widget badge = Container(
      padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: AppRadius.roundedFull,
        border: Border.all(color: borderColor, width: 1),
      ),
      child: badgeContent,
    );

    if (widget.onTap != null) {
      badge = Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AppRadius.roundedFull,
          onTap: widget.onTap,
          child: badge,
        ),
      );
    }

    return badge;
  }
}
