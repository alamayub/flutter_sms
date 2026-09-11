import 'package:flutter/material.dart';
import 'app_button.dart';

/// Clean, lightweight vector-drawn illustration background for empty states
class _EmptyStateIllustrationPainter extends CustomPainter {
  final Color primaryColor;
  final bool isDark;

  _EmptyStateIllustrationPainter({
    required this.primaryColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paintCircle1 =
        Paint()
          ..color = primaryColor.withAlpha(isDark ? 18 : 22)
          ..style = PaintingStyle.fill;

    final paintCircle2 =
        Paint()
          ..color = primaryColor.withAlpha(isDark ? 30 : 38)
          ..style = PaintingStyle.fill;

    final paintRing =
        Paint()
          ..color = primaryColor.withAlpha(isDark ? 45 : 55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;

    // Outer faint disc
    canvas.drawCircle(center, size.width * 0.48, paintCircle1);
    // Inner softer disc
    canvas.drawCircle(center, size.width * 0.32, paintCircle2);
    // Concentric dashed/solid micro ring
    canvas.drawCircle(center, size.width * 0.40, paintRing);
  }

  @override
  bool shouldRepaint(covariant _EmptyStateIllustrationPainter oldDelegate) {
    return oldDelegate.primaryColor != primaryColor ||
        oldDelegate.isDark != isDark;
  }
}

/// A professional SaaS-grade empty state presentation widget
class AppEmptyState extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget? action;
  final bool isCompact;
  final double? minHeight;

  const AppEmptyState({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.folder_open_outlined,
    this.action,
    this.isCompact = false,
    this.minHeight,
  });

  /// Factory for standard empty dataset
  factory AppEmptyState.noData({
    Key? key,
    String title = 'No records found',
    String subtitle = 'There is nothing to display right now.',
    IconData icon = Icons.inbox_outlined,
    Widget? action,
    bool isCompact = false,
    double? minHeight,
  }) {
    return AppEmptyState(
      key: key,
      title: title,
      subtitle: subtitle,
      icon: icon,
      action: action,
      isCompact: isCompact,
      minHeight: minHeight,
    );
  }

  /// Factory for search with zero matches
  factory AppEmptyState.search({
    Key? key,
    String? query,
    String title = 'No matching results',
    String? subtitle,
    VoidCallback? onClear,
    bool isCompact = false,
    double? minHeight,
  }) {
    final effectiveSubtitle =
        subtitle ??
        (query != null && query.trim().isNotEmpty
            ? 'No results found matching "$query". Try checking for typos or using different keywords.'
            : 'No records found matching your search.');

    return AppEmptyState(
      key: key,
      title: title,
      subtitle: effectiveSubtitle,
      icon: Icons.search_off_rounded,
      isCompact: isCompact,
      minHeight: minHeight,
      action:
          onClear != null
              ? AppButton.secondary(
                text: 'Clear Search',
                leadingIcon: const Icon(Icons.clear_rounded, size: 16),
                onPressed: onClear,
                size:
                    isCompact
                        ? AppButtonSizeVariant.sm
                        : AppButtonSizeVariant.md,
              )
              : null,
    );
  }

  /// Factory for filtered empty states
  factory AppEmptyState.filter({
    Key? key,
    String title = 'No results match filters',
    String subtitle =
        'Try adjusting or clearing your active filters to see records.',
    VoidCallback? onReset,
    bool isCompact = false,
    double? minHeight,
  }) {
    return AppEmptyState(
      key: key,
      title: title,
      subtitle: subtitle,
      icon: Icons.filter_alt_off_outlined,
      isCompact: isCompact,
      minHeight: minHeight,
      action:
          onReset != null
              ? AppButton.secondary(
                text: 'Reset Filters',
                leadingIcon: const Icon(Icons.refresh_rounded, size: 16),
                onPressed: onReset,
                size:
                    isCompact
                        ? AppButtonSizeVariant.sm
                        : AppButtonSizeVariant.md,
              )
              : null,
    );
  }

  /// Factory for offline / no connection state
  factory AppEmptyState.offline({
    Key? key,
    String title = 'No network connection',
    String subtitle =
        'Please check your internet or local network connection and try again.',
    VoidCallback? onRetry,
    bool isCompact = false,
    double? minHeight,
  }) {
    return AppEmptyState(
      key: key,
      title: title,
      subtitle: subtitle,
      icon: Icons.wifi_off_rounded,
      isCompact: isCompact,
      minHeight: minHeight,
      action:
          onRetry != null
              ? AppButton.primary(
                text: 'Retry Connection',
                leadingIcon: const Icon(Icons.refresh_rounded, size: 16),
                onPressed: onRetry,
                size:
                    isCompact
                        ? AppButtonSizeVariant.sm
                        : AppButtonSizeVariant.md,
              )
              : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    final discSize = isCompact ? 64.0 : 100.0;
    final iconSize = isCompact ? 28.0 : 44.0;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: minHeight ?? (isCompact ? 140 : 260),
          maxWidth: 440,
        ),
        child: Padding(
          padding: EdgeInsets.all(isCompact ? 16.0 : 28.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Vector illustrated icon disc
              SizedBox(
                width: discSize,
                height: discSize,
                child: CustomPaint(
                  painter: _EmptyStateIllustrationPainter(
                    primaryColor: primary,
                    isDark: isDark,
                  ),
                  child: Center(
                    child: Icon(icon, size: iconSize, color: primary),
                  ),
                ),
              ),
              SizedBox(height: isCompact ? 12 : 20),

              // Title
              Text(
                title,
                textAlign: TextAlign.center,
                style: (isCompact
                        ? theme.textTheme.titleSmall
                        : theme.textTheme.titleMedium)
                    ?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
              ),

              // Subtitle
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],

              // Call to Action
              if (action != null) ...[
                SizedBox(height: isCompact ? 12 : 20),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
