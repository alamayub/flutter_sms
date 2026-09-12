import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../config/enums.dart';
import '../../config/extensions.dart';
import '../../config/responsive.dart';
import '../../config/theme.dart';
import '../../config/translations.dart';
import '../../data/app_database.dart';
import '../../providers/locale_provider.dart';
import '../../providers/subject_provider.dart';
import '../../utils/ui_helpers.dart';
import '../../utils/validators.dart';
import '../../widgets/app_input.dart';

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
      builder: (_) => _SubjectFormDialog(subject: subject),
    );
  }
}

/// Modal dialog to create or edit a subject
class _SubjectFormDialog extends ConsumerStatefulWidget {
  final Subject? subject;

  const _SubjectFormDialog({this.subject});

  @override
  ConsumerState<_SubjectFormDialog> createState() => _SubjectFormDialogState();
}

class _SubjectFormDialogState extends ConsumerState<_SubjectFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _codeController;
  late TextEditingController _nameController;
  late TextEditingController _fullMarksController;
  late TextEditingController _passMarksController;
  late TextEditingController _theoryMarksController;
  late TextEditingController _practicalMarksController;
  late TextEditingController _descController;

  late SubjectType _subjectType;
  late bool _isOptional;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final isEditing = widget.subject != null;

    if (isEditing) {
      final s = widget.subject!;
      _codeController = TextEditingController(text: s.code);
      _nameController = TextEditingController(text: s.name);
      _fullMarksController = TextEditingController(
        text: s.fullMarks.toString(),
      );
      _passMarksController = TextEditingController(
        text: s.passMarks.toString(),
      );
      _theoryMarksController = TextEditingController(
        text: s.theoryMarks?.toString() ?? '',
      );
      _practicalMarksController = TextEditingController(
        text: s.practicalMarks?.toString() ?? '',
      );
      _descController = TextEditingController(text: s.description ?? '');
      _subjectType = s.subjectType;
      _isOptional = s.isOptional;
    } else {
      _codeController = TextEditingController();
      _nameController = TextEditingController();
      _fullMarksController = TextEditingController(text: '100');
      _passMarksController = TextEditingController(text: '40');
      _theoryMarksController = TextEditingController(text: '75');
      _practicalMarksController = TextEditingController(text: '25');
      _descController = TextEditingController();
      _subjectType = SubjectType.both;
      _isOptional = false;
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _fullMarksController.dispose();
    _passMarksController.dispose();
    _theoryMarksController.dispose();
    _practicalMarksController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.subject != null;
    final currentLang = ref.watch(localeProvider);
    final langCode = currentLang.locale.languageCode;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        isEditing
            ? AppTranslations.text('edit_subject', langCode)
            : AppTranslations.text('add_subject', langCode),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Subject Name & Code
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText:
                              '${AppTranslations.text('subject_name', langCode)} *',
                          hintText: 'e.g. English, Optional Mathematics',
                          prefixIcon: const Icon(Icons.menu_book_outlined),
                        ),
                        validator:
                            (v) => Validators.requiredField(
                              v,
                              'Subject name is required',
                            ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 1,
                      child: TextFormField(
                        controller: _codeController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          labelText:
                              '${AppTranslations.text('subject_code', langCode)} *',
                          hintText: 'e.g. MATH-10',
                        ),
                        validator:
                            (v) => Validators.requiredField(v, 'Code required'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Subject Delivery Type
                Text(
                  AppTranslations.text('subject_type', langCode),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                SegmentedButton<SubjectType>(
                  segments: [
                    ButtonSegment(
                      value: SubjectType.theory,
                      label: Text(AppTranslations.text('theory', langCode)),
                      icon: const Icon(Icons.menu_book, size: 16),
                    ),
                    ButtonSegment(
                      value: SubjectType.practical,
                      label: Text(AppTranslations.text('practical', langCode)),
                      icon: const Icon(Icons.science_outlined, size: 16),
                    ),
                    ButtonSegment(
                      value: SubjectType.both,
                      label: Text(AppTranslations.text('both', langCode)),
                      icon: const Icon(Icons.assignment_outlined, size: 16),
                    ),
                  ],
                  selected: {_subjectType},
                  onSelectionChanged: (set) {
                    setState(() {
                      _subjectType = set.first;
                      if (_subjectType == SubjectType.theory) {
                        _theoryMarksController.text = _fullMarksController.text;
                        _practicalMarksController.text = '0';
                      } else if (_subjectType == SubjectType.practical) {
                        _theoryMarksController.text = '0';
                        _practicalMarksController.text =
                            _fullMarksController.text;
                      } else {
                        _theoryMarksController.text = '75';
                        _practicalMarksController.text = '25';
                      }
                    });
                  },
                ),
                const SizedBox(height: 12),

                // Optional Subject Checkbox
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    AppTranslations.text('is_optional', langCode),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    langCode == 'ne'
                        ? 'विद्यार्थीहरूले छनौट गर्न पाउने ऐच्छिक विषय'
                        : 'Students can choose this subject as an elective/optional course',
                    style: const TextStyle(fontSize: 12),
                  ),
                  value: _isOptional,
                  onChanged: (val) {
                    setState(() {
                      _isOptional = val;
                    });
                  },
                ),
                const SizedBox(height: 12),

                // Marks Setup
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _fullMarksController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: AppTranslations.text(
                            'full_marks',
                            langCode,
                          ),
                        ),
                        validator: (v) {
                          final n = int.tryParse(v ?? '');
                          if (n == null || n <= 0) return 'Invalid';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _passMarksController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: AppTranslations.text(
                            'pass_marks',
                            langCode,
                          ),
                        ),
                        validator: (v) {
                          final pass = int.tryParse(v ?? '');
                          final full = int.tryParse(_fullMarksController.text);
                          if (pass == null || pass <= 0) return 'Invalid';
                          if (full != null && pass > full) return '> Full';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _theoryMarksController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: AppTranslations.text(
                            'theory_marks',
                            langCode,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _practicalMarksController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: AppTranslations.text(
                            'practical_marks',
                            langCode,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Description
                TextFormField(
                  controller: _descController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText:
                        langCode == 'ne'
                            ? 'विवरण (ऐच्छिक)'
                            : 'Description (Optional)',
                    hintText: 'e.g. Syllabus, textbook reference...',
                  ),
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

    final fullMarks = int.tryParse(_fullMarksController.text.trim()) ?? 100;
    final passMarks = int.tryParse(_passMarksController.text.trim()) ?? 40;
    final theoryMarks = int.tryParse(_theoryMarksController.text.trim());
    final practicalMarks = int.tryParse(_practicalMarksController.text.trim());

    if (theoryMarks != null && practicalMarks != null) {
      if (theoryMarks + practicalMarks != fullMarks) {
        UiHelpers.showSnackBar(
          context,
          'Theory marks ($theoryMarks) + Practical marks ($practicalMarks) must equal Full marks ($fullMarks)',
          isError: true,
        );
        return;
      }
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final controller = ref.read(subjectControllerProvider.notifier);
      final isEditing = widget.subject != null;

      if (isEditing) {
        await controller.updateSubject(
          id: widget.subject!.id,
          code: _codeController.text.trim(),
          name: _nameController.text.trim(),
          subjectType: _subjectType,
          isOptional: _isOptional,
          fullMarks: fullMarks,
          passMarks: passMarks,
          theoryMarks: theoryMarks,
          practicalMarks: practicalMarks,
          description: _descController.text.trim(),
        );
      } else {
        await controller.createSubject(
          code: _codeController.text.trim(),
          name: _nameController.text.trim(),
          subjectType: _subjectType,
          isOptional: _isOptional,
          fullMarks: fullMarks,
          passMarks: passMarks,
          theoryMarks: theoryMarks,
          practicalMarks: practicalMarks,
          description: _descController.text.trim(),
        );
      }

      if (mounted) {
        context.pop();
        UiHelpers.showSnackBar(
          context,
          isEditing
              ? 'Subject updated successfully'
              : 'Subject created successfully',
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
