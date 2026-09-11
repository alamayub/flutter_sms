import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../services/teacher_service.dart';
import 'database_provider.dart';

export 'employee_provider.dart'
    show teachersStreamProvider, teacherSearchQueryProvider;

final teacherServiceProvider = Provider<TeacherService>((ref) {
  final db = ref.watch(databaseProvider);
  return TeacherService(db);
});
