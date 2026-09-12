import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import '../../config/theme.dart';

/// Premium interactive tactile card widget adhering to modern 3D design tokens.
class AppCard extends HookWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? accentColor;
  final bool isHoverable;
  final bool depth3d;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;
  final Border? border;
  final double? width;
  final double? height;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.onTap,
    this.accentColor,
    this.isHoverable = true,
    this.depth3d = false,
    this.borderRadius,
    this.backgroundColor,
    this.border,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final isHovered = useState<bool>(false);
    final isPressed = useState<bool>(false);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    final radius = borderRadius ?? AppRadius.roundedXl;
    final surfaceBg =
        backgroundColor ??
        (isDark ? theme.colorScheme.surface : theme.colorScheme.surface);

    final borderColor =
        isDark
            ? (isHovered.value && accentColor != null
                ? accentColor!.withAlpha(120)
                : theme.colorScheme.outlineVariant.withAlpha(90))
            : (isHovered.value && accentColor != null
                ? accentColor!.withAlpha(100)
                : theme.colorScheme.outlineVariant.withAlpha(120));

    final shadows =
        depth3d
            ? AppShadows.depth3d(isDark)
            : (isHovered.value && isHoverable && onTap != null
                ? (isDark ? AppShadows.hoverDark : AppShadows.hoverLight)
                : (isDark ? AppShadows.cardDark : AppShadows.cardLight));

    Widget cardBox = Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: surfaceBg,
        borderRadius: radius,
        border: border ?? Border.all(color: borderColor, width: 1),
        boxShadow: shadows,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            // Top specular highlight bevel
            if (depth3d || accentColor == null)
              Positioned(
                top: 0,
                left: 1,
                right: 1,
                height: 1.2,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: AppGradients.specularHighlight,
                  ),
                ),
              ),

            // Optional top accent gradient line
            if (accentColor != null)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 3,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: AppGradients.topAccentBar(accentColor!),
                  ),
                ),
              ),

            // Card body
            Padding(padding: padding ?? const EdgeInsets.all(16), child: child),

            // Inkwell ripple when clickable
            if (onTap != null)
              Positioned.fill(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: radius,
                    mouseCursor: SystemMouseCursors.click,
                    onTap: onTap,
                    onHighlightChanged: (highlighted) {
                      if (!reduceMotion && context.mounted) {
                        isPressed.value = highlighted;
                      }
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    if (onTap != null) {
      cardBox = MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) {
          if (!reduceMotion && context.mounted && isHoverable) {
            isHovered.value = true;
          }
        },
        onExit: (_) {
          if (!reduceMotion && context.mounted && isHoverable) {
            isHovered.value = false;
          }
        },
        child: AnimatedScale(
          scale:
              !reduceMotion
                  ? (isPressed.value
                      ? 0.985
                      : (isHovered.value && isHoverable ? 1.008 : 1.0))
                  : 1.0,
          duration: AppMotion.snappy,
          curve: AppMotion.snappyCurve,
          child: cardBox,
        ),
      );
    }

    return cardBox;
  }
}
