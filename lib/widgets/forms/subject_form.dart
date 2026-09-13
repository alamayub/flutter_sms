import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../config/enums.dart';
import '../../config/extensions.dart';
import '../../config/translations.dart';
import '../../data/app_database.dart';
import '../../providers/locale_provider.dart';
import '../../providers/subject_provider.dart';
import '../../utils/ui_helpers.dart';
import '../../utils/validators.dart';
import '../ui/app_form_doalog.dart';

class SubjectForm extends HookConsumerWidget {
  final Subject? subject;

  const SubjectForm({super.key, this.subject});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formKey = useMemoized(() => GlobalKey<FormState>());

    final isEditing = subject != null;

    final codeController = useTextEditingController(
      text: isEditing ? subject!.code : '',
    );

    final nameController = useTextEditingController(
      text: isEditing ? subject!.name : '',
    );

    final fullMarksController = useTextEditingController(
      text: isEditing ? subject!.fullMarks.toString() : '100',
    );

    final passMarksController = useTextEditingController(
      text: isEditing ? subject!.passMarks.toString() : '40',
    );

    final theoryMarksController = useTextEditingController(
      text: isEditing ? subject!.theoryMarks?.toString() ?? '' : '75',
    );

    final practicalMarksController = useTextEditingController(
      text: isEditing ? subject!.practicalMarks?.toString() ?? '' : '25',
    );

    final descController = useTextEditingController(
      text: isEditing ? subject!.description ?? '' : '',
    );

    final subjectType = useState<SubjectType>(
      isEditing ? subject!.subjectType : SubjectType.both,
    );

    final isOptional = useState<bool>(isEditing ? subject!.isOptional : false);

    final isSubmitting = useState(false);

    final currentLang = ref.watch(localeProvider);
    final langCode = currentLang.locale.languageCode;

    void onSubjectTypeChanged(SubjectType type) {
      subjectType.value = type;

      if (type == SubjectType.theory) {
        theoryMarksController.text = fullMarksController.text;
        practicalMarksController.text = '0';
      } else if (type == SubjectType.practical) {
        theoryMarksController.text = '0';
        practicalMarksController.text = fullMarksController.text;
      } else {
        theoryMarksController.text = '75';
        practicalMarksController.text = '25';
      }
    }

    Future<void> save() async {
      if (!formKey.currentState!.validate()) return;

      final fullMarks = int.tryParse(fullMarksController.text.trim()) ?? 100;

      final passMarks = int.tryParse(passMarksController.text.trim()) ?? 40;

      final theoryMarks = int.tryParse(theoryMarksController.text.trim());

      final practicalMarks = int.tryParse(practicalMarksController.text.trim());

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

      isSubmitting.value = true;

      try {
        final controller = ref.read(subjectControllerProvider.notifier);

        if (isEditing) {
          await controller.updateSubject(
            id: subject!.id,
            code: codeController.text.trim(),
            name: nameController.text.trim(),
            subjectType: subjectType.value,
            isOptional: isOptional.value,
            fullMarks: fullMarks,
            passMarks: passMarks,
            theoryMarks: theoryMarks,
            practicalMarks: practicalMarks,
            description: descController.text.trim(),
          );
        } else {
          await controller.createSubject(
            code: codeController.text.trim(),
            name: nameController.text.trim(),
            subjectType: subjectType.value,
            isOptional: isOptional.value,
            fullMarks: fullMarks,
            passMarks: passMarks,
            theoryMarks: theoryMarks,
            practicalMarks: practicalMarks,
            description: descController.text.trim(),
          );
        }

        if (context.mounted) {
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
              ? AppTranslations.text('edit_subject', langCode)
              : AppTranslations.text('add_subject', langCode),
      cancelText: AppTranslations.text('cancel', langCode),
      actionText: AppTranslations.text('save', langCode),
      isSubmitting: isSubmitting.value,
      onAction: save,
      width: 500,

      content: Form(
        key: formKey,
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
                      controller: nameController,
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
                      controller: codeController,
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
                selected: {subjectType.value},
                onSelectionChanged: (set) {
                  onSubjectTypeChanged(set.first);
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
                value: isOptional.value,
                onChanged: (value) {
                  isOptional.value = value;
                },
              ),

              const SizedBox(height: 12),

              // Marks Setup
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: fullMarksController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: AppTranslations.text('full_marks', langCode),
                      ),
                      validator: (v) {
                        final n = int.tryParse(v ?? '');

                        if (n == null || n <= 0) {
                          return 'Invalid';
                        }

                        return null;
                      },
                    ),
                  ),

                  const SizedBox(width: 8),

                  Expanded(
                    child: TextFormField(
                      controller: passMarksController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: AppTranslations.text('pass_marks', langCode),
                      ),
                      validator: (v) {
                        final pass = int.tryParse(v ?? '');

                        final full = int.tryParse(fullMarksController.text);

                        if (pass == null || pass <= 0) {
                          return 'Invalid';
                        }

                        if (full != null && pass > full) {
                          return '> Full';
                        }

                        return null;
                      },
                    ),
                  ),

                  const SizedBox(width: 8),

                  Expanded(
                    child: TextFormField(
                      controller: theoryMarksController,
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
                      controller: practicalMarksController,
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
                controller: descController,
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
    );
  }
}
