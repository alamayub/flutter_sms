import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sms/data/app_database.dart';
import 'package:sms/data/database_seeder.dart';
import 'package:sms/services/employee_service.dart';

void main() {
  late AppDatabase db;
  late EmployeeService employeeService;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    employeeService = EmployeeService(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('Employee Seeder Tests (Teachers & Staff)', () {
    test('Automatically seeds both teachers and non-teaching staff', () async {
      final allEmployees = await employeeService.getAllEmployees();
      expect(allEmployees, isNotEmpty);
      expect(allEmployees.length, greaterThanOrEqualTo(13));

      final teachers =
          allEmployees
              .where((e) => e.employeeType == EmployeeType.teacher)
              .toList();
      final staff =
          allEmployees
              .where((e) => e.employeeType == EmployeeType.staff)
              .toList();

      expect(teachers.length, greaterThanOrEqualTo(8));
      expect(staff.length, greaterThanOrEqualTo(5));
    });

    test('Seeded records contain realistic designations', () async {
      final allEmployees = await employeeService.getAllEmployees();
      final designations = allEmployees.map((e) => e.designation).toList();

      // Teachers
      expect(designations.contains('Senior Mathematics Teacher'), true);
      expect(designations.contains('English Department Head'), true);
      expect(designations.contains('Science & Technology Teacher'), true);

      // Support Staff (Peon, Accountant, Librarian, Security Guard)
      expect(designations.contains('Senior Accountant'), true);
      expect(designations.contains('Peon / Office Assistant'), true);
      expect(designations.contains('Peon / Bell & Support Staff'), true);
      expect(designations.contains('Librarian'), true);
      expect(designations.contains('Head Security Guard'), true);
    });

    test(
      'Seeded records populate optional personal and professional info',
      () async {
        final allEmployees = await employeeService.getAllEmployees();

        // Check Accountant
        final accountant = allEmployees.firstWhere(
          (e) => e.designation == 'Senior Accountant',
        );
        expect(accountant.employeeType, EmployeeType.staff);
        expect(accountant.department, 'Accounts & Finance');
        expect(accountant.qualification, isNotNull);
        expect(accountant.bloodGroup, 'O+');
        expect(accountant.gender, 'Male');
        expect(accountant.phone, isNotNull);
        expect(accountant.dateOfBirth, isNotNull);
        expect(accountant.address, contains('Kathmandu'));

        // Check Peon
        final peon = allEmployees.firstWhere(
          (e) => e.designation == 'Peon / Office Assistant',
        );
        expect(peon.employeeType, EmployeeType.staff);
        expect(peon.name, 'Maiya Devi Shrestha');
        expect(peon.gender, 'Female');
        expect(peon.bloodGroup, 'B+');
        expect(peon.email, isNull); // Optional email is null
        expect(peon.dateOfBirth, isNotNull);

        // Check Teacher
        final mathTeacher = allEmployees.firstWhere(
          (e) => e.designation == 'Senior Mathematics Teacher',
        );
        expect(mathTeacher.employeeType, EmployeeType.teacher);
        expect(mathTeacher.department, 'Mathematics');
        expect(mathTeacher.qualification, contains('M.Sc.'));
        expect(mathTeacher.dateOfBirth, isNotNull);
        expect(mathTeacher.employeeCode, 'TCH-001');
        expect(mathTeacher.maritalStatus, 'Married');
        expect(mathTeacher.emergencyContactName, isNotNull);
        expect(mathTeacher.emergencyContactPhone, isNotNull);
        expect(mathTeacher.emergencyContactRelation, 'Spouse');
      },
    );

    test(
      'Seeded employees all have employeeCode and emergency contacts',
      () async {
        final allEmployees = await employeeService.getAllEmployees();
        for (final emp in allEmployees) {
          expect(emp.employeeCode, isNotNull);
          expect(emp.employeeCode!.isNotEmpty, true);
          expect(emp.emergencyContactName, isNotNull);
          expect(emp.emergencyContactPhone, isNotNull);
        }
      },
    );

    test('DatabaseSeeder.seedIfEmpty is idempotent for employees', () async {
      final countBefore = (await employeeService.getAllEmployees()).length;
      await DatabaseSeeder.seedIfEmpty(db);
      final countAfter = (await employeeService.getAllEmployees()).length;
      expect(countAfter, equals(countBefore));
    });
  });

  group('Employee Separation by Type Tests', () {
    test('Can query strictly by EmployeeType.teacher', () async {
      final teachers = await employeeService.getAllEmployees(
        type: EmployeeType.teacher,
      );
      expect(teachers, isNotEmpty);
      expect(
        teachers.every((e) => e.employeeType == EmployeeType.teacher),
        true,
      );
    });

    test('Can query strictly by EmployeeType.staff', () async {
      final staff = await employeeService.getAllEmployees(
        type: EmployeeType.staff,
      );
      expect(staff, isNotEmpty);
      expect(staff.every((e) => e.employeeType == EmployeeType.staff), true);
    });

    test(
      'Searching by keyword filters across name, designation, and department',
      () async {
        // Search for accountant
        final accountantResults = await employeeService.getAllEmployees(
          searchQuery: 'accountant',
        );
        expect(accountantResults, isNotEmpty);
        expect(
          accountantResults.any(
            (e) => e.designation.toLowerCase().contains('accountant'),
          ),
          true,
        );

        // Search for peon
        final peonResults = await employeeService.getAllEmployees(
          searchQuery: 'peon',
        );
        expect(peonResults.length, greaterThanOrEqualTo(2));
        expect(
          peonResults.every(
            (e) => e.designation.toLowerCase().contains('peon'),
          ),
          true,
        );
      },
    );
  });

  group('Employee CRUD & Optional Fields Tests', () {
    test('Can create a staff member with full optional details', () async {
      final id = await employeeService.createEmployee(
        name: 'Gopal Bahadur Karki',
        employeeType: EmployeeType.staff,
        designation: 'School Bus Driver',
        department: 'Transportation',
        qualification: 'Heavy Vehicle Driving License',
        phone: '9841987654',
        email: 'driver.gopal@school.edu.np',
        dateOfBirth: DateTime(1983, 6, 20),
        gender: 'Male',
        bloodGroup: 'B+',
        address: 'Bhaktapur-5, Sallaghari',
        basicSalary: 25000.0,
      );

      final emp = await employeeService.getEmployeeById(id);
      expect(emp, isNotNull);
      expect(emp!.name, 'Gopal Bahadur Karki');
      expect(emp.employeeType, EmployeeType.staff);
      expect(emp.designation, 'School Bus Driver');
      expect(emp.department, 'Transportation');
      expect(emp.qualification, 'Heavy Vehicle Driving License');
      expect(emp.phone, '9841987654');
      expect(emp.email, 'driver.gopal@school.edu.np');
      expect(emp.gender, 'Male');
      expect(emp.bloodGroup, 'B+');
      expect(emp.address, 'Bhaktapur-5, Sallaghari');
      expect(emp.basicSalary, 25000.0);
      expect(emp.dateOfBirth, DateTime(1983, 6, 20));
      expect(emp.isActive, true);
    });

    test(
      'Can create an employee with only mandatory fields (optional fields omitted)',
      () async {
        final id = await employeeService.createEmployee(
          name: 'Sunil Thapa',
          employeeType: EmployeeType.staff,
          designation: 'Office Peon',
        );

        final emp = await employeeService.getEmployeeById(id);
        expect(emp, isNotNull);
        expect(emp!.name, 'Sunil Thapa');
        expect(emp.designation, 'Office Peon');
        expect(emp.employeeType, EmployeeType.staff);
        expect(emp.email, isNull);
        expect(emp.phone, isNull);
        expect(emp.dateOfBirth, isNull);
        expect(emp.gender, isNull);
        expect(emp.bloodGroup, isNull);
        expect(emp.address, isNull);
        expect(emp.qualification, isNull);
      },
    );

    test(
      'Can create an employee with code, photo, emergency contacts, and marital status',
      () async {
        final id = await employeeService.createEmployee(
          name: 'Suman Shrestha',
          employeeType: EmployeeType.teacher,
          designation: 'Physics Teacher',
          employeeCode: 'TCH-099',
          photoPath: 'https://example.com/photos/suman.jpg',
          emergencyContactName: 'Rita Shrestha',
          emergencyContactPhone: '9841000111',
          emergencyContactRelation: 'Spouse',
          maritalStatus: 'Married',
          gender: 'Male',
          phone: '9841222333',
          bloodGroup: 'O+',
          department: 'Science',
        );

        final emp = await employeeService.getEmployeeById(id);
        expect(emp, isNotNull);
        expect(emp!.employeeCode, 'TCH-099');
        expect(emp.photoPath, 'https://example.com/photos/suman.jpg');
        expect(emp.emergencyContactName, 'Rita Shrestha');
        expect(emp.emergencyContactPhone, '9841000111');
        expect(emp.emergencyContactRelation, 'Spouse');
        expect(emp.maritalStatus, 'Married');
      },
    );

    test('Can update employeeCode, photo, and emergency contacts', () async {
      final id = await employeeService.createEmployee(
        name: 'Anil Shrestha',
        employeeType: EmployeeType.teacher,
        designation: 'Assistant Science Teacher',
      );

      final updated = await employeeService.updateEmployee(
        id: id,
        name: 'Anil Shrestha',
        employeeType: EmployeeType.teacher,
        designation: 'Head of Science Department',
        employeeCode: 'TCH-088',
        photoPath: 'assets/images/anil.png',
        emergencyContactName: 'Kamala Shrestha',
        emergencyContactPhone: '9841999888',
        emergencyContactRelation: 'Mother',
        maritalStatus: 'Single',
        qualification: 'M.Sc. Chemistry',
        bloodGroup: 'AB+',
        gender: 'Male',
        phone: '9841112233',
        address: 'Lalitpur-2, Sanepa',
      );

      expect(updated, true);

      final emp = await employeeService.getEmployeeById(id);
      expect(emp!.designation, 'Head of Science Department');
      expect(emp.employeeCode, 'TCH-088');
      expect(emp.photoPath, 'assets/images/anil.png');
      expect(emp.emergencyContactName, 'Kamala Shrestha');
      expect(emp.emergencyContactPhone, '9841999888');
      expect(emp.emergencyContactRelation, 'Mother');
      expect(emp.maritalStatus, 'Single');
      expect(emp.qualification, 'M.Sc. Chemistry');
      expect(emp.bloodGroup, 'AB+');
      expect(emp.phone, '9841112233');
      expect(emp.address, 'Lalitpur-2, Sanepa');
    });

    test('Searching by employeeCode returns matching record', () async {
      final results = await employeeService.getAllEmployees(
        searchQuery: 'TCH-001',
      );
      expect(results, isNotEmpty);
      expect(results.first.employeeCode, 'TCH-001');
    });

    test(
      'Searching by emergency contact name returns matching record',
      () async {
        final all = await employeeService.getAllEmployees();
        final firstWithEmergency = all.firstWhere(
          (e) => e.emergencyContactName != null,
        );
        final results = await employeeService.getAllEmployees(
          searchQuery: firstWithEmergency.emergencyContactName!,
        );
        expect(results, isNotEmpty);
        expect(results.any((e) => e.id == firstWithEmergency.id), true);
      },
    );

    test('Can delete an employee', () async {
      final id = await employeeService.createEmployee(
        name: 'Temporary Staff',
        employeeType: EmployeeType.staff,
        designation: 'Night Security Guard',
      );

      expect(await employeeService.getEmployeeById(id), isNotNull);

      final deleted = await employeeService.deleteEmployee(id);
      expect(deleted, 1);
      expect(await employeeService.getEmployeeById(id), isNull);
    });
  });

  group('Employee Code Generation & Local Photo Path Tests', () {
    test(
      'generateNextEmployeeCode generates sequential codes for teacher and staff',
      () async {
        final nextTeacherCode = await employeeService.generateNextEmployeeCode(
          EmployeeType.teacher,
        );
        expect(nextTeacherCode, 'TCH-009');

        final nextStaffCode = await employeeService.generateNextEmployeeCode(
          EmployeeType.staff,
        );
        expect(nextStaffCode, 'STF-006');
      },
    );

    test(
      'createEmployee auto-generates sequential code when employeeCode is not provided',
      () async {
        final teacherId = await employeeService.createEmployee(
          name: 'New Biology Teacher',
          employeeType: EmployeeType.teacher,
          designation: 'Biology Teacher',
        );

        final teacher = await employeeService.getEmployeeById(teacherId);
        expect(teacher, isNotNull);
        expect(teacher!.employeeCode, 'TCH-009');

        // Subsequent creation gets next number
        final nextTeacherCode = await employeeService.generateNextEmployeeCode(
          EmployeeType.teacher,
        );
        expect(nextTeacherCode, 'TCH-010');

        // Staff creation uses STF prefix
        final staffId = await employeeService.createEmployee(
          name: 'New Electrician',
          employeeType: EmployeeType.staff,
          designation: 'Electrician & Maintenance',
        );

        final staff = await employeeService.getEmployeeById(staffId);
        expect(staff, isNotNull);
        expect(staff!.employeeCode, 'STF-006');
      },
    );

    test('Can store and retrieve local file photo path', () async {
      const localPhotoPath =
          '/data/user/0/com.example.sms/app_flutter/employee_photos/emp_12345.jpg';
      final id = await employeeService.createEmployee(
        name: 'Local Photo Employee',
        employeeType: EmployeeType.staff,
        designation: 'Assistant',
        photoPath: localPhotoPath,
      );

      final emp = await employeeService.getEmployeeById(id);
      expect(emp, isNotNull);
      expect(emp!.photoPath, localPhotoPath);
    });
  });

  group('Employee Validation Tests', () {
    test('Validates empty name throws ArgumentError', () async {
      expect(
        () => employeeService.createEmployee(
          name: '   ',
          employeeType: EmployeeType.staff,
          designation: 'Accountant',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Validates empty designation throws ArgumentError', () async {
      expect(
        () => employeeService.createEmployee(
          name: 'Ramesh Adhikari',
          employeeType: EmployeeType.staff,
          designation: '   ',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Validates invalid email format throws ArgumentError', () async {
      expect(
        () => employeeService.createEmployee(
          name: 'Ramesh Adhikari',
          employeeType: EmployeeType.staff,
          designation: 'Accountant',
          email: 'not-a-valid-email',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Validates invalid phone format throws ArgumentError', () async {
      expect(
        () => employeeService.createEmployee(
          name: 'Ramesh Adhikari',
          employeeType: EmployeeType.staff,
          designation: 'Accountant',
          phone: '12345',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test(
      'Validates invalid emergencyContactPhone throws ArgumentError',
      () async {
        expect(
          () => employeeService.createEmployee(
            name: 'Ramesh Adhikari',
            employeeType: EmployeeType.staff,
            designation: 'Accountant',
            emergencyContactPhone: 'not-a-phone',
          ),
          throwsA(isA<ArgumentError>()),
        );
      },
    );

    test('Validates invalid blood group throws ArgumentError', () async {
      expect(
        () => employeeService.createEmployee(
          name: 'Ramesh Adhikari',
          employeeType: EmployeeType.staff,
          designation: 'Accountant',
          bloodGroup: 'Z+', // invalid blood group
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Validates future date of birth throws ArgumentError', () async {
      expect(
        () => employeeService.createEmployee(
          name: 'Ramesh Adhikari',
          employeeType: EmployeeType.staff,
          designation: 'Accountant',
          dateOfBirth: DateTime.now().add(const Duration(days: 365)),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('Reactive Stream Tests', () {
    test('Stream emits updated list when a new employee is added', () async {
      final stream = employeeService.watchEmployees(type: EmployeeType.staff);

      final initial = await stream.first;
      final initialCount = initial.length;

      await employeeService.createEmployee(
        name: 'New Support Staff',
        employeeType: EmployeeType.staff,
        designation: 'Receptionist & Front Desk',
      );

      final updated = await stream.first;
      expect(updated.length, initialCount + 1);
      expect(
        updated.any((e) => e.designation == 'Receptionist & Front Desk'),
        true,
      );
    });
  });
}
