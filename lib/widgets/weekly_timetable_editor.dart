import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../config/enums.dart';
import '../config/translations.dart';
import '../data/app_database.dart';
import '../providers/employee_provider.dart';
import '../providers/subject_provider.dart';
import '../providers/timetable_provider.dart';
import '../services/timetable_service.dart';
import 'searchable_select.dart';

/// Representation of a daily time slot in the weekly schedule
class _WeeklyTimeSlot {
  final String id;
  String startTime;
  String endTime;
  int periodNumber;
  bool isBreak;
  String? breakTitle;

  _WeeklyTimeSlot({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.periodNumber,
    this.isBreak = false,
    this.breakTitle,
  });
}

/// Representation of subject, teacher, and room assigned to a specific cell
class _CellAssignment {
  int? subjectId;
  int? teacherId;
  String? roomNumber;

  _CellAssignment({this.subjectId, this.teacherId, this.roomNumber});

  bool get isEmpty =>
      subjectId == null &&
      !hasTeacher &&
      (roomNumber == null || roomNumber!.isEmpty);
  bool get hasTeacher => teacherId != null;

  _CellAssignment copyWith({
    int? subjectId,
    int? teacherId,
    String? roomNumber,
    bool clearSubject = false,
    bool clearTeacher = false,
  }) {
    return _CellAssignment(
      subjectId: clearSubject ? null : (subjectId ?? this.subjectId),
      teacherId: clearTeacher ? null : (teacherId ?? this.teacherId),
      roomNumber: roomNumber ?? this.roomNumber,
    );
  }
}

/// Full Weekly Timetable Editor Dialog
class WeeklyTimetableEditorDialog extends ConsumerStatefulWidget {
  final int academicYearId;
  final String? academicYearName;
  final int classId;
  final int? sectionId;
  final String className;
  final String? sectionName;
  final String langCode;

  const WeeklyTimetableEditorDialog({
    super.key,
    required this.academicYearId,
    this.academicYearName,
    required this.classId,
    this.sectionId,
    required this.className,
    this.sectionName,
    required this.langCode,
  });

  static Future<void> show(
    BuildContext context, {
    required int academicYearId,
    String? academicYearName,
    required int classId,
    int? sectionId,
    required String className,
    String? sectionName,
    required String langCode,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => WeeklyTimetableEditorDialog(
            academicYearId: academicYearId,
            academicYearName: academicYearName,
            classId: classId,
            sectionId: sectionId,
            className: className,
            sectionName: sectionName,
            langCode: langCode,
          ),
    );
  }

  @override
  ConsumerState<WeeklyTimetableEditorDialog> createState() =>
      _WeeklyTimetableEditorDialogState();
}

class _WeeklyTimetableEditorDialogState
    extends ConsumerState<WeeklyTimetableEditorDialog> {
  static const List<String> _schoolDays = [
    'sunday',
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
  ];

  bool _isLoading = true;
  bool _isSaving = false;

  final List<_WeeklyTimeSlot> _slots = [];
  // Map: [dayOfWeek][slotId] -> _CellAssignment
  final Map<String, Map<String, _CellAssignment>> _matrix = {};

  @override
  void initState() {
    super.initState();
    _loadExistingSchedule();
  }

  Future<void> _loadExistingSchedule() async {
    setState(() => _isLoading = true);

    try {
      final service = ref.read(timetableServiceProvider);
      final existingPeriods = await service.getAllPeriodsWithDetails(
        academicYearId: widget.academicYearId,
        classId: widget.classId,
        sectionId: widget.sectionId,
      );

      // Initialize empty day matrix
      for (final day in _schoolDays) {
        _matrix[day] = {};
      }

      if (existingPeriods.isNotEmpty) {
        // Derive unique slots ordered chronologically
        final seenSlots = <String, _WeeklyTimeSlot>{};

        for (final p in existingPeriods) {
          final slotKey = '${p.startTime}_${p.endTime}';
          if (!seenSlots.containsKey(slotKey)) {
            seenSlots[slotKey] = _WeeklyTimeSlot(
              id: slotKey,
              startTime: p.startTime,
              endTime: p.endTime,
              periodNumber: p.periodNumber,
              isBreak: p.isBreak,
              breakTitle: p.breakTitle,
            );
          }

          final day = p.dayOfWeek.toLowerCase();
          if (_matrix.containsKey(day)) {
            _matrix[day]![slotKey] = _CellAssignment(
              subjectId: p.subject?.id,
              teacherId: p.teacher?.id,
              roomNumber: p.roomNumber,
            );
          }
        }

        final sorted =
            seenSlots.values.toList()
              ..sort((a, b) => a.startTime.compareTo(b.startTime));

        _slots.clear();
        _slots.addAll(sorted);
      } else {
        // Pre-populate standard default school timetable slots
        _createDefaultSlots();
      }
    } catch (e) {
      _createDefaultSlots();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _createDefaultSlots() {
    _slots.clear();
    for (final day in _schoolDays) {
      _matrix[day] = {};
    }

    final defaultTemplate = [
      _WeeklyTimeSlot(
        id: 'slot_assembly',
        startTime: '09:30',
        endTime: '10:00',
        periodNumber: 0,
        isBreak: true,
        breakTitle: 'Morning Assembly',
      ),
      _WeeklyTimeSlot(
        id: 'slot_1',
        startTime: '10:00',
        endTime: '10:45',
        periodNumber: 1,
      ),
      _WeeklyTimeSlot(
        id: 'slot_2',
        startTime: '10:45',
        endTime: '11:30',
        periodNumber: 2,
      ),
      _WeeklyTimeSlot(
        id: 'slot_3',
        startTime: '11:30',
        endTime: '12:15',
        periodNumber: 3,
      ),
      _WeeklyTimeSlot(
        id: 'slot_4',
        startTime: '12:15',
        endTime: '13:00',
        periodNumber: 4,
      ),
      _WeeklyTimeSlot(
        id: 'slot_lunch',
        startTime: '13:00',
        endTime: '13:45',
        periodNumber: 0,
        isBreak: true,
        breakTitle: 'Tiffin / Lunch Break',
      ),
      _WeeklyTimeSlot(
        id: 'slot_5',
        startTime: '13:45',
        endTime: '14:30',
        periodNumber: 5,
      ),
      _WeeklyTimeSlot(
        id: 'slot_6',
        startTime: '14:30',
        endTime: '15:15',
        periodNumber: 6,
      ),
      _WeeklyTimeSlot(
        id: 'slot_7',
        startTime: '15:15',
        endTime: '16:00',
        periodNumber: 7,
      ),
    ];

    _slots.addAll(defaultTemplate);
  }

  int get _calculatedPeriodsCount {
    int count = 0;
    for (final day in _schoolDays) {
      for (final slot in _slots) {
        if (slot.isBreak) {
          count++;
        } else {
          final cell = _matrix[day]?[slot.id];
          if (cell != null && cell.subjectId != null) {
            count++;
          }
        }
      }
    }
    return count;
  }

  void _copySundayToWeekdays() {
    final sundayMap = _matrix['sunday'] ?? {};
    final weekdays = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday'];

    setState(() {
      for (final day in weekdays) {
        _matrix[day] ??= {};
        for (final slot in _slots) {
          if (!slot.isBreak) {
            final sunCell = sundayMap[slot.id];
            if (sunCell != null) {
              _matrix[day]![slot.id] = _CellAssignment(
                subjectId: sunCell.subjectId,
                teacherId: sunCell.teacherId,
                roomNumber: sunCell.roomNumber,
              );
            }
          }
        }
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppTranslations.text('copied_to_weekdays', widget.langCode),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _clearAllSchedule() {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(
              AppTranslations.text('clear_weekly_timetable', widget.langCode),
            ),
            content: const Text(
              'Are you sure you want to clear all assignments from this weekly timetable?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(AppTranslations.text('cancel', widget.langCode)),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  setState(() {
                    for (final day in _schoolDays) {
                      _matrix[day]?.clear();
                    }
                  });
                },
                child: const Text('Clear All'),
              ),
            ],
          ),
    );
  }

  void _addSlotDialog() {
    final startCtrl = TextEditingController(text: '16:00');
    final endCtrl = TextEditingController(text: '16:45');
    final titleCtrl = TextEditingController();
    bool isBreak = false;

    showDialog(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: Text(AppTranslations.text('add_slot', widget.langCode)),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Is Break / Recess'),
                        value: isBreak,
                        onChanged: (val) {
                          setDialogState(() => isBreak = val);
                        },
                      ),
                      if (isBreak)
                        TextField(
                          controller: titleCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Break Title',
                            hintText: 'e.g. Short Recess',
                          ),
                        ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: startCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Start Time',
                                hintText: 'HH:mm',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: endCtrl,
                              decoration: const InputDecoration(
                                labelText: 'End Time',
                                hintText: 'HH:mm',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text(
                      AppTranslations.text('cancel', widget.langCode),
                    ),
                  ),
                  FilledButton(
                    onPressed: () {
                      final start = startCtrl.text.trim();
                      final end = endCtrl.text.trim();
                      if (start.isEmpty || end.isEmpty) return;

                      final nextPeriodNum =
                          _slots.where((s) => !s.isBreak).length + 1;
                      final newSlot = _WeeklyTimeSlot(
                        id: 'slot_${DateTime.now().millisecondsSinceEpoch}',
                        startTime: start,
                        endTime: end,
                        periodNumber: isBreak ? 0 : nextPeriodNum,
                        isBreak: isBreak,
                        breakTitle:
                            isBreak
                                ? (titleCtrl.text.trim().isEmpty
                                    ? 'Break'
                                    : titleCtrl.text.trim())
                                : null,
                      );

                      setState(() {
                        _slots.add(newSlot);
                        _slots.sort(
                          (a, b) => a.startTime.compareTo(b.startTime),
                        );
                      });

                      Navigator.of(ctx).pop();
                    },
                    child: Text(AppTranslations.text('add', widget.langCode)),
                  ),
                ],
              );
            },
          ),
    );
  }

  void _editCellDialog({
    required String dayOfWeek,
    required _WeeklyTimeSlot slot,
  }) {
    final currentCell = _matrix[dayOfWeek]?[slot.id] ?? _CellAssignment();
    int? selectedSubjectId = currentCell.subjectId;
    int? selectedTeacherId = currentCell.teacherId;
    final roomCtrl = TextEditingController(text: currentCell.roomNumber ?? '');
    bool applyToAllWeekdays = false;

    showDialog(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder: (context, setDialogState) {
              final subjectsAsync = ref.watch(subjectsStreamProvider);
              final employeesAsync = ref.watch(employeesStreamProvider);

              return AlertDialog(
                title: Row(
                  children: [
                    Icon(
                      Icons.edit_calendar,
                      color: Theme.of(context).colorScheme.primary,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${AppTranslations.text(dayOfWeek, widget.langCode)} • ${slot.startTime}–${slot.endTime}',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
                content: SizedBox(
                  width: 420,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Subject Dropdown
                        subjectsAsync.when(
                          data: (subjects) {
                            final activeSubjects = subjects;
                            return AppSearchableSelect<int>(
                              value: selectedSubjectId,
                              label: AppTranslations.text(
                                'subject',
                                widget.langCode,
                              ),
                              prefixIcon: const Icon(Icons.book_outlined),
                              isClearable: true,
                              hint: '— Select Subject —',
                              items:
                                  activeSubjects.map((s) {
                                    return SearchableSelectItem<int>(
                                      value: s.id,
                                      label: '${s.name} (${s.code})',
                                    );
                                  }).toList(),
                              onChanged: (val) {
                                setDialogState(() => selectedSubjectId = val);
                              },
                            );
                          },
                          loading: () => const LinearProgressIndicator(),
                          error: (_, _) => const Text('Error loading subjects'),
                        ),
                        const SizedBox(height: 12),

                        // Teacher Dropdown
                        employeesAsync.when(
                          data: (employees) {
                            final teachers =
                                employees
                                    .where(
                                      (e) =>
                                          e.employeeType ==
                                              EmployeeType.teacher &&
                                          e.isActive,
                                    )
                                    .toList();
                            return AppSearchableSelect<int>(
                              value: selectedTeacherId,
                              label: AppTranslations.text(
                                'teacher',
                                widget.langCode,
                              ),
                              prefixIcon: const Icon(Icons.person_outline),
                              isClearable: true,
                              hint: '— Select Teacher (Optional) —',
                              items:
                                  teachers.map((t) {
                                    final codeSuffix =
                                        t.employeeCode != null
                                            ? ' [${t.employeeCode}]'
                                            : '';
                                    return SearchableSelectItem<int>(
                                      value: t.id,
                                      label: '${t.name}$codeSuffix',
                                    );
                                  }).toList(),
                              onChanged: (val) {
                                setDialogState(() => selectedTeacherId = val);
                              },
                            );
                          },
                          loading: () => const LinearProgressIndicator(),
                          error: (_, _) => const Text('Error loading teachers'),
                        ),
                        const SizedBox(height: 12),

                        // Room textfield
                        TextField(
                          controller: roomCtrl,
                          decoration: InputDecoration(
                            labelText: AppTranslations.text(
                              'room_number',
                              widget.langCode,
                            ),
                            hintText: 'e.g. Room 101, Lab 2',
                            prefixIcon: const Icon(Icons.meeting_room_outlined),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Apply to all weekdays checkbox
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Apply to all weekdays (Mon–Fri)'),
                          subtitle: const Text(
                            'Use same subject & teacher for this slot across weekdays',
                          ),
                          value: applyToAllWeekdays,
                          onChanged: (val) {
                            setDialogState(
                              () => applyToAllWeekdays = val ?? false,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  if (selectedSubjectId != null || selectedTeacherId != null)
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                      ),
                      onPressed: () {
                        setState(() {
                          _matrix[dayOfWeek]?[slot.id] = _CellAssignment();
                        });
                        Navigator.of(ctx).pop();
                      },
                      child: const Text('Clear'),
                    ),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text(
                      AppTranslations.text('cancel', widget.langCode),
                    ),
                  ),
                  FilledButton(
                    onPressed: () {
                      final room =
                          roomCtrl.text.trim().isEmpty
                              ? null
                              : roomCtrl.text.trim();
                      setState(() {
                        _matrix[dayOfWeek] ??= {};
                        _matrix[dayOfWeek]![slot.id] = _CellAssignment(
                          subjectId: selectedSubjectId,
                          teacherId: selectedTeacherId,
                          roomNumber: room,
                        );

                        if (applyToAllWeekdays) {
                          final weekdays = [
                            'monday',
                            'tuesday',
                            'wednesday',
                            'thursday',
                            'friday',
                          ];
                          for (final d in weekdays) {
                            _matrix[d] ??= {};
                            _matrix[d]![slot.id] = _CellAssignment(
                              subjectId: selectedSubjectId,
                              teacherId: selectedTeacherId,
                              roomNumber: room,
                            );
                          }
                        }
                      });
                      Navigator.of(ctx).pop();
                    },
                    child: Text(AppTranslations.text('save', widget.langCode)),
                  ),
                ],
              );
            },
          ),
    );
  }

  Future<void> _saveWeeklyTimetable() async {
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final errorColor = Theme.of(context).colorScheme.error;

    // Build the full list of inputs across the week
    final periodInputs = <WeeklyPeriodSlotInput>[];

    for (final day in _schoolDays) {
      for (final slot in _slots) {
        if (slot.isBreak) {
          periodInputs.add(
            WeeklyPeriodSlotInput(
              dayOfWeek: day,
              periodNumber: slot.periodNumber,
              startTime: slot.startTime,
              endTime: slot.endTime,
              isBreak: true,
              breakTitle: slot.breakTitle ?? 'Break / Recess',
            ),
          );
        } else {
          final cell = _matrix[day]?[slot.id];
          if (cell != null && cell.subjectId != null) {
            periodInputs.add(
              WeeklyPeriodSlotInput(
                dayOfWeek: day,
                periodNumber: slot.periodNumber,
                startTime: slot.startTime,
                endTime: slot.endTime,
                isBreak: false,
                subjectId: cell.subjectId,
                teacherId: cell.teacherId,
                roomNumber: cell.roomNumber,
              ),
            );
          }
        }
      }
    }

    setState(() => _isSaving = true);

    try {
      await ref
          .read(timetableControllerProvider.notifier)
          .saveWeeklyTimetable(
            academicYearId: widget.academicYearId,
            classId: widget.classId,
            sectionId: widget.sectionId,
            periods: periodInputs,
          );

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            AppTranslations.text('weekly_timetable_saved', widget.langCode),
          ),
          backgroundColor: Colors.green.shade700,
        ),
      );

      nav.pop();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to save weekly timetable: $e'),
          backgroundColor: errorColor,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subjectsAsync = ref.watch(subjectsStreamProvider);
    final employeesAsync = ref.watch(employeesStreamProvider);

    final subjectsMap = <int, Subject>{};
    subjectsAsync.whenData((subjects) {
      for (final s in subjects) {
        subjectsMap[s.id] = s;
      }
    });

    final teachersMap = <int, Employee>{};
    employeesAsync.whenData((employees) {
      for (final e in employees) {
        teachersMap[e.id] = e;
      }
    });

    final classSectionTitle =
        widget.sectionName != null
            ? '${widget.className} (${widget.sectionName})'
            : widget.className;
    final fullSubtitle = [
      if (widget.academicYearName != null &&
          widget.academicYearName!.isNotEmpty)
        widget.academicYearName!,
      classSectionTitle,
    ].join(' • ');

    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppTranslations.text(
                  'weekly_timetable_editor',
                  widget.langCode,
                ),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                fullSubtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          actions: [
            // Quick copy utility
            TextButton.icon(
              icon: const Icon(Icons.copy_all, size: 18),
              label: Text(
                AppTranslations.text('copy_to_weekdays', widget.langCode),
              ),
              onPressed: _copySundayToWeekdays,
            ),
            const SizedBox(width: 8),

            // Clear all
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: AppTranslations.text(
                'clear_weekly_timetable',
                widget.langCode,
              ),
              onPressed: _clearAllSchedule,
            ),
            const SizedBox(width: 8),

            // Save weekly button
            FilledButton.icon(
              icon:
                  _isSaving
                      ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                      : const Icon(Icons.check, size: 18),
              label: Text(
                '${AppTranslations.text('save', widget.langCode)} ($_calculatedPeriodsCount)',
              ),
              onPressed: _isSaving ? null : _saveWeeklyTimetable,
            ),
            const SizedBox(width: 16),
          ],
        ),
        body:
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                  children: [
                    // Slot Toolbar
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withAlpha(50),
                        border: Border(
                          bottom: BorderSide(color: theme.dividerColor),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Click on any period slot to quickly assign or change Subject and Teacher. Use "Copy Sunday to Mon–Fri" to replicate standard periods across the week.',
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.add, size: 16),
                            label: Text(
                              AppTranslations.text('add_slot', widget.langCode),
                            ),
                            onPressed: _addSlotDialog,
                          ),
                        ],
                      ),
                    ),

                    // Interactive Weekly Table
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: 960),
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(
                                theme.colorScheme.surfaceContainerHighest
                                    .withAlpha(90),
                              ),
                              dataRowMinHeight: 80,
                              dataRowMaxHeight: 96,
                              columnSpacing: 14,
                              horizontalMargin: 12,
                              columns: [
                                DataColumn(
                                  label: Text(
                                    widget.langCode == 'ne'
                                        ? 'समय / घण्टी'
                                        : 'Slot / Time',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                ..._schoolDays.map((day) {
                                  return DataColumn(
                                    label: Center(
                                      child: Text(
                                        AppTranslations.text(
                                          day,
                                          widget.langCode,
                                        ),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ],
                              rows:
                                  _slots.map((slot) {
                                    if (slot.isBreak) {
                                      return DataRow(
                                        color: WidgetStateProperty.all(
                                          Colors.amber.withAlpha(25),
                                        ),
                                        cells: [
                                          // Slot Time
                                          DataCell(
                                            _buildSlotTimeCell(theme, slot),
                                          ),
                                          // Spanned or identical break indicators across school days
                                          ..._schoolDays.map((day) {
                                            return DataCell(
                                              Container(
                                                alignment: Alignment.center,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 8,
                                                    ),
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    const Icon(
                                                      Icons.coffee_outlined,
                                                      size: 16,
                                                      color: Colors.amber,
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      slot.breakTitle ??
                                                          'Break / Recess',
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        fontSize: 12,
                                                        color: Colors.amber,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          }),
                                        ],
                                      );
                                    }

                                    return DataRow(
                                      cells: [
                                        // Slot Time Cell with delete option
                                        DataCell(
                                          _buildSlotTimeCell(theme, slot),
                                        ),

                                        // Day Cells
                                        ..._schoolDays.map((day) {
                                          final cell = _matrix[day]?[slot.id];
                                          final subject =
                                              cell?.subjectId != null
                                                  ? subjectsMap[cell!
                                                      .subjectId!]
                                                  : null;
                                          final teacher =
                                              cell?.teacherId != null
                                                  ? teachersMap[cell!
                                                      .teacherId!]
                                                  : null;

                                          return DataCell(
                                            _buildMatrixCell(
                                              theme: theme,
                                              cell: cell,
                                              subject: subject,
                                              teacher: teacher,
                                              onTap:
                                                  () => _editCellDialog(
                                                    dayOfWeek: day,
                                                    slot: slot,
                                                  ),
                                            ),
                                          );
                                        }),
                                      ],
                                    );
                                  }).toList(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
      ),
    );
  }

  Widget _buildSlotTimeCell(ThemeData theme, _WeeklyTimeSlot slot) {
    return Container(
      width: 110,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(50),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                slot.isBreak ? 'BREAK' : 'P${slot.periodNumber}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color:
                      slot.isBreak
                          ? Colors.amber.shade800
                          : theme.colorScheme.primary,
                ),
              ),
              const Spacer(),
              if (_slots.length > 1)
                InkWell(
                  onTap: () {
                    setState(() {
                      _slots.removeWhere((s) => s.id == slot.id);
                      for (final day in _schoolDays) {
                        _matrix[day]?.remove(slot.id);
                      }
                    });
                  },
                  child: Icon(Icons.close, size: 14, color: theme.dividerColor),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '${slot.startTime}–${slot.endTime}',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildMatrixCell({
    required ThemeData theme,
    required _CellAssignment? cell,
    required Subject? subject,
    required Employee? teacher,
    required VoidCallback onTap,
  }) {
    final hasSubject = subject != null;

    if (!hasSubject) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 140,
          margin: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(
              color: theme.dividerColor.withAlpha(120),
              style: BorderStyle.solid,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_circle_outline,
                  size: 16,
                  color: theme.colorScheme.primary.withAlpha(150),
                ),
                const SizedBox(width: 4),
                Text(
                  AppTranslations.text('add', widget.langCode),
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.primary.withAlpha(180),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 140,
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withAlpha(60),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.colorScheme.primary.withAlpha(80)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Subject Name
            Text(
              subject.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 2),

            // Teacher Name
            if (teacher != null)
              Row(
                children: [
                  Icon(
                    Icons.person,
                    size: 11,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Text(
                      teacher.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),

            // Room number
            if (cell?.roomNumber != null && cell!.roomNumber!.isNotEmpty)
              Text(
                cell.roomNumber!,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.secondary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
