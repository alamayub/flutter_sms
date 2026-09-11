import 'package:flutter/material.dart';
import '../../config/theme.dart';

/// Premium interactive tactile card widget adhering to modern 3D design tokens.
class AppCard extends StatefulWidget {
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
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    final radius = widget.borderRadius ?? AppRadius.roundedXl;
    final surfaceBg =
        widget.backgroundColor ??
        (isDark ? theme.colorScheme.surface : theme.colorScheme.surface);

    final borderColor =
        isDark
            ? (_isHovered && widget.accentColor != null
                ? widget.accentColor!.withAlpha(120)
                : theme.colorScheme.outlineVariant.withAlpha(90))
            : (_isHovered && widget.accentColor != null
                ? widget.accentColor!.withAlpha(100)
                : theme.colorScheme.outlineVariant.withAlpha(120));

    final shadows =
        widget.depth3d
            ? AppShadows.depth3d(isDark)
            : (_isHovered && widget.isHoverable && widget.onTap != null
                ? (isDark ? AppShadows.hoverDark : AppShadows.hoverLight)
                : (isDark ? AppShadows.cardDark : AppShadows.cardLight));

    Widget cardBox = Container(
      width: widget.width,
      height: widget.height,
      margin: widget.margin,
      decoration: BoxDecoration(
        color: surfaceBg,
        borderRadius: radius,
        border: widget.border ?? Border.all(color: borderColor, width: 1),
        boxShadow: shadows,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            // Top specular highlight bevel
            if (widget.depth3d || widget.accentColor == null)
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
            if (widget.accentColor != null)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 3,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: AppGradients.topAccentBar(widget.accentColor!),
                  ),
                ),
              ),

            // Card body
            Padding(
              padding: widget.padding ?? const EdgeInsets.all(16),
              child: widget.child,
            ),

            // Inkwell ripple when clickable
            if (widget.onTap != null)
              Positioned.fill(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: radius,
                    mouseCursor: SystemMouseCursors.click,
                    onTap: widget.onTap,
                    onHighlightChanged: (highlighted) {
                      if (!reduceMotion && mounted) {
                        setState(() => _isPressed = highlighted);
                      }
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    if (widget.onTap != null) {
      cardBox = MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) {
          if (!reduceMotion && mounted && widget.isHoverable) {
            setState(() => _isHovered = true);
          }
        },
        onExit: (_) {
          if (!reduceMotion && mounted && widget.isHoverable) {
            setState(() => _isHovered = false);
          }
        },
        child: AnimatedScale(
          scale:
              !reduceMotion
                  ? (_isPressed
                      ? 0.985
                      : (_isHovered && widget.isHoverable ? 1.008 : 1.0))
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
