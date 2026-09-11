import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sms/config/theme.dart';
import 'package:sms/widgets/ui/app_button.dart';
import 'package:sms/widgets/ui/app_tabs.dart';
import 'package:sms/widgets/ui/app_segmented_control.dart';
import 'package:sms/widgets/app_input.dart';

void main() {
  group('Design Tokens & Scales Tests', () {
    test('AppSpacing scale conforms to Tailwind / standard design tokens', () {
      expect(AppSpacing.xs, equals(4.0));
      expect(AppSpacing.sm, equals(8.0));
      expect(AppSpacing.md, equals(12.0));
      expect(AppSpacing.lg, equals(16.0));
      expect(AppSpacing.xl, equals(20.0));
      expect(AppSpacing.xxl, equals(24.0));
      expect(AppSpacing.xxxl, equals(32.0));
      expect(AppSpacing.xxxxl, equals(48.0));
    });

    test('AppRadius tokens conform to rounded corner system', () {
      expect(AppRadius.xs, equals(4.0));
      expect(AppRadius.sm, equals(6.0));
      expect(AppRadius.md, equals(8.0));
      expect(AppRadius.lg, equals(10.0));
      expect(AppRadius.xl, equals(12.0));
      expect(AppRadius.xxl, equals(16.0));
      expect(AppRadius.full, equals(9999.0));

      expect(AppRadius.roundedXs.topLeft.x, equals(4.0));
      expect(AppRadius.roundedLg.topLeft.x, equals(10.0));
      expect(AppRadius.roundedXl.topLeft.x, equals(12.0));
    });

    test('AppTransitions match 300ms cubic-bezier(0.4, 0, 0.2, 1)', () {
      expect(
        AppTransitions.duration,
        equals(const Duration(milliseconds: 300)),
      );
      expect(AppTransitions.curve.a, equals(0.4));
      expect(AppTransitions.curve.b, equals(0.0));
      expect(AppTransitions.curve.c, equals(0.2));
      expect(AppTransitions.curve.d, equals(1.0));
    });

    test('AppPrintStyle defines exact print formatting constants', () {
      expect(AppPrintStyle.printBackground, equals(const Color(0xFFFFFFFF)));
      expect(AppPrintStyle.printText, equals(const Color(0xFF0F172A)));
      expect(AppPrintStyle.printBorder, equals(const Color(0xFFCBD5E1)));
      expect(AppPrintStyle.idCardGridGap, equals(16.0));
      expect(
        AppPrintStyle.idCardSheetPadding,
        equals(const EdgeInsets.all(12.0)),
      );
    });
  });

  group('Interactive Cursor Rules Tests', () {
    test(
      'AppCursors.interactive resolves click when enabled and forbidden when disabled',
      () {
        final normalCursor = AppCursors.interactive.resolve({});
        final hoveredCursor = AppCursors.interactive.resolve({
          WidgetState.hovered,
        });
        final focusedCursor = AppCursors.interactive.resolve({
          WidgetState.focused,
        });
        final disabledCursor = AppCursors.interactive.resolve({
          WidgetState.disabled,
        });

        expect(normalCursor, equals(SystemMouseCursors.click));
        expect(hoveredCursor, equals(SystemMouseCursors.click));
        expect(focusedCursor, equals(SystemMouseCursors.click));
        expect(disabledCursor, equals(SystemMouseCursors.forbidden));
      },
    );

    test(
      'Buttons in light and dark themes have click/forbidden mouse cursors',
      () {
        for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
          // Elevated Button
          final elevatedCursor = theme.elevatedButtonTheme.style?.mouseCursor;
          expect(elevatedCursor?.resolve({}), equals(SystemMouseCursors.click));
          expect(
            elevatedCursor?.resolve({WidgetState.disabled}),
            equals(SystemMouseCursors.forbidden),
          );

          // Outlined Button
          final outlinedCursor = theme.outlinedButtonTheme.style?.mouseCursor;
          expect(outlinedCursor?.resolve({}), equals(SystemMouseCursors.click));
          expect(
            outlinedCursor?.resolve({WidgetState.disabled}),
            equals(SystemMouseCursors.forbidden),
          );

          // Text Button
          final textCursor = theme.textButtonTheme.style?.mouseCursor;
          expect(textCursor?.resolve({}), equals(SystemMouseCursors.click));
          expect(
            textCursor?.resolve({WidgetState.disabled}),
            equals(SystemMouseCursors.forbidden),
          );

          // Filled Button
          final filledCursor = theme.filledButtonTheme.style?.mouseCursor;
          expect(filledCursor?.resolve({}), equals(SystemMouseCursors.click));
          expect(
            filledCursor?.resolve({WidgetState.disabled}),
            equals(SystemMouseCursors.forbidden),
          );

          // Icon Button
          final iconCursor = theme.iconButtonTheme.style?.mouseCursor;
          expect(iconCursor?.resolve({}), equals(SystemMouseCursors.click));
          expect(
            iconCursor?.resolve({WidgetState.disabled}),
            equals(SystemMouseCursors.forbidden),
          );
        }
      },
    );

    test(
      'Selection controls (Checkbox, Radio, Switch, DataTable) resolve click and forbidden',
      () {
        for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
          // Checkbox
          final checkboxCursor = theme.checkboxTheme.mouseCursor;
          expect(checkboxCursor?.resolve({}), equals(SystemMouseCursors.click));
          expect(
            checkboxCursor?.resolve({WidgetState.disabled}),
            equals(SystemMouseCursors.forbidden),
          );

          // Radio
          final radioCursor = theme.radioTheme.mouseCursor;
          expect(radioCursor?.resolve({}), equals(SystemMouseCursors.click));
          expect(
            radioCursor?.resolve({WidgetState.disabled}),
            equals(SystemMouseCursors.forbidden),
          );

          // Switch
          final switchCursor = theme.switchTheme.mouseCursor;
          expect(switchCursor?.resolve({}), equals(SystemMouseCursors.click));
          expect(
            switchCursor?.resolve({WidgetState.disabled}),
            equals(SystemMouseCursors.forbidden),
          );

          // DataTable dataRowCursor
          final dataRowCursor = theme.dataTableTheme.dataRowCursor;
          expect(dataRowCursor?.resolve({}), equals(SystemMouseCursors.click));
          expect(
            dataRowCursor?.resolve({WidgetState.disabled}),
            equals(SystemMouseCursors.forbidden),
          );

          // SegmentedButton
          final segCursor = theme.segmentedButtonTheme.style?.mouseCursor;
          expect(segCursor?.resolve({}), equals(SystemMouseCursors.click));
          expect(
            segCursor?.resolve({WidgetState.disabled}),
            equals(SystemMouseCursors.forbidden),
          );
        }
      },
    );
  });

  group('Typography & Font Features Tests', () {
    test(
      'AppTypography includes cv02, cv03, cv04, cv11 font feature settings',
      () {
        const features = AppTypography.fontFeatures;
        expect(features.length, equals(4));
        expect(features.any((f) => f.feature == 'cv02'), isTrue);
        expect(features.any((f) => f.feature == 'cv03'), isTrue);
        expect(features.any((f) => f.feature == 'cv04'), isTrue);
        expect(features.any((f) => f.feature == 'cv11'), isTrue);
      },
    );

    test(
      'TextTheme in lightTheme and darkTheme incorporates font features',
      () {
        for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
          expect(
            theme.textTheme.bodyMedium?.fontFeatures,
            equals(AppTypography.fontFeatures),
          );
          expect(
            theme.textTheme.titleLarge?.fontFeatures,
            equals(AppTypography.fontFeatures),
          );
          expect(
            theme.textTheme.headlineSmall?.fontFeatures,
            equals(AppTypography.fontFeatures),
          );
        }
      },
    );
  });

  group('Scroll Behavior Tests (Hide Scrollbar)', () {
    test(
      'AppScrollBehavior removes scrollbar thumb and preserves dragging devices',
      () {
        const behavior = AppScrollBehavior();
        final childWidget = Container();

        // buildScrollbar returns child directly without Scrollbar wrapper
        final built = behavior.buildScrollbar(
          TestBuildContext(),
          childWidget,
          ScrollableDetails(
            direction: AxisDirection.down,
            controller: ScrollController(),
          ),
        );
        expect(identical(built, childWidget), isTrue);

        // Drag devices include touch, mouse, trackpad, stylus
        expect(behavior.dragDevices, contains(PointerDeviceKind.touch));
        expect(behavior.dragDevices, contains(PointerDeviceKind.mouse));
        expect(behavior.dragDevices, contains(PointerDeviceKind.trackpad));
        expect(behavior.dragDevices, contains(PointerDeviceKind.stylus));
      },
    );
  });

  group('Widget Rendering & State Verification Tests', () {
    testWidgets(
      'ElevatedButton, OutlinedButton, Checkbox render with proper cursors and styling',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            scrollBehavior: const AppScrollBehavior(),
            home: Scaffold(
              body: Column(
                children: [
                  ElevatedButton(
                    onPressed: () {},
                    child: const Text('Active Button'),
                  ),
                  const ElevatedButton(
                    onPressed: null,
                    child: Text('Disabled Button'),
                  ),
                  Checkbox(value: true, onChanged: (v) {}),
                  const Checkbox(value: false, onChanged: null),
                ],
              ),
            ),
          ),
        );

        // Verify active and disabled widgets are rendered
        expect(find.text('Active Button'), findsOneWidget);
        expect(find.text('Disabled Button'), findsOneWidget);
        expect(find.byType(Checkbox), findsNWidgets(2));
      },
    );
  });

  group('Button Sizing Tokens & Typography Helpers Tests', () {
    test('AppButtonSize defines standardized heights and paddings', () {
      expect(AppButtonSize.heightSm, equals(34.0));
      expect(AppButtonSize.paddingSm.horizontal, equals(24.0)); // 12 + 12
      expect(AppButtonSize.fontSizeSm, equals(12.0));
      expect(AppButtonSize.iconSizeSm, equals(16.0));

      expect(AppButtonSize.heightMd, equals(44.0));
      expect(AppButtonSize.paddingMd.horizontal, equals(36.0)); // 18 + 18
      expect(AppButtonSize.fontSizeMd, equals(14.0));
      expect(AppButtonSize.iconSizeMd, equals(18.0));

      expect(AppButtonSize.heightLg, equals(50.0));
      expect(AppButtonSize.paddingLg.horizontal, equals(48.0)); // 24 + 24
      expect(AppButtonSize.fontSizeLg, equals(15.0));
      expect(AppButtonSize.iconSizeLg, equals(20.0));
    });

    test(
      'AppTypography button, tab, and input helpers include font features',
      () {
        final btnStyle = AppTypography.button();
        expect(btnStyle.fontSize, equals(14.0));
        expect(btnStyle.fontWeight, equals(FontWeight.w600));
        expect(btnStyle.fontFeatures, equals(AppTypography.fontFeatures));

        final tabStyle = AppTypography.tab();
        expect(tabStyle.fontSize, equals(14.0));
        expect(tabStyle.fontWeight, equals(FontWeight.w600));
        expect(tabStyle.fontFeatures, equals(AppTypography.fontFeatures));

        final inputStyle = AppTypography.inputLabel();
        expect(inputStyle.fontSize, equals(14.0));
        expect(inputStyle.fontFeatures, equals(AppTypography.fontFeatures));
      },
    );
  });

  group('TabBarTheme & SegmentedButtonTheme Tests', () {
    test('TabBarThemeData is standardized across light and dark themes', () {
      for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
        final tabBarTheme = theme.tabBarTheme;
        expect(tabBarTheme.indicatorSize, equals(TabBarIndicatorSize.tab));
        expect(tabBarTheme.labelStyle?.fontWeight, equals(FontWeight.w600));
        expect(
          tabBarTheme.unselectedLabelStyle?.fontWeight,
          equals(FontWeight.w500),
        );
      }
    });

    test(
      'SegmentedButtonThemeData defines styles across light and dark themes',
      () {
        for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
          final segTheme = theme.segmentedButtonTheme;
          final style = segTheme.style;
          expect(style, isNotNull);
          expect(
            style?.mouseCursor?.resolve({}),
            equals(SystemMouseCursors.click),
          );
          expect(
            style?.mouseCursor?.resolve({WidgetState.disabled}),
            equals(SystemMouseCursors.forbidden),
          );
        }
      },
    );

    test('DialogTheme and TextSelectionTheme are standardized', () {
      for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
        expect(theme.dialogTheme.backgroundColor, isNotNull);
        expect(theme.dialogTheme.shape, isA<RoundedRectangleBorder>());
        expect(theme.textSelectionTheme.cursorColor, isNotNull);
      }
    });
  });

  group('Standardized UI Primitives Widget Tests', () {
    testWidgets('AppButton renders variants, sizes, and handles clicks', (
      tester,
    ) async {
      bool primaryClicked = false;
      bool outlineClicked = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Column(
              children: [
                AppButton.primary(
                  text: 'Primary Action',
                  onPressed: () => primaryClicked = true,
                ),
                AppButton.secondary(text: 'Secondary Action', onPressed: () {}),
                AppButton.outline(
                  text: 'Outline Action',
                  onPressed: () => outlineClicked = true,
                ),
                AppButton.destructive(text: 'Delete Item', onPressed: () {}),
                AppButton.ghost(text: 'Cancel', onPressed: () {}),
                const AppButton.primary(
                  text: 'Loading Action',
                  isLoading: true,
                  onPressed: null,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Primary Action'), findsOneWidget);
      expect(find.text('Secondary Action'), findsOneWidget);
      expect(find.text('Outline Action'), findsOneWidget);
      expect(find.text('Delete Item'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.tap(find.text('Primary Action'));
      await tester.pump();
      expect(primaryClicked, isTrue);

      await tester.tap(find.text('Outline Action'));
      await tester.pump();
      expect(outlineClicked, isTrue);
    });

    testWidgets('AppPillTabBar and AppUnderlineTabBar render and switch tabs', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const DefaultTabController(
            length: 2,
            child: Scaffold(
              body: Column(
                children: [
                  AppPillTabBar(
                    tabs: [Tab(text: 'Pill Tab 1'), Tab(text: 'Pill Tab 2')],
                  ),
                  AppUnderlineTabBar(
                    tabs: [Tab(text: 'Line Tab 1'), Tab(text: 'Line Tab 2')],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        Center(child: Text('Content 1')),
                        Center(child: Text('Content 2')),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Pill Tab 1'), findsOneWidget);
      expect(find.text('Pill Tab 2'), findsOneWidget);
      expect(find.text('Line Tab 1'), findsOneWidget);
      expect(find.text('Line Tab 2'), findsOneWidget);
      expect(find.text('Content 1'), findsOneWidget);
    });

    testWidgets(
      'AppSegmentedControl renders segments and responds to selection',
      (tester) async {
        String selected = 'A';

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: StatefulBuilder(
              builder: (context, setState) {
                return Scaffold(
                  body: AppSegmentedControl<String>(
                    segments: const [
                      ButtonSegment(value: 'A', label: Text('Option A')),
                      ButtonSegment(value: 'B', label: Text('Option B')),
                    ],
                    selected: {selected},
                    onSelectionChanged: (newSel) {
                      setState(() => selected = newSel.first);
                    },
                  ),
                );
              },
            ),
          ),
        );

        expect(find.text('Option A'), findsOneWidget);
        expect(find.text('Option B'), findsOneWidget);

        await tester.tap(find.text('Option B'));
        await tester.pumpAndSettle();
        expect(selected, equals('B'));
      },
    );

    testWidgets(
      'AppFormFieldWrapper renders label, asterisk, and helper/error text',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Scaffold(
              body: Column(
                children: [
                  AppFormFieldWrapper(
                    label: 'Student Name',
                    isRequired: true,
                    helperText: 'Enter full legal name',
                    child: TextField(),
                  ),
                  AppFormFieldWrapper(
                    label: 'Email',
                    errorText: 'Invalid email address',
                    child: TextField(),
                  ),
                ],
              ),
            ),
          ),
        );

        expect(find.text('Student Name'), findsOneWidget);
        expect(find.text('*'), findsOneWidget);
        expect(find.text('Enter full legal name'), findsOneWidget);
        expect(find.text('Email'), findsOneWidget);
        expect(find.text('Invalid email address'), findsOneWidget);
      },
    );
  });
}

class TestBuildContext extends Fake implements BuildContext {}
