import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../../config/constants.dart' show Strings;
import '../../config/extensions.dart' show DialogText;
import '../../config/theme.dart' show ColorConstants;
import '../../modesl/student_model.dart';
import '../buttons/dialog_action_button.dart';
import '../input/date_input.dart';
import '../input/name_input.dart';
import '../input/number_input.dart';
import '../input/select_widget.dart';
import '../input/text_input.dart';

class AddEditStudentDialog extends HookWidget {
  final StudentModel? student;

  const AddEditStudentDialog({super.key, this.student});

  @override
  Widget build(BuildContext context) {
    var formKey = useMemoized(() => GlobalKey<FormState>());
    final fname = useTextEditingController(text: student?.firstName ?? '');
    final mName = useTextEditingController(text: student?.middleName ?? '');
    final lName = useTextEditingController(text: student?.lastName ?? '');
    final dob = useTextEditingController(text: student?.dob ?? '');
    final grade = useState<String?>(student?.grade);
    final section = useState<String?>(student?.section);
    final rollNo = useTextEditingController(text: student?.rollNo ?? '');
    final address = useTextEditingController(text: student?.address ?? '');

    return AlertDialog(
      title: (student == null ? "Add Student" : "Edit Student").dialogTitle,
      content: Form(
        key: formKey,
        child: SizedBox(
          width: 600,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: NameInput(
                      labeltext: 'First Name*',
                      controller: fname,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: NameInput(
                      required: false,
                      labeltext: 'Middle Name',
                      controller: mName,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: NameInput(
                      labeltext: 'Last Name*',
                      controller: lName,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DateInput(
                      controller: dob,
                      onTap: (x) => dob.text = x ?? '',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: SelectWidget(
                      value: grade.value,
                      onChanged: (x) => grade.value = x,
                      labelText: 'Grade*',
                      lists: List.generate(10, (i) => (i + 1).toString()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SelectWidget(
                      value: section.value,
                      onChanged: (x) => section.value = x,
                      labelText: 'Section*',
                      lists: ['A', 'B', 'C', 'D', 'E'],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: NumberInput(
                      controller: rollNo,
                      labelText: 'Roll No.*',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextInput(controller: address, labelText: 'Address*'),
            ],
          ),
        ),
      ),
      actions: [
        DialogActionButton(
          color: Colors.redAccent,
          title: Strings.cancle,
          onPressed: () => Navigator.pop(context),
        ),
        DialogActionButton(
          color: ColorConstants.primary,
          title: Strings.submit,
          onPressed: () {
            try {
              if (formKey.currentState!.validate()) {
                FocusScope.of(context).unfocus();
                final newStudent =
                    StudentModel()
                      ..firstName = fname.text.trim()
                      ..middleName = mName.text.trim()
                      ..lastName = lName.text.trim()
                      ..dob = dob.text.trim()
                      ..grade = grade.value ?? ''
                      ..section = section.value ?? ''
                      ..rollNo = rollNo.text.trim()
                      ..address = address.text.trim()
                      ..createdBy = student == null ? '' : student!.createdBy
                      ..createdAt =
                          student == null
                              ? DateTime.now().toIso8601String()
                              : student!.createdAt
                      ..updatedBy = student != null ? '' : null
                      ..updatedAt =
                          student != null
                              ? DateTime.now().toIso8601String()
                              : null;

                if (student != null) newStudent.id = student!.id;
                Navigator.pop(context, newStudent);
              }
            } catch (_) {}
          },
        ),
      ],
    );
  }
}
