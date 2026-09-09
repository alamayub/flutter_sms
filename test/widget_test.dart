// test/widget_test.dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sms/core/database/app_database.dart';
import 'package:sms/core/database/database_service.dart';
import 'package:sms/main.dart';

void main() {
  testWidgets(
    'SchoolManagementApp boots up and displays Welcome on fresh launch',
    (WidgetTester tester) async {
      final db = AppDatabase(NativeDatabase.memory());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(db)],
          child: const SchoolManagementApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Welcome / First launch UI rendered
      expect(
        find.textContaining('School Management System'),
        findsAtLeastNWidgets(1),
      );
      expect(find.text('Create New School'), findsOneWidget);
      expect(find.text('Import Existing Database (.sdb)'), findsOneWidget);

      await db.close();
    },
  );
}
