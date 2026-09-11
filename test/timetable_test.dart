import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sms/data/app_database.dart';
import 'package:sms/data/database_seeder.dart';
import 'package:sms/services/teacher_service.dart';
import 'package:sms/services/timetable_service.dart';

void main() {
  late AppDatabase db;
  late TimetableService timetableService;
  late TeacherService teacherService;
  late AcademicYear activeYear;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    timetableService = TimetableService(db);
    teacherService = TeacherService(db);
    final years = await db.getAllAcademicYears();
    activeYear = years.firstWhere(
      (y) => y.isCurrent,
      orElse: () => years.first,
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('Timetable & Teachers Seeder Tests', () {
    test('Automatically seeds teachers and faculty members', () async {
      final teachers = await teacherService.getAllTeachers();
      expect(teachers, isNotEmpty);
      expect(teachers.length, greaterThanOrEqualTo(8));

      final teacherNames = teachers.map((t) => t.name).toList();
      expect(teacherNames.contains('Ram Sharma'), true);
      expect(teacherNames.contains('Sita Thapa'), true);
      expect(teacherNames.contains('Hari Prasad Shrestha'), true);
      expect(teacherNames.contains('Anita Tamang'), true);
    });

    test(
      'Automatically seeds timetable periods covering school week (Sunday to Friday)',
      () async {
        final allPeriods = await timetableService.getAllPeriodsWithDetails();
        expect(allPeriods, isNotEmpty);

        // Verify all 6 school days (sunday through friday) have periods
        const schoolDays = [
          'sunday',
          'monday',
          'tuesday',
          'wednesday',
          'thursday',
          'friday',
        ];
        for (final day in schoolDays) {
          final dayPeriods =
              allPeriods.where((p) => p.dayOfWeek == day).toList();
          expect(
            dayPeriods,
            isNotEmpty,
            reason: 'Day $day should have seeded periods',
          );
        }
      },
    );

    test(
      'Timetable includes both academic periods and break intervals',
      () async {
        final allPeriods = await timetableService.getAllPeriodsWithDetails();

        final academicPeriods = allPeriods.where((p) => !p.isBreak).toList();
        final breakPeriods = allPeriods.where((p) => p.isBreak).toList();

        expect(academicPeriods, isNotEmpty);
        expect(breakPeriods, isNotEmpty);

        // Verify break periods have titles such as Assembly or Lunch
        final breakTitles =
            breakPeriods.map((p) => p.breakTitle ?? '').toList();
        expect(
          breakTitles.any((t) => t.contains('Assembly') || t.contains('Lunch')),
          true,
        );

        // Verify academic periods have joined subjects and teachers
        expect(academicPeriods.any((p) => p.subject != null), true);
        expect(academicPeriods.any((p) => p.teacher != null), true);
      },
    );

    test(
      'DatabaseSeeder.seedIfEmpty is idempotent for teachers and timetable',
      () async {
        final initialTeacherCount =
            (await teacherService.getAllTeachers()).length;
        final initialPeriodCount =
            (await timetableService.getAllPeriodsWithDetails()).length;

        expect(initialTeacherCount, greaterThan(0));
        expect(initialPeriodCount, greaterThan(0));

        // Re-run seeder
        await DatabaseSeeder.seedIfEmpty(db);

        final afterTeacherCount =
            (await teacherService.getAllTeachers()).length;
        final afterPeriodCount =
            (await timetableService.getAllPeriodsWithDetails()).length;

        expect(afterTeacherCount, initialTeacherCount);
        expect(afterPeriodCount, initialPeriodCount);
      },
    );
  });

  group('Timetable CRUD & Validation Tests', () {
    test('Can create and retrieve a subject period', () async {
      final classes = await db.getAllClassesWithSections();
      final subjects = await db.getAllSubjects();
      final teachers = await teacherService.getAllTeachers();

      final targetClass = classes.first;
      final targetSection = targetClass.sections.first;
      final targetSubject = subjects.first;
      final targetTeacher = teachers.first;

      final id = await timetableService.createPeriod(
        academicYearId: activeYear.id,
        classId: targetClass.id,
        sectionId: targetSection.id,
        dayOfWeek: 'sunday',
        periodNumber: 1,
        startTime: '10:00',
        endTime: '10:45',
        isBreak: false,
        subjectId: targetSubject.id,
        teacherId: targetTeacher.id,
        roomNumber: 'Room 205',
      );

      expect(id, greaterThan(0));

      final period = await timetableService.getPeriodWithDetailsById(id);
      expect(period, isNotNull);
      expect(period!.academicYearId, activeYear.id);
      expect(period.classId, targetClass.id);
      expect(period.sectionId, targetSection.id);
      expect(period.dayOfWeek, 'sunday');
      expect(period.startTime, '10:00');
      expect(period.endTime, '10:45');
      expect(period.isBreak, false);
      expect(period.subject?.id, targetSubject.id);
      expect(period.teacher?.id, targetTeacher.id);
      expect(period.roomNumber, 'Room 205');
      expect(period.displayName, targetSubject.name);
    });

    test('Can create and retrieve a break period', () async {
      final classes = await db.getAllClassesWithSections();
      final targetClass = classes.first;

      final id = await timetableService.createPeriod(
        academicYearId: activeYear.id,
        classId: targetClass.id,
        dayOfWeek: 'Monday', // Case-insensitive input, normalized to lowercase
        periodNumber: 5,
        startTime: '13:00',
        endTime: '13:45',
        isBreak: true,
        breakTitle: 'Tiffin & Snacks Break',
        roomNumber: 'Canteen',
      );

      expect(id, greaterThan(0));

      final period = await timetableService.getPeriodWithDetailsById(id);
      expect(period, isNotNull);
      expect(period!.academicYearId, activeYear.id);
      expect(period.dayOfWeek, 'monday');
      expect(period.isBreak, true);
      expect(period.breakTitle, 'Tiffin & Snacks Break');
      expect(period.subject, isNull);
      expect(period.displayName, 'Tiffin & Snacks Break');
    });

    test('Rejects invalid day of week strings', () async {
      final classes = await db.getAllClassesWithSections();
      final targetClass = classes.first;

      // Non-existent day
      expect(
        () => timetableService.createPeriod(
          academicYearId: activeYear.id,
          classId: targetClass.id,
          dayOfWeek: 'funday',
          startTime: '10:00',
          endTime: '10:45',
          isBreak: true,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // Number string
      expect(
        () => timetableService.createPeriod(
          academicYearId: activeYear.id,
          classId: targetClass.id,
          dayOfWeek: '1',
          startTime: '10:00',
          endTime: '10:45',
          isBreak: true,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // Empty string
      expect(
        () => timetableService.createPeriod(
          academicYearId: activeYear.id,
          classId: targetClass.id,
          dayOfWeek: '  ',
          startTime: '10:00',
          endTime: '10:45',
          isBreak: true,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test(
      'Validates time sequence (startTime must be before endTime)',
      () async {
        final classes = await db.getAllClassesWithSections();
        final targetClass = classes.first;

        // Start time equal to end time
        expect(
          () => timetableService.createPeriod(
            academicYearId: activeYear.id,
            classId: targetClass.id,
            dayOfWeek: 'sunday',
            startTime: '10:00',
            endTime: '10:00',
            isBreak: true,
          ),
          throwsA(isA<ArgumentError>()),
        );

        // Start time after end time
        expect(
          () => timetableService.createPeriod(
            academicYearId: activeYear.id,
            classId: targetClass.id,
            dayOfWeek: 'sunday',
            startTime: '11:00',
            endTime: '10:00',
            isBreak: true,
          ),
          throwsA(isA<ArgumentError>()),
        );
      },
    );

    test('Validates non-break period must have a subject', () async {
      final classes = await db.getAllClassesWithSections();
      final targetClass = classes.first;

      expect(
        () => timetableService.createPeriod(
          academicYearId: activeYear.id,
          classId: targetClass.id,
          dayOfWeek: 'sunday',
          startTime: '10:00',
          endTime: '10:45',
          isBreak: false,
          subjectId: null, // Missing subject
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Can update an existing period', () async {
      final all = await timetableService.getAllPeriodsWithDetails();
      final target = all.firstWhere((p) => !p.isBreak);

      final success = await timetableService.updatePeriod(
        id: target.id,
        academicYearId: activeYear.id,
        classId: target.classId,
        sectionId: target.sectionId,
        dayOfWeek: target.dayOfWeek,
        periodNumber: target.periodNumber,
        startTime: '10:15',
        endTime: '11:05',
        isBreak: false,
        subjectId: target.subjectId,
        teacherId: target.teacherId,
        roomNumber: 'Updated Lab 1',
      );

      expect(success, true);

      final updated = await timetableService.getPeriodWithDetailsById(
        target.id,
      );
      expect(updated!.startTime, '10:15');
      expect(updated.endTime, '11:05');
      expect(updated.roomNumber, 'Updated Lab 1');
    });

    test('Can delete a period', () async {
      final all = await timetableService.getAllPeriodsWithDetails();
      final toDelete = all.first;

      final count = await timetableService.deletePeriod(toDelete.id);
      expect(count, 1);

      final check = await timetableService.getPeriodWithDetailsById(
        toDelete.id,
      );
      expect(check, isNull);
    });

    test('Filtering periods by day of week', () async {
      final sundayPeriods = await timetableService.getAllPeriodsWithDetails(
        dayOfWeek: 'sunday',
      );
      final fridayPeriods = await timetableService.getAllPeriodsWithDetails(
        dayOfWeek: 'friday',
      );

      expect(sundayPeriods, isNotEmpty);
      expect(sundayPeriods.every((p) => p.dayOfWeek == 'sunday'), true);

      expect(fridayPeriods, isNotEmpty);
      expect(fridayPeriods.every((p) => p.dayOfWeek == 'friday'), true);
    });

    test('Reactive stream updates when a period is added or deleted', () async {
      final classes = await db.getAllClassesWithSections();
      final targetClass = classes.first;

      final stream = timetableService.watchPeriodsWithDetails(
        classId: targetClass.id,
        dayOfWeek: 'sunday',
      );

      final initial = await stream.first;
      final initialCount = initial.length;

      // Add new period
      final newId = await timetableService.createPeriod(
        academicYearId: activeYear.id,
        classId: targetClass.id,
        dayOfWeek: 'sunday',
        startTime: '08:00',
        endTime: '08:45',
        isBreak: true,
        breakTitle: 'Early Morning Reading',
      );

      final afterAdd = await stream.first;
      expect(afterAdd.length, initialCount + 1);

      // Delete the period
      await timetableService.deletePeriod(newId);
      final afterDelete = await stream.first;
      expect(afterDelete.length, initialCount);
    });
  });

  group('Teacher Service CRUD Tests', () {
    test('Can create, retrieve, update, and delete a teacher', () async {
      final teacherId = await teacherService.createTeacher(
        name: 'Pradeep Adhikari',
        email: 'pradeep@school.edu.np',
        phone: '9841112233',
        designation: 'Physics Lecturer',
      );

      expect(teacherId, greaterThan(0));

      final teacher = await teacherService.getTeacherById(teacherId);
      expect(teacher, isNotNull);
      expect(teacher!.name, 'Pradeep Adhikari');
      expect(teacher.designation, 'Physics Lecturer');

      // Update
      final updateOk = await teacherService.updateTeacher(
        id: teacherId,
        name: 'Pradeep Adhikari (PhD)',
        email: 'pradeep.adhikari@school.edu.np',
        designation: 'Senior Physics Professor',
      );
      expect(updateOk, true);

      final updated = await teacherService.getTeacherById(teacherId);
      expect(updated!.name, 'Pradeep Adhikari (PhD)');
      expect(updated.designation, 'Senior Physics Professor');

      // Delete
      final deleteCount = await teacherService.deleteTeacher(teacherId);
      expect(deleteCount, 1);

      final deleted = await teacherService.getTeacherById(teacherId);
      expect(deleted, isNull);
    });

    test('Teacher validation: empty name throws ArgumentError', () async {
      expect(
        () => teacherService.createTeacher(name: '   '),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('Weekly Timetable Batch & Atomic Replacement Tests', () {
    test(
      'Can save a full weekly schedule atomically across multiple school days',
      () async {
        final classes = await db.getAllClassesWithSections();
        final targetClass = classes.first;
        final subjects = await db.getAllSubjects();
        final mathSub = subjects.firstWhere((s) => s.name.contains('Math'));
        final engSub = subjects.firstWhere((s) => s.name.contains('English'));
        final teachers = await teacherService.getAllTeachers();
        final teacher = teachers.first;

        const schoolDays = [
          'sunday',
          'monday',
          'tuesday',
          'wednesday',
          'thursday',
          'friday',
        ];
        final weeklyInputs = <WeeklyPeriodSlotInput>[];

        for (final day in schoolDays) {
          weeklyInputs.add(
            WeeklyPeriodSlotInput(
              dayOfWeek: day,
              periodNumber: 1,
              startTime: '10:00',
              endTime: '10:45',
              isBreak: false,
              subjectId: mathSub.id,
              teacherId: teacher.id,
              roomNumber: 'Room 101',
            ),
          );
          weeklyInputs.add(
            WeeklyPeriodSlotInput(
              dayOfWeek: day,
              periodNumber: 2,
              startTime: '10:45',
              endTime: '11:30',
              isBreak: false,
              subjectId: engSub.id,
              teacherId: teacher.id,
              roomNumber: 'Room 101',
            ),
          );
          weeklyInputs.add(
            const WeeklyPeriodSlotInput(
              dayOfWeek: 'sunday',
              periodNumber: 0,
              startTime: '11:30',
              endTime: '12:15',
              isBreak: true,
              breakTitle: 'Tiffin Break',
            ),
          );
        }

        await timetableService.saveWeeklyTimetable(
          academicYearId: activeYear.id,
          classId: targetClass.id,
          sectionId: null,
          periods: weeklyInputs,
        );

        final saved = await timetableService.getAllPeriodsWithDetails(
          academicYearId: activeYear.id,
          classId: targetClass.id,
        );

        // Verify all inputs are stored
        expect(saved.length, weeklyInputs.length);
        expect(
          saved.any(
            (p) => p.period.startTime == '10:00' && p.subject?.id == mathSub.id,
          ),
          true,
        );
        expect(
          saved.any(
            (p) => p.period.startTime == '10:45' && p.subject?.id == engSub.id,
          ),
          true,
        );
      },
    );

    test(
      'saveWeeklyTimetable replaces previous schedule atomically with zero leftovers',
      () async {
        final classes = await db.getAllClassesWithSections();
        final targetClass = classes.first;
        final subjects = await db.getAllSubjects();
        final sub = subjects.first;

        // 1. Initial 6 periods (1 per day)
        final firstBatch = [
          for (final day in [
            'sunday',
            'monday',
            'tuesday',
            'wednesday',
            'thursday',
            'friday',
          ])
            WeeklyPeriodSlotInput(
              dayOfWeek: day,
              periodNumber: 1,
              startTime: '09:00',
              endTime: '09:45',
              subjectId: sub.id,
            ),
        ];

        await timetableService.saveWeeklyTimetable(
          academicYearId: activeYear.id,
          classId: targetClass.id,
          sectionId: null,
          periods: firstBatch,
        );

        final count1 =
            (await timetableService.getAllPeriodsWithDetails(
              academicYearId: activeYear.id,
              classId: targetClass.id,
            )).length;
        expect(count1, 6);

        // 2. Replace with 2 periods total (only Sunday and Monday)
        final secondBatch = [
          WeeklyPeriodSlotInput(
            dayOfWeek: 'sunday',
            periodNumber: 1,
            startTime: '10:00',
            endTime: '10:45',
            subjectId: sub.id,
          ),
          WeeklyPeriodSlotInput(
            dayOfWeek: 'monday',
            periodNumber: 1,
            startTime: '10:00',
            endTime: '10:45',
            subjectId: sub.id,
          ),
        ];

        await timetableService.saveWeeklyTimetable(
          academicYearId: activeYear.id,
          classId: targetClass.id,
          sectionId: null,
          periods: secondBatch,
        );

        final updated = await timetableService.getAllPeriodsWithDetails(
          academicYearId: activeYear.id,
          classId: targetClass.id,
        );
        expect(updated.length, 2);
        expect(updated.every((p) => p.period.startTime == '10:00'), true);
      },
    );

    test('saveWeeklyTimetable rejects invalid periods', () async {
      final classes = await db.getAllClassesWithSections();
      final targetClass = classes.first;

      // Invalid start/end time
      expect(
        () => timetableService.saveWeeklyTimetable(
          academicYearId: activeYear.id,
          classId: targetClass.id,
          periods: [
            const WeeklyPeriodSlotInput(
              dayOfWeek: 'sunday',
              startTime: '11:00',
              endTime: '10:00', // start after end
              isBreak: true,
            ),
          ],
        ),
        throwsA(isA<ArgumentError>()),
      );

      // Non-break without subject
      expect(
        () => timetableService.saveWeeklyTimetable(
          academicYearId: activeYear.id,
          classId: targetClass.id,
          periods: [
            const WeeklyPeriodSlotInput(
              dayOfWeek: 'sunday',
              startTime: '10:00',
              endTime: '10:45',
              isBreak: false,
              subjectId: null, // missing subject
            ),
          ],
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('clearWeeklyTimetable empties schedule for target class', () async {
      final classes = await db.getAllClassesWithSections();
      final targetClass = classes.first;
      final subjects = await db.getAllSubjects();

      await timetableService.saveWeeklyTimetable(
        academicYearId: activeYear.id,
        classId: targetClass.id,
        periods: [
          WeeklyPeriodSlotInput(
            dayOfWeek: 'sunday',
            startTime: '10:00',
            endTime: '10:45',
            subjectId: subjects.first.id,
          ),
        ],
      );

      expect(
        (await timetableService.getAllPeriodsWithDetails(
          academicYearId: activeYear.id,
          classId: targetClass.id,
        )).length,
        1,
      );

      await timetableService.clearWeeklyTimetable(
        academicYearId: activeYear.id,
        classId: targetClass.id,
      );
      expect(
        (await timetableService.getAllPeriodsWithDetails(
          academicYearId: activeYear.id,
          classId: targetClass.id,
        )).isEmpty,
        true,
      );
    });
  });

  group('Academic Year Scoping & Copy Schedule Tests', () {
    test(
      'Timetable periods are strictly scoped to their academic year',
      () async {
        final classes = await db.getAllClassesWithSections();
        final targetClass = classes.first;
        final subjects = await db.getAllSubjects();

        // Create a second academic year
        final year2Id = await db
            .into(db.academicYears)
            .insert(
              AcademicYearsCompanion.insert(
                name: '2083/2084 BS',
                startDate: DateTime(2026, 4, 14),
                endDate: DateTime(2027, 4, 13),
                isCurrent: const Value(false),
              ),
            );

        // Save schedule for Year 1 (activeYear)
        await timetableService.saveWeeklyTimetable(
          academicYearId: activeYear.id,
          classId: targetClass.id,
          periods: [
            WeeklyPeriodSlotInput(
              dayOfWeek: 'sunday',
              startTime: '10:00',
              endTime: '10:45',
              subjectId: subjects[0].id,
            ),
            WeeklyPeriodSlotInput(
              dayOfWeek: 'monday',
              startTime: '10:00',
              endTime: '10:45',
              subjectId: subjects[1].id,
            ),
          ],
        );

        // Save completely different schedule for Year 2
        await timetableService.saveWeeklyTimetable(
          academicYearId: year2Id,
          classId: targetClass.id,
          periods: [
            WeeklyPeriodSlotInput(
              dayOfWeek: 'wednesday',
              startTime: '11:00',
              endTime: '11:45',
              subjectId: subjects[2].id,
            ),
          ],
        );

        // Query Year 1
        final year1Periods = await timetableService.getAllPeriodsWithDetails(
          academicYearId: activeYear.id,
          classId: targetClass.id,
        );
        expect(year1Periods.length, 2);
        expect(
          year1Periods.every((p) => p.academicYearId == activeYear.id),
          true,
        );

        // Query Year 2
        final year2Periods = await timetableService.getAllPeriodsWithDetails(
          academicYearId: year2Id,
          classId: targetClass.id,
        );
        expect(year2Periods.length, 1);
        expect(year2Periods.first.academicYearId, year2Id);
        expect(year2Periods.first.dayOfWeek, 'wednesday');

        // Clearing Year 1 does not affect Year 2
        await timetableService.clearWeeklyTimetable(
          academicYearId: activeYear.id,
          classId: targetClass.id,
        );
        final year1AfterClear = await timetableService.getAllPeriodsWithDetails(
          academicYearId: activeYear.id,
          classId: targetClass.id,
        );
        expect(year1AfterClear.isEmpty, true);

        final year2AfterClear = await timetableService.getAllPeriodsWithDetails(
          academicYearId: year2Id,
          classId: targetClass.id,
        );
        expect(year2AfterClear.length, 1);
      },
    );

    test(
      'copyTimetableFromYear clones all periods to target session',
      () async {
        final classes = await db.getAllClassesWithSections();
        final targetClass = classes.first;
        final subjects = await db.getAllSubjects();

        // Create target year
        final targetYearId = await db
            .into(db.academicYears)
            .insert(
              AcademicYearsCompanion.insert(
                name: '2084/2085 BS',
                startDate: DateTime(2027, 4, 14),
                endDate: DateTime(2028, 4, 13),
                isCurrent: const Value(false),
              ),
            );

        // Setup source periods in activeYear
        await timetableService.saveWeeklyTimetable(
          academicYearId: activeYear.id,
          classId: targetClass.id,
          periods: [
            WeeklyPeriodSlotInput(
              dayOfWeek: 'sunday',
              startTime: '10:00',
              endTime: '10:45',
              subjectId: subjects[0].id,
            ),
            WeeklyPeriodSlotInput(
              dayOfWeek: 'sunday',
              startTime: '10:45',
              endTime: '11:30',
              isBreak: true,
              breakTitle: 'Recess',
            ),
          ],
        );

        // Copy to target year
        final copiedCount = await timetableService.copyTimetableFromYear(
          sourceAcademicYearId: activeYear.id,
          targetAcademicYearId: targetYearId,
        );

        expect(copiedCount, greaterThanOrEqualTo(2));

        final targetPeriods = await timetableService.getAllPeriodsWithDetails(
          academicYearId: targetYearId,
          classId: targetClass.id,
        );
        expect(targetPeriods.length, 2);
        expect(
          targetPeriods.every((p) => p.academicYearId == targetYearId),
          true,
        );
        expect(
          targetPeriods.any((p) => p.isBreak && p.breakTitle == 'Recess'),
          true,
        );
        expect(
          targetPeriods.any(
            (p) => !p.isBreak && p.subject?.id == subjects[0].id,
          ),
          true,
        );
      },
    );
  });
}
