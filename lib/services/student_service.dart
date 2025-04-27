import 'package:flutter/foundation.dart' show immutable;
import 'package:hooks_riverpod/hooks_riverpod.dart' show Provider;
import 'package:isar/isar.dart' show Isar, QueryExecute;

import '../models/student_model.dart';
import 'isar_service.dart' show isarServiceProvider;

@immutable
class StudentService {
  final Isar isar;
  const StudentService(this.isar);

  // get all students
  Future<List<StudentModel>> getAllStudents() async {
    try {
      final students = await isar.studentModels.where().findAll();
      return students;
    } catch (e) {
      throw e.toString();
    }
  }

  // add student
  Future<void> addStudent(StudentModel student) async {
    try {
      await isar.writeTxn(() async {
        await isar.studentModels.put(student);
      });
    } catch (e) {
      throw e.toString();
    }
  }

  // update student
  Future<void> updateStudent(StudentModel student) async {
    try {
      await isar.writeTxn(() async {
        await isar.studentModels.put(student);
      });
    } catch (e) {
      throw e.toString();
    }
  }

  // delete students
  Future<void> deleteStudent(StudentModel student) async {
    try {
      await isar.writeTxn(() async {
        await isar.studentModels.delete(student.id);
      });
    } catch (e) {
      throw e.toString();
    }
  }
}

final studentServiceProvider = Provider((ref) {
  final isar = ref.read(isarServiceProvider).instance;
  return StudentService(isar);
});
