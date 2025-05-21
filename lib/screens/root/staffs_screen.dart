import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../config/constants.dart' show Strings;
import '../../config/theme.dart' show ColorConstants;
import '../../models/staff_model.dart';
import '../../providers/staffs_provider.dart';
import '../../widgets/buttons/table_action_widget.dart';
import '../../widgets/dialogs/alert_dialog_model.dart';
import '../../widgets/dialogs/staff_add_edit_dialog.dart';
import '../../widgets/generic/error_retry_widget.dart';
import '../../widgets/generic/loader_widget.dart';
import '../../widgets/generic/table_widget.dart';

class StaffsScreen extends HookConsumerWidget {
  const StaffsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

    return ref
        .watch(staffListProvider)
        .when(
          data:
              (staffs) => TableWidget<StaffModel>(
                title: 'Add Staff',
                onAddPressed: () => addOrEditStaff(context, ref),
                data: staffs,
                columns: [
                  TableColumnDefinition(
                    label: 'Name',
                    cellBuilder: (s) => s.fullName,
                  ),
                  TableColumnDefinition(
                    label: 'Phone',
                    cellBuilder: (s) => s.phoneNumber,
                  ),
                  TableColumnDefinition(
                    label: 'Dsignation',
                    cellBuilder: (s) => s.designation.toUpperCase(),
                  ),
                  TableColumnDefinition(
                    label: 'Joining Date',
                    cellBuilder: (s) => s.joiningDate,
                  ),
                  TableColumnDefinition(
                    label: 'Salary',
                    cellBuilder: (s) => 'रु${s.salary}',
                  ),
                  TableColumnDefinition(
                    label: 'Address',
                    cellBuilder: (s) => s.address,
                  ),
                ],
                actionBuilder:
                    (s, i) => [
                      TableActionWidget(
                        tooltip: 'Edit',
                        icon: Icons.edit_rounded,
                        color: ColorConstants.primary,
                        onPressed: () => addOrEditStaff(context, ref, s),
                      ),
                      const SizedBox(width: 4),
                      TableActionWidget(
                        tooltip: 'Delete',
                        icon: Icons.delete_rounded,
                        color: Colors.red,
                        onPressed: () => deleteStaff(s),
                      ),
                    ],
              ),
          error:
              (error, stackTrace) => ErrorRetryWidget(
                message: error.toString(),
                onRetry: () => ref.refresh(staffListProvider),
              ),
          loading: () => const LoaderWidget(),
        );
  }
}
