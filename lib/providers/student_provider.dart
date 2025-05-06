import 'package:hooks_riverpod/hooks_riverpod.dart'
    show FutureProvider, Ref, StateNotifier, StateNotifierProvider;

import '../models/student_model.dart';
import '../services/student_service.dart' show studentServiceProvider;
import 'global_provider.dart' show globalProvider;

final studentListProvider = FutureProvider<List<StudentModel>>((ref) {
  return ref.read(studentServiceProvider).getAllStudents();
});

final studentProvider = StateNotifierProvider<StudentNotifier, void>((ref) {
  return StudentNotifier(ref);
});

class StudentNotifier extends StateNotifier<void> {
  final Ref ref;

  StudentNotifier(this.ref) : super(null);

  Future<void> addStudent(StudentModel student) async {
    try {
      ref.read(globalProvider.notifier).setLoading(true);
      await ref.read(studentServiceProvider).addStudent(student);
    } catch (e) {
      ref.read(globalProvider.notifier).setMessage(e.toString());
    } finally {
      ref.read(globalProvider.notifier).setLoading(false);
      ref.invalidate(studentListProvider);
    }
  }

  Future<void> updateStudent(StudentModel student) async {
    try {
      ref.read(globalProvider.notifier).setLoading(true);
      await ref.read(studentServiceProvider).updateStudent(student);
    } catch (e) {
      ref.read(globalProvider.notifier).setMessage(e.toString());
    } finally {
      ref.read(globalProvider.notifier).setLoading(false);
      ref.invalidate(studentListProvider);
    }
  }

  Future<void> deleteStudent(StudentModel student) async {
    try {
      ref.read(globalProvider.notifier).setLoading(true);
      await ref.read(studentServiceProvider).deleteStudent(student);
    } catch (e) {
      ref.read(globalProvider.notifier).setMessage(e.toString());
    } finally {
      ref.read(globalProvider.notifier).setLoading(false);
      ref.invalidate(studentListProvider);
    }
  }
}
