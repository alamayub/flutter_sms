import '../config/enums.dart';
import '../data/app_database.dart';
import 'employee_service.dart';

class TeacherService {
  final EmployeeService _employeeService;

  TeacherService(AppDatabase db) : _employeeService = EmployeeService(db);

  Stream<List<Employee>> watchAllTeachers() {
    return _employeeService.watchEmployees(
      type: EmployeeType.teacher,
      isActive: true,
    );
  }

  Future<List<Employee>> getAllTeachers() {
    return _employeeService.getAllEmployees(
      type: EmployeeType.teacher,
      isActive: true,
    );
  }

  Future<Employee?> getTeacherById(int id) =>
      _employeeService.getEmployeeById(id);

  Future<int> createTeacher({
    required String name,
    String? email,
    String? phone,
    String? designation,
    DateTime? dateOfBirth,
    String? gender,
    String? bloodGroup,
    String? address,
    String? qualification,
    String? department,
  }) {
    return _employeeService.createEmployee(
      name: name,
      employeeType: EmployeeType.teacher,
      designation: designation ?? 'Teacher',
      email: email,
      phone: phone,
      dateOfBirth: dateOfBirth,
      gender: gender,
      bloodGroup: bloodGroup,
      address: address,
      qualification: qualification,
      department: department ?? 'Academic',
    );
  }

  Future<bool> updateTeacher({
    required int id,
    required String name,
    String? email,
    String? phone,
    String? designation,
    DateTime? dateOfBirth,
    String? gender,
    String? bloodGroup,
    String? address,
    String? qualification,
    String? department,
    bool? isActive,
  }) {
    return _employeeService.updateEmployee(
      id: id,
      name: name,
      employeeType: EmployeeType.teacher,
      designation: designation ?? 'Teacher',
      email: email,
      phone: phone,
      dateOfBirth: dateOfBirth,
      gender: gender,
      bloodGroup: bloodGroup,
      address: address,
      qualification: qualification,
      department: department ?? 'Academic',
      isActive: isActive,
    );
  }

  Future<int> deleteTeacher(int id) => _employeeService.deleteEmployee(id);
}
