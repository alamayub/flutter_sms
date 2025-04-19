import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../config/extensions.dart' show ContextExtensions;
import '../../config/theme.dart' show ColorConstants;
import '../../providers/nav_provider.dart'
    show currentIndexProvider, rootBodyProvider;
import '../../widgets/root/sidebar_widget.dart';

class RootScreen extends ConsumerWidget {
  const RootScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final body = ref.watch(rootBodyProvider);
    final index = ref.watch(currentIndexProvider);
    return Scaffold(
      appBar: context.isMobile ? AppBar() : null,
      body: Row(
        children: [
          if (!context.isMobile)
            Container(
              width: 250,
              decoration: BoxDecoration(
                color: ColorConstants.scafoldBG,
                borderRadius: BorderRadius.circular(16),
              ),
              margin: EdgeInsets.all(16).copyWith(right: 0),
              padding: EdgeInsets.all(16),
              child: const SidebarWidget(),
            ),
          Expanded(child: body[index]),
        ],
      ),
      drawer:
          context.isMobile
              ? Drawer(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: const SidebarWidget(),
                ),
              )
              : null,
    );
  }
}
