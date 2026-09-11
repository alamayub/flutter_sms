import 'package:drift/drift.dart' hide Column, isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sms/config/theme.dart';
import 'package:sms/config/translations.dart';
import 'package:sms/data/app_database.dart';
import 'package:sms/data/database_seeder.dart';
import 'package:sms/pages/dashboard_screen.dart';
import 'package:sms/providers/dashboard_provider.dart';
import 'package:sms/providers/database_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await DatabaseSeeder.seedAcademicYears(db);
    await DatabaseSeeder.seedClassesAndSections(db);
    await DatabaseSeeder.seedStudents(db);
    await DatabaseSeeder.seedEmployees(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('Dashboard Metrics Computation Tests', () {
    test('computeDashboardMetrics calculates correct metrics on seeded DB', () async {
      final metrics = await computeDashboardMetrics(db);

      // Verify student metrics
      expect(metrics.totalStudents, greaterThan(0));
      expect(metrics.activeStudents, greaterThan(0));
      expect(
        metrics.maleStudents + metrics.femaleStudents + metrics.otherGenderStudents,
        equals(metrics.totalStudents),
      );

      // Verify employee metrics
      expect(metrics.totalEmployees, greaterThan(0));
      expect(
        metrics.teachersCount + metrics.staffCount,
        equals(metrics.totalEmployees),
      );

      // Verify classes and sections
      expect(metrics.totalClasses, greaterThan(0));
      expect(metrics.totalSections, greaterThan(0));

      // Verify class student counts
      expect(metrics.classStudentCounts, isNotEmpty);

      // Verify attendance summary objects
      expect(metrics.studentAttendanceToday, isNotNull);
      expect(metrics.employeeAttendanceToday, isNotNull);

      // Financials
      expect(metrics.feeCollected, greaterThanOrEqualTo(0.0));
      expect(metrics.totalInvoiced, greaterThanOrEqualTo(0.0));
      expect(metrics.feePending, greaterThanOrEqualTo(0.0));
      expect(metrics.expensesTotal, greaterThanOrEqualTo(0.0));
    });

    test('computeDashboardMetrics handles empty database gracefully', () async {
      final emptyDb = AppDatabase(NativeDatabase.memory());
      await emptyDb.delete(emptyDb.students).go();
      await emptyDb.delete(emptyDb.employees).go();
      await emptyDb.delete(emptyDb.schoolClasses).go();
      await emptyDb.delete(emptyDb.sections).go();
      await emptyDb.delete(emptyDb.feePayments).go();
      await emptyDb.delete(emptyDb.studentFees).go();
      await emptyDb.delete(emptyDb.expenses).go();
      await emptyDb.delete(emptyDb.exams).go();

      final metrics = await computeDashboardMetrics(emptyDb);

      expect(metrics.totalStudents, 0);
      expect(metrics.activeStudents, 0);
      expect(metrics.totalEmployees, 0);
      expect(metrics.teachersCount, 0);
      expect(metrics.staffCount, 0);
      expect(metrics.totalClasses, 0);
      expect(metrics.totalSections, 0);
      expect(metrics.feeCollected, 0.0);
      expect(metrics.totalInvoiced, 0.0);
      expect(metrics.feePending, 0.0);
      expect(metrics.expensesTotal, 0.0);
      expect(metrics.classStudentCounts, isEmpty);
      expect(metrics.recentPayments, isEmpty);
      expect(metrics.upcomingExams, isEmpty);

      await emptyDb.close();
    });
  });

  group('DashboardScreen Widget Tests', () {
    testWidgets('Renders dashboard components cleanly without layout errors', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final metrics = await computeDashboardMetrics(db);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            dashboardMetricsStreamProvider.overrideWith(
              (ref) => Stream.value(metrics),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Scaffold(
              body: DashboardScreen(),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pumpAndSettle();

      // Verify dashboard screen is rendered
      expect(find.byType(DashboardScreen), findsOneWidget);
      expect(
        find.text(AppTranslations.text('welcome_admin', 'en')),
        findsOneWidget,
      );
      expect(
        find.text(AppTranslations.text('quick_actions_title', 'en')),
        findsOneWidget,
      );
      expect(
        find.text(AppTranslations.text('class_enrollment_distribution', 'en')),
        findsOneWidget,
      );
      expect(
        find.text(AppTranslations.text('financial_overview', 'en')),
        findsAtLeastNWidgets(1),
      );
    });
  });
}
