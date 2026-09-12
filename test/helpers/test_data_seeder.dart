import 'package:drift/drift.dart';
import 'package:sms/config/enums.dart';
import 'package:sms/data/app_database.dart';
import 'package:sms/utils/exam_grading_utils.dart';

class TestDataSeeder {
  /// Seeds employees (faculty teachers and non-teaching support staff)
  static Future<void> seedEmployees(AppDatabase db) async {
    final employeesList = [
      // ====== TEACHING FACULTY ======
      EmployeesCompanion(
        employeeCode: const Value('TCH-001'),
        name: const Value('Ram Sharma'),
        employeeType: const Value(EmployeeType.teacher),
        designation: const Value('Senior Mathematics Teacher'),
        department: const Value('Mathematics'),
        qualification: const Value('M.Sc. Mathematics, B.Ed'),
        gender: const Value('Male'),
        bloodGroup: const Value('O+'),
        maritalStatus: const Value('Married'),
        phone: const Value('9841234567'),
        email: const Value('ram.sharma@school.edu.np'),
        address: const Value('Kathmandu-10, New Baneshwor'),
        emergencyContactName: const Value('Gauri Sharma'),
        emergencyContactPhone: const Value('9851011223'),
        emergencyContactRelation: const Value('Spouse'),
        dateOfBirth: Value(DateTime(1985, 3, 15)),
        joiningDate: Value(DateTime(2018, 4, 1)),
        basicSalary: const Value(35000.0),
      ),
      EmployeesCompanion(
        employeeCode: const Value('TCH-002'),
        name: const Value('Sita Thapa'),
        employeeType: const Value(EmployeeType.teacher),
        designation: const Value('English Department Head'),
        department: const Value('Languages'),
        qualification: const Value('M.A. English'),
        gender: const Value('Female'),
        bloodGroup: const Value('A+'),
        maritalStatus: const Value('Married'),
        phone: const Value('9842345678'),
        email: const Value('sita.thapa@school.edu.np'),
        address: const Value('Lalitpur-3, Pulchowk'),
        emergencyContactName: const Value('Birendra Thapa'),
        emergencyContactPhone: const Value('9851022334'),
        emergencyContactRelation: const Value('Father'),
        dateOfBirth: Value(DateTime(1988, 7, 22)),
        joiningDate: Value(DateTime(2019, 4, 1)),
        basicSalary: const Value(32000.0),
      ),
      EmployeesCompanion(
        employeeCode: const Value('TCH-003'),
        name: const Value('Hari Prasad Shrestha'),
        employeeType: const Value(EmployeeType.teacher),
        designation: const Value('Science & Technology Teacher'),
        department: const Value('Science'),
        qualification: const Value('M.Sc. Physics'),
        gender: const Value('Male'),
        bloodGroup: const Value('B+'),
        maritalStatus: const Value('Married'),
        phone: const Value('9843456789'),
        email: const Value('hari.shrestha@school.edu.np'),
        address: const Value('Bhaktapur-2, Suryabinayak'),
        emergencyContactName: const Value('Maya Shrestha'),
        emergencyContactPhone: const Value('9851033445'),
        emergencyContactRelation: const Value('Spouse'),
        dateOfBirth: Value(DateTime(1990, 11, 5)),
        joiningDate: Value(DateTime(2020, 5, 15)),
        basicSalary: const Value(30000.0),
      ),
      EmployeesCompanion(
        employeeCode: const Value('TCH-004'),
        name: const Value('Gita Adhikari'),
        employeeType: const Value(EmployeeType.teacher),
        designation: const Value('Nepali Language Specialist'),
        department: const Value('Languages'),
        qualification: const Value('M.A. Nepali, B.Ed'),
        gender: const Value('Female'),
        bloodGroup: const Value('AB+'),
        maritalStatus: const Value('Single'),
        phone: const Value('9844567890'),
        email: const Value('gita.adhikari@school.edu.np'),
        address: const Value('Kathmandu-4, Baluwatar'),
        emergencyContactName: const Value('Rajan Adhikari'),
        emergencyContactPhone: const Value('9851044556'),
        emergencyContactRelation: const Value('Brother'),
        dateOfBirth: Value(DateTime(1991, 2, 18)),
        joiningDate: Value(DateTime(2021, 4, 1)),
        basicSalary: const Value(28000.0),
      ),
      EmployeesCompanion(
        employeeCode: const Value('TCH-005'),
        name: const Value('Bikash KC'),
        employeeType: const Value(EmployeeType.teacher),
        designation: const Value('Social Studies & Civics Teacher'),
        department: const Value('Social Sciences'),
        qualification: const Value('B.A., B.Ed'),
        gender: const Value('Male'),
        bloodGroup: const Value('O-'),
        maritalStatus: const Value('Married'),
        phone: const Value('9845678901'),
        email: const Value('bikash.kc@school.edu.np'),
        address: const Value('Kathmandu-7, Chabahil'),
        emergencyContactName: const Value('Deepa KC'),
        emergencyContactPhone: const Value('9851055667'),
        emergencyContactRelation: const Value('Spouse'),
        dateOfBirth: Value(DateTime(1989, 9, 30)),
        joiningDate: Value(DateTime(2021, 8, 1)),
        basicSalary: const Value(27000.0),
      ),
      EmployeesCompanion(
        employeeCode: const Value('TCH-006'),
        name: const Value('Anita Tamang'),
        employeeType: const Value(EmployeeType.teacher),
        designation: const Value('Computer Science & IT Coordinator'),
        department: const Value('Computer Science'),
        qualification: const Value('B.Sc. CSIT'),
        gender: const Value('Female'),
        bloodGroup: const Value('A-'),
        maritalStatus: const Value('Single'),
        phone: const Value('9846789012'),
        email: const Value('anita.tamang@school.edu.np'),
        address: const Value('Lalitpur-5, Jawalakhel'),
        emergencyContactName: const Value('Pasang Tamang'),
        emergencyContactPhone: const Value('9851066778'),
        emergencyContactRelation: const Value('Father'),
        dateOfBirth: Value(DateTime(1993, 6, 12)),
        joiningDate: Value(DateTime(2022, 1, 15)),
        basicSalary: const Value(29000.0),
      ),
      EmployeesCompanion(
        employeeCode: const Value('TCH-007'),
        name: const Value('Ramesh Joshi'),
        employeeType: const Value(EmployeeType.teacher),
        designation: const Value('Health, PE & Sports Instructor'),
        department: const Value('Sports & Health'),
        qualification: const Value('B.P.Ed'),
        gender: const Value('Male'),
        bloodGroup: const Value('B-'),
        maritalStatus: const Value('Married'),
        phone: const Value('9847890123'),
        email: const Value('ramesh.joshi@school.edu.np'),
        address: const Value('Kathmandu-14, Kuleshwor'),
        emergencyContactName: const Value('Sarita Joshi'),
        emergencyContactPhone: const Value('9851077889'),
        emergencyContactRelation: const Value('Spouse'),
        dateOfBirth: Value(DateTime(1992, 4, 8)),
        joiningDate: Value(DateTime(2022, 4, 1)),
        basicSalary: const Value(26000.0),
      ),
      EmployeesCompanion(
        employeeCode: const Value('TCH-008'),
        name: const Value('Sunita Rai'),
        employeeType: const Value(EmployeeType.teacher),
        designation: const Value('Art, Craft & Music Teacher'),
        department: const Value('Arts & Crafts'),
        qualification: const Value('B.F.A. Fine Arts'),
        gender: const Value('Female'),
        bloodGroup: const Value('AB-'),
        maritalStatus: const Value('Single'),
        phone: const Value('9848901234'),
        email: const Value('sunita.rai@school.edu.np'),
        address: const Value('Bhaktapur-1, Thimi'),
        emergencyContactName: const Value('Prem Rai'),
        emergencyContactPhone: const Value('9851088990'),
        emergencyContactRelation: const Value('Brother'),
        dateOfBirth: Value(DateTime(1994, 12, 25)),
        joiningDate: Value(DateTime(2023, 2, 1)),
        basicSalary: const Value(25000.0),
      ),

      // ====== NON-TEACHING SUPPORT STAFF ======
      EmployeesCompanion(
        employeeCode: const Value('STF-001'),
        name: const Value('Ram Bahadur Tamang'),
        employeeType: const Value(EmployeeType.staff),
        designation: const Value('Senior Accountant'),
        department: const Value('Accounts & Finance'),
        qualification: const Value('M.B.S / B.B.S'),
        gender: const Value('Male'),
        bloodGroup: const Value('O+'),
        maritalStatus: const Value('Married'),
        phone: const Value('9849012345'),
        email: const Value('accountant@school.edu.np'),
        address: const Value('Kathmandu-31, Shantinagar'),
        emergencyContactName: const Value('Laxmi Tamang'),
        emergencyContactPhone: const Value('9851099001'),
        emergencyContactRelation: const Value('Spouse'),
        dateOfBirth: Value(DateTime(1986, 5, 20)),
        joiningDate: Value(DateTime(2017, 3, 15)),
        basicSalary: const Value(30000.0),
      ),
      EmployeesCompanion(
        employeeCode: const Value('STF-002'),
        name: const Value('Maiya Devi Shrestha'),
        employeeType: const Value(EmployeeType.staff),
        designation: const Value('Peon / Office Assistant'),
        department: const Value('Administration'),
        qualification: const Value('Under SLC'),
        gender: const Value('Female'),
        bloodGroup: const Value('B+'),
        maritalStatus: const Value('Married'),
        phone: const Value('9840123456'),
        email: const Value(null),
        address: const Value('Lalitpur-12, Lagankhel'),
        emergencyContactName: const Value('Sundar Shrestha'),
        emergencyContactPhone: const Value('9851100112'),
        emergencyContactRelation: const Value('Spouse'),
        dateOfBirth: Value(DateTime(1984, 8, 14)),
        joiningDate: Value(DateTime(2015, 6, 1)),
        basicSalary: const Value(18000.0),
      ),
      EmployeesCompanion(
        employeeCode: const Value('STF-003'),
        name: const Value('Krishna Gopal Maharjan'),
        employeeType: const Value(EmployeeType.staff),
        designation: const Value('Peon / Bell & Support Staff'),
        department: const Value('Maintenance'),
        qualification: const Value('Basic Literacy'),
        gender: const Value('Male'),
        bloodGroup: const Value('A+'),
        maritalStatus: const Value('Married'),
        phone: const Value('9841122334'),
        email: const Value(null),
        address: const Value('Kathmandu-16, Balaju'),
        emergencyContactName: const Value('Radha Maharjan'),
        emergencyContactPhone: const Value('9851111223'),
        emergencyContactRelation: const Value('Spouse'),
        dateOfBirth: Value(DateTime(1982, 1, 10)),
        joiningDate: Value(DateTime(2016, 1, 1)),
        basicSalary: const Value(18000.0),
      ),
      EmployeesCompanion(
        employeeCode: const Value('STF-004'),
        name: const Value('Sarita Basnet'),
        employeeType: const Value(EmployeeType.staff),
        designation: const Value('Librarian'),
        department: const Value('Library'),
        qualification: const Value('B.Lib.Sc'),
        gender: const Value('Female'),
        bloodGroup: const Value('O+'),
        maritalStatus: const Value('Single'),
        phone: const Value('9842233445'),
        email: const Value('library@school.edu.np'),
        address: const Value('Kathmandu-3, Maharajgunj'),
        emergencyContactName: const Value('Kamal Basnet'),
        emergencyContactPhone: const Value('9851122334'),
        emergencyContactRelation: const Value('Brother'),
        dateOfBirth: Value(DateTime(1992, 10, 3)),
        joiningDate: Value(DateTime(2021, 9, 1)),
        basicSalary: const Value(22000.0),
      ),
      EmployeesCompanion(
        employeeCode: const Value('STF-005'),
        name: const Value('Dhan Bahadur Rai'),
        employeeType: const Value(EmployeeType.staff),
        designation: const Value('Head Security Guard'),
        department: const Value('Security'),
        qualification: const Value('Ex-Military'),
        gender: const Value('Male'),
        bloodGroup: const Value('B+'),
        maritalStatus: const Value('Married'),
        phone: const Value('9843344556'),
        email: const Value(null),
        address: const Value('Kathmandu-26, Samakhusi'),
        emergencyContactName: const Value('Bhim Bahadur Rai'),
        emergencyContactPhone: const Value('9851133445'),
        emergencyContactRelation: const Value('Brother'),
        dateOfBirth: Value(DateTime(1980, 7, 19)),
        joiningDate: Value(DateTime(2018, 11, 1)),
        basicSalary: const Value(20000.0),
      ),
    ];

    for (final emp in employeesList) {
      await db.insertEmployee(emp);
    }
  }

  /// Backward-compatible alias for seedEmployees
  static Future<void> seedTeachers(AppDatabase db) => seedEmployees(db);

  /// Seeds a sample weekly timetable for Class 10 (Section A) and Class 1 (Section A)
  static Future<void> seedTimetable(AppDatabase db) async {
    final years = await db.getAllAcademicYears();
    if (years.isEmpty) return;
    final activeYear = years.firstWhere(
      (y) => y.isCurrent,
      orElse: () => years.first,
    );

    final classes = await db.getAllClassesWithSections();
    if (classes.isEmpty) return;

    final subjects = await db.getAllSubjects();
    if (subjects.isEmpty) return;

    final teachers = await db.getAllTeachers();
    if (teachers.isEmpty) return;

    // Helper to find subject by name keyword
    Subject? findSub(String keyword) {
      return subjects.firstWhere(
        (s) => s.name.toLowerCase().contains(keyword.toLowerCase()),
        orElse: () => subjects.first,
      );
    }

    // Helper to find teacher by name keyword
    Employee? findTea(String keyword) {
      return teachers.firstWhere(
        (t) => t.name.toLowerCase().contains(keyword.toLowerCase()),
        orElse: () => teachers.first,
      );
    }

    final eng = findSub('English');
    final nep = findSub('Nepali');
    final mth = findSub('Mathematics');
    final sci = findSub('Science');
    final soc = findSub('Social');
    final cmp = findSub('Computer');
    final hpe = findSub('Health');

    final sita = findTea('Sita');
    final gita = findTea('Gita');
    final ram = findTea('Ram');
    final hari = findTea('Hari');
    final bikash = findTea('Bikash');
    final anita = findTea('Anita');
    final ramesh = findTea('Ramesh');

    // Target Class 10 (Section A) and Class 1 (Section A)
    final targetClasses = classes.where(
      (c) => c.name == 'Class 10' || c.name == 'Class 1',
    );

    for (final cls in targetClasses) {
      final section = cls.sections.isNotEmpty ? cls.sections.first : null;
      final room = cls.name == 'Class 10' ? 'Room 10' : 'Room 1';

      // School days: Sunday to Friday
      const schoolDays = [
        'sunday',
        'monday',
        'tuesday',
        'wednesday',
        'thursday',
        'friday',
      ];
      for (final day in schoolDays) {
        // Morning Assembly (09:45 - 10:00)
        await db.insertPeriod(
          PeriodEntriesCompanion(
            academicYearId: Value(activeYear.id),
            classId: Value(cls.id),
            sectionId: Value(section?.id),
            dayOfWeek: Value(day),
            periodNumber: const Value(0),
            startTime: const Value('09:45'),
            endTime: const Value('10:00'),
            isBreak: const Value(true),
            breakTitle: const Value('Morning Assembly & Prayer'),
            roomNumber: const Value('Assembly Ground'),
          ),
        );

        // Period 1: English (10:00 - 10:45)
        await db.insertPeriod(
          PeriodEntriesCompanion(
            academicYearId: Value(activeYear.id),
            classId: Value(cls.id),
            sectionId: Value(section?.id),
            dayOfWeek: Value(day),
            periodNumber: const Value(1),
            startTime: const Value('10:00'),
            endTime: const Value('10:45'),
            isBreak: const Value(false),
            subjectId: Value(eng?.id),
            teacherId: Value(sita?.id),
            roomNumber: Value(room),
          ),
        );

        // Period 2: Mathematics (10:45 - 11:30)
        await db.insertPeriod(
          PeriodEntriesCompanion(
            academicYearId: Value(activeYear.id),
            classId: Value(cls.id),
            sectionId: Value(section?.id),
            dayOfWeek: Value(day),
            periodNumber: const Value(2),
            startTime: const Value('10:45'),
            endTime: const Value('11:30'),
            isBreak: const Value(false),
            subjectId: Value(mth?.id),
            teacherId: Value(ram?.id),
            roomNumber: Value(room),
          ),
        );

        // Period 3: Science & Technology (11:30 - 12:15)
        await db.insertPeriod(
          PeriodEntriesCompanion(
            academicYearId: Value(activeYear.id),
            classId: Value(cls.id),
            sectionId: Value(section?.id),
            dayOfWeek: Value(day),
            periodNumber: const Value(3),
            startTime: const Value('11:30'),
            endTime: const Value('12:15'),
            isBreak: const Value(false),
            subjectId: Value(sci?.id),
            teacherId: Value(hari?.id),
            roomNumber: const Value('Science Lab'),
          ),
        );

        // Period 4: Nepali (12:15 - 13:00)
        await db.insertPeriod(
          PeriodEntriesCompanion(
            academicYearId: Value(activeYear.id),
            classId: Value(cls.id),
            sectionId: Value(section?.id),
            dayOfWeek: Value(day),
            periodNumber: const Value(4),
            startTime: const Value('12:15'),
            endTime: const Value('13:00'),
            isBreak: const Value(false),
            subjectId: Value(nep?.id),
            teacherId: Value(gita?.id),
            roomNumber: Value(room),
          ),
        );

        // Tiffin / Lunch Break (13:00 - 13:45)
        await db.insertPeriod(
          PeriodEntriesCompanion(
            academicYearId: Value(activeYear.id),
            classId: Value(cls.id),
            sectionId: Value(section?.id),
            dayOfWeek: Value(day),
            periodNumber: const Value(5),
            startTime: const Value('13:00'),
            endTime: const Value('13:45'),
            isBreak: const Value(true),
            breakTitle: const Value('Lunch & Tiffin Break'),
            roomNumber: const Value('Cafeteria / Dining Hall'),
          ),
        );

        // Period 6: Social Studies (13:45 - 14:30)
        await db.insertPeriod(
          PeriodEntriesCompanion(
            academicYearId: Value(activeYear.id),
            classId: Value(cls.id),
            sectionId: Value(section?.id),
            dayOfWeek: Value(day),
            periodNumber: const Value(6),
            startTime: const Value('13:45'),
            endTime: const Value('14:30'),
            isBreak: const Value(false),
            subjectId: Value(soc?.id),
            teacherId: Value(bikash?.id),
            roomNumber: Value(room),
          ),
        );

        // Period 7: Computer Science (14:30 - 15:15)
        await db.insertPeriod(
          PeriodEntriesCompanion(
            academicYearId: Value(activeYear.id),
            classId: Value(cls.id),
            sectionId: Value(section?.id),
            dayOfWeek: Value(day),
            periodNumber: const Value(7),
            startTime: const Value('14:30'),
            endTime: const Value('15:15'),
            isBreak: const Value(false),
            subjectId: Value(cmp?.id),
            teacherId: Value(anita?.id),
            roomNumber: const Value('Computer Lab'),
          ),
        );

        // Period 8: Health & Physical Education / Sports (15:15 - 16:00)
        await db.insertPeriod(
          PeriodEntriesCompanion(
            academicYearId: Value(activeYear.id),
            classId: Value(cls.id),
            sectionId: Value(section?.id),
            dayOfWeek: Value(day),
            periodNumber: const Value(8),
            startTime: const Value('15:15'),
            endTime: const Value('16:00'),
            isBreak: const Value(false),
            subjectId: Value(hpe?.id),
            teacherId: Value(ramesh?.id),
            roomNumber: const Value('Sports Ground / Hall'),
          ),
        );
      }
    }
  }

  /// Seeds initial contacts for students, employees, and emergency services
  static Future<void> seedContacts(AppDatabase db) async {
    // 1. Seed sample students if empty so we have real IDs to link
    final existingStudents = await db.getAllStudents();
    if (existingStudents.isEmpty) {
      final classes = await db.getAllClassesWithSections();
      final class5 = classes.firstWhere(
        (c) =>
            c.name.toLowerCase().contains('5') ||
            c.name.toLowerCase().contains('five'),
        orElse: () => classes.isNotEmpty ? classes.first : classes.first,
      );
      final class10 = classes.firstWhere(
        (c) =>
            c.name.toLowerCase().contains('10') ||
            c.name.toLowerCase().contains('ten'),
        orElse: () => classes.isNotEmpty ? classes.last : classes.first,
      );
      await db.insertStudent(
        StudentsCompanion(
          name: const Value('Aarav Sharma'),
          classId: Value(class5.id),
        ),
      );
      await db.insertStudent(
        StudentsCompanion(
          name: const Value('Pooja Thapa'),
          classId: Value(class5.id),
        ),
      );
      await db.insertStudent(
        StudentsCompanion(
          name: const Value('Rohan Shrestha'),
          classId: Value(class10.id),
        ),
      );
      await db.insertStudent(
        StudentsCompanion(
          name: const Value('Sneha Adhikari'),
          classId: Value(class10.id),
        ),
      );
      await db.insertStudent(
        StudentsCompanion(
          name: const Value('Ayush Rai'),
          classId: Value(class5.id),
        ),
      );
    }

    final students = await db.getAllStudents();
    final employees = await db.getAllEmployees();

    final aarav = students.isNotEmpty ? students[0] : null;
    final pooja = students.length > 1 ? students[1] : null;
    final rohan = students.length > 2 ? students[2] : null;
    final sneha = students.length > 3 ? students[3] : null;

    final ram = employees.firstWhere(
      (e) => e.name.toLowerCase().contains('ram'),
      orElse: () => employees.isNotEmpty ? employees.first : employees.first,
    );
    final sita = employees.firstWhere(
      (e) => e.name.toLowerCase().contains('sita'),
      orElse: () => employees.length > 1 ? employees[1] : employees.first,
    );
    final hari = employees.firstWhere(
      (e) => e.name.toLowerCase().contains('hari'),
      orElse: () => employees.length > 2 ? employees[2] : employees.first,
    );

    final contactsList = <ContactsCompanion>[
      // --- Student Contacts (Guardians / Parents) ---
      if (aarav != null) ...[
        ContactsCompanion(
          sourceType: const Value(ContactSourceType.student),
          sourceId: Value(aarav.id),
          sourceName: Value('${aarav.name} (Student)'),
          name: const Value('Mukesh Sharma'),
          phone: const Value('9841223344'),
          relation: const Value('Father'),
          email: const Value('mukesh.sharma@gmail.com'),
          address: const Value('Kathmandu-3, Maharajgunj'),
          occupation: const Value('Civil Engineer'),
          isEmergency: const Value(true),
          isPrimary: const Value(true),
          notes: const Value('Available on phone 9 AM - 5 PM'),
        ),
        ContactsCompanion(
          sourceType: const Value(ContactSourceType.student),
          sourceId: Value(aarav.id),
          sourceName: Value('${aarav.name} (Student)'),
          name: const Value('Sunita Sharma'),
          phone: const Value('9841556677'),
          relation: const Value('Mother'),
          email: const Value('sunita.sharma@gmail.com'),
          address: const Value('Kathmandu-3, Maharajgunj'),
          occupation: const Value('Bank Manager'),
          isEmergency: const Value(true),
          isPrimary: const Value(false),
        ),
      ],
      if (pooja != null) ...[
        ContactsCompanion(
          sourceType: const Value(ContactSourceType.student),
          sourceId: Value(pooja.id),
          sourceName: Value('${pooja.name} (Student)'),
          name: const Value('Bhim Bahadur Thapa'),
          phone: const Value('9841889900'),
          relation: const Value('Father'),
          email: const Value('bhim.thapa@yahoo.com'),
          address: const Value('Lalitpur-4, Pulchowk'),
          occupation: const Value('Businessman'),
          isEmergency: const Value(true),
          isPrimary: const Value(true),
        ),
      ],
      if (rohan != null) ...[
        ContactsCompanion(
          sourceType: const Value(ContactSourceType.student),
          sourceId: Value(rohan.id),
          sourceName: Value('${rohan.name} (Student)'),
          name: const Value('Krishna Shrestha'),
          phone: const Value('9842112233'),
          relation: const Value('Father'),
          address: const Value('Bhaktapur-2, Suryabinayak'),
          occupation: const Value('Accountant'),
          isEmergency: const Value(true),
          isPrimary: const Value(true),
        ),
      ],
      if (sneha != null) ...[
        ContactsCompanion(
          sourceType: const Value(ContactSourceType.student),
          sourceId: Value(sneha.id),
          sourceName: Value('${sneha.name} (Student)'),
          name: const Value('Radha Adhikari'),
          phone: const Value('9842334455'),
          relation: const Value('Mother'),
          address: const Value('Kathmandu-10, Baneshwor'),
          occupation: const Value('High School Teacher'),
          isEmergency: const Value(true),
          isPrimary: const Value(true),
        ),
      ],

      // --- Employee Contacts ---
      ContactsCompanion(
        sourceType: const Value(ContactSourceType.employee),
        sourceId: Value(ram.id),
        sourceName: Value('${ram.name} (${ram.employeeCode ?? "EMP"})'),
        name: const Value('Sharmila Shrestha'),
        phone: const Value('9851011223'),
        relation: const Value('Spouse'),
        email: const Value('sharmila.shrestha@gmail.com'),
        address: const Value('Kathmandu-3, Maharajgunj'),
        occupation: const Value('Government Officer'),
        isEmergency: const Value(true),
        isPrimary: const Value(true),
      ),
      ContactsCompanion(
        sourceType: const Value(ContactSourceType.employee),
        sourceId: Value(ram.id),
        sourceName: Value('${ram.name} (${ram.employeeCode ?? "EMP"})'),
        name: const Value('Dr. Pradeep Rayamajhi'),
        phone: const Value('9851099887'),
        relation: const Value('Family Doctor'),
        notes: const Value('Contact in case of medical emergency'),
        isEmergency: const Value(true),
        isPrimary: const Value(false),
      ),
      ContactsCompanion(
        sourceType: const Value(ContactSourceType.employee),
        sourceId: Value(sita.id),
        sourceName: Value('${sita.name} (${sita.employeeCode ?? "EMP"})'),
        name: const Value('Mahesh Dahal'),
        phone: const Value('9851022334'),
        relation: const Value('Spouse'),
        address: const Value('Lalitpur-2, Sanepa'),
        isEmergency: const Value(true),
        isPrimary: const Value(true),
      ),
      ContactsCompanion(
        sourceType: const Value(ContactSourceType.employee),
        sourceId: Value(hari.id),
        sourceName: Value('${hari.name} (${hari.employeeCode ?? "EMP"})'),
        name: const Value('Maya Shrestha'),
        phone: const Value('9851033445'),
        relation: const Value('Spouse'),
        address: const Value('Bhaktapur-2, Suryabinayak'),
        isEmergency: const Value(true),
        isPrimary: const Value(true),
      ),

      // --- General / School Emergency Contacts ---
      const ContactsCompanion(
        sourceType: Value(ContactSourceType.other),
        sourceId: Value(null),
        sourceName: Value('School Administration'),
        name: Value('Dr. Ramesh Gautam (School Physician)'),
        phone: Value('9851000111'),
        relation: Value('School Doctor'),
        email: Value('clinic@school.edu.np'),
        address: Value('School Infirmary, Block A'),
        isEmergency: Value(true),
        isPrimary: Value(false),
        notes: Value('Available on campus Mon-Fri 9:00 - 15:00'),
      ),
      const ContactsCompanion(
        sourceType: Value(ContactSourceType.other),
        sourceId: Value(null),
        sourceName: Value('Emergency Services'),
        name: Value('Red Cross Ambulance Service'),
        phone: Value('102'),
        relation: Value('Ambulance Service'),
        isEmergency: Value(true),
        isPrimary: Value(false),
        notes: Value('Direct emergency hotline 24/7'),
      ),
      const ContactsCompanion(
        sourceType: Value(ContactSourceType.other),
        sourceId: Value(null),
        sourceName: Value('Emergency Services'),
        name: Value('Nepal Police Control'),
        phone: Value('100'),
        relation: Value('Police'),
        isEmergency: Value(true),
        isPrimary: Value(false),
      ),
      const ContactsCompanion(
        sourceType: Value(ContactSourceType.other),
        sourceId: Value(null),
        sourceName: Value('Transport Department'),
        name: Value('Suresh Thapa (Bus In-charge)'),
        phone: Value('9841998877'),
        relation: Value('Transport Coordinator'),
        address: Value('School Bus Depot'),
        isEmergency: Value(false),
        isPrimary: Value(false),
        notes: Value('Contact for bus route changes and delays'),
      ),
    ];

    for (final contact in contactsList) {
      await db.insertContact(contact);
    }
  }

  /// Seeds realistic student profiles with formatted IDs, admission numbers, multi-year academic histories, and guardian contacts
  static Future<void> seedStudents(AppDatabase db) async {
    // 1. Check if students and their academic histories already cleanly exist
    final existingStudents = await db.getAllStudents();
    final existingHistories =
        await db.select(db.studentAcademicHistories).get();
    if (existingStudents.isNotEmpty && existingHistories.isNotEmpty) {
      return;
    }

    // If partial or failed previous seed state, cleanly wipe students & student contacts first
    if (existingStudents.isNotEmpty && existingHistories.isEmpty) {
      await db.delete(db.studentAcademicHistories).go();
      await (db.delete(db.contacts)..where(
        (c) => c.sourceType.equals(ContactSourceType.student.name),
      )).go();
      await db.delete(db.students).go();
    }

    // 2. Ensure academic years 2024-2025 and 2025-2026 exist for multi-year history tracking
    var allYears = await db.getAllAcademicYears();
    final yearNames = allYears.map((y) => y.name).toSet();
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
    allYears = await db.getAllAcademicYears();

    final classesWithSections = await db.getAllClassesWithSections();
    if (allYears.isEmpty || classesWithSections.isEmpty) return;

    // Distinct Academic Years by name
    AcademicYear? year2024 =
        allYears.where((y) => y.name.startsWith('2024')).firstOrNull;
    AcademicYear? year2025 =
        allYears.where((y) => y.name.startsWith('2025')).firstOrNull;
    AcademicYear year2026 =
        allYears
            .where((y) => y.name.startsWith('2026') || y.isCurrent)
            .firstOrNull ??
        allYears.first;

    // Classes
    final class10 = classesWithSections.firstWhere(
      (c) => c.name.toLowerCase() == '10' || c.name.toLowerCase() == 'class 10',
      orElse: () => classesWithSections.last,
    );
    final class9 = classesWithSections.firstWhere(
      (c) => c.name.toLowerCase() == '9' || c.name.toLowerCase() == 'class 9',
      orElse: () => classesWithSections.first,
    );
    final class8 = classesWithSections.firstWhere(
      (c) => c.name.toLowerCase() == '8' || c.name.toLowerCase() == 'class 8',
      orElse: () => classesWithSections.first,
    );
    final class2 = classesWithSections.firstWhere(
      (c) => c.name.toLowerCase() == '2' || c.name.toLowerCase() == 'class 2',
      orElse: () => classesWithSections.first,
    );
    final class1 = classesWithSections.firstWhere(
      (c) => c.name.toLowerCase() == '1' || c.name.toLowerCase() == 'class 1',
      orElse: () => classesWithSections.first,
    );

    final sectionA10 =
        class10.sections.isNotEmpty ? class10.sections.first : null;
    final sectionA9 = class9.sections.isNotEmpty ? class9.sections.first : null;
    final sectionB9 =
        class9.sections.length > 1 ? class9.sections[1] : sectionA9;
    final sectionA8 = class8.sections.isNotEmpty ? class8.sections.first : null;
    final sectionA1 = class1.sections.isNotEmpty ? class1.sections.first : null;
    final sectionB2 =
        class2.sections.length > 1
            ? class2.sections[1]
            : (class2.sections.isNotEmpty ? class2.sections.first : null);

    // 1. Rohan Shrestha (3-Year History: 2024 Class 8 -> 2025 Class 9 -> 2026 Class 10)
    final rohanId = await db.insertStudent(
      StudentsCompanion(
        studentId: const Value('20260001'),
        admissionNumber: const Value('ADM-2024-0001'),
        admissionDate: Value(DateTime(2024, 4, 15)),
        name: const Value('Rohan Shrestha'),
        gender: const Value('Male'),
        dateOfBirth: Value(DateTime(2010, 8, 12)),
        bloodGroup: const Value('O+'),
        address: const Value('Baneshwor, Kathmandu'),
        phone: const Value('9841234001'),
        email: const Value('rohan.shrestha@example.com'),
        emergencyContactName: const Value('Nabin Shrestha'),
        emergencyContactPhone: const Value('9841234101'),
        emergencyContactRelation: const Value('Father'),
        classId: Value(class10.id),
        sectionId: Value(sectionA10?.id),
        rollNumber: const Value(1),
        isActive: const Value(true),
      ),
    );

    // Rohan's 3-year history
    if (sectionA8 != null &&
        year2024 != null &&
        year2024.id != year2026.id &&
        (year2025 == null || year2024.id != year2025.id)) {
      await db.insertAcademicHistory(
        StudentAcademicHistoriesCompanion(
          studentId: Value(rohanId),
          academicYearId: Value(year2024.id),
          classId: Value(class8.id),
          sectionId: Value(sectionA8.id),
          rollNumber: const Value(5),
          status: const Value(AcademicStatus.promoted),
          resultStatus: const Value(AcademicResult.passed),
          remarks: const Value('Passed Class 8 with distinction (GPA 3.85)'),
          enrolledAt: Value(DateTime(2024, 4, 15)),
        ),
      );
    }
    if (sectionA9 != null && year2025 != null && year2025.id != year2026.id) {
      await db.insertAcademicHistory(
        StudentAcademicHistoriesCompanion(
          studentId: Value(rohanId),
          academicYearId: Value(year2025.id),
          classId: Value(class9.id),
          sectionId: Value(sectionA9.id),
          rollNumber: const Value(3),
          status: const Value(AcademicStatus.promoted),
          resultStatus: const Value(AcademicResult.passed),
          remarks: const Value('Promoted to Class 10 (GPA 3.90)'),
          enrolledAt: Value(DateTime(2025, 4, 15)),
        ),
      );
    }
    if (sectionA10 != null) {
      await db.insertAcademicHistory(
        StudentAcademicHistoriesCompanion(
          studentId: Value(rohanId),
          academicYearId: Value(year2026.id),
          classId: Value(class10.id),
          sectionId: Value(sectionA10.id),
          rollNumber: const Value(1),
          status: const Value(AcademicStatus.active),
          resultStatus: const Value(AcademicResult.pending),
          remarks: const Value('Current SEE candidate session'),
          enrolledAt: Value(DateTime(2026, 4, 15)),
        ),
      );
    }

    // Guardian Contact for Rohan
    await db.insertContact(
      ContactsCompanion(
        sourceType: const Value(ContactSourceType.student),
        sourceId: Value(rohanId),
        sourceName: const Value('Rohan Shrestha (20260001)'),
        name: const Value('Nabin Shrestha'),
        phone: const Value('9841234101'),
        relation: const Value('Father'),
        address: const Value('Baneshwor, Kathmandu'),
        occupation: const Value('Civil Engineer'),
        isPrimary: const Value(true),
        isEmergency: const Value(true),
      ),
    );

    // 2. Aarav Sharma (2-Year History: 2025 Class 1 -> 2026 Class 2)
    final aaravId = await db.insertStudent(
      StudentsCompanion(
        studentId: const Value('20260002'),
        admissionNumber: const Value('ADM-2025-0015'),
        admissionDate: Value(DateTime(2025, 4, 16)),
        name: const Value('Aarav Sharma'),
        gender: const Value('Male'),
        dateOfBirth: Value(DateTime(2018, 3, 20)),
        bloodGroup: const Value('A+'),
        address: const Value('Kupondole, Lalitpur'),
        phone: const Value('9841234002'),
        emergencyContactName: const Value('Gita Sharma'),
        emergencyContactPhone: const Value('9841234102'),
        emergencyContactRelation: const Value('Mother'),
        classId: Value(class2.id),
        sectionId: Value(sectionB2?.id),
        rollNumber: const Value(8),
        isActive: const Value(true),
      ),
    );

    if (sectionA1 != null && year2025 != null && year2025.id != year2026.id) {
      await db.insertAcademicHistory(
        StudentAcademicHistoriesCompanion(
          studentId: Value(aaravId),
          academicYearId: Value(year2025.id),
          classId: Value(class1.id),
          sectionId: Value(sectionA1.id),
          rollNumber: const Value(12),
          status: const Value(AcademicStatus.promoted),
          resultStatus: const Value(AcademicResult.passed),
          remarks: const Value('Promoted from Class 1 A to Class 2 B'),
          enrolledAt: Value(DateTime(2025, 4, 16)),
        ),
      );
    }
    if (sectionB2 != null) {
      await db.insertAcademicHistory(
        StudentAcademicHistoriesCompanion(
          studentId: Value(aaravId),
          academicYearId: Value(year2026.id),
          classId: Value(class2.id),
          sectionId: Value(sectionB2.id),
          rollNumber: const Value(8),
          status: const Value(AcademicStatus.active),
          resultStatus: const Value(AcademicResult.pending),
          remarks: const Value('Current enrollment in Class 2 B'),
          enrolledAt: Value(DateTime(2026, 4, 15)),
        ),
      );
    }

    await db.insertContact(
      ContactsCompanion(
        sourceType: const Value(ContactSourceType.student),
        sourceId: Value(aaravId),
        sourceName: const Value('Aarav Sharma (20260002)'),
        name: const Value('Gita Sharma'),
        phone: const Value('9841234102'),
        relation: const Value('Mother'),
        address: const Value('Kupondole, Lalitpur'),
        occupation: const Value('Bank Manager'),
        isPrimary: const Value(true),
        isEmergency: const Value(true),
      ),
    );

    // 3. Priya Adhikari (New Admission in 2026: Class 10 A, Roll 2)
    final priyaId = await db.insertStudent(
      StudentsCompanion(
        studentId: const Value('20260003'),
        admissionNumber: const Value('ADM-2026-0001'),
        admissionDate: Value(DateTime(2026, 4, 10)),
        name: const Value('Priya Adhikari'),
        gender: const Value('Female'),
        dateOfBirth: Value(DateTime(2010, 11, 5)),
        bloodGroup: const Value('B+'),
        address: const Value('Koteshwor, Kathmandu'),
        phone: const Value('9841234003'),
        email: const Value('priya.adhikari@example.com'),
        emergencyContactName: const Value('Deepak Adhikari'),
        emergencyContactPhone: const Value('9841234103'),
        emergencyContactRelation: const Value('Father'),
        classId: Value(class10.id),
        sectionId: Value(sectionA10?.id),
        rollNumber: const Value(2),
        isActive: const Value(true),
      ),
    );

    if (sectionA10 != null) {
      await db.insertAcademicHistory(
        StudentAcademicHistoriesCompanion(
          studentId: Value(priyaId),
          academicYearId: Value(year2026.id),
          classId: Value(class10.id),
          sectionId: Value(sectionA10.id),
          rollNumber: const Value(2),
          status: const Value(AcademicStatus.active),
          resultStatus: const Value(AcademicResult.pending),
          remarks: const Value('Direct admission into Class 10'),
          enrolledAt: Value(DateTime(2026, 4, 10)),
        ),
      );
    }

    await db.insertContact(
      ContactsCompanion(
        sourceType: const Value(ContactSourceType.student),
        sourceId: Value(priyaId),
        sourceName: const Value('Priya Adhikari (20260003)'),
        name: const Value('Deepak Adhikari'),
        phone: const Value('9841234103'),
        relation: const Value('Father'),
        address: const Value('Koteshwor, Kathmandu'),
        occupation: const Value('Advocate'),
        isPrimary: const Value(true),
        isEmergency: const Value(true),
      ),
    );

    // 4. Bikash Thapa (Retained Example: 2025 Class 9 -> 2026 Class 9)
    final bikashId = await db.insertStudent(
      StudentsCompanion(
        studentId: const Value('20260004'),
        admissionNumber: const Value('ADM-2025-0022'),
        admissionDate: Value(DateTime(2025, 4, 18)),
        name: const Value('Bikash Thapa'),
        gender: const Value('Male'),
        dateOfBirth: Value(DateTime(2011, 2, 14)),
        bloodGroup: const Value('AB+'),
        address: const Value('Sanepa, Lalitpur'),
        phone: const Value('9841234004'),
        emergencyContactName: const Value('Suraj Thapa'),
        emergencyContactPhone: const Value('9841234104'),
        emergencyContactRelation: const Value('Father'),
        classId: Value(class9.id),
        sectionId: Value(sectionB9?.id),
        rollNumber: const Value(15),
        isActive: const Value(true),
      ),
    );

    if (sectionB9 != null) {
      if (year2025 != null && year2025.id != year2026.id) {
        await db.insertAcademicHistory(
          StudentAcademicHistoriesCompanion(
            studentId: Value(bikashId),
            academicYearId: Value(year2025.id),
            classId: Value(class9.id),
            sectionId: Value(sectionB9.id),
            rollNumber: const Value(22),
            status: const Value(AcademicStatus.retained),
            resultStatus: const Value(AcademicResult.failed),
            remarks: const Value(
              'Did not clear final exams; retained in Class 9',
            ),
            enrolledAt: Value(DateTime(2025, 4, 18)),
          ),
        );
      }

      await db.insertAcademicHistory(
        StudentAcademicHistoriesCompanion(
          studentId: Value(bikashId),
          academicYearId: Value(year2026.id),
          classId: Value(class9.id),
          sectionId: Value(sectionB9.id),
          rollNumber: const Value(15),
          status: const Value(AcademicStatus.active),
          resultStatus: const Value(AcademicResult.pending),
          remarks: const Value('Repeating Class 9 session'),
          enrolledAt: Value(DateTime(2026, 4, 15)),
        ),
      );
    }

    await db.insertContact(
      ContactsCompanion(
        sourceType: const Value(ContactSourceType.student),
        sourceId: Value(bikashId),
        sourceName: const Value('Bikash Thapa (20260004)'),
        name: const Value('Suraj Thapa'),
        phone: const Value('9841234104'),
        relation: const Value('Father'),
        address: const Value('Sanepa, Lalitpur'),
        occupation: const Value('Businessman'),
        isPrimary: const Value(true),
        isEmergency: const Value(true),
      ),
    );

    // 5. Sneha Gurung (Class 1 A, Roll 1)
    final snehaId = await db.insertStudent(
      StudentsCompanion(
        studentId: const Value('20260005'),
        admissionNumber: const Value('ADM-2026-0002'),
        admissionDate: Value(DateTime(2026, 4, 12)),
        name: const Value('Sneha Gurung'),
        gender: const Value('Female'),
        dateOfBirth: Value(DateTime(2019, 6, 25)),
        bloodGroup: const Value('O-'),
        address: const Value('Chabahil, Kathmandu'),
        phone: const Value('9841234005'),
        emergencyContactName: const Value('Sunita Gurung'),
        emergencyContactPhone: const Value('9841234105'),
        emergencyContactRelation: const Value('Mother'),
        classId: Value(class1.id),
        sectionId: Value(sectionA1?.id),
        rollNumber: const Value(1),
        isActive: const Value(true),
      ),
    );

    if (sectionA1 != null) {
      await db.insertAcademicHistory(
        StudentAcademicHistoriesCompanion(
          studentId: Value(snehaId),
          academicYearId: Value(year2026.id),
          classId: Value(class1.id),
          sectionId: Value(sectionA1.id),
          rollNumber: const Value(1),
          status: const Value(AcademicStatus.active),
          resultStatus: const Value(AcademicResult.pending),
          remarks: const Value('Fresh admission in Class 1'),
          enrolledAt: Value(DateTime(2026, 4, 12)),
        ),
      );
    }

    await db.insertContact(
      ContactsCompanion(
        sourceType: const Value(ContactSourceType.student),
        sourceId: Value(snehaId),
        sourceName: const Value('Sneha Gurung (20260005)'),
        name: const Value('Sunita Gurung'),
        phone: const Value('9841234105'),
        relation: const Value('Mother'),
        address: const Value('Chabahil, Kathmandu'),
        occupation: const Value('Nurse'),
        isPrimary: const Value(true),
        isEmergency: const Value(true),
      ),
    );
  }

  /// Seeds default system expense categories
  static Future<void> seedExpenseCategories(AppDatabase db) async {
    final existing = await db.getAllExpenseCategories();
    if (existing.isNotEmpty) return;

    final categories = [
      const ExpenseCategoriesCompanion(
        name: Value('Room Rent'),
        iconName: Value('domain'),
        colorValue: Value(0xFF3F51B5), // Indigo
        isSystem: Value(true),
      ),
      const ExpenseCategoriesCompanion(
        name: Value('Travel'),
        iconName: Value('directions_bus'),
        colorValue: Value(0xFF009688), // Teal
        isSystem: Value(true),
      ),
      const ExpenseCategoriesCompanion(
        name: Value('Breakfast'),
        iconName: Value('free_breakfast'),
        colorValue: Value(0xFFFF9800), // Amber/Orange
        isSystem: Value(true),
      ),
      const ExpenseCategoriesCompanion(
        name: Value('Lunch'),
        iconName: Value('restaurant'),
        colorValue: Value(0xFFF4511E), // Deep Orange
        isSystem: Value(true),
      ),
      const ExpenseCategoriesCompanion(
        name: Value('Dinner'),
        iconName: Value('dinner_dining'),
        colorValue: Value(0xFF9C27B0), // Purple
        isSystem: Value(true),
      ),
      const ExpenseCategoriesCompanion(
        name: Value('Miscellaneous'),
        iconName: Value('category'),
        colorValue: Value(0xFF607D8B), // Blue Grey
        isSystem: Value(true),
      ),
      const ExpenseCategoriesCompanion(
        name: Value('Utilities & Bills'),
        iconName: Value('lightbulb'),
        colorValue: Value(0xFF2196F3), // Blue
        isSystem: Value(true),
      ),
      const ExpenseCategoriesCompanion(
        name: Value('Stationery & Supplies'),
        iconName: Value('inventory_2'),
        colorValue: Value(0xFF4CAF50), // Green
        isSystem: Value(true),
      ),
    ];

    for (final cat in categories) {
      await db.insertExpenseCategory(cat);
    }
  }

  /// Seeds realistic school expenses spanning today, this week, this month, and this year
  static Future<void> seedExpenses(AppDatabase db) async {
    final existing = await db.getExpensesWithCategory();
    if (existing.isNotEmpty) return;

    final categories = await db.getAllExpenseCategories();
    if (categories.isEmpty) return;

    final catMap = {for (final c in categories) c.name: c.id};
    final currentYear = await db.getCurrentAcademicYear();
    final yearId = currentYear?.id;

    final now = DateTime.now();

    final sampleExpenses = [
      // Today
      ExpensesCompanion(
        title: const Value('Staff Morning Tea & Snacks'),
        categoryId: Value(catMap['Breakfast'] ?? categories.first.id),
        amount: const Value(1250.0),
        expenseDate: Value(DateTime(now.year, now.month, now.day, 10, 30)),
        paymentMethod: const Value('Cash'),
        referenceNumber: const Value('EXP-2026-001'),
        paidTo: const Value('Annapurna Bakery & Tea Stall'),
        notes: const Value(
          'Morning refreshments for teachers & administrative staff',
        ),
        academicYearId: Value(yearId),
      ),
      ExpensesCompanion(
        title: const Value('Visitor Lunch Meeting'),
        categoryId: Value(catMap['Lunch'] ?? categories.first.id),
        amount: const Value(3400.0),
        expenseDate: Value(DateTime(now.year, now.month, now.day, 13, 15)),
        paymentMethod: const Value('eSewa'),
        referenceNumber: const Value('EXP-2026-002'),
        paidTo: const Value('Himalayan Thakali Kitchen'),
        notes: const Value(
          'Lunch with district education board inspection delegates',
        ),
        academicYearId: Value(yearId),
      ),

      // 2 Days ago (This Week)
      ExpensesCompanion(
        title: const Value('School Bus Fuel & Mobil Refill'),
        categoryId: Value(catMap['Travel'] ?? categories.first.id),
        amount: const Value(8500.0),
        expenseDate: Value(now.subtract(const Duration(days: 2))),
        paymentMethod: const Value('Bank Transfer'),
        referenceNumber: const Value('EXP-2026-003'),
        paidTo: const Value('Sajha Petrol Pump, Pulchowk'),
        notes: const Value('Diesel top-up for Bus #1 and Bus #2 weekly run'),
        academicYearId: Value(yearId),
      ),
      ExpensesCompanion(
        title: const Value('Exam Answer Sheets & Whiteboard Markers'),
        categoryId: Value(
          catMap['Stationery & Supplies'] ?? categories.first.id,
        ),
        amount: const Value(4800.0),
        expenseDate: Value(now.subtract(const Duration(days: 3))),
        paymentMethod: const Value('Cash'),
        referenceNumber: const Value('EXP-2026-004'),
        paidTo: const Value('Bhrikuti Paper & Stationery Mart'),
        notes: const Value(
          'Stationery refill for terminal evaluation printing and tests',
        ),
        academicYearId: Value(yearId),
      ),

      // 8 Days ago (This Month)
      ExpensesCompanion(
        title: const Value('School Main Building Monthly Room Rent'),
        categoryId: Value(catMap['Room Rent'] ?? categories.first.id),
        amount: const Value(85000.0),
        expenseDate: Value(now.subtract(const Duration(days: 8))),
        paymentMethod: const Value('Bank Transfer'),
        referenceNumber: const Value('EXP-2026-005'),
        paidTo: const Value('Bishnu Prasad Pokharel (Landlord)'),
        notes: const Value(
          'Rent for Primary & Secondary blocks building premises',
        ),
        academicYearId: Value(yearId),
      ),
      ExpensesCompanion(
        title: const Value('Staff Appreciation Dinner Party'),
        categoryId: Value(catMap['Dinner'] ?? categories.first.id),
        amount: const Value(16200.0),
        expenseDate: Value(now.subtract(const Duration(days: 12))),
        paymentMethod: const Value('Cheque'),
        referenceNumber: const Value('CHQ-882910'),
        paidTo: const Value('Valley Banquet & Event Center'),
        notes: const Value('Annual teachers day dinner celebration'),
        academicYearId: Value(yearId),
      ),
      ExpensesCompanion(
        title: const Value('Electricity & High-Speed Internet Bill'),
        categoryId: Value(catMap['Utilities & Bills'] ?? categories.first.id),
        amount: const Value(9200.0),
        expenseDate: Value(now.subtract(const Duration(days: 15))),
        paymentMethod: const Value('eSewa'),
        referenceNumber: const Value('EXP-2026-007'),
        paidTo: const Value('NEA & WorldLink Communications'),
        notes: const Value('Monthly school campus utility payments'),
        academicYearId: Value(yearId),
      ),

      // 40 Days ago (Earlier this year)
      ExpensesCompanion(
        title: const Value('Inter-School Sports Meet Van Rental'),
        categoryId: Value(catMap['Travel'] ?? categories.first.id),
        amount: const Value(12000.0),
        expenseDate: Value(now.subtract(const Duration(days: 40))),
        paymentMethod: const Value('Bank Transfer'),
        referenceNumber: const Value('EXP-2026-008'),
        paidTo: const Value('KTM Tourist Bus & Van Services'),
        notes: const Value(
          'Round-trip commute for football and basketball squads',
        ),
        academicYearId: Value(yearId),
      ),
      ExpensesCompanion(
        title: const Value('First-Aid Medical Kit & Emergency Supplies'),
        categoryId: Value(catMap['Miscellaneous'] ?? categories.first.id),
        amount: const Value(3100.0),
        expenseDate: Value(now.subtract(const Duration(days: 65))),
        paymentMethod: const Value('Cash'),
        referenceNumber: const Value('EXP-2026-009'),
        paidTo: const Value('Apollo Medical Store, Baneshwor'),
        notes: const Value(
          'Bandages, dettol, paracetamol, and sports ice-packs',
        ),
        academicYearId: Value(yearId),
      ),
      ExpensesCompanion(
        title: const Value('Library Book Display Rack Renovation'),
        categoryId: Value(catMap['Miscellaneous'] ?? categories.first.id),
        amount: const Value(7500.0),
        expenseDate: Value(now.subtract(const Duration(days: 90))),
        paymentMethod: const Value('Cash'),
        referenceNumber: const Value('EXP-2026-010'),
        paidTo: const Value('Modern Carpentry Works'),
        notes: const Value(
          'Wood repair and varnishing of library reading shelves',
        ),
        academicYearId: Value(yearId),
      ),
    ];

    for (final exp in sampleExpenses) {
      await db.insertExpense(exp);
    }
  }

  /// Seeds realistic employee payroll records and salary advance scenarios
  static Future<void> seedPayroll(AppDatabase db) async {
    final existingPayments = await db.select(db.salaryPayments).get();
    if (existingPayments.isNotEmpty) return;

    final employeesList = await db.getAllEmployees();
    if (employeesList.isEmpty) return;

    final currentYear = await db.getCurrentAcademicYear();
    final yearId = currentYear?.id;
    final now = DateTime.now();

    // Map employees by code or name
    final empMap = {
      for (final e in employeesList) (e.employeeCode ?? e.name): e,
    };

    // 1. Give Advance to Ram Sharma (TCH-001) - 10,000
    final ram = empMap['TCH-001'] ?? employeesList.first;
    final ramAdvanceId = await db.insertSalaryAdvance(
      SalaryAdvancesCompanion(
        employeeId: Value(ram.id),
        amount: const Value(10000.0),
        advanceDate: Value(now.subtract(const Duration(days: 45))),
        adjustedAmount: const Value(3000.0), // 3,000 adjusted in last pay
        paymentMethod: const Value('Bank Transfer'),
        referenceNumber: const Value('ADV-2026-001'),
        reason: const Value('Urgent medical treatment'),
        notes: const Value('Agreed to adjust in installments over 3-4 months'),
        academicYearId: Value(yearId),
        status: const Value('partially_adjusted'),
      ),
    );

    // 2. Paid Salary for Ram Sharma for previous month with partial advance deduction (multi-term)
    final prevMonthDate = DateTime(
      now.year,
      now.month == 1 ? 12 : now.month - 1,
      28,
    );
    final ramPaymentId = await db.insertSalaryPayment(
      SalaryPaymentsCompanion(
        employeeId: Value(ram.id),
        academicYearId: Value(yearId),
        year: Value(prevMonthDate.year),
        month: Value(prevMonthDate.month),
        paymentDate: Value(prevMonthDate),
        basicSalary: Value(ram.basicSalary ?? 35000.0),
        bonus: const Value(2500.0),
        bonusReason: const Value('Festival / Performance Allowance'),
        deduction: const Value(1500.0),
        deductionReason: const Value('Income Tax & Provident Fund'),
        advanceDeduction: const Value(3000.0),
        grossSalary: Value((ram.basicSalary ?? 35000.0) + 2500.0),
        totalDeductions: const Value(1500.0 + 3000.0),
        netSalary: Value((ram.basicSalary ?? 35000.0) + 2500.0 - 4500.0),
        paymentMethod: const Value('Bank Transfer'),
        referenceNumber: const Value('SAL-2026-001'),
        status: const Value('paid'),
        notes: const Value('Monthly salary disbursed; 3,000 advance adjusted'),
      ),
    );

    // Link adjustment
    await db.insertSalaryAdvanceAdjustment(
      SalaryAdvanceAdjustmentsCompanion(
        salaryPaymentId: Value(ramPaymentId),
        salaryAdvanceId: Value(ramAdvanceId),
        adjustedAmount: const Value(3000.0),
      ),
    );

    // 3. Paid Salary for Sita Thapa (TCH-002) - Standard without advance
    final sita = empMap['TCH-002'];
    if (sita != null) {
      final sitaBasic = sita.basicSalary ?? 32000.0;
      await db.insertSalaryPayment(
        SalaryPaymentsCompanion(
          employeeId: Value(sita.id),
          academicYearId: Value(yearId),
          year: Value(prevMonthDate.year),
          month: Value(prevMonthDate.month),
          paymentDate: Value(prevMonthDate),
          basicSalary: Value(sitaBasic),
          bonus: const Value(0.0),
          deduction: const Value(1200.0),
          deductionReason: const Value('Tax & Social Security'),
          advanceDeduction: const Value(0.0),
          grossSalary: Value(sitaBasic),
          totalDeductions: const Value(1200.0),
          netSalary: Value(sitaBasic - 1200.0),
          paymentMethod: const Value('Bank Transfer'),
          referenceNumber: const Value('SAL-2026-002'),
          status: const Value('paid'),
          notes: const Value('Monthly salary disbursed on time'),
        ),
      );
    }

    // 4. Paid Salary for Ram Bahadur Tamang (STF-001) - Support Staff
    final accountant = empMap['STF-001'];
    if (accountant != null) {
      final accBasic = accountant.basicSalary ?? 30000.0;
      await db.insertSalaryPayment(
        SalaryPaymentsCompanion(
          employeeId: Value(accountant.id),
          academicYearId: Value(yearId),
          year: Value(prevMonthDate.year),
          month: Value(prevMonthDate.month),
          paymentDate: Value(prevMonthDate),
          basicSalary: Value(accBasic),
          bonus: const Value(1000.0),
          bonusReason: const Value('Audit Completion Allowance'),
          deduction: const Value(800.0),
          deductionReason: const Value('Tax & Health Insurance'),
          advanceDeduction: const Value(0.0),
          grossSalary: Value(accBasic + 1000.0),
          totalDeductions: const Value(800.0),
          netSalary: Value(accBasic + 1000.0 - 800.0),
          paymentMethod: const Value('Bank Transfer'),
          referenceNumber: const Value('SAL-2026-003'),
          status: const Value('paid'),
          notes: const Value('Senior Accountant monthly compensation'),
        ),
      );
    }

    // 5. Open Advance for Hari Prasad Shrestha (TCH-003) - 5,000 pending (not yet adjusted)
    final hari = empMap['TCH-003'];
    if (hari != null) {
      await db.insertSalaryAdvance(
        SalaryAdvancesCompanion(
          employeeId: Value(hari.id),
          amount: const Value(5000.0),
          advanceDate: Value(now.subtract(const Duration(days: 12))),
          adjustedAmount: const Value(0.0),
          paymentMethod: const Value('Cash'),
          referenceNumber: const Value('ADV-2026-002'),
          reason: const Value('Home repair advance'),
          notes: const Value('To be adjusted in next salary payout'),
          academicYearId: Value(yearId),
          status: const Value('pending'),
        ),
      );
    }
  }

  /// Seeds fee categories, student fees, and fee payments
  static Future<void> seedFees(AppDatabase db) async {
    // 1. Seed Fee Categories
    final existingCategories = await db.getAllFeeCategories();
    Map<String, int> catMap = {};
    if (existingCategories.isEmpty) {
      final defaultCats = [
        const FeeCategoriesCompanion(
          name: Value('Monthly Tuition Fee'),
          frequency: Value('monthly'),
          defaultAmount: Value(2500.0),
          description: Value('Regular monthly academic tuition charges'),
          isSystem: Value(true),
        ),
        const FeeCategoriesCompanion(
          name: Value('Admission Fee'),
          frequency: Value('one_time'),
          defaultAmount: Value(5000.0),
          description: Value('New student enrollment & admission charges'),
          isSystem: Value(true),
        ),
        const FeeCategoriesCompanion(
          name: Value('Uniform & Dress'),
          frequency: Value('one_time'),
          defaultAmount: Value(3500.0),
          description: Value('School uniform set, sportswear, tie and blazer'),
          isSystem: Value(true),
        ),
        const FeeCategoriesCompanion(
          name: Value('Term Examination Fee'),
          frequency: Value('term_wise'),
          defaultAmount: Value(1000.0),
          description: Value('Terminal exam and evaluation charges'),
          isSystem: Value(true),
        ),
        const FeeCategoriesCompanion(
          name: Value('Transportation Fee'),
          frequency: Value('monthly'),
          defaultAmount: Value(1500.0),
          description: Value('School bus commute and transit services'),
          isSystem: Value(false),
        ),
        const FeeCategoriesCompanion(
          name: Value('Annual Sports & Activities Fee'),
          frequency: Value('yearly'),
          defaultAmount: Value(2000.0),
          description: Value(
            'Annual sports meet, cultural events, and extracurriculars',
          ),
          isSystem: Value(false),
        ),
        const FeeCategoriesCompanion(
          name: Value('Computer & Science Lab Fee'),
          frequency: Value('quarterly'),
          defaultAmount: Value(800.0),
          description: Value(
            'Quarterly lab materials, computer science and IT lab usage',
          ),
          isSystem: Value(false),
        ),
      ];

      for (final cat in defaultCats) {
        final id = await db.insertFeeCategory(cat);
        catMap[cat.name.value] = id;
      }
    } else {
      catMap = {for (final c in existingCategories) c.name: c.id};
    }

    // 2. Seed Student Fees & Payments
    final existingStudentFees = await db.select(db.studentFees).get();
    if (existingStudentFees.isNotEmpty) return;

    final students = await db.getAllStudents();
    if (students.isEmpty) return;

    final activeYear = await db.getActiveAcademicYear();
    final yearId = activeYear?.id;
    final now = DateTime.now();

    final tuitionCatId = catMap['Monthly Tuition Fee'];
    final admissionCatId = catMap['Admission Fee'];
    final dressCatId = catMap['Uniform & Dress'];
    final examCatId = catMap['Term Examination Fee'];

    if (tuitionCatId == null ||
        admissionCatId == null ||
        dressCatId == null ||
        examCatId == null) {
      return;
    }

    final stuMap = {for (final s in students) (s.admissionNumber): s};
    final student1 = stuMap['ADM-2026-001'] ?? students[0];
    final student2 =
        stuMap['ADM-2026-002'] ??
        (students.length > 1 ? students[1] : students[0]);
    final student3 =
        stuMap['ADM-2026-003'] ??
        (students.length > 2 ? students[2] : students[0]);

    // Student 1 (Aarav Sharma):
    // Fee 1: Baishakh Tuition Fee (2,500) -> Paid 2,500 (Status: paid)
    final f1Id = await db.insertStudentFee(
      StudentFeesCompanion(
        studentId: Value(student1.id),
        academicYearId: Value(yearId),
        feeCategoryId: Value(tuitionCatId),
        title: const Value('Baishakh Tuition Fee'),
        totalAmount: const Value(2500.0),
        discountAmount: const Value(0.0),
        paidAmount: const Value(2500.0),
        dueDate: Value(now.subtract(const Duration(days: 20))),
        status: const Value('paid'),
        academicMonth: const Value(1),
        academicTerm: const Value('Term 1'),
        notes: const Value('Monthly tuition for Baishakh'),
      ),
    );
    await db.insertFeePayment(
      FeePaymentsCompanion(
        studentFeeId: Value(f1Id),
        studentId: Value(student1.id),
        academicYearId: Value(yearId),
        receiptNumber: const Value('REC-2026-0001'),
        amount: const Value(2500.0),
        paymentDate: Value(now.subtract(const Duration(days: 22))),
        paymentMethod: const Value('Cash'),
        referenceNumber: const Value('CASH-001'),
        remarks: const Value('Full payment received at counter'),
        receivedBy: const Value('Accountant'),
      ),
    );

    // Fee 2: Jestha Tuition Fee (2,500) -> Paid 1,500 (Partial Payment!), Remaining: 1,000
    final f2Id = await db.insertStudentFee(
      StudentFeesCompanion(
        studentId: Value(student1.id),
        academicYearId: Value(yearId),
        feeCategoryId: Value(tuitionCatId),
        title: const Value('Jestha Tuition Fee'),
        totalAmount: const Value(2500.0),
        discountAmount: const Value(0.0),
        paidAmount: const Value(1500.0),
        dueDate: Value(now.add(const Duration(days: 10))),
        status: const Value('partial'),
        academicMonth: const Value(2),
        academicTerm: const Value('Term 1'),
        notes: const Value('Monthly tuition for Jestha - 1st installment paid'),
      ),
    );
    await db.insertFeePayment(
      FeePaymentsCompanion(
        studentFeeId: Value(f2Id),
        studentId: Value(student1.id),
        academicYearId: Value(yearId),
        receiptNumber: const Value('REC-2026-0002'),
        amount: const Value(1500.0),
        paymentDate: Value(now.subtract(const Duration(days: 2))),
        paymentMethod: const Value('eSewa'),
        referenceNumber: const Value('ESEWA-98412345'),
        remarks: const Value('Partial payment via eSewa digital wallet'),
        receivedBy: const Value('Online System'),
      ),
    );

    // Fee 3: Uniform & Dress (3,500) -> 0 paid (Pending!)
    await db.insertStudentFee(
      StudentFeesCompanion(
        studentId: Value(student1.id),
        academicYearId: Value(yearId),
        feeCategoryId: Value(dressCatId),
        title: const Value('Grade 8 Uniform & Dress Set'),
        totalAmount: const Value(3500.0),
        discountAmount: const Value(0.0),
        paidAmount: const Value(0.0),
        dueDate: Value(now.add(const Duration(days: 15))),
        status: const Value('pending'),
        notes: const Value('Winter jacket, blazer, shirts, tie, belt'),
      ),
    );

    // Fee 4: 1st Term Exam Fee (1,000) -> Paid 1,000 (Status: paid, paid today!)
    final f4Id = await db.insertStudentFee(
      StudentFeesCompanion(
        studentId: Value(student1.id),
        academicYearId: Value(yearId),
        feeCategoryId: Value(examCatId),
        title: const Value('1st Term Examination Fee'),
        totalAmount: const Value(1000.0),
        discountAmount: const Value(0.0),
        paidAmount: const Value(1000.0),
        dueDate: Value(now.subtract(const Duration(days: 1))),
        status: const Value('paid'),
        academicTerm: const Value('Term 1'),
        notes: const Value('First term evaluation fee'),
      ),
    );
    await db.insertFeePayment(
      FeePaymentsCompanion(
        studentFeeId: Value(f4Id),
        studentId: Value(student1.id),
        academicYearId: Value(yearId),
        receiptNumber: const Value('REC-2026-0003'),
        amount: const Value(1000.0),
        paymentDate: Value(now), // TODAY!
        paymentMethod: const Value('Bank Transfer'),
        referenceNumber: const Value('TXN-NABIL-8921'),
        remarks: const Value('Bank transfer confirmed'),
        receivedBy: const Value('Accountant'),
      ),
    );

    // Student 2 (Bibek Poudel):
    // Fee 5: Admission Fee (5,000) -> Paid 5,000 (Status: paid)
    final f5Id = await db.insertStudentFee(
      StudentFeesCompanion(
        studentId: Value(student2.id),
        academicYearId: Value(yearId),
        feeCategoryId: Value(admissionCatId),
        title: const Value('Class 6 Admission & Registration Fee'),
        totalAmount: const Value(5000.0),
        discountAmount: const Value(0.0),
        paidAmount: const Value(5000.0),
        dueDate: Value(now.subtract(const Duration(days: 30))),
        status: const Value('paid'),
        notes: const Value('Admission enrollment fee'),
      ),
    );
    await db.insertFeePayment(
      FeePaymentsCompanion(
        studentFeeId: Value(f5Id),
        studentId: Value(student2.id),
        academicYearId: Value(yearId),
        receiptNumber: const Value('REC-2026-0004'),
        amount: const Value(5000.0),
        paymentDate: Value(now.subtract(const Duration(days: 30))),
        paymentMethod: const Value('Bank Transfer'),
        referenceNumber: const Value('TXN-GBIME-1102'),
        remarks: const Value('New admission fees deposit'),
        receivedBy: const Value('Finance Officer'),
      ),
    );

    // Fee 6: Baishakh Tuition Fee (2,500) -> Paid 1,000 (Partial Payment!), Remaining: 1,500
    final f6Id = await db.insertStudentFee(
      StudentFeesCompanion(
        studentId: Value(student2.id),
        academicYearId: Value(yearId),
        feeCategoryId: Value(tuitionCatId),
        title: const Value('Baishakh Tuition Fee'),
        totalAmount: const Value(2500.0),
        discountAmount: const Value(0.0),
        paidAmount: const Value(1000.0),
        dueDate: Value(now.subtract(const Duration(days: 5))),
        status: const Value('partial'),
        academicMonth: const Value(1),
        academicTerm: const Value('Term 1'),
        notes: const Value('Partial payment by parent'),
      ),
    );
    await db.insertFeePayment(
      FeePaymentsCompanion(
        studentFeeId: Value(f6Id),
        studentId: Value(student2.id),
        academicYearId: Value(yearId),
        receiptNumber: const Value('REC-2026-0005'),
        amount: const Value(1000.0),
        paymentDate: Value(now.subtract(const Duration(days: 4))),
        paymentMethod: const Value('Khalti'),
        referenceNumber: const Value('KHALTI-771234'),
        remarks: const Value('Khalti app payment'),
        receivedBy: const Value('Online System'),
      ),
    );

    // Fee 7: Jestha Tuition Fee (2,500) -> 0 paid (Pending)
    await db.insertStudentFee(
      StudentFeesCompanion(
        studentId: Value(student2.id),
        academicYearId: Value(yearId),
        feeCategoryId: Value(tuitionCatId),
        title: const Value('Jestha Tuition Fee'),
        totalAmount: const Value(2500.0),
        discountAmount: const Value(0.0),
        paidAmount: const Value(0.0),
        dueDate: Value(now.add(const Duration(days: 10))),
        status: const Value('pending'),
        academicMonth: const Value(2),
        academicTerm: const Value('Term 1'),
      ),
    );

    // Student 3 (Pooja Thapa):
    // Fee 8: Baishakh Tuition Fee with 500 Merit Discount -> 2,500 total, 500 discount, paid 2,000 (Status: paid)
    final f8Id = await db.insertStudentFee(
      StudentFeesCompanion(
        studentId: Value(student3.id),
        academicYearId: Value(yearId),
        feeCategoryId: Value(tuitionCatId),
        title: const Value('Baishakh Tuition Fee (Merit Discount)'),
        totalAmount: const Value(2500.0),
        discountAmount: const Value(500.0),
        paidAmount: const Value(2000.0),
        dueDate: Value(now.subtract(const Duration(days: 18))),
        status: const Value('paid'),
        academicMonth: const Value(1),
        academicTerm: const Value('Term 1'),
        notes: const Value('20% Academic scholarship discount applied'),
      ),
    );
    await db.insertFeePayment(
      FeePaymentsCompanion(
        studentFeeId: Value(f8Id),
        studentId: Value(student3.id),
        academicYearId: Value(yearId),
        receiptNumber: const Value('REC-2026-0006'),
        amount: const Value(2000.0),
        paymentDate: Value(now.subtract(const Duration(days: 18))),
        paymentMethod: const Value('Cash'),
        referenceNumber: const Value('CASH-002'),
        remarks: const Value('Paid at school cashier desk'),
        receivedBy: const Value('Accountant'),
      ),
    );

    // Fee 9: 1st Term Exam Fee (1,000) -> 0 paid (Pending)
    await db.insertStudentFee(
      StudentFeesCompanion(
        studentId: Value(student3.id),
        academicYearId: Value(yearId),
        feeCategoryId: Value(examCatId),
        title: const Value('1st Term Examination Fee'),
        totalAmount: const Value(1000.0),
        discountAmount: const Value(0.0),
        paidAmount: const Value(0.0),
        dueDate: Value(now.add(const Duration(days: 5))),
        status: const Value('pending'),
        academicTerm: const Value('Term 1'),
      ),
    );
  }

  /// Seeds sample exams and class exam subject schedules
  static Future<void> seedExams(AppDatabase db) async {
    final existingExams = await db.getAllExamsWithDetails();
    if (existingExams.isNotEmpty) return;

    final academicYear =
        await db.getCurrentAcademicYear() ??
        (await db.getAllAcademicYears()).firstOrNull;
    if (academicYear == null) return;

    final classes = await db.getAllClassesWithSections();
    final subjects = await db.getAllSubjects();
    if (classes.isEmpty || subjects.isEmpty) return;

    final now = DateTime.now();
    final yearId = academicYear.id;

    // Exam 1: First Terminal Exam (Upcoming / Scheduled)
    final exam1StartDate = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(const Duration(days: 10));
    final exam1EndDate = exam1StartDate.add(const Duration(days: 10));

    final exam1Id = await db.insertExam(
      ExamsCompanion(
        name: const Value('First Terminal Examination 2083'),
        category: const Value('Terminal Exam 1'),
        academicYearId: Value(yearId),
        startDate: Value(exam1StartDate),
        endDate: Value(exam1EndDate),
        description: const Value(
          'First comprehensive terminal examination covering Quarter 1 syllabus.',
        ),
        status: const Value('Scheduled'),
      ),
    );

    // Schedule subjects for Class 10 (or first class)
    final class10 = classes.firstWhere(
      (c) => c.name.contains('10'),
      orElse: () => classes.first,
    );

    final coreSubjects = subjects.where((s) => !s.isOptional).take(6).toList();
    if (coreSubjects.isEmpty) {
      coreSubjects.addAll(subjects.take(5));
    }

    for (int i = 0; i < coreSubjects.length; i++) {
      final sub = coreSubjects[i];
      final paperDate = exam1StartDate.add(Duration(days: i));
      await db.insertExamSchedule(
        ExamSchedulesCompanion(
          examId: Value(exam1Id),
          academicYearId: Value(yearId),
          classId: Value(class10.id),
          subjectId: Value(sub.id),
          examDate: Value(paperDate),
          startTime: const Value('10:00 AM'),
          endTime: const Value('01:00 PM'),
          fullMarks: Value(sub.fullMarks),
          passMarks: Value(sub.passMarks),
          theoryMarks: Value(sub.theoryMarks),
          practicalMarks: Value(sub.practicalMarks),
          roomNumber: Value('Hall ${101 + (i % 3)}'),
          remarks: const Value('Admit card mandatory. Arrive 15 mins before.'),
          orderIndex: Value(i + 1),
        ),
      );
    }

    // Schedule subjects for Class 9 (if available)
    final class9 = classes.where((c) => c.name.contains('9')).firstOrNull;
    if (class9 != null && class9.id != class10.id) {
      for (int i = 0; i < coreSubjects.length; i++) {
        final sub = coreSubjects[i];
        final paperDate = exam1StartDate.add(Duration(days: i));
        await db.insertExamSchedule(
          ExamSchedulesCompanion(
            examId: Value(exam1Id),
            academicYearId: Value(yearId),
            classId: Value(class9.id),
            subjectId: Value(sub.id),
            examDate: Value(paperDate),
            startTime: const Value('10:00 AM'),
            endTime: const Value('01:00 PM'),
            fullMarks: Value(sub.fullMarks),
            passMarks: Value(sub.passMarks),
            theoryMarks: Value(sub.theoryMarks),
            practicalMarks: Value(sub.practicalMarks),
            roomNumber: Value('Hall ${201 + (i % 2)}'),
            remarks: const Value('Admit card required.'),
            orderIndex: Value(i + 1),
          ),
        );
      }
    }

    // Exam 2: Class Test 1 (Completed)
    final exam2StartDate = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 35));
    final exam2EndDate = exam2StartDate.add(const Duration(days: 4));

    final exam2Id = await db.insertExam(
      ExamsCompanion(
        name: const Value('Class Test 1 - Monthly Assessment'),
        category: const Value('Class Test 1'),
        academicYearId: Value(yearId),
        startDate: Value(exam2StartDate),
        endDate: Value(exam2EndDate),
        description: const Value('First 25-mark monthly formative class test.'),
        status: const Value('Completed'),
      ),
    );

    for (int i = 0; i < coreSubjects.take(3).length; i++) {
      final sub = coreSubjects[i];
      final paperDate = exam2StartDate.add(Duration(days: i));
      await db.insertExamSchedule(
        ExamSchedulesCompanion(
          examId: Value(exam2Id),
          academicYearId: Value(yearId),
          classId: Value(class10.id),
          subjectId: Value(sub.id),
          examDate: Value(paperDate),
          startTime: const Value('08:00 AM'),
          endTime: const Value('09:00 AM'),
          fullMarks: const Value(25),
          passMarks: const Value(10),
          theoryMarks: const Value(25),
          practicalMarks: const Value(0),
          roomNumber: const Value('Room 10A'),
          remarks: const Value('Conducted during 1st period.'),
          orderIndex: Value(i + 1),
        ),
      );
    }

    // Exam 3: Half Yearly Exam (Draft / Upcoming later)
    final exam3StartDate = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(const Duration(days: 85));
    final exam3EndDate = exam3StartDate.add(const Duration(days: 12));

    await db.insertExam(
      ExamsCompanion(
        name: const Value('Half Yearly Examination 2083'),
        category: const Value('Half Yearly'),
        academicYearId: Value(yearId),
        startDate: Value(exam3StartDate),
        endDate: Value(exam3EndDate),
        description: const Value('Mid-term comprehensive annual assessment.'),
        status: const Value('Draft'),
      ),
    );
  }

  /// Seeds realistic sample exam results and marks for students
  static Future<void> seedExamResults(AppDatabase db) async {
    final existingResults = await db.select(db.examResults).get();
    if (existingResults.isNotEmpty) return;

    final exams = await db.getAllExamsWithDetails();
    if (exams.isEmpty) return;

    final exam = exams.firstWhere(
      (e) => e.scheduleCount > 0,
      orElse: () => exams.first,
    );

    final schedules = await db.getAllExamSchedulesWithDetails(examId: exam.id);
    if (schedules.isEmpty) return;

    // Target Class 10 (or first scheduled class)
    final classId = schedules.first.classId;
    final classSchedules =
        schedules.where((s) => s.classId == classId).toList();

    // Fetch enrolled students for this class
    final historyQuery = db.select(db.students).join([
      innerJoin(
        db.studentAcademicHistories,
        db.studentAcademicHistories.studentId.equalsExp(db.students.id),
      ),
    ])..where(
      db.studentAcademicHistories.classId.equals(classId) &
          db.studentAcademicHistories.academicYearId.equals(
            exam.academicYearId,
          ) &
          db.studentAcademicHistories.status.equalsValue(AcademicStatus.active),
    );

    final studentRows = await historyQuery.get();
    final students = studentRows.map((r) => r.readTable(db.students)).toList();
    if (students.isEmpty) return;

    final now = DateTime.now();
    final resultCompanions = <ExamResultsCompanion>[];

    for (int sIdx = 0; sIdx < students.length; sIdx++) {
      final student = students[sIdx];
      final sectionId =
          studentRows[sIdx].readTable(db.studentAcademicHistories).sectionId;

      for (int i = 0; i < classSchedules.length; i++) {
        final sched = classSchedules[i];
        final sub = sched.subject;
        final hasPractical = sub.subjectType != SubjectType.theory;

        final theoryFull =
            (sched.theoryMarks ??
                    (hasPractical ? (sub.theoryMarks ?? 75) : sched.fullMarks))
                .toDouble();
        final theoryPass =
            (hasPractical
                    ? (sub.theoryMarks != null
                        ? (sub.theoryMarks! * 0.4).round()
                        : 30)
                    : sched.passMarks)
                .toDouble();
        final practicalFull =
            hasPractical
                ? (sched.practicalMarks ?? sub.practicalMarks ?? 25).toDouble()
                : null;
        final practicalPass =
            hasPractical ? (practicalFull! * 0.4).toDouble() : null;

        // Realistic score variation
        final basePct = 0.72 + ((sIdx * 7 + i * 5) % 25) / 100.0;
        final theoryObtained = (theoryFull * basePct).clamp(0.0, theoryFull);
        final practicalObtained =
            practicalFull != null
                ? (practicalFull * (basePct + 0.05).clamp(0.0, 1.0)).clamp(
                  0.0,
                  practicalFull,
                )
                : null;

        final calc = ExamGradingUtils.calculateSubjectResult(
          theoryMarksObtained: double.parse(theoryObtained.toStringAsFixed(1)),
          theoryFullMarks: theoryFull,
          theoryPassMarks: theoryPass,
          practicalMarksObtained:
              practicalObtained != null
                  ? double.parse(practicalObtained.toStringAsFixed(1))
                  : null,
          practicalFullMarks: practicalFull,
          practicalPassMarks: practicalPass,
        );

        resultCompanions.add(
          ExamResultsCompanion(
            examId: Value(exam.id),
            academicYearId: Value(exam.academicYearId),
            classId: Value(classId),
            sectionId: Value(sectionId),
            studentId: Value(student.id),
            subjectId: Value(sub.id),
            examScheduleId: Value(sched.id),
            theoryMarksObtained: Value(calc.theoryMarksObtained),
            theoryFullMarks: Value(calc.theoryFullMarks),
            theoryPassMarks: Value(calc.theoryPassMarks),
            practicalMarksObtained: Value(calc.practicalMarksObtained),
            practicalFullMarks: Value(calc.practicalFullMarks),
            practicalPassMarks: Value(calc.practicalPassMarks),
            totalMarksObtained: Value(calc.totalMarksObtained),
            totalFullMarks: Value(calc.totalFullMarks),
            totalPassMarks: Value(calc.totalPassMarks),
            percentage: Value(calc.percentage),
            gradePoint: Value(calc.gradePoint),
            letterGrade: Value(calc.letterGrade),
            isPassed: Value(calc.isPassed),
            isAbsent: const Value(false),
            remarks: const Value('Evaluated'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
      }
    }

    await db.batchUpsertExamResults(resultCompanions);

    // Compute and store summaries
    final studentMap = <int, List<ExamResultsCompanion>>{};
    for (final r in resultCompanions) {
      studentMap.putIfAbsent(r.studentId.value, () => []).add(r);
    }

    final summaryCompanions = <ExamResultSummariesCompanion>[];
    studentMap.forEach((studentId, records) {
      final subjectResults =
          records.map((r) {
            return SubjectGradeResult(
              theoryMarksObtained: r.theoryMarksObtained.value,
              theoryFullMarks: r.theoryFullMarks.value,
              theoryPassMarks: r.theoryPassMarks.value,
              practicalMarksObtained: r.practicalMarksObtained.value,
              practicalFullMarks: r.practicalFullMarks.value,
              practicalPassMarks: r.practicalPassMarks.value,
              totalMarksObtained: r.totalMarksObtained.value,
              totalFullMarks: r.totalFullMarks.value,
              totalPassMarks: r.totalPassMarks.value,
              percentage: r.percentage.value,
              gradePoint: r.gradePoint.value,
              letterGrade: r.letterGrade.value,
              description: '',
              isPassed: r.isPassed.value,
              isAbsent: r.isAbsent.value,
              color:
                  ExamGradingUtils.getGradeFromPercentage(
                    r.percentage.value,
                  ).color,
            );
          }).toList();

      final overall = ExamGradingUtils.calculateOverallResult(subjectResults);
      final sectionId = records.first.sectionId.value;

      summaryCompanions.add(
        ExamResultSummariesCompanion(
          examId: Value(exam.id),
          academicYearId: Value(exam.academicYearId),
          classId: Value(classId),
          sectionId: Value(sectionId),
          studentId: Value(studentId),
          totalMarksObtained: Value(overall.totalMarksObtained),
          totalFullMarks: Value(overall.totalFullMarks),
          overallPercentage: Value(overall.percentage),
          overallGpa: Value(overall.gpa),
          overallGrade: Value(overall.letterGrade),
          totalSubjects: Value(overall.totalSubjects),
          passedSubjects: Value(overall.passedSubjects),
          failedSubjects: Value(overall.failedSubjects),
          isPassed: Value(overall.isPassed),
          updatedAt: Value(now),
        ),
      );
    });

    // Assign rank in class
    summaryCompanions.sort((a, b) {
      final gpaCompare = b.overallGpa.value.compareTo(a.overallGpa.value);
      if (gpaCompare != 0) return gpaCompare;
      return b.overallPercentage.value.compareTo(a.overallPercentage.value);
    });

    final rankedSummaries = <ExamResultSummariesCompanion>[];
    for (int i = 0; i < summaryCompanions.length; i++) {
      final s = summaryCompanions[i];
      rankedSummaries.add(
        s.copyWith(rankInClass: Value(s.isPassed.value ? (i + 1) : null)),
      );
    }

    await db.batchUpsertExamResultSummaries(rankedSummaries);
  }

  /// Seeds realistic initial attendance for students and employees
  static Future<void> seedAttendance(AppDatabase db) async {
    final currentYear = await db.getCurrentAcademicYear();
    if (currentYear == null) return;

    final students = await db.getAllStudents();
    final employees = await db.getAllEmployees();
    final now = DateTime.now();

    final studentAttendances = <StudentAttendancesCompanion>[];
    final employeeAttendances = <EmployeeAttendancesCompanion>[];

    // Seed past 7 school days (skipping Saturdays if applicable, or seeding 5 days)
    for (int dayOffset = 0; dayOffset <= 6; dayOffset++) {
      final date = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: dayOffset));
      // In Nepal, Saturday (weekday == 6) is a weekend holiday
      if (date.weekday == DateTime.saturday) continue;

      // Seed student attendances
      for (final student in students) {
        if (student.classId == null) continue;

        // Pseudo-random distribution based on student id and date
        final hash = (student.id * 31 + date.day * 17 + dayOffset * 7) % 100;
        AttendanceStatus status;
        String? remarks;

        if (hash < 82) {
          status = AttendanceStatus.present;
        } else if (hash < 90) {
          status = AttendanceStatus.late;
          remarks = 'Late by 15 mins';
        } else if (hash < 96) {
          status = AttendanceStatus.absent;
          remarks = 'Unexcused absence';
        } else {
          status = AttendanceStatus.excused;
          remarks = 'Sick leave requested';
        }

        studentAttendances.add(
          StudentAttendancesCompanion(
            studentId: Value(student.id),
            academicYearId: Value(currentYear.id),
            classId: Value(student.classId!),
            sectionId: Value(student.sectionId),
            date: Value(date),
            status: Value(status),
            remarks: Value(remarks),
            createdAt: Value(now),
          ),
        );
      }

      // Seed employee attendances
      for (final emp in employees) {
        final hash = (emp.id * 23 + date.day * 19 + dayOffset * 11) % 100;
        AttendanceStatus status;
        String? checkIn;
        String? checkOut;
        String? remarks;

        if (hash < 85) {
          status = AttendanceStatus.present;
          final minute = (emp.id * 7) % 25;
          checkIn = '09:${minute.toString().padLeft(2, '0')} AM';
          checkOut = '04:30 PM';
        } else if (hash < 92) {
          status = AttendanceStatus.late;
          checkIn = '10:05 AM';
          checkOut = '04:30 PM';
          remarks = 'Traffic delay';
        } else if (hash < 97) {
          status = AttendanceStatus.onLeave;
          remarks = 'Casual leave approved';
        } else {
          status = AttendanceStatus.absent;
          remarks = 'Absent without notice';
        }

        employeeAttendances.add(
          EmployeeAttendancesCompanion(
            employeeId: Value(emp.id),
            date: Value(date),
            status: Value(status),
            checkInTime: Value(checkIn),
            checkOutTime: Value(checkOut),
            remarks: Value(remarks),
            createdAt: Value(now),
          ),
        );
      }
    }

    if (studentAttendances.isNotEmpty) {
      await db.batchUpsertStudentAttendances(studentAttendances);
    }
    if (employeeAttendances.isNotEmpty) {
      await db.batchUpsertEmployeeAttendances(employeeAttendances);
    }
  }
}
