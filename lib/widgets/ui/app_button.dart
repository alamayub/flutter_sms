import 'package:flutter/material.dart';
import '../../config/theme.dart';

/// Supported button visual variants
enum AppButtonVariant { primary, secondary, outline, destructive, ghost }

/// Supported button size scales
enum AppButtonSizeVariant { sm, md, lg }

/// Production-grade standardized tactile button conforming to the app's SaaS design tokens.
/// Features physical micro-interactions (press scale, specular bevels, smooth spring motion).
class AppButton extends StatefulWidget {
  final String? text;
  final Widget? child;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSizeVariant size;
  final Widget? leadingIcon;
  final Widget? trailingIcon;
  final bool isLoading;
  final bool isFullWidth;
  final String? tooltip;
  final FocusNode? focusNode;
  final bool autofocus;

  const AppButton({
    super.key,
    this.text,
    this.child,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSizeVariant.md,
    this.leadingIcon,
    this.trailingIcon,
    this.isLoading = false,
    this.isFullWidth = false,
    this.tooltip,
    this.focusNode,
    this.autofocus = false,
  }) : assert(
         text != null || child != null,
         'Either text or child must be provided.',
       );

  /// Convenience constructor for primary buttons
  const AppButton.primary({
    super.key,
    this.text,
    this.child,
    required this.onPressed,
    this.size = AppButtonSizeVariant.md,
    this.leadingIcon,
    this.trailingIcon,
    this.isLoading = false,
    this.isFullWidth = false,
    this.tooltip,
    this.focusNode,
    this.autofocus = false,
  }) : variant = AppButtonVariant.primary,
       assert(text != null || child != null);

  /// Convenience constructor for secondary / tonal buttons
  const AppButton.secondary({
    super.key,
    this.text,
    this.child,
    required this.onPressed,
    this.size = AppButtonSizeVariant.md,
    this.leadingIcon,
    this.trailingIcon,
    this.isLoading = false,
    this.isFullWidth = false,
    this.tooltip,
    this.focusNode,
    this.autofocus = false,
  }) : variant = AppButtonVariant.secondary,
       assert(text != null || child != null);

  /// Convenience constructor for outlined border buttons
  const AppButton.outline({
    super.key,
    this.text,
    this.child,
    required this.onPressed,
    this.size = AppButtonSizeVariant.md,
    this.leadingIcon,
    this.trailingIcon,
    this.isLoading = false,
    this.isFullWidth = false,
    this.tooltip,
    this.focusNode,
    this.autofocus = false,
  }) : variant = AppButtonVariant.outline,
       assert(text != null || child != null);

  /// Convenience constructor for destructive / danger action buttons
  const AppButton.destructive({
    super.key,
    this.text,
    this.child,
    required this.onPressed,
    this.size = AppButtonSizeVariant.md,
    this.leadingIcon,
    this.trailingIcon,
    this.isLoading = false,
    this.isFullWidth = false,
    this.tooltip,
    this.focusNode,
    this.autofocus = false,
  }) : variant = AppButtonVariant.destructive,
       assert(text != null || child != null);

  /// Convenience constructor for ghost / text action buttons
  const AppButton.ghost({
    super.key,
    this.text,
    this.child,
    required this.onPressed,
    this.size = AppButtonSizeVariant.md,
    this.leadingIcon,
    this.trailingIcon,
    this.isLoading = false,
    this.isFullWidth = false,
    this.tooltip,
    this.focusNode,
    this.autofocus = false,
  }) : variant = AppButtonVariant.ghost,
       assert(text != null || child != null);

  /// Convenience constructor for compact icon buttons
  static Widget icon({
    Key? key,
    required Widget icon,
    required VoidCallback? onPressed,
    AppButtonVariant variant = AppButtonVariant.ghost,
    AppButtonSizeVariant size = AppButtonSizeVariant.md,
    String? tooltip,
    bool isLoading = false,
  }) {
    return AppButton(
      key: key,
      variant: variant,
      size: size,
      onPressed: onPressed,
      isLoading: isLoading,
      tooltip: tooltip,
      child: icon,
    );
  }

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isEnabled = widget.onPressed != null && !widget.isLoading;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    // Resolve sizing tokens
    final double height;
    final EdgeInsets padding;
    final double fontSize;
    final double iconSize;

    switch (widget.size) {
      case AppButtonSizeVariant.sm:
        height = AppButtonSize.heightSm;
        padding =
            widget.text != null || widget.child is! Icon
                ? AppButtonSize.paddingSm
                : const EdgeInsets.all(7);
        fontSize = AppButtonSize.fontSizeSm;
        iconSize = AppButtonSize.iconSizeSm;
        break;
      case AppButtonSizeVariant.lg:
        height = AppButtonSize.heightLg;
        padding =
            widget.text != null || widget.child is! Icon
                ? AppButtonSize.paddingLg
                : const EdgeInsets.all(13);
        fontSize = AppButtonSize.fontSizeLg;
        iconSize = AppButtonSize.iconSizeLg;
        break;
      case AppButtonSizeVariant.md:
        height = AppButtonSize.heightMd;
        padding =
            widget.text != null || widget.child is! Icon
                ? AppButtonSize.paddingMd
                : const EdgeInsets.all(11);
        fontSize = AppButtonSize.fontSizeMd;
        iconSize = AppButtonSize.iconSizeMd;
        break;
    }

    // Resolve colors by variant
    Color backgroundColor;
    Color foregroundColor;
    BorderSide? borderSide;
    List<BoxShadow>? shadows;

    switch (widget.variant) {
      case AppButtonVariant.primary:
        backgroundColor =
            isEnabled
                ? (isDark ? AppTheme.primaryLight : AppTheme.primaryColor)
                : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0));
        foregroundColor =
            isEnabled
                ? Colors.white
                : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8));
        if (isEnabled) {
          shadows = [
            BoxShadow(
              color: backgroundColor.withAlpha(isDark ? 80 : 60),
              blurRadius: _isHovered ? 12 : 6,
              offset: Offset(0, _isHovered ? 4 : 2),
            ),
          ];
        }
        break;

      case AppButtonVariant.secondary:
        backgroundColor =
            isEnabled
                ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9))
                : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC));
        foregroundColor =
            isEnabled
                ? (isDark
                    ? AppTheme.darkTextPrimary
                    : AppTheme.lightTextPrimary)
                : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8));
        borderSide = BorderSide(
          color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
          width: 1,
        );
        break;

      case AppButtonVariant.outline:
        backgroundColor =
            _isHovered && isEnabled
                ? (isDark
                    ? AppTheme.primaryLight.withAlpha(20)
                    : AppTheme.primaryColor.withAlpha(15))
                : Colors.transparent;
        foregroundColor =
            isEnabled
                ? (isDark ? AppTheme.primaryLight : AppTheme.primaryColor)
                : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8));
        borderSide = BorderSide(
          color:
              isEnabled
                  ? (isDark ? AppTheme.primaryLight : AppTheme.primaryColor)
                  : (isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFCBD5E1)),
          width: 1.2,
        );
        break;

      case AppButtonVariant.destructive:
        backgroundColor =
            isEnabled
                ? AppTheme.errorColor
                : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0));
        foregroundColor =
            isEnabled
                ? Colors.white
                : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8));
        if (isEnabled) {
          shadows = [
            BoxShadow(
              color: AppTheme.errorColor.withAlpha(isDark ? 80 : 50),
              blurRadius: _isHovered ? 10 : 5,
              offset: Offset(0, _isHovered ? 3 : 2),
            ),
          ];
        }
        break;

      case AppButtonVariant.ghost:
        backgroundColor =
            _isHovered && isEnabled
                ? (isDark
                    ? Colors.white.withAlpha(15)
                    : const Color(0xFFF1F5F9))
                : Colors.transparent;
        foregroundColor =
            isEnabled
                ? (isDark
                    ? AppTheme.darkTextPrimary
                    : AppTheme.lightTextPrimary)
                : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8));
        break;
    }

    final effectiveTextStyle = AppTypography.button(
      fontSize: fontSize,
      fontWeight: FontWeight.w600,
      color: foregroundColor,
    );

    // Build content with icon spacing
    Widget content;
    if (widget.isLoading) {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: iconSize,
            height: iconSize,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(foregroundColor),
            ),
          ),
          if (widget.text != null || widget.child != null) ...[
            const SizedBox(width: 8),
            Text(widget.text ?? '', style: effectiveTextStyle),
          ],
        ],
      );
    } else {
      final List<Widget> children = [];

      if (widget.leadingIcon != null) {
        children.add(
          IconTheme(
            data: IconThemeData(color: foregroundColor, size: iconSize),
            child: widget.leadingIcon!,
          ),
        );
      }

      if (widget.text != null) {
        if (children.isNotEmpty) children.add(const SizedBox(width: 8));
        children.add(Text(widget.text!, style: effectiveTextStyle));
      } else if (widget.child != null) {
        if (children.isNotEmpty) children.add(const SizedBox(width: 8));
        children.add(widget.child!);
      }

      if (widget.trailingIcon != null) {
        children.add(const SizedBox(width: 8));
        children.add(
          IconTheme(
            data: IconThemeData(color: foregroundColor, size: iconSize),
            child: widget.trailingIcon!,
          ),
        );
      }

      content =
          children.length == 1
              ? children.first
              : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: children,
              );
    }

    final borderRadius = BorderRadius.circular(
      widget.variant == AppButtonVariant.ghost &&
              (widget.text == null && widget.child is Icon)
          ? AppRadius.md
          : AppRadius.lg,
    );

    // Subtle specular highlight for physical button polish
    final showSpecular =
        isEnabled &&
        (widget.variant == AppButtonVariant.primary ||
            widget.variant == AppButtonVariant.destructive);

    Widget buttonWidget = MouseRegion(
      cursor:
          isEnabled ? SystemMouseCursors.click : SystemMouseCursors.forbidden,
      onEnter: isEnabled ? (_) => setState(() => _isHovered = true) : null,
      onExit: isEnabled ? (_) => setState(() => _isHovered = false) : null,
      child: AnimatedScale(
        scale:
            !reduceMotion && isEnabled
                ? (_isPressed ? 0.975 : (_isHovered ? 1.015 : 1.0))
                : 1.0,
        duration: AppMotion.snappy,
        curve: AppMotion.snappyCurve,
        child: AnimatedContainer(
          duration: AppMotion.snappy,
          curve: AppMotion.snappyCurve,
          height: height,
          constraints: BoxConstraints(minWidth: height),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: borderRadius,
            border:
                borderSide != null ? Border.fromBorderSide(borderSide) : null,
            boxShadow: shadows,
          ),
          child: Stack(
            children: [
              // Specular light edge highlight across top border
              if (showSpecular)
                Positioned(
                  top: 0,
                  left: 2,
                  right: 2,
                  height: 1.2,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: AppGradients.specularHighlight,
                      borderRadius: borderRadius,
                    ),
                  ),
                ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: isEnabled ? widget.onPressed : null,
                  onHighlightChanged: (highlighted) {
                    if (isEnabled && !reduceMotion && mounted) {
                      setState(() => _isPressed = highlighted);
                    }
                  },
                  focusNode: widget.focusNode,
                  autofocus: widget.autofocus,
                  borderRadius: borderRadius,
                  splashColor: foregroundColor.withAlpha(25),
                  highlightColor: foregroundColor.withAlpha(15),
                  child: Padding(
                    padding: padding,
                    child: Center(
                      widthFactor: widget.isFullWidth ? null : 1.0,
                      child: content,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (widget.isFullWidth) {
      buttonWidget = SizedBox(width: double.infinity, child: buttonWidget);
    }

    if (widget.tooltip != null && widget.tooltip!.isNotEmpty) {
      buttonWidget = Tooltip(message: widget.tooltip!, child: buttonWidget);
    }

    return buttonWidget;
  }
}
