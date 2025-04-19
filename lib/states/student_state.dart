import 'package:flutter/foundation.dart' show immutable, listEquals;

import '../modesl/student_model.dart';

@immutable
class StudentState {
  final bool loading;
  final String? error;
  final List<StudentModel> students;
  final String? search;
  final String? grade;

  const StudentState({
    this.loading = false,
    this.error,
    this.students = const [],
    this.search,
    this.grade,
  });

  StudentState copyWith({
    bool? loading,
    String? error,
    List<StudentModel>? students,
    String? search,
    String? grade,
  }) => StudentState(
    loading: loading ?? this.loading,
    error: error ?? this.error,
    students: students ?? this.students,
    search: search ?? this.search,
    grade: grade ?? this.grade,
  );

  @override
  bool operator ==(covariant StudentState other) =>
      identical(this, other) ||
      (loading == other.loading &&
          error == other.error &&
          listEquals(students, other.students) &&
          search == other.search &&
          grade == other.grade);

  @override
  int get hashCode => Object.hash(loading, error, students, search, grade);
}
