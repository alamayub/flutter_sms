import 'dart:ui';
import 'package:flutter/material.dart';
import '../../config/theme.dart';

/// Modal bottom sheet action item configuration
class AppBottomSheetAction {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color? color;
  final VoidCallback onTap;
  final bool isDestructive;

  const AppBottomSheetAction({
    required this.title,
    this.subtitle,
    this.icon,
    this.color,
    required this.onTap,
    this.isDestructive = false,
  });
}

/// Standardized adaptive mobile bottom sheet system
class AppBottomSheet extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;
  final bool showHandle;
  final EdgeInsets padding;

  const AppBottomSheet({
    super.key,
    this.title,
    this.subtitle,
    required this.child,
    this.trailing,
    this.showHandle = true,
    this.padding = const EdgeInsets.fromLTRB(20, 12, 20, 24),
  });

  /// Displays an adaptive, frosted bottom sheet
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    String? title,
    String? subtitle,
    Widget? trailing,
    bool isDismissible = true,
    bool enableDrag = true,
    bool isScrollControlled = true,
    double? maxHeightFraction = 0.88,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      isScrollControlled: isScrollControlled,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (sheetContext) {
        final maxHeight =
            MediaQuery.of(sheetContext).size.height *
            (maxHeightFraction ?? 0.88);

        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: AppBottomSheet(
            title: title,
            subtitle: subtitle,
            trailing: trailing,
            child: child,
          ),
        );
      },
    );
  }

  /// Convenience helper to display a standardized list of interactive actions
  static Future<T?> showActionList<T>({
    required BuildContext context,
    required List<AppBottomSheetAction> actions,
    String? title,
    String? subtitle,
  }) {
    return show<T>(
      context: context,
      title: title,
      subtitle: subtitle,
      isScrollControlled: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children:
            actions.map((action) {
              final isDestructive = action.isDestructive;
              final color =
                  action.color ??
                  (isDestructive
                      ? AppColors.error
                      : Theme.of(context).colorScheme.onSurface);

              return Material(
                color: Colors.transparent,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  leading:
                      action.icon != null
                          ? Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: color.withAlpha(20),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(action.icon, color: color, size: 20),
                          )
                          : null,
                  title: Text(
                    action.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: color,
                    ),
                  ),
                  subtitle:
                      action.subtitle != null
                          ? Text(
                            action.subtitle!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withAlpha(140),
                            ),
                          )
                          : null,
                  trailing: const Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: Color(0xFF94A3B8),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    action.onTap();
                  },
                ),
              );
            }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor =
        isDark
            ? const Color(0xFF0F172A).withAlpha(240)
            : Colors.white.withAlpha(245);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(
              color:
                  isDark
                      ? Colors.white.withAlpha(25)
                      : Colors.black.withAlpha(15),
              width: 1,
            ),
            boxShadow: AppShadows.depth3d(isDark),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Drag handle
                if (showHandle)
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 10, bottom: 6),
                      width: 40,
                      height: 4.5,
                      decoration: BoxDecoration(
                        color:
                            isDark
                                ? Colors.white.withAlpha(45)
                                : Colors.black.withAlpha(40),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),

                // Header if title or trailing provided
                if (title != null || trailing != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 16, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (title != null)
                                Text(
                                  title!,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              if (subtitle != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  subtitle!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurface
                                        .withAlpha(150),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (trailing != null) trailing!,
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          visualDensity: VisualDensity.compact,
                          splashRadius: 20,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),

                if (title != null || trailing != null)
                  Divider(
                    height: 1,
                    thickness: 1,
                    color:
                        isDark
                            ? Colors.white.withAlpha(15)
                            : Colors.black.withAlpha(12),
                  ),

                // Content body
                Flexible(child: Padding(padding: padding, child: child)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
