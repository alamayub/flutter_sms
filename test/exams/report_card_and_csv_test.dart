// test/exams/report_card_and_csv_test.dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sms/core/database/app_database.dart';
import 'package:sms/features/exams/domain/exam_models.dart';
import 'package:sms/features/exams/domain/result_calculator.dart';
import 'package:sms/features/exams/services/csv/marks_csv_service.dart';
import 'package:sms/features/exams/services/pdf/report_card_pdf_service.dart';

void main() {
  final now = DateTime.now();

  final dummyStudents = [
    Student(
      id: 'stud1',
      schoolId: 'sch1',
      studentCode: 'STD001',
      firstName: 'Alice',
      lastName: 'Smith',
      gender: 'Female',
      isActive: true,
      isArchived: false,
      createdAt: now,
      updatedAt: now,
    ),
    Student(
      id: 'stud2',
      schoolId: 'sch1',
      studentCode: 'STD002',
      firstName: 'Bob',
      lastName: 'Jones',
      gender: 'Male',
      isActive: true,
      isArchived: false,
      createdAt: now,
      updatedAt: now,
    ),
  ];

  final dummyExamSubject = ExamSubject(
    id: 'es1',
    schoolId: 'sch1',
    examId: 'ex1',
    classId: 'cls1',
    subjectId: 'sub1',
    fullMarks: 100.0,
    passMarks: 40.0,
    theoryMarks: 70.0,
    practicalMarks: 20.0,
    internalMarks: 10.0,
    creditHours: 3.0,
    weight: 1.0,
    createdAt: now,
    updatedAt: now,
  );

  group('MarksCsvService Tests', () {
    const csvService = MarksCsvService();

    test('generateMarksTemplate generates clean header and student rows', () {
      final template = csvService.generateMarksTemplate(
        examSubject: dummyExamSubject,
        students: dummyStudents,
      );

      expect(template, contains('Student Code'));
      expect(template, contains('Theory (70)'));
      expect(template, contains('Practical (20)'));
      expect(template, contains('Internal (10)'));
      expect(template, contains('STD001,Alice Smith'));
      expect(template, contains('STD002,Bob Jones'));
    });

    test('exportMarks exports existing marks accurately', () {
      final marks = [
        Mark(
          id: 'm1',
          schoolId: 'sch1',
          examId: 'ex1',
          examSubjectId: 'es1',
          studentId: 'stud1',
          theoryMarks: 60.0,
          practicalMarks: 18.0,
          internalMarks: 9.0,
          totalMarks: 87.0,
          percentage: 87.0,
          grade: 'A',
          status: 'present',
          isLocked: false,
          enteredBy: 'teacher',
          createdAt: now,
          updatedAt: now,
        ),
        Mark(
          id: 'm2',
          schoolId: 'sch1',
          examId: 'ex1',
          examSubjectId: 'es1',
          studentId: 'stud2',
          totalMarks: null,
          status: 'absent',
          isLocked: false,
          enteredBy: 'teacher',
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final csv = csvService.exportMarks(
        examSubject: dummyExamSubject,
        students: dummyStudents,
        marks: marks,
      );

      expect(csv, contains('STD001,Alice Smith,60.0,18.0,9.0,87.0,present'));
      expect(csv, contains('STD002,Bob Jones,,,,ABSENT,absent'));
    });

    test('validateAndParseCsv validates and parses valid CSV content', () {
      const csvData = '''
Student Code,Student Name,Theory (70),Practical (20),Internal (10),Status,Remarks
STD001,Alice Smith,65,18,9,present,Great work
STD002,Bob Jones,,,,absent,Medical issue
''';

      final res = csvService.validateAndParseCsv(
        csvContent: csvData,
        examSubject: dummyExamSubject,
        students: dummyStudents,
      );

      expect(res.hasErrors, isFalse);
      expect(res.isValid, isTrue);
      expect(res.validRows.length, equals(2));

      final row1 = res.validRows.first;
      expect(row1.studentCode, equals('STD001'));
      expect(row1.theoryMarks, equals(65.0));
      expect(row1.practicalMarks, equals(18.0));
      expect(row1.internalMarks, equals(9.0));
      expect(row1.status, equals(MarkStatus.present));
      expect(row1.remarks, equals('Great work'));

      final row2 = res.validRows.last;
      expect(row2.studentCode, equals('STD002'));
      expect(row2.status, equals(MarkStatus.absent));
      expect(row2.theoryMarks, isNull);
    });

    test(
      'validateAndParseCsv catches invalid marks, bounds, and unknown students',
      () {
        const invalidCsv = '''
Student Code,Student Name,Theory,Practical,Internal,Status
UNKNOWN999,Ghost Student,50,10,5,present
STD001,Alice Smith,75,10,5,present
STD002,Bob Jones,50,30,5,invalid_status
''';

        final res = csvService.validateAndParseCsv(
          csvContent: invalidCsv,
          examSubject: dummyExamSubject,
          students: dummyStudents,
        );

        expect(res.hasErrors, isTrue);
        expect(res.errors.length, greaterThanOrEqualTo(3));

        // Error 1: unknown student code
        expect(
          res.errors.any(
            (e) => e.message.contains('does not match any enrolled student'),
          ),
          isTrue,
        );

        // Error 2: theory marks (75) > max theory (70)
        expect(
          res.errors.any(
            (e) => e.message.contains('must be between 0 and max theory'),
          ),
          isTrue,
        );

        // Error 3: practical marks (30) > max practical (20)
        expect(
          res.errors.any(
            (e) => e.message.contains('must be between 0 and max practical'),
          ),
          isTrue,
        );

        // Error 4: invalid status
        expect(
          res.errors.any((e) => e.message.contains('Invalid status')),
          isTrue,
        );
      },
    );
  });

  group('ReportCardPdfService Tests', () {
    final subRes1 = ResultCalculator.calculateSubjectResult(
      subjectId: 'sub1',
      subjectName: 'English Language',
      fullMarks: 100,
      passMarks: 40,
      theoryMarks: 65,
      practicalMarks: 18,
      internalMarks: 9,
      status: MarkStatus.present,
    );

    final subRes2 = ResultCalculator.calculateSubjectResult(
      subjectId: 'sub2',
      subjectName: 'Mathematics',
      fullMarks: 100,
      passMarks: 40,
      theoryMarks: 50,
      practicalMarks: 15,
      internalMarks: 10,
      status: MarkStatus.present,
    );

    final examResult = ResultCalculator.calculateStudentResult(
      studentId: 'stud1',
      studentName: 'Alice Smith',
      studentCode: 'STD001',
      rollNumber: 1,
      classId: 'cls1',
      sectionId: 'sec1',
      subjectResults: [subRes1, subRes2],
    ).copyWith(rank: 1);

    final reportCardData = ReportCardData(
      schoolName: 'Springfield Academy',
      schoolAddress: '123 Academic Way, Springfield',
      schoolPhone: '+1 555 0192',
      schoolPrincipal: 'Dr. Seymour Skinner',
      academicYearName: '2026-2027',
      examName: 'First Term Examination 2026',
      studentName: 'Alice Smith',
      studentCode: 'STD001',
      rollNumber: 1,
      className: 'Grade 9',
      sectionName: 'Section A',
      result: examResult,
      attendanceStats: const StudentAttendanceStats(
        totalDays: 100,
        presentDays: 96,
        absentDays: 4,
        percentage: 96.0,
      ),
      issueDate: DateTime.now(),
    );

    test('generateReportCardPdf produces valid PDF bytes', () async {
      final pdfBytes = await ReportCardPdfService.generateReportCardPdf(
        reportCardData,
      );

      expect(pdfBytes, isNotEmpty);
      // Valid PDF document starts with %PDF
      final header = ascii.decode(pdfBytes.sublist(0, 4));
      expect(header, equals('%PDF'));
    });

    test(
      'generateBulkReportCardsPdf compiles multi-page document with progress callbacks',
      () async {
        final List<int> progressList = [];

        final bulkData = [reportCardData, reportCardData];
        final pdfBytes = await ReportCardPdfService.generateBulkReportCardsPdf(
          studentsData: bulkData,
          onProgress: (cur, total) {
            progressList.add(cur);
          },
        );

        expect(pdfBytes, isNotEmpty);
        final header = ascii.decode(pdfBytes.sublist(0, 4));
        expect(header, equals('%PDF'));
        expect(progressList, equals([1, 2]));
      },
    );
  });
}
