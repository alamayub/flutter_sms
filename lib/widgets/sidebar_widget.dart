import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../config/theme.dart';
import '../config/translations.dart';
import '../providers/calendar_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/nav_providers.dart';
import '../utils/date_time_utils.dart';
import '../providers/auth_provider.dart';
import '../providers/school_profile_provider.dart';
import 'calendar_switcher.dart';
import 'language_switcher.dart';
import 'theme_switcher.dart';

class SidebarWidget extends ConsumerWidget {
  final bool isPermanent;

  const SidebarWidget({super.key, this.isPermanent = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(navGroupsProvider);
    final flatItems = ref.watch(flatNavItemsProvider);
    final selectedIndex = ref.watch(selectedMenuIndexProvider);
    final currentLang = ref.watch(localeProvider);
    final currentCalendar = ref.watch(calendarProvider);
    final school = ref.watch(schoolProfileProvider);
    final langCode = currentLang.locale.languageCode;
    final isNepali = langCode == 'ne';
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final content = Column(
      children: [
        // Modern Institutional Brand Header
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient:
                isDark
                    ? LinearGradient(
                      colors: [
                        theme.colorScheme.surface,
                        theme.colorScheme.surfaceContainerHighest,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                    : AppGradients.primary,
            border: Border(
              bottom: BorderSide(
                color:
                    isDark
                        ? theme.colorScheme.outlineVariant.withAlpha(60)
                        : Colors.white.withAlpha(40),
                width: 1,
              ),
            ),
          ),
          padding: EdgeInsets.fromLTRB(16, isPermanent ? 24 : 44, 16, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color:
                          isDark
                              ? theme.colorScheme.primary.withAlpha(40)
                              : Colors.white,
                      borderRadius: AppRadius.roundedLg,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(35),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        Icons.school_rounded,
                        color:
                            isDark
                                ? theme.colorScheme.primary
                                : AppTheme.primaryColor,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          school.name.isNotEmpty
                              ? school.name
                              : AppTranslations.text('app_title', langCode),
                          style: TextStyle(
                            color:
                                isDark
                                    ? theme.colorScheme.onSurface
                                    : Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFF10B981),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                AppTranslations.text('offline_mode', langCode),
                                style: TextStyle(
                                  color:
                                      isDark
                                          ? theme.colorScheme.onSurfaceVariant
                                          : Colors.white.withAlpha(210),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Institutional Calendar Pill Tag
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4.5,
                ),
                decoration: BoxDecoration(
                  color:
                      isDark
                          ? theme.colorScheme.primary.withAlpha(20)
                          : Colors.white.withAlpha(30),
                  borderRadius: AppRadius.roundedFull,
                  border: Border.all(
                    color:
                        isDark
                            ? theme.colorScheme.primary.withAlpha(45)
                            : Colors.white.withAlpha(45),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 12,
                      color: isDark ? theme.colorScheme.primary : Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      DateTimeUtils.formatDateByMode(
                        DateTime.now(),
                        mode: currentCalendar,
                        inNepaliScript: isNepali,
                      ),
                      style: TextStyle(
                        color:
                            isDark ? theme.colorScheme.onSurface : Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Navigation Menu Groups & Items
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            children: [
              for (final group in groups) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 14, 12, 6),
                  child: Row(
                    children: [
                      if (group.icon != null) ...[
                        Icon(
                          group.icon,
                          size: 13,
                          color: theme.colorScheme.primary.withAlpha(180),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        AppTranslations.text(
                          group.titleKey,
                          langCode,
                        ).toUpperCase(),
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: theme.colorScheme.onSurfaceVariant.withAlpha(
                            170,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                for (final item in group.items) ...[
                  Builder(
                    builder: (context) {
                      final itemFlatIndex = flatItems.indexOf(item);
                      final isSelected = itemFlatIndex == selectedIndex;
                      final title = AppTranslations.text(
                        item.titleKey,
                        langCode,
                      );

                      return _SidebarNavItem(
                        icon: item.icon,
                        label: title.isNotEmpty ? title : item.defaultTitle,
                        isSelected: isSelected,
                        onTap: () {
                          ref
                              .read(selectedMenuIndexProvider.notifier)
                              .setIndex(itemFlatIndex);
                          if (!isPermanent && Navigator.of(context).canPop()) {
                            Navigator.of(context).pop();
                          }
                        },
                      );
                    },
                  ),
                ],
                const SizedBox(height: 4),
              ],
            ],
          ),
        ),

        // Bottom Footer: Administrator Info & Control Switchers
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color:
                isDark
                    ? theme.colorScheme.surfaceContainerLow
                    : theme.colorScheme.surfaceContainerHighest.withAlpha(80),
            border: Border(
              top: BorderSide(
                color: theme.colorScheme.outlineVariant.withAlpha(70),
                width: 1,
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // User Admin Profile Pill
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: AppRadius.roundedLg,
                  onTap: () {
                    ref
                        .read(selectedMenuIndexProvider.notifier)
                        .selectById(flatItems, 'school_profile');
                    if (!isPermanent && Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isDark ? theme.colorScheme.surface : Colors.white,
                      borderRadius: AppRadius.roundedLg,
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant.withAlpha(70),
                        width: 0.8,
                      ),
                      boxShadow:
                          isDark ? AppShadows.cardDark : AppShadows.cardLight,
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 15,
                          backgroundColor: theme.colorScheme.primary.withAlpha(
                            30,
                          ),
                          child: Text(
                            school.adminUsername.isNotEmpty
                                ? school.adminUsername[0].toUpperCase()
                                : 'A',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                school.adminUsername.isNotEmpty
                                    ? school.adminUsername
                                    : 'Administrator',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurface,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'School Profile',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.logout_rounded, size: 15),
                          tooltip: 'Sign Out',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 26,
                            minHeight: 26,
                          ),
                          onPressed: () {
                            ref.read(authStateProvider.notifier).logout();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Compact Switcher Controls Row
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? theme.colorScheme.surface : Colors.white,
                  borderRadius: AppRadius.roundedMd,
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withAlpha(60),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: const [
                    ThemeSwitcherWidget(compact: true),
                    LanguageSwitcherWidget(compact: true),
                    CalendarSwitcherWidget(compact: true),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );

    if (isPermanent) {
      return Container(
        width: 260,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(
            right: BorderSide(
              color: theme.colorScheme.outlineVariant.withAlpha(80),
              width: 1,
            ),
          ),
        ),
        child: content,
      );
    }

    return Drawer(
      backgroundColor: theme.colorScheme.surface,
      elevation: 0,
      child: content,
    );
  }
}

/// Interactive navigation pill item with hover effect and left glow bar
class _SidebarNavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SidebarNavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_SidebarNavItem> createState() => _SidebarNavItemState();
}

class _SidebarNavItemState extends State<_SidebarNavItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    Color bg;
    if (widget.isSelected) {
      bg = theme.colorScheme.primary;
    } else if (_isHovered) {
      bg = theme.colorScheme.primary.withAlpha(isDark ? 28 : 18);
    } else {
      bg = Colors.transparent;
    }

    Color fg;
    if (widget.isSelected) {
      fg = Colors.white;
    } else if (_isHovered) {
      fg = theme.colorScheme.primary;
    } else {
      fg = theme.colorScheme.onSurfaceVariant;
    }

    final shadow =
        widget.isSelected
            ? AppShadows.glow(theme.colorScheme.primary, opacity: 0.28, blur: 8)
            : null;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        if (!reduceMotion && mounted) setState(() => _isHovered = true);
      },
      onExit: (_) {
        if (!reduceMotion && mounted) setState(() => _isHovered = false);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: AppRadius.roundedLg,
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: AppMotion.snappy,
              curve: AppMotion.snappyCurve,
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 7.5,
              ),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: AppRadius.roundedLg,
                boxShadow: shadow,
              ),
              child: Row(
                children: [
                  Icon(widget.icon, size: 16, color: fg),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.label,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight:
                            widget.isSelected
                                ? FontWeight.w600
                                : FontWeight.w500,
                        color: fg,
                        letterSpacing: 0.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (widget.isSelected)
                    Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
