import 'package:drift/drift.dart';
import 'app_database.dart';

class DatabaseSeeder {
  /// Seeds initial data if the academic years or classes tables are currently empty
  static Future<void> seedIfEmpty(AppDatabase db) async {
    final existingYears = await db.getAllAcademicYears();
    if (existingYears.isEmpty) {
      await seedAcademicYears(db);
    } else {
      // In an existing database upgraded to v11, 2024-2025 and 2025-2026 might be missing
      final yearNames = existingYears.map((y) => y.name).toSet();
      if (!yearNames.contains('2024-2025')) {
        await db.insertAcademicYear(
          AcademicYearsCompanion(
            name: const Value('2024-2025'),
            startDate: Value(DateTime(2024, 4, 14)),
            endDate: Value(DateTime(2025, 4, 13)),
            isCurrent: const Value(false),
            description: const Value('Academic Session 2024-2025'),
          ),
        );
      }
      if (!yearNames.contains('2025-2026')) {
        await db.insertAcademicYear(
          AcademicYearsCompanion(
            name: const Value('2025-2026'),
            startDate: Value(DateTime(2025, 4, 14)),
            endDate: Value(DateTime(2026, 4, 13)),
            isCurrent: const Value(false),
            description: const Value('Academic Session 2025-2026'),
          ),
        );
      }
    }
    final existingClasses = await db.getAllClassesWithSections();
    if (existingClasses.isEmpty) {
      await seedClassesAndSections(db);
    } else {
      // If classes exist but Nursery, LKG, UKG are missing, backfill them
      final names = existingClasses.map((c) => c.name.toLowerCase()).toSet();
      if (!names.contains('nursery') && !names.contains('nursary')) {
        await db.insertClassWithSections(
          classCompanion: const SchoolClassesCompanion(
            name: Value('Nursery'),
            displayName: Value('Nursery'),
            orderIndex: Value(1),
          ),
          sectionNames: const ['A', 'B', 'C'],
        );
      }
      if (!names.contains('lkg')) {
        await db.insertClassWithSections(
          classCompanion: const SchoolClassesCompanion(
            name: Value('LKG'),
            displayName: Value('LKG (Lower Kindergarten)'),
            orderIndex: Value(2),
          ),
          sectionNames: const ['A', 'B', 'C'],
        );
      }
      if (!names.contains('ukg')) {
        await db.insertClassWithSections(
          classCompanion: const SchoolClassesCompanion(
            name: Value('UKG'),
            displayName: Value('UKG (Upper Kindergarten)'),
            orderIndex: Value(3),
          ),
          sectionNames: const ['A', 'B', 'C'],
        );
      }
    }

    final existingSubjects = await db.getAllSubjects();
    if (existingSubjects.isEmpty) {
      await seedSubjects(db);
    }
  }

  /// Seeds generic curriculum subjects covering pre-primary to class 10 with types and optional flags
  static Future<void> seedSubjects(AppDatabase db) async {
    final genericSubjects = [
      // Core Compulsory Subjects
      const SubjectsCompanion(
        code: Value('ENG'),
        name: Value('English'),
        subjectType: Value(SubjectType.both),
        isOptional: Value(false),
        fullMarks: Value(100),
        passMarks: Value(40),
        theoryMarks: Value(75),
        practicalMarks: Value(25),
        description: Value('English Language & Literature'),
      ),
      const SubjectsCompanion(
        code: Value('NEP'),
        name: Value('Nepali'),
        subjectType: Value(SubjectType.both),
        isOptional: Value(false),
        fullMarks: Value(100),
        passMarks: Value(40),
        theoryMarks: Value(75),
        practicalMarks: Value(25),
        description: Value('नेपाली भाषा तथा साहित्य'),
      ),
      const SubjectsCompanion(
        code: Value('MTH'),
        name: Value('Mathematics'),
        subjectType: Value(SubjectType.theory),
        isOptional: Value(false),
        fullMarks: Value(100),
        passMarks: Value(40),
        theoryMarks: Value(100),
        practicalMarks: Value(0),
        description: Value('General & Compulsory Mathematics'),
      ),
      const SubjectsCompanion(
        code: Value('SCI'),
        name: Value('Science & Technology'),
        subjectType: Value(SubjectType.both),
        isOptional: Value(false),
        fullMarks: Value(100),
        passMarks: Value(40),
        theoryMarks: Value(75),
        practicalMarks: Value(25),
        description: Value('General Science & Scientific Inquiry'),
      ),
      const SubjectsCompanion(
        code: Value('SOC'),
        name: Value('Social Studies & Life Skills'),
        subjectType: Value(SubjectType.both),
        isOptional: Value(false),
        fullMarks: Value(100),
        passMarks: Value(40),
        theoryMarks: Value(75),
        practicalMarks: Value(25),
        description: Value('Social Studies, Civics & Life Skills'),
      ),
      const SubjectsCompanion(
        code: Value('HPE'),
        name: Value('Health, Physical & Moral Education'),
        subjectType: Value(SubjectType.both),
        isOptional: Value(false),
        fullMarks: Value(100),
        passMarks: Value(40),
        theoryMarks: Value(50),
        practicalMarks: Value(50),
        description: Value('Physical fitness, health education, and values'),
      ),
      const SubjectsCompanion(
        code: Value('OBT'),
        name: Value('Occupation, Business & Technology'),
        subjectType: Value(SubjectType.both),
        isOptional: Value(false),
        fullMarks: Value(100),
        passMarks: Value(40),
        theoryMarks: Value(50),
        practicalMarks: Value(50),
        description: Value('Vocational, business, and occupational skills'),
      ),

      // Pre-Primary & Foundational Subjects
      const SubjectsCompanion(
        code: Value('DRW'),
        name: Value('Drawing, Art & Craft'),
        subjectType: Value(SubjectType.practical),
        isOptional: Value(false),
        fullMarks: Value(50),
        passMarks: Value(20),
        theoryMarks: Value(0),
        practicalMarks: Value(50),
        description: Value('Visual arts, coloring, and craft activities'),
      ),
      const SubjectsCompanion(
        code: Value('RHY'),
        name: Value('Rhymes & Storytelling'),
        subjectType: Value(SubjectType.practical),
        isOptional: Value(false),
        fullMarks: Value(50),
        passMarks: Value(20),
        theoryMarks: Value(0),
        practicalMarks: Value(50),
        description: Value('Early childhood rhymes and oral narrative skills'),
      ),
      const SubjectsCompanion(
        code: Value('GK'),
        name: Value('General Knowledge & Awareness'),
        subjectType: Value(SubjectType.both),
        isOptional: Value(false),
        fullMarks: Value(50),
        passMarks: Value(20),
        theoryMarks: Value(25),
        practicalMarks: Value(25),
        description: Value('General awareness, culture, and science facts'),
      ),
      const SubjectsCompanion(
        code: Value('ENV'),
        name: Value('My Surroundings & Environment'),
        subjectType: Value(SubjectType.both),
        isOptional: Value(false),
        fullMarks: Value(100),
        passMarks: Value(40),
        theoryMarks: Value(60),
        practicalMarks: Value(40),
        description: Value('Environmental studies and community exploration'),
      ),

      // Electives & Optional Subjects
      const SubjectsCompanion(
        code: Value('OPTMTH'),
        name: Value('Optional Mathematics'),
        subjectType: Value(SubjectType.theory),
        isOptional: Value(true),
        fullMarks: Value(100),
        passMarks: Value(40),
        theoryMarks: Value(100),
        practicalMarks: Value(0),
        description: Value(
          'Advanced algebra, trigonometry, vectors, and calculus',
        ),
      ),
      const SubjectsCompanion(
        code: Value('COM'),
        name: Value('Computer Science'),
        subjectType: Value(SubjectType.both),
        isOptional: Value(true),
        fullMarks: Value(100),
        passMarks: Value(40),
        theoryMarks: Value(50),
        practicalMarks: Value(50),
        description: Value(
          'Programming, computer systems, and digital literacy',
        ),
      ),
      const SubjectsCompanion(
        code: Value('ECO'),
        name: Value('Economics'),
        subjectType: Value(SubjectType.theory),
        isOptional: Value(true),
        fullMarks: Value(100),
        passMarks: Value(40),
        theoryMarks: Value(100),
        practicalMarks: Value(0),
        description: Value('Micro & macro economics principles'),
      ),
      const SubjectsCompanion(
        code: Value('ACC'),
        name: Value('Accountancy & Office Management'),
        subjectType: Value(SubjectType.both),
        isOptional: Value(true),
        fullMarks: Value(100),
        passMarks: Value(40),
        theoryMarks: Value(75),
        practicalMarks: Value(25),
        description: Value(
          'Bookkeeping, financial records, and office procedures',
        ),
      ),
      const SubjectsCompanion(
        code: Value('SAN'),
        name: Value('Sanskrit Language'),
        subjectType: Value(SubjectType.theory),
        isOptional: Value(true),
        fullMarks: Value(100),
        passMarks: Value(40),
        theoryMarks: Value(100),
        practicalMarks: Value(0),
        description: Value('संस्कृत भाषा तथा साहित्य'),
      ),
      const SubjectsCompanion(
        code: Value('MUS'),
        name: Value('Music & Performing Arts'),
        subjectType: Value(SubjectType.practical),
        isOptional: Value(true),
        fullMarks: Value(50),
        passMarks: Value(20),
        theoryMarks: Value(0),
        practicalMarks: Value(50),
        description: Value('Vocal, instrumental music, and traditional dance'),
      ),
    ];

    for (final companion in genericSubjects) {
      await db.insertSubject(companion);
    }
  }

  /// Seeds Nursery, LKG, UKG, and Class 1 through Class 10 with 3 sections each (A, B, C)
  static Future<void> seedClassesAndSections(AppDatabase db) async {
    final prePrimary = [
      {'name': 'Nursery', 'displayName': 'Nursery', 'order': 1},
      {'name': 'LKG', 'displayName': 'LKG (Lower Kindergarten)', 'order': 2},
      {'name': 'UKG', 'displayName': 'UKG (Upper Kindergarten)', 'order': 3},
    ];

    for (final item in prePrimary) {
      await db.insertClassWithSections(
        classCompanion: SchoolClassesCompanion(
          name: Value(item['name'] as String),
          displayName: Value(item['displayName'] as String),
          orderIndex: Value(item['order'] as int),
        ),
        sectionNames: const ['A', 'B', 'C'],
      );
    }

    for (int i = 1; i <= 10; i++) {
      await db.insertClassWithSections(
        classCompanion: SchoolClassesCompanion(
          name: Value('Class $i'),
          displayName: Value('Grade $i'),
          orderIndex: Value(i + 3),
        ),
        sectionNames: const ['A', 'B', 'C'],
      );
    }
  }

  /// Seeds 3 default academic years: 2026-2027, 2027-2028, and 2029-2030
  static Future<void> seedAcademicYears(AppDatabase db) async {
    final records = [
      AcademicYearsCompanion(
        name: const Value('2024-2025'),
        startDate: Value(DateTime(2024, 4, 14)),
        endDate: Value(DateTime(2025, 4, 13)),
        isCurrent: const Value(false),
        description: const Value('Academic Session 2024-2025'),
      ),
      AcademicYearsCompanion(
        name: const Value('2025-2026'),
        startDate: Value(DateTime(2025, 4, 14)),
        endDate: Value(DateTime(2026, 4, 13)),
        isCurrent: const Value(false),
        description: const Value('Academic Session 2025-2026'),
      ),
      AcademicYearsCompanion(
        name: const Value('2026-2027'),
        startDate: Value(DateTime(2026, 4, 14)),
        endDate: Value(DateTime(2027, 4, 13)),
        isCurrent: const Value(true), // Active session for 2026
        description: const Value('Academic Session 2026-2027'),
      ),
      AcademicYearsCompanion(
        name: const Value('2027-2028'),
        startDate: Value(DateTime(2027, 4, 14)),
        endDate: Value(DateTime(2028, 4, 13)),
        isCurrent: const Value(false),
        description: const Value('Academic Session 2027-2028'),
      ),
      AcademicYearsCompanion(
        name: const Value('2029-2030'),
        startDate: Value(DateTime(2029, 4, 14)),
        endDate: Value(DateTime(2030, 4, 13)),
        isCurrent: const Value(false),
        description: const Value('Academic Session 2029-2030'),
      ),
    ];

    for (final companion in records) {
      await db.insertAcademicYear(companion);
    }
  }
}
