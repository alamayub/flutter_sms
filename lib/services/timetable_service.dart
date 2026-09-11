import 'package:drift/drift.dart';
import '../data/app_database.dart';

class TimetableService {
  final AppDatabase _db;

  TimetableService(this._db);

  static const List<String> validDaysOfWeek = [
    'sunday',
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
  ];

  static String _validateAndNormalizeDay(String day) {
    final trimmed = day.trim().toLowerCase();
    if (!validDaysOfWeek.contains(trimmed)) {
      throw ArgumentError(
        'Invalid day of week: $day. Valid values are: ${validDaysOfWeek.join(", ")}',
      );
    }
    return trimmed;
  }

  /// Watch reactive periods stream with optional filtering
  Stream<List<PeriodWithDetails>> watchPeriodsWithDetails({
    int? academicYearId,
    int? classId,
    int? sectionId,
    String? dayOfWeek,
  }) {
    return _db.watchPeriodsWithDetails(
      academicYearId: academicYearId,
      classId: classId,
      sectionId: sectionId,
      dayOfWeek: dayOfWeek != null ? _validateAndNormalizeDay(dayOfWeek) : null,
    );
  }

  /// Get all periods with optional filtering
  Future<List<PeriodWithDetails>> getAllPeriodsWithDetails({
    int? academicYearId,
    int? classId,
    int? sectionId,
    String? dayOfWeek,
  }) {
    return _db.getAllPeriodsWithDetails(
      academicYearId: academicYearId,
      classId: classId,
      sectionId: sectionId,
      dayOfWeek: dayOfWeek != null ? _validateAndNormalizeDay(dayOfWeek) : null,
    );
  }

  /// Get a single period with details by ID
  Future<PeriodWithDetails?> getPeriodWithDetailsById(int id) {
    return _db.getPeriodWithDetailsById(id);
  }

  /// Helper to convert "HH:mm" to total minutes from midnight for validation
  static int _timeToMinutes(String time) {
    final parts = time.trim().split(':');
    if (parts.length != 2) {
      throw ArgumentError('Invalid time format: $time. Expected HH:mm');
    }
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      throw ArgumentError('Invalid time components in $time');
    }
    return hour * 60 + minute;
  }

  /// Create a new period entry
  Future<int> createPeriod({
    required int academicYearId,
    required int classId,
    int? sectionId,
    required String dayOfWeek,
    int periodNumber = 1,
    required String startTime,
    required String endTime,
    bool isBreak = false,
    String? breakTitle,
    int? subjectId,
    int? teacherId,
    String? roomNumber,
  }) async {
    final normalizedDay = _validateAndNormalizeDay(dayOfWeek);
    final startMins = _timeToMinutes(startTime);
    final endMins = _timeToMinutes(endTime);

    if (startMins >= endMins) {
      throw ArgumentError(
        'Start time ($startTime) must be before end time ($endTime)',
      );
    }

    if (!isBreak && subjectId == null) {
      throw ArgumentError('Non-break periods must have a subject selected');
    }

    if (isBreak && (breakTitle == null || breakTitle.trim().isEmpty)) {
      breakTitle = 'Break / Recess';
    }

    final companion = PeriodEntriesCompanion(
      academicYearId: Value(academicYearId),
      classId: Value(classId),
      sectionId: Value(sectionId),
      dayOfWeek: Value(normalizedDay),
      periodNumber: Value(periodNumber),
      startTime: Value(startTime.trim()),
      endTime: Value(endTime.trim()),
      isBreak: Value(isBreak),
      breakTitle: Value(breakTitle?.trim()),
      subjectId: Value(subjectId),
      teacherId: Value(teacherId),
      roomNumber: Value(roomNumber?.trim()),
    );

    return _db.insertPeriod(companion);
  }

  /// Update an existing period entry
  Future<bool> updatePeriod({
    required int id,
    required int academicYearId,
    required int classId,
    int? sectionId,
    required String dayOfWeek,
    int periodNumber = 1,
    required String startTime,
    required String endTime,
    bool isBreak = false,
    String? breakTitle,
    int? subjectId,
    int? teacherId,
    String? roomNumber,
  }) async {
    final existing = await _db.getPeriodWithDetailsById(id);
    if (existing == null) return false;

    final normalizedDay = _validateAndNormalizeDay(dayOfWeek);
    final startMins = _timeToMinutes(startTime);
    final endMins = _timeToMinutes(endTime);

    if (startMins >= endMins) {
      throw ArgumentError(
        'Start time ($startTime) must be before end time ($endTime)',
      );
    }

    if (!isBreak && subjectId == null) {
      throw ArgumentError('Non-break periods must have a subject selected');
    }

    if (isBreak && (breakTitle == null || breakTitle.trim().isEmpty)) {
      breakTitle = 'Break / Recess';
    }

    final updated = existing.period.copyWith(
      academicYearId: academicYearId,
      classId: classId,
      sectionId: Value(sectionId),
      dayOfWeek: normalizedDay,
      periodNumber: periodNumber,
      startTime: startTime.trim(),
      endTime: endTime.trim(),
      isBreak: isBreak,
      breakTitle: Value(breakTitle?.trim()),
      subjectId: Value(subjectId),
      teacherId: Value(teacherId),
      roomNumber: Value(roomNumber?.trim()),
    );

    return _db.updatePeriodEntry(updated);
  }

  /// Delete a period by ID
  Future<int> deletePeriod(int id) => _db.deletePeriod(id);

  /// Save an entire weekly schedule atomically for a class and optional section in an academic year
  Future<void> saveWeeklyTimetable({
    required int academicYearId,
    required int classId,
    int? sectionId,
    required List<WeeklyPeriodSlotInput> periods,
  }) async {
    final companions = <PeriodEntriesCompanion>[];

    for (final p in periods) {
      final normalizedDay = _validateAndNormalizeDay(p.dayOfWeek);
      final startMins = _timeToMinutes(p.startTime);
      final endMins = _timeToMinutes(p.endTime);

      if (startMins >= endMins) {
        throw ArgumentError(
          'Start time (${p.startTime}) must be before end time (${p.endTime}) for day $normalizedDay',
        );
      }

      if (!p.isBreak && p.subjectId == null) {
        throw ArgumentError(
          'Non-break period on $normalizedDay (${p.startTime}-${p.endTime}) must have a subject selected',
        );
      }

      String? breakTitle = p.breakTitle;
      if (p.isBreak && (breakTitle == null || breakTitle.trim().isEmpty)) {
        breakTitle = 'Break / Recess';
      }

      companions.add(
        PeriodEntriesCompanion(
          academicYearId: Value(academicYearId),
          classId: Value(classId),
          sectionId: Value(sectionId),
          dayOfWeek: Value(normalizedDay),
          periodNumber: Value(p.periodNumber),
          startTime: Value(p.startTime.trim()),
          endTime: Value(p.endTime.trim()),
          isBreak: Value(p.isBreak),
          breakTitle: Value(breakTitle?.trim()),
          subjectId: Value(p.isBreak ? null : p.subjectId),
          teacherId: Value(p.isBreak ? null : p.teacherId),
          roomNumber: Value(p.roomNumber?.trim()),
        ),
      );
    }

    await _db.replaceWeeklyTimetable(
      academicYearId: academicYearId,
      classId: classId,
      sectionId: sectionId,
      periods: companions,
    );
  }

  /// Clear the entire weekly schedule for a class and optional section in an academic year
  Future<int> clearWeeklyTimetable({
    required int academicYearId,
    required int classId,
    int? sectionId,
  }) {
    return _db.clearWeeklyTimetable(
      academicYearId: academicYearId,
      classId: classId,
      sectionId: sectionId,
    );
  }

  /// Copy all periods from one academic year to another (optionally scoped to a class and section)
  Future<int> copyTimetableFromYear({
    required int sourceAcademicYearId,
    required int targetAcademicYearId,
    int? classId,
    int? sectionId,
  }) async {
    final sourcePeriods = await _db.getAllPeriodsWithDetails(
      academicYearId: sourceAcademicYearId,
      classId: classId,
      sectionId: sectionId,
    );

    if (sourcePeriods.isEmpty) return 0;

    final companions =
        sourcePeriods.map((p) {
          return PeriodEntriesCompanion(
            academicYearId: Value(targetAcademicYearId),
            classId: Value(p.classId),
            sectionId: Value(p.sectionId),
            dayOfWeek: Value(p.dayOfWeek),
            periodNumber: Value(p.periodNumber),
            startTime: Value(p.startTime),
            endTime: Value(p.endTime),
            isBreak: Value(p.isBreak),
            breakTitle: Value(p.breakTitle),
            subjectId: Value(p.subjectId),
            teacherId: Value(p.teacherId),
            roomNumber: Value(p.roomNumber),
          );
        }).toList();

    int insertedCount = 0;
    for (final comp in companions) {
      await _db.insertPeriod(comp);
      insertedCount++;
    }

    return insertedCount;
  }
}

/// Data container for a single period slot in weekly timetable creation/updating
class WeeklyPeriodSlotInput {
  final String dayOfWeek;
  final int periodNumber;
  final String startTime;
  final String endTime;
  final bool isBreak;
  final String? breakTitle;
  final int? subjectId;
  final int? teacherId;
  final String? roomNumber;

  const WeeklyPeriodSlotInput({
    required this.dayOfWeek,
    this.periodNumber = 1,
    required this.startTime,
    required this.endTime,
    this.isBreak = false,
    this.breakTitle,
    this.subjectId,
    this.teacherId,
    this.roomNumber,
  });
}
