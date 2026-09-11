import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:sms/config/theme.dart';

/// Lightweight custom vector graphics and procedural canvas decorators
/// designed for zero-asset, high-performance, 120 FPS rendering.

/// An ambient aurora glow mesh that renders smooth multi-point radial gradients.
/// Wrapped in a [RepaintBoundary] to ensure zero GPU/CPU cost during parent layout or scrolling.
class AuroraMeshBackground extends StatelessWidget {
  final Widget? child;
  final double opacity;
  final List<Color>? colors;
  final Alignment focalAlignment;

  const AuroraMeshBackground({
    super.key,
    this.child,
    this.opacity = 0.85,
    this.colors,
    this.focalAlignment = Alignment.topRight,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultColors =
        isDark
            ? [
              AppColors.primary.withAlpha((opacity * 40).round()),
              AppColors.secondary.withAlpha((opacity * 25).round()),
              AppColors.accent.withAlpha((opacity * 30).round()),
            ]
            : [
              AppColors.primary.withAlpha((opacity * 25).round()),
              AppColors.secondary.withAlpha((opacity * 15).round()),
              AppColors.accent.withAlpha((opacity * 20).round()),
            ];

    return RepaintBoundary(
      child: CustomPaint(
        painter: _AuroraMeshPainter(
          colors: colors ?? defaultColors,
          focalAlignment: focalAlignment,
        ),
        child: child,
      ),
    );
  }
}

class _AuroraMeshPainter extends CustomPainter {
  final List<Color> colors;
  final Alignment focalAlignment;

  _AuroraMeshPainter({required this.colors, required this.focalAlignment});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final rect = Offset.zero & size;
    final paint = Paint()..isAntiAlias = true;

    // Orb 1: Primary anchor orb based on focalAlignment
    final dx1 = size.width * ((focalAlignment.x + 1) / 2);
    final dy1 = size.height * ((focalAlignment.y + 1) / 2);
    final radius1 = math.max(size.width, size.height) * 0.7;

    paint.shader = RadialGradient(
      center: Alignment(focalAlignment.x, focalAlignment.y),
      radius: 0.85,
      colors: [colors[0], colors[0].withAlpha(0)],
      stops: const [0.0, 1.0],
    ).createShader(rect);
    canvas.drawCircle(Offset(dx1, dy1), radius1, paint);

    // Orb 2: Secondary orbital balance orb (bottom left offset)
    if (colors.length > 1) {
      final dx2 = size.width * 0.15;
      final dy2 = size.height * 0.85;
      final radius2 = math.max(size.width, size.height) * 0.55;

      paint.shader = RadialGradient(
        center: const Alignment(-0.7, 0.7),
        radius: 0.7,
        colors: [colors[1], colors[1].withAlpha(0)],
        stops: const [0.0, 1.0],
      ).createShader(rect);
      canvas.drawCircle(Offset(dx2, dy2), radius2, paint);
    }

    // Orb 3: Accent subtle shimmer
    if (colors.length > 2) {
      final dx3 = size.width * 0.85;
      final dy3 = size.height * 0.5;
      final radius3 = math.max(size.width, size.height) * 0.45;

      paint.shader = RadialGradient(
        center: const Alignment(0.7, 0.0),
        radius: 0.6,
        colors: [colors[2], colors[2].withAlpha(0)],
        stops: const [0.0, 1.0],
      ).createShader(rect);
      canvas.drawCircle(Offset(dx3, dy3), radius3, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AuroraMeshPainter oldDelegate) {
    return oldDelegate.focalAlignment != focalAlignment ||
        oldDelegate.colors != colors;
  }
}

/// Geometric decorative watermark painted in the corner of dashboard cards.
/// Delivers high-end architectural feel with zero raster image overhead.
class GeometricCardDecor extends StatelessWidget {
  final Color? color;
  final double size;
  final Alignment alignment;

  const GeometricCardDecor({
    super.key,
    this.color,
    this.size = 110,
    this.alignment = Alignment.topRight,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor =
        color ??
        (Theme.of(context).brightness == Brightness.dark
            ? Colors.white.withAlpha(16)
            : AppColors.primary.withAlpha(20));

    return Align(
      alignment: alignment,
      child: RepaintBoundary(
        child: SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _GeometricCardDecorPainter(color: effectiveColor),
          ),
        ),
      ),
    );
  }
}

class _GeometricCardDecorPainter extends CustomPainter {
  final Color color;

  _GeometricCardDecorPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.25
          ..isAntiAlias = true;

    final fillPaint =
        Paint()
          ..color = color.withAlpha(((color.a * 255.0) * 0.35).round())
          ..style = PaintingStyle.fill
          ..isAntiAlias = true;

    final center = Offset(size.width * 0.85, size.height * 0.15);

    // Concentric orbits
    canvas.drawCircle(center, size.width * 0.35, strokePaint);
    canvas.drawCircle(center, size.width * 0.55, strokePaint);
    canvas.drawCircle(center, size.width * 0.75, strokePaint);

    // Soft orbital moon
    canvas.drawCircle(
      Offset(center.dx - size.width * 0.38, center.dy + size.height * 0.25),
      size.width * 0.08,
      fillPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GeometricCardDecorPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Vector badge icon container that draws a subtle glowing squircle / shield
class VectorBadgeIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final double iconSize;

  const VectorBadgeIcon({
    super.key,
    required this.icon,
    required this.color,
    this.size = 46,
    this.iconSize = 22,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withAlpha(isDark ? 38 : 28),
        borderRadius: BorderRadius.circular(size * 0.32),
        border: Border.all(
          color: color.withAlpha(isDark ? 80 : 60),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withAlpha(isDark ? 45 : 30),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(child: Icon(icon, size: iconSize, color: color)),
    );
  }
}

/// Subtle glowing status dot for badges and headers
class StatusGlowDot extends StatelessWidget {
  final Color color;
  final double size;

  const StatusGlowDot({super.key, required this.color, this.size = 8.0});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withAlpha(160),
            blurRadius: size * 1.5,
            spreadRadius: 1.0,
          ),
        ],
      ),
    );
  }
}
