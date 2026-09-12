import 'package:drift/drift.dart';
import '../config/enums.dart';
import '../data/app_database.dart';

class SubjectService {
  final AppDatabase _db;

  SubjectService(this._db);

  /// Watch reactive stream of subjects
  Stream<List<Subject>> watchSubjects({SubjectType? type, bool? isOptional}) {
    return _db.watchSubjects(type: type, isOptional: isOptional);
  }

  /// Get all subjects
  Future<List<Subject>> getAllSubjects() {
    return _db.getAllSubjects();
  }

  /// Get subject by ID
  Future<Subject?> getSubjectById(int id) {
    return _db.getSubjectById(id);
  }

  /// Create a new generic subject with validation
  Future<int> createSubject({
    required String code,
    required String name,
    required SubjectType subjectType,
    bool isOptional = false,
    int fullMarks = 100,
    int passMarks = 40,
    int? theoryMarks,
    int? practicalMarks,
    String? description,
  }) async {
    final trimmedCode = code.trim();
    final trimmedName = name.trim();

    if (trimmedCode.isEmpty) {
      throw ArgumentError('Subject code cannot be empty');
    }
    if (trimmedName.isEmpty) {
      throw ArgumentError('Subject name cannot be empty');
    }
    if (passMarks > fullMarks) {
      throw ArgumentError('Pass marks cannot exceed full marks');
    }
    if (theoryMarks != null && practicalMarks != null) {
      if (theoryMarks + practicalMarks != fullMarks) {
        throw ArgumentError(
          'Theory marks and practical marks must sum to full marks',
        );
      }
    }

    final companion = SubjectsCompanion(
      code: Value(trimmedCode),
      name: Value(trimmedName),
      subjectType: Value(subjectType),
      isOptional: Value(isOptional),
      fullMarks: Value(fullMarks),
      passMarks: Value(passMarks),
      theoryMarks: Value(theoryMarks),
      practicalMarks: Value(practicalMarks),
      description: Value(description?.trim()),
    );

    return _db.insertSubject(companion);
  }

  /// Update an existing generic subject with validation
  Future<bool> updateSubject({
    required int id,
    required String code,
    required String name,
    required SubjectType subjectType,
    required bool isOptional,
    int fullMarks = 100,
    int passMarks = 40,
    int? theoryMarks,
    int? practicalMarks,
    String? description,
  }) async {
    final trimmedCode = code.trim();
    final trimmedName = name.trim();

    if (trimmedCode.isEmpty) {
      throw ArgumentError('Subject code cannot be empty');
    }
    if (trimmedName.isEmpty) {
      throw ArgumentError('Subject name cannot be empty');
    }
    if (passMarks > fullMarks) {
      throw ArgumentError('Pass marks cannot exceed full marks');
    }
    if (theoryMarks != null && practicalMarks != null) {
      if (theoryMarks + practicalMarks != fullMarks) {
        throw ArgumentError(
          'Theory marks and practical marks must sum to full marks',
        );
      }
    }

    final existing = await _db.getSubjectById(id);
    if (existing == null) return false;

    final updated = existing.copyWith(
      code: trimmedCode,
      name: trimmedName,
      subjectType: subjectType,
      isOptional: isOptional,
      fullMarks: fullMarks,
      passMarks: passMarks,
      theoryMarks: Value(theoryMarks),
      practicalMarks: Value(practicalMarks),
      description: Value(description?.trim()),
    );

    return _db.updateSubjectEntry(updated);
  }

  /// Delete a subject by ID
  Future<int> deleteSubject(int id) => _db.deleteSubject(id);
}
