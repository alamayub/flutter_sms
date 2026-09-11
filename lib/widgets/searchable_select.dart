import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Item representation for [AppSearchableSelect]
class SearchableSelectItem<T> {
  final T value;
  final String label;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final bool disabled;

  const SearchableSelectItem({
    required this.value,
    required this.label,
    this.subtitle,
    this.leading,
    this.trailing,
    this.disabled = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SearchableSelectItem &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;
}

/// A modern, responsive, searchable select dropdown widget that conforms
/// to the app's design system tokens, interactive cursors, and theme styling.
class AppSearchableSelect<T> extends FormField<T> {
  final List<SearchableSelectItem<T>> items;
  final String? label;
  final String? hint;
  final String searchHint;
  final Widget? prefixIcon;
  final bool isSearchable;
  final bool isClearable;
  final bool isCompact;
  final bool isDense;
  final ValueChanged<T?>? onChanged;
  final InputDecoration? customDecoration;
  final Widget Function(
    BuildContext context,
    SearchableSelectItem<T> item,
    bool isSelected,
  )?
  itemBuilder;

  AppSearchableSelect({
    super.key,
    required this.items,
    T? value,
    this.onChanged,
    this.label,
    this.hint,
    this.searchHint = 'Type to search...',
    this.prefixIcon,
    this.isSearchable = true,
    this.isClearable = false,
    this.isCompact = false,
    this.isDense = true,
    super.enabled = true,
    super.validator,
    super.onSaved,
    super.autovalidateMode,
    this.customDecoration,
    this.itemBuilder,
  }) : super(
         initialValue: value,
         builder: (FormFieldState<T> field) {
           final state = field as _AppSearchableSelectState<T>;
           return state.buildWidget();
         },
       );

  /// Helper constructor to quickly create from a generic list of models
  factory AppSearchableSelect.fromList({
    Key? key,
    required List<T> items,
    required String Function(T) labelBuilder,
    String Function(T)? subtitleBuilder,
    Widget Function(T)? leadingBuilder,
    Widget Function(T)? trailingBuilder,
    bool Function(T)? disabledBuilder,
    T? value,
    ValueChanged<T?>? onChanged,
    String? label,
    String? hint,
    String searchHint = 'Type to search...',
    Widget? prefixIcon,
    bool isSearchable = true,
    bool isClearable = false,
    bool isCompact = false,
    bool isDense = true,
    bool enabled = true,
    String? Function(T?)? validator,
    void Function(T?)? onSaved,
    AutovalidateMode? autovalidateMode,
    InputDecoration? customDecoration,
    Widget Function(
      BuildContext context,
      SearchableSelectItem<T> item,
      bool isSelected,
    )?
    itemBuilder,
  }) {
    final selectItems =
        items.map((item) {
          return SearchableSelectItem<T>(
            value: item,
            label: labelBuilder(item),
            subtitle: subtitleBuilder?.call(item),
            leading: leadingBuilder?.call(item),
            trailing: trailingBuilder?.call(item),
            disabled: disabledBuilder?.call(item) ?? false,
          );
        }).toList();

    return AppSearchableSelect<T>(
      key: key,
      items: selectItems,
      value: value,
      onChanged: onChanged,
      label: label,
      hint: hint,
      searchHint: searchHint,
      prefixIcon: prefixIcon,
      isSearchable: isSearchable,
      isClearable: isClearable,
      isCompact: isCompact,
      isDense: isDense,
      enabled: enabled,
      validator: validator,
      onSaved: onSaved,
      autovalidateMode: autovalidateMode,
      customDecoration: customDecoration,
      itemBuilder: itemBuilder,
    );
  }

  /// Compact filter bar variant
  factory AppSearchableSelect.filter({
    Key? key,
    required List<SearchableSelectItem<T>> items,
    T? value,
    ValueChanged<T?>? onChanged,
    String? hint,
    String searchHint = 'Filter...',
    Widget? prefixIcon,
    bool isClearable = true,
    bool enabled = true,
  }) {
    return AppSearchableSelect<T>(
      key: key,
      items: items,
      value: value,
      onChanged: onChanged,
      hint: hint,
      searchHint: searchHint,
      prefixIcon: prefixIcon,
      isSearchable: true,
      isClearable: isClearable,
      isCompact: true,
      enabled: enabled,
    );
  }

  @override
  FormFieldState<T> createState() => _AppSearchableSelectState<T>();
}

class _AppSearchableSelectState<T> extends FormFieldState<T> {
  @override
  AppSearchableSelect<T> get widget => super.widget as AppSearchableSelect<T>;

  SearchableSelectItem<T>? get _selectedItem {
    try {
      return widget.items.firstWhere((it) => it.value == value);
    } catch (_) {
      return null;
    }
  }

  @override
  void didUpdateWidget(covariant AppSearchableSelect<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue) {
      setValue(widget.initialValue);
    }
  }

  void _handleTap() async {
    if (!widget.enabled) return;

    final selected = await showDialog<SearchableSelectItem<T>?>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext ctx) {
        return _SearchSelectDialog<T>(
          title: widget.label ?? widget.hint ?? 'Select Option',
          searchHint: widget.searchHint,
          items: widget.items,
          selectedValue: value,
          isSearchable: widget.isSearchable,
          itemBuilder: widget.itemBuilder,
        );
      },
    );

    if (selected != null) {
      final newValue = selected.value;
      didChange(newValue);
      widget.onChanged?.call(newValue);
    }
  }

  void _handleClear() {
    didChange(null);
    widget.onChanged?.call(null);
  }

  Widget buildWidget() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final selected = _selectedItem;

    final baseBorderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final textPrimary =
        isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textSecondary =
        isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;

    final hasError = this.hasError;
    final borderColor = hasError ? AppTheme.errorColor : baseBorderColor;

    final padding =
        widget.isCompact
            ? const EdgeInsets.symmetric(horizontal: 10, vertical: 8)
            : EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: widget.isDense ? 12 : 14,
            );

    return MouseRegion(
      cursor:
          widget.enabled
              ? SystemMouseCursors.click
              : SystemMouseCursors.forbidden,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.label != null && !widget.isCompact) ...[
            Text(
              widget.label!,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: widget.enabled ? textPrimary : textSecondary,
                fontFeatures: AppTypography.fontFeatures,
              ),
            ),
            const SizedBox(height: 6),
          ],
          InkWell(
            onTap: widget.enabled ? _handleTap : null,
            borderRadius: BorderRadius.circular(
              widget.isCompact ? AppRadius.md : AppRadius.lg,
            ),
            child: AnimatedContainer(
              duration: AppTransitions.duration,
              curve: AppTransitions.curve,
              padding: padding,
              decoration: BoxDecoration(
                color:
                    widget.enabled
                        ? surfaceColor
                        : (isDark
                            ? const Color(0xFF1E293B).withAlpha(128)
                            : const Color(0xFFF1F5F9)),
                borderRadius: BorderRadius.circular(
                  widget.isCompact ? AppRadius.md : AppRadius.lg,
                ),
                border: Border.all(
                  color: borderColor,
                  width: hasError ? 1.5 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  if (widget.prefixIcon != null) ...[
                    widget.prefixIcon!,
                    const SizedBox(width: 8),
                  ],
                  if (selected?.leading != null) ...[
                    selected!.leading!,
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      selected != null
                          ? selected.label
                          : (widget.hint ?? 'Select an option'),
                      style: TextStyle(
                        fontSize: widget.isCompact ? 13 : 14,
                        fontWeight:
                            selected != null
                                ? FontWeight.w500
                                : FontWeight.w400,
                        color:
                            selected != null
                                ? (widget.enabled ? textPrimary : textSecondary)
                                : textSecondary,
                        fontFeatures: AppTypography.fontFeatures,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (widget.isClearable &&
                      selected != null &&
                      widget.enabled) ...[
                    GestureDetector(
                      onTap: _handleClear,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(
                          Icons.close,
                          size: 16,
                          color: textSecondary,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 4),
                  Icon(
                    Icons.keyboard_arrow_down,
                    size: 18,
                    color:
                        widget.enabled
                            ? textSecondary
                            : textSecondary.withAlpha(128),
                  ),
                ],
              ),
            ),
          ),
          if (hasError) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                errorText!,
                style: const TextStyle(
                  color: AppTheme.errorColor,
                  fontSize: 12,
                  fontFeatures: AppTypography.fontFeatures,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Internal modal dialog with live search filter
class _SearchSelectDialog<T> extends StatefulWidget {
  final String title;
  final String searchHint;
  final List<SearchableSelectItem<T>> items;
  final T? selectedValue;
  final bool isSearchable;
  final Widget Function(
    BuildContext context,
    SearchableSelectItem<T> item,
    bool isSelected,
  )?
  itemBuilder;

  const _SearchSelectDialog({
    required this.title,
    required this.searchHint,
    required this.items,
    this.selectedValue,
    this.isSearchable = true,
    this.itemBuilder,
  });

  @override
  State<_SearchSelectDialog<T>> createState() => _SearchSelectDialogState<T>();
}

class _SearchSelectDialogState<T> extends State<_SearchSelectDialog<T>> {
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  List<SearchableSelectItem<T>> get _filteredItems {
    if (_query.trim().isEmpty) {
      return widget.items;
    }
    final q = _query.trim().toLowerCase();
    return widget.items.where((it) {
      final labelMatch = it.label.toLowerCase().contains(q);
      final subtitleMatch = it.subtitle?.toLowerCase().contains(q) ?? false;
      return labelMatch || subtitleMatch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final filtered = _filteredItems;

    final surfaceColor = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final textPrimary =
        isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textSecondary =
        isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;
    final primaryColor = isDark ? AppTheme.primaryLight : AppTheme.primaryColor;

    final mediaQuery = MediaQuery.of(context);
    final isSmallScreen = mediaQuery.size.width < 600;
    final dialogWidth = isSmallScreen ? mediaQuery.size.width * 0.92 : 460.0;
    final dialogMaxHeight = mediaQuery.size.height * 0.75;

    return Dialog(
      backgroundColor: surfaceColor,
      elevation: 4,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: borderColor),
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: dialogWidth,
          maxHeight: dialogMaxHeight,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                        fontFeatures: AppTypography.fontFeatures,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 20),
                    tooltip: 'Close',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Search Bar
            if (widget.isSearchable) ...[
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: widget.searchHint,
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon:
                        _query.isNotEmpty
                            ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _query = '');
                              },
                            )
                            : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
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
                      borderSide: BorderSide(color: primaryColor, width: 1.5),
                    ),
                  ),
                  onChanged: (val) => setState(() => _query = val),
                ),
              ),
              const Divider(height: 1),
            ],

            // Item List
            Flexible(
              child:
                  filtered.isEmpty
                      ? Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 32,
                          horizontal: 16,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.search_off_rounded,
                              size: 40,
                              color: textSecondary.withAlpha(153),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'No matching options found',
                              style: TextStyle(
                                fontSize: 14,
                                color: textSecondary,
                                fontFeatures: AppTypography.fontFeatures,
                              ),
                            ),
                          ],
                        ),
                      )
                      : ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final item = filtered[index];
                          final isSelected = item.value == widget.selectedValue;

                          if (widget.itemBuilder != null) {
                            return InkWell(
                              onTap:
                                  item.disabled
                                      ? null
                                      : () => Navigator.of(context).pop(item),
                              child: widget.itemBuilder!(
                                context,
                                item,
                                isSelected,
                              ),
                            );
                          }

                          return MouseRegion(
                            cursor:
                                item.disabled
                                    ? SystemMouseCursors.forbidden
                                    : SystemMouseCursors.click,
                            child: InkWell(
                              onTap:
                                  item.disabled
                                      ? null
                                      : () => Navigator.of(context).pop(item),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                color:
                                    isSelected
                                        ? primaryColor.withAlpha(
                                          isDark ? 51 : 20,
                                        )
                                        : Colors.transparent,
                                child: Row(
                                  children: [
                                    if (item.leading != null) ...[
                                      item.leading!,
                                      const SizedBox(width: 12),
                                    ],
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.label,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight:
                                                  isSelected
                                                      ? FontWeight.w600
                                                      : FontWeight.normal,
                                              color:
                                                  item.disabled
                                                      ? textSecondary.withAlpha(
                                                        128,
                                                      )
                                                      : (isSelected
                                                          ? primaryColor
                                                          : textPrimary),
                                              fontFeatures:
                                                  AppTypography.fontFeatures,
                                            ),
                                          ),
                                          if (item.subtitle != null) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              item.subtitle!,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: textSecondary,
                                                fontFeatures:
                                                    AppTypography.fontFeatures,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    if (item.trailing != null) item.trailing!,
                                    if (isSelected) ...[
                                      const SizedBox(width: 8),
                                      Icon(
                                        Icons.check_circle_rounded,
                                        size: 18,
                                        color: primaryColor,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Comprehensive, searchable relationship items for contacts, guardians, and emergency profiles.
class ContactRelationOptions {
  static const List<SearchableSelectItem<String>> items = [
    // Immediate Family
    SearchableSelectItem(
      value: 'Father',
      label: 'Father',
      subtitle: 'Immediate Family • बुबा / बाबु',
      leading: Icon(Icons.person, size: 20),
    ),
    SearchableSelectItem(
      value: 'Mother',
      label: 'Mother',
      subtitle: 'Immediate Family • आमा',
      leading: Icon(Icons.person_2_outlined, size: 20),
    ),
    SearchableSelectItem(
      value: 'Husband',
      label: 'Husband',
      subtitle: 'Spouse • श्रीमान् / पति',
      leading: Icon(Icons.favorite_outline, size: 20),
    ),
    SearchableSelectItem(
      value: 'Wife',
      label: 'Wife',
      subtitle: 'Spouse • श्रीमती / पत्नी',
      leading: Icon(Icons.favorite, size: 20),
    ),
    SearchableSelectItem(
      value: 'Spouse',
      label: 'Spouse',
      subtitle: 'Partner • दम्पती / पति-पत्नी',
      leading: Icon(Icons.favorite_border, size: 20),
    ),
    SearchableSelectItem(
      value: 'Son',
      label: 'Son',
      subtitle: 'Child • छोरा',
      leading: Icon(Icons.child_care, size: 20),
    ),
    SearchableSelectItem(
      value: 'Daughter',
      label: 'Daughter',
      subtitle: 'Child • छोरी',
      leading: Icon(Icons.face_3_outlined, size: 20),
    ),
    SearchableSelectItem(
      value: 'Brother',
      label: 'Brother',
      subtitle: 'Sibling • दाजु / भाइ',
      leading: Icon(Icons.people_outline, size: 20),
    ),
    SearchableSelectItem(
      value: 'Sister',
      label: 'Sister',
      subtitle: 'Sibling • दिदी / बहिनी',
      leading: Icon(Icons.people_outline, size: 20),
    ),

    // Grandparents & Extended Relatives
    SearchableSelectItem(
      value: 'Grandfather',
      label: 'Grandfather',
      subtitle: 'Grandparent • हजुरबुबा',
      leading: Icon(Icons.elderly, size: 20),
    ),
    SearchableSelectItem(
      value: 'Grandmother',
      label: 'Grandmother',
      subtitle: 'Grandparent • हजुरआमा',
      leading: Icon(Icons.elderly_woman, size: 20),
    ),
    SearchableSelectItem(
      value: 'Uncle',
      label: 'Uncle',
      subtitle: 'Relative • काका / मामा / ठूलोबुबा',
      leading: Icon(Icons.person_outline, size: 20),
    ),
    SearchableSelectItem(
      value: 'Aunt',
      label: 'Aunt',
      subtitle: 'Relative • काकी / फुपू / माइजु / ठूलीआमा',
      leading: Icon(Icons.person_2_outlined, size: 20),
    ),
    SearchableSelectItem(
      value: 'Cousin',
      label: 'Cousin',
      subtitle: 'Relative • दाजुभाइ / दिदीबहिनी',
      leading: Icon(Icons.people_alt_outlined, size: 20),
    ),
    SearchableSelectItem(
      value: 'Nephew',
      label: 'Nephew',
      subtitle: 'Relative • भतिजा / भान्जा',
      leading: Icon(Icons.boy_outlined, size: 20),
    ),
    SearchableSelectItem(
      value: 'Niece',
      label: 'Niece',
      subtitle: 'Relative • भतिजी / भान्जी',
      leading: Icon(Icons.girl_outlined, size: 20),
    ),

    // In-Laws
    SearchableSelectItem(
      value: 'Father-in-law',
      label: 'Father-in-law',
      subtitle: 'In-Law • ससुरा',
      leading: Icon(Icons.person_outline, size: 20),
    ),
    SearchableSelectItem(
      value: 'Mother-in-law',
      label: 'Mother-in-law',
      subtitle: 'In-Law • सासू',
      leading: Icon(Icons.person_2_outlined, size: 20),
    ),
    SearchableSelectItem(
      value: 'Brother-in-law',
      label: 'Brother-in-law',
      subtitle: 'In-Law • साला / जेठान / देवर / भिनाजु',
      leading: Icon(Icons.people_outline, size: 20),
    ),
    SearchableSelectItem(
      value: 'Sister-in-law',
      label: 'Sister-in-law',
      subtitle: 'In-Law • साली / नन्द / अमाजू / भाउजू',
      leading: Icon(Icons.people_outline, size: 20),
    ),
    SearchableSelectItem(
      value: 'Son-in-law',
      label: 'Son-in-law',
      subtitle: 'In-Law • ज्वाइँ',
      leading: Icon(Icons.person_outline, size: 20),
    ),
    SearchableSelectItem(
      value: 'Daughter-in-law',
      label: 'Daughter-in-law',
      subtitle: 'In-Law • बुहारी',
      leading: Icon(Icons.person_2_outlined, size: 20),
    ),

    // Guardianship & Blended Family
    SearchableSelectItem(
      value: 'Legal Guardian',
      label: 'Legal Guardian',
      subtitle: 'Guardian • कानुनी अभिभावक',
      leading: Icon(Icons.shield_outlined, size: 20),
    ),
    SearchableSelectItem(
      value: 'Guardian',
      label: 'Guardian',
      subtitle: 'Guardian • अभिभावक',
      leading: Icon(Icons.security_outlined, size: 20),
    ),
    SearchableSelectItem(
      value: 'Stepfather',
      label: 'Stepfather',
      subtitle: 'Parent • सौतेनी बुबा',
      leading: Icon(Icons.person_outline, size: 20),
    ),
    SearchableSelectItem(
      value: 'Stepmother',
      label: 'Stepmother',
      subtitle: 'Parent • सौतेनी आमा',
      leading: Icon(Icons.person_2_outlined, size: 20),
    ),
    SearchableSelectItem(
      value: 'Foster Parent',
      label: 'Foster Parent',
      subtitle: 'Caregiver • पालक आमाबाबु',
      leading: Icon(Icons.volunteer_activism_outlined, size: 20),
    ),

    // Health, Community & Professional
    SearchableSelectItem(
      value: 'Family Doctor',
      label: 'Family Doctor',
      subtitle: 'Medical • डाक्टर / पारिवारिक चिकित्सक',
      leading: Icon(Icons.medical_services_outlined, size: 20),
    ),
    SearchableSelectItem(
      value: 'Emergency Contact',
      label: 'Emergency Contact',
      subtitle: 'Emergency • आपतकालीन सम्पर्क',
      leading: Icon(Icons.emergency_outlined, size: 20),
    ),
    SearchableSelectItem(
      value: 'Neighbor',
      label: 'Neighbor',
      subtitle: 'Community • छिमेकी',
      leading: Icon(Icons.home_outlined, size: 20),
    ),
    SearchableSelectItem(
      value: 'Family Friend',
      label: 'Family Friend',
      subtitle: 'Friend • पारिवारिक मित्र',
      leading: Icon(Icons.handshake_outlined, size: 20),
    ),
    SearchableSelectItem(
      value: 'Friend',
      label: 'Friend',
      subtitle: 'Friend • साथी / मित्र',
      leading: Icon(Icons.sentiment_satisfied_alt, size: 20),
    ),
    SearchableSelectItem(
      value: 'Driver',
      label: 'Driver',
      subtitle: 'Transport • चालक',
      leading: Icon(Icons.directions_car_outlined, size: 20),
    ),
    SearchableSelectItem(
      value: 'Caretaker',
      label: 'Caretaker',
      subtitle: 'Support • हेरचाहकर्ता',
      leading: Icon(Icons.clean_hands_outlined, size: 20),
    ),
    SearchableSelectItem(
      value: 'Teacher',
      label: 'Teacher / Tutor',
      subtitle: 'Education • शिक्षक / शिक्षिका',
      leading: Icon(Icons.school_outlined, size: 20),
    ),
    SearchableSelectItem(
      value: 'Colleague',
      label: 'Colleague / Coworker',
      subtitle: 'Professional • सहकर्मी',
      leading: Icon(Icons.work_outline, size: 20),
    ),
    SearchableSelectItem(
      value: 'Self',
      label: 'Self',
      subtitle: 'Personal • आफै',
      leading: Icon(Icons.person_pin_outlined, size: 20),
    ),
    SearchableSelectItem(
      value: 'Other',
      label: 'Other',
      subtitle: 'Custom relation • अन्य सम्बन्ध',
      leading: Icon(Icons.more_horiz, size: 20),
    ),
  ];

  /// Finds the best matching predefined value case-insensitively, or returns null.
  static String? match(String? relation) {
    if (relation == null || relation.trim().isEmpty) return null;
    final r = relation.trim().toLowerCase();
    try {
      return items.firstWhere((it) => it.value.toLowerCase() == r).value;
    } catch (_) {
      return null;
    }
  }

  /// Returns whether a given relation is in the predefined list.
  static bool contains(String? relation) => match(relation) != null;
}
