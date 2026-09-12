import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sms/config/enums.dart';
import 'package:sms/data/app_database.dart';
import 'package:sms/data/database_seeder.dart';
import 'package:sms/services/exam_result_service.dart';
import 'package:sms/services/exam_service.dart';
import 'package:sms/utils/exam_grading_utils.dart';

void main() {
  group('ExamGradingUtils Tests', () {
    test(
      'Percentage to Grade and GPA conversion matches standard 4.0 grading scale',
      () {
        // 90-100: O (4.0)
        final g100 = ExamGradingUtils.getGradeFromPercentage(100.0);
        expect(g100.letterGrade, 'O');
        expect(g100.gradePoint, 4.0);

        final g92 = ExamGradingUtils.getGradeFromPercentage(92.5);
        expect(g92.letterGrade, 'O');
        expect(g92.gradePoint, 4.0);

        // 80-89.9: A+ (3.6)
        final g85 = ExamGradingUtils.getGradeFromPercentage(85.0);
        expect(g85.letterGrade, 'A+');
        expect(g85.gradePoint, 3.6);

        // 70-79.9: A (3.2)
        final g75 = ExamGradingUtils.getGradeFromPercentage(75.0);
        expect(g75.letterGrade, 'A');
        expect(g75.gradePoint, 3.2);

        // 60-69.9: B+ (2.8)
        final g65 = ExamGradingUtils.getGradeFromPercentage(65.0);
        expect(g65.letterGrade, 'B+');
        expect(g65.gradePoint, 2.8);

        // 50-59.9: B (2.4)
        final g55 = ExamGradingUtils.getGradeFromPercentage(55.0);
        expect(g55.letterGrade, 'B');
        expect(g55.gradePoint, 2.4);

        // 40-49.9: C+ (2.0)
        final g45 = ExamGradingUtils.getGradeFromPercentage(45.0);
        expect(g45.letterGrade, 'C+');
        expect(g45.gradePoint, 2.0);

        // 35-39.9: C (1.6)
        final g37 = ExamGradingUtils.getGradeFromPercentage(37.5);
        expect(g37.letterGrade, 'C');
        expect(g37.gradePoint, 1.6);

        // 30-34.9: D (1.2)
        final g32 = ExamGradingUtils.getGradeFromPercentage(32.0);
        expect(g32.letterGrade, 'D');
        expect(g32.gradePoint, 1.2);

        // Below 30: F / Non-Graded (0.0)
        final g25 = ExamGradingUtils.getGradeFromPercentage(25.0);
        expect(g25.letterGrade, 'F');
        expect(g25.gradePoint, 0.0);
      },
    );

    test(
      'Subject evaluation passes when both theory and practical pass marks are met',
      () {
        final res = ExamGradingUtils.calculateSubjectResult(
          theoryMarksObtained: 60.0,
          theoryFullMarks: 75.0,
          theoryPassMarks: 27.0,
          practicalMarksObtained: 20.0,
          practicalFullMarks: 25.0,
          practicalPassMarks: 10.0,
        );

        expect(res.totalFullMarks, 100.0);
        expect(res.totalMarksObtained, 80.0);
        expect(res.percentage, 80.0);
        expect(res.isPassed, isTrue);
        expect(res.letterGrade, 'A+');
        expect(res.gradePoint, 3.6);
      },
    );

    test(
      'Subject evaluation fails if practical marks are below pass marks even if total is high',
      () {
        // 70/75 in theory, but only 5/25 in practical (pass mark is 10)
        // Total is 75/100 (75%), but student failed practical component
        final res = ExamGradingUtils.calculateSubjectResult(
          theoryMarksObtained: 70.0,
          theoryFullMarks: 75.0,
          theoryPassMarks: 27.0,
          practicalMarksObtained: 5.0,
          practicalFullMarks: 25.0,
          practicalPassMarks: 10.0,
        );

        expect(res.totalMarksObtained, 75.0);
        expect(res.percentage, 75.0);
        expect(res.isPassed, isFalse);
        expect(res.letterGrade, 'F');
        expect(res.gradePoint, 0.0);
        expect(res.description, 'Fail / Non-Graded');
      },
    );

    test('Subject evaluation fails if theory marks are below pass marks', () {
      // 20/75 in theory (pass mark 27), and 25/25 in practical
      final res = ExamGradingUtils.calculateSubjectResult(
        theoryMarksObtained: 20.0,
        theoryFullMarks: 75.0,
        theoryPassMarks: 27.0,
        practicalMarksObtained: 25.0,
        practicalFullMarks: 25.0,
        practicalPassMarks: 10.0,
      );

      expect(res.isPassed, isFalse);
      expect(res.letterGrade, 'F');
      expect(res.gradePoint, 0.0);
      expect(res.description, 'Fail / Non-Graded');
    });

    test(
      'Absent student receives 0 marks, 0 GPA, AB grade, and isPassed false',
      () {
        final res = ExamGradingUtils.calculateSubjectResult(
          theoryMarksObtained: 0.0,
          theoryFullMarks: 100.0,
          theoryPassMarks: 35.0,
          isAbsent: true,
        );

        expect(res.isAbsent, isTrue);
        expect(res.isPassed, isFalse);
        expect(res.totalMarksObtained, 0.0);
        expect(res.percentage, 0.0);
        expect(res.gradePoint, 0.0);
        expect(res.letterGrade, 'AB');
      },
    );

    test(
      'Overall grade calculation accurately computes aggregate GPA, percentage and status',
      () {
        final sub1 = ExamGradingUtils.calculateSubjectResult(
          theoryMarksObtained: 85.0,
          theoryFullMarks: 100.0,
          theoryPassMarks: 35.0,
        ); // 85% -> A+ (3.6)

        final sub2 = ExamGradingUtils.calculateSubjectResult(
          theoryMarksObtained: 95.0,
          theoryFullMarks: 100.0,
          theoryPassMarks: 35.0,
        ); // 95% -> O (4.0)

        final sub3 = ExamGradingUtils.calculateSubjectResult(
          theoryMarksObtained: 75.0,
          theoryFullMarks: 100.0,
          theoryPassMarks: 35.0,
        ); // 75% -> A (3.2)

        final overall = ExamGradingUtils.calculateOverallResult([
          sub1,
          sub2,
          sub3,
        ]);

        expect(overall.totalFullMarks, 300.0);
        expect(overall.totalMarksObtained, 255.0);
        expect(overall.percentage, 85.0);
        // (3.6 + 4.0 + 3.2) / 3 = 3.6
        expect(overall.gpa, 3.6);
        expect(overall.isPassed, isTrue);
        expect(overall.passedSubjects, 3);
        expect(overall.failedSubjects, 0);
      },
    );

    test('Overall grade calculation fails if any subject fails', () {
      final passSub = ExamGradingUtils.calculateSubjectResult(
        theoryMarksObtained: 90.0,
        theoryFullMarks: 100.0,
        theoryPassMarks: 35.0,
      );

      final failSub = ExamGradingUtils.calculateSubjectResult(
        theoryMarksObtained: 20.0,
        theoryFullMarks: 100.0,
        theoryPassMarks: 35.0,
      );

      final overall = ExamGradingUtils.calculateOverallResult([
        passSub,
        failSub,
      ]);

      expect(overall.isPassed, isFalse);
      expect(overall.failedSubjects, 1);
      expect(overall.passedSubjects, 1);
      expect(overall.letterGrade, 'F');
      expect(overall.gpa, 2.0);
    });
  });

  group('ExamResultService Database Integration Tests', () {
    late AppDatabase db;
    late ExamResultService resultService;
    late ExamService examService;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      await DatabaseSeeder.seedIfEmpty(db);
      resultService = ExamResultService(db);
      examService = ExamService(db);
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'Seeded database contains exam results and summaries with grading and percentage stored',
      () async {
        final exams = await examService.getAllExamsWithDetails();
        expect(exams, isNotEmpty);
        final exam = exams.firstWhere((e) => e.scheduleCount > 0);

        final results = await resultService.getExamResults(examId: exam.id);
        expect(
          results,
          isNotEmpty,
          reason: 'Seeder should populate sample exam results',
        );

        // Verify each result has both percentage and grading persistently stored
        for (final r in results) {
          expect(r.percentage, isNotNull);
          expect(r.percentage, inInclusiveRange(0.0, 100.0));
          expect(r.gradePoint, inInclusiveRange(0.0, 4.0));
          expect(r.letterGrade, isNotEmpty);
          expect(r.studentName, isNotEmpty);
          expect(r.subjectName, isNotEmpty);
        }

        // Verify summaries exist with GPA and rankings
        final summaries = await resultService.getExamSummaries(examId: exam.id);
        expect(summaries, isNotEmpty);
        for (final s in summaries) {
          expect(s.overallPercentage, inInclusiveRange(0.0, 100.0));
          expect(s.overallGpa, inInclusiveRange(0.0, 4.0));
          expect(s.overallGrade, isNotEmpty);
          expect(s.rankInClass, isNotNull);
          expect(s.studentName, isNotEmpty);
        }
      },
    );

    test(
      'Can save batch subject marks and updates tabulation ledger',
      () async {
        final exams = await examService.getAllExamsWithDetails();
        final exam = exams.firstWhere((e) => e.scheduleCount > 0);

        final schedules = await examService.getAllExamSchedulesWithDetails(
          examId: exam.id,
        );
        expect(schedules, isNotEmpty);
        final schedule = schedules.firstWhere((s) => s.className == 'Class 10');

        final students = await resultService.getStudentsForExam(
          classId: schedule.classId,
          academicYearId: exam.academicYearId,
        );
        expect(students, isNotEmpty);

        final hasPrac = schedule.subject.subjectType != SubjectType.theory;
        final tFull =
            (hasPrac ? (schedule.theoryMarks ?? 75) : schedule.fullMarks)
                .toDouble();
        final tPass =
            (hasPrac
                    ? (schedule.passMarks > 30 ? 27 : schedule.passMarks)
                    : schedule.passMarks)
                .toDouble();
        final pFull =
            hasPrac ? (schedule.practicalMarks ?? 25).toDouble() : null;
        final pPass = hasPrac ? 10.0 : null;

        // Enter marks for students in this subject
        final entries = [
          SubjectMarksEntryInput(
            studentId: students[0].id,
            theoryMarks: 65.0,
            practicalMarks: hasPrac ? 22.0 : null,
          ),
        ];

        if (students.length > 1) {
          entries.add(
            SubjectMarksEntryInput(
              studentId: students[1].id,
              theoryMarks: 40.0,
              practicalMarks: hasPrac ? 15.0 : null,
            ),
          );
        }

        await resultService.saveSubjectMarksBatch(
          examId: exam.id,
          academicYearId: exam.academicYearId,
          classId: schedule.classId,
          sectionId: null,
          subjectId: schedule.subjectId,
          examScheduleId: schedule.id,
          theoryFullMarks: tFull,
          theoryPassMarks: tPass,
          practicalFullMarks: pFull,
          practicalPassMarks: pPass,
          entries: entries,
        );

        // Verify results are stored
        final updatedResults = await resultService.getExamResults(
          examId: exam.id,
          classId: schedule.classId,
          subjectId: schedule.subjectId,
        );
        expect(updatedResults, isNotEmpty);

        final s1Result = updatedResults.firstWhere(
          (r) => r.studentId == students[0].id,
        );
        expect(s1Result.theoryMarksObtained, 65.0);
        expect(s1Result.percentage, isNotNull);
        expect(s1Result.gradePoint, isNotNull);
        expect(s1Result.letterGrade, isNotNull);
      },
    );

    test('Can save student marksheet entry across all subjects', () async {
      final exams = await examService.getAllExamsWithDetails();
      final exam = exams.firstWhere((e) => e.scheduleCount > 0);

      final classes = await db.select(db.schoolClasses).get();
      expect(classes, isNotEmpty);
      final schoolClass = classes.firstWhere((c) => c.name == 'Class 10');

      final students = await resultService.getStudentsForExam(
        classId: schoolClass.id,
        academicYearId: exam.academicYearId,
      );
      expect(students, isNotEmpty);
      final student = students.first;

      final subjects = await examService.getSubjectsForClass(
        classId: schoolClass.id,
        academicYearId: exam.academicYearId,
      );
      expect(subjects, isNotEmpty);

      // Prepare marksheet entries for this student across all subjects
      final entries =
          subjects.map((sub) {
            final hasPrac = sub.subjectType != SubjectType.theory;
            return StudentSubjectMarksEntryInput(
              subjectId: sub.id,
              theoryMarks: hasPrac ? 60.0 : 80.0,
              practicalMarks: hasPrac ? 20.0 : null,
              theoryFullMarks: hasPrac ? 75.0 : 100.0,
              theoryPassMarks: hasPrac ? 27.0 : 35.0,
              practicalFullMarks: hasPrac ? 25.0 : null,
              practicalPassMarks: hasPrac ? 10.0 : null,
            );
          }).toList();

      // Clear any pre-seeded results for this student to test a clean marksheet entry
      await (db.delete(db.examResults)..where(
        (t) => t.examId.equals(exam.id) & t.studentId.equals(student.id),
      )).go();

      await resultService.saveStudentMarksheetBatch(
        examId: exam.id,
        academicYearId: exam.academicYearId,
        classId: schoolClass.id,
        studentId: student.id,
        entries: entries,
      );

      // Check student's summary was created
      final summaries = await resultService.getExamSummaries(
        examId: exam.id,
        classId: schoolClass.id,
      );

      final studentSummary =
          summaries.where((s) => s.studentId == student.id).firstOrNull;
      expect(studentSummary, isNotNull);
      expect(studentSummary!.totalSubjects, subjects.length);
      expect(studentSummary.passedSubjects, subjects.length);
      expect(studentSummary.isPassed, isTrue);
      expect(studentSummary.overallGpa, greaterThan(3.0));
      expect(studentSummary.overallPercentage, greaterThan(70.0));
    });

    test(
      'Recalculate class tabulation ledger ranks students correctly based on GPA and percentage',
      () async {
        final exams = await examService.getAllExamsWithDetails();
        final exam = exams.firstWhere((e) => e.scheduleCount > 0);

        final classes = await db.select(db.schoolClasses).get();
        final schoolClass = classes.firstWhere((c) => c.name == 'Class 10');

        // Recalculate ledger for this class
        await resultService.recalculateExamSummariesForClass(
          examId: exam.id,
          academicYearId: exam.academicYearId,
          classId: schoolClass.id,
        );

        final summaries = await resultService.getExamSummaries(
          examId: exam.id,
          classId: schoolClass.id,
        );

        if (summaries.length >= 2) {
          // First rank should have >= GPA / percentage of subsequent ranks
          final rank1 = summaries.firstWhere((s) => s.rankInClass == 1);
          final rank2 = summaries.firstWhere((s) => s.rankInClass == 2);

          expect(
            rank1.overallGpa >= rank2.overallGpa ||
                (rank1.overallGpa == rank2.overallGpa &&
                    rank1.overallPercentage >= rank2.overallPercentage),
            isTrue,
          );
        }
      },
    );

    test(
      'getSubjectMarksConfig loads custom theory and practical pass marks configured in exam schedule',
      () async {
        final years = await db.getAllAcademicYears();
        final classes = await db.getAllClassesWithSections();
        final allSubjects = await db.getAllSubjects();
        final bothSubject = allSubjects.firstWhere(
          (s) => s.subjectType == SubjectType.both,
          orElse: () => allSubjects.first,
        );

        final examId = await examService.saveExamWithClassSchedules(
          name: 'Custom Pass Marks Test Exam',
          category: 'Terminal Exam 1',
          academicYearId: years.first.id,
          classId: classes.first.id,
          startDate: DateTime(2026, 12, 1),
          endDate: DateTime(2026, 12, 5),
          status: 'Scheduled',
          schedules: [
            ExamScheduleItemInput(
              subjectId: bothSubject.id,
              examDate: DateTime(2026, 12, 1),
              startTime: '10:00 AM',
              endTime: '01:00 PM',
              fullMarks: 100,
              passMarks: 37,
              theoryMarks: 75,
              theoryPassMarks: 27,
              practicalMarks: 25,
              practicalPassMarks: 10,
            ),
          ],
        );

        final config = await resultService.getSubjectMarksConfig(
          examId: examId,
          classId: classes.first.id,
          subjectId: bothSubject.id,
        );

        expect(config, isNotNull);
        expect(config!.totalFullMarks, 100.0);
        expect(config.totalPassMarks, 37.0);
        expect(config.theoryFullMarks, 75.0);
        expect(config.theoryPassMarks, 27.0);
        expect(config.practicalFullMarks, 25.0);
        expect(config.practicalPassMarks, 10.0);
      },
    );

    test(
      'Result preview accurately calculates class KPI aggregates and flags validation limits',
      () {
        // 3 students in a class:
        // Student 1: 65/75 theory, 20/25 practical -> 85/100 (85%, A+, 3.6 GPA, PASS)
        // Student 2: 20/75 theory, 18/25 practical -> 38/100 (38%, failed theory pass mark 27, F, 0.0 GPA, FAIL)
        // Student 3: Absent -> 0/100 (0%, AB, 0.0 GPA, ABSENT)

        final s1 = ExamGradingUtils.calculateSubjectResult(
          theoryMarksObtained: 65.0,
          theoryFullMarks: 75.0,
          theoryPassMarks: 27.0,
          practicalMarksObtained: 20.0,
          practicalFullMarks: 25.0,
          practicalPassMarks: 10.0,
        );

        final s2 = ExamGradingUtils.calculateSubjectResult(
          theoryMarksObtained: 20.0,
          theoryFullMarks: 75.0,
          theoryPassMarks: 27.0,
          practicalMarksObtained: 18.0,
          practicalFullMarks: 25.0,
          practicalPassMarks: 10.0,
        );

        final s3 = ExamGradingUtils.calculateSubjectResult(
          theoryMarksObtained: 0.0,
          theoryFullMarks: 75.0,
          theoryPassMarks: 27.0,
          practicalMarksObtained: 0.0,
          practicalFullMarks: 25.0,
          practicalPassMarks: 10.0,
          isAbsent: true,
        );

        expect(s1.isPassed, isTrue);
        expect(s1.letterGrade, 'A+');
        expect(s1.gradePoint, 3.6);

        expect(s2.isPassed, isFalse);
        expect(s2.letterGrade, 'F');
        expect(s2.gradePoint, 0.0);

        expect(s3.isAbsent, isTrue);
        expect(s3.letterGrade, 'AB');
        expect(s3.gradePoint, 0.0);

        // Class aggregations
        const totalStudents = 3;
        const absentCount = 1;
        const evaluatedCount = totalStudents - absentCount; // 2
        final passedCount = [s1, s2].where((s) => s.isPassed).length; // 1
        final failedCount = [s1, s2].where((s) => !s.isPassed).length; // 1

        expect(passedCount, 1);
        expect(failedCount, 1);

        final totalMarks =
            s1.totalMarksObtained + s2.totalMarksObtained; // 85 + 38 = 123
        final maxMarks = evaluatedCount * 100.0; // 200
        final avgPercentage = (totalMarks / maxMarks) * 100; // 61.5%
        expect(avgPercentage, 61.5);

        final avgGpa =
            (s1.gradePoint + s2.gradePoint) /
            evaluatedCount; // (3.6 + 0) / 2 = 1.8
        expect(avgGpa, 1.8);

        // Validation limit detection: marks > full marks or negative
        const theoryFull = 75.0;
        const practicalFull = 25.0;

        bool isValidMark(double t, double? p) {
          if (t < 0 || t > theoryFull) return false;
          if (p != null && (p < 0 || p > practicalFull)) return false;
          return true;
        }

        expect(isValidMark(65, 20), isTrue);
        expect(isValidMark(85, 20), isFalse); // Theory 85 > 75
        expect(isValidMark(-5, 20), isFalse); // Negative theory
        expect(isValidMark(65, 30), isFalse); // Practical 30 > 25
        expect(isValidMark(65, -2), isFalse); // Negative practical
      },
    );

    test(
      'Overall marksheet preview computes student aggregate across subjects',
      () {
        // 3 Subjects:
        // Sub 1: Math (100) -> 85/100 (85%, A+, 3.6 GPA, PASS)
        // Sub 2: Science (100) -> 72/100 (72%, A, 3.2 GPA, PASS)
        // Sub 3: English (100) -> 58/100 (58%, B, 2.4 GPA, PASS)

        final sub1 = ExamGradingUtils.calculateSubjectResult(
          theoryMarksObtained: 85,
          theoryFullMarks: 100,
          theoryPassMarks: 35,
        );
        final sub2 = ExamGradingUtils.calculateSubjectResult(
          theoryMarksObtained: 72,
          theoryFullMarks: 100,
          theoryPassMarks: 35,
        );
        final sub3 = ExamGradingUtils.calculateSubjectResult(
          theoryMarksObtained: 58,
          theoryFullMarks: 100,
          theoryPassMarks: 35,
        );

        final overall = ExamGradingUtils.calculateOverallResult([
          sub1,
          sub2,
          sub3,
        ]);

        expect(overall.totalFullMarks, 300.0);
        expect(overall.totalMarksObtained, 215.0);
        expect(overall.percentage, closeTo(71.67, 0.01));
        expect(overall.letterGrade, 'A');
        expect(overall.gpa, closeTo(3.07, 0.01));
        expect(overall.isPassed, isTrue);
        expect(overall.passedSubjects, 3);
        expect(overall.failedSubjects, 0);
      },
    );
  });
}
