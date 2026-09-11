import 'package:flutter/material.dart';
import '../../config/theme.dart';

/// Shimmer loading skeleton placeholder with smooth GPU-efficient gradient animation
class AppSkeleton extends StatefulWidget {
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final ShapeBorder? shape;

  const AppSkeleton({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius,
    this.shape,
  });

  /// Single line of text skeleton
  const AppSkeleton.line({
    super.key,
    this.width,
    this.height = 14,
    this.borderRadius,
  }) : shape = null;

  /// Rounded card skeleton
  const AppSkeleton.card({
    super.key,
    this.width,
    this.height = 120,
    this.borderRadius,
  }) : shape = null;

  /// Circular skeleton for avatars or icons
  const AppSkeleton.circle({super.key, double size = 40})
    : width = size,
      height = size,
      borderRadius = null,
      shape = const CircleBorder();

  /// Avatar skeleton
  const AppSkeleton.avatar({super.key, double size = 40})
    : width = size,
      height = size,
      borderRadius = null,
      shape = const CircleBorder();

  /// Composite list skeleton placeholder
  static Widget list({
    Key? key,
    int count = 5,
    EdgeInsetsGeometry padding = const EdgeInsets.all(AppSpacing.md),
  }) {
    return ListView.separated(
      key: key,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: padding,
      itemCount: count,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
      itemBuilder:
          (context, _) => Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const AppSkeleton.circle(size: 40),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    AppSkeleton.line(width: 140, height: 15),
                    SizedBox(height: 6),
                    AppSkeleton.line(width: 220, height: 11),
                  ],
                ),
              ),
            ],
          ),
    );
  }

  /// Composite table skeleton placeholder
  static Widget table({
    Key? key,
    int rows = 6,
    int columns = 4,
    EdgeInsetsGeometry padding = const EdgeInsets.all(AppSpacing.md),
  }) {
    return Padding(
      key: key,
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header row
          Container(
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.sm,
              horizontal: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(8),
              borderRadius: AppRadius.roundedSm,
            ),
            child: Row(
              children: List.generate(
                columns,
                (i) => Expanded(
                  flex: i == 0 ? 3 : 2,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: AppSkeleton.line(height: 14, width: 60.0 + (i * 15)),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          // Data rows
          ...List.generate(
            rows,
            (r) => Padding(
              padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.sm,
                horizontal: AppSpacing.md,
              ),
              child: Row(
                children: List.generate(
                  columns,
                  (c) => Expanded(
                    flex: c == 0 ? 3 : 2,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: AppSkeleton.line(
                        height: 12,
                        width: 40.0 + ((r + c) % 4) * 20,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Composite cards grid/list skeleton
  static Widget cards({
    Key? key,
    int count = 4,
    EdgeInsetsGeometry padding = const EdgeInsets.all(AppSpacing.md),
  }) {
    return Padding(
      key: key,
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: List.generate(
          count,
          (i) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.withAlpha(40)),
                borderRadius: AppRadius.roundedMd,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  AppSkeleton.line(width: 160, height: 18),
                  SizedBox(height: 10),
                  AppSkeleton.line(width: double.infinity, height: 12),
                  SizedBox(height: 6),
                  AppSkeleton.line(width: 200, height: 12),
                  SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      AppSkeleton.line(width: 70, height: 28),
                      SizedBox(width: 8),
                      AppSkeleton.line(width: 70, height: 28),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Composite form skeleton
  static Widget form({
    Key? key,
    int fields = 4,
    EdgeInsetsGeometry padding = const EdgeInsets.all(AppSpacing.lg),
  }) {
    return Padding(
      key: key,
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: List.generate(
          fields,
          (i) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppSkeleton.line(width: 100, height: 13),
                const SizedBox(height: 8),
                AppSkeleton(height: 48, borderRadius: AppRadius.roundedMd),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  State<AppSkeleton> createState() => _AppSkeletonState();
}

class _AppSkeletonState extends State<AppSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _animation = Tween<double>(begin: -1.5, end: 2.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    final baseColor =
        isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    final highlightColor =
        isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9);

    final radius = widget.borderRadius ?? AppRadius.roundedMd;

    if (reduceMotion) {
      return Container(
        width: widget.width,
        height: widget.height,
        decoration: ShapeDecoration(
          color: baseColor,
          shape: widget.shape ?? RoundedRectangleBorder(borderRadius: radius),
        ),
      );
    }

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: ShapeDecoration(
            shape: widget.shape ?? RoundedRectangleBorder(borderRadius: radius),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              stops: const [0.0, 0.5, 1.0],
              colors: [baseColor, highlightColor, baseColor],
              transform: _SlidingGradientTransform(
                slidePercent: _animation.value,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  final double slidePercent;

  const _SlidingGradientTransform({required this.slidePercent});

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * slidePercent, 0.0, 0.0);
  }
}
