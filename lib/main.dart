import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart'
    show
        AsyncValueX,
        ConsumerWidget,
        HookConsumerWidget,
        ProviderScope,
        WidgetRef;

import 'config/navigator_observer.dart';
import 'config/theme.dart' show Themes;
import 'providers/global_provider.dart' show appStartupProvider;
import 'screens/wrapper.dart';
import 'widgets/startup/startup_error.dart';
import 'widgets/startup/startup_loading.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: AppStartupWidget()));
}

class AppStartupWidget extends ConsumerWidget {
  const AppStartupWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navigatorObserver = MyNavigatorObserver(ref);
    return MaterialApp(
      title: 'BOOK',
      debugShowCheckedModeBanner: false,
      theme: Themes.light,
      home: const MyApp(),
      // builder: (context, child) {
      //   final MediaQueryData data = MediaQuery.of(context);
      //   return MediaQuery(
      //     data: data.copyWith(
      //       textScaler: TextScaler.linear(
      //         data.size.width > 680
      //             ? 1.15
      //             : data.size.width < 380
      //             ? 0.9
      //             : 1.01,
      //       ),
      //     ),
      //     child: child!,
      //   );
      // },
      navigatorObservers: [navigatorObserver],
    );
  }
}

class MyApp extends HookConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appStartup = ref.watch(appStartupProvider);
    return appStartup.when(
      data: (_) => const Wrapper(),
      loading: () => StartupLoading(),
      error:
          (err, _) => StartupError(
            error: err,
            onRetry: () => ref.refresh(appStartupProvider),
          ),
    );
  }
}

// dart run build_runner build