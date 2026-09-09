import 'package:flutter_test/flutter_test.dart';
import 'package:sms/features/exams/domain/exam_models.dart';
import 'package:sms/features/exams/domain/grading_engine.dart';
import 'package:sms/features/exams/domain/ranking_service.dart';
import 'package:sms/features/exams/domain/result_calculator.dart';

void main() {
  group('GradingEngine Tests', () {
    test('default grading scheme produces correct grades and grade points', () {
      final r1 = GradingEngine.getGradeForPercentage(percentage: 95.0);
      expect(r1.grade, equals('A+'));
      expect(r1.gradePoint, equals(4.0));
      expect(r1.isPassing, isTrue);

      final r2 = GradingEngine.getGradeForPercentage(percentage: 85.0);
      expect(r2.grade, equals('A'));
      expect(r2.gradePoint, equals(3.6));
      expect(r2.isPassing, isTrue);

      final r3 = GradingEngine.getGradeForPercentage(percentage: 72.5);
      expect(r3.grade, equals('B+'));
      expect(r3.gradePoint, equals(3.2));
      expect(r3.isPassing, isTrue);

      final r4 = GradingEngine.getGradeForPercentage(percentage: 60.0);
      expect(r4.grade, equals('B'));
      expect(r4.gradePoint, equals(2.8));
      expect(r4.isPassing, isTrue);

      final r5 = GradingEngine.getGradeForPercentage(percentage: 50.0);
      expect(r5.grade, equals('C+'));
      expect(r5.gradePoint, equals(2.4));
      expect(r5.isPassing, isTrue);

      final r6 = GradingEngine.getGradeForPercentage(percentage: 40.0);
      expect(r6.grade, equals('C'));
      expect(r6.gradePoint, equals(2.0));
      expect(r6.isPassing, isTrue);

      final r7 = GradingEngine.getGradeForPercentage(percentage: 35.0);
      expect(r7.grade, equals('D'));
      expect(r7.gradePoint, equals(1.6));
      expect(r7.isPassing, isTrue);

      final r8 = GradingEngine.getGradeForPercentage(percentage: 34.9);
      expect(r8.grade, equals('F'));
      expect(r8.gradePoint, equals(0.0));
      expect(r8.isPassing, isFalse);
    });

    test(
      'boundary values match upper and lower limits with epsilon tolerance',
      () {
        // Exactly 90.0 is A+
        expect(
          GradingEngine.getGradeForPercentage(percentage: 90.0).grade,
          equals('A+'),
        );

        // 89.999 is A
        expect(
          GradingEngine.getGradeForPercentage(percentage: 89.99).grade,
          equals('A'),
        );

        // 0.0 is F
        expect(
          GradingEngine.getGradeForPercentage(percentage: 0.0).grade,
          equals('F'),
        );

        // 100.0 is A+
        expect(
          GradingEngine.getGradeForPercentage(percentage: 100.0).grade,
          equals('A+'),
        );
      },
    );

    test(
      'validates grading rules and rejects overlapping or inconsistent rules',
      () {
        final invalidRulesOverlap = [
          const GradeRuleModel(
            grade: 'A',
            minPercentage: 70,
            maxPercentage: 100,
            gradePoint: 4.0,
            isPassing: true,
          ),
          const GradeRuleModel(
            grade: 'B',
            minPercentage: 60,
            maxPercentage: 75,
            gradePoint: 3.0,
            isPassing: true,
          ), // overlaps 70-75
        ];
        expect(GradingEngine.validateRules(invalidRulesOverlap), isNotNull);

        final invalidRange = [
          const GradeRuleModel(
            grade: 'A',
            minPercentage: 90,
            maxPercentage: 80,
            gradePoint: 4.0,
            isPassing: true,
          ), // min > max
        ];
        expect(GradingEngine.validateRules(invalidRange), isNotNull);

        expect(GradingEngine.validateRules(GradingEngine.defaultRules), isNull);
      },
    );
  });

  group('ResultCalculator Tests', () {
    test(
      'calculateSubjectResult calculates total, percentage, and pass/fail correctly',
      () {
        final res = ResultCalculator.calculateSubjectResult(
          subjectId: 'sub1',
          subjectName: 'Mathematics',
          fullMarks: 100,
          passMarks: 40,
          theoryMarks: 50,
          practicalMarks: 20,
          internalMarks: 15,
          status: MarkStatus.present,
        );

        expect(res.totalMarks, equals(85.0));
        expect(res.percentage, equals(85.0));
        expect(res.grade, equals('A'));
        expect(res.gradePoint, equals(3.6));
        expect(res.isPassed, isTrue);
      },
    );

    test('calculateSubjectResult handles failure when marks < passMarks', () {
      final res = ResultCalculator.calculateSubjectResult(
        subjectId: 'sub2',
        subjectName: 'Science',
        fullMarks: 100,
        passMarks: 40,
        theoryMarks: 25,
        practicalMarks: 5,
        internalMarks: 4,
        status: MarkStatus.present,
      );

      expect(res.totalMarks, equals(34.0));
      expect(res.percentage, equals(34.0));
      expect(res.grade, equals('F'));
      expect(res.isPassed, isFalse);
    });

    test(
      'calculateSubjectResult correctly handles absent status (never stored as 0 marks)',
      () {
        final res = ResultCalculator.calculateSubjectResult(
          subjectId: 'sub3',
          subjectName: 'English',
          fullMarks: 100,
          passMarks: 40,
          theoryMarks: null,
          practicalMarks: null,
          internalMarks: null,
          status: MarkStatus.absent,
        );

        expect(res.totalMarks, isNull);
        expect(res.percentage, isNull);
        expect(res.grade, equals('F'));
        expect(res.gradePoint, equals(0.0));
        expect(res.isPassed, isFalse);
        expect(res.status, equals(MarkStatus.absent));
      },
    );

    test(
      'calculateStudentResult aggregates across subjects and determines GPA',
      () {
        final s1 = ResultCalculator.calculateSubjectResult(
          subjectId: 'sub1',
          subjectName: 'Math',
          fullMarks: 100,
          passMarks: 40,
          theoryMarks: 70,
          practicalMarks: 15,
          internalMarks: 10,
          status: MarkStatus.present,
        ); // 95 -> A+ (4.0)

        final s2 = ResultCalculator.calculateSubjectResult(
          subjectId: 'sub2',
          subjectName: 'Physics',
          fullMarks: 100,
          passMarks: 40,
          theoryMarks: 60,
          practicalMarks: 15,
          internalMarks: 10,
          status: MarkStatus.present,
        ); // 85 -> A (3.6)

        final creditHours = {'sub1': 4.0, 'sub2': 4.0};

        final studentRes = ResultCalculator.calculateStudentResult(
          studentId: 'stud1',
          studentName: 'Alice Green',
          studentCode: 'STD001',
          rollNumber: 1,
          classId: 'cls1',
          sectionId: 'sec1',
          subjectResults: [s1, s2],
          subjectCreditHours: creditHours,
        );

        expect(studentRes.totalMarksObtained, equals(180.0));
        expect(studentRes.totalFullMarks, equals(200.0));
        expect(studentRes.percentage, equals(90.0));
        expect(studentRes.overallGrade, equals('A+'));
        // GPA: (4.0*4 + 3.6*4) / 8 = 3.8
        expect(studentRes.gpa, equals(3.8));
        expect(studentRes.isPassed, isTrue);
      },
    );

    test(
      'calculateStudentResult sets isPassed to false if any subject is failed',
      () {
        final s1 = ResultCalculator.calculateSubjectResult(
          subjectId: 'sub1',
          subjectName: 'Math',
          fullMarks: 100,
          passMarks: 40,
          theoryMarks: 70,
          practicalMarks: 15,
          internalMarks: 10,
          status: MarkStatus.present,
        ); // Passed

        final s2 = ResultCalculator.calculateSubjectResult(
          subjectId: 'sub2',
          subjectName: 'History',
          fullMarks: 100,
          passMarks: 40,
          theoryMarks: 20,
          practicalMarks: 5,
          internalMarks: 5,
          status: MarkStatus.present,
        ); // 30 marks -> Failed!

        final studentRes = ResultCalculator.calculateStudentResult(
          studentId: 'stud2',
          studentName: 'Bob Brown',
          classId: 'cls1',
          sectionId: 'sec1',
          subjectResults: [s1, s2],
        );

        expect(studentRes.isPassed, isFalse);
      },
    );
  });

  group('RankingService Tests', () {
    test(
      'calculateOrdinalRanks ranks students by percentage and correctly handles ties',
      () {
        final s1 = ResultCalculator.calculateStudentResult(
          studentId: 'st1',
          studentName: 'Student 1',
          classId: 'c1',
          sectionId: 's1',
          subjectResults: [
            ResultCalculator.calculateSubjectResult(
              subjectId: 'sub1',
              subjectName: 'Sub1',
              fullMarks: 100,
              passMarks: 40,
              theoryMarks: 95,
              status: MarkStatus.present,
            ),
          ],
        ); // 95%

        final s2 = ResultCalculator.calculateStudentResult(
          studentId: 'st2',
          studentName: 'Student 2',
          classId: 'c1',
          sectionId: 's1',
          subjectResults: [
            ResultCalculator.calculateSubjectResult(
              subjectId: 'sub1',
              subjectName: 'Sub1',
              fullMarks: 100,
              passMarks: 40,
              theoryMarks: 95,
              status: MarkStatus.present,
            ),
          ],
        ); // 95% (Tied with Student 1)

        final s3 = ResultCalculator.calculateStudentResult(
          studentId: 'st3',
          studentName: 'Student 3',
          classId: 'c1',
          sectionId: 's1',
          subjectResults: [
            ResultCalculator.calculateSubjectResult(
              subjectId: 'sub1',
              subjectName: 'Sub1',
              fullMarks: 100,
              passMarks: 40,
              theoryMarks: 80,
              status: MarkStatus.present,
            ),
          ],
        ); // 80% (Should be rank 3 due to tie ahead of them)

        final s4 = ResultCalculator.calculateStudentResult(
          studentId: 'st4',
          studentName: 'Student 4',
          classId: 'c1',
          sectionId: 's1',
          subjectResults: [
            ResultCalculator.calculateSubjectResult(
              subjectId: 'sub1',
              subjectName: 'Sub1',
              fullMarks: 100,
              passMarks: 40,
              theoryMarks: 20,
              status: MarkStatus.present,
            ),
          ],
        ); // 20% Failed

        final ranked = RankingService.rankStudents([s3, s1, s4, s2]);

        final r1 = ranked.firstWhere((r) => r.studentId == 'st1');
        final r2 = ranked.firstWhere((r) => r.studentId == 'st2');
        final r3 = ranked.firstWhere((r) => r.studentId == 'st3');
        final r4 = ranked.firstWhere((r) => r.studentId == 'st4');

        expect(r1.rank, equals(1));
        expect(r2.rank, equals(1));
        expect(r3.rank, equals(3));
        expect(r4.rank, equals(4));
      },
    );
  });
}
