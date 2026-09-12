import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sms/widgets/ui/app_form_doalog.dart';

import '../../config/extensions.dart';
import '../../config/translations.dart';
import '../../data/app_database.dart';
import '../../providers/class_section_provider.dart';
import '../../utils/ui_helpers.dart';

class AddSectionDialog extends HookConsumerWidget {
  final ClassWithSections classItem;
  final String langCode;

  const AddSectionDialog({
    super.key,
    required this.classItem,
    required this.langCode,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = useTextEditingController();
    final isSubmitting = useState(false);

    Future<void> submit() async {
      final text = controller.text.trim();

      if (text.isEmpty) return;

      if (classItem.sections.any(
        (s) => s.name.toLowerCase() == text.toLowerCase(),
      )) {
        UiHelpers.showSnackBar(
          context,
          'Section "$text" already exists in ${classItem.name}',
          isError: true,
        );
        return;
      }

      isSubmitting.value = true;

      try {
        await ref
            .read(classSectionControllerProvider.notifier)
            .addSection(classId: classItem.id, name: text);

        if (context.mounted) {
          context.pop();

          UiHelpers.showSnackBar(
            context,
            'Section "$text" added to ${classItem.name}',
            isSuccess: true,
          );
        }
      } catch (e) {
        if (context.mounted) {
          UiHelpers.showSnackBar(
            context,
            'Failed to add section: $e',
            isError: true,
          );
        }
      } finally {
        if (context.mounted) {
          isSubmitting.value = false;
        }
      }
    }

    return AppFormDialog(
      title:
          '${AppTranslations.text('add_section', langCode)}: ${classItem.name}',
      cancelText: AppTranslations.text('cancel', langCode),
      actionText: AppTranslations.text('save', langCode),
      isSubmitting: isSubmitting.value,
      onAction: submit,
      width: 360,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: AppTranslations.text('section_name', langCode),
              hintText: 'e.g. A, B, C, Rose, Lotus',
              prefixIcon: const Icon(Icons.meeting_room_outlined),
            ),
            onSubmitted: (_) => submit(),
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
                      return !classItem.sections.any(
                        (sec) => sec.name.toUpperCase() == s,
                      );
                    })
                    .map((s) {
                      return ActionChip(
                        label: Text(s),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        onPressed:
                            isSubmitting.value
                                ? null
                                : () {
                                  controller.text = s;
                                  submit();
                                },
                      );
                    })
                    .toList(),
          ),
        ],
      ),
    );
  }
}
