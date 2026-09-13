import 'package:flutter/material.dart';
import '../../config/extensions.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../../config/responsive.dart';
import '../../config/translations.dart';
import '../../data/app_database.dart';
import '../../models/calendar_mode.dart';
import '../../providers/academic_year_provider.dart';
import '../../providers/calendar_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/locale_provider.dart';
import '../../services/expense_service.dart';
import '../../utils/date_time_utils.dart';
import '../../widgets/app_input.dart';
import '../../widgets/ui/app_button.dart';
import '../../widgets/ui/app_empty_state.dart';
import '../../widgets/ui/app_error_view.dart';
import '../../widgets/ui/app_skeleton.dart';
import '../../widgets/ui/app_tabs.dart';

class ExpensesScreen extends ConsumerStatefulWidget {
  final int? fixedTab;
  const ExpensesScreen({super.key, this.fixedTab});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class ExpensesListScreen extends StatelessWidget {
  const ExpensesListScreen({super.key});

  @override
  Widget build(BuildContext context) => const ExpensesScreen(fixedTab: 0);
}

class ExpenseReportScreen extends StatelessWidget {
  const ExpenseReportScreen({super.key});

  @override
  Widget build(BuildContext context) => const ExpensesScreen(fixedTab: 1);
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.fixedTab ?? 0,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  static IconData getCategoryIcon(String iconName) {
    switch (iconName.toLowerCase()) {
      case 'domain':
      case 'hotel':
      case 'room rent':
        return Icons.domain;
      case 'directions_bus':
      case 'travel':
      case 'bus':
        return Icons.directions_bus;
      case 'free_breakfast':
      case 'breakfast':
      case 'tea':
        return Icons.free_breakfast;
      case 'restaurant':
      case 'lunch':
      case 'food':
        return Icons.restaurant;
      case 'dinner_dining':
      case 'dinner':
        return Icons.dinner_dining;
      case 'lightbulb':
      case 'utilities':
      case 'electricity':
        return Icons.lightbulb;
      case 'inventory_2':
      case 'stationery':
      case 'supplies':
        return Icons.inventory_2;
      case 'school':
      case 'education':
        return Icons.school;
      case 'computer':
        return Icons.computer;
      case 'medical_services':
      case 'health':
        return Icons.medical_services;
      case 'sports_soccer':
      case 'sports':
        return Icons.sports_soccer;
      default:
        return Icons.category;
    }
  }

  String _formatAmount(double amount) {
    final formatter = NumberFormat('#,##,###.##');
    return 'Rs. ${formatter.format(amount)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lang = ref.watch(localeProvider).locale.languageCode;
    final calendarMode = ref.watch(calendarProvider);
    final isNepali = lang == 'ne';

    final selectedPeriod = ref.watch(expensePeriodFilterProvider);
    final customDateRange = ref.watch(expenseCustomDateRangeProvider);
    final selectedCategoryId = ref.watch(expenseCategoryFilterProvider);
    final selectedAcademicYearId = ref.watch(expenseAcademicYearFilterProvider);
    final academicYearsAsync = ref.watch(academicYearsStreamProvider);
    final categoriesAsync = ref.watch(expenseCategoriesStreamProvider);
    final expensesAsync = ref.watch(filteredExpensesStreamProvider);
    final reportSummary = ref.watch(expenseReportProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // 1. Top Screen Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withAlpha(30),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.account_balance_wallet_rounded,
                      color: theme.colorScheme.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppTranslations.text('expenses', lang),
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          AppTranslations.text('expense_report', lang),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Category Management Quick Button
                  OutlinedButton.icon(
                    onPressed: () => _openCategoryManagementDialog(context),
                    icon: const Icon(Icons.tune, size: 18),
                    label: Text(
                      context.isMobile
                          ? AppTranslations.text('category', lang)
                          : AppTranslations.text('all_categories', lang),
                    ),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Add Expense Button
                  FilledButton.icon(
                    onPressed: () => _openAddEditExpenseDialog(context),
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(AppTranslations.text('add_expense', lang)),
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. Metrics Cards
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: _buildMetricCards(context, theme, reportSummary, lang),
            ),
          ),

          // 3. Period Selection Tabs & Date Range Chips
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildPeriodChip(
                          label: AppTranslations.text('today', lang),
                          isSelected: selectedPeriod == ExpensePeriodType.day,
                          onTap: () {
                            ref
                                .read(expensePeriodFilterProvider.notifier)
                                .setPeriod(ExpensePeriodType.day);
                          },
                        ),
                        const SizedBox(width: 8),
                        _buildPeriodChip(
                          label: AppTranslations.text('this_week', lang),
                          isSelected: selectedPeriod == ExpensePeriodType.week,
                          onTap: () {
                            ref
                                .read(expensePeriodFilterProvider.notifier)
                                .setPeriod(ExpensePeriodType.week);
                          },
                        ),
                        const SizedBox(width: 8),
                        _buildPeriodChip(
                          label: AppTranslations.text('this_month', lang),
                          isSelected: selectedPeriod == ExpensePeriodType.month,
                          onTap: () {
                            ref
                                .read(expensePeriodFilterProvider.notifier)
                                .setPeriod(ExpensePeriodType.month);
                          },
                        ),
                        const SizedBox(width: 8),
                        _buildPeriodChip(
                          label: AppTranslations.text('this_year', lang),
                          isSelected: selectedPeriod == ExpensePeriodType.year,
                          onTap: () {
                            ref
                                .read(expensePeriodFilterProvider.notifier)
                                .setPeriod(ExpensePeriodType.year);
                          },
                        ),
                        const SizedBox(width: 8),
                        _buildPeriodChip(
                          label: AppTranslations.text('all_time', lang),
                          isSelected:
                              selectedPeriod == ExpensePeriodType.allTime,
                          onTap: () {
                            ref
                                .read(expensePeriodFilterProvider.notifier)
                                .setPeriod(ExpensePeriodType.allTime);
                          },
                        ),
                        const SizedBox(width: 8),
                        _buildPeriodChip(
                          label: AppTranslations.text('custom_range', lang),
                          isSelected:
                              selectedPeriod == ExpensePeriodType.custom,
                          onTap: () async {
                            ref
                                .read(expensePeriodFilterProvider.notifier)
                                .setPeriod(ExpensePeriodType.custom);
                            await _pickCustomDateRange(context);
                          },
                          icon: Icons.date_range,
                        ),
                      ],
                    ),
                  ),

                  // Show custom date range indicator if custom selected
                  if (selectedPeriod == ExpensePeriodType.custom &&
                      (customDateRange.start != null ||
                          customDateRange.end != null)) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondaryContainer.withAlpha(
                          90,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 14,
                            color: theme.colorScheme.onSecondaryContainer,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${customDateRange.start != null ? DateTimeUtils.formatDateByMode(customDateRange.start!, mode: calendarMode, inNepaliScript: isNepali) : 'Any'} → ${customDateRange.end != null ? DateTimeUtils.formatDateByMode(customDateRange.end!, mode: calendarMode, inNepaliScript: isNepali) : 'Any'}',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onSecondaryContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () => _pickCustomDateRange(context),
                            child: Text(
                              AppTranslations.text('edit', lang),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // 4. Secondary Filter Toolbar (Search + Category Filter + View Mode Tabs)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Card(
                elevation: 0,
                color: theme.colorScheme.surfaceContainerHighest.withAlpha(120),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // Search box
                      SizedBox(
                        width: context.isMobile ? double.infinity : 260,
                        child: AppSearchField(
                          controller: _searchController,
                          hintText: AppTranslations.text('search', lang),
                          onChanged: (val) {
                            ref
                                .read(expenseSearchQueryProvider.notifier)
                                .setQuery(val);
                          },
                          onClear: () {
                            ref
                                .read(expenseSearchQueryProvider.notifier)
                                .setQuery('');
                          },
                        ),
                      ),

                      // Academic Year Dropdown Filter
                      academicYearsAsync.when(
                        data:
                            (years) => SizedBox(
                              width: 180,
                              child: AppSearchableSelect<int?>.filter(
                                value: selectedAcademicYearId,
                                hint: AppTranslations.text(
                                  'all_academic_years',
                                  lang,
                                ),
                                items: [
                                  SearchableSelectItem<int?>(
                                    value: null,
                                    label: AppTranslations.text(
                                      'all_academic_years',
                                      lang,
                                    ),
                                  ),
                                  ...years.map((y) {
                                    return SearchableSelectItem<int?>(
                                      value: y.id,
                                      label:
                                          y.name +
                                          (y.isCurrent ? ' (Active)' : ''),
                                      leading: Icon(
                                        Icons.school,
                                        size: 16,
                                        color:
                                            y.isCurrent
                                                ? theme.colorScheme.primary
                                                : theme
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                      ),
                                    );
                                  }),
                                ],
                                onChanged: (val) {
                                  ref
                                      .read(
                                        expenseAcademicYearFilterProvider
                                            .notifier,
                                      )
                                      .setAcademicYear(val);
                                },
                              ),
                            ),
                        loading:
                            () => const SizedBox(
                              width: 40,
                              height: 40,
                              child: Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                        error: (err, stack) => const SizedBox.shrink(),
                      ),

                      // Category Dropdown Filter
                      categoriesAsync.when(
                        data:
                            (categories) => SizedBox(
                              width: 180,
                              child: AppSearchableSelect<int?>.filter(
                                value: selectedCategoryId,
                                hint: AppTranslations.text(
                                  'all_categories',
                                  lang,
                                ),
                                items: [
                                  SearchableSelectItem<int?>(
                                    value: null,
                                    label: AppTranslations.text(
                                      'all_categories',
                                      lang,
                                    ),
                                  ),
                                  ...categories.map((cat) {
                                    return SearchableSelectItem<int?>(
                                      value: cat.id,
                                      label: cat.name,
                                      leading: Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          color: Color(cat.colorValue),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    );
                                  }),
                                ],
                                onChanged: (val) {
                                  ref
                                      .read(
                                        expenseCategoryFilterProvider.notifier,
                                      )
                                      .setCategory(val);
                                },
                              ),
                            ),
                        loading:
                            () => const SizedBox(
                              width: 40,
                              height: 40,
                              child: Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                        error: (err, stack) => const SizedBox.shrink(),
                      ),

                      // Tab Toggle: List View vs Report View (only shown when not in standalone mode)
                      if (widget.fixedTab == null)
                        AppPillTabBar(
                          controller: _tabController,
                          isScrollable: true,
                          tabs: [
                            Tab(
                              icon: const Icon(Icons.list_alt, size: 18),
                              text: AppTranslations.text('expenses', lang),
                            ),
                            Tab(
                              icon: const Icon(
                                Icons.pie_chart_outline,
                                size: 18,
                              ),
                              text: AppTranslations.text(
                                'expense_report',
                                lang,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 5. Dynamic Content (List View OR Report View)
          SliverFillRemaining(
            hasScrollBody: true,
            child:
                widget.fixedTab != null
                    ? (widget.fixedTab == 0
                        ? _buildExpensesListView(
                          context,
                          theme,
                          expensesAsync,
                          calendarMode,
                          isNepali,
                          lang,
                        )
                        : _buildReportAnalyticsView(
                          context,
                          theme,
                          reportSummary,
                          expensesAsync,
                          calendarMode,
                          isNepali,
                          lang,
                        ))
                    : TabBarView(
                      controller: _tabController,
                      children: [
                        // TAB 1: Expenses List View
                        _buildExpensesListView(
                          context,
                          theme,
                          expensesAsync,
                          calendarMode,
                          isNepali,
                          lang,
                        ),

                        // TAB 2: Reports & Breakdown View
                        _buildReportAnalyticsView(
                          context,
                          theme,
                          reportSummary,
                          expensesAsync,
                          calendarMode,
                          isNepali,
                          lang,
                        ),
                      ],
                    ),
          ),
        ],
      ),
    );
  }

  // ================= METRICS CARDS =================

  Widget _buildMetricCards(
    BuildContext context,
    ThemeData theme,
    ExpenseReportSummary? report,
    String lang,
  ) {
    final total = report?.totalAmount ?? 0.0;
    final count = report?.transactionCount ?? 0;
    final avg = report?.averageAmount ?? 0.0;
    final topCat =
        (report?.categoryBreakdowns.isNotEmpty ?? false)
            ? '${report!.categoryBreakdowns.first.categoryName} (${report.categoryBreakdowns.first.percentage.toStringAsFixed(1)}%)'
            : 'N/A';

    final isDesktop = context.isDesktop;
    final cards = [
      _buildStatCard(
        theme,
        title: AppTranslations.text('total_expenses', lang),
        value: _formatAmount(total),
        icon: Icons.payments,
        color: theme.colorScheme.error,
      ),
      _buildStatCard(
        theme,
        title: AppTranslations.text('total_transactions', lang),
        value: count.toString(),
        icon: Icons.receipt_long,
        color: theme.colorScheme.primary,
      ),
      _buildStatCard(
        theme,
        title: AppTranslations.text('average_expense', lang),
        value: _formatAmount(avg),
        icon: Icons.trending_up,
        color: Colors.orange,
      ),
      _buildStatCard(
        theme,
        title: AppTranslations.text('top_category', lang),
        value: topCat,
        icon: Icons.pie_chart,
        color: Colors.purple,
      ),
    ];

    if (isDesktop) {
      return Row(
        children:
            cards
                .map(
                  (c) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: c,
                    ),
                  ),
                )
                .toList(),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              cards
                  .map(
                    (c) => SizedBox(
                      width: (constraints.maxWidth - 8) / 2,
                      child: c,
                    ),
                  )
                  .toList(),
        );
      },
    );
  }

  Widget _buildStatCard(
    ThemeData theme, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 0,
      color: color.withAlpha(20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withAlpha(50)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 16, color: color),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ================= PERIOD CHIP =================

  Widget _buildPeriodChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    final theme = Theme.of(context);
    return FilterChip(
      selected: isSelected,
      label: Text(label),
      avatar:
          icon != null
              ? Icon(
                icon,
                size: 16,
                color:
                    isSelected
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.primary,
              )
              : null,
      onSelected: (_) => onTap(),
      selectedColor: theme.colorScheme.primary,
      labelStyle: TextStyle(
        color:
            isSelected
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.onSurface,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      showCheckmark: false,
    );
  }

  // ================= EXPENSES LIST VIEW =================

  Widget _buildExpensesListView(
    BuildContext context,
    ThemeData theme,
    AsyncValue<List<ExpenseWithCategory>> expensesAsync,
    CalendarMode calendarMode,
    bool isNepali,
    String lang,
  ) {
    return expensesAsync.when(
      data: (expenses) {
        if (expenses.isEmpty) {
          return Center(
            child: AppEmptyState.noData(
              title: AppTranslations.text('no_expenses', lang),
              icon: Icons.receipt_long_outlined,
              action: AppButton.primary(
                onPressed: () => _openAddEditExpenseDialog(context),
                leadingIcon: const Icon(Icons.add, size: 16),
                text: AppTranslations.text('add_expense', lang),
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
          itemCount: expenses.length,
          itemBuilder: (context, index) {
            final item = expenses[index];
            final catColor = Color(item.category.colorValue);
            final formattedDate = DateTimeUtils.formatDateByMode(
              item.expenseDate,
              mode: calendarMode,
              inNepaliScript: isNepali,
            );

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              elevation: 0,
              color: theme.colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: theme.colorScheme.outlineVariant.withAlpha(100),
                ),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: catColor.withAlpha(30),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    getCategoryIcon(item.category.iconName),
                    color: catColor,
                    size: 24,
                  ),
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      _formatAmount(item.amount),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // Category badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: catColor.withAlpha(20),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: catColor.withAlpha(60)),
                        ),
                        child: Text(
                          item.categoryName,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: catColor,
                          ),
                        ),
                      ),

                      // Academic Year badge
                      if (item.academicYear != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer.withAlpha(
                              120,
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.school_outlined,
                                size: 11,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                item.academicYear!.name,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Date
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            formattedDate,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),

                      // Payment Method
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.paymentMethod,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),

                      // Payee if available
                      if (item.paidTo != null && item.paidTo!.isNotEmpty) ...[
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.person_outline,
                              size: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              item.paidTo!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],

                      // Reference if available
                      if (item.referenceNumber != null &&
                          item.referenceNumber!.isNotEmpty) ...[
                        Text(
                          '#${item.referenceNumber}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                trailing: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20),
                  onSelected: (action) {
                    if (action == 'edit') {
                      _openAddEditExpenseDialog(context, existing: item);
                    } else if (action == 'delete') {
                      _confirmDeleteExpense(context, item);
                    }
                  },
                  itemBuilder:
                      (context) => [
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              const Icon(Icons.edit, size: 18),
                              const SizedBox(width: 8),
                              Text(AppTranslations.text('edit', lang)),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete,
                                size: 18,
                                color: theme.colorScheme.error,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                AppTranslations.text('delete', lang),
                                style: TextStyle(
                                  color: theme.colorScheme.error,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                ),
              ),
            );
          },
        );
      },
      loading: () => AppSkeleton.list(count: 6),
      error:
          (e, stack) => Center(
            child: AppErrorView(
              error: e,
              stackTrace: stack,
              onRetry: () => ref.refresh(filteredExpensesStreamProvider),
            ),
          ),
    );
  }

  // ================= REPORTS & ANALYTICS VIEW =================

  Widget _buildReportAnalyticsView(
    BuildContext context,
    ThemeData theme,
    ExpenseReportSummary? report,
    AsyncValue<List<ExpenseWithCategory>> expensesAsync,
    CalendarMode calendarMode,
    bool isNepali,
    String lang,
  ) {
    if (report == null || report.transactionCount == 0) {
      return Center(
        child: Text(
          AppTranslations.text('no_expenses', lang),
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Category Breakdown Progress Bars
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: theme.colorScheme.outlineVariant.withAlpha(100),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        AppTranslations.text('category_breakdown', lang),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${report.categoryBreakdowns.length} Categories',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  ...report.categoryBreakdowns.map((cat) {
                    final color = Color(cat.colorValue);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                getCategoryIcon(cat.iconName),
                                size: 16,
                                color: color,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  cat.categoryName,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Text(
                                '${cat.percentage.toStringAsFixed(1)}%',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: color,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                _formatAmount(cat.totalAmount),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: cat.percentage / 100,
                              minHeight: 8,
                              backgroundColor: color.withAlpha(30),
                              valueColor: AlwaysStoppedAnimation<Color>(color),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 2. Payment Method Distribution
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: theme.colorScheme.outlineVariant.withAlpha(100),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppTranslations.text('payment_method', lang),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Divider(height: 24),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children:
                        report.paymentMethodBreakdown.entries.map((entry) {
                          final pct =
                              report.totalAmount > 0
                                  ? (entry.value / report.totalAmount) * 100
                                  : 0.0;
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest
                                  .withAlpha(120),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: theme.colorScheme.outlineVariant
                                    .withAlpha(80),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entry.key,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatAmount(entry.value),
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '${pct.toStringAsFixed(1)}%',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ================= DATE RANGE PICKER =================

  Future<void> _pickCustomDateRange(BuildContext context) async {
    final now = DateTime.now();
    final custom = ref.read(expenseCustomDateRangeProvider);
    final initialRange =
        (custom.start != null && custom.end != null)
            ? DateTimeRange(start: custom.start!, end: custom.end!)
            : DateTimeRange(start: DateTime(now.year, now.month, 1), end: now);

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDateRange: initialRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    if (picked != null) {
      ref
          .read(expenseCustomDateRangeProvider.notifier)
          .setRange(picked.start, picked.end);
    }
  }

  // ================= ADD / EDIT EXPENSE DIALOG =================

  void _openAddEditExpenseDialog(
    BuildContext context, {
    ExpenseWithCategory? existing,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ExpenseDialog(existing: existing),
    );
  }

  void _confirmDeleteExpense(BuildContext context, ExpenseWithCategory item) {
    final lang = ref.read(localeProvider).locale.languageCode;
    showDialog(
      context: context,
      builder:
          (dialogCtx) => AlertDialog(
            title: Text(AppTranslations.text('delete_expense', lang)),
            content: Text(
              'Are you sure you want to delete "${item.title}" of ${_formatAmount(item.amount)}?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: Text(AppTranslations.text('cancel', lang)),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(dialogCtx).colorScheme.error,
                ),
                onPressed: () async {
                  Navigator.pop(dialogCtx);
                  final success = await ref
                      .read(expenseControllerProvider.notifier)
                      .deleteExpense(item.id);
                  context.showSnackbar(
                    SnackBar(
                      content: Text(
                        success
                            ? 'Expense deleted successfully'
                            : 'Failed to delete expense',
                      ),
                    ),
                  );
                },
                child: Text(AppTranslations.text('delete', lang)),
              ),
            ],
          ),
    );
  }

  void _openCategoryManagementDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const _CategoryManagementDialog(),
    );
  }
}

// ================= DIALOGS =================

class _ExpenseDialog extends ConsumerStatefulWidget {
  final ExpenseWithCategory? existing;

  const _ExpenseDialog({this.existing});

  @override
  ConsumerState<_ExpenseDialog> createState() => _ExpenseDialogState();
}

class _ExpenseDialogState extends ConsumerState<_ExpenseDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _amountController;
  late TextEditingController _paidToController;
  late TextEditingController _refNumberController;
  late TextEditingController _notesController;

  int? _selectedCategoryId;
  int? _selectedAcademicYearId;
  late DateTime _expenseDate;
  late String _paymentMethod;

  final List<String> _paymentMethods = [
    'Cash',
    'Bank Transfer',
    'Cheque',
    'eSewa',
    'Khalti',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _titleController = TextEditingController(text: e?.title ?? '');
    _amountController = TextEditingController(
      text: e != null ? e.amount.toStringAsFixed(2) : '',
    );
    _paidToController = TextEditingController(text: e?.paidTo ?? '');
    _refNumberController = TextEditingController(
      text: e?.referenceNumber ?? '',
    );
    _notesController = TextEditingController(text: e?.notes ?? '');

    _selectedCategoryId = e?.category.id;
    _selectedAcademicYearId = e?.expense.academicYearId;
    _expenseDate = e?.expenseDate ?? DateTime.now();
    _paymentMethod = e?.paymentMethod ?? 'Cash';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _paidToController.dispose();
    _refNumberController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lang = ref.watch(localeProvider).locale.languageCode;
    final calendarMode = ref.watch(calendarProvider);
    final isNepali = lang == 'ne';
    final categoriesAsync = ref.watch(expenseCategoriesStreamProvider);
    final academicYearsAsync = ref.watch(academicYearsStreamProvider);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        widget.existing != null
                            ? AppTranslations.text('edit_expense', lang)
                            : AppTranslations.text('add_expense', lang),
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(height: 24),

                  // Academic Year Dropdown
                  academicYearsAsync.when(
                    data: (years) {
                      if (_selectedAcademicYearId == null && years.isNotEmpty) {
                        final active =
                            years.where((y) => y.isCurrent).firstOrNull ??
                            years.first;
                        _selectedAcademicYearId = active.id;
                      }
                      return AppSearchableSelect<int>(
                        value: _selectedAcademicYearId,
                        label: AppTranslations.text('academic_year', lang),
                        hint: 'Select Academic Year',
                        prefixIcon: const Icon(Icons.school, size: 20),
                        items:
                            years.map((y) {
                              return SearchableSelectItem<int>(
                                value: y.id,
                                label:
                                    y.name + (y.isCurrent ? ' (Active)' : ''),
                              );
                            }).toList(),
                        onChanged: (val) {
                          setState(() => _selectedAcademicYearId = val);
                        },
                      );
                    },
                    loading:
                        () => const SizedBox(
                          height: 48,
                          child: Center(child: CircularProgressIndicator()),
                        ),
                    error: (err, _) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 14),

                  // Title Field
                  TextFormField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: AppTranslations.text('expense_title', lang),
                      hintText: 'e.g. Monthly Room Rent, Staff Lunch',
                      prefixIcon: const Icon(Icons.title, size: 20),
                    ),
                    validator:
                        (val) =>
                            (val == null || val.trim().isEmpty)
                                ? 'Please enter expense title'
                                : null,
                  ),
                  const SizedBox(height: 14),

                  // Category & Amount Row
                  Row(
                    children: [
                      // Category Dropdown
                      Expanded(
                        child: categoriesAsync.when(
                          data: (categories) {
                            if (_selectedCategoryId == null &&
                                categories.isNotEmpty) {
                              _selectedCategoryId = categories.first.id;
                            }
                            return AppSearchableSelect<int>(
                              value: _selectedCategoryId,
                              label: AppTranslations.text('category', lang),
                              hint: 'Select Category',
                              prefixIcon: const Icon(Icons.category, size: 20),
                              items:
                                  categories.map((cat) {
                                    return SearchableSelectItem<int>(
                                      value: cat.id,
                                      label: cat.name,
                                      leading: Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          color: Color(cat.colorValue),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                              onChanged: (val) {
                                setState(() => _selectedCategoryId = val);
                              },
                            );
                          },
                          loading:
                              () => const Center(
                                child: CircularProgressIndicator(),
                              ),
                          error: (err, _) => const SizedBox.shrink(),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Amount Field
                      Expanded(
                        child: TextFormField(
                          controller: _amountController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: AppTranslations.text('amount', lang),
                            hintText: '0.00',
                            prefixIcon: const Icon(
                              Icons.currency_rupee,
                              size: 20,
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Enter amount';
                            }
                            final n = double.tryParse(val.trim());
                            if (n == null || n <= 0) {
                              return 'Enter valid amount > 0';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Date & Payment Method Row
                  Row(
                    children: [
                      // Date Picker
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _expenseDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2035),
                            );
                            if (picked != null) {
                              setState(() => _expenseDate = picked);
                            }
                          },
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: AppTranslations.text(
                                'expense_date',
                                lang,
                              ),
                              prefixIcon: const Icon(
                                Icons.calendar_month,
                                size: 20,
                              ),
                            ),
                            child: Text(
                              DateTimeUtils.formatDateByMode(
                                _expenseDate,
                                mode: calendarMode,
                                inNepaliScript: isNepali,
                              ),
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Payment Method
                      Expanded(
                        child: AppSearchableSelect<String>(
                          value: _paymentMethod,
                          label: AppTranslations.text('payment_method', lang),
                          prefixIcon: const Icon(Icons.payment, size: 20),
                          items:
                              _paymentMethods.map((m) {
                                return SearchableSelectItem<String>(
                                  value: m,
                                  label: m,
                                );
                              }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _paymentMethod = val);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Paid To & Reference Number Row
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _paidToController,
                          decoration: InputDecoration(
                            labelText: AppTranslations.text('paid_to', lang),
                            hintText: 'Vendor or payee',
                            prefixIcon: const Icon(Icons.person, size: 20),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _refNumberController,
                          decoration: InputDecoration(
                            labelText: AppTranslations.text(
                              'reference_no',
                              lang,
                            ),
                            hintText: 'Voucher / Bill No.',
                            prefixIcon: const Icon(Icons.receipt, size: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Notes Field
                  TextFormField(
                    controller: _notesController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: AppTranslations.text('notes', lang),
                      hintText: 'Additional remarks...',
                      prefixIcon: const Icon(Icons.note_alt_outlined, size: 20),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Submit & Cancel Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(AppTranslations.text('cancel', lang)),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        onPressed: _saveExpense,
                        child: Text(AppTranslations.text('save', lang)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null) return;

    final title = _titleController.text.trim();
    final amount = double.parse(_amountController.text.trim());
    final paidTo = _paidToController.text.trim();
    final refNo = _refNumberController.text.trim();
    final notes = _notesController.text.trim();

    bool success;
    if (widget.existing != null) {
      success = await ref
          .read(expenseControllerProvider.notifier)
          .updateExpense(
            id: widget.existing!.id,
            title: title,
            categoryId: _selectedCategoryId!,
            amount: amount,
            expenseDate: _expenseDate,
            paymentMethod: _paymentMethod,
            paidTo: paidTo.isNotEmpty ? paidTo : null,
            referenceNumber: refNo.isNotEmpty ? refNo : null,
            notes: notes.isNotEmpty ? notes : null,
            academicYearId: _selectedAcademicYearId,
          );
    } else {
      success = await ref
          .read(expenseControllerProvider.notifier)
          .createExpense(
            title: title,
            categoryId: _selectedCategoryId!,
            amount: amount,
            expenseDate: _expenseDate,
            paymentMethod: _paymentMethod,
            paidTo: paidTo.isNotEmpty ? paidTo : null,
            referenceNumber: refNo.isNotEmpty ? refNo : null,
            notes: notes.isNotEmpty ? notes : null,
            academicYearId: _selectedAcademicYearId,
          );
    }

    if (mounted) {
      Navigator.pop(context);
      context.showSnackbar(
        SnackBar(
          content: Text(
            success
                ? (widget.existing != null
                    ? 'Expense updated successfully'
                    : 'Expense added successfully')
                : 'Failed to save expense',
          ),
        ),
      );
    }
  }
}

// ================= CATEGORY MANAGEMENT DIALOG =================

class _CategoryManagementDialog extends ConsumerWidget {
  const _CategoryManagementDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final lang = ref.watch(localeProvider).locale.languageCode;
    final categoriesAsync = ref.watch(expenseCategoriesStreamProvider);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    AppTranslations.text('category', lang),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: () => _openAddCategoryDialog(context, ref),
                  icon: const Icon(Icons.add, size: 16),
                  label: Text(AppTranslations.text('add_category', lang)),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: categoriesAsync.when(
                  data: (categories) {
                    if (categories.isEmpty) {
                      return const Center(child: Text('No categories found'));
                    }
                    return ListView.separated(
                      itemCount: categories.length,
                      separatorBuilder:
                          (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final cat = categories[index];
                        final color = Color(cat.colorValue);
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                          ),
                          leading: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: color.withAlpha(30),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              _ExpensesScreenState.getCategoryIcon(
                                cat.iconName,
                              ),
                              color: color,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            cat.name,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          trailing:
                              cat.isSystem
                                  ? Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          theme
                                              .colorScheme
                                              .surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Default',
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color:
                                                theme
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                          ),
                                    ),
                                  )
                                  : IconButton(
                                    icon: Icon(
                                      Icons.delete_outline,
                                      color: theme.colorScheme.error,
                                      size: 20,
                                    ),
                                    onPressed: () async {
                                      final success = await ref
                                          .read(
                                            expenseControllerProvider.notifier,
                                          )
                                          .deleteCategory(cat.id);
                                      if (context.mounted && !success) {
                                        context.showSnackbar(
                                          const SnackBar(
                                            content: Text(
                                              'Cannot delete category with associated expenses',
                                            ),
                                          ),
                                        );
                                      }
                                    },
                                  ),
                        );
                      },
                    );
                  },
                  loading:
                      () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openAddCategoryDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    int selectedColor = 0xFF3F51B5;
    String selectedIcon = 'category';

    final colors = [
      0xFF3F51B5, // Indigo
      0xFF009688, // Teal
      0xFFFF9800, // Amber
      0xFFF4511E, // Deep Orange
      0xFF9C27B0, // Purple
      0xFF2196F3, // Blue
      0xFF4CAF50, // Green
      0xFFE91E63, // Pink
      0xFF607D8B, // Blue Grey
    ];

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setState) {
              final theme = Theme.of(context);
              return AlertDialog(
                title: const Text('Add Custom Category'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Category Name',
                          hintText: 'e.g. Laboratory, Library Books',
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text('Choose Color', style: theme.textTheme.labelMedium),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children:
                            colors.map((c) {
                              final isSelected = selectedColor == c;
                              return InkWell(
                                onTap: () => setState(() => selectedColor = c),
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: Color(c),
                                    shape: BoxShape.circle,
                                    border:
                                        isSelected
                                            ? Border.all(
                                              color: Colors.white,
                                              width: 3,
                                            )
                                            : null,
                                    boxShadow:
                                        isSelected
                                            ? [
                                              BoxShadow(
                                                color: Color(c).withAlpha(120),
                                                blurRadius: 6,
                                              ),
                                            ]
                                            : null,
                                  ),
                                ),
                              );
                            }).toList(),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () async {
                      final name = nameController.text.trim();
                      if (name.isNotEmpty) {
                        await ref
                            .read(expenseControllerProvider.notifier)
                            .createCategory(
                              name: name,
                              colorValue: selectedColor,
                              iconName: selectedIcon,
                            );
                        if (context.mounted) Navigator.pop(context);
                      }
                    },
                    child: const Text('Add'),
                  ),
                ],
              );
            },
          ),
    );
  }
}
