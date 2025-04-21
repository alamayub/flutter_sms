import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart'
    show HookConsumerWidget, WidgetRef;

import '../../config/constants.dart' show Strings;
import '../../config/theme.dart' show ColorConstants;
import '../../modesl/staff_model.dart';
import '../../providers/staffs_provider.dart' show staffProvider;
import '../../widgets/buttons/table_action_widget.dart';
import '../../widgets/dialogs/alert_dialog_model.dart';
import '../../widgets/dialogs/staff_add_edit_dialog.dart';
import '../../widgets/generic/table_widget.dart';

class StaffsScreen extends HookConsumerWidget {
  const StaffsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staffs = ref.watch(staffProvider.select((state) => state.staffs));

    void addOrEditStaff(
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

    void deleteStaff(StaffModel staff) async {
      var result = await GenericDialog(
        Strings.delete,
      ).present(context).then((val) => val ?? false);
      if (result) {
        ref.read(staffProvider.notifier).deleteStaff(staff);
      }
    }

    return TableWidget<StaffModel>(
      title: 'Add Staff',
      onAddPressed: () => addOrEditStaff(context, ref),
      data: staffs,
      columns: [
        TableColumnDefinition(
          label: 'Full Name',
          cellBuilder: (s) => s.fullName,
        ),
        TableColumnDefinition(
          label: 'Phone Number',
          cellBuilder: (s) => s.phoneNumber,
        ),
        TableColumnDefinition(label: 'Address', cellBuilder: (s) => s.address),
      ],
      actionBuilder:
          (s, i) => [
            TableActionWidget(
              icon: Icons.edit_rounded,
              color: ColorConstants.primary,
              onPressed: () => addOrEditStaff(context, ref, s),
            ),
            TableActionWidget(
              icon: Icons.delete_rounded,
              color: Colors.red,
              onPressed: () => deleteStaff(s),
            ),
          ],
    );
  }
}
