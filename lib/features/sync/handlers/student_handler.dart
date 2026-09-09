// lib/features/sync/handlers/student_handler.dart
import 'package:drift/drift.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/database/app_database.dart';
import '../client/conflict_manager.dart';
import '../domain/sync_event_model.dart';
import 'entity_sync_handler.dart';

class StudentHandler implements EntitySyncHandler {
  @override
  String get entityType => SyncEntityType.student;

  @override
  bool canHandle(String type) => type == SyncEntityType.student;

  @override
  Future<void> apply(
    SyncEventModel event,
    AppDatabase db,
    ConflictManager conflictManager,
  ) async {
    final conflictResult = await conflictManager.evaluateConflict(
      remoteEvent: event,
    );
    final p = conflictResult.mergedPayload;

    final id = event.entityId;
    final schoolId = event.schoolId;
    final existing =
        await (db.select(db.students)
          ..where((t) => t.id.equals(id))).getSingleOrNull();

    final studentCode =
        p['studentCode'] != null
            ? (p['studentCode'] as String).toUpperCase()
            : (existing?.studentCode ??
                (id.length >= 6 ? id.substring(0, 6) : id).toUpperCase());
    final firstName =
        p.containsKey('firstName')
            ? (p['firstName'] as String? ?? '')
            : (existing?.firstName ?? '');
    final middleName =
        p.containsKey('middleName')
            ? (p['middleName'] as String?)
            : existing?.middleName;
    final lastName =
        p.containsKey('lastName')
            ? (p['lastName'] as String? ?? '')
            : (existing?.lastName ?? '');
    final dateOfBirth =
        p.containsKey('dateOfBirth')
            ? (p['dateOfBirth'] != null
                ? DateTime.parse(p['dateOfBirth'] as String)
                : null)
            : existing?.dateOfBirth;
    final gender =
        p.containsKey('gender')
            ? (p['gender'] as String? ?? 'Other')
            : (existing?.gender ?? 'Other');
    final phone =
        p.containsKey('phone') ? (p['phone'] as String?) : existing?.phone;
    final address =
        p.containsKey('address')
            ? (p['address'] as String?)
            : existing?.address;
    final guardianName =
        p.containsKey('guardianName')
            ? (p['guardianName'] as String?)
            : existing?.guardianName;
    final guardianPhone =
        p.containsKey('guardianPhone')
            ? (p['guardianPhone'] as String?)
            : existing?.guardianPhone;
    final admissionDate =
        p.containsKey('admissionDate')
            ? (p['admissionDate'] != null
                ? DateTime.parse(p['admissionDate'] as String)
                : null)
            : existing?.admissionDate;
    final isActive =
        p.containsKey('isActive')
            ? (p['isActive'] as bool? ?? true)
            : (existing?.isActive ?? true);
    final isArchived =
        event.operation == SyncOperation.delete ||
        (p.containsKey('isArchived')
            ? (p['isArchived'] as bool? ?? false)
            : (existing?.isArchived ?? false));
    final archivedAt =
        p.containsKey('archivedAt')
            ? (p['archivedAt'] != null
                ? DateTime.parse(p['archivedAt'] as String)
                : null)
            : (isArchived ? (existing?.archivedAt ?? DateTime.now()) : null);
    final now = DateTime.now();

    if (existing != null) {
      await (db.update(db.students)..where((t) => t.id.equals(id))).write(
        StudentsCompanion(
          studentCode: Value(studentCode),
          firstName: Value(firstName),
          middleName: Value(middleName),
          lastName: Value(lastName),
          dateOfBirth: Value(dateOfBirth),
          gender: Value(gender),
          phone: Value(phone),
          address: Value(address),
          guardianName: Value(guardianName),
          guardianPhone: Value(guardianPhone),
          admissionDate: Value(admissionDate),
          isActive: Value(isActive),
          isArchived: Value(isArchived),
          archivedAt: Value(archivedAt),
          updatedAt: Value(now),
        ),
      );
    } else {
      await db
          .into(db.students)
          .insert(
            StudentsCompanion.insert(
              id: id,
              schoolId: schoolId,
              studentCode: studentCode,
              firstName: firstName,
              middleName: Value(middleName),
              lastName: lastName,
              dateOfBirth: Value(dateOfBirth),
              gender: Value(gender),
              phone: Value(phone),
              address: Value(address),
              guardianName: Value(guardianName),
              guardianPhone: Value(guardianPhone),
              admissionDate: Value(admissionDate),
              isActive: Value(isActive),
              isArchived: Value(isArchived),
              archivedAt: Value(archivedAt),
              createdAt: event.timestamp,
              updatedAt: now,
            ),
          );
    }
  }
}
