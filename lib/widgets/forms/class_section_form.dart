import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../config/extensions.dart';
import '../../config/translations.dart';
import '../../data/app_database.dart';
import '../../providers/class_section_provider.dart';
import '../../providers/locale_provider.dart';
import '../../utils/ui_helpers.dart';
import '../../utils/validators.dart';
import '../ui/app_form_doalog.dart';

/// Full modal dialog to add or edit a class along with dynamic sections management
class ClassSectionForm extends HookConsumerWidget {
  final ClassWithSections? item;

  const ClassSectionForm({super.key, this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formKey = useMemoized(() => GlobalKey<FormState>());

    final isEditing = item != null;

    final nameController = useTextEditingController(
      text: isEditing ? item!.name : '',
    );

    final displayController = useTextEditingController(
      text: isEditing ? item!.displayName : '',
    );

    final orderController = useTextEditingController(
      text: isEditing ? item!.orderIndex.toString() : '1',
    );

    final newSectionController = useTextEditingController();

    final sections = useState<List<String>>(
      isEditing ? item!.sections.map((s) => s.name).toList() : ['A', 'B', 'C'],
    );

    final isSubmitting = useState(false);

    final currentLang = ref.watch(localeProvider);
    final langCode = currentLang.locale.languageCode;

    void addSection() {
      final text = newSectionController.text.trim();

      if (text.isEmpty) return;

      if (sections.value.any((s) => s.toLowerCase() == text.toLowerCase())) {
        UiHelpers.showSnackBar(
          context,
          'Section "$text" is already added',
          isError: true,
        );
        return;
      }

      sections.value = [...sections.value, text];

      newSectionController.clear();
    }

    void removeSection(String sectionName) {
      sections.value = sections.value.where((s) => s != sectionName).toList();
    }

    Future<void> save() async {
      if (!formKey.currentState!.validate()) return;

      isSubmitting.value = true;

      try {
        final controller = ref.read(classSectionControllerProvider.notifier);

        final name = nameController.text.trim();

        final displayName =
            displayController.text.trim().isEmpty
                ? name
                : displayController.text.trim();

        final orderIndex = int.tryParse(orderController.text.trim()) ?? 0;

        if (isEditing) {
          await controller.updateClass(
            id: item!.id,
            name: name,
            displayName: displayName,
            orderIndex: orderIndex,
            sections: sections.value,
          );
        } else {
          await controller.createClass(
            name: name,
            displayName: displayName,
            orderIndex: orderIndex,
            sections: sections.value,
          );
        }

        if (context.mounted) {
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
        if (context.mounted) {
          UiHelpers.showSnackBar(context, 'Failed to save: $e', isError: true);
        }
      } finally {
        if (context.mounted) {
          isSubmitting.value = false;
        }
      }
    }

    return AppFormDialog(
      title:
          isEditing
              ? AppTranslations.text('edit_class', langCode)
              : AppTranslations.text('add_class', langCode),
      cancelText: AppTranslations.text('cancel', langCode),
      actionText: AppTranslations.text('save', langCode),
      isSubmitting: isSubmitting.value,
      onAction: save,
      width: 480,

      content: Form(
        key: formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Class Name
              TextFormField(
                controller: nameController,
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
                  // Auto fill display name if empty
                  if (!isEditing && displayController.text.isEmpty) {
                    displayController.text = val;
                  }
                },
              ),

              const SizedBox(height: 14),

              // Display Name
              TextFormField(
                controller: displayController,
                decoration: InputDecoration(
                  labelText: AppTranslations.text('display_name', langCode),
                  hintText: 'e.g. Grade 1, Standard 1',
                  prefixIcon: const Icon(Icons.badge_outlined),
                ),
              ),

              const SizedBox(height: 14),

              // Order Index
              TextFormField(
                controller: orderController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: AppTranslations.text('order_index', langCode),
                  hintText: 'e.g. 1, 2, 3...',
                  prefixIcon: const Icon(Icons.format_list_numbered),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return null;
                  }

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
                      controller: newSectionController,
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
                      onSubmitted: (_) => addSection(),
                    ),
                  ),

                  const SizedBox(width: 8),

                  ElevatedButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: Text(AppTranslations.text('add', langCode)),
                    onPressed: addSection,
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
              if (sections.value.isEmpty)
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
                      sections.value.map((sec) {
                        return Chip(
                          label: Text(
                            '${AppTranslations.text('section', langCode)} $sec',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          deleteIcon: const Icon(Icons.close, size: 14),
                          onDeleted: () => removeSection(sec),
                        );
                      }).toList(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
