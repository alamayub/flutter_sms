// lib/core/database/app_database.dart
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'tables/tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Schools,
    Users,
    AcademicYears,
    SchoolClasses,
    Sections,
    Subjects,
    ClassSubjects,
    Teachers,
    Students,
    Enrollments,
    Timetables,
    Attendance,
    AuditLogs,
    AppSettings,
    SyncDevices,
    SyncEvents,
    SyncCursors,
    SyncConflicts,
    Exams,
    ExamSubjects,
    AssessmentComponents,
    Marks,
    MarksAudits,
    GradeSchemes,
    GradeSchemeRules,
    Results,
    ResultPublications,
    FeeCategories,
    FeeStructures,
    FeeDiscounts,
    StudentFeeAssignments,
    StudentFees,
    FeePayments,
    FeePaymentItems,
    StudentAdvances,
    SchoolExpenses,
    SchoolIncomes,
    DailyClosings,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? _openConnection());

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 2) {
        // v1 -> v2: Add soft-delete and archive tracking columns
        await m.addColumn(academicYears, academicYears.archivedAt);
        await m.addColumn(schoolClasses, schoolClasses.archivedAt);
        await m.addColumn(sections, sections.archivedAt);
        await m.addColumn(subjects, subjects.isArchived);
        await m.addColumn(subjects, subjects.archivedAt);
        await m.addColumn(teachers, teachers.isArchived);
        await m.addColumn(teachers, teachers.archivedAt);
        await m.addColumn(students, students.isArchived);
        await m.addColumn(students, students.archivedAt);
        await m.addColumn(enrollments, enrollments.isArchived);
        await m.addColumn(enrollments, enrollments.archivedAt);
      }
      if (from < 3) {
        // v2 -> v3: Add LAN synchronization tables
        await m.createTable(syncDevices);
        await m.createTable(syncEvents);
        await m.createTable(syncCursors);
        await m.createTable(syncConflicts);
      }
      if (from < 4) {
        // v3 -> v4: Add Examination, Marks, Grading, and Results tables
        await m.createTable(exams);
        await m.createTable(examSubjects);
        await m.createTable(assessmentComponents);
        await m.createTable(marks);
        await m.createTable(marksAudits);
        await m.createTable(gradeSchemes);
        await m.createTable(gradeSchemeRules);
        await m.createTable(results);
        await m.createTable(resultPublications);
      }
      if (from < 5) {
        // v4 -> v5: Add Finance & Fee Management tables and School currency columns
        await m.addColumn(schools, schools.currencyCode);
        await m.addColumn(schools, schools.currencyName);
        await m.addColumn(schools, schools.currencySymbol);
        await m.addColumn(schools, schools.currencyDecimals);
        await m.createTable(feeCategories);
        await m.createTable(feeStructures);
        await m.createTable(feeDiscounts);
        await m.createTable(studentFeeAssignments);
        await m.createTable(studentFees);
        await m.createTable(feePayments);
        await m.createTable(feePaymentItems);
        await m.createTable(studentAdvances);
        await m.createTable(schoolExpenses);
        await m.createTable(schoolIncomes);
        await m.createTable(dailyClosings);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON;');
      await customStatement('PRAGMA journal_mode = WAL;');
      await customStatement('PRAGMA busy_timeout = 5000;');
    },
  );

  static QueryExecutor _openConnection() {
    return LazyDatabase(() async {
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(p.join(dbFolder.path, 'sms_local_db.sqlite'));
      return NativeDatabase.createInBackground(file);
    });
  }
}
