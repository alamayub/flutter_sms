import 'package:flutter/material.dart';
import '../../config/theme.dart';

/// Modern SaaS segmented pill tab bar with container background and sliding pill indicator.
class AppPillTabBar extends StatelessWidget implements PreferredSizeWidget {
  final TabController? controller;
  final List<Widget> tabs;
  final bool isScrollable;
  final TabAlignment? tabAlignment;
  final ValueChanged<int>? onTap;
  final double height;
  final EdgeInsetsGeometry padding;

  const AppPillTabBar({
    super.key,
    this.controller,
    required this.tabs,
    this.isScrollable = false,
    this.tabAlignment,
    this.onTap,
    this.height = 42.0,
    this.padding = const EdgeInsets.all(4.0),
  });

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final containerColor =
        isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final activeColor = isDark ? AppTheme.primaryLight : AppTheme.primaryColor;

    return Container(
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: containerColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: TabBar(
        controller: controller,
        tabs: tabs,
        isScrollable: isScrollable,
        tabAlignment:
            tabAlignment ?? (isScrollable ? TabAlignment.start : null),
        onTap: onTap,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: activeColor,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: [
            BoxShadow(
              color: activeColor.withAlpha(50),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        labelColor: Colors.white,
        unselectedLabelColor:
            isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
        labelStyle: AppTypography.tab(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: AppTypography.tab(
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// Standardized underline tab bar with crisp accent line and typography tokens.
class AppUnderlineTabBar extends StatelessWidget
    implements PreferredSizeWidget {
  final TabController? controller;
  final List<Widget> tabs;
  final bool isScrollable;
  final TabAlignment? tabAlignment;
  final ValueChanged<int>? onTap;

  const AppUnderlineTabBar({
    super.key,
    this.controller,
    required this.tabs,
    this.isScrollable = false,
    this.tabAlignment,
    this.onTap,
  });

  @override
  Size get preferredSize => const Size.fromHeight(46.0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final activeColor = isDark ? AppTheme.primaryLight : AppTheme.primaryColor;

    return TabBar(
      controller: controller,
      tabs: tabs,
      isScrollable: isScrollable,
      tabAlignment: tabAlignment ?? (isScrollable ? TabAlignment.start : null),
      onTap: onTap,
      indicatorColor: activeColor,
      indicatorWeight: 2.5,
      indicatorSize: TabBarIndicatorSize.tab,
      dividerColor: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
      labelColor: activeColor,
      unselectedLabelColor:
          isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
      labelStyle: AppTypography.tab(fontSize: 14, fontWeight: FontWeight.w600),
      unselectedLabelStyle: AppTypography.tab(
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}
