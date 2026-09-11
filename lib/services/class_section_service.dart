import 'package:drift/drift.dart';
import '../data/app_database.dart';

class ClassSectionService {
  final AppDatabase _db;

  ClassSectionService(this._db);

  /// Watch reactive stream of all classes with their sections
  Stream<List<ClassWithSections>> watchClassesWithSections() =>
      _db.watchClassesWithSections();

  /// Fetch all classes with sections once
  Future<List<ClassWithSections>> getAllClassesWithSections() =>
      _db.getAllClassesWithSections();

  /// Fetch single class with its sections by class ID
  Future<ClassWithSections?> getClassWithSectionsById(int id) =>
      _db.getClassWithSectionsById(id);

  /// Create a new class with its initial list of section names
  Future<int> createClass({
    required String name,
    required String displayName,
    int orderIndex = 0,
    List<String> sections = const [],
  }) async {
    final trimmedName = name.trim();
    final trimmedDisplayName = displayName.trim();

    if (trimmedName.isEmpty) {
      throw ArgumentError('Class name cannot be empty');
    }

    final companion = SchoolClassesCompanion(
      name: Value(trimmedName),
      displayName: Value(
        trimmedDisplayName.isEmpty ? trimmedName : trimmedDisplayName,
      ),
      orderIndex: Value(orderIndex),
    );

    return _db.insertClassWithSections(
      classCompanion: companion,
      sectionNames: sections,
    );
  }

  /// Update an existing class and synchronize its section names
  Future<void> updateClass({
    required int id,
    required String name,
    required String displayName,
    int orderIndex = 0,
    List<String> sections = const [],
  }) async {
    final trimmedName = name.trim();
    final trimmedDisplayName = displayName.trim();

    if (trimmedName.isEmpty) {
      throw ArgumentError('Class name cannot be empty');
    }

    final existing = await _db.getClassWithSectionsById(id);
    if (existing == null) {
      throw StateError('Class with ID $id not found');
    }

    final updatedClass = existing.schoolClass.copyWith(
      name: trimmedName,
      displayName:
          trimmedDisplayName.isEmpty ? trimmedName : trimmedDisplayName,
      orderIndex: orderIndex,
    );

    return _db.updateClassWithSections(
      updatedClass: updatedClass,
      sectionNames: sections,
    );
  }

  /// Delete a class and all associated sections
  Future<int> deleteClass(int id) => _db.deleteClass(id);

  /// Add a new section directly to a class
  Future<int> addSection({
    required int classId,
    required String name,
    String? roomNumber,
    int? capacity,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('Section name cannot be empty');
    }

    return _db.addSection(
      classId: classId,
      name: trimmedName,
      roomNumber: roomNumber,
      capacity: capacity,
    );
  }

  /// Delete a specific section by its ID
  Future<int> deleteSection(int sectionId) => _db.deleteSection(sectionId);
}
