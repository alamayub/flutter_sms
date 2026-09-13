import 'package:drift/drift.dart';

import '../config/enums.dart';
import 'app_database.dart';

/// Seeds master data required for a new installation.
class DatabaseSeeder {
  static Future<void> seedIfEmpty(AppDatabase db) async {
    if ((await db.getAllAcademicYears()).isEmpty) {
      await seedAcademicYears(db);
    }
    if ((await db.getAllClassesWithSections()).isEmpty) {
      await seedClassesAndSections(db);
    }
    if ((await db.getAllSubjects()).isEmpty) {
      await seedSubjects(db);
    }
    await seedFeeCategories(db);
  }

  /// Seeds common fee heads used by schools in Nepal.
  ///
  /// Amounts intentionally start at zero because each school configures its
  /// own rates. These are categories only; no student fee records are created.
  static Future<void> seedFeeCategories(AppDatabase db) async {
    const categories = [
      (
        name: 'Admission Fee',
        frequency: 'one_time',
        description: 'New student admission and enrollment charge',
      ),
      (
        name: 'Registration / Application Fee',
        frequency: 'one_time',
        description: 'Application, entrance, or registration processing fee',
      ),
      (
        name: 'Monthly Tuition / School Fee',
        frequency: 'monthly',
        description: 'Regular monthly tuition and school charges',
      ),
      (
        name: 'Annual / Development Fee',
        frequency: 'yearly',
        description: 'Annual development and institutional charges',
      ),
      (
        name: 'Transport Fee',
        frequency: 'monthly',
        description: 'School bus or van transportation service',
      ),
      (
        name: 'Transport Registration Fee',
        frequency: 'one_time',
        description: 'One-time school transport registration charge',
      ),
      (
        name: 'Hostel / Boarding Fee',
        frequency: 'monthly',
        description: 'Hostel accommodation and boarding charge',
      ),
      (
        name: 'Hostel Admission Fee',
        frequency: 'one_time',
        description: 'One-time hostel enrollment charge',
      ),
      (
        name: 'Meal / Mess Fee',
        frequency: 'monthly',
        description: 'Student meal and mess service charge',
      ),
      (
        name: 'Library Fee',
        frequency: 'yearly',
        description: 'Library access, books, and catalogue services',
      ),
      (
        name: 'Computer / ICT Fee',
        frequency: 'yearly',
        description: 'Computer lab, ICT, and digital learning services',
      ),
      (
        name: 'Science Lab Fee',
        frequency: 'yearly',
        description: 'Science laboratory and practical materials',
      ),
      (
        name: 'Examination Fee',
        frequency: 'term_wise',
        description: 'Terminal, annual, and examination administration charge',
      ),
      (
        name: 'Internal Assessment Fee',
        frequency: 'term_wise',
        description: 'Internal assessment, practical, and evaluation charge',
      ),
      (
        name: 'Books & Stationery Fee',
        frequency: 'yearly',
        description: 'Textbooks, notebooks, copies, and stationery',
      ),
      (
        name: 'Uniform / Dress Fee',
        frequency: 'one_time',
        description: 'School uniform, dress, badge, and accessories',
      ),
      (
        name: 'Sports Fee',
        frequency: 'yearly',
        description: 'Sports activities, equipment, and annual sports meet',
      ),
      (
        name: 'Extra-Curricular Activities Fee',
        frequency: 'yearly',
        description: 'Clubs, cultural programs, and co-curricular activities',
      ),
      (
        name: 'Educational Tour / Field Trip Fee',
        frequency: 'one_time',
        description: 'Educational tour, excursion, or field trip charge',
      ),
      (
        name: 'Student ID Card Fee',
        frequency: 'one_time',
        description: 'Student identity card and replacement card charge',
      ),
      (
        name: 'School Diary Fee',
        frequency: 'yearly',
        description: 'Annual student diary and communication book',
      ),
      (
        name: 'Medical / Health Fee',
        frequency: 'yearly',
        description: 'Basic health, first-aid, and medical support services',
      ),
      (
        name: 'Security Deposit',
        frequency: 'one_time',
        description: 'Refundable school or hostel security deposit',
      ),
      (
        name: 'Late Fee / Fine',
        frequency: 'one_time',
        description: 'Late payment or administrative fine',
      ),
    ];

    final existing = await db.getAllFeeCategories();
    for (final category in categories) {
      final alreadyExists = existing.any(
        (item) => item.name.toLowerCase() == category.name.toLowerCase(),
      );
      if (alreadyExists) continue;

      await db.insertFeeCategory(
        FeeCategoriesCompanion(
          name: Value(category.name),
          frequency: Value(category.frequency),
          defaultAmount: const Value(0.0),
          description: Value(category.description),
          isSystem: const Value(true),
        ),
      );
    }
  }

  static Future<void> seedSubjects(AppDatabase db) async {
    const subjects = [
      SubjectsCompanion(
        code: Value('ENG'),
        name: Value('English'),
        subjectType: Value(SubjectType.both),
        theoryMarks: Value(75),
        practicalMarks: Value(25),
        description: Value('English Language & Literature'),
      ),
      SubjectsCompanion(
        code: Value('NEP'),
        name: Value('Nepali'),
        subjectType: Value(SubjectType.both),
        theoryMarks: Value(75),
        practicalMarks: Value(25),
        description: Value('Nepali Language & Literature'),
      ),
      SubjectsCompanion(
        code: Value('MTH'),
        name: Value('Mathematics'),
        subjectType: Value(SubjectType.theory),
        theoryMarks: Value(100),
        practicalMarks: Value(0),
      ),
      SubjectsCompanion(
        code: Value('SCI'),
        name: Value('Science & Technology'),
        subjectType: Value(SubjectType.both),
        theoryMarks: Value(75),
        practicalMarks: Value(25),
      ),
      SubjectsCompanion(
        code: Value('SOC'),
        name: Value('Social Studies & Life Skills'),
        subjectType: Value(SubjectType.both),
        theoryMarks: Value(75),
        practicalMarks: Value(25),
      ),
      SubjectsCompanion(
        code: Value('HPE'),
        name: Value('Health, Physical & Moral Education'),
        subjectType: Value(SubjectType.both),
        theoryMarks: Value(50),
        practicalMarks: Value(50),
      ),
      SubjectsCompanion(
        code: Value('OBT'),
        name: Value('Occupation, Business & Technology'),
        subjectType: Value(SubjectType.both),
        theoryMarks: Value(50),
        practicalMarks: Value(50),
      ),
      SubjectsCompanion(
        code: Value('DRW'),
        name: Value('Drawing, Art & Craft'),
        subjectType: Value(SubjectType.practical),
        fullMarks: Value(50),
        passMarks: Value(20),
        theoryMarks: Value(0),
        practicalMarks: Value(50),
      ),
      SubjectsCompanion(
        code: Value('RHY'),
        name: Value('Rhymes & Storytelling'),
        subjectType: Value(SubjectType.practical),
        fullMarks: Value(50),
        passMarks: Value(20),
        theoryMarks: Value(0),
        practicalMarks: Value(50),
      ),
      SubjectsCompanion(
        code: Value('GK'),
        name: Value('General Knowledge & Awareness'),
        subjectType: Value(SubjectType.both),
        fullMarks: Value(50),
        passMarks: Value(20),
        theoryMarks: Value(25),
        practicalMarks: Value(25),
      ),
      SubjectsCompanion(
        code: Value('ENV'),
        name: Value('My Surroundings & Environment'),
        subjectType: Value(SubjectType.both),
        theoryMarks: Value(60),
        practicalMarks: Value(40),
      ),
      SubjectsCompanion(
        code: Value('OPTMTH'),
        name: Value('Optional Mathematics'),
        subjectType: Value(SubjectType.theory),
        isOptional: Value(true),
        theoryMarks: Value(100),
        practicalMarks: Value(0),
      ),
      SubjectsCompanion(
        code: Value('COM'),
        name: Value('Computer Science'),
        subjectType: Value(SubjectType.both),
        isOptional: Value(true),
        theoryMarks: Value(50),
        practicalMarks: Value(50),
      ),
      SubjectsCompanion(
        code: Value('ECO'),
        name: Value('Economics'),
        subjectType: Value(SubjectType.theory),
        isOptional: Value(true),
        theoryMarks: Value(100),
        practicalMarks: Value(0),
      ),
      SubjectsCompanion(
        code: Value('ACC'),
        name: Value('Accountancy & Office Management'),
        subjectType: Value(SubjectType.both),
        isOptional: Value(true),
        theoryMarks: Value(75),
        practicalMarks: Value(25),
      ),
      SubjectsCompanion(
        code: Value('SAN'),
        name: Value('Sanskrit Language'),
        subjectType: Value(SubjectType.theory),
        isOptional: Value(true),
        theoryMarks: Value(100),
        practicalMarks: Value(0),
      ),
      SubjectsCompanion(
        code: Value('MUS'),
        name: Value('Music & Performing Arts'),
        subjectType: Value(SubjectType.practical),
        isOptional: Value(true),
        fullMarks: Value(50),
        passMarks: Value(20),
        theoryMarks: Value(0),
        practicalMarks: Value(50),
      ),
    ];

    for (final subject in subjects) {
      await db.insertSubject(subject);
    }
  }

  static Future<void> seedClassesAndSections(AppDatabase db) async {
    final classes = [
      ('Nursery', 'Nursery'),
      ('LKG', 'LKG (Lower Kindergarten)'),
      ('UKG', 'UKG (Upper Kindergarten)'),
      ...List.generate(
        10,
        (index) => ('Class ${index + 1}', 'Grade ${index + 1}'),
      ),
    ];

    for (var index = 0; index < classes.length; index++) {
      final (name, displayName) = classes[index];
      await db.insertClassWithSections(
        classCompanion: SchoolClassesCompanion(
          name: Value(name),
          displayName: Value(displayName),
          orderIndex: Value(index + 1),
        ),
        sectionNames: const ['A', 'B', 'C'],
      );
    }
  }

  static Future<void> seedAcademicYears(AppDatabase db) async {
    final records = [
      AcademicYearsCompanion(
        name: const Value('2026-2027'),
        startDate: Value(DateTime(2026, 4, 14)),
        endDate: Value(DateTime(2027, 4, 13)),
        isCurrent: const Value(true),
        description: const Value('Academic Session 2026-2027'),
      ),
      AcademicYearsCompanion(
        name: const Value('2027-2028'),
        startDate: Value(DateTime(2027, 4, 14)),
        endDate: Value(DateTime(2028, 4, 13)),
        description: const Value('Academic Session 2027-2028'),
      ),
      AcademicYearsCompanion(
        name: const Value('2029-2030'),
        startDate: Value(DateTime(2029, 4, 14)),
        endDate: Value(DateTime(2030, 4, 13)),
        description: const Value('Academic Session 2029-2030'),
      ),
    ];

    for (final record in records) {
      await db.insertAcademicYear(record);
    }
  }
}
