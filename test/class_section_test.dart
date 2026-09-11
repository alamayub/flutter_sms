import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sms/data/app_database.dart';
import 'package:sms/data/database_seeder.dart';
import 'package:sms/services/class_section_service.dart';

void main() {
  late AppDatabase db;
  late ClassSectionService service;

  setUp(() {
    // Isolated in-memory Drift database instance
    db = AppDatabase(NativeDatabase.memory());
    service = ClassSectionService(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('Classes & Sections Seeder Tests', () {
    test(
      'Automatically seeds Nursery, LKG, UKG, and Class 1 through Class 10 with 3 sections (A, B, C) each',
      () async {
        final classes = await service.getAllClassesWithSections();

        // 13 classes seeded (Nursery, LKG, UKG + Class 1 to 10)
        expect(classes.length, 13);

        // Verify pre-primary classes
        final nursery = classes.firstWhere((c) => c.name == 'Nursery');
        expect(nursery.displayName, 'Nursery');
        expect(nursery.orderIndex, 1);
        expect(nursery.sections.length, 3);

        final lkg = classes.firstWhere((c) => c.name == 'LKG');
        expect(lkg.displayName, contains('Lower Kindergarten'));
        expect(lkg.orderIndex, 2);
        expect(lkg.sections.length, 3);

        final ukg = classes.firstWhere((c) => c.name == 'UKG');
        expect(ukg.displayName, contains('Upper Kindergarten'));
        expect(ukg.orderIndex, 3);
        expect(ukg.sections.length, 3);

        // Verify each class 1 to 10 has exact names and 3 sections
        for (int i = 1; i <= 10; i++) {
          final c = classes.firstWhere((item) => item.name == 'Class $i');
          expect(c.displayName, 'Grade $i');
          expect(c.orderIndex, i + 3);
          expect(c.sections.length, 3);
          final sectionNames = c.sections.map((s) => s.name).toList()..sort();
          expect(sectionNames, ['A', 'B', 'C']);
        }

        // Total sections across all 13 classes should be 39
        final totalSections = classes.fold<int>(
          0,
          (sum, c) => sum + c.sections.length,
        );
        expect(totalSections, 39);
      },
    );

    test(
      'DatabaseSeeder.seedIfEmpty is idempotent for classes and sections',
      () async {
        final initialCount = (await service.getAllClassesWithSections()).length;
        expect(initialCount, 13);

        // Re-running seeder should not duplicate
        await DatabaseSeeder.seedIfEmpty(db);
        final afterCount = (await service.getAllClassesWithSections()).length;
        expect(afterCount, 13);
      },
    );
  });

  group('Classes & Sections CRUD & Dynamic Section Management', () {
    test('Can create a new class with custom sections', () async {
      final newId = await service.createClass(
        name: 'Class 11',
        displayName: 'Grade 11 Science',
        orderIndex: 11,
        sections: ['Physics', 'Biology', 'Maths'],
      );

      expect(newId, greaterThan(0));

      final created = await service.getClassWithSectionsById(newId);
      expect(created, isNotNull);
      expect(created!.name, 'Class 11');
      expect(created.displayName, 'Grade 11 Science');
      expect(created.orderIndex, 11);
      expect(created.sections.length, 3);

      final sectionNames = created.sections.map((s) => s.name).toList();
      expect(sectionNames, containsAll(['Physics', 'Biology', 'Maths']));
    });

    test('Validates that class name cannot be empty', () async {
      expect(
        () => service.createClass(name: '   ', displayName: 'Blank'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Can dynamically add a section to an existing class', () async {
      final classes = await service.getAllClassesWithSections();
      final class1 = classes.firstWhere((c) => c.name == 'Class 1');
      expect(class1.sections.length, 3);

      // Add section 'D'
      final newSecId = await service.addSection(
        classId: class1.id,
        name: 'D',
        roomNumber: '104',
        capacity: 35,
      );

      expect(newSecId, greaterThan(0));

      final updatedClass1 = await service.getClassWithSectionsById(class1.id);
      expect(updatedClass1!.sections.length, 4);
      expect(updatedClass1.sections.any((s) => s.name == 'D'), true);
    });

    test('Can dynamically delete a section from a class', () async {
      final classes = await service.getAllClassesWithSections();
      final class2 = classes.firstWhere((c) => c.name == 'Class 2');
      final sectionToDelete = class2.sections.firstWhere((s) => s.name == 'C');

      final deletedRows = await service.deleteSection(sectionToDelete.id);
      expect(deletedRows, 1);

      final updatedClass2 = await service.getClassWithSectionsById(class2.id);
      expect(updatedClass2!.sections.length, 2);
      expect(updatedClass2.sections.any((s) => s.name == 'C'), false);
    });

    test('Can update class details and synchronize sections', () async {
      final classes = await service.getAllClassesWithSections();
      final class3 = classes.firstWhere((c) => c.name == 'Class 3');

      // Update name, display name, and change sections to ['A', 'D'] (removes B and C, adds D)
      await service.updateClass(
        id: class3.id,
        name: 'Class 3 (Senior)',
        displayName: 'Standard 3',
        orderIndex: 3,
        sections: ['A', 'D'],
      );

      final updated = await service.getClassWithSectionsById(class3.id);
      expect(updated!.name, 'Class 3 (Senior)');
      expect(updated.displayName, 'Standard 3');
      expect(updated.sections.length, 2);

      final sectionNames = updated.sections.map((s) => s.name).toList();
      expect(sectionNames, containsAll(['A', 'D']));
      expect(sectionNames.contains('B'), false);
      expect(sectionNames.contains('C'), false);
    });

    test('Deleting a class cascades and deletes all its sections', () async {
      final classes = await service.getAllClassesWithSections();
      final class10 = classes.firstWhere((c) => c.name == 'Class 10');
      final class10Id = class10.id;

      // Class 10 initially has 3 sections
      expect(class10.sections.length, 3);

      // Delete Class 10
      final deleted = await service.deleteClass(class10Id);
      expect(deleted, 1);

      // Class should not exist
      final retrieved = await service.getClassWithSectionsById(class10Id);
      expect(retrieved, isNull);

      // All classes count should be 12 (13 initial - 1)
      final remainingClasses = await service.getAllClassesWithSections();
      expect(remainingClasses.length, 12);
      expect(remainingClasses.any((c) => c.id == class10Id), false);
    });

    test(
      'Reactive stream watchClassesWithSections emits updates when modified',
      () async {
        final initial = await service.watchClassesWithSections().first;
        expect(initial.length, 13);

        final futureClasses = service.watchClassesWithSections().skip(1).first;

        await service.createClass(
          name: 'Class 11',
          displayName: 'Grade 11',
          orderIndex: 14,
          sections: ['A'],
        );

        final updated = await futureClasses;
        expect(updated.length, 14);
      },
    );
  });
}
