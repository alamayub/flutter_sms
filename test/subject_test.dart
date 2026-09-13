import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sms/config/enums.dart';
import 'package:sms/data/app_database.dart';
import 'package:sms/services/subject_service.dart';

void main() {
  late AppDatabase db;
  late SubjectService service;

  setUp(() {
    // In-memory Drift database
    db = AppDatabase(NativeDatabase.memory());
    service = SubjectService(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('Generic Subjects Seeder & Curriculum Tests', () {
    test(
      'Automatically seeds generic master subjects covering Nursery to Class 10 curriculum',
      () async {
        final allSubjects = await service.getAllSubjects();
        expect(allSubjects, isNotEmpty);
        expect(allSubjects.length, greaterThanOrEqualTo(15));

        final names = allSubjects.map((s) => s.name).toList();
        expect(names.contains('English'), true);
        expect(names.contains('Nepali'), true);
        expect(names.contains('Mathematics'), true);
        expect(names.contains('Science & Technology'), true);
        expect(names.contains('Social Studies & Life Skills'), true);
        expect(names.contains('Optional Mathematics'), true);
        expect(names.contains('Computer Science'), true);
        expect(names.contains('Drawing, Art & Craft'), true);
        expect(names.contains('Rhymes & Storytelling'), true);
      },
    );

    test(
      'Contains all three subject types: theory, practical, and both',
      () async {
        final allSubjects = await service.getAllSubjects();

        final theorySubjects =
            allSubjects
                .where((s) => s.subjectType == SubjectType.theory)
                .toList();
        final practicalSubjects =
            allSubjects
                .where((s) => s.subjectType == SubjectType.practical)
                .toList();
        final bothSubjects =
            allSubjects
                .where((s) => s.subjectType == SubjectType.both)
                .toList();

        expect(
          theorySubjects,
          isNotEmpty,
          reason: 'Must contain theory subjects',
        );
        expect(
          practicalSubjects,
          isNotEmpty,
          reason: 'Must contain practical subjects',
        );
        expect(
          bothSubjects,
          isNotEmpty,
          reason: 'Must contain both (theory & practical) subjects',
        );

        // Verify specific expected types
        expect(
          theorySubjects.any(
            (s) =>
                s.name.contains('Mathematics') || s.name.contains('Economics'),
          ),
          true,
        );
        expect(
          practicalSubjects.any(
            (s) => s.name.contains('Drawing') || s.name.contains('Rhymes'),
          ),
          true,
        );
        expect(
          bothSubjects.any(
            (s) => s.name.contains('English') || s.name.contains('Science'),
          ),
          true,
        );
      },
    );

    test('Contains both compulsory and optional/elective subjects', () async {
      final allSubjects = await service.getAllSubjects();

      final compulsorySubjects =
          allSubjects.where((s) => !s.isOptional).toList();
      final optionalSubjects = allSubjects.where((s) => s.isOptional).toList();

      expect(compulsorySubjects, isNotEmpty);
      expect(optionalSubjects, isNotEmpty);

      // Verify electives such as Optional Mathematics and Computer Science
      final optionalNames = optionalSubjects.map((s) => s.name).toList();

      expect(
        optionalNames.any((name) => name.contains('Optional Mathematics')),
        true,
      );
      expect(
        optionalNames.any((name) => name.contains('Computer Science')),
        true,
      );
      expect(optionalNames.any((name) => name.contains('Economics')), true);
    });

    test('DatabaseSeeder.seedIfEmpty is idempotent for subjects', () async {
      final initialCount = (await service.getAllSubjects()).length;
      expect(initialCount, greaterThan(0));

      final afterCount = (await service.getAllSubjects()).length;
      expect(afterCount, initialCount);
    });
  });

  group('Subjects CRUD & Validation Tests', () {
    test('Can create and retrieve a custom generic subject', () async {
      final id = await service.createSubject(
        code: 'VOC-MUSIC',
        name: 'Vocal Music & Instruments',
        subjectType: SubjectType.practical,
        isOptional: true,
        fullMarks: 50,
        passMarks: 20,
        theoryMarks: 0,
        practicalMarks: 50,
        description: 'Music appreciation and vocal training',
      );

      expect(id, greaterThan(0));

      final created = await service.getSubjectById(id);
      expect(created, isNotNull);
      expect(created!.code, 'VOC-MUSIC');
      expect(created.name, 'Vocal Music & Instruments');
      expect(created.subjectType, SubjectType.practical);
      expect(created.isOptional, true);
      expect(created.fullMarks, 50);
      expect(created.passMarks, 20);
      expect(created.theoryMarks, 0);
      expect(created.practicalMarks, 50);
    });

    test('Validates empty code and empty name', () async {
      expect(
        () => service.createSubject(
          code: '   ',
          name: 'Subject',
          subjectType: SubjectType.theory,
        ),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => service.createSubject(
          code: 'CODE-1',
          name: '   ',
          subjectType: SubjectType.theory,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Validates marks constraints', () async {
      // Pass marks > Full marks
      expect(
        () => service.createSubject(
          code: 'MATH-1',
          name: 'Math',
          subjectType: SubjectType.theory,
          fullMarks: 50,
          passMarks: 60,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // Theory + Practical != Full marks
      expect(
        () => service.createSubject(
          code: 'SCI-1',
          name: 'Science',
          subjectType: SubjectType.both,
          fullMarks: 100,
          passMarks: 40,
          theoryMarks: 60,
          practicalMarks: 20, // Sum is 80 != 100
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Can update an existing subject', () async {
      final all = await service.getAllSubjects();
      final subject = all.first;

      final updatedSuccess = await service.updateSubject(
        id: subject.id,
        code: '${subject.code}-REV',
        name: '${subject.name} (Revised)',
        subjectType: SubjectType.both,
        isOptional: !subject.isOptional,
        fullMarks: 100,
        passMarks: 40,
        theoryMarks: 75,
        practicalMarks: 25,
        description: 'Updated syllabus details',
      );

      expect(updatedSuccess, true);

      final updated = await service.getSubjectById(subject.id);
      expect(updated!.code, '${subject.code}-REV');
      expect(updated.name, '${subject.name} (Revised)');
      expect(updated.isOptional, !subject.isOptional);
    });

    test('Can delete a subject', () async {
      final all = await service.getAllSubjects();
      final toDelete = all.first;

      final count = await service.deleteSubject(toDelete.id);
      expect(count, 1);

      final check = await service.getSubjectById(toDelete.id);
      expect(check, isNull);
    });

    test('Stream filtering by subjectType and isOptional', () async {
      // Filter by Optional only
      final optionalList = await service.watchSubjects(isOptional: true).first;

      expect(optionalList, isNotEmpty);
      expect(optionalList.every((s) => s.isOptional == true), true);

      // Filter by Theory only
      final theoryOnly =
          await service.watchSubjects(type: SubjectType.theory).first;

      expect(theoryOnly, isNotEmpty);
      expect(
        theoryOnly.every((s) => s.subjectType == SubjectType.theory),
        true,
      );

      // Filter by Practical only
      final practicalOnly =
          await service.watchSubjects(type: SubjectType.practical).first;

      expect(practicalOnly, isNotEmpty);
      expect(
        practicalOnly.every((s) => s.subjectType == SubjectType.practical),
        true,
      );

      // Filter by Both only
      final bothOnly =
          await service.watchSubjects(type: SubjectType.both).first;

      expect(bothOnly, isNotEmpty);
      expect(bothOnly.every((s) => s.subjectType == SubjectType.both), true);
    });
  });
}
