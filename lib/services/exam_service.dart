import 'dart:convert';
import 'package:drift/drift.dart';
import '../data/app_database.dart';

/// Input data for scheduling a subject exam paper
class ExamScheduleItemInput {
  final int? id;
  final int subjectId;
  final DateTime examDate;
  final String startTime;
  final String endTime;
  final int fullMarks;
  final int passMarks;
  final int? theoryMarks;
  final int? practicalMarks;
  final int? theoryPassMarks;
  final int? practicalPassMarks;
  final String? roomNumber;
  final String? remarks;
  final int orderIndex;

  const ExamScheduleItemInput({
    this.id,
    required this.subjectId,
    required this.examDate,
    required this.startTime,
    required this.endTime,
    required this.fullMarks,
    required this.passMarks,
    this.theoryMarks,
    this.practicalMarks,
    this.theoryPassMarks,
    this.practicalPassMarks,
    this.roomNumber,
    this.remarks,
    this.orderIndex = 0,
  });
}

class ExamService {
  final AppDatabase _db;

  ExamService(this._db);

  // Standard predefined exam categories
  static const List<String> defaultCategories = [
    'Class Test 1',
    'Class Test 2',
    'Unit Test',
    'Terminal Exam 1',
    'Half Yearly',
    'Third Terminal Exam',
    'Pre-Board Exam',
    'Final Exam',
    'Other',
  ];

  // Standard exam status options
  static const List<String> statusOptions = [
    'Draft',
    'Scheduled',
    'Ongoing',
    'Completed',
    'Cancelled',
  ];

  /// Watch reactive stream of all exams with details
  Stream<List<ExamWithDetails>> watchExamsWithDetails({
    int? academicYearId,
    String? category,
    String? status,
  }) {
    return _db.watchExamsWithDetails(
      academicYearId: academicYearId,
      category: category,
      status: status,
    );
  }

  /// Get all exams with details
  Future<List<ExamWithDetails>> getAllExamsWithDetails({
    int? academicYearId,
    String? category,
    String? status,
  }) {
    return _db.getAllExamsWithDetails(
      academicYearId: academicYearId,
      category: category,
      status: status,
    );
  }

  /// Get exam with details by ID
  Future<ExamWithDetails?> getExamWithDetailsById(int id) {
    return _db.getExamWithDetailsById(id);
  }

  /// Create a new exam
  Future<int> createExam({
    required String name,
    required String category,
    required int academicYearId,
    required DateTime startDate,
    required DateTime endDate,
    String? description,
    String status = 'Scheduled',
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('Exam name is required.');
    }
    if (startDate.isAfter(endDate)) {
      throw ArgumentError('Start date cannot be after end date.');
    }

    return _db.insertExam(
      ExamsCompanion(
        name: Value(trimmedName),
        category: Value(category.trim()),
        academicYearId: Value(academicYearId),
        startDate: Value(startDate),
        endDate: Value(endDate),
        description: Value(description?.trim()),
        status: Value(status),
      ),
    );
  }

  /// Update an existing exam
  Future<bool> updateExam({
    required int id,
    required String name,
    required String category,
    required int academicYearId,
    required DateTime startDate,
    required DateTime endDate,
    String? description,
    required String status,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('Exam name is required.');
    }
    if (startDate.isAfter(endDate)) {
      throw ArgumentError('Start date cannot be after end date.');
    }

    return _db.updateExam(
      ExamsCompanion(
        id: Value(id),
        name: Value(trimmedName),
        category: Value(category.trim()),
        academicYearId: Value(academicYearId),
        startDate: Value(startDate),
        endDate: Value(endDate),
        description: Value(description?.trim()),
        status: Value(status),
      ),
    );
  }

  /// Delete an exam
  Future<int> deleteExam(int id) {
    return _db.deleteExam(id);
  }

  /// Watch reactive list of exam schedules with details
  Stream<List<ExamScheduleWithDetails>> watchExamSchedulesWithDetails({
    int? examId,
    int? classId,
    int? academicYearId,
    int? subjectId,
  }) {
    return _db.watchExamSchedulesWithDetails(
      examId: examId,
      classId: classId,
      academicYearId: academicYearId,
      subjectId: subjectId,
    );
  }

  /// Get all exam schedules with details
  Future<List<ExamScheduleWithDetails>> getAllExamSchedulesWithDetails({
    int? examId,
    int? classId,
    int? academicYearId,
    int? subjectId,
  }) {
    return _db.getAllExamSchedulesWithDetails(
      examId: examId,
      classId: classId,
      academicYearId: academicYearId,
      subjectId: subjectId,
    );
  }

  /// Save or replace subject routines for a specific class in an exam
  Future<void> saveClassExamSchedule({
    required int examId,
    required int academicYearId,
    required int classId,
    required List<ExamScheduleItemInput> items,
  }) async {
    final companions = <ExamSchedulesCompanion>[];

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      String? remarksToStore = item.remarks?.trim();
      if (item.theoryPassMarks != null || item.practicalPassMarks != null) {
        final payload = <String, dynamic>{};
        if (item.theoryPassMarks != null) {
          payload['theoryPass'] = item.theoryPassMarks;
        }
        if (item.practicalPassMarks != null) {
          payload['practicalPass'] = item.practicalPassMarks;
        }
        if (remarksToStore != null && remarksToStore.isNotEmpty) {
          payload['note'] = remarksToStore;
        }
        remarksToStore = jsonEncode(payload);
      }

      companions.add(
        ExamSchedulesCompanion(
          examId: Value(examId),
          academicYearId: Value(academicYearId),
          classId: Value(classId),
          subjectId: Value(item.subjectId),
          examDate: Value(item.examDate),
          startTime: Value(item.startTime.trim()),
          endTime: Value(item.endTime.trim()),
          fullMarks: Value(item.fullMarks),
          passMarks: Value(item.passMarks),
          theoryMarks: Value(item.theoryMarks),
          practicalMarks: Value(item.practicalMarks),
          roomNumber: Value(item.roomNumber?.trim()),
          remarks: Value(remarksToStore),
          orderIndex: Value(item.orderIndex > 0 ? item.orderIndex : i + 1),
        ),
      );
    }

    await _db.replaceClassExamSchedules(examId, classId, companions);
  }

  /// Delete a single scheduled subject paper
  Future<int> deleteExamSchedule(int id) {
    return _db.deleteExamSchedule(id);
  }

  /// Delete all schedules for a specific class in an exam
  Future<int> deleteClassSchedule(int examId, int classId) {
    return _db.deleteExamSchedulesForClass(examId, classId);
  }

  /// Retrieves all subjects that are supposed to be there for a class.
  /// First checks if subjects are configured in timetable period entries for this class.
  /// If not yet set up in timetable, falls back to all active curriculum subjects.
  Future<List<Subject>> getSubjectsForClass({
    required int classId,
    required int academicYearId,
  }) async {
    final periods = await _db.getAllPeriodsWithDetails(
      classId: classId,
      academicYearId: academicYearId,
    );

    final subjectsMap = <int, Subject>{};
    for (final p in periods) {
      if (p.subject != null) {
        subjectsMap[p.subject!.id] = p.subject!;
      }
    }

    if (subjectsMap.isNotEmpty) {
      return subjectsMap.values.toList();
    }

    // Fallback: all curriculum subjects
    return _db.getAllSubjects();
  }

  /// Creates or updates an exam along with its class subject schedules atomically
  Future<int> saveExamWithClassSchedules({
    int? examId,
    required String name,
    required String category,
    required int academicYearId,
    required int classId,
    int? sectionId,
    required DateTime startDate,
    required DateTime endDate,
    String? description,
    required String status,
    required List<ExamScheduleItemInput> schedules,
  }) async {
    final int savedExamId;
    if (examId == null) {
      savedExamId = await createExam(
        name: name,
        category: category,
        academicYearId: academicYearId,
        startDate: startDate,
        endDate: endDate,
        description: description,
        status: status,
      );
    } else {
      await updateExam(
        id: examId,
        name: name,
        category: category,
        academicYearId: academicYearId,
        startDate: startDate,
        endDate: endDate,
        description: description,
        status: status,
      );
      savedExamId = examId;
    }

    if (schedules.isNotEmpty) {
      await saveClassExamSchedule(
        examId: savedExamId,
        academicYearId: academicYearId,
        classId: classId,
        items: schedules,
      );
    }

    return savedExamId;
  }
}
