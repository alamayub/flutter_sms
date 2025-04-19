import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../config/constants.dart' show Strings;
import '../../config/extensions.dart' show ContextExtensions;
import '../../config/theme.dart' show ColorConstants;
import '../../config/typo_config.dart';
import '../../providers/auth_providers.dart' show authProvider;
import '../../providers/nav_provider.dart';
import '../dialogs/alert_dialog_model.dart';

class SidebarWidget extends ConsumerWidget {
  const SidebarWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(currentIndexProvider);
    final icons = ref.watch(navIconsProvider);
    final labels = ref.watch(navLabelsProvider);
    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            shrinkWrap: true,
            itemBuilder:
                (_, i) => TextButton.icon(
                  onPressed: () {
                    ref.read(currentIndexProvider.notifier).state = i;
                    if (context.isMobile) Navigator.pop(context);
                  },
                  iconAlignment: IconAlignment.start,
                  style: TextButton.styleFrom(
                    backgroundColor:
                        i == index ? ColorConstants.primary : Colors.white,
                    alignment: Alignment.centerLeft,
                  ),
                  icon: Icon(
                    icons[i],
                    size: 16,
                    color: i == index ? Colors.white : ColorConstants.primary,
                  ),
                  label: Text(
                    labels[i],
                    style: typoConfig.textStyle.smallCaptionSubtitle2.copyWith(
                      color: i == index ? Colors.white : ColorConstants.primary,
                    ),
                  ),
                ),
            separatorBuilder: (_, i) => const SizedBox(height: 12),
            itemCount: labels.length,
          ),
        ),
        SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            onPressed: () async {
              var result = await GenericDialog(
                Strings.logout,
              ).present(context).then((val) => val ?? false);
              if (result) {
                ref.read(authProvider.notifier).logout();
              }
            },
            icon: Icon(Icons.logout, size: 16),
            label: Text(
              'Logout',
              style: typoConfig.textStyle.smallCaptionSubtitle2.copyWith(
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
