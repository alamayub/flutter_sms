import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hooks_riverpod/misc.dart';

import 'loader_widget.dart';

class ProviderDataViewWidget<T> extends ConsumerWidget {
  final Refreshable<AsyncValue<T>> provider;
  final Widget Function(T data) dataBuilder;
  final Widget? loading;

  const ProviderDataViewWidget({
    super.key,
    required this.provider,
    required this.dataBuilder,
    this.loading,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(provider);
    return value.when(
      data: dataBuilder,
      loading: () => loading ?? const LoaderWidget(),
      error:
          (error, _) => Center(
            child: Column(
              spacing: 8,
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Error: ${error.toString()}', textAlign: TextAlign.center),
                ElevatedButton(
                  onPressed: () => ref.refresh(provider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
    );
  }
}
