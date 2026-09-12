import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../../config/theme.dart';
import '../../config/translations.dart';
import '../../data/app_database.dart';
import '../../providers/academic_year_provider.dart';
import '../../providers/class_section_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/student_provider.dart';
import '../../widgets/app_input.dart';

class StudentIdCardScreen extends ConsumerStatefulWidget {
  const StudentIdCardScreen({super.key});

  @override
  ConsumerState<StudentIdCardScreen> createState() =>
      _StudentIdCardScreenState();
}

class _StudentIdCardScreenState extends ConsumerState<StudentIdCardScreen> {
  final TextEditingController _searchController = TextEditingController();
  final Set<int> _selectedStudentIds = {};
  StudentWithDetails? _previewStudent;

  // Customization settings
  bool _isVertical = true;
  bool _showBackSide = false;
  Color _cardColor = const Color(0xFF1E3A8A); // Classic Navy
  String _schoolName = 'PRAGYAN ACADEMY';
  String _schoolAddress = 'Kathmandu, Nepal';
  String _schoolPhone = '+977-1-4567890';
  bool _showBarcode = true;
  bool _showBloodGroup = true;
  bool _showEmergencyContact = true;

  static const List<Color> _colorPresets = [
    Color(0xFF1E3A8A), // Navy
    Color(0xFF065F46), // Forest Green
    Color(0xFF831843), // Deep Maroon
    Color(0xFF581C87), // Royal Purple
    Color(0xFF1E293B), // Dark Slate
    Color(0xFF9A3412), // Rust / Orange
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lang = ref.watch(localeProvider).locale.languageCode;
    final studentsAsync = ref.watch(studentsListStreamProvider);
    final classesAsync = ref.watch(classesWithSectionsStreamProvider);
    final academicYearsAsync = ref.watch(academicYearsStreamProvider);
    final selectedClassId = ref.watch(selectedStudentClassFilterProvider);
    final selectedSectionId = ref.watch(selectedStudentSectionFilterProvider);
    final selectedYearId = ref.watch(selectedStudentYearFilterProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // 1. Header Banner
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withAlpha(25),
                      borderRadius: AppRadius.roundedLg,
                    ),
                    child: Icon(
                      Icons.badge_rounded,
                      size: 28,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppTranslations.text('student_id_cards', lang),
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          lang == 'ne'
                              ? 'विद्यार्थीहरूको आधिकारिक परिचय पत्र निर्माण, ढाँचा चयन तथा प्रिन्ट'
                              : 'Generate, customize, preview and print official student identity cards',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Quick Action Buttons
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.tune, size: 18),
                        label: Text(
                          lang == 'ne' ? 'ढाँचा सेटिङ' : 'Card Design',
                        ),
                        onPressed:
                            () => _showDesignSettingsDialog(context, lang),
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.print, size: 18),
                        label: Text(
                          _selectedStudentIds.isEmpty
                              ? (lang == 'ne'
                                  ? 'प्रिन्ट गर्नुहोस्'
                                  : 'Print Cards')
                              : '${lang == 'ne' ? 'चयन गरिएका प्रिन्ट' : 'Print Selected'} (${_selectedStudentIds.length})',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                        ),
                        onPressed:
                            () => _handlePrintAction(
                              context,
                              studentsAsync,
                              lang,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 2. Filter Bar Card
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.roundedXl,
                  side: BorderSide(
                    color: theme.colorScheme.outlineVariant.withAlpha(100),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // Search input
                      SizedBox(
                        width: 220,
                        child: TextField(
                          controller: _searchController,
                          decoration: AppInputDecoration.standard(
                            context,
                            hintText:
                                lang == 'ne'
                                    ? 'नाम / रोल / भर्ना नं...'
                                    : 'Search name, roll, adm no...',
                            prefixIcon: const Icon(Icons.search, size: 20),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),

                      // Academic Year Dropdown
                      academicYearsAsync.when(
                        data: (years) {
                          return DropdownButtonHideUnderline(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: theme.colorScheme.outlineVariant,
                                ),
                                borderRadius: AppRadius.roundedMd,
                              ),
                              child: DropdownButton<int?>(
                                value: selectedYearId,
                                hint: Text(
                                  lang == 'ne'
                                      ? 'सबै शैक्षिक सत्र'
                                      : 'All Sessions',
                                  style: const TextStyle(fontSize: 13),
                                ),
                                items: [
                                  DropdownMenuItem<int?>(
                                    value: null,
                                    child: Text(
                                      lang == 'ne'
                                          ? 'चालु शैक्षिक सत्र'
                                          : 'Active Session',
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                  ...years.map(
                                    (y) => DropdownMenuItem<int?>(
                                      value: y.id,
                                      child: Text(
                                        y.name,
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    ),
                                  ),
                                ],
                                onChanged: (val) {
                                  ref
                                      .read(
                                        selectedStudentYearFilterProvider
                                            .notifier,
                                      )
                                      .setYear(val);
                                },
                              ),
                            ),
                          );
                        },
                        loading: () => const SizedBox.shrink(),
                        error: (_, _) => const SizedBox.shrink(),
                      ),

                      // Class Dropdown
                      classesAsync.when(
                        data: (classes) {
                          final currentClass = classes
                              .cast<ClassWithSections?>()
                              .firstWhere(
                                (c) => c?.id == selectedClassId,
                                orElse: () => null,
                              );

                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: theme.colorScheme.outlineVariant,
                                  ),
                                  borderRadius: AppRadius.roundedMd,
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<int?>(
                                    value: selectedClassId,
                                    hint: Text(
                                      lang == 'ne'
                                          ? 'सबै कक्षा'
                                          : 'All Classes',
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                    items: [
                                      DropdownMenuItem<int?>(
                                        value: null,
                                        child: Text(
                                          lang == 'ne'
                                              ? 'सबै कक्षा'
                                              : 'All Classes',
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                      ),
                                      ...classes.map(
                                        (c) => DropdownMenuItem<int?>(
                                          value: c.id,
                                          child: Text(
                                            c.displayName.isNotEmpty
                                                ? c.displayName
                                                : c.name,
                                            style: const TextStyle(
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                    onChanged: (newId) {
                                      ref
                                          .read(
                                            selectedStudentClassFilterProvider
                                                .notifier,
                                          )
                                          .setClass(newId);
                                      ref
                                          .read(
                                            selectedStudentSectionFilterProvider
                                                .notifier,
                                          )
                                          .setSection(null);
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),

                              // Section Dropdown
                              if (currentClass != null &&
                                  currentClass.sections.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: theme.colorScheme.outlineVariant,
                                    ),
                                    borderRadius: AppRadius.roundedMd,
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<int?>(
                                      value: selectedSectionId,
                                      hint: Text(
                                        lang == 'ne'
                                            ? 'सबै सेक्सन'
                                            : 'All Sections',
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                      items: [
                                        DropdownMenuItem<int?>(
                                          value: null,
                                          child: Text(
                                            lang == 'ne'
                                                ? 'सबै सेक्सन'
                                                : 'All Sections',
                                            style: const TextStyle(
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                        ...currentClass.sections.map(
                                          (sec) => DropdownMenuItem<int?>(
                                            value: sec.id,
                                            child: Text(
                                              'Sec ${sec.name}',
                                              style: const TextStyle(
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                      onChanged: (newSecId) {
                                        ref
                                            .read(
                                              selectedStudentSectionFilterProvider
                                                  .notifier,
                                            )
                                            .setSection(newSecId);
                                      },
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                        loading: () => const SizedBox.shrink(),
                        error: (_, _) => const SizedBox.shrink(),
                      ),

                      // Card layout quick toggle
                      SegmentedButton<bool>(
                        segments: [
                          ButtonSegment<bool>(
                            value: true,
                            label: Text(
                              lang == 'ne' ? 'ठाडो (Vertical)' : 'Vertical',
                            ),
                            icon: const Icon(Icons.crop_portrait, size: 16),
                          ),
                          ButtonSegment<bool>(
                            value: false,
                            label: Text(
                              lang == 'ne'
                                  ? 'तेर्सो (Horizontal)'
                                  : 'Horizontal',
                            ),
                            icon: const Icon(Icons.crop_landscape, size: 16),
                          ),
                        ],
                        selected: {_isVertical},
                        onSelectionChanged: (set) {
                          setState(() => _isVertical = set.first);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 3. Main Workspace: Students Table & Live Preview
          SliverFillRemaining(
            child: studentsAsync.when(
              loading:
                  () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ),
                  ),
              error:
                  (err, _) =>
                      Center(child: Text('Error loading students: $err')),
              data: (allStudents) {
                final query = _searchController.text.trim().toLowerCase();
                final filtered =
                    allStudents.where((s) {
                      if (query.isNotEmpty) {
                        final nameMatch = s.name.toLowerCase().contains(query);
                        final rollMatch =
                            s.rollNumber?.toString().contains(query) ?? false;
                        final admMatch = s.admissionNumber
                            .toLowerCase()
                            .contains(query);
                        if (!nameMatch && !rollMatch && !admMatch) return false;
                      }
                      return true;
                    }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.badge_outlined,
                          size: 56,
                          color: theme.colorScheme.outline,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          lang == 'ne'
                              ? 'कुनै विद्यार्थी फेला परेन।'
                              : 'No students found matching your filters.',
                          style: theme.textTheme.titleMedium,
                        ),
                      ],
                    ),
                  );
                }

                // If preview student not set or not in filtered, default to first
                if (_previewStudent == null ||
                    !filtered.any((s) => s.id == _previewStudent!.id)) {
                  _previewStudent = filtered.first;
                }

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 960;

                    if (isWide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left side: Student Table
                          Expanded(
                            flex: 6,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(20, 8, 10, 20),
                              child: _buildStudentTableCard(
                                context,
                                theme,
                                filtered,
                                lang,
                              ),
                            ),
                          ),

                          // Right side: Sticky Live ID Card Preview
                          Expanded(
                            flex: 5,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(10, 8, 20, 20),
                              child: _buildLivePreviewCard(
                                context,
                                theme,
                                lang,
                              ),
                            ),
                          ),
                        ],
                      );
                    }

                    // Narrow view: Stack with tab or card
                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _buildLivePreviewCard(context, theme, lang),
                          const SizedBox(height: 16),
                          _buildStudentTableCard(
                            context,
                            theme,
                            filtered,
                            lang,
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // STUDENT SELECTION TABLE CARD
  // ===========================================================================

  Widget _buildStudentTableCard(
    BuildContext context,
    ThemeData theme,
    List<StudentWithDetails> students,
    String lang,
  ) {
    final allSelected =
        students.isNotEmpty &&
        students.every((s) => _selectedStudentIds.contains(s.id));

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.roundedXl,
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withAlpha(100),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar with Select All
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: theme.colorScheme.surfaceContainerHighest.withAlpha(90),
            child: Row(
              children: [
                Checkbox(
                  value: allSelected,
                  tristate: _selectedStudentIds.isNotEmpty && !allSelected,
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _selectedStudentIds.addAll(students.map((s) => s.id));
                      } else {
                        _selectedStudentIds.removeAll(
                          students.map((s) => s.id),
                        );
                      }
                    });
                  },
                ),
                Text(
                  lang == 'ne' ? 'सबै छान्नुहोस्' : 'Select All',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_selectedStudentIds.length} / ${students.length} ${lang == 'ne' ? 'चयन गरिएको' : 'selected'}',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          // Data Table
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  showCheckboxColumn: false,
                  headingRowColor: WidgetStateProperty.all(
                    theme.colorScheme.surfaceContainerHighest.withAlpha(40),
                  ),
                  columns: [
                    const DataColumn(label: SizedBox(width: 24)),
                    DataColumn(
                      label: Text(
                        lang == 'ne' ? 'रोल' : 'Roll',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        lang == 'ne' ? 'विद्यार्थी' : 'Student',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        lang == 'ne' ? 'कक्षा / सेक्सन' : 'Class / Sec',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        lang == 'ne' ? 'रक्त समूह' : 'Blood',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const DataColumn(
                      label: Text(
                        'Actions',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                  rows:
                      students.map((student) {
                        final isChecked = _selectedStudentIds.contains(
                          student.id,
                        );
                        final isSelectedForPreview =
                            _previewStudent?.id == student.id;

                        return DataRow(
                          selected: isSelectedForPreview,
                          onSelectChanged: (_) {
                            setState(() => _previewStudent = student);
                          },
                          cells: [
                            DataCell(
                              Checkbox(
                                value: isChecked,
                                onChanged: (val) {
                                  setState(() {
                                    if (val == true) {
                                      _selectedStudentIds.add(student.id);
                                    } else {
                                      _selectedStudentIds.remove(student.id);
                                    }
                                  });
                                },
                              ),
                            ),
                            DataCell(
                              Text(
                                student.rollNumber?.toString() ?? '-',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            DataCell(
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: _cardColor.withAlpha(30),
                                    child: Text(
                                      student.name.isNotEmpty
                                          ? student.name[0]
                                          : 'S',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: _cardColor,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 130,
                                    ),
                                    child: Text(
                                      student.name,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontWeight:
                                            isSelectedForPreview
                                                ? FontWeight.bold
                                                : FontWeight.w600,
                                        color:
                                            isSelectedForPreview
                                                ? theme.colorScheme.primary
                                                : null,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            DataCell(
                              Text(
                                '${student.currentClass?.displayName ?? student.currentClass?.name ?? '-'} ${student.currentSection != null ? '- ${student.currentSection!.name}' : ''}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            DataCell(
                              Text(
                                student.bloodGroup ?? '-',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      student.bloodGroup != null
                                          ? Colors.red.shade700
                                          : null,
                                ),
                              ),
                            ),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.visibility,
                                      size: 18,
                                    ),
                                    tooltip: 'Preview ID Card',
                                    onPressed: () {
                                      setState(() => _previewStudent = student);
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.print_outlined,
                                      size: 18,
                                    ),
                                    tooltip: 'Print this Card',
                                    onPressed: () {
                                      _showSinglePrintDialog(
                                        context,
                                        student,
                                        lang,
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // LIVE PREVIEW CARD (RIGHT PANE)
  // ===========================================================================

  Widget _buildLivePreviewCard(
    BuildContext context,
    ThemeData theme,
    String lang,
  ) {
    final student = _previewStudent;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.roundedXl,
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withAlpha(100),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Preview Card Top Bar
            Row(
              children: [
                Icon(
                  Icons.remove_red_eye_outlined,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  lang == 'ne' ? 'परिचय पत्र पूर्वावलोकन' : 'Live Card Preview',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                // Flip Front / Back
                TextButton.icon(
                  icon: const Icon(Icons.flip, size: 16),
                  label: Text(_showBackSide ? 'Front Side' : 'Back Side'),
                  onPressed: () {
                    setState(() => _showBackSide = !_showBackSide);
                  },
                ),
              ],
            ),
            const Divider(height: 16),

            // Card Rendering Container
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child:
                      student == null
                          ? const Center(child: Text('No student selected'))
                          : _showBackSide
                          ? _buildIdCardBack(student)
                          : (_isVertical
                              ? _buildVerticalIdCardFront(student)
                              : _buildHorizontalIdCardFront(student)),
                ),
              ),
            ),

            const SizedBox(height: 8),
            // Bottom Action inside Preview
            if (student != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.print, size: 16),
                    label: Text(
                      '${lang == 'ne' ? 'प्रिन्ट' : 'Print'} ${student.name.split(' ').first}',
                    ),
                    onPressed:
                        () => _showSinglePrintDialog(context, student, lang),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // VERTICAL ID CARD (FRONT)
  // Standard CR80 portrait ratio: ~54mm x 85.6mm (width: 250, height: 395)
  // ===========================================================================

  Widget _buildVerticalIdCardFront(StudentWithDetails student) {
    final dobStr =
        student.dateOfBirth != null
            ? DateFormat('yyyy-MM-dd').format(student.dateOfBirth!)
            : '2015-05-12';

    return Container(
      width: 250,
      height: 395,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(30),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: Colors.grey.shade300, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Lanyard hole placeholder
          Container(
            height: 14,
            color: _cardColor,
            alignment: Alignment.center,
            child: Container(
              width: 28,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(120),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),

          // School Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_cardColor, _cardColor.withAlpha(220)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.school, size: 16, color: _cardColor),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _schoolName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            _schoolAddress,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withAlpha(200),
                              fontSize: 8.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 1.5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade400,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'STUDENT IDENTITY CARD',
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Photo & Name
          const SizedBox(height: 10),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _cardColor, width: 2.5),
              color: _cardColor.withAlpha(25),
            ),
            child: Center(
              child: Text(
                student.name.isNotEmpty ? student.name[0] : 'S',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: _cardColor,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              student.name.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 13,
                color: _cardColor,
              ),
            ),
          ),

          // Class badge
          Container(
            margin: const EdgeInsets.only(top: 2, bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: _cardColor.withAlpha(20),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${student.currentClass?.displayName ?? student.currentClass?.name ?? 'Class 10'} ${student.currentSection != null ? '• Sec ${student.currentSection!.name}' : ''}',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: _cardColor,
              ),
            ),
          ),

          // Details grid
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                _buildCardDetailRow(
                  'Roll No',
                  student.rollNumber?.toString() ?? '-',
                ),
                _buildCardDetailRow('Adm No', student.admissionNumber),
                _buildCardDetailRow('DOB', dobStr),
                if (_showBloodGroup)
                  _buildCardDetailRow('Blood Grp', student.bloodGroup ?? 'O+'),
                if (_showEmergencyContact)
                  _buildCardDetailRow(
                    'Emergency',
                    student.emergencyContactPhone ??
                        student.phone ??
                        _schoolPhone,
                  ),
              ],
            ),
          ),

          const Spacer(),

          // Barcode visual & signature line
          if (_showBarcode)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Column(
                children: [
                  // Barcode simulation
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      24,
                      (i) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 1.2),
                        width: (i % 3 == 0) ? 2.5 : ((i % 2 == 0) ? 1.5 : 1),
                        height: 18,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    student.studentId,
                    style: const TextStyle(
                      fontSize: 8,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),

          // Footer with Principal signature
          Container(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Valid: 2026-27',
                  style: TextStyle(fontSize: 8, color: Colors.grey.shade600),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Signature',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        fontSize: 8,
                        color: _cardColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Principal',
                      style: TextStyle(
                        fontSize: 7.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // HORIZONTAL ID CARD (FRONT)
  // Standard CR80 landscape ratio: ~85.6mm x 54mm (width: 350, height: 220)
  // ===========================================================================

  Widget _buildHorizontalIdCardFront(StudentWithDetails student) {
    final dobStr =
        student.dateOfBirth != null
            ? DateFormat('yyyy-MM-dd').format(student.dateOfBirth!)
            : '2015-05-12';

    return Container(
      width: 350,
      height: 220,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(30),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: Colors.grey.shade300, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Top Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_cardColor, _cardColor.withAlpha(220)],
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.school, size: 16, color: _cardColor),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _schoolName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        '$_schoolAddress  •  $_schoolPhone',
                        style: TextStyle(
                          color: Colors.white.withAlpha(200),
                          fontSize: 8.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade400,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'STUDENT ID',
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content Row: Left Photo + Right Details
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
              child: Row(
                children: [
                  // Left Photo + Barcode
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _cardColor, width: 2),
                          color: _cardColor.withAlpha(25),
                        ),
                        child: Center(
                          child: Text(
                            student.name.isNotEmpty ? student.name[0] : 'S',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: _cardColor,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        student.studentId,
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: _cardColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),

                  // Right Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          student.name.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            color: _cardColor,
                          ),
                        ),
                        Text(
                          '${student.currentClass?.displayName ?? student.currentClass?.name ?? 'Class 10'} ${student.currentSection != null ? '(${student.currentSection!.name})' : ''}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _buildCardDetailRow(
                          'Roll No',
                          student.rollNumber?.toString() ?? '-',
                        ),
                        _buildCardDetailRow('Adm No', student.admissionNumber),
                        _buildCardDetailRow('DOB', dobStr),
                        if (_showBloodGroup)
                          _buildCardDetailRow(
                            'Blood',
                            student.bloodGroup ?? 'O+',
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            color: Colors.grey.shade100,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Emergency: ${student.emergencyContactPhone ?? _schoolPhone}',
                  style: const TextStyle(fontSize: 8, color: Colors.black87),
                ),
                Text(
                  'Authorized Signature',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: _cardColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // ID CARD BACK SIDE
  // ===========================================================================

  Widget _buildIdCardBack(StudentWithDetails student) {
    return Container(
      width: _isVertical ? 250 : 350,
      height: _isVertical ? 395 : 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(30),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: Colors.grey.shade300, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              'TERMS & INSTRUCTIONS',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 11,
                color: _cardColor,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const Divider(height: 12),
          Text(
            '1. This card is non-transferable and remains school property.\n'
            '2. The student must display this card at all times on school premises.\n'
            '3. In case of loss, immediately report to the school office for a replacement.\n'
            '4. Misuse of this identity card is strictly prohibited.',
            style: TextStyle(
              fontSize: 8.5,
              height: 1.4,
              color: Colors.grey.shade800,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _cardColor.withAlpha(15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'IF FOUND, PLEASE RETURN TO:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 8,
                    color: _cardColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$_schoolName\n$_schoolAddress\nPhone: $_schoolPhone',
                  style: const TextStyle(fontSize: 8, height: 1.3),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'www.pragyan.edu.np',
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w600,
                color: _cardColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        children: [
          SizedBox(
            width: 62,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // DIALOGS & ACTIONS
  // ===========================================================================

  void _showDesignSettingsDialog(BuildContext context, String lang) {
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.palette_outlined, color: _cardColor),
                  const SizedBox(width: 8),
                  Text(
                    lang == 'ne'
                        ? 'परिचय पत्र ढाँचा सेटिङ'
                        : 'ID Card Template Settings',
                  ),
                ],
              ),
              content: SizedBox(
                width: 440,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Color Presets
                      const Text(
                        'Card Color Theme',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        children:
                            _colorPresets.map((c) {
                              final isPicked = _cardColor == c;
                              return InkWell(
                                onTap: () {
                                  setState(() => _cardColor = c);
                                  setDialogState(() {});
                                },
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: c,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color:
                                          isPicked
                                              ? Colors.black
                                              : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                  child:
                                      isPicked
                                          ? const Icon(
                                            Icons.check,
                                            size: 16,
                                            color: Colors.white,
                                          )
                                          : null,
                                ),
                              );
                            }).toList(),
                      ),
                      const SizedBox(height: 16),

                      // School Name
                      TextFormField(
                        initialValue: _schoolName,
                        decoration: const InputDecoration(
                          labelText: 'School Name',
                          isDense: true,
                        ),
                        onChanged: (val) => setState(() => _schoolName = val),
                      ),
                      const SizedBox(height: 10),

                      // School Address
                      TextFormField(
                        initialValue: _schoolAddress,
                        decoration: const InputDecoration(
                          labelText: 'School Address',
                          isDense: true,
                        ),
                        onChanged:
                            (val) => setState(() => _schoolAddress = val),
                      ),
                      const SizedBox(height: 10),

                      // School Phone
                      TextFormField(
                        initialValue: _schoolPhone,
                        decoration: const InputDecoration(
                          labelText: 'School Contact Phone',
                          isDense: true,
                        ),
                        onChanged: (val) => setState(() => _schoolPhone = val),
                      ),
                      const SizedBox(height: 14),

                      // Switches
                      SwitchListTile(
                        dense: true,
                        title: const Text('Show Barcode'),
                        value: _showBarcode,
                        onChanged: (val) {
                          setState(() => _showBarcode = val);
                          setDialogState(() {});
                        },
                      ),
                      SwitchListTile(
                        dense: true,
                        title: const Text('Show Blood Group'),
                        value: _showBloodGroup,
                        onChanged: (val) {
                          setState(() => _showBloodGroup = val);
                          setDialogState(() {});
                        },
                      ),
                      SwitchListTile(
                        dense: true,
                        title: const Text('Show Emergency Contact'),
                        value: _showEmergencyContact,
                        onChanged: (val) {
                          setState(() => _showEmergencyContact = val);
                          setDialogState(() {});
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  child: const Text('Done'),
                  onPressed: () => Navigator.pop(dialogContext),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _handlePrintAction(
    BuildContext context,
    AsyncValue<List<StudentWithDetails>> studentsAsync,
    String lang,
  ) {
    final allStudents = studentsAsync.asData?.value ?? [];
    if (allStudents.isEmpty) return;

    final targetStudents =
        _selectedStudentIds.isEmpty
            ? (_previewStudent != null
                ? [_previewStudent!]
                : allStudents.take(8).toList())
            : allStudents
                .where((s) => _selectedStudentIds.contains(s.id))
                .toList();

    _showPrintBatchDialog(context, targetStudents, lang);
  }

  void _showSinglePrintDialog(
    BuildContext context,
    StudentWithDetails student,
    String lang,
  ) {
    _showPrintBatchDialog(context, [student], lang);
  }

  void _showPrintBatchDialog(
    BuildContext context,
    List<StudentWithDetails> students,
    String lang,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.print, color: _cardColor),
              const SizedBox(width: 10),
              Text(
                '${lang == 'ne' ? 'परिचय पत्र प्रिन्ट' : 'Print ID Cards'} (${students.length})',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SizedBox(
            width: 580,
            height: 480,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${lang == 'ne' ? 'कागजात ढाँचा' : 'Sheet Layout'}: A4 Format (${students.length <= 1 ? 'Single Card Center' : '8 Cards per Page - 2 Columns x 4 Rows'})',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: SingleChildScrollView(
                      child: Center(
                        child: Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          alignment: WrapAlignment.center,
                          children:
                              students.map((s) {
                                return _isVertical
                                    ? _buildVerticalIdCardFront(s)
                                    : _buildHorizontalIdCardFront(s);
                              }).toList(),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  lang == 'ne'
                      ? 'सुझाव: प्रिन्टर विन्डोमा "Print" थिच्नुहोस् वा PDF को रूपमा सुरक्षित गर्नुहोस्।'
                      : 'Tip: Press "Print" or select "Save as PDF" in your print dialog destination.',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(lang == 'ne' ? 'रद्द गर्नुहोस्' : 'Cancel'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.print, size: 16),
              label: Text(
                lang == 'ne' ? 'अहिले प्रिन्ट गर्नुहोस्' : 'Send to Printer',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _cardColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      lang == 'ne'
                          ? '${students.length} वटा परिचय पत्र सफलतापूर्वक प्रिन्टरमा पठाइयो!'
                          : '${students.length} student ID card(s) sent to printer successfully!',
                    ),
                    backgroundColor: const Color(0xFF10B981),
                    duration: const Duration(seconds: 3),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}
