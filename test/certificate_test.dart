import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sms/data/app_database.dart';
import 'package:sms/data/database_seeder.dart';
import 'package:sms/services/certificate_service.dart';
import 'helpers/test_data_seeder.dart';

void main() {
  late AppDatabase db;
  late CertificateService service;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    service = CertificateService(db);
    // Seed prerequisites: academic years, classes, sections, students
    await DatabaseSeeder.seedAcademicYears(db);
    await DatabaseSeeder.seedClassesAndSections(db);
    await TestDataSeeder.seedStudents(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('Grading and GPA Calculations', () {
    test('calculateGrade calculates correct grades and grade points', () {
      expect(CertificateService.calculateGrade(95.0).grade, 'A+');
      expect(CertificateService.calculateGrade(95.0).gradePoint, 4.0);

      expect(CertificateService.calculateGrade(82.5).grade, 'A');
      expect(CertificateService.calculateGrade(82.5).gradePoint, 3.6);

      expect(CertificateService.calculateGrade(74.0).grade, 'B+');
      expect(CertificateService.calculateGrade(74.0).gradePoint, 3.2);

      expect(CertificateService.calculateGrade(63.0).grade, 'B');
      expect(CertificateService.calculateGrade(63.0).gradePoint, 2.8);

      expect(CertificateService.calculateGrade(52.0).grade, 'C+');
      expect(CertificateService.calculateGrade(52.0).gradePoint, 2.4);

      expect(CertificateService.calculateGrade(44.0).grade, 'C');
      expect(CertificateService.calculateGrade(44.0).gradePoint, 2.0);

      expect(CertificateService.calculateGrade(35.0).grade, 'D');
      expect(CertificateService.calculateGrade(35.0).gradePoint, 1.6);

      expect(CertificateService.calculateGrade(22.0).grade, 'F');
      expect(CertificateService.calculateGrade(22.0).gradePoint, 0.0);
    });

    test('calculateDivision calculates correct academic division', () {
      expect(CertificateService.calculateDivision(85.0), 'Distinction');
      expect(CertificateService.calculateDivision(68.0), 'First Division');
      expect(CertificateService.calculateDivision(52.0), 'Second Division');
      expect(CertificateService.calculateDivision(38.0), 'Third Division');
      expect(CertificateService.calculateDivision(25.0), 'Fail');
    });
  });

  group('Certificate Number Generation', () {
    test('Generates sequential certificate numbers based on type', () async {
      final numTc1 = await service.generateCertificateNumber(
        CertificateTypes.transferCertificate,
      );
      expect(numTc1, startsWith('TC-'));

      final numCc1 = await service.generateCertificateNumber(
        CertificateTypes.characterCertificate,
      );
      expect(numCc1, startsWith('CC-'));

      final numBon1 = await service.generateCertificateNumber(
        CertificateTypes.bonafideCertificate,
      );
      expect(numBon1, startsWith('BON-'));

      final numMs1 = await service.generateCertificateNumber(
        CertificateTypes.markSheet,
      );
      expect(numMs1, startsWith('MS-'));

      final numCustom = await service.generateCertificateNumber(
        CertificateTypes.customCertificate,
      );
      expect(numCustom, startsWith('CERT-'));
    });
  });

  group('Transfer Certificate (TC)', () {
    test(
      'Can issue, retrieve, and deserialize a Transfer Certificate',
      () async {
        final students = await db.getAllStudents();
        expect(students, isNotEmpty);
        final student = students.first;
        final years = await db.getAllAcademicYears();
        final year = years.first;

        final certId = await service.issueTransferCertificate(
          studentId: student.id,
          academicYearId: year.id,
          reason: 'Parent transferred to another district',
          conduct: 'Exemplary',
          duesCleared: true,
          leavingDate: DateTime(2026, 3, 31),
          promotedToClass: 'Class 9',
          lastExamPassed: 'Class 8 Annual Examination',
          totalWorkingDays: 210,
          daysPresent: 198,
          remarks: 'All library books returned and dues cleared.',
          issuedBy: 'Principal John Doe',
        );

        expect(certId, greaterThan(0));

        final certWithDetails = await service.getCertificateById(certId);
        expect(certWithDetails, isNotNull);
        expect(
          certWithDetails!.certificate.certificateType,
          CertificateTypes.transferCertificate,
        );
        expect(certWithDetails.certificate.duesCleared, isTrue);
        expect(
          certWithDetails.certificate.reason,
          'Parent transferred to another district',
        );
        expect(certWithDetails.certificate.conduct, 'Exemplary');
        expect(certWithDetails.student.name, student.name);

        final tcData = service.getTransferCertificateData(
          certWithDetails.certificate,
        );
        expect(tcData, isNotNull);
        expect(tcData!.promotedToClass, 'Class 9');
        expect(tcData.lastExamPassed, 'Class 8 Annual Examination');
        expect(tcData.totalWorkingDays, 210);
        expect(tcData.daysPresent, 198);
      },
    );
  });

  group('Character Certificate (CC)', () {
    test('Can issue and retrieve a Character Certificate', () async {
      final students = await db.getAllStudents();
      final student = students.first;
      final years = await db.getAllAcademicYears();
      final year = years.first;

      final certId = await service.issueCharacterCertificate(
        studentId: student.id,
        academicYearId: year.id,
        conduct: 'Excellent and Disciplined',
        motherName: 'Sunita Sharma',
        session: '2025 - 2026',
        coCurricularActivities:
            'Captain of School Football Team, Debate Club Winner',
        academicPerformance: 'Consistently ranks in top 5% of class',
        remarks: 'Worthy of high praise and trust.',
        issuedBy: 'Headmaster',
      );

      expect(certId, greaterThan(0));

      final cert = await service.getCertificateById(certId);
      expect(cert, isNotNull);
      expect(
        cert!.certificate.certificateType,
        CertificateTypes.characterCertificate,
      );
      expect(cert.certificate.conduct, 'Excellent and Disciplined');

      final ccData = service.getCharacterCertificateData(cert.certificate)!;
      expect(ccData, isNotNull);
      expect(ccData.coCurricularActivities, contains('Football'));
      expect(ccData.motherName, 'Sunita Sharma');
      expect(ccData.session, '2025 - 2026');
      expect(ccData.coCurricularActivities, contains('Football'));
      expect(ccData.academicPerformance, contains('top 5%'));

      // Test JSON round-trip
      final json = ccData.toJson();
      final reconstructed = CharacterCertificateData.fromJson(json);
      expect(reconstructed.motherName, 'Sunita Sharma');
      expect(reconstructed.session, '2025 - 2026');
      expect(
        reconstructed.coCurricularActivities,
        ccData.coCurricularActivities,
      );
    });
  });

  group('Bonafide Certificate', () {
    test('Can issue and retrieve a Bonafide Certificate', () async {
      final students = await db.getAllStudents();
      final student = students.first;
      final years = await db.getAllAcademicYears();
      final year = years.first;

      final certId = await service.issueBonafideCertificate(
        studentId: student.id,
        academicYearId: year.id,
        purpose: 'Passport & Visa documentation verification',
        validTill: DateTime(2026, 12, 31),
        fatherName: 'Carlos Rodriguez',
        motherName: 'Maria Rodriguez',
        session: '2025-2026',
        dob: DateTime(2010, 9, 21),
        remarks: 'Their conduct and character have been consistently good throughout their tenure at this institution.',
        issuedBy: 'Registrar',
      );

      expect(certId, greaterThan(0));

      final cert = await service.getCertificateById(certId);
      expect(cert, isNotNull);
      expect(
        cert!.certificate.certificateType,
        CertificateTypes.bonafideCertificate,
      );
      expect(cert.certificate.reason, 'Passport & Visa documentation verification');

      final bonData = service.getBonafideCertificateData(cert.certificate);
      expect(bonData, isNotNull);
      expect(bonData!.purpose, 'Passport & Visa documentation verification');
      expect(bonData.fatherName, 'Carlos Rodriguez');
      expect(bonData.motherName, 'Maria Rodriguez');
      expect(bonData.session, '2025-2026');
      expect(bonData.dob, DateTime(2010, 9, 21));
      expect(bonData.validTill, isNotNull);

      // JSON roundtrip test
      final json = bonData.toJson();
      final roundtripped = BonafideCertificateData.fromJson(json);
      expect(roundtripped.fatherName, 'Carlos Rodriguez');
      expect(roundtripped.motherName, 'Maria Rodriguez');
      expect(roundtripped.session, '2025-2026');
      expect(roundtripped.purpose, 'Passport & Visa documentation verification');
    });
  });

  group('Mark Sheet / Academic Transcript', () {
    test(
      'Calculates subject totals, percentage, GPA, and Letter Grade accurately',
      () async {
        final students = await db.getAllStudents();
        final student = students.first;
        final years = await db.getAllAcademicYears();
        final year = years.first;

        final subjects = [
          MarksheetSubjectEntry(
            subjectCode: 'MTH101',
            subjectName: 'Mathematics',
            theoryMarks: 68,
            practicalMarks: 25,
            fullMarks: 100,
            passMarks: 40,
          ),
          MarksheetSubjectEntry(
            subjectCode: 'SCI101',
            subjectName: 'Science',
            theoryMarks: 60,
            practicalMarks: 24,
            fullMarks: 100,
            passMarks: 40,
          ),
          MarksheetSubjectEntry(
            subjectCode: 'ENG101',
            subjectName: 'English',
            theoryMarks: 78,
            practicalMarks: 0,
            fullMarks: 100,
            passMarks: 40,
          ),
        ];

        final certId = await service.issueMarksheet(
          studentId: student.id,
          academicYearId: year.id,
          examName: 'Annual Final Examination 2026',
          subjects: subjects,
          fatherName: 'Vikram Patel',
          motherName: 'Sunita Patel',
          session: '2025-2026',
          remarks: 'Promoted with Honours',
          issuedBy: 'Examination Controller',
        );

        expect(certId, greaterThan(0));

        final cert = await service.getCertificateById(certId);
        expect(cert, isNotNull);
        expect(cert!.certificate.certificateType, CertificateTypes.markSheet);

        final msData = service.getMarksheetData(cert.certificate);
        expect(msData, isNotNull);
        expect(msData!.fatherName, 'Vikram Patel');
        expect(msData.motherName, 'Sunita Patel');
        expect(msData.session, '2025-2026');
        expect(msData.subjects.length, 3);
        expect(msData.totalFullMarks, 300.0);
        // Math: 68+25 = 93. Sci: 60+24 = 84. Eng: 78. Total = 255.
        expect(msData.totalObtainedMarks, 255.0);
        // Percentage: 255 / 300 = 85.0%
        expect(msData.percentage, closeTo(85.0, 0.01));
        expect(msData.overallGrade, 'A');
        expect(msData.gpa, closeTo(3.6, 0.01));
        expect(msData.division, 'Distinction');
        expect(msData.isPassed, isTrue);

        // Verify individual subject calculations
        final math = msData.subjects.firstWhere(
          (s) => s.subjectCode == 'MTH101',
        );
        expect(math.obtainedMarks, 93.0);
        expect(math.grade, 'A+');
        expect(math.gradePoint, 4.0);
        expect(math.isPassed, isTrue);
      },
    );

    test('Marksheet marks fail when obtained is below pass marks', () async {
      final students = await db.getAllStudents();
      final student = students.first;
      final years = await db.getAllAcademicYears();
      final year = years.first;

      final subjects = [
        MarksheetSubjectEntry(
          subjectCode: 'PHY101',
          subjectName: 'Physics',
          theoryMarks: 15,
          practicalMarks: 10,
          fullMarks: 100,
          passMarks: 40,
        ),
      ];

      final certId = await service.issueMarksheet(
        studentId: student.id,
        academicYearId: year.id,
        examName: 'First Term Examination',
        subjects: subjects,
        issuedBy: 'Class Teacher',
      );

      final cert = await service.getCertificateById(certId);
      final msData = service.getMarksheetData(cert!.certificate);
      expect(msData!.isPassed, isFalse);
      expect(msData.subjects.first.isPassed, isFalse);
      expect(msData.overallGrade, 'F');
      expect(msData.division, 'Fail');
    });
  });

  group('Certificate of Merit & Distinction', () {
    test('Can issue and retrieve a Certificate of Merit & Distinction', () async {
      final students = await db.getAllStudents();
      final student = students.first;
      final years = await db.getAllAcademicYears();
      final year = years.first;

      final certId = await service.issueMeritCertificate(
        studentId: student.id,
        academicYearId: year.id,
        eventTitle: 'Annual Inter-School Science & Technology Exhibition',
        rank: 'First Place & Gold Medalist',
        citation: 'Awarded for extraordinary research and autonomous robotic vehicle design.',
        academicSession: '2025-2026',
        remarks: 'Extraordinary dedication.',
        issuedBy: 'Activity Department',
      );

      expect(certId, greaterThan(0));

      final cert = await service.getCertificateById(certId);
      expect(cert, isNotNull);
      expect(
        cert!.certificate.certificateType,
        CertificateTypes.meritCertificate,
      );
      expect(cert.certificate.reason, 'Annual Inter-School Science & Technology Exhibition');

      final meritData = service.getMeritCertificateData(cert.certificate);
      expect(meritData, isNotNull);
      expect(meritData!.eventTitle, 'Annual Inter-School Science & Technology Exhibition');
      expect(meritData.rank, 'First Place & Gold Medalist');
      expect(meritData.citation, contains('autonomous robotic vehicle design'));
      expect(meritData.academicSession, '2025-2026');

      // JSON roundtrip test
      final json = meritData.toJson();
      final roundtripped = MeritCertificateData.fromJson(json);
      expect(roundtripped.eventTitle, meritData.eventTitle);
      expect(roundtripped.rank, meritData.rank);
      expect(roundtripped.citation, meritData.citation);
    });
  });

  group('Certificate Management Lifecycle & Metrics', () {
    test('Can update status and edit certificate remarks', () async {
      final students = await db.getAllStudents();
      final student = students.first;
      final years = await db.getAllAcademicYears();
      final year = years.first;

      final certId = await service.issueBonafideCertificate(
        studentId: student.id,
        academicYearId: year.id,
        purpose: 'Bank Account Opening',
      );

      // Update status to cancelled
      await service.updateCertificateStatus(
        certId,
        CertificateStatuses.cancelled,
        remarks: 'Duplicate request cancelled',
      );

      final updated = await service.getCertificateById(certId);
      expect(updated!.certificate.status, CertificateStatuses.cancelled);
      expect(updated.certificate.remarks, 'Duplicate request cancelled');
    });

    test('Can delete a certificate', () async {
      final students = await db.getAllStudents();
      final student = students.first;
      final years = await db.getAllAcademicYears();
      final year = years.first;

      final certId = await service.issueBonafideCertificate(
        studentId: student.id,
        academicYearId: year.id,
        purpose: 'Scholarship verification',
      );

      final deleted = await service.deleteCertificate(certId);
      expect(deleted, 1);

      final cert = await service.getCertificateById(certId);
      expect(cert, isNull);
    });

    test(
      'Computes aggregate summary metrics across certificate types',
      () async {
        final students = await db.getAllStudents();
        final s1 = students[0];
        final s2 = students.length > 1 ? students[1] : students[0];
        final years = await db.getAllAcademicYears();
        final year = years.first;

        await service.issueTransferCertificate(
          studentId: s1.id,
          academicYearId: year.id,
          reason: 'Relocating',
        );

        await service.issueCharacterCertificate(
          studentId: s1.id,
          academicYearId: year.id,
          conduct: 'Good',
        );

        await service.issueBonafideCertificate(
          studentId: s2.id,
          academicYearId: year.id,
          purpose: 'Bus Pass',
        );

        final summary = await service.getCertificateSummary();
        expect(summary.total, greaterThanOrEqualTo(3));
        expect(summary.transferCertificates, greaterThanOrEqualTo(1));
        expect(summary.characterCertificates, greaterThanOrEqualTo(1));
        expect(summary.bonafideCertificates, greaterThanOrEqualTo(1));
        expect(summary.active, greaterThanOrEqualTo(3));
      },
    );

    test('Filters certificates by student and type', () async {
      final students = await db.getAllStudents();
      final s1 = students[0];
      final years = await db.getAllAcademicYears();
      final year = years.first;

      await service.issueTransferCertificate(
        studentId: s1.id,
        academicYearId: year.id,
        reason: 'Migration',
      );

      final s1Certs = await service.getCertificatesForStudent(s1.id);
      expect(s1Certs.any((c) => c.certificate.studentId == s1.id), isTrue);

      final tcOnly = await service.getAllCertificates(
        certificateType: CertificateTypes.transferCertificate,
      );
      expect(
        tcOnly.every(
          (c) =>
              c.certificate.certificateType ==
              CertificateTypes.transferCertificate,
        ),
        isTrue,
      );
    });
  });
}
