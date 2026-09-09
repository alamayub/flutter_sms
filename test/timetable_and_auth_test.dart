// test/timetable_and_auth_test.dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sms/core/constants/app_constants.dart';
import 'package:sms/core/database/app_database.dart';
import 'package:sms/core/errors/app_exceptions.dart';
import 'package:sms/core/utils/password_hasher.dart';
import 'package:sms/features/academic_year/data/academic_year_repository.dart';
import 'package:sms/features/audit/data/audit_repository.dart';
import 'package:sms/features/auth/data/auth_repository.dart';
import 'package:sms/features/classes/data/classes_repository.dart';
import 'package:sms/features/school/data/school_repository.dart';
import 'package:sms/features/subjects/data/subjects_repository.dart';
import 'package:sms/features/teachers/data/teachers_repository.dart';
import 'package:sms/features/timetable/data/timetable_repository.dart';

void main() {
  late AppDatabase db;
  late AuditRepository auditRepo;
  late SchoolRepository schoolRepo;
  late AuthRepository authRepo;
  late AcademicYearRepository academicRepo;
  late ClassesRepository classesRepo;
  late SubjectsRepository subjectsRepo;
  late TeachersRepository teachersRepo;
  late TimetableRepository timetableRepo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    auditRepo = AuditRepository(db);
    schoolRepo = SchoolRepository(db, auditRepo);
    authRepo = AuthRepository(db, auditRepo);
    academicRepo = AcademicYearRepository(db, auditRepo);
    classesRepo = ClassesRepository(db, auditRepo);
    subjectsRepo = SubjectsRepository(db, auditRepo);
    teachersRepo = TeachersRepository(db, auditRepo, authRepo);
    timetableRepo = TimetableRepository(db, auditRepo);
  });

  tearDown(() async {
    await db.close();
  });

  group('Authentication & Password Hashing', () {
    test('Password hashing produces unique salts and verifies correctly', () {
      final hash1 = PasswordHasher.createHash('secret123');
      final hash2 = PasswordHasher.createHash('secret123');

      // Salts must differ
      expect(hash1.salt != hash2.salt, isTrue);
      // Hashes must differ because salts differ
      expect(hash1.hash != hash2.hash, isTrue);

      // Verify correct password
      expect(
        PasswordHasher.verifyPassword(
          candidatePassword: 'secret123',
          storedHash: hash1.hash,
          storedSalt: hash1.salt,
        ),
        isTrue,
      );

      // Verify incorrect password
      expect(
        PasswordHasher.verifyPassword(
          candidatePassword: 'wrongpassword',
          storedHash: hash1.hash,
          storedSalt: hash1.salt,
        ),
        isFalse,
      );
    });

    test(
      'Local login validates credentials and rejects wrong passwords',
      () async {
        final school = await schoolRepo.createSchool(name: 'Auth Test School');
        await authRepo.createAdministrator(
          schoolId: school.id,
          name: 'Headmaster',
          username: 'principal',
          password: 'securePass123',
          role: UserRole.principal,
        );

        // Valid login
        final user = await authRepo.login(
          usernameOrEmail: 'principal',
          password: 'securePass123',
        );
        expect(user.username, 'principal');
        expect(user.role, UserRole.principal);

        // Invalid password
        expect(
          () => authRepo.login(
            usernameOrEmail: 'principal',
            password: 'wrongPassword',
          ),
          throwsA(isA<AuthException>()),
        );

        // Non-existent user
        expect(
          () => authRepo.login(
            usernameOrEmail: 'unknown_user',
            password: 'password',
          ),
          throwsA(isA<AuthException>()),
        );
      },
    );
  });

  group('Timetable Conflict Detection', () {
    test('Detects teacher schedule conflict across different classes', () async {
      final school = await schoolRepo.createSchool(name: 'Timetable School');
      final year = await academicRepo.createAcademicYear(
        schoolId: school.id,
        name: '2026/27',
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 12, 31),
        isCurrent: true,
      );

      final class8 = await classesRepo.createClass(
        schoolId: school.id,
        academicYearId: year.id,
        name: 'Grade 8',
      );
      final sec8A = await classesRepo.createSection(
        classId: class8.id,
        name: 'Section A',
      );

      final class9 = await classesRepo.createClass(
        schoolId: school.id,
        academicYearId: year.id,
        name: 'Grade 9',
      );
      final sec9A = await classesRepo.createSection(
        classId: class9.id,
        name: 'Section A',
      );

      final math = await subjectsRepo.createSubject(
        schoolId: school.id,
        name: 'Mathematics',
        code: 'MATH01',
      );
      final science = await subjectsRepo.createSubject(
        schoolId: school.id,
        name: 'Science',
        code: 'SCI01',
      );

      final teacherRam = await teachersRepo.createTeacher(
        schoolId: school.id,
        employeeCode: 'TEA01',
        name: 'Ram Sharma',
      );

      // 1. Assign Teacher Ram to Grade 8A Monday 09:00 - 09:45
      await timetableRepo.createEntry(
        schoolId: school.id,
        academicYearId: year.id,
        classId: class8.id,
        sectionId: sec8A.id,
        dayOfWeek: 1, // Monday
        period: 1,
        subjectId: math.id,
        teacherId: teacherRam.id,
        startTime: '09:00',
        endTime: '09:45',
        room: 'Room 101',
      );

      // 2. Try to assign Teacher Ram to Grade 9A Monday 09:15 - 10:00 (Overlapping!)
      expect(
        () => timetableRepo.createEntry(
          schoolId: school.id,
          academicYearId: year.id,
          classId: class9.id,
          sectionId: sec9A.id,
          dayOfWeek: 1, // Monday
          period: 1,
          subjectId: science.id,
          teacherId: teacherRam.id,
          startTime: '09:15',
          endTime: '10:00',
          room: 'Room 102',
        ),
        throwsA(isA<ConflictException>()),
      );
    });

    test(
      'Detects room conflict when two classes attempt to book same room',
      () async {
        final school = await schoolRepo.createSchool(
          name: 'Room Conflict School',
        );
        final year = await academicRepo.createAcademicYear(
          schoolId: school.id,
          name: '2026/27',
          startDate: DateTime(2026, 1, 1),
          endDate: DateTime(2026, 12, 31),
          isCurrent: true,
        );
        final class8 = await classesRepo.createClass(
          schoolId: school.id,
          academicYearId: year.id,
          name: 'Grade 8',
        );
        final sec8A = await classesRepo.createSection(
          classId: class8.id,
          name: 'Section A',
        );
        final class9 = await classesRepo.createClass(
          schoolId: school.id,
          academicYearId: year.id,
          name: 'Grade 9',
        );
        final sec9A = await classesRepo.createSection(
          classId: class9.id,
          name: 'Section A',
        );

        final math = await subjectsRepo.createSubject(
          schoolId: school.id,
          name: 'Mathematics',
          code: 'M01',
        );
        final science = await subjectsRepo.createSubject(
          schoolId: school.id,
          name: 'Science',
          code: 'S01',
        );

        final teacher1 = await teachersRepo.createTeacher(
          schoolId: school.id,
          employeeCode: 'T1',
          name: 'Teacher One',
        );
        final teacher2 = await teachersRepo.createTeacher(
          schoolId: school.id,
          employeeCode: 'T2',
          name: 'Teacher Two',
        );

        // Book Science Lab for Grade 8A Monday 10:00 - 11:00
        await timetableRepo.createEntry(
          schoolId: school.id,
          academicYearId: year.id,
          classId: class8.id,
          sectionId: sec8A.id,
          dayOfWeek: 1,
          period: 2,
          subjectId: science.id,
          teacherId: teacher1.id,
          startTime: '10:00',
          endTime: '11:00',
          room: 'Science Lab',
        );

        // Grade 9A tries to book Science Lab during same time with Teacher 2
        expect(
          () => timetableRepo.createEntry(
            schoolId: school.id,
            academicYearId: year.id,
            classId: class9.id,
            sectionId: sec9A.id,
            dayOfWeek: 1,
            period: 2,
            subjectId: math.id,
            teacherId: teacher2.id,
            startTime: '10:30',
            endTime: '11:30',
            room: 'Science Lab',
          ),
          throwsA(isA<ConflictException>()),
        );
      },
    );
  });
}
