import 'package:drift/drift.dart';
import '../config/enums.dart';
import '../data/app_database.dart';
import '../utils/image_storage_helper.dart';

/// Item data model for promoting an individual student
class StudentPromotionItem {
  final int studentId;
  final String studentName;
  final String studentCode;
  final int? currentRollNumber;
  final AcademicResult resultStatus;
  final bool
  isPromoted; // true = promote to target class/section, false = retain in current/retained class
  final int targetClassId;
  final int targetSectionId;
  final int? targetRollNumber;
  final String? remarks;

  const StudentPromotionItem({
    required this.studentId,
    required this.studentName,
    required this.studentCode,
    this.currentRollNumber,
    required this.resultStatus,
    required this.isPromoted,
    required this.targetClassId,
    required this.targetSectionId,
    this.targetRollNumber,
    this.remarks,
  });

  StudentPromotionItem copyWith({
    AcademicResult? resultStatus,
    bool? isPromoted,
    int? targetClassId,
    int? targetSectionId,
    int? targetRollNumber,
    String? remarks,
  }) {
    return StudentPromotionItem(
      studentId: studentId,
      studentName: studentName,
      studentCode: studentCode,
      currentRollNumber: currentRollNumber,
      resultStatus: resultStatus ?? this.resultStatus,
      isPromoted: isPromoted ?? this.isPromoted,
      targetClassId: targetClassId ?? this.targetClassId,
      targetSectionId: targetSectionId ?? this.targetSectionId,
      targetRollNumber: targetRollNumber ?? this.targetRollNumber,
      remarks: remarks ?? this.remarks,
    );
  }
}

class StudentService {
  final AppDatabase _db;

  StudentService(this._db);

  /// Watch students with full current enrollment details
  Stream<List<StudentWithDetails>> watchStudents({
    int? academicYearId,
    int? classId,
    int? sectionId,
    String? search,
  }) {
    return _db.watchStudentsWithDetails(
      academicYearId: academicYearId,
      classId: classId,
      sectionId: sectionId,
      search: search,
    );
  }

  /// Get students with full current enrollment details
  Future<List<StudentWithDetails>> getStudents({
    int? academicYearId,
    int? classId,
    int? sectionId,
    String? search,
  }) {
    return _db.getStudentsWithDetails(
      academicYearId: academicYearId,
      classId: classId,
      sectionId: sectionId,
      search: search,
    );
  }

  /// Get a single student with enrollment and class details
  Future<StudentWithDetails?> getStudentById(int id, {int? academicYearId}) {
    return _db.getStudentWithDetailsById(id, academicYearId: academicYearId);
  }

  /// Watch academic history of a student (multi-year timeline)
  Stream<List<StudentAcademicHistoryWithDetails>> watchStudentAcademicHistory(
    int studentId,
  ) {
    return _db.watchStudentAcademicHistory(studentId);
  }

  /// Get academic history of a student
  Future<List<StudentAcademicHistoryWithDetails>> getStudentAcademicHistory(
    int studentId,
  ) {
    return _db.getStudentAcademicHistory(studentId);
  }

  /// Generates the next sequential student ID in format YYYY#### (e.g. 20260001, 20260002)
  Future<String> generateNextStudentId(int year) async {
    final latestId = await _db.getLatestStudentIdForYear(year);
    if (latestId == null || latestId.length < 5) {
      return '${year}0001';
    }
    final prefix = year.toString();
    if (latestId.startsWith(prefix)) {
      final seqStr = latestId.substring(prefix.length);
      final seq = int.tryParse(seqStr);
      if (seq != null) {
        return '$prefix${(seq + 1).toString().padLeft(4, '0')}';
      }
    }
    return '${year}0001';
  }

  /// Generates next admission number in format ADM-YYYY-#### (e.g. ADM-2026-0001)
  Future<String> generateNextAdmissionNumber(int year) async {
    final latestAdm = await _db.getLatestAdmissionNumberForYear(year);
    if (latestAdm == null) {
      return 'ADM-$year-0001';
    }
    final prefix = 'ADM-$year-';
    if (latestAdm.startsWith(prefix)) {
      final seqStr = latestAdm.substring(prefix.length);
      final seq = int.tryParse(seqStr);
      if (seq != null) {
        return '$prefix${(seq + 1).toString().padLeft(4, '0')}';
      }
    }
    return 'ADM-$year-0001';
  }

  /// Admits a new student, creates initial academic history enrollment, and links guardian contacts
  Future<int> admitStudent({
    required String name,
    required String gender,
    required int academicYearId,
    required int classId,
    required int sectionId,
    int? rollNumber,
    DateTime? admissionDate,
    DateTime? dateOfBirth,
    String? bloodGroup,
    String? address,
    String? phone,
    String? email,
    String? photoPath,
    // Emergency contact
    String? emergencyContactName,
    String? emergencyContactPhone,
    String? emergencyContactRelation,
    String? emergencyContactOccupation,
    // Primary Guardian contact (for Contacts table)
    String? guardianName,
    String? guardianPhone,
    String? guardianRelation,
    String? guardianOccupation,
    // Facility Opt-ins
    bool hasTransport = false,
    bool hasHostel = false,
    bool hasLibrary = false,
  }) async {
    final date = admissionDate ?? DateTime.now();
    final year = date.year;
    final generatedStudentId = await generateNextStudentId(year);
    final generatedAdmissionNum = await generateNextAdmissionNumber(year);

    return _db.transaction(() async {
      // 1. Insert into Students table
      final studentId = await _db.insertStudent(
        StudentsCompanion(
          studentId: Value(generatedStudentId),
          admissionNumber: Value(generatedAdmissionNum),
          admissionDate: Value(date),
          name: Value(name.trim()),
          gender: Value(gender.trim()),
          dateOfBirth: Value(dateOfBirth),
          bloodGroup: Value(bloodGroup),
          address: Value(address?.trim()),
          phone: Value(phone?.trim()),
          email: Value(email?.trim()),
          photoPath: Value(photoPath),
          emergencyContactName: Value(emergencyContactName?.trim()),
          emergencyContactPhone: Value(emergencyContactPhone?.trim()),
          emergencyContactRelation: Value(emergencyContactRelation?.trim()),
          classId: Value(classId),
          sectionId: Value(sectionId),
          rollNumber: Value(rollNumber),
          hasTransport: Value(hasTransport),
          hasHostel: Value(hasHostel),
          hasLibrary: Value(hasLibrary),
          isActive: const Value(true),
        ),
      );

      // 2. Insert into StudentAcademicHistories table
      await _db.insertAcademicHistory(
        StudentAcademicHistoriesCompanion(
          studentId: Value(studentId),
          academicYearId: Value(academicYearId),
          classId: Value(classId),
          sectionId: Value(sectionId),
          rollNumber: Value(rollNumber),
          status: const Value(AcademicStatus.active),
          resultStatus: const Value(AcademicResult.pending),
          remarks: const Value('Initial Admission Enrollment'),
          enrolledAt: Value(date),
        ),
      );

      // 3. Save Primary Guardian into Contacts table
      if (guardianName != null &&
          guardianName.trim().isNotEmpty &&
          guardianPhone != null &&
          guardianPhone.trim().isNotEmpty) {
        await _db.insertContact(
          ContactsCompanion(
            sourceType: const Value(ContactSourceType.student),
            sourceId: Value(studentId),
            sourceName: Value('${name.trim()} ($generatedStudentId)'),
            name: Value(guardianName.trim()),
            phone: Value(guardianPhone.trim()),
            relation: Value(guardianRelation?.trim() ?? 'Guardian'),
            address: Value(address?.trim()),
            occupation: Value(guardianOccupation?.trim()),
            isPrimary: const Value(true),
            isEmergency: const Value(false),
          ),
        );
      }

      // 4. Save Emergency Contact into Contacts table if provided
      if (emergencyContactName != null &&
          emergencyContactName.trim().isNotEmpty &&
          emergencyContactPhone != null &&
          emergencyContactPhone.trim().isNotEmpty) {
        await _db.insertContact(
          ContactsCompanion(
            sourceType: const Value(ContactSourceType.student),
            sourceId: Value(studentId),
            sourceName: Value('${name.trim()} ($generatedStudentId)'),
            name: Value(emergencyContactName.trim()),
            phone: Value(emergencyContactPhone.trim()),
            relation: Value(
              emergencyContactRelation?.trim() ?? 'Emergency Contact',
            ),
            address: Value(address?.trim()),
            occupation: Value(emergencyContactOccupation?.trim()),
            isPrimary: const Value(false),
            isEmergency: const Value(true),
          ),
        );
      }

      return studentId;
    });
  }

  /// Updates student profile and current session enrollment
  Future<void> updateStudent({
    required Student student,
    required int academicYearId,
    required int classId,
    required int sectionId,
    int? rollNumber,
    String? name,
    String? gender,
    DateTime? dateOfBirth,
    String? bloodGroup,
    String? address,
    String? phone,
    String? email,
    String? photoPath,
    String? emergencyContactName,
    String? emergencyContactPhone,
    String? emergencyContactRelation,
    String? emergencyContactOccupation,
    String? guardianName,
    String? guardianPhone,
    String? guardianRelation,
    String? guardianOccupation,
    bool? hasTransport,
    bool? hasHostel,
    bool? hasLibrary,
    bool? isActive,
  }) async {
    await _db.transaction(() async {
      // If photo changed and old photo exists, delete old photo
      if (photoPath != null &&
          student.photoPath != null &&
          student.photoPath != photoPath) {
        await ImageStorageHelper.deleteStudentPhoto(student.photoPath);
      }

      // 1. Update Student Table
      final updatedStudent = student.copyWith(
        name: name?.trim() ?? student.name,
        gender: gender?.trim() ?? student.gender,
        dateOfBirth: Value(dateOfBirth ?? student.dateOfBirth),
        bloodGroup: Value(bloodGroup ?? student.bloodGroup),
        address: Value(address?.trim() ?? student.address),
        phone: Value(phone?.trim() ?? student.phone),
        email: Value(email?.trim() ?? student.email),
        photoPath: Value(photoPath ?? student.photoPath),
        emergencyContactName: Value(
          emergencyContactName?.trim() ?? student.emergencyContactName,
        ),
        emergencyContactPhone: Value(
          emergencyContactPhone?.trim() ?? student.emergencyContactPhone,
        ),
        emergencyContactRelation: Value(
          emergencyContactRelation?.trim() ?? student.emergencyContactRelation,
        ),
        classId: Value(classId),
        sectionId: Value(sectionId),
        rollNumber: Value(rollNumber ?? student.rollNumber),
        hasTransport: hasTransport ?? student.hasTransport,
        hasHostel: hasHostel ?? student.hasHostel,
        hasLibrary: hasLibrary ?? student.hasLibrary,
        isActive: isActive ?? student.isActive,
      );

      await _db.updateStudentEntry(updatedStudent);

      // 2. Upsert / update academic history for the session
      final existingHistory = await _db.getStudentAcademicHistoryForYear(
        student.id,
        academicYearId,
      );
      if (existingHistory != null) {
        await _db.updateAcademicHistoryEntry(
          existingHistory.copyWith(
            classId: classId,
            sectionId: sectionId,
            rollNumber: Value(rollNumber ?? existingHistory.rollNumber),
          ),
        );
      } else {
        await _db.insertAcademicHistory(
          StudentAcademicHistoriesCompanion(
            studentId: Value(student.id),
            academicYearId: Value(academicYearId),
            classId: Value(classId),
            sectionId: Value(sectionId),
            rollNumber: Value(rollNumber),
            status: const Value(AcademicStatus.active),
            resultStatus: const Value(AcademicResult.pending),
            enrolledAt: Value(DateTime.now()),
          ),
        );
      }

      // 3. Upsert / sync Primary Guardian into Contacts table
      if (guardianName != null && guardianName.trim().isNotEmpty) {
        final existingContacts = await _db.getContactsBySource(
          ContactSourceType.student,
          student.id,
        );
        final primaryContact = existingContacts.cast<Contact?>().firstWhere(
          (c) => c!.isPrimary,
          orElse: () => null,
        );
        if (primaryContact != null) {
          await _db.updateContactEntry(
            primaryContact.copyWith(
              name: guardianName.trim(),
              phone: guardianPhone?.trim() ?? primaryContact.phone,
              relation: Value(
                guardianRelation?.trim() ?? primaryContact.relation,
              ),
              occupation: Value(
                guardianOccupation?.trim() ?? primaryContact.occupation,
              ),
              address: Value(address?.trim() ?? primaryContact.address),
            ),
          );
        } else if (guardianPhone != null && guardianPhone.trim().isNotEmpty) {
          await _db.insertContact(
            ContactsCompanion(
              sourceType: const Value(ContactSourceType.student),
              sourceId: Value(student.id),
              sourceName: Value(
                '${name?.trim() ?? student.name} (${student.studentId})',
              ),
              name: Value(guardianName.trim()),
              phone: Value(guardianPhone.trim()),
              relation: Value(guardianRelation?.trim() ?? 'Guardian'),
              address: Value(address?.trim() ?? student.address),
              occupation: Value(guardianOccupation?.trim()),
              isPrimary: const Value(true),
              isEmergency: const Value(false),
            ),
          );
        }
      }

      // 4. Upsert / sync Emergency Contact into Contacts table
      if (emergencyContactName != null &&
          emergencyContactName.trim().isNotEmpty) {
        final existingContacts = await _db.getContactsBySource(
          ContactSourceType.student,
          student.id,
        );
        final emergencyContact = existingContacts.cast<Contact?>().firstWhere(
          (c) => c!.isEmergency,
          orElse: () => null,
        );
        if (emergencyContact != null) {
          await _db.updateContactEntry(
            emergencyContact.copyWith(
              name: emergencyContactName.trim(),
              phone: emergencyContactPhone?.trim() ?? emergencyContact.phone,
              relation: Value(
                emergencyContactRelation?.trim() ?? emergencyContact.relation,
              ),
              occupation: Value(
                emergencyContactOccupation?.trim() ??
                    emergencyContact.occupation,
              ),
              address: Value(address?.trim() ?? emergencyContact.address),
            ),
          );
        } else if (emergencyContactPhone != null &&
            emergencyContactPhone.trim().isNotEmpty) {
          await _db.insertContact(
            ContactsCompanion(
              sourceType: const Value(ContactSourceType.student),
              sourceId: Value(student.id),
              sourceName: Value(
                '${name?.trim() ?? student.name} (${student.studentId})',
              ),
              name: Value(emergencyContactName.trim()),
              phone: Value(emergencyContactPhone.trim()),
              relation: Value(
                emergencyContactRelation?.trim() ?? 'Emergency Contact',
              ),
              address: Value(address?.trim() ?? student.address),
              occupation: Value(emergencyContactOccupation?.trim()),
              isPrimary: const Value(false),
              isEmergency: const Value(true),
            ),
          );
        }
      }
    });
  }

  /// Deletes a student, removes their photo, associated contacts, and histories
  Future<void> deleteStudent(int id) async {
    final student = await _db.getStudentWithDetailsById(id);
    if (student?.photoPath != null) {
      await ImageStorageHelper.deleteStudentPhoto(student!.photoPath);
    }
    await _db.transaction(() async {
      // Explicitly delete academic history records
      await (_db.delete(_db.studentAcademicHistories)
        ..where((t) => t.studentId.equals(id))).go();
      // Delete contacts
      await _db.deleteContactsBySource(ContactSourceType.student, id);
      // Delete student record
      await _db.deleteStudentEntry(id);
    });
  }

  /// Promotes a batch of students from source academic year to target academic year
  /// Handles:
  /// - Status: Promoted or Retained based on user selection
  /// - Result Status: Passed or Failed
  /// - Updates student's current class/section/rollNumber
  Future<void> promoteStudents({
    required int sourceAcademicYearId,
    required int targetAcademicYearId,
    required List<StudentPromotionItem> items,
  }) async {
    await _db.transaction(() async {
      for (final item in items) {
        // 1. Update source academic year history
        final sourceHistory = await _db.getStudentAcademicHistoryForYear(
          item.studentId,
          sourceAcademicYearId,
        );

        final updatedStatus =
            item.isPromoted ? AcademicStatus.promoted : AcademicStatus.retained;

        if (sourceHistory != null) {
          await _db.updateAcademicHistoryEntry(
            sourceHistory.copyWith(
              status: updatedStatus,
              resultStatus: item.resultStatus,
              remarks: Value(item.remarks ?? sourceHistory.remarks),
            ),
          );
        }

        // 2. Check if target academic year history already exists
        final existingTargetHistory = await _db
            .getStudentAcademicHistoryForYear(
              item.studentId,
              targetAcademicYearId,
            );

        if (existingTargetHistory != null) {
          await _db.updateAcademicHistoryEntry(
            existingTargetHistory.copyWith(
              classId: item.targetClassId,
              sectionId: item.targetSectionId,
              rollNumber: Value(item.targetRollNumber),
              status: AcademicStatus.active,
              resultStatus: AcademicResult.pending,
              remarks: Value(
                item.isPromoted
                    ? 'Promoted from previous session'
                    : 'Retained from previous session',
              ),
            ),
          );
        } else {
          await _db.insertAcademicHistory(
            StudentAcademicHistoriesCompanion(
              studentId: Value(item.studentId),
              academicYearId: Value(targetAcademicYearId),
              classId: Value(item.targetClassId),
              sectionId: Value(item.targetSectionId),
              rollNumber: Value(item.targetRollNumber),
              status: const Value(AcademicStatus.active),
              resultStatus: const Value(AcademicResult.pending),
              remarks: Value(
                item.isPromoted
                    ? 'Promoted from previous session'
                    : 'Retained from previous session',
              ),
              enrolledAt: Value(DateTime.now()),
            ),
          );
        }

        // 3. Update student table's cached classId, sectionId, and rollNumber
        final student =
            await (_db.select(_db.students)
              ..where((t) => t.id.equals(item.studentId))).getSingleOrNull();

        if (student != null) {
          await _db.updateStudentEntry(
            student.copyWith(
              classId: Value(item.targetClassId),
              sectionId: Value(item.targetSectionId),
              rollNumber: Value(item.targetRollNumber),
            ),
          );
        }
      }
    });
  }
}
