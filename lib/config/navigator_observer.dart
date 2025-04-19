import 'dart:developer' show log;

import 'package:flutter/material.dart' show NavigatorObserver, Route;
import 'package:hooks_riverpod/hooks_riverpod.dart' show WidgetRef;

class MyNavigatorObserver extends NavigatorObserver {
  final WidgetRef ref;

  MyNavigatorObserver(this.ref);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    log('previousRoute => $previousRoute, route => $route');
  }
}
