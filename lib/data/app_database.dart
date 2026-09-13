import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../config/enums.dart';
import 'database_seeder.dart';

part 'academic_database.dart';
part 'app_database.g.dart';
part 'attendance_database.dart';
part 'certificate_database.dart';
part 'contact_database.dart';
part 'exam_database.dart';
part 'finance_database.dart';
part 'staff_database.dart';
part 'student_database.dart';
part 'timetable_database.dart';

@DriftDatabase(
  tables: [
    AcademicYears,
    SchoolClasses,
    Sections,
    Subjects,
    Employees,
    PeriodEntries,
    Students,
    StudentAcademicHistories,
    Contacts,
    ExpenseCategories,
    Expenses,
    SalaryAdvances,
    SalaryPayments,
    SalaryAdvanceAdjustments,
    FeeCategories,
    StudentFees,
    FeePayments,
    Certificates,
    Exams,
    ExamSchedules,
    ExamResults,
    ExamResultSummaries,
    StudentAttendances,
    EmployeeAttendances,
  ],
)
class AppDatabase extends _$AppDatabase {
  static const databaseFileName = 'sms_app_db.db';

  AppDatabase([QueryExecutor? e]) : super(e ?? _openConnection());

  @override
  int get schemaVersion => 19;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
      await DatabaseSeeder.seedAcademicYears(this);
      await DatabaseSeeder.seedClassesAndSections(this);
      await DatabaseSeeder.seedSubjects(this);
      await DatabaseSeeder.seedFeeCategories(this);
    },
  );

  /// Clears all application data and leaves the database ready for fresh setup.
  ///
  /// The tables are deleted in reverse dependency order so foreign-key
  /// constraints remain valid while the database is being reset.
  Future<void> resetDatabase() async {
    await transaction(() async {
      await delete(employeeAttendances).go();
      await delete(studentAttendances).go();
      await delete(examResultSummaries).go();
      await delete(examResults).go();
      await delete(examSchedules).go();
      await delete(exams).go();
      await delete(feePayments).go();
      await delete(studentFees).go();
      await delete(feeCategories).go();
      await delete(salaryAdvanceAdjustments).go();
      await delete(salaryPayments).go();
      await delete(salaryAdvances).go();
      await delete(expenses).go();
      await delete(expenseCategories).go();
      await delete(certificates).go();
      await delete(periodEntries).go();
      await delete(studentAcademicHistories).go();
      await delete(contacts).go();
      await delete(students).go();
      await delete(employees).go();
      await delete(subjects).go();
      await delete(sections).go();
      await delete(schoolClasses).go();
      await delete(academicYears).go();
      await DatabaseSeeder.seedAcademicYears(this);
      await DatabaseSeeder.seedClassesAndSections(this);
      await DatabaseSeeder.seedSubjects(this);
      await DatabaseSeeder.seedFeeCategories(this);
    });
  }

  /// Stream all academic years sorted descending by start date
  Stream<List<AcademicYear>> watchAllAcademicYears() {
    return (select(academicYears)..orderBy([
      (t) => OrderingTerm(expression: t.startDate, mode: OrderingMode.desc),
    ])).watch();
  }

  /// Get all academic years as future
  Future<List<AcademicYear>> getAllAcademicYears() {
    return (select(academicYears)..orderBy([
      (t) => OrderingTerm(expression: t.startDate, mode: OrderingMode.desc),
    ])).get();
  }

  /// Get current active academic year
  Future<AcademicYear?> getCurrentAcademicYear() {
    return (select(academicYears)
      ..where((t) => t.isCurrent.equals(true))).getSingleOrNull();
  }

  /// Alias for getCurrentAcademicYear
  Future<AcademicYear?> getActiveAcademicYear() => getCurrentAcademicYear();

  /// Watch current active academic year reactively
  Stream<AcademicYear?> watchCurrentAcademicYear() {
    return (select(academicYears)
      ..where((t) => t.isCurrent.equals(true))).watchSingleOrNull();
  }

  /// Insert academic year with atomic constraint: if isCurrent is true, unset other years
  Future<int> insertAcademicYear(AcademicYearsCompanion companion) {
    return transaction(() async {
      if (companion.isCurrent.present && companion.isCurrent.value == true) {
        await update(
          academicYears,
        ).write(const AcademicYearsCompanion(isCurrent: Value(false)));
      }
      return into(academicYears).insert(companion);
    });
  }

  /// Update academic year with atomic constraint: if isCurrent is true, unset other years
  Future<bool> updateAcademicYearEntry(AcademicYear entry) {
    return transaction(() async {
      if (entry.isCurrent) {
        await (update(academicYears)..where(
          (t) => t.id.isNotValue(entry.id),
        )).write(const AcademicYearsCompanion(isCurrent: Value(false)));
      }
      return update(academicYears).replace(entry);
    });
  }

  /// Set specified academic year as active and deactivate all others
  Future<void> setActiveAcademicYear(int id) {
    return transaction(() async {
      await update(
        academicYears,
      ).write(const AcademicYearsCompanion(isCurrent: Value(false)));
      await (update(academicYears)..where(
        (t) => t.id.equals(id),
      )).write(const AcademicYearsCompanion(isCurrent: Value(true)));
    });
  }

  /// Delete academic year
  Future<int> deleteAcademicYear(int id) {
    return (delete(academicYears)..where((t) => t.id.equals(id))).go();
  }

  /// Get academic year by ID
  Future<AcademicYear?> getAcademicYearById(int id) {
    return (select(academicYears)
      ..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  // ================= CLASSES & SECTIONS =================

  /// Stream all classes with their respective sections
  Stream<List<ClassWithSections>> watchClassesWithSections() {
    final query = select(schoolClasses).join([
      leftOuterJoin(sections, sections.classId.equalsExp(schoolClasses.id)),
    ])..orderBy([
      OrderingTerm(
        expression: schoolClasses.orderIndex,
        mode: OrderingMode.asc,
      ),
      OrderingTerm(expression: schoolClasses.id, mode: OrderingMode.asc),
    ]);

    return query.watch().map((rows) {
      final Map<int, SchoolClass> classMap = {};
      final Map<int, List<Section>> sectionsMap = {};

      for (final row in rows) {
        final sc = row.readTable(schoolClasses);
        classMap.putIfAbsent(sc.id, () => sc);
        sectionsMap.putIfAbsent(sc.id, () => []);

        final sec = row.readTableOrNull(sections);
        if (sec != null) {
          if (!sectionsMap[sc.id]!.any((s) => s.id == sec.id)) {
            sectionsMap[sc.id]!.add(sec);
          }
        }
      }

      return classMap.values.map((sc) {
        final secList = sectionsMap[sc.id] ?? [];
        secList.sort((a, b) => a.name.compareTo(b.name));
        return ClassWithSections(schoolClass: sc, sections: secList);
      }).toList();
    });
  }

  /// Get all classes with their respective sections as a Future
  Future<List<ClassWithSections>> getAllClassesWithSections() async {
    final query = select(schoolClasses).join([
      leftOuterJoin(sections, sections.classId.equalsExp(schoolClasses.id)),
    ])..orderBy([
      OrderingTerm(
        expression: schoolClasses.orderIndex,
        mode: OrderingMode.asc,
      ),
      OrderingTerm(expression: schoolClasses.id, mode: OrderingMode.asc),
    ]);

    final rows = await query.get();
    final Map<int, SchoolClass> classMap = {};
    final Map<int, List<Section>> sectionsMap = {};

    for (final row in rows) {
      final sc = row.readTable(schoolClasses);
      classMap.putIfAbsent(sc.id, () => sc);
      sectionsMap.putIfAbsent(sc.id, () => []);

      final sec = row.readTableOrNull(sections);
      if (sec != null) {
        if (!sectionsMap[sc.id]!.any((s) => s.id == sec.id)) {
          sectionsMap[sc.id]!.add(sec);
        }
      }
    }

    return classMap.values.map((sc) {
      final secList = sectionsMap[sc.id] ?? [];
      secList.sort((a, b) => a.name.compareTo(b.name));
      return ClassWithSections(schoolClass: sc, sections: secList);
    }).toList();
  }

  /// Get a single class with its sections by ID
  Future<ClassWithSections?> getClassWithSectionsById(int id) async {
    final sc =
        await (select(schoolClasses)
          ..where((c) => c.id.equals(id))).getSingleOrNull();
    if (sc == null) return null;
    final secList =
        await (select(sections)
              ..where((s) => s.classId.equals(id))
              ..orderBy([
                (s) => OrderingTerm(expression: s.name, mode: OrderingMode.asc),
              ]))
            .get();
    return ClassWithSections(schoolClass: sc, sections: secList);
  }

  /// Insert a class and optionally its sections
  Future<int> insertClassWithSections({
    required SchoolClassesCompanion classCompanion,
    List<String> sectionNames = const [],
  }) {
    return transaction(() async {
      final classId = await into(schoolClasses).insert(classCompanion);
      for (final name in sectionNames) {
        final trimmed = name.trim();
        if (trimmed.isNotEmpty) {
          await into(sections).insert(
            SectionsCompanion(classId: Value(classId), name: Value(trimmed)),
          );
        }
      }
      return classId;
    });
  }

  /// Update class and synchronize section names
  Future<void> updateClassWithSections({
    required SchoolClass updatedClass,
    required List<String> sectionNames,
  }) {
    return transaction(() async {
      await update(schoolClasses).replace(updatedClass);

      final currentSections =
          await (select(sections)
            ..where((s) => s.classId.equals(updatedClass.id))).get();
      final currentNames = currentSections.map((s) => s.name).toSet();
      final newNames =
          sectionNames.map((s) => s.trim()).where((s) => s.isNotEmpty).toSet();

      // Delete sections that are removed
      for (final sec in currentSections) {
        if (!newNames.contains(sec.name)) {
          await (delete(sections)..where((s) => s.id.equals(sec.id))).go();
        }
      }

      // Insert newly added sections
      for (final name in newNames) {
        if (!currentNames.contains(name)) {
          await into(sections).insert(
            SectionsCompanion(
              classId: Value(updatedClass.id),
              name: Value(name),
            ),
          );
        }
      }
    });
  }

  /// Delete a class and all associated sections
  Future<int> deleteClass(int classId) {
    return transaction(() async {
      await (delete(sections)..where((s) => s.classId.equals(classId))).go();
      return (delete(schoolClasses)..where((c) => c.id.equals(classId))).go();
    });
  }

  /// Add a single section to a class
  Future<int> addSection({
    required int classId,
    required String name,
    String? roomNumber,
    int? capacity,
  }) {
    return into(sections).insert(
      SectionsCompanion(
        classId: Value(classId),
        name: Value(name.trim()),
        roomNumber: Value(roomNumber?.trim()),
        capacity: Value(capacity),
      ),
    );
  }

  /// Delete a single section by ID
  Future<int> deleteSection(int sectionId) {
    return (delete(sections)..where((s) => s.id.equals(sectionId))).go();
  }

  // ================= SUBJECTS =================

  /// Stream all generic subjects with optional filtering by subjectType and isOptional
  Stream<List<Subject>> watchSubjects({SubjectType? type, bool? isOptional}) {
    var query = select(subjects);

    if (type != null) {
      query = query..where((t) => t.subjectType.equals(type.name));
    }
    if (isOptional != null) {
      query = query..where((t) => t.isOptional.equals(isOptional));
    }

    query =
        query..orderBy([
          (t) => OrderingTerm(expression: t.name, mode: OrderingMode.asc),
        ]);

    return query.watch();
  }

  /// Get all generic subjects as a Future
  Future<List<Subject>> getAllSubjects() {
    return (select(subjects)..orderBy([
      (t) => OrderingTerm(expression: t.name, mode: OrderingMode.asc),
    ])).get();
  }

  /// Get single subject by ID
  Future<Subject?> getSubjectById(int id) {
    return (select(subjects)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Insert subject
  Future<int> insertSubject(SubjectsCompanion companion) {
    return into(subjects).insert(companion);
  }

  /// Update subject
  Future<bool> updateSubjectEntry(Subject entry) {
    return update(subjects).replace(entry);
  }

  /// Delete subject
  Future<int> deleteSubject(int id) {
    return (delete(subjects)..where((s) => s.id.equals(id))).go();
  }

  // ================= EMPLOYEES (TEACHERS & STAFF) =================

  /// Watch employees with optional type, search query, and active status filters
  Stream<List<Employee>> watchEmployees({
    EmployeeType? type,
    String? searchQuery,
    bool? isActive,
  }) {
    final query = select(employees);
    if (type != null) {
      query.where((t) => t.employeeType.equals(type.name));
    }
    if (isActive != null) {
      query.where((t) => t.isActive.equals(isActive));
    }
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final term = '%${searchQuery.trim().toLowerCase()}%';
      query.where(
        (t) =>
            t.name.lower().like(term) |
            t.designation.lower().like(term) |
            t.department.lower().like(term) |
            t.employeeCode.lower().like(term) |
            t.emergencyContactName.lower().like(term) |
            t.emergencyContactPhone.lower().like(term),
      );
    }
    query.orderBy([
      (t) => OrderingTerm(expression: t.name, mode: OrderingMode.asc),
    ]);
    return query.watch();
  }

  /// Get all employees with optional filters
  Future<List<Employee>> getAllEmployees({
    EmployeeType? type,
    String? searchQuery,
    bool? isActive,
  }) {
    final query = select(employees);
    if (type != null) {
      query.where((t) => t.employeeType.equals(type.name));
    }
    if (isActive != null) {
      query.where((t) => t.isActive.equals(isActive));
    }
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final term = '%${searchQuery.trim().toLowerCase()}%';
      query.where(
        (t) =>
            t.name.lower().like(term) |
            t.designation.lower().like(term) |
            t.department.lower().like(term) |
            t.employeeCode.lower().like(term) |
            t.emergencyContactName.lower().like(term) |
            t.emergencyContactPhone.lower().like(term),
      );
    }
    query.orderBy([
      (t) => OrderingTerm(expression: t.name, mode: OrderingMode.asc),
    ]);
    return query.get();
  }

  /// Get single employee by ID
  Future<Employee?> getEmployeeById(int id) {
    return (select(employees)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Insert employee
  Future<int> insertEmployee(EmployeesCompanion companion) {
    return into(employees).insert(companion);
  }

  /// Update employee
  Future<bool> updateEmployeeEntry(Employee entry) {
    return update(employees).replace(entry);
  }

  /// Delete employee
  Future<int> deleteEmployee(int id) {
    return (delete(employees)..where((t) => t.id.equals(id))).go();
  }

  // Backward-compatible teacher query methods
  Stream<List<Employee>> watchAllTeachers() =>
      watchEmployees(type: EmployeeType.teacher, isActive: true);

  Future<List<Employee>> getAllTeachers() =>
      getAllEmployees(type: EmployeeType.teacher, isActive: true);

  Future<Employee?> getTeacherById(int id) => getEmployeeById(id);

  Future<int> insertTeacher(EmployeesCompanion companion) =>
      insertEmployee(companion);

  Future<bool> updateTeacherEntry(Employee entry) => updateEmployeeEntry(entry);

  Future<int> deleteTeacher(int id) => deleteEmployee(id);

  // ================= TIMETABLE & PERIODS =================

  static const _dayOrderExp = CustomExpression<int>(
    'CASE LOWER(period_entries.day_of_week) '
    "WHEN 'sunday' THEN 1 "
    "WHEN 'monday' THEN 2 "
    "WHEN 'tuesday' THEN 3 "
    "WHEN 'wednesday' THEN 4 "
    "WHEN 'thursday' THEN 5 "
    "WHEN 'friday' THEN 6 "
    "WHEN 'saturday' THEN 7 "
    'ELSE 8 END',
  );

  /// Watch periods with full details (class, section, subject, teacher, academicYear)
  Stream<List<PeriodWithDetails>> watchPeriodsWithDetails({
    int? academicYearId,
    int? classId,
    int? sectionId,
    String? dayOfWeek,
  }) {
    final query = select(periodEntries).join([
      leftOuterJoin(
        academicYears,
        academicYears.id.equalsExp(periodEntries.academicYearId),
      ),
      leftOuterJoin(
        schoolClasses,
        schoolClasses.id.equalsExp(periodEntries.classId),
      ),
      leftOuterJoin(sections, sections.id.equalsExp(periodEntries.sectionId)),
      leftOuterJoin(subjects, subjects.id.equalsExp(periodEntries.subjectId)),
      leftOuterJoin(employees, employees.id.equalsExp(periodEntries.teacherId)),
    ]);

    if (academicYearId != null) {
      query.where(periodEntries.academicYearId.equals(academicYearId));
    }
    if (classId != null) {
      query.where(periodEntries.classId.equals(classId));
    }
    if (sectionId != null) {
      query.where(periodEntries.sectionId.equals(sectionId));
    }
    if (dayOfWeek != null && dayOfWeek.trim().isNotEmpty) {
      query.where(
        periodEntries.dayOfWeek.equals(dayOfWeek.trim().toLowerCase()),
      );
    }

    query.orderBy([
      OrderingTerm(expression: _dayOrderExp, mode: OrderingMode.asc),
      OrderingTerm(expression: periodEntries.startTime, mode: OrderingMode.asc),
      OrderingTerm(
        expression: periodEntries.periodNumber,
        mode: OrderingMode.asc,
      ),
    ]);

    return query.watch().map((rows) {
      return rows.map((row) {
        return PeriodWithDetails(
          period: row.readTable(periodEntries),
          schoolClass: row.readTableOrNull(schoolClasses),
          section: row.readTableOrNull(sections),
          subject: row.readTableOrNull(subjects),
          teacher: row.readTableOrNull(employees),
          academicYear: row.readTableOrNull(academicYears),
        );
      }).toList();
    });
  }

  /// Get all periods with details
  Future<List<PeriodWithDetails>> getAllPeriodsWithDetails({
    int? academicYearId,
    int? classId,
    int? sectionId,
    String? dayOfWeek,
  }) {
    final query = select(periodEntries).join([
      leftOuterJoin(
        academicYears,
        academicYears.id.equalsExp(periodEntries.academicYearId),
      ),
      leftOuterJoin(
        schoolClasses,
        schoolClasses.id.equalsExp(periodEntries.classId),
      ),
      leftOuterJoin(sections, sections.id.equalsExp(periodEntries.sectionId)),
      leftOuterJoin(subjects, subjects.id.equalsExp(periodEntries.subjectId)),
      leftOuterJoin(employees, employees.id.equalsExp(periodEntries.teacherId)),
    ]);

    if (academicYearId != null) {
      query.where(periodEntries.academicYearId.equals(academicYearId));
    }
    if (classId != null) {
      query.where(periodEntries.classId.equals(classId));
    }
    if (sectionId != null) {
      query.where(periodEntries.sectionId.equals(sectionId));
    }
    if (dayOfWeek != null && dayOfWeek.trim().isNotEmpty) {
      query.where(
        periodEntries.dayOfWeek.equals(dayOfWeek.trim().toLowerCase()),
      );
    }

    query.orderBy([
      OrderingTerm(expression: _dayOrderExp, mode: OrderingMode.asc),
      OrderingTerm(expression: periodEntries.startTime, mode: OrderingMode.asc),
      OrderingTerm(
        expression: periodEntries.periodNumber,
        mode: OrderingMode.asc,
      ),
    ]);

    return query.get().then((rows) {
      return rows.map((row) {
        return PeriodWithDetails(
          period: row.readTable(periodEntries),
          schoolClass: row.readTableOrNull(schoolClasses),
          section: row.readTableOrNull(sections),
          subject: row.readTableOrNull(subjects),
          teacher: row.readTableOrNull(employees),
          academicYear: row.readTableOrNull(academicYears),
        );
      }).toList();
    });
  }

  /// Get single period with details by ID
  Future<PeriodWithDetails?> getPeriodWithDetailsById(int id) {
    final query = (select(periodEntries)..where((t) => t.id.equals(id))).join([
      leftOuterJoin(
        academicYears,
        academicYears.id.equalsExp(periodEntries.academicYearId),
      ),
      leftOuterJoin(
        schoolClasses,
        schoolClasses.id.equalsExp(periodEntries.classId),
      ),
      leftOuterJoin(sections, sections.id.equalsExp(periodEntries.sectionId)),
      leftOuterJoin(subjects, subjects.id.equalsExp(periodEntries.subjectId)),
      leftOuterJoin(employees, employees.id.equalsExp(periodEntries.teacherId)),
    ]);

    return query.getSingleOrNull().then((row) {
      if (row == null) return null;
      return PeriodWithDetails(
        period: row.readTable(periodEntries),
        schoolClass: row.readTableOrNull(schoolClasses),
        section: row.readTableOrNull(sections),
        subject: row.readTableOrNull(subjects),
        teacher: row.readTableOrNull(employees),
        academicYear: row.readTableOrNull(academicYears),
      );
    });
  }

  /// Insert period
  Future<int> insertPeriod(PeriodEntriesCompanion companion) {
    return into(periodEntries).insert(companion);
  }

  /// Update period
  Future<bool> updatePeriodEntry(PeriodEntry entry) {
    return update(periodEntries).replace(entry);
  }

  /// Delete period
  Future<int> deletePeriod(int id) {
    return (delete(periodEntries)..where((t) => t.id.equals(id))).go();
  }

  /// Atomically replaces the entire weekly timetable for a class and section in an academic year
  Future<void> replaceWeeklyTimetable({
    required int academicYearId,
    required int classId,
    int? sectionId,
    required List<PeriodEntriesCompanion> periods,
  }) {
    return transaction(() async {
      // 1. Delete existing periods for this academic year, class, and section
      final del = delete(periodEntries)..where(
        (t) =>
            t.academicYearId.equals(academicYearId) & t.classId.equals(classId),
      );
      if (sectionId != null) {
        del.where((t) => t.sectionId.equals(sectionId));
      } else {
        del.where((t) => t.sectionId.isNull());
      }
      await del.go();

      // 2. Insert new periods in batch
      if (periods.isNotEmpty) {
        await batch((b) {
          b.insertAll(periodEntries, periods);
        });
      }
    });
  }

  /// Delete all periods for a specific class and optional section in an academic year
  Future<int> clearWeeklyTimetable({
    required int academicYearId,
    required int classId,
    int? sectionId,
  }) {
    final del = delete(periodEntries)..where(
      (t) =>
          t.academicYearId.equals(academicYearId) & t.classId.equals(classId),
    );
    if (sectionId != null) {
      del.where((t) => t.sectionId.equals(sectionId));
    } else {
      del.where((t) => t.sectionId.isNull());
    }
    return del.go();
  }

  // ==================== Contacts Operations ====================

  /// Stream all contacts ordered by name
  Stream<List<Contact>> watchAllContacts() {
    return (select(contacts)
      ..orderBy([(t) => OrderingTerm(expression: t.name)])).watch();
  }

  /// Get all contacts ordered by name
  Future<List<Contact>> getAllContacts() {
    return (select(contacts)
      ..orderBy([(t) => OrderingTerm(expression: t.name)])).get();
  }

  /// Watch contacts for a specific source (e.g. employee ID or student ID)
  Stream<List<Contact>> watchContactsBySource(
    ContactSourceType sourceType,
    int? sourceId,
  ) {
    final query = select(contacts)
      ..where((t) => t.sourceType.equals(sourceType.name));
    if (sourceId != null) {
      query.where((t) => t.sourceId.equals(sourceId));
    }
    query.orderBy([
      (t) => OrderingTerm(expression: t.isPrimary, mode: OrderingMode.desc),
      (t) => OrderingTerm(expression: t.name),
    ]);
    return query.watch();
  }

  /// Get contacts for a specific source
  Future<List<Contact>> getContactsBySource(
    ContactSourceType sourceType,
    int? sourceId,
  ) {
    final query = select(contacts)
      ..where((t) => t.sourceType.equals(sourceType.name));
    if (sourceId != null) {
      query.where((t) => t.sourceId.equals(sourceId));
    }
    query.orderBy([
      (t) => OrderingTerm(expression: t.isPrimary, mode: OrderingMode.desc),
      (t) => OrderingTerm(expression: t.name),
    ]);
    return query.get();
  }

  /// Stream emergency contacts
  Stream<List<Contact>> watchEmergencyContacts() {
    return (select(contacts)
          ..where((t) => t.isEmergency.equals(true))
          ..orderBy([(t) => OrderingTerm(expression: t.name)]))
        .watch();
  }

  /// Search contacts by query
  Future<List<Contact>> searchContacts(String query) {
    final q = '%${query.toLowerCase()}%';
    return (select(contacts)
          ..where(
            (t) =>
                t.name.lower().like(q) |
                t.phone.like(q) |
                t.relation.lower().like(q) |
                t.sourceName.lower().like(q),
          )
          ..orderBy([(t) => OrderingTerm(expression: t.name)]))
        .get();
  }

  /// Insert new contact
  Future<int> insertContact(ContactsCompanion companion) {
    return into(contacts).insert(companion);
  }

  /// Update contact
  Future<bool> updateContactEntry(Contact entry) {
    return update(contacts).replace(entry);
  }

  /// Delete contact
  Future<int> deleteContactEntry(int id) {
    return (delete(contacts)..where((t) => t.id.equals(id))).go();
  }

  /// Delete all contacts for a specific source
  Future<int> deleteContactsBySource(
    ContactSourceType sourceType,
    int sourceId,
  ) {
    return (delete(contacts)..where(
      (t) => t.sourceType.equals(sourceType.name) & t.sourceId.equals(sourceId),
    )).go();
  }

  // ==================== Students Operations ====================

  /// Stream students with full details (class, section, enrollment, academic year)
  Stream<List<StudentWithDetails>> watchStudentsWithDetails({
    int? academicYearId,
    int? classId,
    int? sectionId,
    String? search,
  }) {
    if (academicYearId != null) {
      final query = select(students).join([
        innerJoin(
          studentAcademicHistories,
          studentAcademicHistories.studentId.equalsExp(students.id) &
              studentAcademicHistories.academicYearId.equals(academicYearId),
        ),
        leftOuterJoin(
          schoolClasses,
          schoolClasses.id.equalsExp(studentAcademicHistories.classId),
        ),
        leftOuterJoin(
          sections,
          sections.id.equalsExp(studentAcademicHistories.sectionId),
        ),
        leftOuterJoin(
          academicYears,
          academicYears.id.equalsExp(studentAcademicHistories.academicYearId),
        ),
      ]);
      if (classId != null) {
        query.where(studentAcademicHistories.classId.equals(classId));
      }
      if (sectionId != null) {
        query.where(studentAcademicHistories.sectionId.equals(sectionId));
      }
      if (search != null && search.trim().isNotEmpty) {
        final q = '%${search.trim().toLowerCase()}%';
        query.where(
          students.name.lower().like(q) |
              students.studentId.lower().like(q) |
              students.admissionNumber.lower().like(q) |
              students.phone.like(q),
        );
      }
      query.orderBy([
        OrderingTerm(
          expression: studentAcademicHistories.rollNumber,
          mode: OrderingMode.asc,
        ),
        OrderingTerm(expression: students.name, mode: OrderingMode.asc),
      ]);
      return query.watch().map((rows) {
        return rows.map((row) {
          return StudentWithDetails(
            student: row.readTable(students),
            currentClass: row.readTableOrNull(schoolClasses),
            currentSection: row.readTableOrNull(sections),
            currentEnrollment: row.readTableOrNull(studentAcademicHistories),
            currentAcademicYear: row.readTableOrNull(academicYears),
          );
        }).toList();
      });
    } else {
      final query = select(students).join([
        leftOuterJoin(
          schoolClasses,
          schoolClasses.id.equalsExp(students.classId),
        ),
        leftOuterJoin(sections, sections.id.equalsExp(students.sectionId)),
      ]);
      if (classId != null) {
        query.where(students.classId.equals(classId));
      }
      if (sectionId != null) {
        query.where(students.sectionId.equals(sectionId));
      }
      if (search != null && search.trim().isNotEmpty) {
        final q = '%${search.trim().toLowerCase()}%';
        query.where(
          students.name.lower().like(q) |
              students.studentId.lower().like(q) |
              students.admissionNumber.lower().like(q) |
              students.phone.like(q),
        );
      }
      query.orderBy([
        OrderingTerm(expression: students.rollNumber, mode: OrderingMode.asc),
        OrderingTerm(expression: students.name, mode: OrderingMode.asc),
      ]);
      return query.watch().map((rows) {
        return rows.map((row) {
          return StudentWithDetails(
            student: row.readTable(students),
            currentClass: row.readTableOrNull(schoolClasses),
            currentSection: row.readTableOrNull(sections),
            currentEnrollment: null,
            currentAcademicYear: null,
          );
        }).toList();
      });
    }
  }

  /// Get students with full details as future
  Future<List<StudentWithDetails>> getStudentsWithDetails({
    int? academicYearId,
    int? classId,
    int? sectionId,
    String? search,
  }) async {
    if (academicYearId != null) {
      final query = select(students).join([
        innerJoin(
          studentAcademicHistories,
          studentAcademicHistories.studentId.equalsExp(students.id) &
              studentAcademicHistories.academicYearId.equals(academicYearId),
        ),
        leftOuterJoin(
          schoolClasses,
          schoolClasses.id.equalsExp(studentAcademicHistories.classId),
        ),
        leftOuterJoin(
          sections,
          sections.id.equalsExp(studentAcademicHistories.sectionId),
        ),
        leftOuterJoin(
          academicYears,
          academicYears.id.equalsExp(studentAcademicHistories.academicYearId),
        ),
      ]);
      if (classId != null) {
        query.where(studentAcademicHistories.classId.equals(classId));
      }
      if (sectionId != null) {
        query.where(studentAcademicHistories.sectionId.equals(sectionId));
      }
      if (search != null && search.trim().isNotEmpty) {
        final q = '%${search.trim().toLowerCase()}%';
        query.where(
          students.name.lower().like(q) |
              students.studentId.lower().like(q) |
              students.admissionNumber.lower().like(q) |
              students.phone.like(q),
        );
      }
      query.orderBy([
        OrderingTerm(
          expression: studentAcademicHistories.rollNumber,
          mode: OrderingMode.asc,
        ),
        OrderingTerm(expression: students.name, mode: OrderingMode.asc),
      ]);
      final rows = await query.get();
      return rows.map((row) {
        return StudentWithDetails(
          student: row.readTable(students),
          currentClass: row.readTableOrNull(schoolClasses),
          currentSection: row.readTableOrNull(sections),
          currentEnrollment: row.readTableOrNull(studentAcademicHistories),
          currentAcademicYear: row.readTableOrNull(academicYears),
        );
      }).toList();
    } else {
      final query = select(students).join([
        leftOuterJoin(
          schoolClasses,
          schoolClasses.id.equalsExp(students.classId),
        ),
        leftOuterJoin(sections, sections.id.equalsExp(students.sectionId)),
      ]);
      if (classId != null) {
        query.where(students.classId.equals(classId));
      }
      if (sectionId != null) {
        query.where(students.sectionId.equals(sectionId));
      }
      if (search != null && search.trim().isNotEmpty) {
        final q = '%${search.trim().toLowerCase()}%';
        query.where(
          students.name.lower().like(q) |
              students.studentId.lower().like(q) |
              students.admissionNumber.lower().like(q) |
              students.phone.like(q),
        );
      }
      query.orderBy([
        OrderingTerm(expression: students.rollNumber, mode: OrderingMode.asc),
        OrderingTerm(expression: students.name, mode: OrderingMode.asc),
      ]);
      final rows = await query.get();
      return rows.map((row) {
        return StudentWithDetails(
          student: row.readTable(students),
          currentClass: row.readTableOrNull(schoolClasses),
          currentSection: row.readTableOrNull(sections),
          currentEnrollment: null,
          currentAcademicYear: null,
        );
      }).toList();
    }
  }

  /// Get student with full details by student ID
  Future<StudentWithDetails?> getStudentWithDetailsById(
    int id, {
    int? academicYearId,
  }) async {
    final student =
        await (select(students)
          ..where((t) => t.id.equals(id))).getSingleOrNull();
    if (student == null) return null;

    SchoolClass? currentClass;
    Section? currentSection;
    StudentAcademicHistory? currentEnrollment;
    AcademicYear? currentYear;

    if (academicYearId != null) {
      currentEnrollment =
          await (select(studentAcademicHistories)..where(
            (t) =>
                t.studentId.equals(id) &
                t.academicYearId.equals(academicYearId),
          )).getSingleOrNull();
      if (currentEnrollment != null) {
        currentClass =
            await (select(schoolClasses)..where(
              (t) => t.id.equals(currentEnrollment!.classId),
            )).getSingleOrNull();
        currentSection =
            await (select(sections)..where(
              (t) => t.id.equals(currentEnrollment!.sectionId),
            )).getSingleOrNull();
        currentYear =
            await (select(academicYears)
              ..where((t) => t.id.equals(academicYearId))).getSingleOrNull();
      }
    }

    if (currentClass == null && student.classId != null) {
      currentClass =
          await (select(schoolClasses)
            ..where((t) => t.id.equals(student.classId!))).getSingleOrNull();
    }
    if (currentSection == null && student.sectionId != null) {
      currentSection =
          await (select(sections)
            ..where((t) => t.id.equals(student.sectionId!))).getSingleOrNull();
    }

    return StudentWithDetails(
      student: student,
      currentClass: currentClass,
      currentSection: currentSection,
      currentEnrollment: currentEnrollment,
      currentAcademicYear: currentYear,
    );
  }

  /// Stream all raw students
  Stream<List<Student>> watchAllStudents() {
    return (select(students)
      ..orderBy([(t) => OrderingTerm(expression: t.name)])).watch();
  }

  /// Get all raw students
  Future<List<Student>> getAllStudents() {
    return (select(students)
      ..orderBy([(t) => OrderingTerm(expression: t.name)])).get();
  }

  /// Insert student
  Future<int> insertStudent(StudentsCompanion companion) {
    return into(students).insert(companion);
  }

  /// Update student entry
  Future<bool> updateStudentEntry(Student entry) {
    return update(students).replace(entry);
  }

  /// Delete student entry and cascade
  Future<int> deleteStudentEntry(int id) {
    return (delete(students)..where((t) => t.id.equals(id))).go();
  }

  // ==================== Student Academic History Operations ====================

  /// Watch academic history of a student sorted descending by academic year
  Stream<List<StudentAcademicHistoryWithDetails>> watchStudentAcademicHistory(
    int studentId,
  ) {
    final query =
        select(studentAcademicHistories).join([
            innerJoin(
              academicYears,
              academicYears.id.equalsExp(
                studentAcademicHistories.academicYearId,
              ),
            ),
            innerJoin(
              schoolClasses,
              schoolClasses.id.equalsExp(studentAcademicHistories.classId),
            ),
            innerJoin(
              sections,
              sections.id.equalsExp(studentAcademicHistories.sectionId),
            ),
          ])
          ..where(studentAcademicHistories.studentId.equals(studentId))
          ..orderBy([
            OrderingTerm(
              expression: academicYears.startDate,
              mode: OrderingMode.desc,
            ),
          ]);

    return query.watch().map((rows) {
      return rows.map((row) {
        return StudentAcademicHistoryWithDetails(
          history: row.readTable(studentAcademicHistories),
          academicYear: row.readTable(academicYears),
          schoolClass: row.readTable(schoolClasses),
          section: row.readTable(sections),
        );
      }).toList();
    });
  }

  /// Get academic history of a student sorted descending by academic year
  Future<List<StudentAcademicHistoryWithDetails>> getStudentAcademicHistory(
    int studentId,
  ) async {
    final query =
        select(studentAcademicHistories).join([
            innerJoin(
              academicYears,
              academicYears.id.equalsExp(
                studentAcademicHistories.academicYearId,
              ),
            ),
            innerJoin(
              schoolClasses,
              schoolClasses.id.equalsExp(studentAcademicHistories.classId),
            ),
            innerJoin(
              sections,
              sections.id.equalsExp(studentAcademicHistories.sectionId),
            ),
          ])
          ..where(studentAcademicHistories.studentId.equals(studentId))
          ..orderBy([
            OrderingTerm(
              expression: academicYears.startDate,
              mode: OrderingMode.desc,
            ),
          ]);

    final rows = await query.get();
    return rows.map((row) {
      return StudentAcademicHistoryWithDetails(
        history: row.readTable(studentAcademicHistories),
        academicYear: row.readTable(academicYears),
        schoolClass: row.readTable(schoolClasses),
        section: row.readTable(sections),
      );
    }).toList();
  }

  /// Insert academic history entry
  Future<int> insertAcademicHistory(
    StudentAcademicHistoriesCompanion companion, {
    InsertMode mode = InsertMode.insertOrReplace,
  }) {
    return into(studentAcademicHistories).insert(companion, mode: mode);
  }

  /// Update academic history entry
  Future<bool> updateAcademicHistoryEntry(StudentAcademicHistory entry) {
    return update(studentAcademicHistories).replace(entry);
  }

  /// Get academic history entry for specific student and academic year
  Future<StudentAcademicHistory?> getStudentAcademicHistoryForYear(
    int studentId,
    int academicYearId,
  ) {
    return (select(studentAcademicHistories)..where(
      (t) =>
          t.studentId.equals(studentId) &
          t.academicYearId.equals(academicYearId),
    )).getSingleOrNull();
  }

  /// Get all enrolled students in an academic year, class, and section
  Future<List<StudentAcademicHistoryWithDetails>>
  getEnrolledStudentsForClassSection(
    int academicYearId,
    int classId,
    int sectionId,
  ) async {
    final query =
        select(studentAcademicHistories).join([
            innerJoin(
              academicYears,
              academicYears.id.equalsExp(
                studentAcademicHistories.academicYearId,
              ),
            ),
            innerJoin(
              schoolClasses,
              schoolClasses.id.equalsExp(studentAcademicHistories.classId),
            ),
            innerJoin(
              sections,
              sections.id.equalsExp(studentAcademicHistories.sectionId),
            ),
            innerJoin(
              students,
              students.id.equalsExp(studentAcademicHistories.studentId),
            ),
          ])
          ..where(
            studentAcademicHistories.academicYearId.equals(academicYearId) &
                studentAcademicHistories.classId.equals(classId) &
                studentAcademicHistories.sectionId.equals(sectionId),
          )
          ..orderBy([
            OrderingTerm(
              expression: studentAcademicHistories.rollNumber,
              mode: OrderingMode.asc,
            ),
            OrderingTerm(expression: students.name, mode: OrderingMode.asc),
          ]);

    final rows = await query.get();
    return rows.map((row) {
      return StudentAcademicHistoryWithDetails(
        history: row.readTable(studentAcademicHistories),
        academicYear: row.readTable(academicYears),
        schoolClass: row.readTable(schoolClasses),
        section: row.readTable(sections),
      );
    }).toList();
  }

  /// Query latest student ID for a given year prefix to generate sequential IDs (e.g. '20260001')
  Future<String?> getLatestStudentIdForYear(int year) async {
    final prefix = '$year%';
    final query =
        select(students)
          ..where((t) => t.studentId.like(prefix))
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.studentId, mode: OrderingMode.desc),
          ])
          ..limit(1);
    final result = await query.getSingleOrNull();
    return result?.studentId;
  }

  /// Query latest admission number for a given year prefix (e.g. 'ADM-2026-0001')
  Future<String?> getLatestAdmissionNumberForYear(int year) async {
    final prefix = 'ADM-$year-%';
    final query =
        select(students)
          ..where((t) => t.admissionNumber.like(prefix))
          ..orderBy([
            (t) => OrderingTerm(
              expression: t.admissionNumber,
              mode: OrderingMode.desc,
            ),
          ])
          ..limit(1);
    final result = await query.getSingleOrNull();
    return result?.admissionNumber;
  }

  // ================= EXPENSE CATEGORIES DAO =================

  /// Stream all expense categories sorted by name
  Stream<List<ExpenseCategory>> watchAllExpenseCategories() {
    return (select(expenseCategories)
      ..orderBy([(t) => OrderingTerm(expression: t.name)])).watch();
  }

  /// Get all expense categories as future
  Future<List<ExpenseCategory>> getAllExpenseCategories() {
    return (select(expenseCategories)
      ..orderBy([(t) => OrderingTerm(expression: t.name)])).get();
  }

  /// Insert a new expense category
  Future<int> insertExpenseCategory(
    ExpenseCategoriesCompanion companion, {
    InsertMode mode = InsertMode.insertOrReplace,
  }) {
    return into(expenseCategories).insert(companion, mode: mode);
  }

  /// Update an existing expense category
  Future<bool> updateExpenseCategory(ExpenseCategory category) {
    return update(expenseCategories).replace(category);
  }

  /// Delete an expense category by ID
  Future<int> deleteExpenseCategory(int id) {
    return (delete(expenseCategories)..where((t) => t.id.equals(id))).go();
  }

  /// Get an expense category by ID
  Future<ExpenseCategory?> getExpenseCategoryById(int id) {
    return (select(expenseCategories)
      ..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  // ================= EXPENSES DAO =================

  /// Reactive stream of expenses joined with their categories and academic years
  Stream<List<ExpenseWithCategory>> watchExpensesWithCategory({
    DateTime? startDate,
    DateTime? endDate,
    int? categoryId,
    String? query,
    int? academicYearId,
  }) {
    final q = select(expenses).join([
      innerJoin(
        expenseCategories,
        expenseCategories.id.equalsExp(expenses.categoryId),
      ),
      leftOuterJoin(
        academicYears,
        academicYears.id.equalsExp(expenses.academicYearId),
      ),
    ]);

    if (academicYearId != null) {
      q.where(expenses.academicYearId.equals(academicYearId));
    }
    if (startDate != null) {
      q.where(expenses.expenseDate.isBiggerOrEqualValue(startDate));
    }
    if (endDate != null) {
      q.where(expenses.expenseDate.isSmallerOrEqualValue(endDate));
    }
    if (categoryId != null) {
      q.where(expenses.categoryId.equals(categoryId));
    }
    if (query != null && query.trim().isNotEmpty) {
      final term = '%${query.trim().toLowerCase()}%';
      q.where(
        expenses.title.lower().like(term) |
            expenses.paidTo.lower().like(term) |
            expenses.referenceNumber.lower().like(term) |
            expenses.paymentMethod.lower().like(term) |
            expenseCategories.name.lower().like(term),
      );
    }

    q.orderBy([
      OrderingTerm(expression: expenses.expenseDate, mode: OrderingMode.desc),
      OrderingTerm(expression: expenses.id, mode: OrderingMode.desc),
    ]);

    return q.watch().map((rows) {
      return rows.map((row) {
        return ExpenseWithCategory(
          expense: row.readTable(expenses),
          category: row.readTable(expenseCategories),
          academicYear: row.readTableOrNull(academicYears),
        );
      }).toList();
    });
  }

  /// Get expenses joined with categories as Future
  Future<List<ExpenseWithCategory>> getExpensesWithCategory({
    DateTime? startDate,
    DateTime? endDate,
    int? categoryId,
    String? query,
    int? academicYearId,
  }) {
    final q = select(expenses).join([
      innerJoin(
        expenseCategories,
        expenseCategories.id.equalsExp(expenses.categoryId),
      ),
      leftOuterJoin(
        academicYears,
        academicYears.id.equalsExp(expenses.academicYearId),
      ),
    ]);

    if (academicYearId != null) {
      q.where(expenses.academicYearId.equals(academicYearId));
    }
    if (startDate != null) {
      q.where(expenses.expenseDate.isBiggerOrEqualValue(startDate));
    }
    if (endDate != null) {
      q.where(expenses.expenseDate.isSmallerOrEqualValue(endDate));
    }
    if (categoryId != null) {
      q.where(expenses.categoryId.equals(categoryId));
    }
    if (query != null && query.trim().isNotEmpty) {
      final term = '%${query.trim().toLowerCase()}%';
      q.where(
        expenses.title.lower().like(term) |
            expenses.paidTo.lower().like(term) |
            expenses.referenceNumber.lower().like(term) |
            expenses.paymentMethod.lower().like(term) |
            expenseCategories.name.lower().like(term),
      );
    }

    q.orderBy([
      OrderingTerm(expression: expenses.expenseDate, mode: OrderingMode.desc),
      OrderingTerm(expression: expenses.id, mode: OrderingMode.desc),
    ]);

    return q.get().then((rows) {
      return rows.map((row) {
        return ExpenseWithCategory(
          expense: row.readTable(expenses),
          category: row.readTable(expenseCategories),
          academicYear: row.readTableOrNull(academicYears),
        );
      }).toList();
    });
  }

  /// Insert a new expense
  Future<int> insertExpense(ExpensesCompanion companion) {
    return into(expenses).insert(companion);
  }

  /// Update an existing expense
  Future<bool> updateExpenseEntry(Expense expense) {
    return update(expenses).replace(expense);
  }

  /// Delete an expense by ID
  Future<int> deleteExpense(int id) {
    return (delete(expenses)..where((t) => t.id.equals(id))).go();
  }

  /// Get an expense by ID
  Future<Expense?> getExpenseById(int id) {
    return (select(expenses)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  // ==========================================
  // EMPLOYEE PAYROLL & SALARY ADVANCES DAO
  // ==========================================

  /// Watch salary payments with joined employee and academic year
  Stream<List<SalaryPaymentWithDetails>> watchSalaryPaymentsWithDetails({
    int? year,
    int? month,
    EmployeeType? employeeType,
    String? query,
    int? academicYearId,
  }) {
    final q = select(salaryPayments).join([
      innerJoin(employees, employees.id.equalsExp(salaryPayments.employeeId)),
      leftOuterJoin(
        academicYears,
        academicYears.id.equalsExp(salaryPayments.academicYearId),
      ),
    ]);

    if (academicYearId != null) {
      q.where(salaryPayments.academicYearId.equals(academicYearId));
    }
    if (year != null) {
      q.where(salaryPayments.year.equals(year));
    }
    if (month != null) {
      q.where(salaryPayments.month.equals(month));
    }
    if (employeeType != null) {
      q.where(employees.employeeType.equals(employeeType.name));
    }
    if (query != null && query.trim().isNotEmpty) {
      final term = '%${query.trim().toLowerCase()}%';
      q.where(
        employees.name.lower().like(term) |
            employees.designation.lower().like(term) |
            salaryPayments.referenceNumber.lower().like(term) |
            salaryPayments.paymentMethod.lower().like(term),
      );
    }

    q.orderBy([
      OrderingTerm(
        expression: salaryPayments.paymentDate,
        mode: OrderingMode.desc,
      ),
      OrderingTerm(expression: salaryPayments.id, mode: OrderingMode.desc),
    ]);

    return q.watch().asyncMap((rows) async {
      final result = <SalaryPaymentWithDetails>[];
      for (final row in rows) {
        final payment = row.readTable(salaryPayments);
        final adjustments =
            await (select(salaryAdvanceAdjustments)
              ..where((t) => t.salaryPaymentId.equals(payment.id))).get();
        result.add(
          SalaryPaymentWithDetails(
            payment: payment,
            employee: row.readTable(employees),
            academicYear: row.readTableOrNull(academicYears),
            adjustments: adjustments,
          ),
        );
      }
      return result;
    });
  }

  /// Get salary payments with joined employee and academic year
  Future<List<SalaryPaymentWithDetails>> getSalaryPaymentsWithDetails({
    int? year,
    int? month,
    EmployeeType? employeeType,
    String? query,
    int? academicYearId,
  }) async {
    final q = select(salaryPayments).join([
      innerJoin(employees, employees.id.equalsExp(salaryPayments.employeeId)),
      leftOuterJoin(
        academicYears,
        academicYears.id.equalsExp(salaryPayments.academicYearId),
      ),
    ]);

    if (academicYearId != null) {
      q.where(salaryPayments.academicYearId.equals(academicYearId));
    }
    if (year != null) {
      q.where(salaryPayments.year.equals(year));
    }
    if (month != null) {
      q.where(salaryPayments.month.equals(month));
    }
    if (employeeType != null) {
      q.where(employees.employeeType.equals(employeeType.name));
    }
    if (query != null && query.trim().isNotEmpty) {
      final term = '%${query.trim().toLowerCase()}%';
      q.where(
        employees.name.lower().like(term) |
            employees.designation.lower().like(term) |
            salaryPayments.referenceNumber.lower().like(term) |
            salaryPayments.paymentMethod.lower().like(term),
      );
    }

    q.orderBy([
      OrderingTerm(
        expression: salaryPayments.paymentDate,
        mode: OrderingMode.desc,
      ),
      OrderingTerm(expression: salaryPayments.id, mode: OrderingMode.desc),
    ]);

    final rows = await q.get();
    final result = <SalaryPaymentWithDetails>[];
    for (final row in rows) {
      final payment = row.readTable(salaryPayments);
      final adjustments =
          await (select(salaryAdvanceAdjustments)
            ..where((t) => t.salaryPaymentId.equals(payment.id))).get();
      result.add(
        SalaryPaymentWithDetails(
          payment: payment,
          employee: row.readTable(employees),
          academicYear: row.readTableOrNull(academicYears),
          adjustments: adjustments,
        ),
      );
    }
    return result;
  }

  /// Insert a salary payment
  Future<int> insertSalaryPayment(SalaryPaymentsCompanion companion) {
    return into(salaryPayments).insert(companion);
  }

  /// Update salary payment
  Future<bool> updateSalaryPaymentEntry(SalaryPayment payment) {
    return update(salaryPayments).replace(payment);
  }

  /// Delete salary payment
  Future<int> deleteSalaryPayment(int id) {
    return (delete(salaryPayments)..where((t) => t.id.equals(id))).go();
  }

  /// Get salary payment by ID
  Future<SalaryPayment?> getSalaryPaymentById(int id) {
    return (select(salaryPayments)
      ..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Watch salary advances with joined employee
  Stream<List<SalaryAdvanceWithEmployee>> watchSalaryAdvancesWithEmployee({
    int? employeeId,
    String? status,
    String? query,
    int? academicYearId,
  }) {
    final q = select(salaryAdvances).join([
      innerJoin(employees, employees.id.equalsExp(salaryAdvances.employeeId)),
      leftOuterJoin(
        academicYears,
        academicYears.id.equalsExp(salaryAdvances.academicYearId),
      ),
    ]);

    if (academicYearId != null) {
      q.where(salaryAdvances.academicYearId.equals(academicYearId));
    }
    if (employeeId != null) {
      q.where(salaryAdvances.employeeId.equals(employeeId));
    }
    if (status != null && status != 'all') {
      if (status == 'settled') {
        q.where(salaryAdvances.status.equals('settled'));
      } else if (status == 'active' || status == 'pending') {
        q.where(salaryAdvances.status.isNotValue('settled'));
      }
    }
    if (query != null && query.trim().isNotEmpty) {
      final term = '%${query.trim().toLowerCase()}%';
      q.where(
        employees.name.lower().like(term) |
            employees.designation.lower().like(term) |
            salaryAdvances.reason.lower().like(term) |
            salaryAdvances.referenceNumber.lower().like(term),
      );
    }

    q.orderBy([
      OrderingTerm(
        expression: salaryAdvances.advanceDate,
        mode: OrderingMode.desc,
      ),
      OrderingTerm(expression: salaryAdvances.id, mode: OrderingMode.desc),
    ]);

    return q.watch().map((rows) {
      return rows.map((row) {
        return SalaryAdvanceWithEmployee(
          advance: row.readTable(salaryAdvances),
          employee: row.readTable(employees),
          academicYear: row.readTableOrNull(academicYears),
        );
      }).toList();
    });
  }

  /// Get salary advances with joined employee
  Future<List<SalaryAdvanceWithEmployee>> getSalaryAdvancesWithEmployee({
    int? employeeId,
    String? status,
    String? query,
    int? academicYearId,
  }) {
    final q = select(salaryAdvances).join([
      innerJoin(employees, employees.id.equalsExp(salaryAdvances.employeeId)),
      leftOuterJoin(
        academicYears,
        academicYears.id.equalsExp(salaryAdvances.academicYearId),
      ),
    ]);

    if (academicYearId != null) {
      q.where(salaryAdvances.academicYearId.equals(academicYearId));
    }
    if (employeeId != null) {
      q.where(salaryAdvances.employeeId.equals(employeeId));
    }
    if (status != null && status != 'all') {
      if (status == 'settled') {
        q.where(salaryAdvances.status.equals('settled'));
      } else if (status == 'active' || status == 'pending') {
        q.where(salaryAdvances.status.isNotValue('settled'));
      }
    }
    if (query != null && query.trim().isNotEmpty) {
      final term = '%${query.trim().toLowerCase()}%';
      q.where(
        employees.name.lower().like(term) |
            employees.designation.lower().like(term) |
            salaryAdvances.reason.lower().like(term) |
            salaryAdvances.referenceNumber.lower().like(term),
      );
    }

    q.orderBy([
      OrderingTerm(
        expression: salaryAdvances.advanceDate,
        mode: OrderingMode.desc,
      ),
      OrderingTerm(expression: salaryAdvances.id, mode: OrderingMode.desc),
    ]);

    return q.get().then((rows) {
      return rows.map((row) {
        return SalaryAdvanceWithEmployee(
          advance: row.readTable(salaryAdvances),
          employee: row.readTable(employees),
          academicYear: row.readTableOrNull(academicYears),
        );
      }).toList();
    });
  }

  /// Get all pending/partially settled advances for an employee (ordered chronologically FIFO)
  Future<List<SalaryAdvance>> getPendingAdvancesForEmployee(int employeeId) {
    return (select(salaryAdvances)
          ..where(
            (t) =>
                t.employeeId.equals(employeeId) &
                t.status.isNotValue('settled'),
          )
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.advanceDate, mode: OrderingMode.asc),
          ]))
        .get();
  }

  /// Insert salary advance
  Future<int> insertSalaryAdvance(SalaryAdvancesCompanion companion) {
    return into(salaryAdvances).insert(companion);
  }

  /// Update salary advance
  Future<bool> updateSalaryAdvanceEntry(SalaryAdvance advance) {
    return update(salaryAdvances).replace(advance);
  }

  /// Delete salary advance
  Future<int> deleteSalaryAdvance(int id) {
    return (delete(salaryAdvances)..where((t) => t.id.equals(id))).go();
  }

  /// Get salary advance by ID
  Future<SalaryAdvance?> getSalaryAdvanceById(int id) {
    return (select(salaryAdvances)
      ..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Insert advance adjustment link
  Future<int> insertSalaryAdvanceAdjustment(
    SalaryAdvanceAdjustmentsCompanion companion,
  ) {
    return into(salaryAdvanceAdjustments).insert(companion);
  }

  /// Get adjustments for a payment
  Future<List<SalaryAdvanceAdjustment>> getAdjustmentsForPayment(
    int paymentId,
  ) {
    return (select(salaryAdvanceAdjustments)
      ..where((t) => t.salaryPaymentId.equals(paymentId))).get();
  }

  /// Delete adjustments for a payment
  Future<int> deleteAdjustmentsForPayment(int paymentId) {
    return (delete(salaryAdvanceAdjustments)
      ..where((t) => t.salaryPaymentId.equals(paymentId))).go();
  }

  // ==================== FEE MANAGEMENT ====================

  /// Stream all fee categories
  Stream<List<FeeCategory>> watchAllFeeCategories() {
    return (select(feeCategories)..orderBy([
      (t) => OrderingTerm(expression: t.name, mode: OrderingMode.asc),
    ])).watch();
  }

  /// Get all fee categories
  Future<List<FeeCategory>> getAllFeeCategories() {
    return (select(feeCategories)..orderBy([
      (t) => OrderingTerm(expression: t.name, mode: OrderingMode.asc),
    ])).get();
  }

  /// Insert fee category
  Future<int> insertFeeCategory(FeeCategoriesCompanion companion) {
    return into(feeCategories).insert(companion);
  }

  /// Update fee category
  Future<bool> updateFeeCategory(FeeCategory category) {
    return update(feeCategories).replace(category);
  }

  /// Delete fee category
  Future<int> deleteFeeCategory(int id) {
    return (delete(feeCategories)..where((t) => t.id.equals(id))).go();
  }

  /// Get fee category by ID
  Future<FeeCategory?> getFeeCategoryById(int id) {
    return (select(feeCategories)
      ..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Watch student fees with joined student, category, and academic year
  Stream<List<StudentFeeWithDetails>> watchStudentFeesWithDetails({
    int? studentId,
    int? academicYearId,
    String? status,
    String? frequency,
    String? query,
  }) {
    final q = select(studentFees).join([
      innerJoin(students, students.id.equalsExp(studentFees.studentId)),
      innerJoin(
        feeCategories,
        feeCategories.id.equalsExp(studentFees.feeCategoryId),
      ),
      leftOuterJoin(
        academicYears,
        academicYears.id.equalsExp(studentFees.academicYearId),
      ),
    ]);

    if (studentId != null) {
      q.where(studentFees.studentId.equals(studentId));
    }
    if (academicYearId != null) {
      q.where(studentFees.academicYearId.equals(academicYearId));
    }
    if (status != null && status != 'all') {
      q.where(studentFees.status.equals(status));
    }
    if (frequency != null && frequency != 'all') {
      q.where(feeCategories.frequency.equals(frequency));
    }
    if (query != null && query.trim().isNotEmpty) {
      final term = '%${query.trim().toLowerCase()}%';
      q.where(
        students.name.lower().like(term) |
            students.admissionNumber.lower().like(term) |
            studentFees.title.lower().like(term) |
            feeCategories.name.lower().like(term),
      );
    }

    q.orderBy([
      OrderingTerm(expression: studentFees.dueDate, mode: OrderingMode.desc),
      OrderingTerm(expression: studentFees.id, mode: OrderingMode.desc),
    ]);

    return q.watch().asyncMap((rows) async {
      final result = <StudentFeeWithDetails>[];
      for (final row in rows) {
        final fee = row.readTable(studentFees);
        final payments =
            await (select(feePayments)
                  ..where((t) => t.studentFeeId.equals(fee.id))
                  ..orderBy([
                    (t) => OrderingTerm(
                      expression: t.paymentDate,
                      mode: OrderingMode.desc,
                    ),
                  ]))
                .get();
        result.add(
          StudentFeeWithDetails(
            fee: fee,
            student: row.readTable(students),
            category: row.readTable(feeCategories),
            academicYear: row.readTableOrNull(academicYears),
            payments: payments,
          ),
        );
      }
      return result;
    });
  }

  /// Get student fees with joined student, category, and academic year
  Future<List<StudentFeeWithDetails>> getStudentFeesWithDetails({
    int? studentId,
    int? academicYearId,
    String? status,
    String? frequency,
    String? query,
  }) async {
    final q = select(studentFees).join([
      innerJoin(students, students.id.equalsExp(studentFees.studentId)),
      innerJoin(
        feeCategories,
        feeCategories.id.equalsExp(studentFees.feeCategoryId),
      ),
      leftOuterJoin(
        academicYears,
        academicYears.id.equalsExp(studentFees.academicYearId),
      ),
    ]);

    if (studentId != null) {
      q.where(studentFees.studentId.equals(studentId));
    }
    if (academicYearId != null) {
      q.where(studentFees.academicYearId.equals(academicYearId));
    }
    if (status != null && status != 'all') {
      q.where(studentFees.status.equals(status));
    }
    if (frequency != null && frequency != 'all') {
      q.where(feeCategories.frequency.equals(frequency));
    }
    if (query != null && query.trim().isNotEmpty) {
      final term = '%${query.trim().toLowerCase()}%';
      q.where(
        students.name.lower().like(term) |
            students.admissionNumber.lower().like(term) |
            studentFees.title.lower().like(term) |
            feeCategories.name.lower().like(term),
      );
    }

    q.orderBy([
      OrderingTerm(expression: studentFees.dueDate, mode: OrderingMode.desc),
      OrderingTerm(expression: studentFees.id, mode: OrderingMode.desc),
    ]);

    final rows = await q.get();
    final result = <StudentFeeWithDetails>[];
    for (final row in rows) {
      final fee = row.readTable(studentFees);
      final payments =
          await (select(feePayments)
                ..where((t) => t.studentFeeId.equals(fee.id))
                ..orderBy([
                  (t) => OrderingTerm(
                    expression: t.paymentDate,
                    mode: OrderingMode.desc,
                  ),
                ]))
              .get();
      result.add(
        StudentFeeWithDetails(
          fee: fee,
          student: row.readTable(students),
          category: row.readTable(feeCategories),
          academicYear: row.readTableOrNull(academicYears),
          payments: payments,
        ),
      );
    }
    return result;
  }

  /// Insert student fee
  Future<int> insertStudentFee(StudentFeesCompanion companion) {
    return into(studentFees).insert(companion);
  }

  /// Update student fee
  Future<bool> updateStudentFeeEntry(StudentFee fee) {
    return update(studentFees).replace(fee);
  }

  /// Delete student fee
  Future<int> deleteStudentFee(int id) {
    return (delete(studentFees)..where((t) => t.id.equals(id))).go();
  }

  /// Get student fee by ID
  Future<StudentFee?> getStudentFeeById(int id) {
    return (select(studentFees)
      ..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Watch fee payments with details
  Stream<List<FeePaymentWithDetails>> watchFeePaymentsWithDetails({
    int? studentId,
    int? academicYearId,
    DateTime? startDate,
    DateTime? endDate,
    String? query,
  }) {
    final q = select(feePayments).join([
      innerJoin(
        studentFees,
        studentFees.id.equalsExp(feePayments.studentFeeId),
      ),
      innerJoin(students, students.id.equalsExp(feePayments.studentId)),
      innerJoin(
        feeCategories,
        feeCategories.id.equalsExp(studentFees.feeCategoryId),
      ),
      leftOuterJoin(
        academicYears,
        academicYears.id.equalsExp(feePayments.academicYearId),
      ),
    ]);

    if (studentId != null) {
      q.where(feePayments.studentId.equals(studentId));
    }
    if (academicYearId != null) {
      q.where(feePayments.academicYearId.equals(academicYearId));
    }
    if (startDate != null) {
      q.where(feePayments.paymentDate.isBiggerOrEqualValue(startDate));
    }
    if (endDate != null) {
      q.where(feePayments.paymentDate.isSmallerOrEqualValue(endDate));
    }
    if (query != null && query.trim().isNotEmpty) {
      final term = '%${query.trim().toLowerCase()}%';
      q.where(
        students.name.lower().like(term) |
            students.admissionNumber.lower().like(term) |
            feePayments.receiptNumber.lower().like(term) |
            studentFees.title.lower().like(term) |
            feePayments.paymentMethod.lower().like(term),
      );
    }

    q.orderBy([
      OrderingTerm(
        expression: feePayments.paymentDate,
        mode: OrderingMode.desc,
      ),
      OrderingTerm(expression: feePayments.id, mode: OrderingMode.desc),
    ]);

    return q.watch().map((rows) {
      return rows.map((row) {
        return FeePaymentWithDetails(
          payment: row.readTable(feePayments),
          fee: row.readTable(studentFees),
          student: row.readTable(students),
          category: row.readTable(feeCategories),
          academicYear: row.readTableOrNull(academicYears),
        );
      }).toList();
    });
  }

  /// Get fee payments with details
  Future<List<FeePaymentWithDetails>> getFeePaymentsWithDetails({
    int? studentId,
    int? academicYearId,
    DateTime? startDate,
    DateTime? endDate,
    String? query,
  }) async {
    final q = select(feePayments).join([
      innerJoin(
        studentFees,
        studentFees.id.equalsExp(feePayments.studentFeeId),
      ),
      innerJoin(students, students.id.equalsExp(feePayments.studentId)),
      innerJoin(
        feeCategories,
        feeCategories.id.equalsExp(studentFees.feeCategoryId),
      ),
      leftOuterJoin(
        academicYears,
        academicYears.id.equalsExp(feePayments.academicYearId),
      ),
    ]);

    if (studentId != null) {
      q.where(feePayments.studentId.equals(studentId));
    }
    if (academicYearId != null) {
      q.where(feePayments.academicYearId.equals(academicYearId));
    }
    if (startDate != null) {
      q.where(feePayments.paymentDate.isBiggerOrEqualValue(startDate));
    }
    if (endDate != null) {
      q.where(feePayments.paymentDate.isSmallerOrEqualValue(endDate));
    }
    if (query != null && query.trim().isNotEmpty) {
      final term = '%${query.trim().toLowerCase()}%';
      q.where(
        students.name.lower().like(term) |
            students.admissionNumber.lower().like(term) |
            feePayments.receiptNumber.lower().like(term) |
            studentFees.title.lower().like(term) |
            feePayments.paymentMethod.lower().like(term),
      );
    }

    q.orderBy([
      OrderingTerm(
        expression: feePayments.paymentDate,
        mode: OrderingMode.desc,
      ),
      OrderingTerm(expression: feePayments.id, mode: OrderingMode.desc),
    ]);

    final rows = await q.get();
    return rows.map((row) {
      return FeePaymentWithDetails(
        payment: row.readTable(feePayments),
        fee: row.readTable(studentFees),
        student: row.readTable(students),
        category: row.readTable(feeCategories),
        academicYear: row.readTableOrNull(academicYears),
      );
    }).toList();
  }

  /// Get payments for a specific student fee
  Future<List<FeePayment>> getFeePaymentsForStudentFee(int studentFeeId) {
    return (select(feePayments)
          ..where((t) => t.studentFeeId.equals(studentFeeId))
          ..orderBy([
            (t) => OrderingTerm(
              expression: t.paymentDate,
              mode: OrderingMode.desc,
            ),
          ]))
        .get();
  }

  /// Insert fee payment
  Future<int> insertFeePayment(FeePaymentsCompanion companion) {
    return into(feePayments).insert(companion);
  }

  /// Delete fee payment
  Future<int> deleteFeePayment(int id) {
    return (delete(feePayments)..where((t) => t.id.equals(id))).go();
  }

  /// Get fee payment by ID
  Future<FeePayment?> getFeePaymentById(int id) {
    return (select(feePayments)
      ..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  // ==================== CERTIFICATES ====================

  /// Watch all certificates with joined student, class, section, academic year
  Stream<List<CertificateWithDetails>> watchCertificatesWithDetails({
    String? certificateType,
    int? studentId,
    int? classId,
    int? academicYearId,
    String? query,
    String? status,
  }) {
    final q = select(certificates).join([
      innerJoin(students, students.id.equalsExp(certificates.studentId)),
      leftOuterJoin(
        schoolClasses,
        schoolClasses.id.equalsExp(students.classId),
      ),
      leftOuterJoin(sections, sections.id.equalsExp(students.sectionId)),
      leftOuterJoin(
        academicYears,
        academicYears.id.equalsExp(certificates.academicYearId),
      ),
    ]);

    if (certificateType != null && certificateType != 'all') {
      q.where(certificates.certificateType.equals(certificateType));
    }
    if (studentId != null) {
      q.where(certificates.studentId.equals(studentId));
    }
    if (classId != null) {
      q.where(students.classId.equals(classId));
    }
    if (academicYearId != null) {
      q.where(certificates.academicYearId.equals(academicYearId));
    }
    if (status != null && status != 'all') {
      q.where(certificates.status.equals(status));
    }
    if (query != null && query.trim().isNotEmpty) {
      final term = '%${query.trim()}%';
      q.where(
        certificates.certificateNumber.like(term) |
            students.name.like(term) |
            students.admissionNumber.like(term) |
            certificates.title.like(term),
      );
    }

    q.orderBy([
      OrderingTerm(expression: certificates.issueDate, mode: OrderingMode.desc),
      OrderingTerm(expression: certificates.id, mode: OrderingMode.desc),
    ]);

    return q.watch().map((rows) {
      return rows.map((row) {
        return CertificateWithDetails(
          certificate: row.readTable(certificates),
          student: row.readTable(students),
          schoolClass: row.readTableOrNull(schoolClasses),
          section: row.readTableOrNull(sections),
          academicYear: row.readTableOrNull(academicYears),
        );
      }).toList();
    });
  }

  /// Get certificates with details as future
  Future<List<CertificateWithDetails>> getCertificatesWithDetails({
    String? certificateType,
    int? studentId,
    int? classId,
    int? academicYearId,
    String? query,
    String? status,
  }) {
    final q = select(certificates).join([
      innerJoin(students, students.id.equalsExp(certificates.studentId)),
      leftOuterJoin(
        schoolClasses,
        schoolClasses.id.equalsExp(students.classId),
      ),
      leftOuterJoin(sections, sections.id.equalsExp(students.sectionId)),
      leftOuterJoin(
        academicYears,
        academicYears.id.equalsExp(certificates.academicYearId),
      ),
    ]);

    if (certificateType != null && certificateType != 'all') {
      q.where(certificates.certificateType.equals(certificateType));
    }
    if (studentId != null) {
      q.where(certificates.studentId.equals(studentId));
    }
    if (classId != null) {
      q.where(students.classId.equals(classId));
    }
    if (academicYearId != null) {
      q.where(certificates.academicYearId.equals(academicYearId));
    }
    if (status != null && status != 'all') {
      q.where(certificates.status.equals(status));
    }
    if (query != null && query.trim().isNotEmpty) {
      final term = '%${query.trim()}%';
      q.where(
        certificates.certificateNumber.like(term) |
            students.name.like(term) |
            students.admissionNumber.like(term) |
            certificates.title.like(term),
      );
    }

    q.orderBy([
      OrderingTerm(expression: certificates.issueDate, mode: OrderingMode.desc),
      OrderingTerm(expression: certificates.id, mode: OrderingMode.desc),
    ]);

    return q.get().then((rows) {
      return rows.map((row) {
        return CertificateWithDetails(
          certificate: row.readTable(certificates),
          student: row.readTable(students),
          schoolClass: row.readTableOrNull(schoolClasses),
          section: row.readTableOrNull(sections),
          academicYear: row.readTableOrNull(academicYears),
        );
      }).toList();
    });
  }

  /// Get single certificate with details by ID
  Future<CertificateWithDetails?> getCertificateWithDetailsById(int id) {
    final q = select(certificates).join([
      innerJoin(students, students.id.equalsExp(certificates.studentId)),
      leftOuterJoin(
        schoolClasses,
        schoolClasses.id.equalsExp(students.classId),
      ),
      leftOuterJoin(sections, sections.id.equalsExp(students.sectionId)),
      leftOuterJoin(
        academicYears,
        academicYears.id.equalsExp(certificates.academicYearId),
      ),
    ])..where(certificates.id.equals(id));

    return q.getSingleOrNull().then((row) {
      if (row == null) return null;
      return CertificateWithDetails(
        certificate: row.readTable(certificates),
        student: row.readTable(students),
        schoolClass: row.readTableOrNull(schoolClasses),
        section: row.readTableOrNull(sections),
        academicYear: row.readTableOrNull(academicYears),
      );
    });
  }

  /// Insert a certificate
  Future<int> insertCertificate(CertificatesCompanion companion) {
    return into(certificates).insert(companion);
  }

  /// Update a certificate
  Future<bool> updateCertificate(Insertable<Certificate> companion) {
    return update(certificates).replace(companion);
  }

  /// Delete a certificate
  Future<int> deleteCertificate(int id) {
    return (delete(certificates)..where((t) => t.id.equals(id))).go();
  }

  /// Count certificates
  Future<int> countCertificates({String? certificateType}) {
    final countExp = certificates.id.count();
    final q = selectOnly(certificates)..addColumns([countExp]);
    if (certificateType != null) {
      q.where(certificates.certificateType.equals(certificateType));
    }
    return q.map((r) => r.read(countExp) ?? 0).getSingle();
  }

  // ==========================================
  // EXAMS & EXAM SCHEDULES
  // ==========================================

  /// Watch reactive list of exams with details
  Stream<List<ExamWithDetails>> watchExamsWithDetails({
    int? academicYearId,
    String? category,
    String? status,
  }) {
    final query = select(exams).join([
      innerJoin(
        academicYears,
        academicYears.id.equalsExp(exams.academicYearId),
      ),
    ]);

    if (academicYearId != null) {
      query.where(exams.academicYearId.equals(academicYearId));
    }
    if (category != null && category.trim().isNotEmpty) {
      query.where(exams.category.equals(category.trim()));
    }
    if (status != null && status.trim().isNotEmpty) {
      query.where(exams.status.equals(status.trim()));
    }

    query.orderBy([
      OrderingTerm(expression: exams.startDate, mode: OrderingMode.desc),
    ]);

    return query.watch().asyncMap((rows) async {
      final result = <ExamWithDetails>[];
      for (final row in rows) {
        final examRow = row.readTable(exams);
        final yearRow = row.readTable(academicYears);

        // Count schedules and distinct classes
        final scheduleCountExp = examSchedules.id.count();
        final classCountExp = examSchedules.classId.count(distinct: true);
        final countQuery =
            selectOnly(examSchedules)
              ..addColumns([scheduleCountExp, classCountExp])
              ..where(examSchedules.examId.equals(examRow.id));
        final countRow = await countQuery.getSingleOrNull();

        result.add(
          ExamWithDetails(
            exam: examRow,
            academicYear: yearRow,
            scheduleCount: countRow?.read(scheduleCountExp) ?? 0,
            classCount: countRow?.read(classCountExp) ?? 0,
          ),
        );
      }
      return result;
    });
  }

  /// Get all exams with details
  Future<List<ExamWithDetails>> getAllExamsWithDetails({
    int? academicYearId,
    String? category,
    String? status,
  }) async {
    final query = select(exams).join([
      innerJoin(
        academicYears,
        academicYears.id.equalsExp(exams.academicYearId),
      ),
    ]);

    if (academicYearId != null) {
      query.where(exams.academicYearId.equals(academicYearId));
    }
    if (category != null && category.trim().isNotEmpty) {
      query.where(exams.category.equals(category.trim()));
    }
    if (status != null && status.trim().isNotEmpty) {
      query.where(exams.status.equals(status.trim()));
    }

    query.orderBy([
      OrderingTerm(expression: exams.startDate, mode: OrderingMode.desc),
    ]);

    final rows = await query.get();
    final result = <ExamWithDetails>[];
    for (final row in rows) {
      final examRow = row.readTable(exams);
      final yearRow = row.readTable(academicYears);

      final scheduleCountExp = examSchedules.id.count();
      final classCountExp = examSchedules.classId.count(distinct: true);
      final countQuery =
          selectOnly(examSchedules)
            ..addColumns([scheduleCountExp, classCountExp])
            ..where(examSchedules.examId.equals(examRow.id));
      final countRow = await countQuery.getSingleOrNull();

      result.add(
        ExamWithDetails(
          exam: examRow,
          academicYear: yearRow,
          scheduleCount: countRow?.read(scheduleCountExp) ?? 0,
          classCount: countRow?.read(classCountExp) ?? 0,
        ),
      );
    }
    return result;
  }

  /// Get exam with details by ID
  Future<ExamWithDetails?> getExamWithDetailsById(int id) async {
    final query = select(exams).join([
      innerJoin(
        academicYears,
        academicYears.id.equalsExp(exams.academicYearId),
      ),
    ])..where(exams.id.equals(id));

    final row = await query.getSingleOrNull();
    if (row == null) return null;

    final examRow = row.readTable(exams);
    final yearRow = row.readTable(academicYears);

    final scheduleCountExp = examSchedules.id.count();
    final classCountExp = examSchedules.classId.count(distinct: true);
    final countQuery =
        selectOnly(examSchedules)
          ..addColumns([scheduleCountExp, classCountExp])
          ..where(examSchedules.examId.equals(examRow.id));
    final countRow = await countQuery.getSingleOrNull();

    return ExamWithDetails(
      exam: examRow,
      academicYear: yearRow,
      scheduleCount: countRow?.read(scheduleCountExp) ?? 0,
      classCount: countRow?.read(classCountExp) ?? 0,
    );
  }

  /// Insert exam
  Future<int> insertExam(ExamsCompanion companion) {
    return into(exams).insert(companion);
  }

  /// Update exam
  Future<bool> updateExam(Insertable<Exam> companion) {
    return update(exams).replace(companion);
  }

  /// Delete exam (cascades to examSchedules)
  Future<int> deleteExam(int id) {
    return (delete(exams)..where((t) => t.id.equals(id))).go();
  }

  /// Watch reactive list of exam schedules with details
  Stream<List<ExamScheduleWithDetails>> watchExamSchedulesWithDetails({
    int? examId,
    int? classId,
    int? academicYearId,
    int? subjectId,
  }) {
    final query = select(examSchedules).join([
      innerJoin(exams, exams.id.equalsExp(examSchedules.examId)),
      innerJoin(
        academicYears,
        academicYears.id.equalsExp(examSchedules.academicYearId),
      ),
      innerJoin(
        schoolClasses,
        schoolClasses.id.equalsExp(examSchedules.classId),
      ),
      innerJoin(subjects, subjects.id.equalsExp(examSchedules.subjectId)),
    ]);

    if (examId != null) {
      query.where(examSchedules.examId.equals(examId));
    }
    if (classId != null) {
      query.where(examSchedules.classId.equals(classId));
    }
    if (academicYearId != null) {
      query.where(examSchedules.academicYearId.equals(academicYearId));
    }
    if (subjectId != null) {
      query.where(examSchedules.subjectId.equals(subjectId));
    }

    query.orderBy([
      OrderingTerm(expression: examSchedules.examDate, mode: OrderingMode.asc),
      OrderingTerm(
        expression: examSchedules.orderIndex,
        mode: OrderingMode.asc,
      ),
      OrderingTerm(expression: examSchedules.startTime, mode: OrderingMode.asc),
    ]);

    return query.watch().map((rows) {
      return rows.map((row) {
        return ExamScheduleWithDetails(
          schedule: row.readTable(examSchedules),
          exam: row.readTable(exams),
          academicYear: row.readTable(academicYears),
          schoolClass: row.readTable(schoolClasses),
          subject: row.readTable(subjects),
        );
      }).toList();
    });
  }

  /// Get all exam schedules with details
  Future<List<ExamScheduleWithDetails>> getAllExamSchedulesWithDetails({
    int? examId,
    int? classId,
    int? academicYearId,
    int? subjectId,
  }) {
    final query = select(examSchedules).join([
      innerJoin(exams, exams.id.equalsExp(examSchedules.examId)),
      innerJoin(
        academicYears,
        academicYears.id.equalsExp(examSchedules.academicYearId),
      ),
      innerJoin(
        schoolClasses,
        schoolClasses.id.equalsExp(examSchedules.classId),
      ),
      innerJoin(subjects, subjects.id.equalsExp(examSchedules.subjectId)),
    ]);

    if (examId != null) {
      query.where(examSchedules.examId.equals(examId));
    }
    if (classId != null) {
      query.where(examSchedules.classId.equals(classId));
    }
    if (academicYearId != null) {
      query.where(examSchedules.academicYearId.equals(academicYearId));
    }
    if (subjectId != null) {
      query.where(examSchedules.subjectId.equals(subjectId));
    }

    query.orderBy([
      OrderingTerm(expression: examSchedules.examDate, mode: OrderingMode.asc),
      OrderingTerm(
        expression: examSchedules.orderIndex,
        mode: OrderingMode.asc,
      ),
      OrderingTerm(expression: examSchedules.startTime, mode: OrderingMode.asc),
    ]);

    return query.map((row) {
      return ExamScheduleWithDetails(
        schedule: row.readTable(examSchedules),
        exam: row.readTable(exams),
        academicYear: row.readTable(academicYears),
        schoolClass: row.readTable(schoolClasses),
        subject: row.readTable(subjects),
      );
    }).get();
  }

  /// Insert single exam schedule
  Future<int> insertExamSchedule(ExamSchedulesCompanion companion) {
    return into(examSchedules).insert(companion);
  }

  /// Update single exam schedule
  Future<bool> updateExamSchedule(Insertable<ExamSchedule> companion) {
    return update(examSchedules).replace(companion);
  }

  /// Delete single exam schedule
  Future<int> deleteExamSchedule(int id) {
    return (delete(examSchedules)..where((t) => t.id.equals(id))).go();
  }

  /// Delete all schedules for a class within an exam
  Future<int> deleteExamSchedulesForClass(int examId, int classId) {
    return (delete(examSchedules)
      ..where((t) => t.examId.equals(examId) & t.classId.equals(classId))).go();
  }

  /// Replace all subject schedules for a given class in an exam (atomic transaction)
  Future<void> replaceClassExamSchedules(
    int examId,
    int classId,
    List<ExamSchedulesCompanion> companions,
  ) {
    return transaction(() async {
      await (delete(examSchedules)..where(
        (t) => t.examId.equals(examId) & t.classId.equals(classId),
      )).go();
      for (final companion in companions) {
        await into(examSchedules).insert(companion);
      }
    });
  }

  // ===========================================================================
  // Exam Results & Marks Operations
  // ===========================================================================

  /// Watch reactive stream of exam results with joined details
  Stream<List<ExamResultWithDetails>> watchExamResultsWithDetails({
    int? examId,
    int? classId,
    int? sectionId,
    int? subjectId,
    int? studentId,
    int? academicYearId,
  }) {
    final query = select(examResults).join([
      innerJoin(exams, exams.id.equalsExp(examResults.examId)),
      innerJoin(
        academicYears,
        academicYears.id.equalsExp(examResults.academicYearId),
      ),
      innerJoin(schoolClasses, schoolClasses.id.equalsExp(examResults.classId)),
      leftOuterJoin(sections, sections.id.equalsExp(examResults.sectionId)),
      innerJoin(students, students.id.equalsExp(examResults.studentId)),
      innerJoin(subjects, subjects.id.equalsExp(examResults.subjectId)),
      leftOuterJoin(
        examSchedules,
        examSchedules.id.equalsExp(examResults.examScheduleId),
      ),
    ]);

    if (examId != null) {
      query.where(examResults.examId.equals(examId));
    }
    if (classId != null) {
      query.where(examResults.classId.equals(classId));
    }
    if (sectionId != null) {
      query.where(examResults.sectionId.equals(sectionId));
    }
    if (subjectId != null) {
      query.where(examResults.subjectId.equals(subjectId));
    }
    if (studentId != null) {
      query.where(examResults.studentId.equals(studentId));
    }
    if (academicYearId != null) {
      query.where(examResults.academicYearId.equals(academicYearId));
    }

    query.orderBy([
      OrderingTerm(expression: students.rollNumber, mode: OrderingMode.asc),
      OrderingTerm(expression: students.name, mode: OrderingMode.asc),
    ]);

    return query.watch().map((rows) {
      return rows.map((row) {
        return ExamResultWithDetails(
          result: row.readTable(examResults),
          exam: row.readTable(exams),
          academicYear: row.readTable(academicYears),
          schoolClass: row.readTable(schoolClasses),
          section: row.readTableOrNull(sections),
          student: row.readTable(students),
          subject: row.readTable(subjects),
          schedule: row.readTableOrNull(examSchedules),
        );
      }).toList();
    });
  }

  /// Get exam results with joined details
  Future<List<ExamResultWithDetails>> getExamResultsWithDetails({
    int? examId,
    int? classId,
    int? sectionId,
    int? subjectId,
    int? studentId,
    int? academicYearId,
  }) {
    final query = select(examResults).join([
      innerJoin(exams, exams.id.equalsExp(examResults.examId)),
      innerJoin(
        academicYears,
        academicYears.id.equalsExp(examResults.academicYearId),
      ),
      innerJoin(schoolClasses, schoolClasses.id.equalsExp(examResults.classId)),
      leftOuterJoin(sections, sections.id.equalsExp(examResults.sectionId)),
      innerJoin(students, students.id.equalsExp(examResults.studentId)),
      innerJoin(subjects, subjects.id.equalsExp(examResults.subjectId)),
      leftOuterJoin(
        examSchedules,
        examSchedules.id.equalsExp(examResults.examScheduleId),
      ),
    ]);

    if (examId != null) {
      query.where(examResults.examId.equals(examId));
    }
    if (classId != null) {
      query.where(examResults.classId.equals(classId));
    }
    if (sectionId != null) {
      query.where(examResults.sectionId.equals(sectionId));
    }
    if (subjectId != null) {
      query.where(examResults.subjectId.equals(subjectId));
    }
    if (studentId != null) {
      query.where(examResults.studentId.equals(studentId));
    }
    if (academicYearId != null) {
      query.where(examResults.academicYearId.equals(academicYearId));
    }

    query.orderBy([
      OrderingTerm(expression: students.rollNumber, mode: OrderingMode.asc),
      OrderingTerm(expression: students.name, mode: OrderingMode.asc),
    ]);

    return query.map((row) {
      return ExamResultWithDetails(
        result: row.readTable(examResults),
        exam: row.readTable(exams),
        academicYear: row.readTable(academicYears),
        schoolClass: row.readTable(schoolClasses),
        section: row.readTableOrNull(sections),
        student: row.readTable(students),
        subject: row.readTable(subjects),
        schedule: row.readTableOrNull(examSchedules),
      );
    }).get();
  }

  /// Upsert single exam result
  Future<int> upsertExamResult(ExamResultsCompanion companion) {
    return into(
      examResults,
    ).insert(companion, mode: InsertMode.insertOrReplace);
  }

  /// Batch upsert exam results (fast bulk save)
  Future<void> batchUpsertExamResults(List<ExamResultsCompanion> companions) {
    return batch((b) {
      b.insertAll(examResults, companions, mode: InsertMode.insertOrReplace);
    });
  }

  /// Delete exam result by ID
  Future<int> deleteExamResult(int id) {
    return (delete(examResults)..where((t) => t.id.equals(id))).go();
  }

  /// Delete all exam results for an exam and class
  Future<int> deleteExamResultsForExamAndClass(
    int examId,
    int classId, {
    int? sectionId,
    int? subjectId,
  }) {
    var q = delete(examResults)
      ..where((t) => t.examId.equals(examId) & t.classId.equals(classId));
    if (sectionId != null) {
      q = delete(examResults)..where(
        (t) =>
            t.examId.equals(examId) &
            t.classId.equals(classId) &
            t.sectionId.equals(sectionId),
      );
    }
    if (subjectId != null) {
      q = delete(examResults)..where(
        (t) =>
            t.examId.equals(examId) &
            t.classId.equals(classId) &
            t.subjectId.equals(subjectId),
      );
    }
    return q.go();
  }

  /// Watch reactive stream of student exam summaries
  Stream<List<StudentExamSummaryWithDetails>>
  watchExamResultSummariesWithDetails({
    required int examId,
    int? classId,
    int? sectionId,
  }) {
    final query = select(examResultSummaries).join([
      innerJoin(exams, exams.id.equalsExp(examResultSummaries.examId)),
      innerJoin(
        academicYears,
        academicYears.id.equalsExp(examResultSummaries.academicYearId),
      ),
      innerJoin(
        schoolClasses,
        schoolClasses.id.equalsExp(examResultSummaries.classId),
      ),
      leftOuterJoin(
        sections,
        sections.id.equalsExp(examResultSummaries.sectionId),
      ),
      innerJoin(students, students.id.equalsExp(examResultSummaries.studentId)),
    ])..where(examResultSummaries.examId.equals(examId));

    if (classId != null) {
      query.where(examResultSummaries.classId.equals(classId));
    }
    if (sectionId != null) {
      query.where(examResultSummaries.sectionId.equals(sectionId));
    }

    query.orderBy([
      OrderingTerm(
        expression: examResultSummaries.overallGpa,
        mode: OrderingMode.desc,
      ),
      OrderingTerm(
        expression: examResultSummaries.overallPercentage,
        mode: OrderingMode.desc,
      ),
      OrderingTerm(expression: students.rollNumber, mode: OrderingMode.asc),
    ]);

    return query.watch().map((rows) {
      return rows.map((row) {
        return StudentExamSummaryWithDetails(
          summary: row.readTable(examResultSummaries),
          exam: row.readTable(exams),
          academicYear: row.readTable(academicYears),
          schoolClass: row.readTable(schoolClasses),
          section: row.readTableOrNull(sections),
          student: row.readTable(students),
        );
      }).toList();
    });
  }

  /// Get student exam summaries with joined details
  Future<List<StudentExamSummaryWithDetails>>
  getExamResultSummariesWithDetails({
    required int examId,
    int? classId,
    int? sectionId,
  }) {
    final query = select(examResultSummaries).join([
      innerJoin(exams, exams.id.equalsExp(examResultSummaries.examId)),
      innerJoin(
        academicYears,
        academicYears.id.equalsExp(examResultSummaries.academicYearId),
      ),
      innerJoin(
        schoolClasses,
        schoolClasses.id.equalsExp(examResultSummaries.classId),
      ),
      leftOuterJoin(
        sections,
        sections.id.equalsExp(examResultSummaries.sectionId),
      ),
      innerJoin(students, students.id.equalsExp(examResultSummaries.studentId)),
    ])..where(examResultSummaries.examId.equals(examId));

    if (classId != null) {
      query.where(examResultSummaries.classId.equals(classId));
    }
    if (sectionId != null) {
      query.where(examResultSummaries.sectionId.equals(sectionId));
    }

    query.orderBy([
      OrderingTerm(
        expression: examResultSummaries.overallGpa,
        mode: OrderingMode.desc,
      ),
      OrderingTerm(
        expression: examResultSummaries.overallPercentage,
        mode: OrderingMode.desc,
      ),
      OrderingTerm(expression: students.rollNumber, mode: OrderingMode.asc),
    ]);

    return query.map((row) {
      return StudentExamSummaryWithDetails(
        summary: row.readTable(examResultSummaries),
        exam: row.readTable(exams),
        academicYear: row.readTable(academicYears),
        schoolClass: row.readTable(schoolClasses),
        section: row.readTableOrNull(sections),
        student: row.readTable(students),
      );
    }).get();
  }

  /// Batch upsert student exam summaries
  Future<void> batchUpsertExamResultSummaries(
    List<ExamResultSummariesCompanion> companions,
  ) {
    return batch((b) {
      b.insertAll(
        examResultSummaries,
        companions,
        mode: InsertMode.insertOrReplace,
      );
    });
  }

  // ==================== ATTENDANCE METHODS ====================

  /// Insert or replace a student attendance record
  Future<int> upsertStudentAttendance(StudentAttendancesCompanion companion) {
    return into(studentAttendances).insertOnConflictUpdate(companion);
  }

  /// Batch insert or replace student attendance records
  Future<void> batchUpsertStudentAttendances(
    List<StudentAttendancesCompanion> companions,
  ) {
    return batch((b) {
      b.insertAll(
        studentAttendances,
        companions,
        mode: InsertMode.insertOrReplace,
      );
    });
  }

  /// Get student attendance records for a specific class, optional section, and date
  Future<List<StudentAttendanceWithStudent>>
  getStudentAttendancesForClassAndDate({
    required int classId,
    int? sectionId,
    required DateTime date,
  }) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final nextDate = normalizedDate.add(const Duration(days: 1));

    final query = select(studentAttendances).join([
      innerJoin(students, students.id.equalsExp(studentAttendances.studentId)),
    ])..where(
      studentAttendances.classId.equals(classId) &
          studentAttendances.date.isBiggerOrEqualValue(normalizedDate) &
          studentAttendances.date.isSmallerThanValue(nextDate),
    );

    if (sectionId != null) {
      query.where(studentAttendances.sectionId.equals(sectionId));
    }

    query.orderBy([
      OrderingTerm(expression: students.rollNumber, mode: OrderingMode.asc),
      OrderingTerm(expression: students.name, mode: OrderingMode.asc),
    ]);

    return query.map((row) {
      return StudentAttendanceWithStudent(
        attendance: row.readTable(studentAttendances),
        student: row.readTable(students),
      );
    }).get();
  }

  /// Stream of student attendance for a class, section, and date
  Stream<List<StudentAttendanceWithStudent>>
  watchStudentAttendancesForClassAndDate({
    required int classId,
    int? sectionId,
    required DateTime date,
  }) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final nextDate = normalizedDate.add(const Duration(days: 1));

    final query = select(studentAttendances).join([
      innerJoin(students, students.id.equalsExp(studentAttendances.studentId)),
    ])..where(
      studentAttendances.classId.equals(classId) &
          studentAttendances.date.isBiggerOrEqualValue(normalizedDate) &
          studentAttendances.date.isSmallerThanValue(nextDate),
    );

    if (sectionId != null) {
      query.where(studentAttendances.sectionId.equals(sectionId));
    }

    query.orderBy([
      OrderingTerm(expression: students.rollNumber, mode: OrderingMode.asc),
      OrderingTerm(expression: students.name, mode: OrderingMode.asc),
    ]);

    return query.map((row) {
      return StudentAttendanceWithStudent(
        attendance: row.readTable(studentAttendances),
        student: row.readTable(students),
      );
    }).watch();
  }

  /// Get student attendances within a date range (for monthly register)
  Future<List<StudentAttendance>> getStudentAttendancesInRange({
    required int classId,
    int? sectionId,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final query = select(studentAttendances)..where(
      (t) =>
          t.classId.equals(classId) &
          t.date.isBiggerOrEqualValue(startDate) &
          t.date.isSmallerOrEqualValue(endDate),
    );
    if (sectionId != null) {
      query.where((t) => t.sectionId.equals(sectionId));
    }
    return query.get();
  }

  /// Insert or replace employee attendance record
  Future<int> upsertEmployeeAttendance(EmployeeAttendancesCompanion companion) {
    return into(employeeAttendances).insertOnConflictUpdate(companion);
  }

  /// Batch insert or replace employee attendance records
  Future<void> batchUpsertEmployeeAttendances(
    List<EmployeeAttendancesCompanion> companions,
  ) {
    return batch((b) {
      b.insertAll(
        employeeAttendances,
        companions,
        mode: InsertMode.insertOrReplace,
      );
    });
  }

  /// Get employee attendance for a specific date with optional filters
  Future<List<EmployeeAttendanceWithEmployee>> getEmployeeAttendancesForDate({
    required DateTime date,
    String? department,
    EmployeeType? employeeType,
  }) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final nextDate = normalizedDate.add(const Duration(days: 1));

    final query = select(employeeAttendances).join([
      innerJoin(
        employees,
        employees.id.equalsExp(employeeAttendances.employeeId),
      ),
    ])..where(
      employeeAttendances.date.isBiggerOrEqualValue(normalizedDate) &
          employeeAttendances.date.isSmallerThanValue(nextDate),
    );

    if (department != null && department.isNotEmpty && department != 'All') {
      query.where(employees.department.equals(department));
    }
    if (employeeType != null) {
      query.where(employees.employeeType.equals(employeeType.name));
    }

    query.orderBy([
      OrderingTerm(expression: employees.name, mode: OrderingMode.asc),
    ]);

    return query.map((row) {
      return EmployeeAttendanceWithEmployee(
        attendance: row.readTable(employeeAttendances),
        employee: row.readTable(employees),
      );
    }).get();
  }

  /// Watch employee attendance for a specific date
  Stream<List<EmployeeAttendanceWithEmployee>> watchEmployeeAttendancesForDate({
    required DateTime date,
    String? department,
    EmployeeType? employeeType,
  }) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final nextDate = normalizedDate.add(const Duration(days: 1));

    final query = select(employeeAttendances).join([
      innerJoin(
        employees,
        employees.id.equalsExp(employeeAttendances.employeeId),
      ),
    ])..where(
      employeeAttendances.date.isBiggerOrEqualValue(normalizedDate) &
          employeeAttendances.date.isSmallerThanValue(nextDate),
    );

    if (department != null && department.isNotEmpty && department != 'All') {
      query.where(employees.department.equals(department));
    }
    if (employeeType != null) {
      query.where(employees.employeeType.equals(employeeType.name));
    }

    query.orderBy([
      OrderingTerm(expression: employees.name, mode: OrderingMode.asc),
    ]);

    return query.map((row) {
      return EmployeeAttendanceWithEmployee(
        attendance: row.readTable(employeeAttendances),
        employee: row.readTable(employees),
      );
    }).watch();
  }

  /// Get employee attendances within a date range (for staff monthly register)
  Future<List<EmployeeAttendance>> getEmployeeAttendancesInRange({
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final query = select(employeeAttendances)..where(
      (t) =>
          t.date.isBiggerOrEqualValue(startDate) &
          t.date.isSmallerOrEqualValue(endDate),
    );
    return query.get();
  }
}

LazyDatabase _openConnection() => LazyDatabase(() async {
  final dbFolder = await getApplicationDocumentsDirectory();
  final file = File(p.join(dbFolder.path, AppDatabase.databaseFileName));
  return NativeDatabase(file);
});
