import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../config/enums.dart';
import '../../config/responsive.dart';
import '../../config/theme.dart';
import '../../config/translations.dart';
import '../../data/app_database.dart';
import '../../providers/locale_provider.dart';
import '../../providers/subject_provider.dart';
import '../../utils/ui_helpers.dart';
import '../../widgets/app_input.dart';
import '../../widgets/forms/subject_form.dart';

class SubjectsScreen extends HookConsumerWidget {
  const SubjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchController = useTextEditingController();
    final searchQuery = useState<String>('');
    final subjectsAsync = ref.watch(subjectsStreamProvider);
    final selectedType = ref.watch(selectedSubjectTypeFilterProvider);
    final selectedOptional = ref.watch(selectedOptionalFilterProvider);

    final currentLang = ref.watch(localeProvider);
    final langCode = currentLang.locale.languageCode;

    return Scaffold(
      body: subjectsAsync.when(
        data: (subjects) {
          final totalCount = subjects.length;
          final compulsoryCount = subjects.where((s) => !s.isOptional).length;
          final optionalCount = subjects.where((s) => s.isOptional).length;

          final filtered =
              subjects.where((s) {
                if (searchQuery.value.isEmpty) return true;
                final q = searchQuery.value.toLowerCase();
                final nameMatch = s.name.toLowerCase().contains(q);
                final codeMatch = s.code.toLowerCase().contains(q);
                return nameMatch || codeMatch;
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
                    totalCount,
                    compulsoryCount,
                    optionalCount,
                    langCode,
                  ),
                  const SizedBox(height: 16),

                  // Filter Row
                  _buildFilters(
                    context,
                    selectedType,
                    selectedOptional,
                    langCode,
                    ref,
                  ),
                  const SizedBox(height: 16),

                  // Search Bar
                  AppSearchField(
                    controller: searchController,
                    hintText: AppTranslations.text('search', langCode),
                    onChanged: (val) {
                      searchQuery.value = val.trim();
                    },
                    onClear: () {
                      searchQuery.value = '';
                    },
                  ),
                  const SizedBox(height: 16),

                  // Content list
                  if (filtered.isEmpty)
                    _buildEmptyState(context, subjects.isEmpty, langCode)
                  else
                    _buildSubjectsList(context, ref, filtered, langCode),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (err, stack) => Center(child: Text('Error loading subjects: $err')),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    int total,
    int compulsory,
    int optional,
    String langCode,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          spacing: 4,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppTranslations.text('subjects', langCode),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            Text(
              langCode == 'ne'
                  ? 'कुल: $total  |  अनिवार्य: $compulsory  |  ऐच्छिक: $optional'
                  : 'Total: $total  |  Compulsory: $compulsory  |  Optional: $optional',
              style: TextStyle(
                color: Theme.of(context).textTheme.bodySmall?.color,
                fontSize: 13,
              ),
            ),
          ],
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.add, size: 18),
          label: Text(AppTranslations.text('add_subject', langCode)),
          onPressed: () => _openAddEditSubjectDialog(context),
        ),
      ],
    );
  }

  Widget _buildFilters(
    BuildContext context,
    SubjectType? selectedType,
    bool? selectedOptional,
    String langCode,
    WidgetRef ref,
  ) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Subject Type Chips
        FilterChip(
          label: Text(langCode == 'ne' ? 'सबै प्रकार' : 'All Types'),
          selected: selectedType == null,
          onSelected: (_) {
            ref
                .read(selectedSubjectTypeFilterProvider.notifier)
                .setFilter(null);
          },
        ),
        FilterChip(
          label: Text(AppTranslations.text('theory', langCode)),
          selected: selectedType == SubjectType.theory,
          onSelected: (_) {
            ref
                .read(selectedSubjectTypeFilterProvider.notifier)
                .setFilter(
                  selectedType == SubjectType.theory
                      ? null
                      : SubjectType.theory,
                );
          },
        ),
        FilterChip(
          label: Text(AppTranslations.text('practical', langCode)),
          selected: selectedType == SubjectType.practical,
          onSelected: (_) {
            ref
                .read(selectedSubjectTypeFilterProvider.notifier)
                .setFilter(
                  selectedType == SubjectType.practical
                      ? null
                      : SubjectType.practical,
                );
          },
        ),
        FilterChip(
          label: Text(AppTranslations.text('both', langCode)),
          selected: selectedType == SubjectType.both,
          onSelected: (_) {
            ref
                .read(selectedSubjectTypeFilterProvider.notifier)
                .setFilter(
                  selectedType == SubjectType.both ? null : SubjectType.both,
                );
          },
        ),

        // Optional / Compulsory Filter
        FilterChip(
          label: Text(AppTranslations.text('compulsory', langCode)),
          selected: selectedOptional == false,
          onSelected: (_) {
            ref
                .read(selectedOptionalFilterProvider.notifier)
                .setFilter(selectedOptional == false ? null : false);
          },
        ),
        FilterChip(
          label: Text(AppTranslations.text('optional', langCode)),
          selected: selectedOptional == true,
          onSelected: (_) {
            ref
                .read(selectedOptionalFilterProvider.notifier)
                .setFilter(selectedOptional == true ? null : true);
          },
        ),
      ],
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    bool isListEmpty,
    String langCode,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          children: [
            Icon(
              Icons.menu_book_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              isListEmpty
                  ? AppTranslations.text('no_subjects', langCode)
                  : (langCode == 'ne'
                      ? 'खोजी नतिजा भेटिएन'
                      : 'No subjects match your filter'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (isListEmpty)
              ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: Text(AppTranslations.text('add_subject', langCode)),
                onPressed: () => _openAddEditSubjectDialog(context),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubjectsList(
    BuildContext context,
    WidgetRef ref,
    List<Subject> list,
    String langCode,
  ) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: list.length,
        padding: EdgeInsets.all(16),
        separatorBuilder: (context, index) => const Divider(height: 24),
        itemBuilder: (context, index) {
          final item = list[index];
          return _buildSubjectCard(context, ref, item, langCode);
        },
      ),
    );
  }

  Widget _buildSubjectCard(
    BuildContext context,
    WidgetRef ref,
    Subject item,
    String langCode,
  ) {
    final theme = Theme.of(context);

    // Color indicators by type
    Color typeColor;
    IconData typeIcon;
    switch (item.subjectType) {
      case SubjectType.theory:
        typeColor = Colors.blue;
        typeIcon = Icons.menu_book;
        break;
      case SubjectType.practical:
        typeColor = Colors.purple;
        typeIcon = Icons.science_outlined;
        break;
      case SubjectType.both:
        typeColor = Colors.teal;
        typeIcon = Icons.assignment_outlined;
        break;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Code & Icon Box
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: typeColor.withAlpha(20),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: typeColor.withAlpha(60)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(typeIcon, size: 20, color: typeColor),
              const SizedBox(height: 2),
              Text(
                item.subjectType == SubjectType.both
                    ? 'BOTH'
                    : item.subjectType.name.toUpperCase(),
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  color: typeColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),

        // Subject Details
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
                  const SizedBox(width: 8),
                  // Optional vs Compulsory pill
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color:
                          item.isOptional
                              ? AppTheme.warningColor.withAlpha(25)
                              : AppTheme.successColor.withAlpha(25),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color:
                            item.isOptional
                                ? AppTheme.warningColor
                                : AppTheme.successColor,
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      item.isOptional
                          ? AppTranslations.text('optional', langCode)
                          : AppTranslations.text('compulsory', langCode),
                      style: TextStyle(
                        color:
                            item.isOptional
                                ? AppTheme.warningColor
                                : AppTheme.successColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  // Code Tag
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      item.code,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: theme.textTheme.bodySmall?.color,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Marks breakdown
                  Text(
                    'Full: ${item.fullMarks}  |  Pass: ${item.passMarks}${item.theoryMarks != null || item.practicalMarks != null ? '  (Th: ${item.theoryMarks ?? 0}, Pr: ${item.practicalMarks ?? 0})' : ''}',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.textTheme.bodySmall?.color,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Actions
        IconButton(
          icon: const Icon(Icons.edit_outlined, size: 18),
          tooltip: AppTranslations.text('edit_subject', langCode),
          onPressed: () => _openAddEditSubjectDialog(context, subject: item),
        ),
        IconButton(
          icon: const Icon(
            Icons.delete_outline,
            color: AppTheme.errorColor,
            size: 18,
          ),
          tooltip: AppTranslations.text('delete_subject', langCode),
          onPressed: () => _confirmDeleteSubject(context, ref, item, langCode),
        ),
      ],
    );
  }

  Future<void> _confirmDeleteSubject(
    BuildContext context,
    WidgetRef ref,
    Subject item,
    String langCode,
  ) async {
    final isConfirmed = await UiHelpers.showConfirmationDialog(
      context,
      title: AppTranslations.text('delete_subject', langCode),
      message:
          langCode == 'ne'
              ? 'के तपाईं "${item.name}" विषय हटाउन चाहनुहुन्छ?'
              : 'Are you sure you want to delete subject "${item.name}" (${item.code})?',
      confirmText: AppTranslations.text('delete', langCode),
      isDestructive: true,
    );

    if (isConfirmed && context.mounted) {
      await ref.read(subjectControllerProvider.notifier).deleteSubject(item.id);
      if (context.mounted) {
        UiHelpers.showSnackBar(
          context,
          '${item.name} deleted successfully',
          isSuccess: true,
        );
      }
    }
  }

  void _openAddEditSubjectDialog(BuildContext context, {Subject? subject}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => SubjectForm(subject: subject),
    );
  }
}
