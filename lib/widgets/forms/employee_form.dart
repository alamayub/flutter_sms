import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../config/enums.dart';
import '../../config/extensions.dart';
import '../../config/translations.dart';
import '../../data/app_database.dart';
import '../../providers/employee_provider.dart';
import '../../utils/image_storage_helper.dart';
import '../../utils/validators.dart';
import '../dual_date_picker.dart';
import '../searchable_select.dart';

class EmployeeForm extends HookConsumerWidget {
  final Employee? employee;
  final String langCode;

  const EmployeeForm({super.key, this.employee, required this.langCode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formKey = useMemoized(() => GlobalKey<FormState>());

    final isEditing = employee != null;
    final theme = Theme.of(context);

    // -------------------------------------------------------------------------
    // Employee type
    // -------------------------------------------------------------------------

    final employeeType = useState<EmployeeType>(
      employee?.employeeType ?? EmployeeType.teacher,
    );

    // -------------------------------------------------------------------------
    // Controllers
    // -------------------------------------------------------------------------

    final nameController = useTextEditingController(text: employee?.name ?? '');

    final designationController = useTextEditingController(
      text:
          employee?.designation ??
          (employeeType.value == EmployeeType.teacher ? 'Teacher' : 'Staff'),
    );

    final phoneController = useTextEditingController(
      text: employee?.phone ?? '',
    );

    final emailController = useTextEditingController(
      text: employee?.email ?? '',
    );

    final addressController = useTextEditingController(
      text: employee?.address ?? '',
    );

    final emergencyNameController = useTextEditingController(
      text: employee?.emergencyContactName ?? '',
    );

    final emergencyPhoneController = useTextEditingController(
      text: employee?.emergencyContactPhone ?? '',
    );

    final departmentController = useTextEditingController(
      text: employee?.department ?? '',
    );

    final qualificationController = useTextEditingController(
      text: employee?.qualification ?? '',
    );

    final salaryController = useTextEditingController(
      text:
          employee?.basicSalary != null ? employee!.basicSalary.toString() : '',
    );

    // -------------------------------------------------------------------------
    // Local state
    // -------------------------------------------------------------------------

    final generatedCode = useState('');
    final loadingCode = useState(false);

    final photoPath = useState<String?>(employee?.photoPath);

    final emergencyRelation = useState<String?>(
      employee?.emergencyContactRelation,
    );

    final gender = useState<String?>(employee?.gender);
    final bloodGroup = useState<String?>(employee?.bloodGroup);
    final maritalStatus = useState<String?>(employee?.maritalStatus);

    final dob = useState<DateTime?>(employee?.dateOfBirth);

    final joiningDate = useState<DateTime?>(employee?.joiningDate);

    final isActive = useState<bool>(employee?.isActive ?? true);

    // -------------------------------------------------------------------------
    // Static options
    // -------------------------------------------------------------------------

    final bloodGroups = const [
      'A+',
      'A-',
      'B+',
      'B-',
      'O+',
      'O-',
      'AB+',
      'AB-',
    ];

    final genders = const ['Male', 'Female', 'Other'];

    final maritalStatuses = const ['Single', 'Married', 'Divorced', 'Widowed'];

    // -------------------------------------------------------------------------
    // Generate employee code when creating
    // -------------------------------------------------------------------------

    Future<void> loadGeneratedCode(EmployeeType type) async {
      if (employee != null) return;

      loadingCode.value = true;

      try {
        final code = await ref
            .read(employeeServiceProvider)
            .generateNextEmployeeCode(type);

        generatedCode.value = code;
      } catch (_) {
        // Optionally show/log error here.
      } finally {
        loadingCode.value = false;
      }
    }

    // Run once for new employee.
    useEffect(() {
      if (employee == null) {
        loadGeneratedCode(employeeType.value);
      }

      return null;
    }, const []);

    // -------------------------------------------------------------------------
    // Photo
    // -------------------------------------------------------------------------

    Future<void> pickPhoto() async {
      try {
        final path = await ImageStorageHelper.pickAndSaveEmployeePhoto();

        if (path != null) {
          photoPath.value = path;
        }
      } catch (error) {
        if (context.mounted) {
          context.showSnackbar('Could not select employee photo: $error');
        }
      }
    }

    void removePhoto() {
      photoPath.value = null;
    }

    // -------------------------------------------------------------------------
    // Save employee
    // -------------------------------------------------------------------------

    Future<void> saveEmployee() async {
      if (!(formKey.currentState?.validate() ?? false)) {
        return;
      }

      final errorColor = theme.colorScheme.error;

      final double? salary =
          salaryController.text.trim().isNotEmpty
              ? double.tryParse(salaryController.text.trim())
              : null;

      try {
        if (isEditing) {
          await ref
              .read(employeeControllerProvider.notifier)
              .updateEmployee(
                id: employee!.id,
                name: nameController.text.trim(),
                employeeType: employeeType.value,
                designation: designationController.text.trim(),
                employeeCode: employee!.employeeCode,
                photoPath: photoPath.value,

                emergencyContactName:
                    emergencyNameController.text.trim().isEmpty
                        ? null
                        : emergencyNameController.text.trim(),

                emergencyContactPhone:
                    emergencyPhoneController.text.trim().isEmpty
                        ? null
                        : emergencyPhoneController.text.trim(),

                emergencyContactRelation: emergencyRelation.value,

                email:
                    emailController.text.trim().isEmpty
                        ? null
                        : emailController.text.trim(),

                phone:
                    phoneController.text.trim().isEmpty
                        ? null
                        : phoneController.text.trim(),

                dateOfBirth: dob.value,
                gender: gender.value,
                bloodGroup: bloodGroup.value,
                maritalStatus: maritalStatus.value,

                address:
                    addressController.text.trim().isEmpty
                        ? null
                        : addressController.text.trim(),

                qualification:
                    qualificationController.text.trim().isEmpty
                        ? null
                        : qualificationController.text.trim(),

                department:
                    departmentController.text.trim().isEmpty
                        ? null
                        : departmentController.text.trim(),

                joiningDate: joiningDate.value,
                basicSalary: salary,
                isActive: isActive.value,
              );
        } else {
          await ref
              .read(employeeControllerProvider.notifier)
              .createEmployee(
                name: nameController.text.trim(),
                employeeType: employeeType.value,
                designation: designationController.text.trim(),
                employeeCode:
                    generatedCode.value.isNotEmpty ? generatedCode.value : null,

                photoPath: photoPath.value,

                emergencyContactName:
                    emergencyNameController.text.trim().isEmpty
                        ? null
                        : emergencyNameController.text.trim(),

                emergencyContactPhone:
                    emergencyPhoneController.text.trim().isEmpty
                        ? null
                        : emergencyPhoneController.text.trim(),

                emergencyContactRelation: emergencyRelation.value,

                email:
                    emailController.text.trim().isEmpty
                        ? null
                        : emailController.text.trim(),

                phone:
                    phoneController.text.trim().isEmpty
                        ? null
                        : phoneController.text.trim(),

                dateOfBirth: dob.value,
                gender: gender.value,
                bloodGroup: bloodGroup.value,
                maritalStatus: maritalStatus.value,

                address:
                    addressController.text.trim().isEmpty
                        ? null
                        : addressController.text.trim(),

                qualification:
                    qualificationController.text.trim().isEmpty
                        ? null
                        : qualificationController.text.trim(),

                department:
                    departmentController.text.trim().isEmpty
                        ? null
                        : departmentController.text.trim(),

                joiningDate: joiningDate.value,
                basicSalary: salary,
                isActive: isActive.value,
              );
        }

        if (!context.mounted) return;

        context.pop();

        context.showSnackbar(
          SnackBar(
            content: Text(
              isEditing
                  ? (langCode == 'ne'
                      ? 'कर्मचारी सफलतापूर्वक अद्यावधिक गरियो'
                      : 'Employee updated successfully')
                  : (langCode == 'ne'
                      ? 'नयाँ कर्मचारी सफलतापूर्वक थपियो'
                      : 'Employee created successfully'),
            ),
          ),
        );
      } catch (e) {
        if (!context.mounted) return;

        context.showSnackbar(
          SnackBar(content: Text('Error: $e'), backgroundColor: errorColor),
        );
      }
    }

    // =========================================================================
    // UI
    // =========================================================================

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 680, maxHeight: 760),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ----------------------------------------------------------------
              // Dialog Title
              // ----------------------------------------------------------------
              Row(
                children: [
                  Icon(
                    isEditing ? Icons.edit : Icons.person_add,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isEditing
                        ? AppTranslations.text('edit_employee', langCode)
                        : AppTranslations.text('add_employee', langCode),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => context.pop(),
                  ),
                ],
              ),

              const Divider(),
              const SizedBox(height: 8),

              // ----------------------------------------------------------------
              // Scrollable Form
              // ----------------------------------------------------------------
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --------------------------------------------------------
                      // Employee Type
                      // --------------------------------------------------------
                      Text(
                        AppTranslations.text('employee_type', langCode),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),

                      const SizedBox(height: 8),

                      SegmentedButton<EmployeeType>(
                        segments: [
                          ButtonSegment(
                            value: EmployeeType.teacher,
                            label: Text(
                              AppTranslations.text('teachers', langCode),
                            ),
                            icon: const Icon(Icons.school_outlined),
                          ),
                          ButtonSegment(
                            value: EmployeeType.staff,
                            label: Text(
                              AppTranslations.text('staff', langCode),
                            ),
                            icon: const Icon(Icons.badge_outlined),
                          ),
                        ],
                        selected: {employeeType.value},
                        onSelectionChanged: (set) {
                          final newType = set.first;

                          employeeType.value = newType;

                          if (!isEditing &&
                              (designationController.text == 'Teacher' ||
                                  designationController.text == 'Staff')) {
                            designationController.text =
                                newType == EmployeeType.teacher
                                    ? 'Teacher'
                                    : 'Staff';
                          }

                          if (!isEditing) {
                            loadGeneratedCode(newType);
                          }
                        },
                      ),

                      const SizedBox(height: 16),

                      // --------------------------------------------------------
                      // Personal Details
                      // --------------------------------------------------------
                      Text(
                        AppTranslations.text('personal_details', langCode),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),

                      const SizedBox(height: 10),

                      TextFormField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText:
                              '${AppTranslations.text('employee', langCode)} Name *',
                          prefixIcon: const Icon(Icons.person_outline),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Please enter employee name';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 10),

                      // --------------------------------------------------------
                      // Employee Code
                      // --------------------------------------------------------
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest
                              .withAlpha(60),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: theme.dividerColor),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.badge_outlined,
                              size: 20,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppTranslations.text(
                                    'employee_code',
                                    langCode,
                                  ),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: theme.textTheme.bodySmall?.color,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isEditing
                                      ? (employee!.employeeCode ?? '-')
                                      : (loadingCode.value
                                          ? 'Generating...'
                                          : generatedCode.value),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withAlpha(25),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isEditing
                                    ? (langCode == 'ne'
                                        ? 'सुरक्षित कोड'
                                        : 'Assigned')
                                    : (langCode == 'ne'
                                        ? 'स्वतः सिर्जना'
                                        : 'Auto-generated'),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 10),

                      // --------------------------------------------------------
                      // Designation & Department
                      // --------------------------------------------------------
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: designationController,
                              decoration: InputDecoration(
                                labelText:
                                    '${AppTranslations.text('designation', langCode)} *',
                                prefixIcon: const Icon(Icons.work_outline),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Please enter designation';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: departmentController,
                              decoration: InputDecoration(
                                labelText: AppTranslations.text(
                                  'department',
                                  langCode,
                                ),
                                prefixIcon: const Icon(Icons.domain),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // --------------------------------------------------------
                      // Phone & Email
                      // --------------------------------------------------------
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: phoneController,
                              decoration: const InputDecoration(
                                labelText: 'Phone',
                                prefixIcon: Icon(Icons.phone_outlined),
                              ),
                              keyboardType: TextInputType.phone,
                              validator: (val) {
                                if (val != null && val.trim().isNotEmpty) {
                                  return Validators.validatePhone(val.trim());
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: emailController,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                prefixIcon: Icon(Icons.email_outlined),
                              ),
                              keyboardType: TextInputType.emailAddress,
                              validator: (val) {
                                if (val != null && val.trim().isNotEmpty) {
                                  return Validators.validateEmail(val.trim());
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // --------------------------------------------------------
                      // Photo
                      // --------------------------------------------------------
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest
                              .withAlpha(40),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: theme.dividerColor),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surface,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: theme.dividerColor),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child:
                                  photoPath.value != null &&
                                          photoPath.value!.isNotEmpty
                                      ? (ImageStorageHelper.isLocalFile(
                                            photoPath.value!,
                                          )
                                          ? Image.file(
                                            File(photoPath.value!),
                                            fit: BoxFit.cover,
                                          )
                                          : (photoPath.value!.startsWith('http')
                                              ? Image.network(
                                                photoPath.value!,
                                                fit: BoxFit.cover,
                                              )
                                              : const Icon(
                                                Icons.person,
                                                size: 32,
                                              )))
                                      : Icon(
                                        Icons.person_outline,
                                        size: 32,
                                        color: theme.colorScheme.primary
                                            .withAlpha(120),
                                      ),
                            ),

                            const SizedBox(width: 14),

                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    AppTranslations.text('photo', langCode),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    photoPath.value != null &&
                                            photoPath.value!.isNotEmpty
                                        ? photoPath.value!.split('/').last
                                        : (langCode == 'ne'
                                            ? 'उपकरणबाट फोटो छान्नुहोस्'
                                            : 'Stored locally in app storage'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: theme.textTheme.bodySmall?.color,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            OutlinedButton.icon(
                              onPressed: pickPhoto,
                              icon: const Icon(
                                Icons.photo_camera_outlined,
                                size: 16,
                              ),
                              label: Text(
                                photoPath.value != null
                                    ? (langCode == 'ne'
                                        ? 'फेर्नुहोस्'
                                        : 'Change')
                                    : (langCode == 'ne'
                                        ? 'फोटो छान्नुहोस्'
                                        : 'Select Photo'),
                              ),
                            ),

                            if (photoPath.value != null &&
                                photoPath.value!.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                  size: 20,
                                ),
                                tooltip:
                                    langCode == 'ne'
                                        ? 'हटाउनुहोस्'
                                        : 'Remove Photo',
                                onPressed: removePhoto,
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // --------------------------------------------------------
                      // Emergency Contact
                      // --------------------------------------------------------
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.withAlpha(20),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber.withAlpha(60)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.emergency_outlined,
                                  size: 16,
                                  color: Colors.amber,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  AppTranslations.text(
                                    'emergency_details',
                                    langCode,
                                  ),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 10),

                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: TextFormField(
                                    controller: emergencyNameController,
                                    decoration: InputDecoration(
                                      labelText: AppTranslations.text(
                                        'emergency_contact',
                                        langCode,
                                      ),
                                      prefixIcon: const Icon(Icons.person_pin),
                                      isDense: true,
                                    ),
                                  ),
                                ),

                                const SizedBox(width: 8),

                                Expanded(
                                  flex: 1,
                                  child: AppSearchableSelect<String>(
                                    value: emergencyRelation.value,
                                    label: AppTranslations.text(
                                      'relation',
                                      langCode,
                                    ),
                                    isDense: true,
                                    items: ContactRelationOptions.items,
                                    onChanged: (val) {
                                      emergencyRelation.value = val;
                                    },
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 8),

                            TextFormField(
                              controller: emergencyPhoneController,
                              decoration: InputDecoration(
                                labelText: AppTranslations.text(
                                  'emergency_phone',
                                  langCode,
                                ),
                                prefixIcon: const Icon(Icons.phone_in_talk),
                                isDense: true,
                              ),
                              keyboardType: TextInputType.phone,
                              validator: (val) {
                                if (val != null && val.trim().isNotEmpty) {
                                  return Validators.validatePhone(val.trim());
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // --------------------------------------------------------
                      // Optional / Personal Information
                      // --------------------------------------------------------
                      Text(
                        AppTranslations.text('optional_info', langCode),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),

                      const SizedBox(height: 10),

                      Row(
                        children: [
                          Expanded(
                            child: DualDatePickerField(
                              label: AppTranslations.text(
                                'date_of_birth',
                                langCode,
                              ),
                              selectedDate: dob.value,
                              onDateSelected: (date) {
                                dob.value = date;
                              },
                              lastDate: DateTime.now(),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: AppSearchableSelect<String>(
                              value: gender.value,
                              label: AppTranslations.text('gender', langCode),
                              prefixIcon: const Icon(Icons.wc),
                              isClearable: true,
                              items:
                                  genders
                                      .map(
                                        (g) => SearchableSelectItem<String>(
                                          value: g,
                                          label: g,
                                        ),
                                      )
                                      .toList(),
                              onChanged: (val) {
                                gender.value = val;
                              },
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      Row(
                        children: [
                          Expanded(
                            child: AppSearchableSelect<String>(
                              value: bloodGroup.value,
                              label: AppTranslations.text(
                                'blood_group',
                                langCode,
                              ),
                              prefixIcon: const Icon(Icons.bloodtype_outlined),
                              isClearable: true,
                              items:
                                  bloodGroups
                                      .map(
                                        (bg) => SearchableSelectItem<String>(
                                          value: bg,
                                          label: bg,
                                        ),
                                      )
                                      .toList(),
                              onChanged: (val) {
                                bloodGroup.value = val;
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: AppSearchableSelect<String>(
                              value: maritalStatus.value,
                              label: AppTranslations.text(
                                'marital_status',
                                langCode,
                              ),
                              prefixIcon: const Icon(Icons.favorite_outline),
                              isClearable: true,
                              items:
                                  maritalStatuses
                                      .map(
                                        (ms) => SearchableSelectItem<String>(
                                          value: ms,
                                          label: ms,
                                        ),
                                      )
                                      .toList(),
                              onChanged: (val) {
                                maritalStatus.value = val;
                              },
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      TextFormField(
                        controller: addressController,
                        decoration: InputDecoration(
                          labelText: AppTranslations.text('address', langCode),
                          prefixIcon: const Icon(Icons.home_outlined),
                        ),
                        maxLines: 2,
                      ),

                      const SizedBox(height: 16),

                      // --------------------------------------------------------
                      // Professional Details
                      // --------------------------------------------------------
                      Text(
                        AppTranslations.text('professional_details', langCode),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),

                      const SizedBox(height: 10),

                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: qualificationController,
                              decoration: InputDecoration(
                                labelText: AppTranslations.text(
                                  'qualification',
                                  langCode,
                                ),
                                prefixIcon: const Icon(Icons.school_outlined),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: salaryController,
                              decoration: const InputDecoration(
                                labelText: 'Basic Salary (Rs.)',
                                prefixIcon: Icon(Icons.attach_money),
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      DualDatePickerField(
                        label: AppTranslations.text('joining_date', langCode),
                        selectedDate: joiningDate.value,
                        onDateSelected: (date) {
                          joiningDate.value = date;
                        },
                      ),

                      const SizedBox(height: 12),

                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(AppTranslations.text('active', langCode)),
                        subtitle: Text(
                          langCode == 'ne'
                              ? 'यस कर्मचारीको खाता सक्रिय राख्ने वा नराख्ने'
                              : 'Whether this employee record is active',
                        ),
                        value: isActive.value,
                        onChanged: (val) {
                          isActive.value = val;
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),
              const Divider(),

              // ----------------------------------------------------------------
              // Actions
              // ----------------------------------------------------------------
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => context.pop(),
                    child: Text(AppTranslations.text('cancel', langCode)),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: saveEmployee,
                    child: Text(AppTranslations.text('save', langCode)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
