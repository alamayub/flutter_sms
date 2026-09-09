// lib/features/school/data/school_repository.dart
import 'package:drift/drift.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_service.dart';
import '../../../core/utils/uuid_generator.dart';
import '../../audit/data/audit_repository.dart';

final schoolRepositoryProvider = Provider<SchoolRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final audit = ref.watch(auditRepositoryProvider);
  return SchoolRepository(db, audit);
});

class SchoolRepository {
  final AppDatabase _db;
  final AuditRepository _audit;

  SchoolRepository(this._db, this._audit);

  /// Checks if any school exists in the database.
  Future<bool> hasAnySchool() async {
    final count = await _db.schools.count().getSingle();
    return count > 0;
  }

  /// Gets the primary/active school.
  Future<School?> getActiveSchool() async {
    return await (_db.select(_db.schools)..limit(1)).getSingleOrNull();
  }

  /// Watches the active school.
  Stream<School?> watchActiveSchool() {
    return (_db.select(_db.schools)..limit(1)).watchSingleOrNull();
  }

  /// Gets a school by ID.
  Future<School?> getSchoolById(String id) async {
    return await (_db.select(_db.schools)
      ..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Creates a new school.
  Future<School> createSchool({
    required String name,
    String? shortName,
    String? address,
    String? phone,
    String? email,
    String? website,
    String? logo,
    String? principalName,
    String? createdByUserId,
  }) async {
    final now = DateTime.now();
    final id = UuidGenerator.v4();

    final companion = SchoolsCompanion.insert(
      id: id,
      name: name,
      shortName: Value(shortName),
      address: Value(address),
      phone: Value(phone),
      email: Value(email),
      website: Value(website),
      logo: Value(logo),
      principalName: Value(principalName),
      createdAt: now,
      updatedAt: now,
    );

    await _db.into(_db.schools).insert(companion);

    await _audit.log(
      schoolId: id,
      userId: createdByUserId,
      action: AuditAction.schoolCreated,
      entityType: 'School',
      entityId: id,
      metadata: {'name': name, 'principalName': principalName},
    );

    return (await getSchoolById(id))!;
  }

  /// Updates an existing school.
  Future<School> updateSchool({
    required String id,
    required String name,
    String? shortName,
    String? address,
    String? phone,
    String? email,
    String? website,
    String? logo,
    String? principalName,
    String? updatedByUserId,
  }) async {
    final now = DateTime.now();

    final companion = SchoolsCompanion(
      name: Value(name),
      shortName: Value(shortName),
      address: Value(address),
      phone: Value(phone),
      email: Value(email),
      website: Value(website),
      logo: Value(logo),
      principalName: Value(principalName),
      updatedAt: Value(now),
    );

    await (_db.update(_db.schools)
      ..where((t) => t.id.equals(id))).write(companion);

    await _audit.log(
      schoolId: id,
      userId: updatedByUserId,
      action: AuditAction.schoolUpdated,
      entityType: 'School',
      entityId: id,
      metadata: {'name': name},
    );

    return (await getSchoolById(id))!;
  }
}
