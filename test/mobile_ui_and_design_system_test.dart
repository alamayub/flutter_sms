import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sms/config/theme.dart';
import 'package:sms/providers/nav_providers.dart';
import 'package:sms/widgets/ui/app_bottom_sheet.dart';
import 'package:sms/widgets/ui/app_button.dart';
import 'package:sms/widgets/ui/app_card.dart';
import 'package:sms/widgets/ui/app_vector_graphics.dart';
import 'package:sms/widgets/ui/mobile_bottom_nav.dart';

void main() {
  group('Mobile UI & Design System Tokens', () {
    test('3D Depth & Floating Dock Shadows conform to design tokens', () {
      final depthLight = AppShadows.depth3d(false);
      final depthDark = AppShadows.depth3d(true);
      expect(depthLight.length, equals(3));
      expect(depthDark.length, equals(3));

      final dockLight = AppShadows.floatingDock(false);
      final dockDark = AppShadows.floatingDock(true);
      expect(dockLight, isNotEmpty);
      expect(dockDark, isNotEmpty);
    });

    test('3D Gradients & Specular Highlights generate expected shaders', () {
      expect(AppGradients.specularHighlight.colors.length, equals(3));
      expect(
        AppGradients.specularHighlight.colors.last,
        equals(Colors.transparent),
      );

      final aurora = AppGradients.auroraGlow(
        primary: const Color(0xFF1E3A8A),
        accent: const Color(0xFF0D9488),
      );
      expect(aurora.colors.length, equals(3));

      final bevelLight = AppGradients.cardBevel(false);
      final bevelDark = AppGradients.cardBevel(true);
      expect(bevelLight.colors.first, equals(Colors.white));
      expect(bevelDark.colors.first, equals(const Color(0xFF1E293B)));
    });

    test('AppColors token shorthand alias properly maps to brand colors', () {
      expect(AppColors.primary, equals(AppTheme.primaryColor));
      expect(AppColors.secondary, equals(AppTheme.secondaryColor));
      expect(AppColors.accent, equals(AppTheme.accentColor));
      expect(AppColors.success, equals(AppTheme.successColor));
      expect(AppColors.error, equals(AppTheme.errorColor));
      expect(AppColors.warning, equals(AppTheme.warningColor));
      expect(AppColors.info, equals(AppTheme.infoColor));
    });
  });

  group('Procedural Vector Graphics & Decorators', () {
    testWidgets('AuroraMeshBackground renders without errors', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AuroraMeshBackground(child: Text('Ambient Glow Content')),
          ),
        ),
      );

      expect(find.text('Ambient Glow Content'), findsOneWidget);
      expect(find.byType(AuroraMeshBackground), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('GeometricCardDecor paints watermark correctly', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              height: 200,
              child: GeometricCardDecor(size: 80),
            ),
          ),
        ),
      );

      expect(find.byType(GeometricCardDecor), findsOneWidget);
    });

    testWidgets('VectorBadgeIcon renders icon and styled container', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VectorBadgeIcon(
              icon: Icons.verified_rounded,
              color: Colors.blue,
              size: 48,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.verified_rounded), findsOneWidget);
      expect(find.byType(VectorBadgeIcon), findsOneWidget);
    });

    testWidgets('StatusGlowDot renders glowing circular indicator', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: StatusGlowDot(color: Colors.green, size: 10)),
        ),
      );

      expect(find.byType(StatusGlowDot), findsOneWidget);
    });
  });

  group('Interactive AppCard & AppButton 3D Micro-interactions', () {
    testWidgets('AppCard supports depth3d styling and tap interactions', (
      tester,
    ) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: AppCard(
                depth3d: true,
                onTap: () => tapped = true,
                child: const Text('Interactive Card'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Interactive Card'), findsOneWidget);

      // Tap card
      await tester.tap(find.byType(AppCard));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });

    testWidgets('AppButton supports primary variant with specular top line', (
      tester,
    ) async {
      bool pressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: AppButton.primary(
                text: 'Confirm Action',
                onPressed: () => pressed = true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Confirm Action'), findsOneWidget);
      await tester.tap(find.text('Confirm Action'));
      await tester.pumpAndSettle();
      expect(pressed, isTrue);
    });
  });

  group('Adaptive Bottom Sheet System', () {
    testWidgets('AppBottomSheet renders title and body content', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder:
                  (ctx) => ElevatedButton(
                    onPressed: () {
                      AppBottomSheet.show(
                        context: ctx,
                        title: 'Test Sheet',
                        subtitle: 'Test Subtitle',
                        child: const Text('Sheet Body Content'),
                      );
                    },
                    child: const Text('Open Sheet'),
                  ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Test Sheet'), findsOneWidget);
      expect(find.text('Test Subtitle'), findsOneWidget);
      expect(find.text('Sheet Body Content'), findsOneWidget);
    });

    testWidgets('AppBottomSheet.showActionList executes tapped actions', (
      tester,
    ) async {
      bool actionTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder:
                  (ctx) => ElevatedButton(
                    onPressed: () {
                      AppBottomSheet.showActionList(
                        context: ctx,
                        title: 'Choose Action',
                        actions: [
                          AppBottomSheetAction(
                            title: 'Export PDF',
                            icon: Icons.picture_as_pdf,
                            onTap: () => actionTapped = true,
                          ),
                        ],
                      );
                    },
                    child: const Text('Show Actions'),
                  ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Actions'));
      await tester.pumpAndSettle();

      expect(find.text('Choose Action'), findsOneWidget);
      expect(find.text('Export PDF'), findsOneWidget);

      await tester.tap(find.text('Export PDF'));
      await tester.pumpAndSettle();

      expect(actionTapped, isTrue);
    });
  });

  group('Mobile Floating Bottom Navigation Dock', () {
    testWidgets('MobileBottomNav renders 5 tabs and responds to tab switches', (
      tester,
    ) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(bottomNavigationBar: MobileBottomNav()),
          ),
        ),
      );

      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Students'), findsOneWidget);
      expect(find.text('Attendance'), findsOneWidget);
      expect(find.text('Fees'), findsOneWidget);
      expect(find.text('More'), findsOneWidget);

      // Initially active item is dashboard (index 0)
      expect(container.read(activeMenuItemProvider).id, equals('dashboard'));

      // Tap 'Students' tab
      await tester.tap(find.text('Students'));
      await tester.pumpAndSettle();
      expect(container.read(activeMenuItemProvider).id, equals('students'));

      // Tap 'Fees' tab
      await tester.tap(find.text('Fees'));
      await tester.pumpAndSettle();
      expect(
        container.read(activeMenuItemProvider).id,
        equals('fee_collection'),
      );

      // Tap 'More' tab opens More Hub bottom sheet
      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();

      expect(find.text('School Management Hub'), findsOneWidget);
      expect(find.text('Preferences'), findsOneWidget);
    });
  });
}
