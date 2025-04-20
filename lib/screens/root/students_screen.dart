import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../config/constants.dart' show Strings;
import '../../config/theme.dart';
import '../../modesl/student_model.dart';
import '../../providers/student_provider.dart' show studentProvider;
import '../../widgets/buttons/table_action_widget.dart';
import '../../widgets/dialogs/add_edit_student_dialog.dart';
import '../../widgets/dialogs/alert_dialog_model.dart';
import '../../widgets/generic/table_widget.dart';

class StudentsScreen extends HookConsumerWidget {
  const StudentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final students = ref.watch(
      studentProvider.select((state) => state.students),
    );

    void addOrEditStudent(
      BuildContext context,
      WidgetRef ref, [
      StudentModel? student,
    ]) async {
      final result = await showDialog<StudentModel>(
        context: context,
        builder: (_) => AddEditStudentDialog(student: student),
      );

      if (result != null) {
        final notifier = ref.read(studentProvider.notifier);
        if (student == null) {
          await notifier.addStudent(result);
        } else {
          await notifier.updateStudent(result);
        }
      }
    }

    void deleteStudent(StudentModel student) async {
      var result = await GenericDialog(
        Strings.delete,
      ).present(context).then((val) => val ?? false);
      if (result) {
        ref.read(studentProvider.notifier).deleteStudent(student);
      }
    }

    return TableWidget<StudentModel>(
      title: 'Add Student',
      onAddPressed: () => addOrEditStudent(context, ref),
      data: students,
      columns: [
        TableColumnDefinition(
          label: 'Full Name',
          cellBuilder: (s) => s.fullName,
        ),
        TableColumnDefinition(
          label: 'Class',
          cellBuilder: (s) => '${s.grade} ${s.section} ${s.rollNo}',
        ),
        TableColumnDefinition(label: 'DOB', cellBuilder: (s) => s.dob),
        TableColumnDefinition(label: 'Address', cellBuilder: (s) => s.address),
      ],
      actionBuilder:
          (s, i) => [
            TableActionWidget(
              icon: Icons.edit_rounded,
              color: ColorConstants.primary,
              onPressed: () => addOrEditStudent(context, ref, s),
            ),
            TableActionWidget(
              icon: Icons.delete_rounded,
              color: Colors.red,
              onPressed: () => deleteStudent(s),
            ),
          ],
    );
  }
}
