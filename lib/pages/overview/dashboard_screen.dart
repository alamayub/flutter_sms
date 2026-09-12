import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nepali_utils/nepali_utils.dart';
import '../../config/theme.dart';
import '../../config/translations.dart';
import '../../models/calendar_mode.dart';
import '../../models/school_profile.dart';
import '../../providers/calendar_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/nav_providers.dart';
import '../../providers/school_profile_provider.dart';
import '../../utils/date_time_utils.dart';
import '../../widgets/ui/app_badge.dart';
import '../../widgets/ui/app_card.dart';
import '../../widgets/ui/app_empty_state.dart';
import '../../widgets/ui/app_skeleton.dart';
import '../../widgets/ui/app_vector_graphics.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  String _formatDateDual(DateTime date, CalendarMode mode, String lang) {
    final adStr = DateFormat('yyyy-MM-dd (EEE)').format(date);
    final bs = date.toNepaliDateTime();
    final bsMonth =
        lang == 'ne'
            ? DateTimeUtils.bsMonthNamesNe[bs.month - 1]
            : DateTimeUtils.bsMonthNamesEn[bs.month - 1];
    final bsStr = '${bs.year} $bsMonth ${bs.day}';

    if (mode == CalendarMode.bs) {
      return '$bsStr BS • $adStr AD';
    } else {
      return '$adStr AD • $bsStr BS';
    }
  }

  void _navigateToMenu(WidgetRef ref, String menuItemId) {
    final flatItems = ref.read(flatNavItemsProvider);
    ref
        .read(selectedMenuIndexProvider.notifier)
        .selectById(flatItems, menuItemId);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final lang = ref.watch(localeProvider).locale.languageCode;
    final calendarMode = ref.watch(calendarProvider);
    final metricsAsync = ref.watch(dashboardMetricsStreamProvider);
    final school = ref.watch(schoolProfileProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 1000;
        final isTablet = constraints.maxWidth >= 650 && !isDesktop;

        return Scaffold(
          body: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(dashboardMetricsStreamProvider);
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // 1. Executive Welcome & Header Banner
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                    child: _buildWelcomeHeader(
                      context,
                      theme,
                      lang,
                      calendarMode,
                      metricsAsync.asData?.value,
                      school,
                    ),
                  ),
                ),

                // 2. Core 4 KPI Metric Cards
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    child: metricsAsync.when(
                      data:
                          (metrics) => _buildKpiRow(
                            context,
                            theme,
                            lang,
                            metrics,
                            isDesktop,
                            isTablet,
                            ref,
                          ),
                      loading: () => _buildKpiLoadingRow(isDesktop, isTablet),
                      error:
                          (err, _) => Card(
                            color: theme.colorScheme.errorContainer,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                'Error loading metrics: $err',
                                style: TextStyle(
                                  color: theme.colorScheme.onErrorContainer,
                                ),
                              ),
                            ),
                          ),
                    ),
                  ),
                ),

                // 3. Quick Action Hub
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    child: _buildQuickActionsSection(
                      context,
                      theme,
                      lang,
                      ref,
                      isDesktop,
                    ),
                  ),
                ),

                // 4. Detailed Analytics & Operations Breakdown (2-Column Layout)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    child: metricsAsync.when(
                      data: (metrics) {
                        if (isDesktop) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Left Column: Class Strength & Attendance Pulse (flex: 6)
                              Expanded(
                                flex: 6,
                                child: Column(
                                  children: [
                                    _buildClassEnrollmentCard(
                                      context,
                                      theme,
                                      lang,
                                      metrics,
                                    ),
                                    const SizedBox(height: 16),
                                    _buildAttendancePulseCard(
                                      context,
                                      theme,
                                      lang,
                                      metrics,
                                      ref,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 20),
                              // Right Column: Financial Health, Recent Transactions & Upcoming Exams (flex: 4)
                              Expanded(
                                flex: 4,
                                child: Column(
                                  children: [
                                    _buildFinancialHealthCard(
                                      context,
                                      theme,
                                      lang,
                                      metrics,
                                      ref,
                                    ),
                                    const SizedBox(height: 16),
                                    _buildRecentTransactionsCard(
                                      context,
                                      theme,
                                      lang,
                                      metrics,
                                      ref,
                                    ),
                                    const SizedBox(height: 16),
                                    _buildUpcomingExamsCard(
                                      context,
                                      theme,
                                      lang,
                                      metrics,
                                      ref,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        } else {
                          // Tablet / Mobile: Stacked
                          return Column(
                            children: [
                              _buildClassEnrollmentCard(
                                context,
                                theme,
                                lang,
                                metrics,
                              ),
                              const SizedBox(height: 16),
                              _buildAttendancePulseCard(
                                context,
                                theme,
                                lang,
                                metrics,
                                ref,
                              ),
                              const SizedBox(height: 16),
                              _buildFinancialHealthCard(
                                context,
                                theme,
                                lang,
                                metrics,
                                ref,
                              ),
                              const SizedBox(height: 16),
                              _buildRecentTransactionsCard(
                                context,
                                theme,
                                lang,
                                metrics,
                                ref,
                              ),
                              const SizedBox(height: 16),
                              _buildUpcomingExamsCard(
                                context,
                                theme,
                                lang,
                                metrics,
                                ref,
                              ),
                            ],
                          );
                        }
                      },
                      loading:
                          () => Column(
                            children: const [
                              AppSkeleton.card(height: 200),
                              SizedBox(height: 16),
                              AppSkeleton.card(height: 180),
                            ],
                          ),
                      error: (_, _) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // 1. WELCOME & INSTITUTIONAL HEADER
  // ===========================================================================
  Widget _buildWelcomeHeader(
    BuildContext context,
    ThemeData theme,
    String lang,
    CalendarMode mode,
    DashboardMetrics? metrics,
    SchoolProfile school,
  ) {
    final now = DateTime.now();
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < 700;

    final crestWidget = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: AppGradients.primary,
        shape: BoxShape.circle,
        boxShadow: AppShadows.glow(
          theme.colorScheme.primary,
          opacity: 0.35,
          blur: 10,
        ),
      ),
      child: const Icon(
        Icons.account_balance_rounded,
        size: 28,
        color: Colors.white,
      ),
    );

    final titleColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            Text(
              school.name.isNotEmpty
                  ? school.name.toUpperCase()
                  : 'PRAGYAN ACADEMY',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: theme.colorScheme.primary,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withAlpha(isDark ? 35 : 22),
                borderRadius: AppRadius.roundedFull,
                border: Border.all(
                  color: theme.colorScheme.primary.withAlpha(50),
                  width: 0.8,
                ),
              ),
              child: Text(
                metrics?.activeAcademicYearName ?? 'Session 2026 - 2027',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          AppTranslations.text('welcome_admin', lang),
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            fontSize: isCompact ? 22 : 28,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          AppTranslations.text('dashboard_subtitle', lang),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: isCompact ? 13 : 14,
          ),
        ),
      ],
    );

    final datePill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withAlpha(isDark ? 220 : 240),
        borderRadius: AppRadius.roundedLg,
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withAlpha(90),
          width: 0.8,
        ),
        boxShadow: isDark ? AppShadows.cardDark : AppShadows.cardLight,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.calendar_today_rounded,
            size: 14,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              _formatDateDual(now, mode, lang),
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 11.5,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );

    return AppCard(
      depth3d: true,
      padding: EdgeInsets.zero,
      child: AuroraMeshBackground(
        opacity: isDark ? 0.6 : 0.4,
        child: Padding(
          padding: EdgeInsets.all(isCompact ? 16 : 22),
          child:
              isCompact
                  ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          crestWidget,
                          const SizedBox(width: 14),
                          Expanded(child: titleColumn),
                        ],
                      ),
                      const SizedBox(height: 14),
                      datePill,
                    ],
                  )
                  : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      crestWidget,
                      const SizedBox(width: 16),
                      Expanded(child: titleColumn),
                      const SizedBox(width: 16),
                      datePill,
                    ],
                  ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 2. CORE 4 KPI METRIC CARDS
  // ===========================================================================
  Widget _buildKpiRow(
    BuildContext context,
    ThemeData theme,
    String lang,
    DashboardMetrics metrics,
    bool isDesktop,
    bool isTablet,
    WidgetRef ref,
  ) {
    final cards = [
      // 1. Students Card
      _buildSingleKpiCard(
        context,
        theme,
        title: AppTranslations.text('total_students_card', lang),
        value: '${metrics.totalStudents}',
        subtitle:
            '${metrics.activeStudents} ${AppTranslations.text('active_enrolled', lang)}',
        extraText:
            'Boys: ${metrics.maleStudents} • Girls: ${metrics.femaleStudents}',
        icon: Icons.school_rounded,
        accentColor: const Color(0xFF2563EB), // Royal Blue
        badgeText: 'Active',
        onTap: () => _navigateToMenu(ref, 'students'),
      ),

      // 2. Employees Card
      _buildSingleKpiCard(
        context,
        theme,
        title: AppTranslations.text('faculty_and_staff', lang),
        value: '${metrics.totalEmployees}',
        subtitle:
            '${metrics.teachersCount} ${AppTranslations.text('teachers_count', lang)} • ${metrics.staffCount} ${AppTranslations.text('staff_count', lang)}',
        extraText:
            '${metrics.totalClasses} Classes • ${metrics.totalSections} Sections',
        icon: Icons.badge_rounded,
        accentColor: const Color(0xFF059669), // Emerald Green
        badgeText: 'On Roll',
        onTap: () => _navigateToMenu(ref, 'employees'),
      ),

      // 3. Attendance Today Card
      _buildSingleKpiCard(
        context,
        theme,
        title: AppTranslations.text('today_attendance_summary', lang),
        value:
            '${metrics.studentAttendanceToday.percentage.toStringAsFixed(1)}%',
        subtitle:
            '${metrics.studentAttendanceToday.present} / ${metrics.studentAttendanceToday.total} ${AppTranslations.text('present_students', lang)}',
        extraText:
            'Staff Attendance: ${metrics.employeeAttendanceToday.percentage.toStringAsFixed(1)}%',
        icon: Icons.how_to_reg_rounded,
        accentColor: const Color(0xFF7C3AED), // Purple
        badgeText: 'Today',
        onTap: () => _navigateToMenu(ref, 'student_attendance'),
      ),

      // 4. Financial Health Card
      _buildSingleKpiCard(
        context,
        theme,
        title: AppTranslations.text('financial_overview', lang),
        value: 'NPR ${metrics.feeCollected.toStringAsFixed(0)}',
        subtitle:
            '${AppTranslations.text('fees_collected_label', lang)} • NPR ${metrics.feePending.toStringAsFixed(0)} Due',
        extraText: 'Expenses: NPR ${metrics.expensesTotal.toStringAsFixed(0)}',
        icon: Icons.account_balance_wallet_rounded,
        accentColor: const Color(0xFFD97706), // Amber
        badgeText: 'Fiscal',
        onTap: () => _navigateToMenu(ref, 'fee_collection'),
      ),
    ];

    if (isDesktop) {
      return Row(
        children:
            cards
                .map(
                  (c) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: c,
                    ),
                  ),
                )
                .toList(),
      );
    } else if (isTablet || MediaQuery.sizeOf(context).width >= 400) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(child: cards[0]),
              const SizedBox(width: 12),
              Expanded(child: cards[1]),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: cards[2]),
              const SizedBox(width: 12),
              Expanded(child: cards[3]),
            ],
          ),
        ],
      );
    } else {
      return Column(
        children:
            cards
                .map(
                  (c) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: c,
                  ),
                )
                .toList(),
      );
    }
  }

  Widget _buildKpiLoadingRow(bool isDesktop, bool isTablet) {
    if (isDesktop) {
      return Row(
        children: List.generate(
          4,
          (index) => const Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: AppSkeleton.card(height: 125),
            ),
          ),
        ),
      );
    } else if (isTablet) {
      return Column(
        children: const [
          Row(
            children: [
              Expanded(child: AppSkeleton.card(height: 125)),
              SizedBox(width: 12),
              Expanded(child: AppSkeleton.card(height: 125)),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: AppSkeleton.card(height: 125)),
              SizedBox(width: 12),
              Expanded(child: AppSkeleton.card(height: 125)),
            ],
          ),
        ],
      );
    } else {
      return Column(
        children: List.generate(
          4,
          (index) => const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: AppSkeleton.card(height: 125),
          ),
        ),
      );
    }
  }

  Widget _buildSingleKpiCard(
    BuildContext context,
    ThemeData theme, {
    required String title,
    required String value,
    required String subtitle,
    required String extraText,
    required IconData icon,
    required Color accentColor,
    required String badgeText,
    required VoidCallback onTap,
  }) {
    final isDark = theme.brightness == Brightness.dark;

    return AppCard(
      accentColor: accentColor,
      depth3d: true,
      isHoverable: true,
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Stack(
        children: [
          GeometricCardDecor(
            color: accentColor.withAlpha(isDark ? 28 : 16),
            size: 85,
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: accentColor.withAlpha(25),
                      borderRadius: AppRadius.roundedMd,
                      border: Border.all(
                        color: accentColor.withAlpha(45),
                        width: 0.8,
                      ),
                    ),
                    child: Icon(icon, size: 18, color: accentColor),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                value,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                extraText,
                style: TextStyle(
                  fontSize: 10.5,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 3. QUICK ACTIONS HUB
  // ===========================================================================
  Widget _buildQuickActionsSection(
    BuildContext context,
    ThemeData theme,
    String lang,
    WidgetRef ref,
    bool isDesktop,
  ) {
    final actions = [
      (
        id: 'student_attendance',
        title: AppTranslations.text('take_student_attendance', lang),
        icon: Icons.how_to_reg_rounded,
        color: const Color(0xFF2563EB),
      ),
      (
        id: 'employee_attendance',
        title: AppTranslations.text('take_employee_attendance', lang),
        icon: Icons.badge_outlined,
        color: const Color(0xFF059669),
      ),
      (
        id: 'fee_collection',
        title: AppTranslations.text('collect_fees_action', lang),
        icon: Icons.payments_rounded,
        color: const Color(0xFFD97706),
      ),
      (
        id: 'students',
        title: AppTranslations.text('enroll_student_action', lang),
        icon: Icons.person_add_rounded,
        color: const Color(0xFF7C3AED),
      ),
      (
        id: 'employees',
        title: AppTranslations.text('add_employee_action', lang),
        icon: Icons.group_add_rounded,
        color: const Color(0xFF0284C7),
      ),
      (
        id: 'expense_records',
        title: AppTranslations.text('record_expense_action', lang),
        icon: Icons.receipt_long_rounded,
        color: const Color(0xFFDC2626),
      ),
      (
        id: 'student_id_cards',
        title: AppTranslations.text('print_student_id_action', lang),
        icon: Icons.credit_card_rounded,
        color: const Color(0xFF4F46E5),
      ),
      (
        id: 'employee_id_cards',
        title: AppTranslations.text('print_employee_id_action', lang),
        icon: Icons.assignment_ind_rounded,
        color: const Color(0xFF0D9488),
      ),
      (
        id: 'exam_results',
        title: AppTranslations.text('exam_results_action', lang),
        icon: Icons.grade_rounded,
        color: const Color(0xFFE11D48),
      ),
      (
        id: 'timetable',
        title: AppTranslations.text('timetable_action', lang),
        icon: Icons.schedule_rounded,
        color: const Color(0xFFEA580C),
      ),
    ];

    return AppCard(
      isHoverable: false,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withAlpha(25),
                  borderRadius: AppRadius.roundedSm,
                ),
                child: Icon(
                  Icons.bolt_rounded,
                  size: 17,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                AppTranslations.text('quick_actions_title', lang),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children:
                actions.map((act) {
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _navigateToMenu(ref, act.id),
                      borderRadius: AppRadius.roundedMd,
                      mouseCursor: SystemMouseCursors.click,
                      child: Container(
                        width: isDesktop ? 165 : 140,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: act.color.withAlpha(16),
                          borderRadius: AppRadius.roundedMd,
                          border: Border.all(
                            color: act.color.withAlpha(55),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(act.icon, size: 17, color: act.color),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                act.title,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurface,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 4. CLASS ENROLLMENT CARD
  // ===========================================================================
  Widget _buildClassEnrollmentCard(
    BuildContext context,
    ThemeData theme,
    String lang,
    DashboardMetrics metrics,
  ) {
    final entries = metrics.classStudentCounts.entries.toList();
    final maxCount = entries.fold<int>(
      1,
      (max, e) => e.value > max ? e.value : max,
    );

    return AppCard(
      isHoverable: false,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withAlpha(25),
                        borderRadius: AppRadius.roundedSm,
                      ),
                      child: Icon(
                        Icons.bar_chart_rounded,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        AppTranslations.text(
                          'class_enrollment_distribution',
                          lang,
                        ),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AppBadge.primary(
                '${metrics.totalStudents} ${AppTranslations.text('students_count_suffix', lang)}',
                size: AppBadgeSize.sm,
              ),
            ],
          ),
          const SizedBox(height: 18),

          if (entries.isEmpty)
            const AppEmptyState(
              isCompact: true,
              title: 'No class enrollment data available',
              icon: Icons.school_outlined,
            )
          else
            Column(
              children:
                  entries.map((entry) {
                    final ratio =
                        maxCount > 0
                            ? (entry.value / maxCount).clamp(0.0, 1.0)
                            : 0.0;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5.5),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 84,
                            child: Text(
                              entry.key,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: AppRadius.roundedFull,
                              child: LinearProgressIndicator(
                                value: ratio,
                                minHeight: 8,
                                backgroundColor:
                                    theme.colorScheme.surfaceContainerHighest,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  theme.colorScheme.primary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 40,
                            child: Text(
                              '${entry.value}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.primary,
                              ),
                              textAlign: TextAlign.end,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 5. ATTENDANCE PULSE CARD
  // ===========================================================================
  Widget _buildAttendancePulseCard(
    BuildContext context,
    ThemeData theme,
    String lang,
    DashboardMetrics metrics,
    WidgetRef ref,
  ) {
    return AppCard(
      isHoverable: false,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C3AED).withAlpha(25),
                        borderRadius: AppRadius.roundedSm,
                      ),
                      child: const Icon(
                        Icons.pie_chart_outline_rounded,
                        size: 18,
                        color: Color(0xFF7C3AED),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        AppTranslations.text('today_attendance_summary', lang),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => _navigateToMenu(ref, 'attendance_report'),
                child: Text(AppTranslations.text('view_all', lang)),
              ),
            ],
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              // Student Attendance Pulse Box
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withAlpha(
                      50,
                    ),
                    borderRadius: AppRadius.roundedLg,
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withAlpha(80),
                      width: 0.8,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            AppTranslations.text('students', lang),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          AppBadge.primary(
                            '${metrics.studentAttendanceToday.percentage.toStringAsFixed(1)}%',
                            size: AppBadgeSize.sm,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildMiniAttendanceStat(
                            'Present',
                            '${metrics.studentAttendanceToday.present}',
                            const Color(0xFF10B981),
                          ),
                          _buildMiniAttendanceStat(
                            'Absent',
                            '${metrics.studentAttendanceToday.absent}',
                            const Color(0xFFEF4444),
                          ),
                          _buildMiniAttendanceStat(
                            'Late',
                            '${metrics.studentAttendanceToday.late}',
                            const Color(0xFFF59E0B),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Employee Attendance Pulse Box
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withAlpha(
                      50,
                    ),
                    borderRadius: AppRadius.roundedLg,
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withAlpha(80),
                      width: 0.8,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            AppTranslations.text('staff', lang),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          AppBadge.info(
                            '${metrics.employeeAttendanceToday.percentage.toStringAsFixed(1)}%',
                            size: AppBadgeSize.sm,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildMiniAttendanceStat(
                            'Present',
                            '${metrics.employeeAttendanceToday.present}',
                            const Color(0xFF10B981),
                          ),
                          _buildMiniAttendanceStat(
                            'Absent',
                            '${metrics.employeeAttendanceToday.absent}',
                            const Color(0xFFEF4444),
                          ),
                          _buildMiniAttendanceStat(
                            'Late',
                            '${metrics.employeeAttendanceToday.late}',
                            const Color(0xFFF59E0B),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniAttendanceStat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10.5,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // 6. FINANCIAL HEALTH & CASHFLOW CARD
  // ===========================================================================
  Widget _buildFinancialHealthCard(
    BuildContext context,
    ThemeData theme,
    String lang,
    DashboardMetrics metrics,
    WidgetRef ref,
  ) {
    final netCashflow = metrics.feeCollected - metrics.expensesTotal;

    return AppCard(
      accentColor: const Color(0xFFD97706),
      isHoverable: false,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD97706).withAlpha(25),
                        borderRadius: AppRadius.roundedSm,
                      ),
                      child: const Icon(
                        Icons.savings_outlined,
                        size: 18,
                        color: Color(0xFFD97706),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        AppTranslations.text('financial_overview', lang),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => _navigateToMenu(ref, 'fee_collection'),
                child: Text(AppTranslations.text('view_all', lang)),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Financial Summary Rows
          _buildFinancialRow(
            'Total Fees Invoiced',
            'NPR ${metrics.totalInvoiced.toStringAsFixed(0)}',
            theme.colorScheme.onSurface,
          ),
          const SizedBox(height: 7),
          _buildFinancialRow(
            'Collected Fees',
            'NPR ${metrics.feeCollected.toStringAsFixed(0)}',
            const Color(0xFF10B981),
          ),
          const SizedBox(height: 7),
          _buildFinancialRow(
            'Outstanding / Due Fees',
            'NPR ${metrics.feePending.toStringAsFixed(0)}',
            const Color(0xFFF59E0B),
          ),
          const SizedBox(height: 7),
          _buildFinancialRow(
            'Operating Expenses',
            'NPR ${metrics.expensesTotal.toStringAsFixed(0)}',
            const Color(0xFFEF4444),
          ),
          const Divider(height: 20),
          _buildFinancialRow(
            'Net Operating Balance',
            'NPR ${netCashflow.toStringAsFixed(0)}',
            netCashflow >= 0
                ? const Color(0xFF10B981)
                : const Color(0xFFEF4444),
            isBold: true,
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialRow(
    String label,
    String value,
    Color color, {
    bool isBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
              color: Colors.grey.shade700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // 7. RECENT TRANSACTIONS CARD
  // ===========================================================================
  Widget _buildRecentTransactionsCard(
    BuildContext context,
    ThemeData theme,
    String lang,
    DashboardMetrics metrics,
    WidgetRef ref,
  ) {
    return AppCard(
      isHoverable: false,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withAlpha(25),
                        borderRadius: AppRadius.roundedSm,
                      ),
                      child: Icon(
                        Icons.receipt_long_outlined,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        AppTranslations.text('recent_fee_transactions', lang),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => _navigateToMenu(ref, 'fee_collection'),
                child: Text(AppTranslations.text('view_all', lang)),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (metrics.recentPayments.isEmpty)
            const AppEmptyState(
              isCompact: true,
              title: 'No recent fee transactions',
              icon: Icons.receipt_outlined,
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: metrics.recentPayments.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, idx) {
                final p = metrics.recentPayments[idx];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: const Color(0xFF10B981).withAlpha(25),
                        child: const Icon(
                          Icons.check,
                          size: 13,
                          color: Color(0xFF10B981),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.studentName,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${p.receiptNumber} • ${p.paymentMethod}',
                              style: const TextStyle(
                                fontSize: 10.5,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        'NPR ${p.amount.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 8. UPCOMING EXAMINATIONS CARD
  // ===========================================================================
  Widget _buildUpcomingExamsCard(
    BuildContext context,
    ThemeData theme,
    String lang,
    DashboardMetrics metrics,
    WidgetRef ref,
  ) {
    return AppCard(
      isHoverable: false,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withAlpha(25),
                        borderRadius: AppRadius.roundedSm,
                      ),
                      child: const Icon(
                        Icons.assignment_outlined,
                        size: 18,
                        color: Color(0xFF6366F1),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        AppTranslations.text('upcoming_examinations', lang),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => _navigateToMenu(ref, 'exam_schedule'),
                child: Text(AppTranslations.text('view_all', lang)),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (metrics.upcomingExams.isEmpty)
            const AppEmptyState(
              isCompact: true,
              title: 'No upcoming examinations scheduled',
              icon: Icons.assignment_outlined,
            )
          else
            Column(
              children:
                  metrics.upcomingExams.map((exam) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest
                              .withAlpha(40),
                          borderRadius: AppRadius.roundedMd,
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant.withAlpha(
                              70,
                            ),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    exam.name,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${exam.category} • Starts ${DateFormat('MMM dd').format(exam.startDate)}',
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            AppBadge.primary(
                              exam.status,
                              size: AppBadgeSize.sm,
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
            ),
        ],
      ),
    );
  }
}
