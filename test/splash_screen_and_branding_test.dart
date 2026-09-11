import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sms/main.dart';
import 'package:sms/pages/splash_screen.dart';
import 'package:sms/widgets/ui/app_vector_graphics.dart';

void main() {
  group('SplashScreen Widget Tests', () {
    testWidgets('SplashScreen renders Mero School brand identity', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SplashScreen(
            displayDuration: Duration(seconds: 10),
            nextScreen: Scaffold(body: Text('Home Target Screen')),
          ),
        ),
      );

      // Verify branding elements
      expect(find.text('Mero School'), findsOneWidget);
      expect(find.text('SCHOOL MANAGEMENT SYSTEM'), findsOneWidget);
      expect(find.text('v1.0.0 • Offline First Edition'), findsOneWidget);
      expect(find.byType(AuroraMeshBackground), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.school_rounded), findsOneWidget);
    });

    testWidgets('SplashScreen navigates to nextScreen on timer completion', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SplashScreen(
            displayDuration: Duration(milliseconds: 100),
            nextScreen: Scaffold(body: Text('Home Target Screen')),
          ),
        ),
      );

      expect(find.text('Mero School'), findsOneWidget);
      expect(find.text('Home Target Screen'), findsNothing);

      // Advance clock past splash duration
      await tester.pump(const Duration(milliseconds: 120));
      await tester.pumpAndSettle();

      expect(find.text('Home Target Screen'), findsOneWidget);
    });
  });

  group('Application Metadata & Platform Configuration Tests', () {
    testWidgets('SchoolManagementApp sets MaterialApp title to Mero School', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(child: SchoolManagementApp()),
      );
      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.title, equals('Mero School'));
      expect(materialApp.home, isA<SplashScreen>());
    });

    test('AndroidManifest.xml specifies Mero School application label', () {
      final manifest =
          File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
      expect(manifest.contains('android:label="Mero School"'), isTrue);
    });

    test('iOS Info.plist specifies Mero School bundle names', () {
      final plist = File('ios/Runner/Info.plist').readAsStringSync();
      expect(plist.contains('<string>Mero School</string>'), isTrue);
    });

    test('macOS AppInfo.xcconfig specifies Mero School PRODUCT_NAME', () {
      final xcconfig =
          File('macos/Runner/Configs/AppInfo.xcconfig').readAsStringSync();
      expect(xcconfig.contains('PRODUCT_NAME = Mero School'), isTrue);
    });

    test('Windows main.cpp & Runner.rc specify Mero School', () {
      final mainCpp = File('windows/runner/main.cpp').readAsStringSync();
      expect(mainCpp.contains('L"Mero School"'), isTrue);

      final runnerRc = File('windows/runner/Runner.rc').readAsStringSync();
      expect(runnerRc.contains('"Mero School"'), isTrue);
    });

    test('Linux my_application.cc specifies Mero School window title', () {
      final myApp = File('linux/runner/my_application.cc').readAsStringSync();
      expect(myApp.contains('"Mero School"'), isTrue);
    });
  });

  group('Platform Launcher Icons & Splash Assets Existence Tests', () {
    test('Android mipmap icons exist and have valid file sizes', () {
      final densities = ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi'];
      for (final d in densities) {
        final f = File('android/app/src/main/res/mipmap-$d/ic_launcher.png');
        expect(
          f.existsSync(),
          isTrue,
          reason: 'Missing mipmap-$d/ic_launcher.png',
        );
        expect(f.lengthSync(), greaterThan(100));
      }
    });

    test(
      'Android launch background drawables exist and reference brand assets',
      () {
        final d1 =
            File(
              'android/app/src/main/res/drawable/launch_background.xml',
            ).readAsStringSync();
        final d2 =
            File(
              'android/app/src/main/res/drawable-v21/launch_background.xml',
            ).readAsStringSync();
        expect(d1.contains('@color/launch_background'), isTrue);
        expect(d2.contains('@color/launch_background'), isTrue);
        expect(d1.contains('@mipmap/ic_launcher'), isTrue);
      },
    );

    test(
      'iOS AppIcon and LaunchImage assets exist and have valid file sizes',
      () {
        final appIcon1024 = File(
          'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png',
        );
        expect(appIcon1024.existsSync(), isTrue);
        expect(appIcon1024.lengthSync(), greaterThan(1000));

        final launchImage = File(
          'ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage.png',
        );
        expect(launchImage.existsSync(), isTrue);
        expect(launchImage.lengthSync(), greaterThan(100));
      },
    );

    test('macOS AppIcon assets exist and have valid file sizes', () {
      final macIcon1024 = File(
        'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png',
      );
      expect(macIcon1024.existsSync(), isTrue);
      expect(macIcon1024.lengthSync(), greaterThan(1000));
    });

    test(
      'Windows app_icon.ico exists and has valid multi-resolution ICO header',
      () {
        final winIco = File('windows/runner/resources/app_icon.ico');
        expect(winIco.existsSync(), isTrue);
        expect(winIco.lengthSync(), greaterThan(1000));

        // Verify ICO magic bytes (0, 0, 1, 0)
        final bytes = winIco.readAsBytesSync();
        expect(bytes[0], equals(0));
        expect(bytes[1], equals(0));
        expect(bytes[2], equals(1));
        expect(bytes[3], equals(0));
      },
    );
  });
}
