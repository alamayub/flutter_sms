import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../../config/enums.dart';
import '../../config/extensions.dart';
import '../../config/translations.dart';
import '../../data/app_database.dart';
import '../../providers/academic_year_provider.dart';
import '../../providers/class_section_provider.dart';
import '../../providers/contact_provider.dart';
import '../../providers/fee_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/student_provider.dart';
import '../../services/fee_service.dart';
import '../../utils/image_storage_helper.dart';
import '../app_input.dart';

class _AdmissionFeeDraft {
  final FeeCategory category;
  String frequency;
  final TextEditingController amountController;
  final TextEditingController discountController;

  _AdmissionFeeDraft({
    required this.category,
    required this.frequency,
    required double amount,
  }) : amountController = TextEditingController(
         text: amount.toStringAsFixed(2),
       ),
       discountController = TextEditingController(text: '0');

  factory _AdmissionFeeDraft.fromCategory(FeeCategory category) {
    return _AdmissionFeeDraft(
      category: category,
      frequency: category.frequency,
      amount: category.defaultAmount,
    );
  }

  AdmissionFeePlan toAdmissionFeePlan() {
    return AdmissionFeePlan(
      feeCategoryId: category.id,
      title: category.name,
      frequency: frequency,
      amount: double.tryParse(amountController.text.trim()) ?? 0,
      discountAmount: double.tryParse(discountController.text.trim()) ?? 0,
    );
  }

  void dispose() {
    amountController.dispose();
    discountController.dispose();
  }
}

class AdmissionCompletedData {
  final String studentName;
  final String studentId;
  final String admissionNumber;
  final List<AdmissionFeePlan> plans;
  final String? feeError;

  const AdmissionCompletedData({
    required this.studentName,
    required this.studentId,
    required this.admissionNumber,
    required this.plans,
    this.feeError,
  });
}

class StudentAdmissionDialog extends ConsumerStatefulWidget {
  final StudentWithDetails? existingStudent;

  const StudentAdmissionDialog({super.key, this.existingStudent});

  @override
  ConsumerState<StudentAdmissionDialog> createState() =>
      _StudentAdmissionDialogState();
}

class _StudentAdmissionDialogState
    extends ConsumerState<StudentAdmissionDialog> {
  final _formKey = GlobalKey<FormState>();

  // Personal Fields
  late TextEditingController _nameController;
  late TextEditingController _addressController;
  String _gender = 'Male';
  DateTime? _dateOfBirth;
  String? _bloodGroup;
  String? _photoPath;

  // Enrollment Fields
  int? _selectedAcademicYearId;
  int? _selectedClassId;
  int? _selectedSectionId;
  late TextEditingController _rollNumberController;
  DateTime _admissionDate = DateTime.now();

  // Contacts
  late TextEditingController _guardianNameController;
  late TextEditingController _guardianPhoneController;
  late TextEditingController _guardianRelationController;
  late TextEditingController _guardianOccupationController;

  late TextEditingController _emergencyNameController;
  late TextEditingController _emergencyPhoneController;
  late TextEditingController _emergencyRelationController;
  late TextEditingController _emergencyOccupationController;

  // Facilities Opted
  bool _hasTransport = false;
  bool _hasHostel = false;
  bool _hasLibrary = false;

  // Fee schedule selected during a new admission.
  bool _assignFees = true;
  final List<_AdmissionFeeDraft> _feePlans = [];

  bool _isSaving = false;
  String? _previewStudentId;
  String? _previewAdmissionNumber;

  @override
  void initState() {
    super.initState();
    final student = widget.existingStudent?.student;

    _nameController = TextEditingController(text: student?.name ?? '');
    _addressController = TextEditingController(text: student?.address ?? '');
    _gender = student?.gender ?? 'Male';
    _dateOfBirth = student?.dateOfBirth;
    _bloodGroup = student?.bloodGroup;
    _photoPath = student?.photoPath;

    _hasTransport = student?.hasTransport ?? false;
    _hasHostel = student?.hasHostel ?? false;
    _hasLibrary = student?.hasLibrary ?? false;

    _selectedAcademicYearId = widget.existingStudent?.currentAcademicYear?.id;
    _selectedClassId = widget.existingStudent?.classId;
    _selectedSectionId = widget.existingStudent?.sectionId;
    _rollNumberController = TextEditingController(
      text: widget.existingStudent?.rollNumber?.toString() ?? '',
    );
    _admissionDate = student?.admissionDate ?? DateTime.now();

    _guardianNameController = TextEditingController();
    _guardianPhoneController = TextEditingController();
    _guardianRelationController = TextEditingController(text: 'Father');
    _guardianOccupationController = TextEditingController();

    _emergencyNameController = TextEditingController(
      text: student?.emergencyContactName ?? '',
    );
    _emergencyPhoneController = TextEditingController(
      text: student?.emergencyContactPhone ?? '',
    );
    _emergencyRelationController = TextEditingController(
      text: student?.emergencyContactRelation ?? 'Emergency Contact',
    );
    _emergencyOccupationController = TextEditingController();

    _loadPreviews();
    _loadExistingContacts();
  }

  Future<void> _loadExistingContacts() async {
    if (widget.existingStudent == null) return;
    try {
      final contactService = ref.read(contactServiceProvider);
      final contacts = await contactService.getContactsBySource(
        ContactSourceType.student,
        widget.existingStudent!.id,
      );
      if (!mounted) return;
      for (final c in contacts) {
        if (c.isPrimary ||
            (!c.isEmergency && _guardianNameController.text.isEmpty)) {
          if (_guardianNameController.text.isEmpty) {
            _guardianNameController.text = c.name;
            _guardianPhoneController.text = c.phone;
            if (c.relation != null && c.relation!.isNotEmpty) {
              _guardianRelationController.text = c.relation!;
            }
            if (c.occupation != null && c.occupation!.isNotEmpty) {
              _guardianOccupationController.text = c.occupation!;
            }
          }
        }
        if (c.isEmergency) {
          if (_emergencyNameController.text.isEmpty) {
            _emergencyNameController.text = c.name;
          }
          if (_emergencyPhoneController.text.isEmpty) {
            _emergencyPhoneController.text = c.phone;
          }
          if (c.relation != null && c.relation!.isNotEmpty) {
            _emergencyRelationController.text = c.relation!;
          }
          if (c.occupation != null && c.occupation!.isNotEmpty) {
            _emergencyOccupationController.text = c.occupation!;
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _loadPreviews() async {
    if (widget.existingStudent != null) {
      setState(() {
        _previewStudentId = widget.existingStudent!.studentId;
        _previewAdmissionNumber = widget.existingStudent!.admissionNumber;
      });
      return;
    }
    final service = ref.read(studentServiceProvider);
    final year = _admissionDate.year;
    final nextId = await service.generateNextStudentId(year);
    final nextAdm = await service.generateNextAdmissionNumber(year);
    if (mounted) {
      setState(() {
        _previewStudentId = nextId;
        _previewAdmissionNumber = nextAdm;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _rollNumberController.dispose();
    _guardianNameController.dispose();
    _guardianPhoneController.dispose();
    _guardianRelationController.dispose();
    _guardianOccupationController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    _emergencyRelationController.dispose();
    _emergencyOccupationController.dispose();
    for (final plan in _feePlans) {
      plan.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeProvider).locale.languageCode;
    final theme = Theme.of(context);
    final yearsAsync = ref.watch(academicYearsStreamProvider);
    final classesAsync = ref.watch(classesWithSectionsStreamProvider);
    final feeCategoriesAsync = ref.watch(feeCategoriesStreamProvider);
    final isEditing = widget.existingStudent != null;

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            isEditing ? Icons.edit_rounded : Icons.person_add_rounded,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Text(
            isEditing
                ? AppTranslations.text('edit_student', lang)
                : AppTranslations.text('admit_student', lang),
          ),
        ],
      ),
      content: SizedBox(
        width: 650,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ID Preview Banner
                if (_previewStudentId != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withValues(
                        alpha: 0.4,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: theme.colorScheme.primary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${AppTranslations.text("student_id", lang)}: $_previewStudentId',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        Text(
                          '${AppTranslations.text("admission_number", lang)}: $_previewAdmissionNumber',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Photo Picker & Basic Personal Info
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Photo
                    Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 104,
                            height: 104,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: theme.dividerColor.withAlpha(120),
                              ),
                            ),
                            child:
                                ImageStorageHelper.isLocalFile(_photoPath)
                                    ? Image.file(
                                      File(_photoPath!),
                                      fit: BoxFit.cover,
                                    )
                                    : Icon(
                                      Icons.person,
                                      size: 52,
                                      color: theme.colorScheme.primary
                                          .withAlpha(120),
                                    ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton.icon(
                              onPressed: () async {
                                try {
                                  final path =
                                      await ImageStorageHelper.pickAndSaveStudentPhoto(
                                        studentId:
                                            widget
                                                .existingStudent
                                                ?.student
                                                .studentId ??
                                            _previewStudentId,
                                      );
                                  if (path != null && mounted) {
                                    setState(() => _photoPath = path);
                                  }
                                } catch (error) {
                                  if (mounted) {
                                    context.showSnackbar(
                                      'Could not select student photo: $error',
                                      type: MessageType.error,
                                    );
                                  }
                                }
                              },
                              icon: const Icon(
                                Icons.camera_alt_outlined,
                                size: 15,
                              ),
                              label: Text(
                                _photoPath != null
                                    ? AppTranslations.text('change_photo', lang)
                                    : AppTranslations.text(
                                      'select_photo',
                                      lang,
                                    ),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            if (_photoPath != null) ...[
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                tooltip: 'Remove photo',
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.redAccent,
                                  size: 18,
                                ),
                                onPressed: () {
                                  setState(() => _photoPath = null);
                                },
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),

                    // Name & Gender
                    Expanded(
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Student Full Name *',
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Student name is required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: AppSearchableSelect<String>(
                                  value: _gender,
                                  label: 'Gender *',
                                  hint: 'Select Gender',
                                  items: const [
                                    SearchableSelectItem(
                                      value: 'Male',
                                      label: 'Male',
                                    ),
                                    SearchableSelectItem(
                                      value: 'Female',
                                      label: 'Female',
                                    ),
                                    SearchableSelectItem(
                                      value: 'Other',
                                      label: 'Other',
                                    ),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() => _gender = val);
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: AppSearchableSelect<String?>(
                                  value: _bloodGroup,
                                  label: AppTranslations.text(
                                    'blood_group',
                                    lang,
                                  ),
                                  hint: 'Select Blood Group',
                                  isClearable: true,
                                  items: const [
                                    SearchableSelectItem(
                                      value: null,
                                      label: 'Unknown',
                                    ),
                                    SearchableSelectItem(
                                      value: 'A+',
                                      label: 'A+',
                                    ),
                                    SearchableSelectItem(
                                      value: 'A-',
                                      label: 'A-',
                                    ),
                                    SearchableSelectItem(
                                      value: 'B+',
                                      label: 'B+',
                                    ),
                                    SearchableSelectItem(
                                      value: 'B-',
                                      label: 'B-',
                                    ),
                                    SearchableSelectItem(
                                      value: 'O+',
                                      label: 'O+',
                                    ),
                                    SearchableSelectItem(
                                      value: 'O-',
                                      label: 'O-',
                                    ),
                                    SearchableSelectItem(
                                      value: 'AB+',
                                      label: 'AB+',
                                    ),
                                    SearchableSelectItem(
                                      value: 'AB-',
                                      label: 'AB-',
                                    ),
                                  ],
                                  onChanged:
                                      (val) =>
                                          setState(() => _bloodGroup = val),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Date of birth & Address
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate:
                                _dateOfBirth ??
                                DateTime(DateTime.now().year - 10),
                            firstDate: DateTime(1990),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setState(() => _dateOfBirth = picked);
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Date of Birth',
                            suffixIcon: Icon(Icons.calendar_today, size: 18),
                          ),
                          child: Text(
                            _dateOfBirth != null
                                ? DateFormat('yyyy-MM-dd').format(_dateOfBirth!)
                                : 'Select DOB',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _addressController,
                        decoration: const InputDecoration(labelText: 'Address'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Section 2: Academic Enrollment
                Text(
                  AppTranslations.text('enrollment_info', lang),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Divider(),
                const SizedBox(height: 8),

                // Academic Year & Class
                Row(
                  children: [
                    Expanded(
                      child: yearsAsync.when(
                        data: (years) {
                          _selectedAcademicYearId ??=
                              years.where((y) => y.isCurrent).firstOrNull?.id ??
                              (years.isNotEmpty ? years.first.id : null);

                          return AppSearchableSelect<int>(
                            value: _selectedAcademicYearId,
                            label:
                                '${AppTranslations.text("academic_session", lang)} *',
                            hint: 'Select Session',
                            items:
                                years
                                    .map(
                                      (y) => SearchableSelectItem<int>(
                                        value: y.id,
                                        label:
                                            '${y.name} ${y.isCurrent ? "(Current)" : ""}',
                                      ),
                                    )
                                    .toList(),
                            onChanged:
                                (val) => setState(
                                  () => _selectedAcademicYearId = val,
                                ),
                            validator:
                                (v) => v == null ? 'Session is required' : null,
                          );
                        },
                        loading: () => const LinearProgressIndicator(),
                        error: (_, _) => const SizedBox.shrink(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: classesAsync.when(
                        data: (classes) {
                          _selectedClassId ??=
                              classes.isNotEmpty
                                  ? classes.first.schoolClass.id
                                  : null;

                          return AppSearchableSelect<int>(
                            value: _selectedClassId,
                            label: '${AppTranslations.text("class", lang)} *',
                            hint: 'Select Class',
                            items:
                                classes
                                    .map(
                                      (c) => SearchableSelectItem<int>(
                                        value: c.schoolClass.id,
                                        label: c.schoolClass.displayName,
                                      ),
                                    )
                                    .toList(),
                            onChanged: (val) {
                              setState(() {
                                _selectedClassId = val;
                                _selectedSectionId = null;
                              });
                            },
                            validator:
                                (v) => v == null ? 'Class is required' : null,
                          );
                        },
                        loading: () => const LinearProgressIndicator(),
                        error: (_, _) => const SizedBox.shrink(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Section & Roll Number
                Row(
                  children: [
                    Expanded(
                      child: classesAsync.when(
                        data: (classes) {
                          final curClass =
                              classes
                                  .where(
                                    (c) => c.schoolClass.id == _selectedClassId,
                                  )
                                  .firstOrNull;
                          final sections = curClass?.sections ?? [];

                          if (_selectedSectionId == null &&
                              sections.isNotEmpty) {
                            _selectedSectionId = sections.first.id;
                          }

                          return AppSearchableSelect<int>(
                            value: _selectedSectionId,
                            label: '${AppTranslations.text("section", lang)} *',
                            hint: 'Select Section',
                            items:
                                sections
                                    .map(
                                      (s) => SearchableSelectItem<int>(
                                        value: s.id,
                                        label: 'Section ${s.name}',
                                      ),
                                    )
                                    .toList(),
                            onChanged:
                                (val) =>
                                    setState(() => _selectedSectionId = val),
                            validator:
                                (v) => v == null ? 'Section is required' : null,
                          );
                        },
                        loading: () => const LinearProgressIndicator(),
                        error: (_, _) => const SizedBox.shrink(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _rollNumberController,
                        decoration: InputDecoration(
                          labelText: AppTranslations.text('roll_number', lang),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Facilities Opted Section
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50.withAlpha(90),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.indigo.shade100),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.room_service,
                            size: 16,
                            color: Colors.indigo,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Facilities Opted',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo.shade900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          FilterChip(
                            avatar: const Icon(Icons.directions_bus, size: 16),
                            label: const Text('Transport Facility'),
                            selected: _hasTransport,
                            selectedColor: Colors.indigo.shade100,
                            onSelected:
                                (val) => setState(() => _hasTransport = val),
                          ),
                          FilterChip(
                            avatar: const Icon(Icons.hotel, size: 16),
                            label: const Text('Hostel Facility'),
                            selected: _hasHostel,
                            selectedColor: Colors.indigo.shade100,
                            onSelected:
                                (val) => setState(() => _hasHostel = val),
                          ),
                          FilterChip(
                            avatar: const Icon(Icons.local_library, size: 16),
                            label: const Text('Library Facility'),
                            selected: _hasLibrary,
                            selectedColor: Colors.indigo.shade100,
                            onSelected:
                                (val) => setState(() => _hasLibrary = val),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Fee Schedule Section (new admissions only)
                if (!isEditing)
                  _buildAdmissionFeeSection(context, theme, feeCategoriesAsync),

                // Section 3: Guardian & Emergency Contacts
                Text(
                  AppTranslations.text('guardian_info', lang),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Divider(),
                const SizedBox(height: 8),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _guardianNameController,
                        decoration: InputDecoration(
                          labelText: AppTranslations.text(
                            'guardian_name',
                            lang,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _guardianPhoneController,
                        decoration: InputDecoration(
                          labelText: AppTranslations.text(
                            'guardian_phone',
                            lang,
                          ),
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _guardianRelationController,
                        decoration: InputDecoration(
                          labelText: AppTranslations.text(
                            'guardian_relation',
                            lang,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _guardianOccupationController,
                        decoration: InputDecoration(
                          labelText: AppTranslations.text('occupation', lang),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Emergency Contact Fields
                Text(
                  AppTranslations.text('emergency_details', lang),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Divider(),
                const SizedBox(height: 8),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _emergencyNameController,
                        decoration: InputDecoration(
                          labelText: AppTranslations.text(
                            'emergency_contact',
                            lang,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _emergencyPhoneController,
                        decoration: InputDecoration(
                          labelText: AppTranslations.text(
                            'emergency_phone',
                            lang,
                          ),
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _emergencyRelationController,
                        decoration: InputDecoration(
                          labelText: AppTranslations.text('relation', lang),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _emergencyOccupationController,
                        decoration: InputDecoration(
                          labelText: AppTranslations.text('occupation', lang),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        if (widget.existingStudent == null)
          OutlinedButton.icon(
            icon: const Icon(Icons.preview_outlined),
            label: const Text('Preview'),
            onPressed: _isSaving ? null : _showAdmissionPreview,
          ),
        TextButton(
          onPressed: _isSaving ? null : () => context.pop(),
          child: Text(AppTranslations.text('cancel', lang)),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _saveStudent,
          child:
              _isSaving
                  ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                  : Text(AppTranslations.text('save', lang)),
        ),
      ],
    );
  }

  Widget _buildAdmissionFeeSection(
    BuildContext context,
    ThemeData theme,
    AsyncValue<List<FeeCategory>> categoriesAsync,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.teal.shade50.withAlpha(110),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.teal.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long, size: 17, color: Colors.teal),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Admission Fee Schedule',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.teal.shade900,
                  ),
                ),
              ),
              Switch.adaptive(
                value: _assignFees,
                onChanged: (value) => setState(() => _assignFees = value),
              ),
            ],
          ),
          if (_assignFees) ...[
            Text(
              'Create the full academic-year schedule now. Each month or term will have its own pending/paid status.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            categoriesAsync.when(
              loading: () => const LinearProgressIndicator(),
              error:
                  (error, _) => Text('Could not load fee categories: $error'),
              data: (categories) {
                return Column(
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Fee heads',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        AppSearchablePopupMenuButton<FeeCategory>(
                          tooltip: 'Add fee category',
                          items:
                              categories
                                  .map(
                                    (
                                      category,
                                    ) => SearchableSelectItem<FeeCategory>(
                                      value: category,
                                      label: category.name,
                                      subtitle:
                                          '${category.frequency.replaceAll('_', ' ')} • Rs. ${category.defaultAmount.toStringAsFixed(2)}',
                                    ),
                                  )
                                  .toList(),
                          onSelected: (category) {
                            if (_feePlans.any(
                              (plan) => plan.category.id == category.id,
                            )) {
                              context.showSnackbar(
                                'This fee category is already selected.',
                                type: MessageType.warning,
                              );
                              return;
                            }
                            setState(
                              () => _feePlans.add(
                                _AdmissionFeeDraft.fromCategory(category),
                              ),
                            );
                          },
                          child: const Chip(
                            avatar: Icon(Icons.add, size: 16),
                            label: Text('Add fee'),
                          ),
                        ),
                      ],
                    ),
                    if (categories.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'Create fee categories in Fee Collection before assigning them here.',
                        ),
                      ),
                    ..._feePlans.asMap().entries.map(
                      (entry) => _buildAdmissionFeePlanRow(
                        context,
                        theme,
                        entry.key,
                        entry.value,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAdmissionFeePlanRow(
    BuildContext context,
    ThemeData theme,
    int index,
    _AdmissionFeeDraft plan,
  ) {
    const frequencies = <SearchableSelectItem<String>>[
      SearchableSelectItem(value: 'one_time', label: 'One-Time'),
      SearchableSelectItem(value: 'monthly', label: 'Monthly (12 records)'),
      SearchableSelectItem(value: 'quarterly', label: 'Quarterly (4 records)'),
      SearchableSelectItem(
        value: 'half_yearly',
        label: 'Half-Yearly (2 records)',
      ),
      SearchableSelectItem(value: 'yearly', label: 'Yearly (1 record)'),
      SearchableSelectItem(value: 'term_wise', label: 'Term-Wise (3 records)'),
    ];

    return Card(
      margin: const EdgeInsets.only(top: 8),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    plan.category.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  tooltip: 'Remove fee',
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () {
                    setState(() {
                      _feePlans.removeAt(index);
                      plan.dispose();
                    });
                  },
                ),
              ],
            ),
            AppSearchableSelect<String>(
              value: plan.frequency,
              label: 'Billing frequency',
              items: frequencies,
              onChanged: (value) {
                if (value != null) setState(() => plan.frequency = value);
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: plan.amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Amount per billing record',
                      prefixText: 'Rs. ',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: plan.discountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Scholarship/discount total',
                      prefixText: 'Rs. ',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAdmissionPreview() {
    final plans =
        _assignFees
            ? _feePlans.map((plan) => plan.toAdmissionFeePlan()).toList()
            : <AdmissionFeePlan>[];
    final total = plans.fold<double>(
      0,
      (sum, plan) =>
          sum + plan.amount * _admissionFeePeriodCount(plan.frequency),
    );
    final discount = plans.fold<double>(
      0,
      (sum, plan) => sum + plan.discountAmount,
    );

    showDialog<void>(
      context: context,
      builder: (previewContext) {
        final theme = Theme.of(previewContext);
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.preview_outlined, color: Colors.indigo),
              SizedBox(width: 8),
              Text('Admission Preview'),
            ],
          ),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Student details', style: theme.textTheme.titleMedium),
                  const Divider(),
                  _previewDetail('Name', _nameController.text.trim()),
                  _previewDetail('Gender', _gender),
                  _previewDetail(
                    'Date of birth',
                    _dateOfBirth == null
                        ? 'Not provided'
                        : DateFormat('yyyy-MM-dd').format(_dateOfBirth!),
                  ),
                  _previewDetail(
                    'Address',
                    _addressController.text.trim().isEmpty
                        ? 'Not provided'
                        : _addressController.text.trim(),
                  ),
                  _previewDetail(
                    'Guardian',
                    _guardianNameController.text.trim().isEmpty
                        ? 'Not provided'
                        : '${_guardianNameController.text.trim()} • ${_guardianPhoneController.text.trim()}',
                  ),
                  _previewDetail(
                    'Enrollment',
                    'Session ID: ${_selectedAcademicYearId ?? '-'} • Class ID: ${_selectedClassId ?? '-'} • Section ID: ${_selectedSectionId ?? '-'}',
                  ),
                  _previewDetail(
                    'Facilities',
                    [
                          if (_hasTransport) 'Transport',
                          if (_hasHostel) 'Hostel',
                          if (_hasLibrary) 'Library',
                        ].isEmpty
                        ? 'None'
                        : [
                          if (_hasTransport) 'Transport',
                          if (_hasHostel) 'Hostel',
                          if (_hasLibrary) 'Library',
                        ].join(', '),
                  ),
                  const SizedBox(height: 16),
                  Text('Fee structure', style: theme.textTheme.titleMedium),
                  const Divider(),
                  if (plans.isEmpty)
                    const Text('No fee records will be created.'),
                  ...plans.map(
                    (plan) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(plan.title),
                      subtitle: Text(
                        '${plan.frequency.replaceAll('_', ' ')} • ${_admissionFeePeriodCount(plan.frequency)} record(s)',
                      ),
                      trailing: Text(
                        _formatAdmissionCurrency(
                          plan.amount *
                              _admissionFeePeriodCount(plan.frequency),
                        ),
                      ),
                    ),
                  ),
                  const Divider(),
                  _previewTotalRow('Total assessed', total),
                  if (discount > 0)
                    _previewTotalRow('Scholarship / discount', -discount),
                  _previewTotalRow('Net payable', total - discount),
                  const SizedBox(height: 8),
                  Text(
                    'All generated fee records start as pending. Payments update only the selected month or term.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(previewContext),
              child: const Text('Back to Admission'),
            ),
          ],
        );
      },
    );
  }

  Widget _previewDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _previewTotalRow(String label, double amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label), Text(_formatAdmissionCurrency(amount))],
      ),
    );
  }

  String _formatAdmissionCurrency(double amount) {
    return 'Rs. ${NumberFormat('#,##0.00').format(amount)}';
  }

  int _admissionFeePeriodCount(String frequency) {
    switch (frequency.toLowerCase()) {
      case 'one_time':
      case 'yearly':
        return 1;
      case 'quarterly':
        return 4;
      case 'half_yearly':
        return 2;
      case 'term_wise':
        return 3;
      case 'monthly':
      default:
        return 12;
    }
  }

  Future<void> _saveStudent() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedAcademicYearId == null ||
        _selectedClassId == null ||
        _selectedSectionId == null) {
      context.showSnackbar(
        const SnackBar(
          content: Text('Academic Year, Class, and Section are required'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    final roll = int.tryParse(_rollNumberController.text.trim());

    if (widget.existingStudent == null) {
      // Create new admission
      final id = await ref
          .read(studentControllerProvider.notifier)
          .admitStudent(
            name: _nameController.text.trim(),
            gender: _gender,
            academicYearId: _selectedAcademicYearId!,
            classId: _selectedClassId!,
            sectionId: _selectedSectionId!,
            rollNumber: roll,
            admissionDate: _admissionDate,
            dateOfBirth: _dateOfBirth,
            bloodGroup: _bloodGroup,
            address: _addressController.text.trim(),
            photoPath: _photoPath,
            emergencyContactName: _emergencyNameController.text.trim(),
            emergencyContactPhone: _emergencyPhoneController.text.trim(),
            emergencyContactRelation: _emergencyRelationController.text.trim(),
            emergencyContactOccupation:
                _emergencyOccupationController.text.trim(),
            guardianName: _guardianNameController.text.trim(),
            guardianPhone: _guardianPhoneController.text.trim(),
            guardianRelation: _guardianRelationController.text.trim(),
            guardianOccupation: _guardianOccupationController.text.trim(),
            hasTransport: _hasTransport,
            hasHostel: _hasHostel,
            hasLibrary: _hasLibrary,
          );

      if (mounted) {
        setState(() => _isSaving = false);
        if (id != null) {
          String? feeError;
          if (_assignFees && _feePlans.isNotEmpty) {
            try {
              await ref
                  .read(feeControllerProvider.notifier)
                  .assignAdmissionFeeSchedule(
                    studentId: id,
                    academicYearId: _selectedAcademicYearId!,
                    plans:
                        _feePlans
                            .map((plan) => plan.toAdmissionFeePlan())
                            .toList(),
                    dueDate: _admissionDate,
                  );
            } catch (error) {
              feeError = error.toString();
            }
          }
          final plans =
              _assignFees
                  ? _feePlans.map((plan) => plan.toAdmissionFeePlan()).toList()
                  : <AdmissionFeePlan>[];
          context.pop(
            AdmissionCompletedData(
              studentName: _nameController.text.trim(),
              studentId: _previewStudentId ?? '-',
              admissionNumber: _previewAdmissionNumber ?? '-',
              plans: plans,
              feeError: feeError,
            ),
          );
        } else {
          context.showSnackbar(
            'Failed to admit student',
            type: MessageType.error,
          );
        }
      }
    } else {
      // Update existing student
      final success = await ref
          .read(studentControllerProvider.notifier)
          .updateStudent(
            student: widget.existingStudent!.student,
            academicYearId: _selectedAcademicYearId!,
            classId: _selectedClassId!,
            sectionId: _selectedSectionId!,
            rollNumber: roll,
            name: _nameController.text.trim(),
            gender: _gender,
            dateOfBirth: _dateOfBirth,
            bloodGroup: _bloodGroup,
            address: _addressController.text.trim(),
            phone: widget.existingStudent!.student.phone,
            email: widget.existingStudent!.student.email,
            photoPath: _photoPath,
            emergencyContactName: _emergencyNameController.text.trim(),
            emergencyContactPhone: _emergencyPhoneController.text.trim(),
            emergencyContactRelation: _emergencyRelationController.text.trim(),
            emergencyContactOccupation:
                _emergencyOccupationController.text.trim(),
            guardianName: _guardianNameController.text.trim(),
            guardianPhone: _guardianPhoneController.text.trim(),
            guardianRelation: _guardianRelationController.text.trim(),
            guardianOccupation: _guardianOccupationController.text.trim(),
            hasTransport: _hasTransport,
            hasHostel: _hasHostel,
            hasLibrary: _hasLibrary,
          );

      if (mounted) {
        setState(() => _isSaving = false);
        if (success) {
          context.pop();
          context.showSnackbar(
            const SnackBar(content: Text('Student profile updated!')),
          );
        } else {
          context.showSnackbar(
            const SnackBar(content: Text('Failed to update student')),
          );
        }
      }
    }
  }
}

// ==============================================================================
