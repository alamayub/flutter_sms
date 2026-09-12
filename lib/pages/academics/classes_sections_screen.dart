import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../config/responsive.dart';
import '../../config/theme.dart';
import '../../config/translations.dart';
import '../../data/app_database.dart';
import '../../providers/class_section_provider.dart';
import '../../providers/locale_provider.dart';
import '../../utils/ui_helpers.dart';
import '../../widgets/app_input.dart';
import '../../widgets/forms/add_section_dialog.dart';
import '../../widgets/forms/class_section_form.dart';
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
      builder: (_) => AddSectionDialog(classItem: item, langCode: langCode),
    );
  }

  void _openAddEditClassDialog(
    BuildContext context, {
    ClassWithSections? item,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ClassSectionForm(item: item),
    );
  }
}
