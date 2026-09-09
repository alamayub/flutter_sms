// lib/features/students/data/students_repository.dart
import 'package:drift/drift.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_service.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/utils/uuid_generator.dart';
import '../../audit/data/audit_repository.dart';
import '../../sync/client/sync_engine.dart';
import '../../sync/presentation/sync_controller.dart';

final studentsRepositoryProvider = Provider<StudentsRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final audit = ref.watch(auditRepositoryProvider);
  final syncEngine = ref.watch(syncEngineProvider);
  return StudentsRepository(db, audit, syncEngine);
});

class EnrolledStudent {
  final Student student;
  final Enrollment enrollment;
  final String? className;
  final String? sectionName;

  EnrolledStudent({
    required this.student,
    required this.enrollment,
    this.className,
    this.sectionName,
  });

  String get fullName {
    if (student.middleName != null && student.middleName!.trim().isNotEmpty) {
      return '${student.firstName} ${student.middleName} ${student.lastName}';
    }
    return '${student.firstName} ${student.lastName}';
  }
}

class StudentsRepository {
  final AppDatabase _db;
  final AuditRepository _audit;
  final SyncEngine? _syncEngine;

  StudentsRepository(this._db, this._audit, [this._syncEngine]);

  /// Gets all active students for a school with optional search and pagination.
  Future<List<Student>> getStudents(
    String schoolId, {
    String? searchQuery,
    bool includeInactive = false,
    int? limit,
    int? offset,
  }) async {
    final query = _db.select(_db.students)
      ..where((t) => t.schoolId.equals(schoolId));

    if (!includeInactive) {
      query.where((t) => t.isActive.equals(true));
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final term = '%${searchQuery.trim().toLowerCase()}%';
      query.where(
        (t) =>
            t.studentCode.lower().like(term) |
            t.firstName.lower().like(term) |
            t.lastName.lower().like(term),
      );
    }

    query.orderBy([
      (t) => OrderingTerm.asc(t.firstName),
      (t) => OrderingTerm.asc(t.lastName),
    ]);

    if (limit != null) {
      query.limit(limit, offset: offset);
    }

    return await query.get();
  }

  /// Watch students stream.
  Stream<List<Student>> watchStudents(String schoolId) {
    return (_db.select(_db.students)
          ..where((t) => t.schoolId.equals(schoolId) & t.isActive.equals(true))
          ..orderBy([(t) => OrderingTerm.asc(t.firstName)]))
        .watch();
  }

  /// Gets student by ID.
  Future<Student?> getStudentById(String id) async {
    return await (_db.select(_db.students)
      ..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Creates a student within an atomic transaction.
  Future<Student> createStudent({
    required String schoolId,
    required String studentCode,
    required String firstName,
    String? middleName,
    required String lastName,
    DateTime? dateOfBirth,
    String gender = 'Other',
    String? phone,
    String? address,
    String? guardianName,
    String? guardianPhone,
    DateTime? admissionDate,
    String? currentUserId,
  }) async {
    final normalizedCode = studentCode.trim().toUpperCase();

    final existing =
        await (_db.select(_db.students)..where(
          (t) =>
              t.schoolId.equals(schoolId) &
              t.studentCode.equals(normalizedCode),
        )).getSingleOrNull();

    if (existing != null) {
      throw const ConflictException(
        'A student with this student code already exists.',
      );
    }

    final id = UuidGenerator.v4();
    final now = DateTime.now();

    await _db.transaction(() async {
      await _db
          .into(_db.students)
          .insert(
            StudentsCompanion.insert(
              id: id,
              schoolId: schoolId,
              studentCode: normalizedCode,
              firstName: firstName.trim(),
              middleName: Value(middleName?.trim()),
              lastName: lastName.trim(),
              dateOfBirth: Value(dateOfBirth),
              gender: Value(gender),
              phone: Value(phone),
              address: Value(address),
              guardianName: Value(guardianName),
              guardianPhone: Value(guardianPhone),
              admissionDate: Value(admissionDate ?? now),
              isActive: const Value(true),
              isArchived: const Value(false),
              archivedAt: const Value(null),
              createdAt: now,
              updatedAt: now,
            ),
          );

      await _audit.log(
        schoolId: schoolId,
        userId: currentUserId,
        action: AuditAction.studentCreated,
        entityType: 'Student',
        entityId: id,
        metadata: {
          'studentCode': normalizedCode,
          'name': '$firstName $lastName',
        },
      );

      if (_syncEngine != null) {
        await _syncEngine.enqueue(
          schoolId: schoolId,
          userId: currentUserId ?? 'local_user',
          entityType: SyncEntityType.student,
          entityId: id,
          operation: SyncOperation.create,
          payload: {
            'id': id,
            'schoolId': schoolId,
            'studentCode': normalizedCode,
            'firstName': firstName.trim(),
            'middleName': middleName?.trim(),
            'lastName': lastName.trim(),
            'dateOfBirth': dateOfBirth?.toIso8601String(),
            'gender': gender,
            'phone': phone,
            'address': address,
            'guardianName': guardianName,
            'guardianPhone': guardianPhone,
            'admissionDate': (admissionDate ?? now).toIso8601String(),
            'isActive': true,
            'isArchived': false,
            'createdAt': now.toIso8601String(),
            'updatedAt': now.toIso8601String(),
          },
        );
      }
    });

    return (await getStudentById(id))!;
  }

  /// Updates a student within an atomic transaction.
  Future<Student> updateStudent({
    required String id,
    required String studentCode,
    required String firstName,
    String? middleName,
    required String lastName,
    DateTime? dateOfBirth,
    String gender = 'Other',
    String? phone,
    String? address,
    String? guardianName,
    String? guardianPhone,
    DateTime? admissionDate,
    required bool isActive,
    String? currentUserId,
  }) async {
    final now = DateTime.now();

    await _db.transaction(() async {
      await (_db.update(_db.students)..where((t) => t.id.equals(id))).write(
        StudentsCompanion(
          studentCode: Value(studentCode.trim().toUpperCase()),
          firstName: Value(firstName.trim()),
          middleName: Value(middleName?.trim()),
          lastName: Value(lastName.trim()),
          dateOfBirth: Value(dateOfBirth),
          gender: Value(gender),
          phone: Value(phone),
          address: Value(address),
          guardianName: Value(guardianName),
          guardianPhone: Value(guardianPhone),
          admissionDate: Value(admissionDate),
          isActive: Value(isActive),
          updatedAt: Value(now),
        ),
      );

      await _audit.log(
        userId: currentUserId,
        action: AuditAction.studentUpdated,
        entityType: 'Student',
        entityId: id,
        metadata: {'studentCode': studentCode},
      );

      if (_syncEngine != null) {
        final s = await getStudentById(id);
        if (s != null) {
          await _syncEngine.enqueue(
            schoolId: s.schoolId,
            userId: currentUserId ?? 'local_user',
            entityType: SyncEntityType.student,
            entityId: id,
            operation: SyncOperation.update,
            payload: {
              'id': id,
              'schoolId': s.schoolId,
              'studentCode': studentCode.trim().toUpperCase(),
              'firstName': firstName.trim(),
              'middleName': middleName?.trim(),
              'lastName': lastName.trim(),
              'dateOfBirth': dateOfBirth?.toIso8601String(),
              'gender': gender,
              'phone': phone,
              'address': address,
              'guardianName': guardianName,
              'guardianPhone': guardianPhone,
              'admissionDate': admissionDate?.toIso8601String(),
              'isActive': isActive,
              'updatedAt': now.toIso8601String(),
            },
          );
        }
      }
    });

    return (await getStudentById(id))!;
  }

  /// Archives a student (soft delete) preserving historical records.
  Future<void> archiveStudent(String id, {String? currentUserId}) async {
    final now = DateTime.now();
    await _db.transaction(() async {
      await (_db.update(_db.students)..where((t) => t.id.equals(id))).write(
        StudentsCompanion(
          isActive: const Value(false),
          isArchived: const Value(true),
          archivedAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      await _audit.log(
        userId: currentUserId,
        action: 'ARCHIVE_STUDENT',
        entityType: 'Student',
        entityId: id,
      );

      if (_syncEngine != null) {
        final s = await getStudentById(id);
        if (s != null) {
          await _syncEngine.enqueue(
            schoolId: s.schoolId,
            userId: currentUserId ?? 'local_user',
            entityType: SyncEntityType.student,
            entityId: id,
            operation: SyncOperation.delete,
            payload: {
              'id': id,
              'schoolId': s.schoolId,
              'isActive': false,
              'isArchived': true,
              'archivedAt': now.toIso8601String(),
              'updatedAt': now.toIso8601String(),
            },
          );
        }
      }
    });
  }

  /// Restores an archived student.
  Future<void> restoreStudent(String id, {String? currentUserId}) async {
    final now = DateTime.now();
    await _db.transaction(() async {
      await (_db.update(_db.students)..where((t) => t.id.equals(id))).write(
        StudentsCompanion(
          isActive: const Value(true),
          isArchived: const Value(false),
          archivedAt: const Value(null),
          updatedAt: Value(now),
        ),
      );

      await _audit.log(
        userId: currentUserId,
        action: 'RESTORE_STUDENT',
        entityType: 'Student',
        entityId: id,
      );

      if (_syncEngine != null) {
        final s = await getStudentById(id);
        if (s != null) {
          await _syncEngine.enqueue(
            schoolId: s.schoolId,
            userId: currentUserId ?? 'local_user',
            entityType: SyncEntityType.student,
            entityId: id,
            operation: SyncOperation.update,
            payload: {
              'id': id,
              'schoolId': s.schoolId,
              'isActive': true,
              'isArchived': false,
              'archivedAt': null,
              'updatedAt': now.toIso8601String(),
            },
          );
        }
      }
    });
  }

  // --- ENROLLMENTS ---

  /// Enrolls a student into an academic year, class, and section.
  Future<Enrollment> enrollStudent({
    required String schoolId,
    required String studentId,
    required String academicYearId,
    required String classId,
    required String sectionId,
    int? rollNumber,
    String? currentUserId,
  }) async {
    // Check if already enrolled in this academic year
    final existing =
        await (_db.select(_db.enrollments)..where(
          (t) =>
              t.studentId.equals(studentId) &
              t.academicYearId.equals(academicYearId),
        )).getSingleOrNull();

    final now = DateTime.now();

    if (existing != null) {
      // Update existing enrollment within transaction
      await _db.transaction(() async {
        await (_db.update(_db.enrollments)
          ..where((t) => t.id.equals(existing.id))).write(
          EnrollmentsCompanion(
            classId: Value(classId),
            sectionId: Value(sectionId),
            rollNumber: Value(rollNumber),
            isActive: const Value(true),
            isArchived: const Value(false),
            archivedAt: const Value(null),
            updatedAt: Value(now),
          ),
        );
        await _audit.log(
          schoolId: schoolId,
          userId: currentUserId,
          action: AuditAction.studentEnrolled,
          entityType: 'Enrollment',
          entityId: existing.id,
          metadata: {
            'studentId': studentId,
            'classId': classId,
            'sectionId': sectionId,
            'rollNumber': rollNumber,
            'updated': true,
          },
        );

        if (_syncEngine != null) {
          await _syncEngine.enqueue(
            schoolId: schoolId,
            userId: currentUserId ?? 'local_user',
            entityType: SyncEntityType.enrollment,
            entityId: existing.id,
            operation: SyncOperation.update,
            payload: {
              'id': existing.id,
              'schoolId': schoolId,
              'studentId': studentId,
              'academicYearId': academicYearId,
              'classId': classId,
              'sectionId': sectionId,
              'rollNumber': rollNumber,
              'isActive': true,
              'isArchived': false,
              'updatedAt': now.toIso8601String(),
            },
          );
        }
      });
      return (await (_db.select(_db.enrollments)
        ..where((t) => t.id.equals(existing.id))).getSingle());
    }

    final id = UuidGenerator.v4();

    await _db.transaction(() async {
      await _db
          .into(_db.enrollments)
          .insert(
            EnrollmentsCompanion.insert(
              id: id,
              schoolId: schoolId,
              studentId: studentId,
              academicYearId: academicYearId,
              classId: classId,
              sectionId: sectionId,
              rollNumber: Value(rollNumber),
              isActive: const Value(true),
              isArchived: const Value(false),
              archivedAt: const Value(null),
              createdAt: now,
              updatedAt: now,
            ),
          );

      await _audit.log(
        schoolId: schoolId,
        userId: currentUserId,
        action: AuditAction.studentEnrolled,
        entityType: 'Enrollment',
        entityId: id,
        metadata: {
          'studentId': studentId,
          'classId': classId,
          'sectionId': sectionId,
          'rollNumber': rollNumber,
        },
      );

      if (_syncEngine != null) {
        await _syncEngine.enqueue(
          schoolId: schoolId,
          userId: currentUserId ?? 'local_user',
          entityType: SyncEntityType.enrollment,
          entityId: id,
          operation: SyncOperation.create,
          payload: {
            'id': id,
            'schoolId': schoolId,
            'studentId': studentId,
            'academicYearId': academicYearId,
            'classId': classId,
            'sectionId': sectionId,
            'rollNumber': rollNumber,
            'isActive': true,
            'isArchived': false,
            'createdAt': now.toIso8601String(),
            'updatedAt': now.toIso8601String(),
          },
        );
      }
    });

    return (await (_db.select(_db.enrollments)
      ..where((t) => t.id.equals(id))).getSingle());
  }

  /// Gets all enrolled students for a specific class and section in an academic year.
  Future<List<EnrolledStudent>> getEnrolledStudentsForSection({
    required String academicYearId,
    required String sectionId,
  }) async {
    final enrollments =
        await (_db.select(_db.enrollments)
              ..where(
                (t) =>
                    t.academicYearId.equals(academicYearId) &
                    t.sectionId.equals(sectionId) &
                    t.isActive.equals(true),
              )
              ..orderBy([(t) => OrderingTerm.asc(t.rollNumber)]))
            .get();

    final result = <EnrolledStudent>[];

    for (final en in enrollments) {
      final student =
          await (_db.select(_db.students)
            ..where((t) => t.id.equals(en.studentId))).getSingleOrNull();

      if (student == null || !student.isActive) continue;

      final section =
          await (_db.select(_db.sections)
            ..where((t) => t.id.equals(en.sectionId))).getSingleOrNull();

      final schoolClass =
          await (_db.select(_db.schoolClasses)
            ..where((t) => t.id.equals(en.classId))).getSingleOrNull();

      result.add(
        EnrolledStudent(
          student: student,
          enrollment: en,
          className: schoolClass?.name,
          sectionName: section?.name,
        ),
      );
    }

    return result;
  }

  /// Gets total student count for a school using efficient SQL count aggregation.
  Future<int> getTotalStudentCount(String schoolId) async {
    final countCol = _db.students.id.count();
    final query =
        _db.selectOnly(_db.students)
          ..addColumns([countCol])
          ..where(
            _db.students.schoolId.equals(schoolId) &
                _db.students.isActive.equals(true),
          );
    final row = await query.getSingle();
    return row.read(countCol) ?? 0;
  }
}
