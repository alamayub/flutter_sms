import 'package:hooks_riverpod/hooks_riverpod.dart' show Provider;
import 'package:isar/isar.dart' show Isar;
import 'package:path_provider/path_provider.dart'
    show getApplicationDocumentsDirectory;

import '../modesl/student_model.dart';

class IsarService {
  late Isar isar;

  Future<void> init() async {
    try {
      await Future.delayed(const Duration(seconds: 2));
      final dir = await getApplicationDocumentsDirectory();
      isar = await Isar.open([StudentModelSchema], directory: dir.path);
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
