import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'config/theme.dart';
import 'pages/splash_screen.dart';
import 'providers/locale_provider.dart';
import 'providers/storage_provider.dart';
import 'providers/theme_provider.dart';
import 'services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storageService = await StorageService.init();

  runApp(
    ProviderScope(
      overrides: [storageServiceProvider.overrideWithValue(storageService)],
      child: const SchoolManagementApp(),
    ),
  );
}

class SchoolManagementApp extends ConsumerWidget {
  const SchoolManagementApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final currentLocale = ref.watch(currentLocaleProvider);

    return MaterialApp(
      title: 'Mero School',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      themeAnimationDuration: AppTransitions.duration,
      themeAnimationCurve: AppTransitions.curve,
      scrollBehavior: const AppScrollBehavior(),
      locale: currentLocale,
      supportedLocales: const [Locale('en', 'US'), Locale('ne', 'NP')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const SplashScreen(),
    );
  }
}

// flutter build macos --release
// flutter build windows --release

// rm -rf /Applications/com.study2ool.sms.app
// rm -rf ~/Library/Application\ Support/com.study2ool.sms
// rm -rf ~/Library/Caches/com.study2ool.sms
// rm -rf ~/Library/Preferences/com.study2ool.sms.plist
// rm -rf ~/Library/Saved\ Application\ State/com.study2ool.sms.savedState

// rm -rf ~/Library/Containers/com.study2ool.sms
// rm -rf ~/Library/Group\ Containers/com.study2ool.sms

// find ~/Library -iname '*com.study2ool.sms*' 2>/dev/null

// rm -rf \
// "$HOME/Library/Application Support/com.study2ool.sms" \
// "$HOME/Library/Caches/com.study2ool.sms" \
// "$HOME/Library/Preferences/com.study2ool.sms.plist" \
// "$HOME/Library/Containers/com.study2ool.sms"
