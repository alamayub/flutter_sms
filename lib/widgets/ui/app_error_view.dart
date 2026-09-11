import 'package:flutter/material.dart';
import '../../config/theme.dart';
import 'app_button.dart';

/// Universal error presentation widget with retry trigger and technical details inspection.
class AppErrorView extends StatefulWidget {
  final String title;
  final String? message;
  final dynamic error;
  final StackTrace? stackTrace;
  final VoidCallback? onRetry;
  final String retryText;
  final bool isCompact;
  final double? minHeight;

  const AppErrorView({
    super.key,
    this.title = 'Failed to load data',
    this.message,
    this.error,
    this.stackTrace,
    this.onRetry,
    this.retryText = 'Try Again',
    this.isCompact = false,
    this.minHeight,
  });

  @override
  State<AppErrorView> createState() => _AppErrorViewState();
}

class _AppErrorViewState extends State<AppErrorView> {
  bool _expandedDetails = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final discSize = widget.isCompact ? 56.0 : 80.0;
    final iconSize = widget.isCompact ? 28.0 : 40.0;

    final displayMessage =
        widget.message ??
        (widget.error != null
            ? widget.error.toString().replaceFirst(
              RegExp(r'^[A-Za-z]+Exception:?\s*'),
              '',
            )
            : 'An unexpected issue occurred while communicating with local storage.');

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: widget.minHeight ?? (widget.isCompact ? 120 : 240),
          maxWidth: 480,
        ),
        child: Padding(
          padding: EdgeInsets.all(widget.isCompact ? 12.0 : 24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Error icon disc with soft red glow
              Container(
                width: discSize,
                height: discSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.errorColor.withAlpha(isDark ? 30 : 20),
                  border: Border.all(
                    color: AppTheme.errorColor.withAlpha(isDark ? 60 : 40),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.error_outline_rounded,
                    size: iconSize,
                    color: AppTheme.errorColor,
                  ),
                ),
              ),
              SizedBox(height: widget.isCompact ? 10 : 18),

              // Title
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: (widget.isCompact
                        ? theme.textTheme.titleSmall
                        : theme.textTheme.titleMedium)
                    ?.copyWith(
                      fontWeight: FontWeight.w700,
                      color:
                          isDark
                              ? AppTheme.darkTextPrimary
                              : AppTheme.lightTextPrimary,
                      fontFeatures: AppTypography.fontFeatures,
                    ),
              ),
              const SizedBox(height: 6),

              // Friendly explanation
              Text(
                displayMessage,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color:
                      isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.lightTextSecondary,
                  height: 1.4,
                  fontFeatures: AppTypography.fontFeatures,
                ),
                maxLines: widget.isCompact ? 2 : 4,
                overflow: TextOverflow.ellipsis,
              ),

              // Optional technical details expander
              if (widget.error != null && !widget.isCompact) ...[
                const SizedBox(height: 10),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor:
                        isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.lightTextSecondary,
                  ),
                  icon: Icon(
                    _expandedDetails ? Icons.expand_less : Icons.expand_more,
                    size: 16,
                  ),
                  label: Text(
                    _expandedDetails ? 'Hide Details' : 'View Details',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onPressed:
                      () =>
                          setState(() => _expandedDetails = !_expandedDetails),
                ),
                if (_expandedDetails) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:
                          isDark
                              ? const Color(0xFF0F172A)
                              : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                        color:
                            isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                      ),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Text(
                        '${widget.error}\n${widget.stackTrace ?? ''}',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: AppTheme.errorColor,
                        ),
                      ),
                    ),
                  ),
                ],
              ],

              // Retry Action Button
              if (widget.onRetry != null) ...[
                SizedBox(height: widget.isCompact ? 12 : 20),
                AppButton.primary(
                  size:
                      widget.isCompact
                          ? AppButtonSizeVariant.sm
                          : AppButtonSizeVariant.md,
                  leadingIcon: const Icon(Icons.refresh_rounded),
                  text: widget.retryText,
                  onPressed: widget.onRetry,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
