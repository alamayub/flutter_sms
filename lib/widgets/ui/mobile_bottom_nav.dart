import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../config/theme.dart';
import '../../config/translations.dart';
import '../../providers/locale_provider.dart';
import '../../providers/nav_providers.dart';
import '../calendar_switcher.dart';
import '../language_switcher.dart';
import '../theme_switcher.dart';
import 'app_bottom_sheet.dart';

/// Item definition for the mobile floating bottom navigation dock
class _MobileNavTab {
  final String id;
  final String labelKey;
  final String defaultLabel;
  final IconData icon;
  final IconData activeIcon;

  const _MobileNavTab({
    required this.id,
    required this.labelKey,
    required this.defaultLabel,
    required this.icon,
    required this.activeIcon,
  });
}

const _kMobileNavTabs = [
  _MobileNavTab(
    id: 'dashboard',
    labelKey: 'tab_dashboard',
    defaultLabel: 'Dashboard',
    icon: Icons.dashboard_outlined,
    activeIcon: Icons.dashboard_rounded,
  ),
  _MobileNavTab(
    id: 'students',
    labelKey: 'tab_students',
    defaultLabel: 'Students',
    icon: Icons.people_outline_rounded,
    activeIcon: Icons.people_rounded,
  ),
  _MobileNavTab(
    id: 'student_attendance',
    labelKey: 'tab_attendance',
    defaultLabel: 'Attendance',
    icon: Icons.how_to_reg_outlined,
    activeIcon: Icons.how_to_reg_rounded,
  ),
  _MobileNavTab(
    id: 'fee_collection',
    labelKey: 'tab_fees',
    defaultLabel: 'Fees',
    icon: Icons.receipt_long_outlined,
    activeIcon: Icons.receipt_long_rounded,
  ),
  _MobileNavTab(
    id: 'more_hub',
    labelKey: 'tab_more',
    defaultLabel: 'More',
    icon: Icons.grid_view_outlined,
    activeIcon: Icons.grid_view_rounded,
  ),
];

/// Floating frosted bottom navigation dock tailored for modern mobile UX.
/// Eliminates header clutter and provides immediate tactile thumb-reach access.
class MobileBottomNav extends ConsumerWidget {
  const MobileBottomNav({super.key});

  void _openMoreHub(BuildContext context, WidgetRef ref) {
    final navGroups = ref.read(navGroupsProvider);
    final flatItems = ref.read(flatNavItemsProvider);
    final currentLang = ref.read(localeProvider).locale.languageCode;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    AppBottomSheet.show(
      context: context,
      title: 'School Management Hub',
      subtitle: 'Navigate to any module or manage quick preferences',
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Quick Preferences Card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color:
                    isDark
                        ? theme.colorScheme.surfaceContainerHighest.withAlpha(
                          80,
                        )
                        : theme.colorScheme.surfaceContainerHighest.withAlpha(
                          120,
                        ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withAlpha(60),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    'Preferences',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  const ThemeSwitcherWidget(compact: true),
                  const SizedBox(width: 8),
                  const LanguageSwitcherWidget(compact: true),
                  const SizedBox(width: 8),
                  const CalendarSwitcherWidget(compact: true),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Categorized Modules
            for (final group in navGroups) ...[
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8, top: 8),
                child: Row(
                  children: [
                    if (group.icon != null) ...[
                      Icon(
                        group.icon,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      AppTranslations.text(
                            group.titleKey,
                            currentLang,
                          ).isNotEmpty
                          ? AppTranslations.text(group.titleKey, currentLang)
                          : group.defaultTitle,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: group.items.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 2.6,
                ),
                itemBuilder: (ctx, idx) {
                  final item = group.items[idx];
                  final title =
                      AppTranslations.text(
                            item.titleKey,
                            currentLang,
                          ).isNotEmpty
                          ? AppTranslations.text(item.titleKey, currentLang)
                          : item.defaultTitle;

                  return Material(
                    color:
                        isDark
                            ? theme.colorScheme.surfaceContainerHighest
                                .withAlpha(50)
                            : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        Navigator.of(context).pop();
                        ref
                            .read(selectedMenuIndexProvider.notifier)
                            .selectById(flatItems, item.id);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant.withAlpha(
                              50,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withAlpha(20),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                item.icon,
                                size: 17,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeItem = ref.watch(activeMenuItemProvider);
    final flatItems = ref.watch(flatNavItemsProvider);
    final currentLang = ref.watch(localeProvider).locale.languageCode;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    final dockBg =
        isDark
            ? const Color(0xFF0F172A).withAlpha(235)
            : Colors.white.withAlpha(235);

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                color: dockBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color:
                      isDark
                          ? Colors.white.withAlpha(25)
                          : Colors.black.withAlpha(15),
                  width: 1,
                ),
                boxShadow: AppShadows.floatingDock(isDark),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children:
                    _kMobileNavTabs.map((tab) {
                      final isMore = tab.id == 'more_hub';
                      final isSelected = !isMore && activeItem.id == tab.id;
                      final localizedLabel = AppTranslations.text(
                        tab.labelKey,
                        currentLang,
                      );
                      final label =
                          localizedLabel.isNotEmpty
                              ? localizedLabel
                              : tab.defaultLabel;

                      final activeColor = theme.colorScheme.primary;
                      final inactiveColor =
                          isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B);

                      return Expanded(
                        child: InkWell(
                          onTap: () {
                            if (isMore) {
                              _openMoreHub(context, ref);
                            } else {
                              ref
                                  .read(selectedMenuIndexProvider.notifier)
                                  .selectById(flatItems, tab.id);
                            }
                          },
                          splashColor: activeColor.withAlpha(25),
                          highlightColor: Colors.transparent,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              AnimatedContainer(
                                duration:
                                    reduceMotion
                                        ? Duration.zero
                                        : AppMotion.snappy,
                                curve: AppMotion.snappyCurve,
                                padding: EdgeInsets.symmetric(
                                  horizontal: isSelected ? 12 : 6,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      isSelected
                                          ? activeColor.withAlpha(
                                            isDark ? 40 : 25,
                                          )
                                          : Colors.transparent,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(
                                  isSelected ? tab.activeIcon : tab.icon,
                                  size: 21,
                                  color:
                                      isSelected ? activeColor : inactiveColor,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                label,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight:
                                      isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                  color:
                                      isSelected ? activeColor : inactiveColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
