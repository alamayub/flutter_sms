import 'package:flutter/foundation.dart' show immutable, listEquals;

import '../modesl/student_model.dart';

@immutable
class StudentState {
  final bool loading;
  final String? error;
  final List<StudentModel> students;
  final String? grade;

  const StudentState({
    this.loading = false,
    this.error,
    this.students = const [],
    this.grade,
  });

  StudentState copyWith({
    bool? loading,
    String? error,
    List<StudentModel>? students,
    String? grade,
  }) => StudentState(
    loading: loading ?? this.loading,
    error: error ?? this.error,
    students: students ?? this.students,
    grade: grade ?? this.grade,
  );

  @override
  bool operator ==(covariant StudentState other) =>
      identical(this, other) ||
      (loading == other.loading &&
          error == other.error &&
          listEquals(students, other.students) &&
          grade == other.grade);

  @override
  int get hashCode => Object.hash(loading, error, students, grade);
}
