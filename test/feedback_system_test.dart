import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'package:sms/widgets/ui/app_loader.dart';
import 'package:sms/widgets/ui/app_toast.dart';
import 'package:sms/widgets/ui/app_error_view.dart';
import 'package:sms/widgets/ui/app_empty_state.dart';
import 'package:sms/widgets/ui/app_skeleton.dart';
import 'package:sms/widgets/ui/app_async_view.dart';

void main() {
  group('AppLoader & AppLoadingOverlay Tests', () {
    testWidgets('AppLoader renders spinner and message for sm, md, lg', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                AppLoader(size: AppLoaderSize.sm, message: 'Loading small...'),
                AppLoader(size: AppLoaderSize.md, message: 'Loading medium...'),
                AppLoader(size: AppLoaderSize.lg, message: 'Loading large...'),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Loading small...'), findsOneWidget);
      expect(find.text('Loading medium...'), findsOneWidget);
      expect(find.text('Loading large...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNWidgets(3));
    });

    testWidgets('AppLoadingOverlay renders message and handles onCancel', (
      tester,
    ) async {
      bool cancelled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppLoadingOverlay(
              isLoading: true,
              message: 'Exporting database...',
              cancelText: 'Abort',
              onCancel: () {
                cancelled = true;
              },
              child: const SizedBox.expand(
                child: Center(child: Text('Background Content')),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Background Content'), findsOneWidget);
      expect(find.text('Exporting database...'), findsOneWidget);
      expect(find.text('Abort'), findsOneWidget);

      await tester.tap(find.text('Abort'));
      await tester.pump();

      expect(cancelled, isTrue);
    });
  });

  group('AppToast Tests', () {
    testWidgets('AppToast shows success toast', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder:
                  (context) => ElevatedButton(
                    onPressed:
                        () => AppToast.showSuccess(
                          context,
                          'Student saved successfully!',
                        ),
                    child: const Text('Show Success'),
                  ),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Show Success'));
      await tester.pump();
      expect(find.text('Student saved successfully!'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    });

    testWidgets('AppToast shows error toast', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder:
                  (context) => ElevatedButton(
                    onPressed:
                        () => AppToast.showError(
                          context,
                          'Failed to save student',
                        ),
                    child: const Text('Show Error'),
                  ),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Show Error'));
      await tester.pump();
      expect(find.text('Failed to save student'), findsOneWidget);
      expect(find.byIcon(Icons.error_rounded), findsOneWidget);
    });

    testWidgets('AppToast shows warning and info toasts', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder:
                  (context) => ElevatedButton(
                    onPressed:
                        () => AppToast.showWarning(
                          context,
                          'Please backup your database',
                        ),
                    child: const Text('Show Warning'),
                  ),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Show Warning'));
      await tester.pump();
      expect(find.text('Please backup your database'), findsOneWidget);
      expect(find.byIcon(Icons.warning_rounded), findsOneWidget);
    });
  });

  group('AppErrorView Tests', () {
    testWidgets(
      'AppErrorView renders error title, description and retry trigger',
      (tester) async {
        bool retried = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AppErrorView(
                title: 'Custom Error',
                message: 'Something unexpected happened',
                error: Exception('Connection timeout'),
                onRetry: () {
                  retried = true;
                },
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Custom Error'), findsOneWidget);
        expect(find.text('Something unexpected happened'), findsOneWidget);
        expect(find.text('Try Again'), findsOneWidget);

        // Expand technical details
        expect(find.text('View Details'), findsOneWidget);
        await tester.tap(find.text('View Details'));
        await tester.pump();

        expect(find.text('Hide Details'), findsOneWidget);
        expect(
          find.textContaining('Exception: Connection timeout'),
          findsOneWidget,
        );

        // Tap Retry
        await tester.tap(find.text('Try Again'));
        await tester.pump();
        expect(retried, isTrue);
      },
    );
  });

  group('AppEmptyState Tests', () {
    testWidgets('AppEmptyState.noData renders defaults', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: AppEmptyState.noData())),
      );
      await tester.pump();

      expect(find.text('No records found'), findsOneWidget);
      expect(
        find.text('There is nothing to display right now.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
    });

    testWidgets('AppEmptyState.search renders and triggers clear', (
      tester,
    ) async {
      bool cleared = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppEmptyState.search(
              query: 'Aarav',
              onClear: () {
                cleared = true;
              },
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('No matching results'), findsOneWidget);
      expect(
        find.textContaining('No results found matching "Aarav"'),
        findsOneWidget,
      );
      expect(find.text('Clear Search'), findsOneWidget);

      await tester.tap(find.text('Clear Search'));
      await tester.pump();
      expect(cleared, isTrue);
    });

    testWidgets('AppEmptyState.filter and offline presets render correctly', (
      tester,
    ) async {
      bool resetCalled = false;
      bool retryCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  AppEmptyState.filter(onReset: () => resetCalled = true),
                  AppEmptyState.offline(onRetry: () => retryCalled = true),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('No results match filters'), findsOneWidget);
      expect(find.text('Reset Filters'), findsOneWidget);
      await tester.tap(find.text('Reset Filters'));
      await tester.pump();
      expect(resetCalled, isTrue);

      expect(find.text('No network connection'), findsOneWidget);
      expect(find.text('Retry Connection'), findsOneWidget);
      await tester.tap(find.text('Retry Connection'));
      await tester.pump();
      expect(retryCalled, isTrue);
    });
  });

  group('AppSkeleton Tests', () {
    testWidgets('AppSkeleton atoms and composite presets render', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  const AppSkeleton.line(width: 120),
                  const AppSkeleton.circle(size: 44),
                  const AppSkeleton.card(width: 200, height: 80),
                  AppSkeleton.list(count: 3),
                  AppSkeleton.table(rows: 3, columns: 3),
                  AppSkeleton.cards(count: 2),
                  AppSkeleton.form(fields: 2),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AppSkeleton), findsWidgets);
    });
  });

  group('AppAsyncView Tests', () {
    testWidgets('AppAsyncView renders loading state', (tester) async {
      const AsyncValue<List<String>> loadingVal = AsyncLoading();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppAsyncView<List<String>>(
              value: loadingVal,
              data: (list) => Text('Count: ${list.length}'),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AppLoader), findsOneWidget);
      expect(find.textContaining('Count:'), findsNothing);
    });

    testWidgets('AppAsyncView renders error state with retry', (tester) async {
      bool retried = false;
      final AsyncValue<List<String>> errorVal = AsyncError(
        'Database query failed',
        StackTrace.current,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppAsyncView<List<String>>(
              value: errorVal,
              onRetry: () => retried = true,
              data: (list) => Text('Count: ${list.length}'),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AppErrorView), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);

      await tester.tap(find.text('Try Again'));
      await tester.pump();
      expect(retried, isTrue);
    });

    testWidgets('AppAsyncView renders empty state when list is empty', (
      tester,
    ) async {
      const AsyncValue<List<String>> emptyVal = AsyncData([]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppAsyncView<List<String>>(
              value: emptyVal,
              data: (list) => Text('Count: ${list.length}'),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AppEmptyState), findsOneWidget);
      expect(find.text('No records found'), findsOneWidget);
      expect(find.textContaining('Count:'), findsNothing);
    });

    testWidgets('AppAsyncView renders data when non-empty', (tester) async {
      const AsyncValue<List<String>> dataVal = AsyncData(['Alpha', 'Beta']);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppAsyncView<List<String>>(
              value: dataVal,
              data: (list) => Text('Count: ${list.length}'),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Count: 2'), findsOneWidget);
      expect(find.byType(AppEmptyState), findsNothing);
      expect(find.byType(AppLoader), findsNothing);
    });
  });
}
