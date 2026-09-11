import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sms/data/app_database.dart';
import 'package:sms/data/database_seeder.dart';
import 'package:sms/services/academic_year_service.dart';
import 'package:sms/utils/date_time_utils.dart';

void main() {
  late AppDatabase db;
  late AcademicYearService service;

  setUp(() {
    // In-memory Drift database for isolated testing
    db = AppDatabase(NativeDatabase.memory());
    service = AcademicYearService(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('Academic Year Database & Service Tests', () {
    test(
      'Has default seeded records (2024-2025, 2025-2026, 2026-2027, 2027-2028, 2029-2030)',
      () async {
        final all = await service.getAllAcademicYears();
        expect(all.length, 5);

        final names = all.map((e) => e.name).toList();
        expect(
          names,
          containsAll([
            '2024-2025',
            '2025-2026',
            '2026-2027',
            '2027-2028',
            '2029-2030',
          ]),
        );

        final active = await service.getCurrentAcademicYear();
        expect(active?.name, '2026-2027');
        expect(active?.isCurrent, true);
      },
    );

    test('Can insert and retrieve academic years', () async {
      final start = DateTime(2024, 4, 13);
      final end = DateTime(2025, 4, 12);

      final id = await service.createAcademicYear(
        name: '2081/82 BS',
        startDate: start,
        endDate: end,
        isCurrent: true,
        description: 'Academic session 2081/82',
      );

      expect(id, greaterThan(0));

      final all = await service.getAllAcademicYears();
      expect(all.length, 6); // 5 seeded + 1 newly inserted

      final inserted = all.firstWhere((y) => y.id == id);
      expect(inserted.name, '2081/82 BS');
      expect(inserted.isCurrent, true);
      // Verify date is stored in AD and converted on-the-fly to BS
      expect(DateTimeUtils.adToBs(inserted.startDate).year, 2081);
    });

    test('Validates that end date cannot be before start date', () async {
      final start = DateTime(2024, 4, 13);
      final end = DateTime(2023, 4, 13); // Invalid end date

      expect(
        () => service.createAcademicYear(
          name: 'Invalid Session',
          startDate: start,
          endDate: end,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Only ONE academic year can be active at any given time', () async {
      // Initially, 2026-2027 is active
      var active = await service.getCurrentAcademicYear();
      expect(active?.name, '2026-2027');

      // 1. Create a new active session -> should deactivate 2026-2027
      final idNew = await service.createAcademicYear(
        name: '2030-2031',
        startDate: DateTime(2030, 4, 14),
        endDate: DateTime(2031, 4, 13),
        isCurrent: true,
      );

      active = await service.getCurrentAcademicYear();
      expect(active?.id, idNew);
      expect(active?.name, '2030-2031');

      // Check previously active session is now inactive
      final all = await service.getAllAcademicYears();
      final previousActive = all.firstWhere((y) => y.name == '2026-2027');
      expect(previousActive.isCurrent, false);

      // 2. Set 2026-2027 as active again using setActiveYear
      await service.setActiveYear(previousActive.id);
      active = await service.getCurrentAcademicYear();
      expect(active?.id, previousActive.id);
      expect(active?.name, '2026-2027');

      final sessionNew = (await service.getAllAcademicYears()).firstWhere(
        (y) => y.id == idNew,
      );
      expect(sessionNew.isCurrent, false);
    });

    test('Can update an academic year', () async {
      final id = await service.createAcademicYear(
        name: '2028-2029',
        startDate: DateTime(2028, 4, 14),
        endDate: DateTime(2029, 4, 13),
        isCurrent: false,
      );

      final updated = await service.updateAcademicYear(
        id: id,
        name: '2028-2029 Updated',
        startDate: DateTime(2028, 4, 14),
        endDate: DateTime(2029, 4, 13),
        isCurrent: false,
        description: 'Updated description',
      );

      expect(updated, true);

      final all = await service.getAllAcademicYears();
      final year = all.firstWhere((y) => y.id == id);
      expect(year.name, '2028-2029 Updated');
      expect(year.description, 'Updated description');
    });

    test('Can delete an academic year', () async {
      final id = await service.createAcademicYear(
        name: '2031-2032',
        startDate: DateTime(2031, 4, 14),
        endDate: DateTime(2032, 4, 13),
        isCurrent: false,
      );

      var list = await service.getAllAcademicYears();
      expect(list.length, 6);

      final deleted = await service.deleteAcademicYear(id);
      expect(deleted, 1);

      list = await service.getAllAcademicYears();
      expect(list.length, 5);
      expect(list.any((y) => y.id == id), false);
    });

    test('Reactive stream updates when academic year changes', () async {
      final initial = await service.watchAcademicYears().first;
      expect(initial.length, 5); // 5 seeded records

      final futureList = service.watchAcademicYears().skip(1).first;

      await service.createAcademicYear(
        name: '2032-2033',
        startDate: DateTime(2032, 4, 14),
        endDate: DateTime(2033, 4, 13),
      );

      final updatedList = await futureList;
      expect(updatedList.length, 6);
    });

    test('DatabaseSeeder is idempotent (does not duplicate records)', () async {
      final initialCount = (await db.getAllAcademicYears()).length;
      expect(initialCount, 5);

      // Calling seedIfEmpty when not empty does not add duplicates
      await DatabaseSeeder.seedIfEmpty(db);
      final afterSecondCall = (await db.getAllAcademicYears()).length;
      expect(afterSecondCall, 5);
    });
  });
}
