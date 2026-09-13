import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../config/extensions.dart';
import '../../config/translations.dart';
import '../../data/app_database.dart';
import '../../providers/academic_year_provider.dart';
import '../../providers/locale_provider.dart';
import '../../utils/date_time_utils.dart';
import '../../utils/ui_helpers.dart';
import '../../utils/validators.dart';
import '../dual_date_picker.dart';

class AcademicYearForm extends HookConsumerWidget {
  final AcademicYear? year;

  const AcademicYearForm({super.key, this.year});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEditing = year != null;

    final formKey = useMemoized(() => GlobalKey<FormState>());

    final nameController = useTextEditingController(
      text: isEditing ? year!.name : '',
    );

    final descController = useTextEditingController(
      text: isEditing ? year!.description ?? '' : '',
    );

    final now = useMemoized(() => DateTime.now());

    final startDate = useState<DateTime>(isEditing ? year!.startDate : now);

    final endDate = useState<DateTime>(
      isEditing ? year!.endDate : now.add(const Duration(days: 365)),
    );

    final isCurrent = useState<bool>(isEditing ? year!.isCurrent : true);

    final isSubmitting = useState<bool>(false);

    // Set default academic year name only for new sessions.
    useEffect(() {
      if (!isEditing) {
        final nowBs = DateTimeUtils.nowBs;
        final yearStr = DateTimeUtils.getAcademicYearBs(nowBs);
        nameController.text = '$yearStr BS';
      }

      return null;
    }, const []);

    final currentLang = ref.watch(localeProvider);
    final langCode = currentLang.locale.languageCode;

    Future<void> save() async {
      if (!formKey.currentState!.validate()) return;

      if (endDate.value.isBefore(startDate.value)) {
        UiHelpers.showSnackBar(
          context,
          'End date must be after start date',
          isError: true,
        );
        return;
      }

      isSubmitting.value = true;

      try {
        final controller = ref.read(academicYearControllerProvider.notifier);

        if (isEditing) {
          await controller.updateYear(
            id: year!.id,
            name: nameController.text,
            startDate: startDate.value,
            endDate: endDate.value,
            isCurrent: isCurrent.value,
            description: descController.text,
          );
        } else {
          await controller.createYear(
            name: nameController.text,
            startDate: startDate.value,
            endDate: endDate.value,
            isCurrent: isCurrent.value,
            description: descController.text,
          );
        }

        if (context.mounted) {
          context.pop();

          UiHelpers.showSnackBar(
            context,
            isEditing ? 'Academic session updated' : 'Academic session created',
            isSuccess: true,
          );
        }
      } catch (e) {
        if (context.mounted) {
          UiHelpers.showSnackBar(context, 'Failed to save: $e', isError: true);
        }
      } finally {
        isSubmitting.value = false;
      }
    }

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        isEditing
            ? (langCode == 'ne'
                ? 'शैक्षिक सत्र सम्पादन'
                : 'Edit Academic Session')
            : (langCode == 'ne'
                ? 'नयाँ शैक्षिक सत्र थप्नुहोस्'
                : 'New Academic Session'),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: 480,
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText:
                        langCode == 'ne' ? 'सत्रको नाम *' : 'Session Name *',
                    hintText: 'e.g. 2081/82 BS',
                    prefixIcon: const Icon(Icons.label_outline),
                  ),
                  validator:
                      (v) => Validators.requiredField(
                        v,
                        'Session name is required',
                      ),
                ),
                const SizedBox(height: 14),

                DualDatePickerField(
                  label: langCode == 'ne' ? 'सुरु मिति *' : 'Start Date *',
                  selectedDate: startDate.value,
                  onDateSelected: (newDate) {
                    startDate.value = newDate;

                    if (endDate.value.isBefore(newDate)) {
                      endDate.value = newDate.add(const Duration(days: 365));
                    }
                  },
                ),
                const SizedBox(height: 14),

                DualDatePickerField(
                  label: langCode == 'ne' ? 'अन्त्य मिति *' : 'End Date *',
                  selectedDate: endDate.value,
                  onDateSelected: (newDate) {
                    endDate.value = newDate;
                  },
                ),
                const SizedBox(height: 14),

                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    langCode == 'ne'
                        ? 'सक्रिय सत्र बनाउनुहोस्'
                        : 'Set as Active Session',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    langCode == 'ne'
                        ? 'यसले अन्य सबै सत्रहरूलाई निष्क्रिय बनाउनेछ'
                        : 'This will automatically deactivate all other sessions',
                    style: const TextStyle(fontSize: 12),
                  ),
                  value: isCurrent.value,
                  onChanged: (value) {
                    isCurrent.value = value;
                  },
                ),
                const SizedBox(height: 8),

                TextFormField(
                  controller: descController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText:
                        langCode == 'ne'
                            ? 'विवरण (ऐच्छिक)'
                            : 'Description (Optional)',
                    hintText: 'Add notes about this academic session...',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: isSubmitting.value ? null : () => context.pop(),
          child: Text(AppTranslations.text('cancel', langCode)),
        ),
        ElevatedButton(
          onPressed: isSubmitting.value ? null : save,
          child:
              isSubmitting.value
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
}
