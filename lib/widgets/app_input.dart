import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/theme.dart';

export 'searchable_select.dart';

/// Centralized factory for creating consistent, design-token-compliant [InputDecoration]
class AppInputDecoration {
  /// Standard form input decoration adhering to the app design system
  static InputDecoration standard(
    BuildContext context, {
    String? labelText,
    String? hintText,
    String? helperText,
    String? errorText,
    String? prefixText,
    String? suffixText,
    Widget? prefixIcon,
    Widget? suffixIcon,
    bool isDense = true,
    EdgeInsetsGeometry? contentPadding,
    bool enabled = true,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final focusColor = isDark ? AppTheme.primaryLight : AppTheme.primaryColor;

    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      helperText: helperText,
      errorText: errorText,
      prefixText: prefixText,
      suffixText: suffixText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      isDense: isDense,
      constraints: const BoxConstraints(minHeight: AppControlSize.standard),
      filled: true,
      fillColor: surfaceColor,
      contentPadding:
          contentPadding ??
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        borderSide: BorderSide(color: focusColor, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        borderSide: const BorderSide(color: AppTheme.errorColor),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        borderSide: const BorderSide(color: AppTheme.errorColor, width: 1.5),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
    );
  }

  /// Centralized dropdown input decoration
  static InputDecoration dropdown(
    BuildContext context, {
    String? labelText,
    String? hintText,
    String? helperText,
    String? errorText,
    Widget? prefixIcon,
    Widget? suffixIcon,
    bool isDense = true,
    EdgeInsetsGeometry? contentPadding,
    bool enabled = true,
  }) {
    return standard(
      context,
      labelText: labelText,
      hintText: hintText,
      helperText: helperText,
      errorText: errorText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      isDense: isDense,
      contentPadding: contentPadding,
      enabled: enabled,
    );
  }

  /// Centralized search bar input decoration
  static InputDecoration search(
    BuildContext context, {
    String hintText = 'Search...',
    Widget? prefixIcon,
    Widget? suffixIcon,
    VoidCallback? onClear,
    bool showClear = false,
    bool isDense = true,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final focusColor = isDark ? AppTheme.primaryLight : AppTheme.primaryColor;
    final iconColor =
        isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;

    return InputDecoration(
      hintText: hintText,
      prefixIcon: prefixIcon ?? Icon(Icons.search, size: 20, color: iconColor),
      suffixIcon:
          showClear && onClear != null
              ? IconButton(
                icon: Icon(Icons.clear, size: 18, color: iconColor),
                onPressed: onClear,
                splashRadius: 16,
                tooltip: 'Clear search',
              )
              : suffixIcon,
      isDense: isDense,
      constraints: const BoxConstraints(minHeight: AppControlSize.standard),
      filled: true,
      fillColor: surfaceColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        borderSide: BorderSide(color: focusColor, width: 1.5),
      ),
    );
  }

  /// Compact input decoration for table cells and inline editing
  static InputDecoration compact(
    BuildContext context, {
    String? hintText,
    String? prefixText,
    String? suffixText,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final focusColor = isDark ? AppTheme.primaryLight : AppTheme.primaryColor;

    return InputDecoration(
      hintText: hintText,
      prefixText: prefixText,
      suffixText: suffixText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      isDense: true,
      constraints: const BoxConstraints(minHeight: AppControlSize.compact),
      filled: true,
      fillColor: surfaceColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: focusColor, width: 1.5),
      ),
    );
  }
}

/// Centralized Text Field adhering to the App Design System
class AppTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? initialValue;
  final FocusNode? focusNode;
  final String? labelText;
  final String? hintText;
  final String? helperText;
  final String? errorText;
  final String? prefixText;
  final String? suffixText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final bool readOnly;
  final bool enabled;
  final bool autofocus;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final bool isDense;
  final InputDecoration? customDecoration;

  const AppTextField({
    super.key,
    this.controller,
    this.initialValue,
    this.focusNode,
    this.labelText,
    this.hintText,
    this.helperText,
    this.errorText,
    this.prefixText,
    this.suffixText,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.readOnly = false,
    this.enabled = true,
    this.autofocus = false,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.inputFormatters,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.isDense = true,
    this.customDecoration,
  });

  @override
  Widget build(BuildContext context) {
    final decoration =
        customDecoration ??
        AppInputDecoration.standard(
          context,
          labelText: labelText,
          hintText: hintText,
          helperText: helperText,
          errorText: errorText,
          prefixText: prefixText,
          suffixText: suffixText,
          prefixIcon: prefixIcon,
          suffixIcon: suffixIcon,
          isDense: isDense,
          enabled: enabled,
        );

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.text : SystemMouseCursors.forbidden,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        decoration: decoration,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        obscureText: obscureText,
        autofocus: autofocus,
        readOnly: readOnly,
        enabled: enabled,
        maxLines: maxLines,
        minLines: minLines,
        maxLength: maxLength,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        inputFormatters: inputFormatters,
        style: TextStyle(
          fontFeatures: AppTypography.fontFeatures,
          color:
              enabled
                  ? null
                  : (Theme.of(context).brightness == Brightness.dark
                      ? AppTheme.darkTextSecondary
                      : AppTheme.lightTextSecondary),
        ),
      ),
    );
  }
}

/// Centralized Form Field with validation adhering to the App Design System
class AppTextFormField extends StatelessWidget {
  final TextEditingController? controller;
  final String? initialValue;
  final FocusNode? focusNode;
  final String? labelText;
  final String? hintText;
  final String? helperText;
  final String? prefixText;
  final String? suffixText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final bool readOnly;
  final bool enabled;
  final bool autofocus;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;
  final FormFieldSetter<String>? onSaved;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final bool isDense;
  final AutovalidateMode? autovalidateMode;
  final InputDecoration? customDecoration;

  const AppTextFormField({
    super.key,
    this.controller,
    this.initialValue,
    this.focusNode,
    this.labelText,
    this.hintText,
    this.helperText,
    this.prefixText,
    this.suffixText,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.readOnly = false,
    this.enabled = true,
    this.autofocus = false,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.validator,
    this.onSaved,
    this.inputFormatters,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.isDense = true,
    this.autovalidateMode,
    this.customDecoration,
  });

  @override
  Widget build(BuildContext context) {
    final decoration =
        customDecoration ??
        AppInputDecoration.standard(
          context,
          labelText: labelText,
          hintText: hintText,
          helperText: helperText,
          prefixText: prefixText,
          suffixText: suffixText,
          prefixIcon: prefixIcon,
          suffixIcon: suffixIcon,
          isDense: isDense,
          enabled: enabled,
        );

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.text : SystemMouseCursors.forbidden,
      child: TextFormField(
        controller: controller,
        initialValue: initialValue,
        focusNode: focusNode,
        decoration: decoration,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        obscureText: obscureText,
        autofocus: autofocus,
        readOnly: readOnly,
        enabled: enabled,
        maxLines: maxLines,
        minLines: minLines,
        maxLength: maxLength,
        onChanged: onChanged,
        validator: validator,
        onSaved: onSaved,
        autovalidateMode: autovalidateMode,
        inputFormatters: inputFormatters,
        style: TextStyle(
          fontFeatures: AppTypography.fontFeatures,
          color:
              enabled
                  ? null
                  : (Theme.of(context).brightness == Brightness.dark
                      ? AppTheme.darkTextSecondary
                      : AppTheme.lightTextSecondary),
        ),
      ),
    );
  }
}

/// Centralized Search Field for toolbars, list headers, and search dialogs
class AppSearchField extends StatefulWidget {
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;
  final String hintText;
  final bool autofocus;
  final double? width;
  final Widget? prefixIcon;
  final FocusNode? focusNode;

  const AppSearchField({
    super.key,
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.hintText = 'Search...',
    this.autofocus = false,
    this.width,
    this.prefixIcon,
    this.focusNode,
  });

  @override
  State<AppSearchField> createState() => _AppSearchFieldState();
}

class _AppSearchFieldState extends State<AppSearchField> {
  late final TextEditingController _internalController;
  bool _showClear = false;

  TextEditingController get _effectiveController =>
      widget.controller ?? _internalController;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      _internalController = TextEditingController();
    }
    _showClear = _effectiveController.text.isNotEmpty;
    _effectiveController.addListener(_handleTextChange);
  }

  @override
  void didUpdateWidget(AppSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_handleTextChange);
      widget.controller?.addListener(_handleTextChange);
      _showClear = _effectiveController.text.isNotEmpty;
    }
  }

  @override
  void dispose() {
    _effectiveController.removeListener(_handleTextChange);
    if (widget.controller == null) {
      _internalController.dispose();
    }
    super.dispose();
  }

  void _handleTextChange() {
    final hasText = _effectiveController.text.isNotEmpty;
    if (hasText != _showClear) {
      setState(() {
        _showClear = hasText;
      });
    }
  }

  void _clear() {
    _effectiveController.clear();
    widget.onChanged?.call('');
    widget.onClear?.call();
    setState(() {
      _showClear = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final inputWidget = TextField(
      controller: _effectiveController,
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      decoration: AppInputDecoration.search(
        context,
        hintText: widget.hintText,
        prefixIcon: widget.prefixIcon,
        showClear: _showClear,
        onClear: _clear,
      ),
      style: const TextStyle(
        fontSize: 14,
        fontFeatures: AppTypography.fontFeatures,
      ),
    );

    if (widget.width != null) {
      return SizedBox(width: widget.width, child: inputWidget);
    }
    return inputWidget;
  }
}

/// Centralized Dropdown Form Field adhering to the App Design System
class AppDropdownField<T> extends StatelessWidget {
  final T? value;
  final List<DropdownMenuItem<T>>? items;
  final ValueChanged<T?>? onChanged;
  final String? labelText;
  final String? hintText;
  final String? helperText;
  final String? errorText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final Widget? icon;
  final FormFieldValidator<T>? validator;
  final FormFieldSetter<T>? onSaved;
  final bool enabled;
  final bool isDense;
  final bool isExpanded;
  final InputDecoration? customDecoration;
  final FocusNode? focusNode;
  final AutovalidateMode? autovalidateMode;

  const AppDropdownField({
    super.key,
    required this.items,
    this.value,
    this.onChanged,
    this.labelText,
    this.hintText,
    this.helperText,
    this.errorText,
    this.prefixIcon,
    this.suffixIcon,
    this.icon,
    this.validator,
    this.onSaved,
    this.enabled = true,
    this.isDense = true,
    this.isExpanded = true,
    this.customDecoration,
    this.focusNode,
    this.autovalidateMode,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;

    final decoration =
        customDecoration ??
        AppInputDecoration.dropdown(
          context,
          labelText: labelText,
          hintText: hintText,
          helperText: helperText,
          errorText: errorText,
          prefixIcon: prefixIcon,
          suffixIcon: suffixIcon,
          isDense: isDense,
          enabled: enabled,
        );

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.forbidden,
      child: DropdownButtonFormField<T>(
        initialValue: value,
        items: items,
        onChanged: enabled ? onChanged : null,
        validator: validator,
        onSaved: onSaved,
        autovalidateMode: autovalidateMode,
        focusNode: focusNode,
        isDense: isDense,
        isExpanded: isExpanded,
        dropdownColor: surfaceColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        icon: icon ?? const Icon(Icons.arrow_drop_down, size: 22),
        decoration: decoration,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontFeatures: AppTypography.fontFeatures,
          color:
              enabled
                  ? null
                  : (isDark
                      ? AppTheme.darkTextSecondary
                      : AppTheme.lightTextSecondary),
        ),
      ),
    );
  }
}

/// Centralized Date Picker Form Field adhering to the App Design System
class AppDatePickerField extends StatelessWidget {
  final String? labelText;
  final String? hintText;
  final String? helperText;
  final String? errorText;
  final DateTime? selectedDate;
  final ValueChanged<DateTime> onDateSelected;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final String Function(DateTime)? dateFormatter;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool enabled;
  final bool isDense;
  final InputDecoration? customDecoration;

  const AppDatePickerField({
    super.key,
    this.labelText,
    this.hintText,
    this.helperText,
    this.errorText,
    required this.selectedDate,
    required this.onDateSelected,
    this.firstDate,
    this.lastDate,
    this.dateFormatter,
    this.prefixIcon,
    this.suffixIcon,
    this.enabled = true,
    this.isDense = true,
    this.customDecoration,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final String displayText;
    if (selectedDate != null) {
      if (dateFormatter != null) {
        displayText = dateFormatter!(selectedDate!);
      } else {
        displayText =
            '${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}';
      }
    } else {
      displayText = '';
    }

    final decoration =
        customDecoration ??
        AppInputDecoration.standard(
          context,
          labelText: labelText,
          hintText: hintText ?? 'Select date',
          helperText: helperText,
          errorText: errorText,
          prefixIcon:
              prefixIcon ?? const Icon(Icons.calendar_today_outlined, size: 20),
          suffixIcon: suffixIcon,
          isDense: isDense,
          enabled: enabled,
        );

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.forbidden,
      child: InkWell(
        onTap:
            enabled
                ? () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate ?? DateTime.now(),
                    firstDate: firstDate ?? DateTime(1900),
                    lastDate: lastDate ?? DateTime(2100),
                  );
                  if (picked != null) {
                    onDateSelected(picked);
                  }
                }
                : null,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: IgnorePointer(
          child: InputDecorator(
            decoration: decoration,
            isEmpty: selectedDate == null,
            child: Text(
              displayText,
              style: TextStyle(
                fontFeatures: AppTypography.fontFeatures,
                color:
                    enabled
                        ? null
                        : (isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.lightTextSecondary),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Standardized wrapper providing consistent label, required asterisk (*),
/// spacing, and helper/error text for form inputs.
class AppFormFieldWrapper extends StatelessWidget {
  final String? label;
  final bool isRequired;
  final Widget child;
  final String? helperText;
  final String? errorText;
  final EdgeInsetsGeometry margin;

  const AppFormFieldWrapper({
    super.key,
    this.label,
    this.isRequired = false,
    required this.child,
    this.helperText,
    this.errorText,
    this.margin = const EdgeInsets.only(bottom: 16.0),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: margin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (label != null) ...[
            Row(
              children: [
                Text(
                  label!,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color:
                        isDark
                            ? AppTheme.darkTextPrimary
                            : AppTheme.lightTextPrimary,
                    fontFeatures: AppTypography.fontFeatures,
                  ),
                ),
                if (isRequired) ...[
                  const SizedBox(width: 4),
                  const Text(
                    '*',
                    style: TextStyle(
                      color: AppTheme.errorColor,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
          ],
          child,
          if (errorText != null && errorText!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              errorText!,
              style: const TextStyle(
                color: AppTheme.errorColor,
                fontSize: 12,
                fontFeatures: AppTypography.fontFeatures,
              ),
            ),
          ] else if (helperText != null && helperText!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              helperText!,
              style: TextStyle(
                color:
                    isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.lightTextSecondary,
                fontSize: 12,
                fontFeatures: AppTypography.fontFeatures,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
