import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sms/config/enums.dart';
import 'package:sms/data/app_database.dart';
import 'package:sms/services/exam_service.dart';

void main() {
  late AppDatabase db;
  late ExamService examService;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    examService = ExamService(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('Exam Schedule System Tests', () {
    test('Default categories and statuses are correctly defined', () {
      expect(ExamService.defaultCategories, contains('Class Test 1'));
      expect(ExamService.defaultCategories, contains('Terminal Exam 1'));
      expect(ExamService.defaultCategories, contains('Half Yearly'));
      expect(ExamService.defaultCategories, contains('Final Exam'));
      expect(ExamService.statusOptions, contains('Scheduled'));
      expect(ExamService.statusOptions, contains('Ongoing'));
      expect(ExamService.statusOptions, contains('Completed'));
    });

    test('Seeded exams and routines are loaded with details', () async {
      final exams = await examService.getAllExamsWithDetails();
      expect(exams, isNotEmpty);
      expect(exams.any((e) => e.category == 'Terminal Exam 1'), isTrue);

      final scheduledExam = exams.firstWhere((e) => e.scheduleCount > 0);
      expect(scheduledExam.academicYearName, isNotEmpty);

      final routines = await examService.getAllExamSchedulesWithDetails(
        examId: scheduledExam.id,
      );
      expect(routines, isNotEmpty);
      expect(routines.first.className, isNotEmpty);
      expect(routines.first.subjectName, isNotEmpty);
    });

    test('Can create new exam with category and dates', () async {
      final years = await db.getAllAcademicYears();
      expect(years, isNotEmpty);
      final year = years.first;

      final examId = await examService.createExam(
        name: 'Unit Assessment 2083',
        category: 'Class Test 2',
        academicYearId: year.id,
        startDate: DateTime(2026, 10, 1),
        endDate: DateTime(2026, 10, 5),
        description: 'Second unit formative test',
        status: 'Scheduled',
      );

      expect(examId, isPositive);

      final exam = await examService.getExamWithDetailsById(examId);
      expect(exam, isNotNull);
      expect(exam!.name, 'Unit Assessment 2083');
      expect(exam.category, 'Class Test 2');
      expect(exam.status, 'Scheduled');
    });

    test('Can schedule class subject routine and save batch items', () async {
      final years = await db.getAllAcademicYears();
      final classes = await db.getAllClassesWithSections();
      final subjects = await examService.getSubjectsForClass(
        classId: classes.first.id,
        academicYearId: years.first.id,
      );

      expect(subjects, isNotEmpty);

      final examId = await examService.createExam(
        name: 'Pre-Board Exam 2083',
        category: 'Final Exam',
        academicYearId: years.first.id,
        startDate: DateTime(2026, 11, 1),
        endDate: DateTime(2026, 11, 10),
      );

      final scheduleItems = [
        ExamScheduleItemInput(
          subjectId: subjects[0].id,
          examDate: DateTime(2026, 11, 1),
          startTime: '08:00 AM',
          endTime: '11:00 AM',
          fullMarks: subjects[0].fullMarks,
          passMarks: subjects[0].passMarks,
          theoryMarks: subjects[0].theoryMarks,
          practicalMarks: subjects[0].practicalMarks,
          roomNumber: 'Hall A',
          remarks: 'Bring calculator',
          orderIndex: 1,
        ),
        if (subjects.length > 1)
          ExamScheduleItemInput(
            subjectId: subjects[1].id,
            examDate: DateTime(2026, 11, 2),
            startTime: '08:00 AM',
            endTime: '11:00 AM',
            fullMarks: subjects[1].fullMarks,
            passMarks: subjects[1].passMarks,
            theoryMarks: subjects[1].theoryMarks,
            practicalMarks: subjects[1].practicalMarks,
            roomNumber: 'Hall B',
            orderIndex: 2,
          ),
      ];

      await examService.saveClassExamSchedule(
        examId: examId,
        academicYearId: years.first.id,
        classId: classes.first.id,
        items: scheduleItems,
      );

      final saved = await examService.getAllExamSchedulesWithDetails(
        examId: examId,
        classId: classes.first.id,
      );
      expect(saved.length, scheduleItems.length);
      expect(saved[0].subjectName, subjects[0].name);
      expect(saved[0].startTime, '08:00 AM');
      expect(saved[0].roomNumber, 'Hall A');
    });

    test('Deleting an exam cascades and cleans up its schedules', () async {
      final exams = await examService.getAllExamsWithDetails();
      final targetExam = exams.firstWhere((e) => e.scheduleCount > 0);

      final countBefore =
          (await examService.getAllExamSchedulesWithDetails(
            examId: targetExam.id,
          )).length;
      expect(countBefore, isPositive);

      final deleted = await examService.deleteExam(targetExam.id);
      expect(deleted, isPositive);

      final schedulesAfter = await examService.getAllExamSchedulesWithDetails(
        examId: targetExam.id,
      );
      expect(schedulesAfter, isEmpty);
    });

    test(
      'Can create exam and subject schedules together atomically via saveExamWithClassSchedules',
      () async {
        final years = await db.getAllAcademicYears();
        final classes = await db.getAllClassesWithSections();
        final subjects = await examService.getSubjectsForClass(
          classId: classes.first.id,
          academicYearId: years.first.id,
        );

        final schedules = [
          ExamScheduleItemInput(
            subjectId: subjects[0].id,
            examDate: DateTime(2026, 12, 1),
            startTime: '10:00 AM',
            endTime: '01:00 PM',
            fullMarks: 100,
            passMarks: 40,
            theoryMarks: 75,
            practicalMarks: 25,
            roomNumber: 'Room 201',
            remarks: 'Mandatory',
            orderIndex: 1,
          ),
        ];

        final examId = await examService.saveExamWithClassSchedules(
          name: 'Combined Creation Exam 2083',
          category: 'Terminal Exam 1',
          academicYearId: years.first.id,
          classId: classes.first.id,
          startDate: DateTime(2026, 12, 1),
          endDate: DateTime(2026, 12, 10),
          status: 'Scheduled',
          description: 'Created with tabular routine',
          schedules: schedules,
        );

        expect(examId, isPositive);

        final examWithDetails = await examService.getExamWithDetailsById(
          examId,
        );
        expect(examWithDetails, isNotNull);
        expect(examWithDetails!.name, 'Combined Creation Exam 2083');

        final savedSchedules = await examService.getAllExamSchedulesWithDetails(
          examId: examId,
          classId: classes.first.id,
        );
        expect(savedSchedules, hasLength(1));
        expect(savedSchedules.first.subjectId, subjects[0].id);
        expect(savedSchedules.first.roomNumber, 'Room 201');
      },
    );

    test(
      'Stores and retrieves explicit Theory and Practical full/pass marks for combined subjects',
      () async {
        final years = await db.getAllAcademicYears();
        final classes = await db.getAllClassesWithSections();
        final allSubjects = await db.getAllSubjects();
        // Pick a subject with both theory and practical, or create one
        final bothSubject = allSubjects.firstWhere(
          (s) => s.subjectType == SubjectType.both,
          orElse: () => allSubjects.first,
        );

        final schedules = [
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
            roomNumber: 'Lab 1',
            remarks: 'Bring lab coat and instruments',
          ),
        ];

        final examId = await examService.saveExamWithClassSchedules(
          name: 'Science Practical Board 2083',
          category: 'Terminal Exam 1',
          academicYearId: years.first.id,
          classId: classes.first.id,
          startDate: DateTime(2026, 12, 1),
          endDate: DateTime(2026, 12, 5),
          status: 'Scheduled',
          schedules: schedules,
        );

        final saved = await examService.getAllExamSchedulesWithDetails(
          examId: examId,
          classId: classes.first.id,
        );
        expect(saved, hasLength(1));

        final item = saved.first;
        expect(item.fullMarks, 100);
        expect(item.passMarks, 37);
        expect(item.theoryMarks, 75);
        expect(item.practicalMarks, 25);
        expect(item.savedTheoryPassMarks, 27);
        expect(item.savedPracticalPassMarks, 10);
        expect(item.formattedRemarks, 'Bring lab coat and instruments');
      },
    );
  });
}
