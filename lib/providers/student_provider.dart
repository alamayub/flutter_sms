import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../config/enums.dart';
import '../data/app_database.dart';
import '../services/student_service.dart';
import 'academic_year_provider.dart';
import 'database_provider.dart';

/// Provider for StudentService
final studentServiceProvider = Provider<StudentService>((ref) {
  final db = ref.watch(databaseProvider);
  return StudentService(db);
});

/// Selected Academic Year ID filter for student list (null = active academic year)
class SelectedStudentYearNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void setYear(int? yearId) => state = yearId;
}

final selectedStudentYearFilterProvider =
    NotifierProvider<SelectedStudentYearNotifier, int?>(
      SelectedStudentYearNotifier.new,
    );

/// Selected Class ID filter for student list (null = all classes)
class SelectedStudentClassNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void setClass(int? classId) => state = classId;
}

final selectedStudentClassFilterProvider =
    NotifierProvider<SelectedStudentClassNotifier, int?>(
      SelectedStudentClassNotifier.new,
    );

/// Selected Section ID filter for student list (null = all sections)
class SelectedStudentSectionNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void setSection(int? sectionId) => state = sectionId;
}

final selectedStudentSectionFilterProvider =
    NotifierProvider<SelectedStudentSectionNotifier, int?>(
      SelectedStudentSectionNotifier.new,
    );

/// Search query filter for students
class StudentSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) => state = query;
}

final studentSearchQueryProvider =
    NotifierProvider<StudentSearchQueryNotifier, String>(
      StudentSearchQueryNotifier.new,
    );

/// Stream provider for students matching current filters
final studentsListStreamProvider = StreamProvider<List<StudentWithDetails>>((
  ref,
) {
  final service = ref.watch(studentServiceProvider);
  final explicitYearId = ref.watch(selectedStudentYearFilterProvider);
  final activeYearAsync = ref.watch(activeAcademicYearProvider);
  final classId = ref.watch(selectedStudentClassFilterProvider);
  final sectionId = ref.watch(selectedStudentSectionFilterProvider);
  final search = ref.watch(studentSearchQueryProvider);

  // Default to currently active academic year if no year explicitly selected
  final effectiveYearId = explicitYearId ?? activeYearAsync.value?.id;

  return service.watchStudents(
    academicYearId: effectiveYearId,
    classId: classId,
    sectionId: sectionId,
    search: search.trim().isEmpty ? null : search.trim(),
  );
});

/// Stream provider for a single student's multi-year academic history timeline
final studentAcademicHistoryProvider =
    StreamProvider.family<List<StudentAcademicHistoryWithDetails>, int>((
      ref,
      studentId,
    ) {
      final service = ref.watch(studentServiceProvider);
      return service.watchStudentAcademicHistory(studentId);
    });

/// Stream provider for contacts linked to a specific student
final studentContactsStreamProvider = StreamProvider.family<List<Contact>, int>(
  (ref, studentId) {
    final db = ref.watch(databaseProvider);
    return db.watchContactsBySource(ContactSourceType.student, studentId);
  },
);

/// Async mutation controller for Student actions
class StudentController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<int?> admitStudent({
    required String name,
    required String gender,
    required int academicYearId,
    required int classId,
    required int sectionId,
    int? rollNumber,
    DateTime? admissionDate,
    DateTime? dateOfBirth,
    String? bloodGroup,
    String? address,
    String? phone,
    String? email,
    String? photoPath,
    String? emergencyContactName,
    String? emergencyContactPhone,
    String? emergencyContactRelation,
    String? emergencyContactOccupation,
    String? guardianName,
    String? guardianPhone,
    String? guardianRelation,
    String? guardianOccupation,
    bool hasTransport = false,
    bool hasHostel = false,
    bool hasLibrary = false,
  }) async {
    state = const AsyncValue.loading();
    int? createdId;
    state = await AsyncValue.guard(() async {
      final service = ref.read(studentServiceProvider);
      createdId = await service.admitStudent(
        name: name,
        gender: gender,
        academicYearId: academicYearId,
        classId: classId,
        sectionId: sectionId,
        rollNumber: rollNumber,
        admissionDate: admissionDate,
        dateOfBirth: dateOfBirth,
        bloodGroup: bloodGroup,
        address: address,
        phone: phone,
        email: email,
        photoPath: photoPath,
        emergencyContactName: emergencyContactName,
        emergencyContactPhone: emergencyContactPhone,
        emergencyContactRelation: emergencyContactRelation,
        emergencyContactOccupation: emergencyContactOccupation,
        guardianName: guardianName,
        guardianPhone: guardianPhone,
        guardianRelation: guardianRelation,
        guardianOccupation: guardianOccupation,
        hasTransport: hasTransport,
        hasHostel: hasHostel,
        hasLibrary: hasLibrary,
      );
    });
    return createdId;
  }

  Future<bool> updateStudent({
    required Student student,
    required int academicYearId,
    required int classId,
    required int sectionId,
    int? rollNumber,
    String? name,
    String? gender,
    DateTime? dateOfBirth,
    String? bloodGroup,
    String? address,
    String? phone,
    String? email,
    String? photoPath,
    String? emergencyContactName,
    String? emergencyContactPhone,
    String? emergencyContactRelation,
    String? emergencyContactOccupation,
    String? guardianName,
    String? guardianPhone,
    String? guardianRelation,
    String? guardianOccupation,
    bool? hasTransport,
    bool? hasHostel,
    bool? hasLibrary,
    bool? isActive,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(studentServiceProvider);
      await service.updateStudent(
        student: student,
        academicYearId: academicYearId,
        classId: classId,
        sectionId: sectionId,
        rollNumber: rollNumber,
        name: name,
        gender: gender,
        dateOfBirth: dateOfBirth,
        bloodGroup: bloodGroup,
        address: address,
        phone: phone,
        email: email,
        photoPath: photoPath,
        emergencyContactName: emergencyContactName,
        emergencyContactPhone: emergencyContactPhone,
        emergencyContactRelation: emergencyContactRelation,
        emergencyContactOccupation: emergencyContactOccupation,
        guardianName: guardianName,
        guardianPhone: guardianPhone,
        guardianRelation: guardianRelation,
        guardianOccupation: guardianOccupation,
        hasTransport: hasTransport,
        hasHostel: hasHostel,
        hasLibrary: hasLibrary,
        isActive: isActive,
      );
    });
    return !state.hasError;
  }

  Future<bool> deleteStudent(int id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(studentServiceProvider);
      await service.deleteStudent(id);
    });
    return !state.hasError;
  }

  Future<bool> promoteStudents({
    required int sourceAcademicYearId,
    required int targetAcademicYearId,
    required List<StudentPromotionItem> items,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(studentServiceProvider);
      await service.promoteStudents(
        sourceAcademicYearId: sourceAcademicYearId,
        targetAcademicYearId: targetAcademicYearId,
        items: items,
      );
    });
    return !state.hasError;
  }
}

final studentControllerProvider =
    AsyncNotifierProvider<StudentController, void>(StudentController.new);
