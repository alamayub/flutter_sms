import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../config/constants.dart' show Strings;
import '../../config/theme.dart' show ColorConstants;
import '../../modesl/staff_model.dart';
import '../../providers/staffs_provider.dart';
import '../../widgets/dialogs/alert_dialog_model.dart';
import '../../widgets/dialogs/staff_add_edit_dialog.dart';
import '../../widgets/input/text_input.dart';

class StaffsScreen extends HookConsumerWidget {
  const StaffsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rowsPerPage = useState<int>(10);
    final staffs = ref.watch(staffProvider.select((state) => state.staffs));
    final searchQuery = ref.watch(
      staffProvider.select((state) => state.search),
    );
    final search = useTextEditingController();
    final filteredstaffs = useMemoized(() {
      if (searchQuery == null || searchQuery.trim().isEmpty) return staffs;
      final query = searchQuery.toLowerCase();
      return staffs
          .where(
            (s) =>
                s.firstName.toLowerCase().contains(query) ||
                s.lastName.toLowerCase().contains(query),
          )
          .toList();
    }, [searchQuery, staffs]);

    void addOrEditstaff(
      BuildContext context,
      WidgetRef ref, [
      StaffModel? staff,
    ]) async {
      final result = await showDialog<StaffModel>(
        context: context,
        builder: (_) => AddEditStaffDialog(staff: staff),
      );

      if (result != null) {
        final notifier = ref.read(staffProvider.notifier);
        if (staff == null) {
          await notifier.addStaff(result);
        } else {
          await notifier.updateStaff(result);
        }
      }
    }

    void deletestaff(int index) async {
      var result = await GenericDialog(
        Strings.delete,
      ).present(context).then((val) => val ?? false);
      if (result) {
        ref.read(staffProvider.notifier).deleteStaff(filteredstaffs[index]);
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
                onChanged:
                    (val) => ref.read(staffProvider.notifier).updateSearch(val),
              ),
              actions: [
                SizedBox(
                  height: 36,
                  child: ElevatedButton.icon(
                    onPressed: () => addOrEditstaff(context, ref),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Staff'),
                  ),
                ),
              ],
              columns: const [
                DataColumn(
                  label: Text('SN'),
                  columnWidth: FixedColumnWidth(40),
                ),
                DataColumn(label: Text('Name'), columnWidth: FlexColumnWidth()),
                DataColumn(label: Text('Phone Number')),
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
              source: _StaffDataSource(
                filteredstaffs,
                (s, i) => addOrEditstaff(context, ref, s),
                deletestaff,
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

class _StaffDataSource extends DataTableSource {
  final List<StaffModel> staffs;
  final void Function(StaffModel staff, int index) onEdit;
  final void Function(int index) onDelete;

  _StaffDataSource(this.staffs, this.onEdit, this.onDelete);

  @override
  DataRow getRow(int index) {
    final s = staffs[index];
    return DataRow(
      cells: [
        DataCell(Text('${index + 1}')),
        DataCell(Text(s.fullName)),
        DataCell(Text(s.phoneNumber)),
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
  int get rowCount => staffs.length;

  @override
  int get selectedRowCount => 0;
}
