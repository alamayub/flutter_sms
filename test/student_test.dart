import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sms/config/enums.dart';
import 'package:sms/data/app_database.dart';
import 'package:sms/services/student_service.dart';

void main() {
  late AppDatabase db;
  late StudentService service;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    service = StudentService(db);
    // Clear pre-seeded students, histories, and contacts for clean test isolation
    await db.customStatement('DELETE FROM student_academic_histories;');
    await db.customStatement('DELETE FROM contacts;');
    await db.customStatement('DELETE FROM students;');
  });

  tearDown(() async {
    await db.close();
  });

  group('Student ID & Admission Number Generation', () {
    test('generates first student ID for the year (YYYY0001)', () async {
      final id = await service.generateNextStudentId(2026);
      expect(id, '20260001');
    });

    test('generates sequential student IDs for the year', () async {
      final year = await db.getCurrentAcademicYear();
      final classes = await db.getAllClassesWithSections();
      final class1 = classes.first;
      final sec1 = class1.sections.first;

      await service.admitStudent(
        name: 'Student One',
        gender: 'Male',
        academicYearId: year!.id,
        classId: class1.id,
        sectionId: sec1.id,
        admissionDate: DateTime(2026, 4, 15),
      );

      final nextId = await service.generateNextStudentId(2026);
      expect(nextId, '20260002');
    });

    test(
      'generates first admission number (ADM-YYYY-0001) and increments',
      () async {
        final adm1 = await service.generateNextAdmissionNumber(2026);
        expect(adm1, 'ADM-2026-0001');

        final year = await db.getCurrentAcademicYear();
        final classes = await db.getAllClassesWithSections();
        final class1 = classes.first;
        final sec1 = class1.sections.first;

        await service.admitStudent(
          name: 'Student One',
          gender: 'Female',
          academicYearId: year!.id,
          classId: class1.id,
          sectionId: sec1.id,
          admissionDate: DateTime(2026, 4, 15),
        );

        final adm2 = await service.generateNextAdmissionNumber(2026);
        expect(adm2, 'ADM-2026-0002');
      },
    );
  });

  group('Student Admission & Contacts Integration', () {
    test(
      'admits student with complete profile and creates enrollment history',
      () async {
        final year = await db.getCurrentAcademicYear();
        final classes = await db.getAllClassesWithSections();
        final class1 = classes.first;
        final sec1 = class1.sections.first;

        final studentId = await service.admitStudent(
          name: 'Suman Thapa',
          gender: 'Male',
          academicYearId: year!.id,
          classId: class1.id,
          sectionId: sec1.id,
          rollNumber: 10,
          admissionDate: DateTime(2026, 4, 15),
          dateOfBirth: DateTime(2012, 5, 20),
          bloodGroup: 'B+',
          address: 'Baluwatar, Kathmandu',
          phone: '9841999888',
          email: 'suman@example.com',
          emergencyContactName: 'Bikram Thapa',
          emergencyContactPhone: '9841111222',
          emergencyContactRelation: 'Uncle',
          emergencyContactOccupation: 'Civil Engineer',
          guardianName: 'Hari Thapa',
          guardianPhone: '9841333444',
          guardianRelation: 'Father',
          guardianOccupation: 'Accountant',
        );

        expect(studentId, isPositive);

        final studentWithDetails = await service.getStudentById(
          studentId,
          academicYearId: year.id,
        );
        expect(studentWithDetails, isNotNull);
        expect(studentWithDetails!.name, 'Suman Thapa');
        expect(studentWithDetails.studentId, '20260001');
        expect(studentWithDetails.admissionNumber, 'ADM-2026-0001');
        expect(studentWithDetails.bloodGroup, 'B+');
        expect(studentWithDetails.rollNumber, 10);
        expect(studentWithDetails.currentClass?.id, class1.id);
        expect(studentWithDetails.currentSection?.id, sec1.id);

        // Verify academic history
        final history = await service.getStudentAcademicHistory(studentId);
        expect(history.length, 1);
        expect(history.first.academicYear.id, year.id);
        expect(history.first.schoolClass.id, class1.id);
        expect(history.first.section.id, sec1.id);
        expect(history.first.rollNumber, 10);
        expect(history.first.status, AcademicStatus.active);
        expect(history.first.resultStatus, AcademicResult.pending);

        // Verify contacts automatically created in generic Contacts table
        final contacts = await db.getContactsBySource(
          ContactSourceType.student,
          studentId,
        );
        expect(contacts.length, 2); // Guardian + Emergency Contact

        final guardian = contacts.firstWhere((c) => c.isPrimary);
        expect(guardian.name, 'Hari Thapa');
        expect(guardian.phone, '9841333444');
        expect(guardian.relation, 'Father');
        expect(guardian.occupation, 'Accountant');

        final emergency = contacts.firstWhere((c) => c.isEmergency);
        expect(emergency.name, 'Bikram Thapa');
        expect(emergency.phone, '9841111222');
        expect(emergency.relation, 'Uncle');
        expect(emergency.occupation, 'Civil Engineer');
      },
    );

    test(
      'updates student guardian and emergency contacts in Contacts table',
      () async {
        final year = await db.getCurrentAcademicYear();
        final classes = await db.getAllClassesWithSections();
        final class1 = classes.first;
        final sec1 = class1.sections.first;

        final studentId = await service.admitStudent(
          name: 'Initial Name',
          gender: 'Male',
          academicYearId: year!.id,
          classId: class1.id,
          sectionId: sec1.id,
          guardianName: 'Old Guardian',
          guardianPhone: '9841111111',
          guardianRelation: 'Father',
          guardianOccupation: 'Teacher',
          emergencyContactName: 'Old Emergency',
          emergencyContactPhone: '9842222222',
          emergencyContactRelation: 'Friend',
          emergencyContactOccupation: 'Doctor',
        );

        final studentWithDetails = await service.getStudentById(studentId);
        expect(studentWithDetails, isNotNull);

        // Now update the student with new guardian and emergency info
        await service.updateStudent(
          student: studentWithDetails!.student,
          academicYearId: year.id,
          classId: class1.id,
          sectionId: sec1.id,
          name: 'Updated Name',
          guardianName: 'New Guardian',
          guardianPhone: '9843333333',
          guardianRelation: 'Mother',
          guardianOccupation: 'Banker',
          emergencyContactName: 'New Emergency',
          emergencyContactPhone: '9844444444',
          emergencyContactRelation: 'Aunt',
          emergencyContactOccupation: 'Professor',
        );

        final updatedContacts = await db.getContactsBySource(
          ContactSourceType.student,
          studentId,
        );
        expect(updatedContacts.length, 2);

        final guardian = updatedContacts.firstWhere((c) => c.isPrimary);
        expect(guardian.name, 'New Guardian');
        expect(guardian.phone, '9843333333');
        expect(guardian.relation, 'Mother');
        expect(guardian.occupation, 'Banker');

        final emergency = updatedContacts.firstWhere((c) => c.isEmergency);
        expect(emergency.name, 'New Emergency');
        expect(emergency.phone, '9844444444');
        expect(emergency.relation, 'Aunt');
        expect(emergency.occupation, 'Professor');
      },
    );
  });

  group('Multi-Year Academic History', () {
    test('tracks 3 separate years of academic history for a student', () async {
      final allYears = await db.getAllAcademicYears();
      final classes = await db.getAllClassesWithSections();

      // Ensure we have at least 3 years and 3 classes
      expect(allYears.length, greaterThanOrEqualTo(3));
      expect(classes.length, greaterThanOrEqualTo(3));

      final year2024 = allYears.firstWhere((y) => y.name.startsWith('2024'));
      final year2025 = allYears.firstWhere((y) => y.name.startsWith('2025'));
      final year2026 = allYears.firstWhere((y) => y.name.startsWith('2026'));

      final class8 = classes.firstWhere(
        (c) => c.name.toLowerCase().contains('8'),
        orElse: () => classes[0],
      );
      final class9 = classes.firstWhere(
        (c) => c.name.toLowerCase().contains('9'),
        orElse: () => classes[1],
      );
      final class10 = classes.firstWhere(
        (c) => c.name.toLowerCase().contains('10'),
        orElse: () => classes[2],
      );

      final sec8 = class8.sections.first;
      final sec9 = class9.sections.first;
      final sec10 = class10.sections.first;

      // Admit in 2024 (Class 8)
      final studentId = await service.admitStudent(
        name: 'Rohan Shrestha',
        gender: 'Male',
        academicYearId: year2024.id,
        classId: class8.id,
        sectionId: sec8.id,
        rollNumber: 5,
        admissionDate: DateTime(2024, 4, 15),
      );

      // Year 1 outcome: passed & promoted
      final hist2024 = await db.getStudentAcademicHistoryForYear(
        studentId,
        year2024.id,
      );
      await db.updateAcademicHistoryEntry(
        hist2024!.copyWith(
          status: AcademicStatus.promoted,
          resultStatus: AcademicResult.passed,
          remarks: const Value('Passed Class 8 with distinction'),
        ),
      );

      // Year 2: enrolled in Class 9 (2025)
      await db.insertAcademicHistory(
        StudentAcademicHistoriesCompanion(
          studentId: Value(studentId),
          academicYearId: Value(year2025.id),
          classId: Value(class9.id),
          sectionId: Value(sec9.id),
          rollNumber: const Value(3),
          status: const Value(AcademicStatus.promoted),
          resultStatus: const Value(AcademicResult.passed),
          remarks: const Value('Passed Class 9, promoted to Class 10'),
          enrolledAt: Value(DateTime(2025, 4, 15)),
        ),
      );

      // Year 3: enrolled in Class 10 (2026)
      await db.insertAcademicHistory(
        StudentAcademicHistoriesCompanion(
          studentId: Value(studentId),
          academicYearId: Value(year2026.id),
          classId: Value(class10.id),
          sectionId: Value(sec10.id),
          rollNumber: const Value(1),
          status: const Value(AcademicStatus.active),
          resultStatus: const Value(AcademicResult.pending),
          remarks: const Value('Currently preparing for SEE examinations'),
          enrolledAt: Value(DateTime(2026, 4, 15)),
        ),
      );

      // Fetch academic history timeline
      final timeline = await service.getStudentAcademicHistory(studentId);
      expect(timeline.length, 3);

      // Sorted descending by academic year start date
      expect(timeline[0].academicYear.id, year2026.id);
      expect(timeline[0].schoolClass.id, class10.id);
      expect(timeline[0].status, AcademicStatus.active);
      expect(timeline[0].resultStatus, AcademicResult.pending);

      expect(timeline[1].academicYear.id, year2025.id);
      expect(timeline[1].schoolClass.id, class9.id);
      expect(timeline[1].status, AcademicStatus.promoted);
      expect(timeline[1].resultStatus, AcademicResult.passed);

      expect(timeline[2].academicYear.id, year2024.id);
      expect(timeline[2].schoolClass.id, class8.id);
      expect(timeline[2].status, AcademicStatus.promoted);
      expect(timeline[2].resultStatus, AcademicResult.passed);
    });
  });

  group('Student Promotion Flow', () {
    test(
      'promotes passed student to target class and retains failed student in source class',
      () async {
        final allYears = await db.getAllAcademicYears();
        final classes = await db.getAllClassesWithSections();

        final sourceYear = allYears.firstWhere(
          (y) => y.name.startsWith('2025'),
        );
        final targetYear = allYears.firstWhere(
          (y) => y.name.startsWith('2026'),
        );

        final class1 = classes.firstWhere(
          (c) => c.name.toLowerCase().contains('1'),
          orElse: () => classes[0],
        );
        final class2 = classes.firstWhere(
          (c) => c.name.toLowerCase().contains('2'),
          orElse: () => classes[1],
        );

        final sec1A = class1.sections.first;
        final sec2B =
            class2.sections.length > 1
                ? class2.sections[1]
                : class2.sections.first;

        // Student 1: Will pass and be promoted to Class 2 B
        final student1Id = await service.admitStudent(
          name: 'Aarav Sharma',
          gender: 'Male',
          academicYearId: sourceYear.id,
          classId: class1.id,
          sectionId: sec1A.id,
          rollNumber: 1,
          admissionDate: DateTime(2025, 4, 15),
        );

        // Student 2: Will fail and be retained in Class 1 A
        final student2Id = await service.admitStudent(
          name: 'Bikash Thapa',
          gender: 'Male',
          academicYearId: sourceYear.id,
          classId: class1.id,
          sectionId: sec1A.id,
          rollNumber: 2,
          admissionDate: DateTime(2025, 4, 15),
        );

        // Perform promotion batch
        await service.promoteStudents(
          sourceAcademicYearId: sourceYear.id,
          targetAcademicYearId: targetYear.id,
          items: [
            // Aarav: Passed & Promoted to Class 2 Section B
            StudentPromotionItem(
              studentId: student1Id,
              studentName: 'Aarav Sharma',
              studentCode: '20250001',
              currentRollNumber: 1,
              resultStatus: AcademicResult.passed,
              isPromoted: true,
              targetClassId: class2.id,
              targetSectionId: sec2B.id,
              targetRollNumber: 5,
              remarks: 'Promoted to Class 2 Section B',
            ),
            // Bikash: Failed & Retained in Class 1 Section A
            StudentPromotionItem(
              studentId: student2Id,
              studentName: 'Bikash Thapa',
              studentCode: '20250002',
              currentRollNumber: 2,
              resultStatus: AcademicResult.failed,
              isPromoted: false,
              targetClassId: class1.id,
              targetSectionId: sec1A.id,
              targetRollNumber: 1,
              remarks: 'Failed exams; retained in Class 1 Section A',
            ),
          ],
        );

        // Verify Student 1 (Aarav)
        final student1SourceHist = await db.getStudentAcademicHistoryForYear(
          student1Id,
          sourceYear.id,
        );
        expect(student1SourceHist!.status, AcademicStatus.promoted);
        expect(student1SourceHist.resultStatus, AcademicResult.passed);

        final student1TargetHist = await db.getStudentAcademicHistoryForYear(
          student1Id,
          targetYear.id,
        );
        expect(student1TargetHist!.classId, class2.id);
        expect(student1TargetHist.sectionId, sec2B.id);
        expect(student1TargetHist.rollNumber, 5);
        expect(student1TargetHist.status, AcademicStatus.active);
        expect(student1TargetHist.resultStatus, AcademicResult.pending);

        final student1Current = await service.getStudentById(student1Id);
        expect(student1Current!.classId, class2.id);
        expect(student1Current.sectionId, sec2B.id);

        // Verify Student 2 (Bikash - Retained)
        final student2SourceHist = await db.getStudentAcademicHistoryForYear(
          student2Id,
          sourceYear.id,
        );
        expect(student2SourceHist!.status, AcademicStatus.retained);
        expect(student2SourceHist.resultStatus, AcademicResult.failed);

        final student2TargetHist = await db.getStudentAcademicHistoryForYear(
          student2Id,
          targetYear.id,
        );
        expect(student2TargetHist!.classId, class1.id);
        expect(student2TargetHist.sectionId, sec1A.id);
        expect(student2TargetHist.rollNumber, 1);
        expect(student2TargetHist.status, AcademicStatus.active);

        final student2Current = await service.getStudentById(student2Id);
        expect(student2Current!.classId, class1.id);
        expect(student2Current.sectionId, sec1A.id);
      },
    );
  });

  group('Student Profile Deletion', () {
    test(
      'deleting student removes academic history and generic contacts',
      () async {
        final year = await db.getCurrentAcademicYear();
        final classes = await db.getAllClassesWithSections();
        final class1 = classes.first;
        final sec1 = class1.sections.first;

        final studentId = await service.admitStudent(
          name: 'To Be Deleted',
          gender: 'Female',
          academicYearId: year!.id,
          classId: class1.id,
          sectionId: sec1.id,
          guardianName: 'Parent Name',
          guardianPhone: '9841000000',
        );

        // Verify existence
        final initialHistory = await service.getStudentAcademicHistory(
          studentId,
        );
        expect(initialHistory.length, 1);
        final initialContacts = await db.getContactsBySource(
          ContactSourceType.student,
          studentId,
        );
        expect(initialContacts.length, 1);

        // Delete student
        await service.deleteStudent(studentId);

        // Verify cascade deletion
        final student = await service.getStudentById(studentId);
        expect(student, isNull);

        final postHistory = await service.getStudentAcademicHistory(studentId);
        expect(postHistory, isEmpty);

        final postContacts = await db.getContactsBySource(
          ContactSourceType.student,
          studentId,
        );
        expect(postContacts, isEmpty);
      },
    );
  });
}
