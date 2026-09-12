import 'package:drift/drift.dart';
import '../config/enums.dart';
import '../data/app_database.dart';
import '../utils/validators.dart';

class EmployeeService {
  final AppDatabase _db;

  EmployeeService(this._db);

  /// Watch employees with optional type, search query, and active filters
  Stream<List<Employee>> watchEmployees({
    EmployeeType? type,
    String? searchQuery,
    bool? isActive,
  }) {
    return _db.watchEmployees(
      type: type,
      searchQuery: searchQuery,
      isActive: isActive,
    );
  }

  /// Get all employees with optional filters
  Future<List<Employee>> getAllEmployees({
    EmployeeType? type,
    String? searchQuery,
    bool? isActive,
  }) {
    return _db.getAllEmployees(
      type: type,
      searchQuery: searchQuery,
      isActive: isActive,
    );
  }

  /// Get employee by ID
  Future<Employee?> getEmployeeById(int id) {
    return _db.getEmployeeById(id);
  }

  /// Generates the next sequential employee code based on employee type
  /// Teachers: TCH-001, TCH-002...
  /// Staff: STF-001, STF-002...
  Future<String> generateNextEmployeeCode(EmployeeType type) async {
    final prefix = type == EmployeeType.teacher ? 'TCH' : 'STF';
    final allEmployees = await _db.getAllEmployees(type: type);
    int maxNumber = 0;

    for (final emp in allEmployees) {
      final code = emp.employeeCode;
      if (code != null && code.startsWith('$prefix-')) {
        final numPart = code.substring(prefix.length + 1);
        final parsed = int.tryParse(numPart);
        if (parsed != null && parsed > maxNumber) {
          maxNumber = parsed;
        }
      }
    }

    final nextNumber = maxNumber + 1;
    return '$prefix-${nextNumber.toString().padLeft(3, '0')}';
  }

  /// Create a new employee (teacher or staff)
  Future<int> createEmployee({
    required String name,
    required EmployeeType employeeType,
    required String designation,
    String? employeeCode,
    String? email,
    String? phone,
    String? photoPath,
    String? emergencyContactName,
    String? emergencyContactPhone,
    String? emergencyContactRelation,
    DateTime? dateOfBirth,
    String? gender,
    String? bloodGroup,
    String? maritalStatus,
    String? address,
    String? qualification,
    String? department,
    DateTime? joiningDate,
    double? basicSalary,
    bool isActive = true,
  }) async {
    _validateInputs(
      name: name,
      designation: designation,
      email: email,
      phone: phone,
      emergencyContactPhone: emergencyContactPhone,
      bloodGroup: bloodGroup,
      dateOfBirth: dateOfBirth,
    );

    final resolvedCode =
        (employeeCode != null && employeeCode.trim().isNotEmpty)
            ? employeeCode.trim()
            : await generateNextEmployeeCode(employeeType);

    return _db.insertEmployee(
      EmployeesCompanion(
        name: Value(name.trim()),
        employeeType: Value(employeeType),
        designation: Value(designation.trim()),
        employeeCode: Value(resolvedCode),
        email: Value(email?.trim().isEmpty == true ? null : email?.trim()),
        phone: Value(phone?.trim().isEmpty == true ? null : phone?.trim()),
        photoPath: Value(
          photoPath?.trim().isEmpty == true ? null : photoPath?.trim(),
        ),
        emergencyContactName: Value(
          emergencyContactName?.trim().isEmpty == true
              ? null
              : emergencyContactName?.trim(),
        ),
        emergencyContactPhone: Value(
          emergencyContactPhone?.trim().isEmpty == true
              ? null
              : emergencyContactPhone?.trim(),
        ),
        emergencyContactRelation: Value(
          emergencyContactRelation?.trim().isEmpty == true
              ? null
              : emergencyContactRelation?.trim(),
        ),
        dateOfBirth: Value(dateOfBirth),
        gender: Value(gender?.trim().isEmpty == true ? null : gender?.trim()),
        bloodGroup: Value(
          bloodGroup?.trim().isEmpty == true
              ? null
              : bloodGroup?.trim().toUpperCase(),
        ),
        maritalStatus: Value(
          maritalStatus?.trim().isEmpty == true ? null : maritalStatus?.trim(),
        ),
        address: Value(
          address?.trim().isEmpty == true ? null : address?.trim(),
        ),
        qualification: Value(
          qualification?.trim().isEmpty == true ? null : qualification?.trim(),
        ),
        department: Value(
          department?.trim().isEmpty == true ? null : department?.trim(),
        ),
        joiningDate: Value(joiningDate),
        basicSalary: Value(basicSalary),
        isActive: Value(isActive),
      ),
    );
  }

  /// Update an existing employee
  Future<bool> updateEmployee({
    required int id,
    required String name,
    required EmployeeType employeeType,
    required String designation,
    String? employeeCode,
    String? email,
    String? phone,
    String? photoPath,
    String? emergencyContactName,
    String? emergencyContactPhone,
    String? emergencyContactRelation,
    DateTime? dateOfBirth,
    String? gender,
    String? bloodGroup,
    String? maritalStatus,
    String? address,
    String? qualification,
    String? department,
    DateTime? joiningDate,
    double? basicSalary,
    bool? isActive,
  }) async {
    final existing = await _db.getEmployeeById(id);
    if (existing == null) return false;

    _validateInputs(
      name: name,
      designation: designation,
      email: email,
      phone: phone,
      emergencyContactPhone: emergencyContactPhone,
      bloodGroup: bloodGroup,
      dateOfBirth: dateOfBirth,
    );

    return _db.updateEmployeeEntry(
      existing.copyWith(
        name: name.trim(),
        employeeType: employeeType,
        designation: designation.trim(),
        employeeCode: Value(
          employeeCode?.trim().isEmpty == true
              ? existing.employeeCode
              : employeeCode?.trim(),
        ),
        email: Value(email?.trim().isEmpty == true ? null : email?.trim()),
        phone: Value(phone?.trim().isEmpty == true ? null : phone?.trim()),
        photoPath: Value(
          photoPath?.trim().isEmpty == true ? null : photoPath?.trim(),
        ),
        emergencyContactName: Value(
          emergencyContactName?.trim().isEmpty == true
              ? null
              : emergencyContactName?.trim(),
        ),
        emergencyContactPhone: Value(
          emergencyContactPhone?.trim().isEmpty == true
              ? null
              : emergencyContactPhone?.trim(),
        ),
        emergencyContactRelation: Value(
          emergencyContactRelation?.trim().isEmpty == true
              ? null
              : emergencyContactRelation?.trim(),
        ),
        dateOfBirth: Value(dateOfBirth),
        gender: Value(gender?.trim().isEmpty == true ? null : gender?.trim()),
        bloodGroup: Value(
          bloodGroup?.trim().isEmpty == true
              ? null
              : bloodGroup?.trim().toUpperCase(),
        ),
        maritalStatus: Value(
          maritalStatus?.trim().isEmpty == true ? null : maritalStatus?.trim(),
        ),
        address: Value(
          address?.trim().isEmpty == true ? null : address?.trim(),
        ),
        qualification: Value(
          qualification?.trim().isEmpty == true ? null : qualification?.trim(),
        ),
        department: Value(
          department?.trim().isEmpty == true ? null : department?.trim(),
        ),
        joiningDate: Value(joiningDate),
        basicSalary: Value(basicSalary),
        isActive: isActive ?? existing.isActive,
      ),
    );
  }

  /// Delete an employee
  Future<int> deleteEmployee(int id) {
    return _db.deleteEmployee(id);
  }

  /// Validation logic for employee fields
  void _validateInputs({
    required String name,
    required String designation,
    String? email,
    String? phone,
    String? emergencyContactPhone,
    String? bloodGroup,
    DateTime? dateOfBirth,
  }) {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('Employee name cannot be empty');
    }

    final trimmedDesignation = designation.trim();
    if (trimmedDesignation.isEmpty) {
      throw ArgumentError('Designation cannot be empty');
    }

    if (email != null && email.trim().isNotEmpty) {
      final emailError = Validators.validateEmail(email.trim());
      if (emailError != null) {
        throw ArgumentError(emailError);
      }
    }

    if (phone != null && phone.trim().isNotEmpty) {
      final phoneError = Validators.validatePhone(phone.trim());
      if (phoneError != null) {
        throw ArgumentError(phoneError);
      }
    }

    if (emergencyContactPhone != null &&
        emergencyContactPhone.trim().isNotEmpty) {
      final emergencyPhoneError = Validators.validatePhone(
        emergencyContactPhone.trim(),
      );
      if (emergencyPhoneError != null) {
        throw ArgumentError(emergencyPhoneError);
      }
    }

    if (bloodGroup != null && bloodGroup.trim().isNotEmpty) {
      const validBloodGroups = [
        'A+',
        'A-',
        'B+',
        'B-',
        'O+',
        'O-',
        'AB+',
        'AB-',
      ];
      final bg = bloodGroup.trim().toUpperCase();
      if (!validBloodGroups.contains(bg)) {
        throw ArgumentError(
          'Invalid blood group: $bloodGroup. Valid options: ${validBloodGroups.join(", ")}',
        );
      }
    }

    if (dateOfBirth != null) {
      if (dateOfBirth.isAfter(DateTime.now())) {
        throw ArgumentError('Date of birth cannot be in the future');
      }
    }
  }
}
