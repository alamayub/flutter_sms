import 'package:flutter/material.dart';
import '../../config/theme.dart';

/// Toast notification visual variant
enum AppToastType { success, error, warning, info }

/// Universal, SaaS-grade floating toast notifications.
class AppToast {
  /// Show a toast notification on the current Scaffold
  static void show(
    BuildContext context, {
    required String message,
    String? title,
    AppToastType type = AppToastType.info,
    Duration duration = const Duration(milliseconds: 3500),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger.hideCurrentSnackBar();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final Color statusColor;
    final IconData statusIcon;
    final String defaultTitle;

    switch (type) {
      case AppToastType.success:
        statusColor = AppTheme.successColor;
        statusIcon = Icons.check_circle_rounded;
        defaultTitle = 'Success';
        break;
      case AppToastType.error:
        statusColor = AppTheme.errorColor;
        statusIcon = Icons.error_rounded;
        defaultTitle = 'Error';
        break;
      case AppToastType.warning:
        statusColor = AppTheme.warningColor;
        statusIcon = Icons.warning_rounded;
        defaultTitle = 'Warning';
        break;
      case AppToastType.info:
        statusColor = isDark ? AppTheme.primaryLight : AppTheme.primaryColor;
        statusIcon = Icons.info_rounded;
        defaultTitle = 'Information';
        break;
    }

    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final textPrimary =
        isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textSecondary =
        isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;

    messenger.showSnackBar(
      SnackBar(
        duration: duration,
        elevation: 0,
        backgroundColor: Colors.transparent,
        padding: EdgeInsets.zero,
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        behavior: SnackBarBehavior.floating,
        content: Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: cardBorder),
            boxShadow: [
              ...AppShadows.popover(isDark),
              BoxShadow(
                color: statusColor.withAlpha(25),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: IntrinsicHeight(
            child: Row(
              children: [
                // Left status colored vertical bar
                Container(width: 5, color: statusColor),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Status Icon Pill
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: statusColor.withAlpha(isDark ? 35 : 25),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(statusIcon, color: statusColor, size: 18),
                        ),
                        const SizedBox(width: 12),
                        // Title & Message
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (title != null && title.isNotEmpty)
                                Text(
                                  title,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: textPrimary,
                                    fontFeatures: AppTypography.fontFeatures,
                                  ),
                                )
                              else
                                Text(
                                  defaultTitle,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: textPrimary,
                                    fontFeatures: AppTypography.fontFeatures,
                                  ),
                                ),
                              const SizedBox(height: 2),
                              Text(
                                message,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: textSecondary,
                                  height: 1.3,
                                  fontFeatures: AppTypography.fontFeatures,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Optional Action Button
                        if (actionLabel != null && onAction != null) ...[
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () {
                              messenger.hideCurrentSnackBar();
                              onAction();
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: statusColor,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              actionLabel,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                        // Close button
                        IconButton(
                          icon: Icon(
                            Icons.close,
                            size: 16,
                            color: textSecondary,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 28,
                            minHeight: 28,
                          ),
                          tooltip: 'Dismiss',
                          onPressed: () => messenger.hideCurrentSnackBar(),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Convenience for success toasts
  static void showSuccess(
    BuildContext context,
    String message, {
    String? title,
    Duration duration = const Duration(milliseconds: 3500),
    String? actionLabel,
    VoidCallback? onAction,
  }) => show(
    context,
    message: message,
    title: title,
    type: AppToastType.success,
    duration: duration,
    actionLabel: actionLabel,
    onAction: onAction,
  );

  /// Convenience for error toasts
  static void showError(
    BuildContext context,
    String message, {
    String? title,
    Duration duration = const Duration(milliseconds: 4500),
    String? actionLabel,
    VoidCallback? onAction,
  }) => show(
    context,
    message: message,
    title: title,
    type: AppToastType.error,
    duration: duration,
    actionLabel: actionLabel,
    onAction: onAction,
  );

  /// Convenience for warning toasts
  static void showWarning(
    BuildContext context,
    String message, {
    String? title,
    Duration duration = const Duration(milliseconds: 4000),
    String? actionLabel,
    VoidCallback? onAction,
  }) => show(
    context,
    message: message,
    title: title,
    type: AppToastType.warning,
    duration: duration,
    actionLabel: actionLabel,
    onAction: onAction,
  );

  /// Convenience for info toasts
  static void showInfo(
    BuildContext context,
    String message, {
    String? title,
    Duration duration = const Duration(milliseconds: 3500),
    String? actionLabel,
    VoidCallback? onAction,
  }) => show(
    context,
    message: message,
    title: title,
    type: AppToastType.info,
    duration: duration,
    actionLabel: actionLabel,
    onAction: onAction,
  );
}
