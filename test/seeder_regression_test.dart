import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:sms/data/app_database.dart';
import 'package:sms/data/database_seeder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('DatabaseSeeder seeds students cleanly even when older years are initially missing', () async {
    // Simulate an older database state where only 2026-2027 existed
    await db.insertAcademicYear(
      AcademicYearsCompanion(
        name: const Value('2026-2027'),
        startDate: Value(DateTime(2026, 4, 14)),
        endDate: Value(DateTime(2027, 4, 13)),
        isCurrent: const Value(true),
      ),
    );

    // Run seedIfEmpty: it should backfill 2024-2025 & 2025-2026, classes, subjects, employees, timetable, contacts, and students without constraint errors
    await DatabaseSeeder.seedIfEmpty(db);

    final students = await db.getAllStudents();
    expect(students.length, greaterThanOrEqualTo(5));

    final histories = await db.select(db.studentAcademicHistories).get();
    expect(histories.length, greaterThanOrEqualTo(5));

    // Rohan should have 3 distinct histories in 3 distinct academic years
    final rohan = students.firstWhere((s) => s.studentId == '20260001');
    final rohanHistories = histories.where((h) => h.studentId == rohan.id).toList();
    expect(rohanHistories.length, 3);
    final yearIds = rohanHistories.map((h) => h.academicYearId).toSet();
    expect(yearIds.length, 3, reason: 'All 3 histories must have distinct academicYearIds');

    // Run seedIfEmpty again to verify idempotency
    await DatabaseSeeder.seedIfEmpty(db);
    final studentsAfter = await db.getAllStudents();
    expect(studentsAfter.length, students.length);
  });
}
