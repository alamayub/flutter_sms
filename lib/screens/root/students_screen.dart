import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../config/constants.dart' show Strings;
import '../../config/theme.dart' show ColorConstants;
import '../../modesl/student_model.dart';
import '../../providers/student_provider.dart'
    show studentProvider, searchQueryProvider;
import '../../widgets/dialogs/add_edit_student_dialog.dart';
import '../../widgets/dialogs/alert_dialog_model.dart';
import '../../widgets/input/text_input.dart';

class StudentsScreen extends HookConsumerWidget {
  const StudentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rowsPerPage = useState<int>(10);
    final students = ref.watch(
      studentProvider.select((state) => state.students),
    );
    final searchQuery = ref.watch(searchQueryProvider);
    final search = useTextEditingController();
    final filteredStudents = useMemoized(() {
      return students
          .where(
            (s) =>
                s.firstName.toLowerCase().contains(searchQuery.toLowerCase()) ||
                s.lastName.toLowerCase().contains(searchQuery.toLowerCase()),
          )
          .toList();
    }, [searchQuery, students]);

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

    void deleteStudent(int index) async {
      var result = await GenericDialog(
        Strings.delete,
      ).present(context).then((val) => val ?? false);
      if (result) {
        ref
            .read(studentProvider.notifier)
            .deleteStudent(filteredStudents[index]);
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: PaginatedDataTable(
              header: TextInput(
                controller: search,
                labelText: 'Search...',
                onChanged: (val) {
                  if (val != null) {
                    ref.read(searchQueryProvider.notifier).state = val;
                  }
                },
              ),
              actions: [
                SizedBox(
                  height: 36,
                  child: ElevatedButton.icon(
                    onPressed: () => addOrEditStudent(context, ref),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Student'),
                  ),
                ),
              ],
              columns: const [
                DataColumn(
                  label: Text('SN'),
                  columnWidth: FixedColumnWidth(40),
                ),
                DataColumn(label: Text('Name'), columnWidth: FlexColumnWidth()),
                DataColumn(label: Text('Class')),
                DataColumn(
                  label: Text('DOB'),
                  columnWidth: FixedColumnWidth(75),
                ),
                DataColumn(
                  label: Text('Address'),
                  columnWidth: FlexColumnWidth(),
                ),
                DataColumn(
                  label: Text('Actions'),
                  columnWidth: FixedColumnWidth(74),
                ),
              ],
              columnSpacing: 12,
              horizontalMargin: 16,
              headingRowHeight: 30,
              source: _StudentDataSource(
                filteredStudents,
                (s, i) => addOrEditStudent(context, ref, s),
                deleteStudent,
              ),
              rowsPerPage: rowsPerPage.value,
              availableRowsPerPage: const [10, 20, 50],
              onRowsPerPageChanged: (value) => rowsPerPage.value = value ?? 20,
            ),
          ),
        );
      },
    );
  }
}

class _StudentDataSource extends DataTableSource {
  final List<StudentModel> students;
  final void Function(StudentModel student, int index) onEdit;
  final void Function(int index) onDelete;

  _StudentDataSource(this.students, this.onEdit, this.onDelete);

  @override
  DataRow getRow(int index) {
    final s = students[index];
    return DataRow(
      cells: [
        DataCell(Text('${index + 1}')),
        DataCell(Text(s.fullName)),
        DataCell(Text('${s.grade} ${s.section} ${s.rollNo}')),
        DataCell(Text(s.dob)),
        DataCell(Text(s.address)),
        DataCell(
          Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: IconButton(
                  icon: const Icon(
                    Icons.edit,
                    size: 14,
                    color: ColorConstants.primary,
                  ),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    backgroundColor: ColorConstants.primary.withAlpha(40),
                  ),
                  onPressed: () => onEdit(s, index),
                ),
              ),
              const SizedBox(width: 4),
              SizedBox(
                width: 24,
                height: 24,
                child: IconButton(
                  icon: const Icon(Icons.delete, size: 14, color: Colors.red),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    backgroundColor: Colors.red.withAlpha(40),
                  ),
                  onPressed: () => onDelete(index),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => students.length;

  @override
  int get selectedRowCount => 0;
}
