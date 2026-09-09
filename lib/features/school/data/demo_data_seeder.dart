// lib/features/school/data/demo_data_seeder.dart
import 'package:drift/drift.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/database/app_database.dart';
import '../../../core/utils/date_helpers.dart';
import '../../../core/utils/password_hasher.dart';
import '../../../core/utils/uuid_generator.dart';

class DemoDataSeeder {
  final AppDatabase db;

  DemoDataSeeder(this.db);

  /// Seeds a full demo dataset: ABC Secondary School, Academic Year 2026/27,
  /// 5 grades (6A to 10A), 3 teachers, 6 subjects, 150 enrolled students (30 per grade),
  /// timetable schedules, and Grade 8A attendance.
  Future<void> seedDemoData() async {
    final now = DateTime.now();

    await db.transaction(() async {
      // 1. School
      final schoolId = UuidGenerator.v4();
      await db
          .into(db.schools)
          .insert(
            SchoolsCompanion.insert(
              id: schoolId,
              name: 'ABC Secondary School',
              shortName: const Value('ABCSS'),
              address: const Value('Main Road, Ward 4, Pokhara'),
              phone: const Value('+977-61-523456'),
              email: const Value('info@abcschool.edu.np'),
              website: const Value('https://abcschool.edu.np'),
              principalName: const Value('Dr. Ananda Joshi'),
              createdAt: now,
              updatedAt: now,
            ),
          );

      // 2. Admin User
      final adminId = UuidGenerator.v4();
      final adminHash = PasswordHasher.createHash('password123');
      await db
          .into(db.users)
          .insert(
            UsersCompanion.insert(
              id: adminId,
              schoolId: schoolId,
              name: 'School Administrator',
              username: 'admin',
              email: const Value('admin@abcschool.edu.np'),
              passwordHash: adminHash.hash,
              salt: adminHash.salt,
              role: UserRole.admin,
              isActive: const Value(true),
              createdAt: now,
              updatedAt: now,
            ),
          );

      // 3. Academic Year (2026/27)
      final academicYearId = UuidGenerator.v4();
      await db
          .into(db.academicYears)
          .insert(
            AcademicYearsCompanion.insert(
              id: academicYearId,
              schoolId: schoolId,
              name: '2026/27',
              startDate: DateTime(2026, 4, 15),
              endDate: DateTime(2027, 4, 14),
              isCurrent: const Value(true),
              createdAt: now,
              updatedAt: now,
            ),
          );

      // 4. Teachers with user accounts
      final teachersData = [
        {
          'name': 'Ram Sharma',
          'code': 'EMP001',
          'user': 'teacher.ram',
          'phone': '9841234567',
        },
        {
          'name': 'Sita Thapa',
          'code': 'EMP002',
          'user': 'teacher.sita',
          'phone': '9841234568',
        },
        {
          'name': 'Hari Gurung',
          'code': 'EMP003',
          'user': 'teacher.hari',
          'phone': '9841234569',
        },
      ];

      final teacherIds = <String>[];
      for (final t in teachersData) {
        final userId = UuidGenerator.v4();
        final tHash = PasswordHasher.createHash('password123');
        await db
            .into(db.users)
            .insert(
              UsersCompanion.insert(
                id: userId,
                schoolId: schoolId,
                name: t['name']!,
                username: t['user']!,
                email: Value('${t['user']}@abcschool.edu.np'),
                passwordHash: tHash.hash,
                salt: tHash.salt,
                role: UserRole.teacher,
                isActive: const Value(true),
                createdAt: now,
                updatedAt: now,
              ),
            );

        final teacherId = UuidGenerator.v4();
        await db
            .into(db.teachers)
            .insert(
              TeachersCompanion.insert(
                id: teacherId,
                schoolId: schoolId,
                userId: Value(userId),
                employeeCode: t['code']!,
                name: t['name']!,
                phone: Value(t['phone']),
                email: Value('${t['user']}@abcschool.edu.np'),
                joiningDate: Value(DateTime(2022, 1, 15)),
                isActive: const Value(true),
                createdAt: now,
                updatedAt: now,
              ),
            );
        teacherIds.add(teacherId);
      }

      // 5. Subjects
      final subjectsData = [
        {'name': 'Mathematics', 'code': 'MATH101'},
        {'name': 'English', 'code': 'ENG101'},
        {'name': 'Nepali', 'code': 'NEP101'},
        {'name': 'Science', 'code': 'SCI101'},
        {'name': 'Social Studies', 'code': 'SOC101'},
        {'name': 'Computer Science', 'code': 'COMP101'},
      ];

      final subjectIds = <String>[];
      for (final s in subjectsData) {
        final sId = UuidGenerator.v4();
        await db
            .into(db.subjects)
            .insert(
              SubjectsCompanion.insert(
                id: sId,
                schoolId: schoolId,
                name: s['name']!,
                code: s['code']!,
                isActive: const Value(true),
                createdAt: now,
                updatedAt: now,
              ),
            );
        subjectIds.add(sId);
      }

      // 6. Classes (Grade 6 to Grade 10) & Section A
      final firstNames = [
        'Aarav',
        'Bibek',
        'Chirag',
        'Deepak',
        'Elina',
        'Gita',
        'Ishwor',
        'Kabita',
        'Laxman',
        'Manisha',
        'Nabin',
        'Prashant',
        'Rabin',
        'Sagar',
        'Tara',
        'Ujjwal',
        'Bikash',
        'Dikshya',
        'Hemant',
        'Kiran',
        'Milan',
        'Pooja',
        'Rohan',
        'Sarita',
        'Sunil',
        'Bhawana',
        'Dipen',
        'Kripa',
        'Nirajan',
        'Samir',
      ];

      final lastNames = [
        'Adhikari',
        'Bhandari',
        'Chhetri',
        'Dahal',
        'Gautam',
        'Karki',
        'Khadka',
        'Maharjan',
        'Oli',
        'Pandey',
        'Rai',
        'Shrestha',
        'Tamang',
        'Thapa',
        'Acharya',
        'Bhattarai',
        'Basnet',
        'Giri',
        'Joshi',
        'Koirala',
        'Magar',
        'Neupane',
        'Poudel',
        'Rana',
        'Sapkota',
        'Subedi',
        'Tiwari',
        'Bhatia',
        'Regmi',
        'Upadhyaya',
      ];

      String? grade8SectionAId;
      String? grade8ClassId;
      final grade8StudentIds = <String>[];

      for (int gradeIndex = 0; gradeIndex < 5; gradeIndex++) {
        final gradeNumber = 6 + gradeIndex;
        final classId = UuidGenerator.v4();
        await db
            .into(db.schoolClasses)
            .insert(
              SchoolClassesCompanion.insert(
                id: classId,
                schoolId: schoolId,
                academicYearId: academicYearId,
                name: 'Grade $gradeNumber',
                displayOrder: Value(gradeNumber),
                createdAt: now,
                updatedAt: now,
              ),
            );

        // Assign subjects to class
        for (int i = 0; i < subjectIds.length; i++) {
          final teacherId = teacherIds[i % teacherIds.length];
          await db
              .into(db.classSubjects)
              .insert(
                ClassSubjectsCompanion.insert(
                  id: UuidGenerator.v4(),
                  classId: classId,
                  subjectId: subjectIds[i],
                  teacherId: Value(teacherId),
                  createdAt: now,
                  updatedAt: now,
                ),
              );
        }

        // Section A
        final sectionId = UuidGenerator.v4();
        final classTeacherId = teacherIds[gradeIndex % teacherIds.length];
        await db
            .into(db.sections)
            .insert(
              SectionsCompanion.insert(
                id: sectionId,
                classId: classId,
                name: 'Section A',
                capacity: const Value(40),
                classTeacherId: Value(classTeacherId),
                createdAt: now,
                updatedAt: now,
              ),
            );

        if (gradeNumber == 8) {
          grade8ClassId = classId;
          grade8SectionAId = sectionId;
        }

        // 30 Students per class
        for (int i = 0; i < 30; i++) {
          final studentId = UuidGenerator.v4();
          final rollNumber = i + 1;
          final code =
              'STU${gradeNumber.toString().padLeft(2, '0')}${rollNumber.toString().padLeft(2, '0')}';
          final firstName = firstNames[i % firstNames.length];
          final lastName = lastNames[i % lastNames.length];
          final gender = i % 2 == 0 ? 'Male' : 'Female';

          await db
              .into(db.students)
              .insert(
                StudentsCompanion.insert(
                  id: studentId,
                  schoolId: schoolId,
                  studentCode: code,
                  firstName: firstName,
                  lastName: lastName,
                  gender: Value(gender),
                  dateOfBirth: Value(
                    DateTime(2012 - (gradeNumber - 6), 5, rollNumber),
                  ),
                  phone: Value('+977-98000000$rollNumber'),
                  guardianName: Value('$lastName Guardian'),
                  guardianPhone: Value('+977-98100000$rollNumber'),
                  admissionDate: Value(DateTime(2026, 4, 15)),
                  isActive: const Value(true),
                  createdAt: now,
                  updatedAt: now,
                ),
              );

          await db
              .into(db.enrollments)
              .insert(
                EnrollmentsCompanion.insert(
                  id: UuidGenerator.v4(),
                  schoolId: schoolId,
                  studentId: studentId,
                  academicYearId: academicYearId,
                  classId: classId,
                  sectionId: sectionId,
                  rollNumber: Value(rollNumber),
                  isActive: const Value(true),
                  createdAt: now,
                  updatedAt: now,
                ),
              );

          if (gradeNumber == 8) {
            grade8StudentIds.add(studentId);
          }
        }
      }

      // 7. Timetable for Grade 8A
      if (grade8ClassId != null && grade8SectionAId != null) {
        final periods = [
          {
            'period': 1,
            'start': '09:00',
            'end': '09:45',
            'subIdx': 0,
            'teaIdx': 0,
            'room': 'Room 101',
          },
          {
            'period': 2,
            'start': '09:45',
            'end': '10:30',
            'subIdx': 1,
            'teaIdx': 1,
            'room': 'Room 101',
          },
          {
            'period': 3,
            'start': '10:45',
            'end': '11:30',
            'subIdx': 3,
            'teaIdx': 2,
            'room': 'Lab 1',
          },
          {
            'period': 4,
            'start': '11:30',
            'end': '12:15',
            'subIdx': 5,
            'teaIdx': 0,
            'room': 'Comp Lab',
          },
        ];

        for (int day = 1; day <= 5; day++) {
          for (final p in periods) {
            await db
                .into(db.timetables)
                .insert(
                  TimetablesCompanion.insert(
                    id: UuidGenerator.v4(),
                    schoolId: schoolId,
                    academicYearId: academicYearId,
                    classId: grade8ClassId,
                    sectionId: grade8SectionAId,
                    dayOfWeek: day,
                    period: p['period'] as int,
                    subjectId: subjectIds[p['subIdx'] as int],
                    teacherId: Value(teacherIds[p['teaIdx'] as int]),
                    startTime: p['start'] as String,
                    endTime: p['end'] as String,
                    room: Value(p['room'] as String),
                    createdAt: now,
                    updatedAt: now,
                  ),
                );
          }
        }

        // 8. Today's Attendance for Grade 8A (30 students: 26 present, 2 absent, 1 late, 1 excused)
        final today = DateHelpers.todayIsoDate();
        for (int i = 0; i < grade8StudentIds.length; i++) {
          String status = AttendanceStatus.present;
          if (i == 27) {
            status = AttendanceStatus.absent;
          } else if (i == 28) {
            status = AttendanceStatus.absent;
          } else if (i == 29) {
            status = AttendanceStatus.late;
          } else if (i == 26) {
            status = AttendanceStatus.excused;
          }

          await db
              .into(db.attendance)
              .insert(
                AttendanceCompanion.insert(
                  id: UuidGenerator.v4(),
                  schoolId: schoolId,
                  academicYearId: academicYearId,
                  date: today,
                  studentId: grade8StudentIds[i],
                  classId: grade8ClassId,
                  sectionId: grade8SectionAId,
                  status: status,
                  markedBy: adminId,
                  createdAt: now,
                  updatedAt: now,
                ),
              );
        }
      }

      // 9. Audit Log
      await db
          .into(db.auditLogs)
          .insert(
            AuditLogsCompanion.insert(
              id: UuidGenerator.v4(),
              schoolId: Value(schoolId),
              userId: Value(adminId),
              action: AuditAction.demoDataSeeded,
              entityType: 'System',
              metadata: const Value(
                '{"school":"ABC Secondary School","students":150,"classes":5}',
              ),
              createdAt: now,
            ),
          );
    });
  }
}
