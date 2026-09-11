import 'dart:ui';
import 'package:flutter/material.dart';
import '../../config/theme.dart';
import 'app_button.dart';

/// Supported loader size scales
enum AppLoaderSize { sm, md, lg }

/// Universal inline spinner with brand glow and optional message.
class AppLoader extends StatelessWidget {
  final AppLoaderSize size;
  final String? message;
  final Color? color;
  final bool isCenter;

  const AppLoader({
    super.key,
    this.size = AppLoaderSize.md,
    this.message,
    this.color,
    this.isCenter = true,
  });

  const AppLoader.sm({
    super.key,
    this.message,
    this.color,
    this.isCenter = true,
  }) : size = AppLoaderSize.sm;

  const AppLoader.lg({
    super.key,
    this.message,
    this.color,
    this.isCenter = true,
  }) : size = AppLoaderSize.lg;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary =
        color ?? (isDark ? AppTheme.primaryLight : AppTheme.primaryColor);

    final double spinnerSize;
    final double strokeWidth;
    final TextStyle? textStyle;

    switch (size) {
      case AppLoaderSize.sm:
        spinnerSize = 20.0;
        strokeWidth = 2.0;
        textStyle = theme.textTheme.bodySmall?.copyWith(
          color:
              isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
        );
        break;
      case AppLoaderSize.lg:
        spinnerSize = 48.0;
        strokeWidth = 3.5;
        textStyle = theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
        );
        break;
      case AppLoaderSize.md:
        spinnerSize = 34.0;
        strokeWidth = 2.8;
        textStyle = theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w500,
          color:
              isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
        );
        break;
    }

    final loaderWidget = Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            // Ambient soft glow
            Container(
              width: spinnerSize + 12,
              height: spinnerSize + 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primary.withAlpha(isDark ? 25 : 20),
              ),
            ),
            // Progress Indicator
            SizedBox(
              width: spinnerSize,
              height: spinnerSize,
              child: CircularProgressIndicator(
                strokeWidth: strokeWidth,
                valueColor: AlwaysStoppedAnimation<Color>(primary),
                strokeCap: StrokeCap.round,
              ),
            ),
          ],
        ),
        if (message != null && message!.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(message!, textAlign: TextAlign.center, style: textStyle),
        ],
      ],
    );

    if (isCenter) {
      return Center(child: loaderWidget);
    }
    return loaderWidget;
  }
}

/// Universal blocking overlay during critical asynchronous tasks.
class AppLoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;
  final String? message;
  final VoidCallback? onCancel;
  final String cancelText;

  const AppLoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.message,
    this.onCancel,
    this.cancelText = 'Cancel',
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.passthrough,
      children: [
        child,
        if (isLoading)
          Positioned.fill(
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.0, end: 1.0),
              duration: AppMotion.standard,
              curve: AppMotion.standardCurve,
              builder: (context, opacity, _) {
                return BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: 4.0 * opacity,
                    sigmaY: 4.0 * opacity,
                  ),
                  child: Container(
                    color: (Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF0B0F19)
                            : Colors.white)
                        .withAlpha((180 * opacity).round()),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 24,
                        ),
                        constraints: const BoxConstraints(maxWidth: 320),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardTheme.color,
                          borderRadius: BorderRadius.circular(AppRadius.xxl),
                          border: Border.all(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? AppTheme.darkBorder
                                    : AppTheme.lightBorder,
                          ),
                          boxShadow: AppShadows.popover(
                            Theme.of(context).brightness == Brightness.dark,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AppLoader(size: AppLoaderSize.md, message: message),
                            if (onCancel != null) ...[
                              const SizedBox(height: 18),
                              AppButton.ghost(
                                size: AppButtonSizeVariant.sm,
                                text: cancelText,
                                onPressed: onCancel,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
