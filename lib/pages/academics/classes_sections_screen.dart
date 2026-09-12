import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../config/extensions.dart';
import '../../config/responsive.dart';
import '../../config/theme.dart';
import '../../config/translations.dart';
import '../../data/app_database.dart';
import '../../providers/class_section_provider.dart';
import '../../providers/locale_provider.dart';
import '../../utils/ui_helpers.dart';
import '../../utils/validators.dart';
import '../../widgets/app_input.dart';
import '../../widgets/ui/app_button.dart';
import '../../widgets/ui/app_empty_state.dart';
import '../../widgets/ui/app_error_view.dart';
import '../../widgets/ui/app_skeleton.dart';

class ClassesSectionsScreen extends ConsumerStatefulWidget {
  const ClassesSectionsScreen({super.key});

  @override
  ConsumerState<ClassesSectionsScreen> createState() =>
      _ClassesSectionsScreenState();
}

class _ClassesSectionsScreenState extends ConsumerState<ClassesSectionsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final classesAsync = ref.watch(classesWithSectionsStreamProvider);
    final currentLang = ref.watch(localeProvider);
    final langCode = currentLang.locale.languageCode;

    return Scaffold(
      body: classesAsync.when(
        data: (classes) {
          final totalSections = classes.fold<int>(
            0,
            (sum, item) => sum + item.sections.length,
          );

          final filtered =
              classes.where((c) {
                if (_searchQuery.isEmpty) return true;
                final query = _searchQuery.toLowerCase();
                final nameMatch = c.name.toLowerCase().contains(query);
                final displayMatch = c.displayName.toLowerCase().contains(
                  query,
                );
                final sectionMatch = c.sections.any(
                  (s) => s.name.toLowerCase().contains(query),
                );
                return nameMatch || displayMatch || sectionMatch;
              }).toList();

          return ResponsiveScaffoldWrapper(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: context.responsive(
                  mobile: 16,
                  tablet: 24,
                  desktop: 32,
                ),
                vertical: 20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  _buildHeader(
                    context,
                    classes.length,
                    totalSections,
                    langCode,
                  ),
                  const SizedBox(height: 16),

                  // Search Bar
                  _buildSearchBar(context, langCode),
                  const SizedBox(height: 16),

                  // Content
                  if (filtered.isEmpty)
                    _buildEmptyState(context, classes.isEmpty, langCode)
                  else
                    _buildClassesList(context, filtered, langCode),
                ],
              ),
            ),
          );
        },
        loading: () => AppSkeleton.list(count: 6),
        error:
            (err, stack) => Center(
              child: AppErrorView(
                error: err,
                stackTrace: stack,
                onRetry: () => ref.refresh(classesWithSectionsStreamProvider),
              ),
            ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    int totalClasses,
    int totalSections,
    String langCode,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppTranslations.text('classes_sections', langCode),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              langCode == 'ne'
                  ? 'कुल कक्षाहरू: $totalClasses  |  कुल सेक्सनहरू: $totalSections'
                  : 'Total Classes: $totalClasses  |  Total Sections: $totalSections',
              style: TextStyle(
                color: Theme.of(context).textTheme.bodySmall?.color,
                fontSize: 13,
              ),
            ),
          ],
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.add, size: 18),
          label: Text(AppTranslations.text('add_class', langCode)),
          onPressed: () => _openAddEditClassDialog(context),
        ),
      ],
    );
  }

  Widget _buildSearchBar(BuildContext context, String langCode) {
    return AppSearchField(
      controller: _searchController,
      hintText: AppTranslations.text('search', langCode),
      onChanged: (val) {
        setState(() {
          _searchQuery = val.trim();
        });
      },
      onClear: () {
        setState(() {
          _searchQuery = '';
        });
      },
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    bool isListEmpty,
    String langCode,
  ) {
    if (isListEmpty) {
      return AppEmptyState.noData(
        title: AppTranslations.text('no_classes', langCode),
        subtitle:
            langCode == 'ne'
                ? 'कुनै कक्षाहरू थपिएका छैनन्। नयाँ कक्षा थप्न तल क्लिक गर्नुहोस्।'
                : 'No classes have been added yet. Click below to add your first class.',
        action: AppButton.primary(
          leadingIcon: const Icon(Icons.add, size: 16),
          text: AppTranslations.text('add_class', langCode),
          onPressed: () => _openAddEditClassDialog(context),
        ),
      );
    }
    return AppEmptyState.search(
      query: _searchQuery,
      title: langCode == 'ne' ? 'खोजी नतिजा भेटिएन' : 'No matching classes',
      onClear: () {
        _searchController.clear();
        setState(() => _searchQuery = '');
      },
    );
  }

  Widget _buildClassesList(
    BuildContext context,
    List<ClassWithSections> list,
    String langCode,
  ) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: list.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = list[index];
        return _buildClassCard(context, item, langCode);
      },
    );
  }

  String _getClassBadgeText(ClassWithSections item) {
    final name = item.name.trim();
    final lower = name.toLowerCase();
    if (lower.contains('nurs')) return 'NUR';
    if (lower.contains('lkg')) return 'LKG';
    if (lower.contains('ukg')) return 'UKG';
    final match = RegExp(r'\d+').firstMatch(name);
    if (match != null) {
      return match.group(0)!;
    }
    if (item.orderIndex > 0) return '${item.orderIndex}';
    return name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '#';
  }

  Widget _buildClassCard(
    BuildContext context,
    ClassWithSections item,
    String langCode,
  ) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row with Class Icon, Names, and Actions
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Order / Class Badge
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: theme.colorScheme.primary.withAlpha(50),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _getClassBadgeText(item),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: _getClassBadgeText(item).length > 2 ? 12 : 15,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Class Name & Display Name
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            item.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (item.displayName.isNotEmpty &&
                              item.displayName != item.name) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                item.displayName,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: theme.textTheme.bodySmall?.color,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        langCode == 'ne'
                            ? 'सेक्सन संख्या: ${item.sections.length}'
                            : 'Sections: ${item.sections.length}',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.textTheme.bodySmall?.color,
                        ),
                      ),
                    ],
                  ),
                ),

                // Card actions: Edit and Delete class
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      tooltip: AppTranslations.text('edit_class', langCode),
                      onPressed:
                          () => _openAddEditClassDialog(context, item: item),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: AppTheme.errorColor,
                        size: 18,
                      ),
                      tooltip: AppTranslations.text('delete_class', langCode),
                      onPressed: () => _confirmDeleteClass(item, langCode),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Sections Row / Chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ...item.sections.map((sec) {
                  return Chip(
                    label: Text(
                      '${AppTranslations.text('section', langCode)} ${sec.name}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    deleteIcon: const Icon(Icons.close, size: 14),
                    onDeleted:
                        () => _confirmDeleteSection(sec, item.name, langCode),
                    backgroundColor: theme.colorScheme.surface,
                    side: BorderSide(
                      color: theme.colorScheme.primary.withAlpha(60),
                    ),
                  );
                }),
                // Quick Add Section Chip
                ActionChip(
                  avatar: const Icon(Icons.add, size: 16),
                  label: Text(
                    AppTranslations.text('add_section', langCode),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  onPressed: () => _openQuickAddSectionDialog(item, langCode),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteClass(
    ClassWithSections item,
    String langCode,
  ) async {
    final isConfirmed = await UiHelpers.showConfirmationDialog(
      context,
      title: AppTranslations.text('delete_class', langCode),
      message:
          langCode == 'ne'
              ? 'के तपाईं "${item.name}" र यसका सबै ${item.sections.length} सेक्सनहरू मेटाउन चाहनुहुन्छ?'
              : 'Are you sure you want to delete "${item.name}" and all of its ${item.sections.length} sections? This action cannot be undone.',
      confirmText: AppTranslations.text('delete', langCode),
      isDestructive: true,
    );

    if (isConfirmed && mounted) {
      await ref
          .read(classSectionControllerProvider.notifier)
          .deleteClass(item.id);
      if (mounted) {
        UiHelpers.showSnackBar(
          context,
          '${item.name} deleted successfully',
          isSuccess: true,
        );
      }
    }
  }

  Future<void> _confirmDeleteSection(
    Section section,
    String className,
    String langCode,
  ) async {
    final isConfirmed = await UiHelpers.showConfirmationDialog(
      context,
      title: AppTranslations.text('delete_section', langCode),
      message:
          langCode == 'ne'
              ? 'के तपाईं "$className" बाट सेक्सन "${section.name}" मेटाउन चाहनुहुन्छ?'
              : 'Are you sure you want to delete section "${section.name}" from "$className"?',
      confirmText: AppTranslations.text('delete', langCode),
      isDestructive: true,
    );

    if (isConfirmed && mounted) {
      await ref
          .read(classSectionControllerProvider.notifier)
          .deleteSection(section.id);
      if (mounted) {
        UiHelpers.showSnackBar(
          context,
          'Section "${section.name}" deleted',
          isSuccess: true,
        );
      }
    }
  }

  void _openQuickAddSectionDialog(ClassWithSections item, String langCode) {
    showDialog(
      context: context,
      builder:
          (_) => _QuickAddSectionDialog(classItem: item, langCode: langCode),
    );
  }

  void _openAddEditClassDialog(
    BuildContext context, {
    ClassWithSections? item,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ClassFormDialog(item: item),
    );
  }
}

/// Modal dialog to quickly add a single section to an existing class
class _QuickAddSectionDialog extends ConsumerStatefulWidget {
  final ClassWithSections classItem;
  final String langCode;

  const _QuickAddSectionDialog({
    required this.classItem,
    required this.langCode,
  });

  @override
  ConsumerState<_QuickAddSectionDialog> createState() =>
      _QuickAddSectionDialogState();
}

class _QuickAddSectionDialogState
    extends ConsumerState<_QuickAddSectionDialog> {
  final _controller = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final langCode = widget.langCode;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        '${AppTranslations.text('add_section', langCode)}: ${widget.classItem.name}',
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
      ),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: AppTranslations.text('section_name', langCode),
                hintText: 'e.g. A, B, C, Rose, Lotus',
                prefixIcon: const Icon(Icons.meeting_room_outlined),
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 12),
            Text(
              langCode == 'ne' ? 'सिफारिस सेक्सनहरू:' : 'Suggested sections:',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children:
                  ['A', 'B', 'C', 'D', 'E']
                      .where((s) {
                        return !widget.classItem.sections.any(
                          (sec) => sec.name.toUpperCase() == s,
                        );
                      })
                      .map((s) {
                        return ActionChip(
                          label: Text(s),
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                          onPressed: () {
                            _controller.text = s;
                            _submit();
                          },
                        );
                      })
                      .toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => context.pop(),
          child: Text(AppTranslations.text('cancel', langCode)),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          child:
              _isSubmitting
                  ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                  : Text(AppTranslations.text('add', langCode)),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    if (widget.classItem.sections.any(
      (s) => s.name.toLowerCase() == text.toLowerCase(),
    )) {
      UiHelpers.showSnackBar(
        context,
        'Section "$text" already exists in ${widget.classItem.name}',
        isError: true,
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await ref
          .read(classSectionControllerProvider.notifier)
          .addSection(classId: widget.classItem.id, name: text);
      if (mounted) {
        context.pop();
        UiHelpers.showSnackBar(
          context,
          'Section "$text" added to ${widget.classItem.name}',
          isSuccess: true,
        );
      }
    } catch (e) {
      if (mounted) {
        UiHelpers.showSnackBar(
          context,
          'Failed to add section: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }
}

/// Full modal dialog to add or edit a class along with dynamic sections management
class _ClassFormDialog extends ConsumerStatefulWidget {
  final ClassWithSections? item;

  const _ClassFormDialog({this.item});

  @override
  ConsumerState<_ClassFormDialog> createState() => _ClassFormDialogState();
}

class _ClassFormDialogState extends ConsumerState<_ClassFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _displayController;
  late TextEditingController _orderController;
  final TextEditingController _newSectionController = TextEditingController();

  late List<String> _sections;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final isEditing = widget.item != null;

    if (isEditing) {
      _nameController = TextEditingController(text: widget.item!.name);
      _displayController = TextEditingController(
        text: widget.item!.displayName,
      );
      _orderController = TextEditingController(
        text: widget.item!.orderIndex.toString(),
      );
      _sections = widget.item!.sections.map((s) => s.name).toList();
    } else {
      _nameController = TextEditingController();
      _displayController = TextEditingController();
      _orderController = TextEditingController(text: '1');
      _sections = ['A', 'B', 'C'];
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _displayController.dispose();
    _orderController.dispose();
    _newSectionController.dispose();
    super.dispose();
  }

  void _addSection() {
    final text = _newSectionController.text.trim();
    if (text.isEmpty) return;

    if (_sections.any((s) => s.toLowerCase() == text.toLowerCase())) {
      UiHelpers.showSnackBar(
        context,
        'Section "$text" is already added',
        isError: true,
      );
      return;
    }

    setState(() {
      _sections.add(text);
      _newSectionController.clear();
    });
  }

  void _removeSection(String sectionName) {
    setState(() {
      _sections.remove(sectionName);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.item != null;
    final currentLang = ref.watch(localeProvider);
    final langCode = currentLang.locale.languageCode;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        isEditing
            ? AppTranslations.text('edit_class', langCode)
            : AppTranslations.text('add_class', langCode),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Class Name
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText:
                        '${AppTranslations.text('class_name', langCode)} *',
                    hintText: 'e.g. Class 1, Class 2, Kindergarten',
                    prefixIcon: const Icon(Icons.school_outlined),
                  ),
                  validator:
                      (v) =>
                          Validators.requiredField(v, 'Class name is required'),
                  onChanged: (val) {
                    // Auto fill display name if empty or previously matching
                    if (!isEditing && _displayController.text.isEmpty) {
                      _displayController.text = val;
                    }
                  },
                ),
                const SizedBox(height: 14),

                // Display Name
                TextFormField(
                  controller: _displayController,
                  decoration: InputDecoration(
                    labelText: AppTranslations.text('display_name', langCode),
                    hintText: 'e.g. Grade 1, Standard 1',
                    prefixIcon: const Icon(Icons.badge_outlined),
                  ),
                ),
                const SizedBox(height: 14),

                // Order Index
                TextFormField(
                  controller: _orderController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: AppTranslations.text('order_index', langCode),
                    hintText: 'e.g. 1, 2, 3...',
                    prefixIcon: const Icon(Icons.format_list_numbered),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    if (int.tryParse(v.trim()) == null) {
                      return 'Enter a valid number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Dynamic Sections Manager
                Text(
                  AppTranslations.text('sections_count', langCode),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),

                // Add Section Input Row
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _newSectionController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          hintText: AppTranslations.text(
                            'section_name',
                            langCode,
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                        onSubmitted: (_) => _addSection(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add, size: 16),
                      label: Text(AppTranslations.text('add', langCode)),
                      onPressed: _addSection,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Current Sections Chips
                if (_sections.isEmpty)
                  Text(
                    AppTranslations.text('no_sections', langCode),
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                      fontStyle: FontStyle.italic,
                    ),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children:
                        _sections.map((sec) {
                          return Chip(
                            label: Text(
                              '${AppTranslations.text('section', langCode)} $sec',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            deleteIcon: const Icon(Icons.close, size: 14),
                            onDeleted: () => _removeSection(sec),
                          );
                        }).toList(),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => context.pop(),
          child: Text(AppTranslations.text('cancel', langCode)),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _save,
          child:
              _isSubmitting
                  ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                  : Text(AppTranslations.text('save', langCode)),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final controller = ref.read(classSectionControllerProvider.notifier);
      final isEditing = widget.item != null;
      final name = _nameController.text.trim();
      final displayName =
          _displayController.text.trim().isEmpty
              ? name
              : _displayController.text.trim();
      final orderIndex = int.tryParse(_orderController.text.trim()) ?? 0;

      if (isEditing) {
        await controller.updateClass(
          id: widget.item!.id,
          name: name,
          displayName: displayName,
          orderIndex: orderIndex,
          sections: _sections,
        );
      } else {
        await controller.createClass(
          name: name,
          displayName: displayName,
          orderIndex: orderIndex,
          sections: _sections,
        );
      }

      if (mounted) {
        context.pop();
        UiHelpers.showSnackBar(
          context,
          isEditing
              ? 'Class updated successfully'
              : 'Class created successfully',
          isSuccess: true,
        );
      }
    } catch (e) {
      if (mounted) {
        UiHelpers.showSnackBar(context, 'Failed to save: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }
}
