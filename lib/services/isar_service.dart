import 'package:hooks_riverpod/hooks_riverpod.dart' show Provider;
import 'package:isar/isar.dart' show Isar;
import 'package:path_provider/path_provider.dart';

import '../models/school_model.dart';
import '../models/staff_model.dart';
import '../models/student_model.dart';

class IsarService {
  late Isar isar;

  Future<void> init() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      isar = await Isar.open([
        SchoolModelSchema,
        StudentModelSchema,
        StaffModelSchema,
      ], directory: dir.path);
    } catch (e) {
      throw e.toString();
    }
  }

  Future<void> close() async {
    try {
      await isar.close();
    } catch (e) {
      throw e.toString();
    }
  }

  Isar get instance => isar;
}

final isarServiceProvider = Provider<IsarService>((ref) => IsarService());
