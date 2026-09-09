// test/exams/marks_repository_test.dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sms/core/database/app_database.dart';
import 'package:sms/features/audit/data/audit_repository.dart';
import 'package:sms/features/exams/data/exams_repository.dart';
import 'package:sms/features/exams/data/grade_scheme_repository.dart';
import 'package:sms/features/exams/data/marks_repository.dart';
import 'package:sms/features/exams/data/results_repository.dart';
import 'package:sms/features/exams/domain/exam_models.dart';

void main() {
  late AppDatabase db;
  late AuditRepository auditRepo;
  late ExamsRepository examsRepo;
  late GradeSchemeRepository gradeSchemeRepo;
  late MarksRepository marksRepo;
  late ResultsRepository resultsRepo;

  const schoolId = 'sch_marks_test';
  const academicYearId = 'ay_2026';
  const classId = 'cls_grade10';
  const sectionId = 'sec_a';
  const subjectId = 'subj_math';
  const userId = 'usr_teacher1';

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    auditRepo = AuditRepository(db);
    examsRepo = ExamsRepository(db, auditRepo);
    gradeSchemeRepo = GradeSchemeRepository(db);
    marksRepo = MarksRepository(db, auditRepo);
    resultsRepo = ResultsRepository(db, auditRepo, gradeSchemeRepo);

    // Seed academic year, class, section, subject, student
    final now = DateTime.now();
    await db
        .into(db.schools)
        .insert(
          SchoolsCompanion.insert(
            id: schoolId,
            name: 'Marks Test School',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await db
        .into(db.academicYears)
        .insert(
          AcademicYearsCompanion.insert(
            id: academicYearId,
            schoolId: schoolId,
            name: '2026-2027',
            startDate: now,
            endDate: now.add(const Duration(days: 365)),
            createdAt: now,
            updatedAt: now,
          ),
        );

    await db
        .into(db.schoolClasses)
        .insert(
          SchoolClassesCompanion.insert(
            id: classId,
            schoolId: schoolId,
            academicYearId: academicYearId,
            name: 'Grade 10',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await db
        .into(db.sections)
        .insert(
          SectionsCompanion.insert(
            id: sectionId,
            classId: classId,
            name: 'Section A',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await db
        .into(db.subjects)
        .insert(
          SubjectsCompanion.insert(
            id: subjectId,
            schoolId: schoolId,
            name: 'Mathematics',
            code: 'MATH101',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await db
        .into(db.students)
        .insert(
          StudentsCompanion.insert(
            id: 'stud1',
            schoolId: schoolId,
            studentCode: 'STD001',
            firstName: 'John',
            lastName: 'Doe',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await db
        .into(db.students)
        .insert(
          StudentsCompanion.insert(
            id: 'stud2',
            schoolId: schoolId,
            studentCode: 'STD002',
            firstName: 'Jane',
            lastName: 'Smith',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await db
        .into(db.enrollments)
        .insert(
          EnrollmentsCompanion.insert(
            id: 'enr1',
            schoolId: schoolId,
            studentId: 'stud1',
            academicYearId: academicYearId,
            classId: classId,
            sectionId: sectionId,
            createdAt: now,
            updatedAt: now,
          ),
        );

    await db
        .into(db.enrollments)
        .insert(
          EnrollmentsCompanion.insert(
            id: 'enr2',
            schoolId: schoolId,
            studentId: 'stud2',
            academicYearId: academicYearId,
            classId: classId,
            sectionId: sectionId,
            createdAt: now,
            updatedAt: now,
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  test('creates exam and configures subject breakdown bounds', () async {
    final exam = await examsRepo.createExam(
      schoolId: schoolId,
      academicYearId: academicYearId,
      name: 'Mid Term Exam 2026',
      startDate: DateTime.now(),
      endDate: DateTime.now().add(const Duration(days: 5)),
      userId: userId,
    );

    final examSubject = await examsRepo.configureExamSubject(
      schoolId: schoolId,
      examId: exam.id,
      classId: classId,
      subjectId: subjectId,
      fullMarks: 100.0,
      passMarks: 40.0,
      theoryMarks: 70.0,
      practicalMarks: 20.0,
      internalMarks: 10.0,
      userId: userId,
    );

    expect(examSubject.fullMarks, equals(100.0));
    expect(examSubject.passMarks, equals(40.0));
    expect(examSubject.theoryMarks, equals(70.0));
    expect(examSubject.practicalMarks, equals(20.0));
    expect(examSubject.internalMarks, equals(10.0));
  });

  test(
    'validates marks against exam subject bounds (rejects exceeding marks)',
    () async {
      final exam = await examsRepo.createExam(
        schoolId: schoolId,
        academicYearId: academicYearId,
        name: 'Mid Term Exam',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 5)),
        userId: userId,
      );

      final examSubject = await examsRepo.configureExamSubject(
        schoolId: schoolId,
        examId: exam.id,
        classId: classId,
        subjectId: subjectId,
        fullMarks: 100.0,
        passMarks: 40.0,
        theoryMarks: 70.0,
        practicalMarks: 20.0,
        internalMarks: 10.0,
        userId: userId,
      );

      // Theory exceeds 70 -> Should throw ArgumentError
      expect(
        () => marksRepo.saveMark(
          schoolId: schoolId,
          examId: exam.id,
          examSubjectId: examSubject.id,
          studentId: 'stud1',
          theoryMarks: 75.0, // Invalid!
          practicalMarks: 15.0,
          internalMarks: 5.0,
          userId: userId,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // Practical exceeds 20 -> Should throw ArgumentError
      expect(
        () => marksRepo.saveMark(
          schoolId: schoolId,
          examId: exam.id,
          examSubjectId: examSubject.id,
          studentId: 'stud1',
          theoryMarks: 50.0,
          practicalMarks: 25.0, // Invalid!
          internalMarks: 5.0,
          userId: userId,
        ),
        throwsA(isA<ArgumentError>()),
      );
    },
  );

  test('saves valid marks, computes totals, grade, and percentage', () async {
    final exam = await examsRepo.createExam(
      schoolId: schoolId,
      academicYearId: academicYearId,
      name: 'Mid Term Exam',
      startDate: DateTime.now(),
      endDate: DateTime.now().add(const Duration(days: 5)),
      userId: userId,
    );

    final examSubject = await examsRepo.configureExamSubject(
      schoolId: schoolId,
      examId: exam.id,
      classId: classId,
      subjectId: subjectId,
      fullMarks: 100.0,
      passMarks: 40.0,
      theoryMarks: 70.0,
      practicalMarks: 20.0,
      internalMarks: 10.0,
      userId: userId,
    );

    final mark = await marksRepo.saveMark(
      schoolId: schoolId,
      examId: exam.id,
      examSubjectId: examSubject.id,
      studentId: 'stud1',
      theoryMarks: 65.0,
      practicalMarks: 18.0,
      internalMarks: 9.0,
      userId: userId,
    );

    expect(mark.totalMarks, equals(92.0));
    expect(mark.percentage, equals(92.0));
    expect(mark.grade, equals('A+'));
    expect(mark.gradePoint, equals(4.0));
    expect(mark.isLocked, isFalse);
  });

  test('records absent student correctly without storing 0 marks', () async {
    final exam = await examsRepo.createExam(
      schoolId: schoolId,
      academicYearId: academicYearId,
      name: 'Mid Term Exam',
      startDate: DateTime.now(),
      endDate: DateTime.now().add(const Duration(days: 5)),
      userId: userId,
    );

    final examSubject = await examsRepo.configureExamSubject(
      schoolId: schoolId,
      examId: exam.id,
      classId: classId,
      subjectId: subjectId,
      fullMarks: 100.0,
      passMarks: 40.0,
      userId: userId,
    );

    final mark = await marksRepo.saveMark(
      schoolId: schoolId,
      examId: exam.id,
      examSubjectId: examSubject.id,
      studentId: 'stud1',
      status: MarkStatus.absent,
      userId: userId,
    );

    expect(mark.status, equals('absent'));
    expect(mark.totalMarks, isNull);
    expect(mark.grade, equals('F'));
  });

  test('batch save updates completion progress correctly', () async {
    final exam = await examsRepo.createExam(
      schoolId: schoolId,
      academicYearId: academicYearId,
      name: 'Mid Term Exam',
      startDate: DateTime.now(),
      endDate: DateTime.now().add(const Duration(days: 5)),
      userId: userId,
    );

    final examSubject = await examsRepo.configureExamSubject(
      schoolId: schoolId,
      examId: exam.id,
      classId: classId,
      subjectId: subjectId,
      fullMarks: 100.0,
      passMarks: 40.0,
      userId: userId,
    );

    var progress = await marksRepo.getMarksProgress(
      examId: exam.id,
      examSubjectId: examSubject.id,
      classId: classId,
      sectionId: sectionId,
    );
    expect(progress.totalStudents, equals(2));
    expect(progress.enteredStudents, equals(0));
    expect(progress.percentage, equals(0.0));

    await marksRepo.saveDraftMarksBatch(
      schoolId: schoolId,
      examId: exam.id,
      examSubjectId: examSubject.id,
      entries: [
        const MarkInputData(studentId: 'stud1', theoryMarks: 70),
        const MarkInputData(studentId: 'stud2', theoryMarks: 80),
      ],
      userId: userId,
    );

    progress = await marksRepo.getMarksProgress(
      examId: exam.id,
      examSubjectId: examSubject.id,
      classId: classId,
      sectionId: sectionId,
    );
    expect(progress.enteredStudents, equals(2));
    expect(progress.percentage, equals(100.0));
  });

  test(
    'publication locks marks, rejects unauthorized edit, but allows admin override with audit trail',
    () async {
      final exam = await examsRepo.createExam(
        schoolId: schoolId,
        academicYearId: academicYearId,
        name: 'Final Term Exam',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 5)),
        userId: userId,
      );

      final examSubject = await examsRepo.configureExamSubject(
        schoolId: schoolId,
        examId: exam.id,
        classId: classId,
        subjectId: subjectId,
        fullMarks: 100.0,
        passMarks: 40.0,
        userId: userId,
      );

      final mark = await marksRepo.saveMark(
        schoolId: schoolId,
        examId: exam.id,
        examSubjectId: examSubject.id,
        studentId: 'stud1',
        theoryMarks: 60.0,
        userId: userId,
      );

      // Publish results for the class
      await resultsRepo.publishResults(
        schoolId: schoolId,
        examId: exam.id,
        classId: classId,
        sectionId: sectionId,
        publishedBy: 'admin1',
      );

      // Verify marks are locked in DB
      final updatedMark =
          await (db.select(db.marks)
            ..where((t) => t.id.equals(mark.id))).getSingle();
      expect(updatedMark.isLocked, isTrue);

      // Standard edit should fail with StateError
      expect(
        () => marksRepo.saveMark(
          schoolId: schoolId,
          examId: exam.id,
          examSubjectId: examSubject.id,
          studentId: 'stud1',
          theoryMarks: 65.0,
          userId: userId,
        ),
        throwsA(isA<StateError>()),
      );

      // Admin override with reason should succeed
      final correctedMark = await marksRepo.correctPublishedMark(
        schoolId: schoolId,
        markId: mark.id,
        newTheoryMarks: 68.0,
        newPracticalMarks: null,
        newInternalMarks: null,
        newStatus: MarkStatus.present,
        reason: 'Recount requested by parent and approved by Headmaster',
        adminUserId: 'admin1',
      );

      expect(correctedMark.totalMarks, equals(68.0));

      // Check MarksAudits table
      final audits = await db.select(db.marksAudits).get();
      expect(audits, isNotEmpty);
      final auditEntry = audits.first;
      expect(auditEntry.oldMarks, equals(60.0));
      expect(auditEntry.newMarks, equals(68.0));
      expect(auditEntry.reason, contains('Recount requested'));
      expect(auditEntry.changedBy, equals('admin1'));
    },
  );
}
