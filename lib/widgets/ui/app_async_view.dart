import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'app_empty_state.dart';
import 'app_error_view.dart';
import 'app_loader.dart';

/// A universal, reactive wrapper for Riverpod's [AsyncValue].
/// Automatically manages loading indicators/skeletons, error displays with retry,
/// empty collection/data handling, and successful data presentation.
class AppAsyncView<T> extends StatelessWidget {
  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final Widget Function()? loading;
  final Widget? skeleton;
  final Widget Function(Object error, StackTrace? stackTrace)? error;
  final VoidCallback? onRetry;
  final bool Function(T data)? isEmpty;
  final Widget Function()? empty;

  const AppAsyncView({
    super.key,
    required this.value,
    required this.data,
    this.loading,
    this.skeleton,
    this.error,
    this.onRetry,
    this.isEmpty,
    this.empty,
  });

  @override
  Widget build(BuildContext context) {
    return value.when(
      loading: () {
        if (loading != null) return loading!();
        if (skeleton != null) return skeleton!;
        return const Center(child: AppLoader());
      },
      error: (err, stack) {
        if (error != null) return error!(err, stack);
        return Center(
          child: AppErrorView(error: err, stackTrace: stack, onRetry: onRetry),
        );
      },
      data: (d) {
        final checkEmpty =
            isEmpty != null ? isEmpty!(d) : (d is Iterable && d.isEmpty);

        if (checkEmpty) {
          if (empty != null) return empty!();
          return Center(child: AppEmptyState.noData());
        }

        return data(d);
      },
    );
  }
}
