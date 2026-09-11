import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../config/responsive.dart';
import '../config/theme.dart';
import '../config/translations.dart';
import '../providers/calendar_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/nav_providers.dart';
import '../utils/date_time_utils.dart';
import '../widgets/calendar_switcher.dart';
import '../widgets/language_switcher.dart';
import '../widgets/sidebar_widget.dart';
import '../widgets/theme_switcher.dart';
import '../widgets/ui/mobile_bottom_nav.dart';

class RootScreen extends ConsumerWidget {
  const RootScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeItem = ref.watch(activeMenuItemProvider);
    final isDesktop = context.isDesktop;
    final isMobile = context.isMobile;
    final currentLang = ref.watch(localeProvider);
    final currentCalendar = ref.watch(calendarProvider);
    final langCode = currentLang.locale.languageCode;
    final isNepali = langCode == 'ne';
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    final localizedTitle = AppTranslations.text(activeItem.titleKey, langCode);
    final displayTitle =
        localizedTitle.isNotEmpty ? localizedTitle : activeItem.defaultTitle;

    // Desktop/Tablet full switchers & date capsule
    final desktopAppBarActions = [
      Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color:
              isDark
                  ? theme.colorScheme.surfaceContainerHighest.withAlpha(90)
                  : theme.colorScheme.surfaceContainerHighest.withAlpha(120),
          borderRadius: AppRadius.roundedFull,
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withAlpha(80),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ThemeSwitcherWidget(compact: true),
            const SizedBox(width: 4),
            const LanguageSwitcherWidget(compact: true),
            const SizedBox(width: 4),
            const CalendarSwitcherWidget(compact: true),
            const SizedBox(width: 8),
            // Divider
            Container(
              height: 16,
              width: 1,
              color: theme.colorScheme.outlineVariant.withAlpha(100),
            ),
            const SizedBox(width: 8),
            // Date badge
            Icon(
              Icons.today_rounded,
              size: 13,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 5),
            Text(
              DateTimeUtils.formatDateByMode(
                DateTime.now(),
                mode: currentCalendar,
                inNepaliScript: isNepali,
              ),
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
                letterSpacing: 0.1,
              ),
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
      const SizedBox(width: 8),
    ];

    // Streamlined mobile app bar actions (compact theme + language)
    final mobileAppBarActions = [
      const ThemeSwitcherWidget(compact: true),
      const SizedBox(width: 4),
      const LanguageSwitcherWidget(compact: true),
      const SizedBox(width: 8),
    ];

    final pageBody = AnimatedSwitcher(
      duration: reduceMotion ? Duration.zero : AppMotion.snappy,
      switchInCurve: AppMotion.snappyCurve,
      switchOutCurve: Curves.easeIn,
      child: KeyedSubtree(
        key: ValueKey<String>(activeItem.id),
        child: activeItem.widget,
      ),
    );

    if (isDesktop) {
      return Scaffold(
        body: Row(
          children: [
            const SidebarWidget(isPermanent: true),
            Expanded(
              child: Scaffold(
                appBar: AppBar(
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  backgroundColor: theme.colorScheme.surface,
                  title: Text(
                    displayTitle,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                  bottom: PreferredSize(
                    preferredSize: const Size.fromHeight(1),
                    child: Container(
                      color: theme.colorScheme.outlineVariant.withAlpha(70),
                      height: 1,
                    ),
                  ),
                  actions: desktopAppBarActions,
                ),
                body: pageBody,
              ),
            ),
          ],
        ),
      );
    }

    // Mobile layout with floating frosted bottom nav & uncrowded app bar
    if (isMobile) {
      return Scaffold(
        appBar: AppBar(
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: theme.colorScheme.surface,
          title: Text(
            displayTitle,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(
              color: theme.colorScheme.outlineVariant.withAlpha(70),
              height: 1,
            ),
          ),
          actions: mobileAppBarActions,
        ),
        drawer: const SidebarWidget(isPermanent: false),
        body: pageBody,
        bottomNavigationBar: const MobileBottomNav(),
      );
    }

    // Tablet layout
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: theme.colorScheme.surface,
        title: Text(
          displayTitle,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: theme.colorScheme.outlineVariant.withAlpha(70),
            height: 1,
          ),
        ),
        actions: desktopAppBarActions,
      ),
      drawer: const SidebarWidget(isPermanent: false),
      body: pageBody,
    );
  }
}
