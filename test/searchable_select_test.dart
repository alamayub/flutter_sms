import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sms/config/theme.dart';
import 'package:sms/widgets/searchable_select.dart';

void main() {
  Widget buildTestWidget({required Widget child}) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: Scaffold(
        body: Padding(padding: const EdgeInsets.all(16), child: child),
      ),
    );
  }

  group('AppSearchableSelect Component Tests', () {
    testWidgets('Renders label, hint, and displays placeholder initially', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(
          child: AppSearchableSelect<String>(
            label: 'Select Class',
            hint: 'Choose a class',
            items: const [
              SearchableSelectItem(value: '1', label: 'Class 1'),
              SearchableSelectItem(value: '2', label: 'Class 2'),
            ],
          ),
        ),
      );

      expect(find.text('Select Class'), findsOneWidget);
      expect(find.text('Choose a class'), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
    });

    testWidgets('Tapping opens search dialog and lists items', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          child: AppSearchableSelect<String>(
            label: 'Select Class',
            hint: 'Choose a class',
            items: const [
              SearchableSelectItem(
                value: '1',
                label: 'Class 1',
                subtitle: 'Grade 1',
              ),
              SearchableSelectItem(
                value: '2',
                label: 'Class 2',
                subtitle: 'Grade 2',
              ),
              SearchableSelectItem(
                value: '3',
                label: 'Class 3',
                subtitle: 'Grade 3',
              ),
            ],
          ),
        ),
      );

      // Tap to open
      await tester.tap(find.text('Choose a class'));
      await tester.pumpAndSettle();

      // Dialog is open
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text('Class 1'), findsOneWidget);
      expect(find.text('Class 2'), findsOneWidget);
      expect(find.text('Class 3'), findsOneWidget);
      expect(find.text('Grade 1'), findsOneWidget);
    });

    testWidgets('Typing in search field filters items dynamically', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(
          child: AppSearchableSelect<String>(
            items: const [
              SearchableSelectItem(value: '10', label: 'Class 10'),
              SearchableSelectItem(value: '1', label: 'Class 1'),
              SearchableSelectItem(value: '2', label: 'Class 2'),
              SearchableSelectItem(value: 'nur', label: 'Nursery'),
            ],
          ),
        ),
      );

      await tester.tap(find.byType(AppSearchableSelect<String>));
      await tester.pumpAndSettle();

      // Enter search query
      await tester.enterText(find.byType(TextField), 'Nurs');
      await tester.pumpAndSettle();

      expect(find.text('Nursery'), findsOneWidget);
      expect(find.text('Class 10'), findsNothing);
      expect(find.text('Class 1'), findsNothing);
    });

    testWidgets('Selecting an item closes dialog and invokes onChanged', (
      tester,
    ) async {
      String? selectedValue;

      await tester.pumpWidget(
        buildTestWidget(
          child: AppSearchableSelect<String>(
            hint: 'Choose fruit',
            items: const [
              SearchableSelectItem(value: 'apple', label: 'Apple'),
              SearchableSelectItem(value: 'banana', label: 'Banana'),
            ],
            onChanged: (val) {
              selectedValue = val;
            },
          ),
        ),
      );

      await tester.tap(find.text('Choose fruit'));
      await tester.pumpAndSettle();

      // Select 'Banana'
      await tester.tap(find.text('Banana'));
      await tester.pumpAndSettle();

      // Dialog should be closed and Banana shown
      expect(find.byType(Dialog), findsNothing);
      expect(find.text('Banana'), findsOneWidget);
      expect(selectedValue, equals('banana'));
    });

    testWidgets('Clear button resets value when isClearable is true', (
      tester,
    ) async {
      String? currentValue = 'apple';

      await tester.pumpWidget(
        buildTestWidget(
          child: StatefulBuilder(
            builder: (context, setState) {
              return AppSearchableSelect<String>(
                value: currentValue,
                isClearable: true,
                items: const [
                  SearchableSelectItem(value: 'apple', label: 'Apple'),
                  SearchableSelectItem(value: 'banana', label: 'Banana'),
                ],
                onChanged: (val) {
                  setState(() => currentValue = val);
                },
              );
            },
          ),
        ),
      );

      expect(find.text('Apple'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);

      // Tap clear
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(currentValue, isNull);
      expect(find.text('Select an option'), findsOneWidget);
    });

    testWidgets('Disabled state prevents opening dialog', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          child: AppSearchableSelect<String>(
            hint: 'Disabled Select',
            enabled: false,
            items: const [SearchableSelectItem(value: '1', label: 'Item 1')],
          ),
        ),
      );

      await tester.tap(find.text('Disabled Select'));
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsNothing);
    });

    testWidgets('Form validation displays error text', (tester) async {
      final formKey = GlobalKey<FormState>();

      await tester.pumpWidget(
        buildTestWidget(
          child: Form(
            key: formKey,
            child: AppSearchableSelect<String>(
              hint: 'Required selection',
              items: const [SearchableSelectItem(value: '1', label: 'Item 1')],
              validator: (val) {
                if (val == null) return 'This field is required';
                return null;
              },
            ),
          ),
        ),
      );

      // Trigger validation
      formKey.currentState!.validate();
      await tester.pumpAndSettle();

      expect(find.text('This field is required'), findsOneWidget);
    });

    testWidgets(
      'AppSearchableSelect.fromList factory works with model objects',
      (tester) async {
        final items = [
          {'id': 101, 'name': 'Mathematics'},
          {'id': 102, 'name': 'Science'},
        ];

        Map<String, Object>? selectedMap;

        await tester.pumpWidget(
          buildTestWidget(
            child: AppSearchableSelect<Map<String, Object>>.fromList(
              items: items,
              labelBuilder: (m) => m['name'] as String,
              subtitleBuilder: (m) => 'Code: ${m['id']}',
              onChanged: (val) => selectedMap = val,
            ),
          ),
        );

        await tester.tap(find.byType(AppSearchableSelect<Map<String, Object>>));
        await tester.pumpAndSettle();

        expect(find.text('Mathematics'), findsOneWidget);
        expect(find.text('Code: 101'), findsOneWidget);

        await tester.tap(find.text('Mathematics'));
        await tester.pumpAndSettle();

        expect(selectedMap?['id'], equals(101));
      },
    );
  });
}
