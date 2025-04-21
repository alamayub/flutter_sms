import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../modesl/staff_model.dart';
import '../../providers/auth_providers.dart';
import '../input/name_input.dart';
import '../input/text_input.dart';
import 'form_dialog.dart';

class AddEditStaffDialog extends HookConsumerWidget {
  final StaffModel? staff;

  const AddEditStaffDialog({super.key, this.staff});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider.select((state) => state.school));
    var formKey = useMemoized(() => GlobalKey<FormState>());
    final fname = useTextEditingController(text: staff?.firstName ?? '');
    final mName = useTextEditingController(text: staff?.middleName ?? '');
    final lName = useTextEditingController(text: staff?.lastName ?? '');
    final phoneNumber = useTextEditingController(
      text: staff?.phoneNumber ?? '',
    );
    final address = useTextEditingController(text: staff?.address ?? '');

    return FormDialog(
      title: staff == null ? 'Add Staff' : 'Edit Staff',
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
                    child: TextInput(
                      controller: phoneNumber,
                      labelText: 'Phone Number*',
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
      onPressed: () {
        try {
          if (formKey.currentState!.validate()) {
            FocusScope.of(context).unfocus();
            final newStaff =
                StaffModel()
                  ..firstName = fname.text.trim()
                  ..middleName = mName.text.trim()
                  ..lastName = lName.text.trim()
                  ..address = address.text.trim()
                  ..createdBy = staff == null ? auth!.id : staff!.createdBy
                  ..createdAt =
                      staff == null
                          ? DateTime.now().toIso8601String()
                          : staff!.createdAt
                  ..updatedBy = staff != null ? auth!.id : null
                  ..updatedAt =
                      staff != null ? DateTime.now().toIso8601String() : null;

            if (staff != null) newStaff.id = staff!.id;
            Navigator.pop(context, newStaff);
          }
        } catch (_) {}
      },
    );
  }
}
