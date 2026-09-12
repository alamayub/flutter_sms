import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../config/enums.dart';
import '../data/app_database.dart';
import '../services/employee_service.dart';
import 'database_provider.dart';

/// Service provider for EmployeeService
final employeeServiceProvider = Provider<EmployeeService>((ref) {
  final db = ref.watch(databaseProvider);
  return EmployeeService(db);
});

/// Filter state for selected employee type (null = All)
class SelectedEmployeeTypeFilterNotifier extends Notifier<EmployeeType?> {
  @override
  EmployeeType? build() => null;

  void setType(EmployeeType? type) => state = type;
}

final selectedEmployeeTypeFilterProvider =
    NotifierProvider<SelectedEmployeeTypeFilterNotifier, EmployeeType?>(
      SelectedEmployeeTypeFilterNotifier.new,
    );

/// Filter state for search query
class EmployeeSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) => state = query;
}

final employeeSearchQueryProvider =
    NotifierProvider<EmployeeSearchQueryNotifier, String>(
      EmployeeSearchQueryNotifier.new,
    );

/// Stream provider for all employees filtered by type and search
final employeesStreamProvider = StreamProvider<List<Employee>>((ref) {
  final service = ref.watch(employeeServiceProvider);
  final type = ref.watch(selectedEmployeeTypeFilterProvider);
  final query = ref.watch(employeeSearchQueryProvider);

  return service.watchEmployees(
    type: type,
    searchQuery: query.isEmpty ? null : query,
  );
});

/// Filter state for teacher search query
class TeacherSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) => state = query;
}

final teacherSearchQueryProvider =
    NotifierProvider<TeacherSearchQueryNotifier, String>(
      TeacherSearchQueryNotifier.new,
    );

/// Filter state for staff search query
class StaffSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) => state = query;
}

final staffSearchQueryProvider =
    NotifierProvider<StaffSearchQueryNotifier, String>(
      StaffSearchQueryNotifier.new,
    );

/// Stream provider specifically for teaching faculty
final teachersStreamProvider = StreamProvider<List<Employee>>((ref) {
  final service = ref.watch(employeeServiceProvider);
  final query = ref.watch(teacherSearchQueryProvider);

  return service.watchEmployees(
    type: EmployeeType.teacher,
    searchQuery: query.isEmpty ? null : query,
  );
});

/// Stream provider specifically for non-teaching staff
final staffStreamProvider = StreamProvider<List<Employee>>((ref) {
  final service = ref.watch(employeeServiceProvider);
  final query = ref.watch(staffSearchQueryProvider);

  return service.watchEmployees(
    type: EmployeeType.staff,
    searchQuery: query.isEmpty ? null : query,
  );
});

/// Stream provider for all active employees (unfiltered for dropdowns)
final allEmployeesStreamProvider = StreamProvider<List<Employee>>((ref) {
  final service = ref.watch(employeeServiceProvider);
  return service.watchEmployees();
});

/// Controller for creating, updating, and deleting employees
class EmployeeController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> createEmployee({
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
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(employeeServiceProvider);
      await service.createEmployee(
        name: name,
        employeeType: employeeType,
        designation: designation,
        employeeCode: employeeCode,
        email: email,
        phone: phone,
        photoPath: photoPath,
        emergencyContactName: emergencyContactName,
        emergencyContactPhone: emergencyContactPhone,
        emergencyContactRelation: emergencyContactRelation,
        dateOfBirth: dateOfBirth,
        gender: gender,
        bloodGroup: bloodGroup,
        maritalStatus: maritalStatus,
        address: address,
        qualification: qualification,
        department: department,
        joiningDate: joiningDate,
        basicSalary: basicSalary,
        isActive: isActive,
      );
    });
  }

  Future<void> updateEmployee({
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
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(employeeServiceProvider);
      await service.updateEmployee(
        id: id,
        name: name,
        employeeType: employeeType,
        designation: designation,
        employeeCode: employeeCode,
        email: email,
        phone: phone,
        photoPath: photoPath,
        emergencyContactName: emergencyContactName,
        emergencyContactPhone: emergencyContactPhone,
        emergencyContactRelation: emergencyContactRelation,
        dateOfBirth: dateOfBirth,
        gender: gender,
        bloodGroup: bloodGroup,
        maritalStatus: maritalStatus,
        address: address,
        qualification: qualification,
        department: department,
        joiningDate: joiningDate,
        basicSalary: basicSalary,
        isActive: isActive,
      );
    });
  }

  Future<void> deleteEmployee(int id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(employeeServiceProvider);
      await service.deleteEmployee(id);
    });
  }
}

final employeeControllerProvider =
    AsyncNotifierProvider<EmployeeController, void>(EmployeeController.new);

/// Future provider for the next auto-generated employee code for a given employee type
final nextEmployeeCodeProvider = FutureProvider.family<String, EmployeeType>((
  ref,
  type,
) async {
  final service = ref.watch(employeeServiceProvider);
  return service.generateNextEmployeeCode(type);
});
