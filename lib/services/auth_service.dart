import 'package:flutter/foundation.dart' show immutable;
import 'package:hooks_riverpod/hooks_riverpod.dart' show Provider;
import 'package:isar/isar.dart' show Isar, QueryExecute;

import '../models/school_model.dart';
import 'isar_service.dart';

@immutable
class AuthService {
  final Isar isar;
  const AuthService(this.isar);

  // login
  Future<SchoolModel> login(String username, String password) async {
    try {
      final school =
          await isar.schoolModels
              .filter()
              .usernameEqualTo(username, caseSensitive: false)
              .findFirst();
      if (school != null) {
        if (school.password == password) {
          return school;
        } else {
          throw 'Wrong password!';
        }
      } else {
        throw 'Wrong username!';
      }
    } catch (e) {
      throw e.toString();
    }
  }

  // register school
  Future<SchoolModel> registerSchool(SchoolModel school) async {
    try {
      await isar.writeTxn(() async {
        final id = await isar.schoolModels.put(school);
        school.id = id;
      });
      return school;
    } catch (e) {
      if (e.toString().contains("duplicate")) {
        throw "Username already exist. Use another one!";
      }
      throw e.toString();
    }
  }

  // update school
  Future<SchoolModel> updateSchool(SchoolModel school) async {
    try {
      await isar.writeTxn(() async {
        final id = await isar.schoolModels.put(school);
        school.id = id;
      });
      return school;
    } catch (e) {
      if (e.toString().contains("duplicate")) {
        throw "Username already exist. Use another one!";
      }
      throw e.toString();
    }
  }
}

final authServiceProvider = Provider((ref) {
  final isar = ref.read(isarServiceProvider).instance;
  return AuthService(isar);
});
