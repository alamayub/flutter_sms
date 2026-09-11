import 'package:drift/drift.dart';
import '../data/app_database.dart';
import '../services/storage_service.dart';

class AcademicYearService {
  final AppDatabase _db;
  final StorageService? _storage;

  AcademicYearService(this._db, [this._storage]);

  Stream<List<AcademicYear>> watchAcademicYears() =>
      _db.watchAllAcademicYears();

  Future<List<AcademicYear>> getAllAcademicYears() => _db.getAllAcademicYears();

  Stream<AcademicYear?> watchCurrentAcademicYear() =>
      _db.watchCurrentAcademicYear();

  Future<AcademicYear?> getCurrentAcademicYear() =>
      _db.getCurrentAcademicYear();

  /// Create a new Academic Year (stores dates in AD timestamp)
  Future<int> createAcademicYear({
    required String name,
    required DateTime startDate,
    required DateTime endDate,
    bool isCurrent = false,
    String? description,
  }) async {
    if (endDate.isBefore(startDate)) {
      throw ArgumentError('End date must be after start date');
    }

    final companion = AcademicYearsCompanion(
      name: Value(name.trim()),
      startDate: Value(startDate),
      endDate: Value(endDate),
      isCurrent: Value(isCurrent),
      description: Value(description?.trim()),
    );

    final id = await _db.insertAcademicYear(companion);

    if (isCurrent && _storage != null) {
      await _storage.setActiveAcademicYearId(id);
    }

    return id;
  }

  /// Update an existing Academic Year
  Future<bool> updateAcademicYear({
    required int id,
    required String name,
    required DateTime startDate,
    required DateTime endDate,
    required bool isCurrent,
    String? description,
  }) async {
    if (endDate.isBefore(startDate)) {
      throw ArgumentError('End date must be after start date');
    }

    final existing = await _db.getAcademicYearById(id);
    if (existing == null) return false;

    final updated = existing.copyWith(
      name: name.trim(),
      startDate: startDate,
      endDate: endDate,
      isCurrent: isCurrent,
      description: Value(description?.trim()),
    );

    final success = await _db.updateAcademicYearEntry(updated);

    if (isCurrent && _storage != null) {
      await _storage.setActiveAcademicYearId(id);
    }

    return success;
  }

  /// Set the selected academic year as the active session
  Future<void> setActiveYear(int id) async {
    await _db.setActiveAcademicYear(id);
    if (_storage != null) {
      await _storage.setActiveAcademicYearId(id);
    }
  }

  /// Delete an academic year
  Future<int> deleteAcademicYear(int id) async {
    final active = await _db.getCurrentAcademicYear();
    final count = await _db.deleteAcademicYear(id);
    if (active?.id == id && _storage != null) {
      final remaining = await _db.getAllAcademicYears();
      if (remaining.isNotEmpty) {
        await setActiveYear(remaining.first.id);
      }
    }
    return count;
  }
}
