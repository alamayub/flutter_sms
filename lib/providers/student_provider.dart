import 'package:hooks_riverpod/hooks_riverpod.dart'
    show Ref, StateNotifier, StateNotifierProvider, StateProvider;

import '../models/student_model.dart';
import '../services/student_service.dart' show studentServiceProvider;
import '../states/student_state.dart';

final searchQueryProvider = StateProvider<String>((ref) => '');

final studentProvider = StateNotifierProvider<StudentNotifier, StudentState>((
  ref,
) {
  return StudentNotifier(ref);
});

class StudentNotifier extends StateNotifier<StudentState> {
  final Ref ref;

  StudentNotifier(this.ref) : super(const StudentState()) {
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    try {
      state = state.copyWith(loading: true);
      final students = await ref.read(studentServiceProvider).getAllStudents();
      state = state.copyWith(students: students);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    } finally {
      state = state.copyWith(loading: false);
    }
  }

  Future<void> addStudent(StudentModel student) async {
    try {
      state = state.copyWith(loading: true);
      await ref.read(studentServiceProvider).addStudent(student);
      _loadStudents();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    } finally {
      state = state.copyWith(loading: false);
    }
  }

  Future<void> updateStudent(StudentModel student) async {
    try {
      state = state.copyWith(loading: true);
      await ref.read(studentServiceProvider).updateStudent(student);
      _loadStudents();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    } finally {
      state = state.copyWith(loading: false);
    }
  }

  Future<void> deleteStudent(StudentModel student) async {
    try {
      state = state.copyWith(loading: true);
      await ref.read(studentServiceProvider).deleteStudent(student);
      _loadStudents();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    } finally {
      state = state.copyWith(loading: false);
    }
  }
}
