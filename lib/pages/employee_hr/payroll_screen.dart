import 'dart:math';
import '../../config/extensions.dart';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../../config/enums.dart';
import '../../config/translations.dart';
import '../../data/app_database.dart';
import '../../providers/academic_year_provider.dart';
import '../../providers/calendar_provider.dart';
import '../../providers/employee_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/payroll_provider.dart';
import '../../services/payroll_service.dart';
import '../../utils/date_time_utils.dart';
import '../../widgets/app_input.dart';
import '../../widgets/ui/app_empty_state.dart';
import '../../widgets/ui/app_error_view.dart';
import '../../widgets/ui/app_skeleton.dart';
import '../../widgets/ui/app_tabs.dart';

class PayrollScreen extends ConsumerStatefulWidget {
  final EmployeeType? initialEmployeeType;
  final int? fixedTab;

  const PayrollScreen({super.key, this.initialEmployeeType, this.fixedTab});

  @override
  ConsumerState<PayrollScreen> createState() => _PayrollScreenState();
}

class SalaryPaymentsScreen extends StatelessWidget {
  const SalaryPaymentsScreen({super.key});

  @override
  Widget build(BuildContext context) => const PayrollScreen(fixedTab: 0);
}

class SalaryAdvancesScreen extends StatelessWidget {
  const SalaryAdvancesScreen({super.key});

  @override
  Widget build(BuildContext context) => const PayrollScreen(fixedTab: 1);
}

class _PayrollScreenState extends ConsumerState<PayrollScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  static const List<String> _englishMonths = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static const List<String> _nepaliMonths = [
    'बैशाख (Baishakh)',
    'जेष्ठ (Jestha)',
    'असार (Ashadh)',
    'श्रावण (Shrawan)',
    'भदौ (Bhadra)',
    'असोज (Ashwin)',
    'कात्तिक (Kartik)',
    'मंसिर (Mangsir)',
    'पुष (Poush)',
    'माघ (Magh)',
    'फागुन (Falgun)',
    'चैत (Chaitra)',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.fixedTab ?? 0,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialEmployeeType != null) {
        ref
            .read(payrollEmployeeTypeFilterProvider.notifier)
            .setType(widget.initialEmployeeType);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String _formatAmount(double amount) {
    final formatter = NumberFormat('#,##,###.##');
    return 'Rs. ${formatter.format(amount)}';
  }

  String _getMonthName(int month, bool isNepali) {
    if (month < 1 || month > 12) return 'Month $month';
    return isNepali ? _nepaliMonths[month - 1] : _englishMonths[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeProvider).locale.languageCode;
    final isNepali = lang == 'ne';
    final currentYear = ref.watch(payrollYearFilterProvider);
    final currentMonth = ref.watch(payrollMonthFilterProvider);
    final currentAcademicYearId = ref.watch(payrollAcademicYearFilterProvider);
    final academicYearsAsync = ref.watch(academicYearsStreamProvider);
    final currentType = ref.watch(payrollEmployeeTypeFilterProvider);
    final statsAsync = ref.watch(payrollSummaryStatsProvider);

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            // Top Metrics Bar
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: statsAsync.when(
                  data: (stats) => _buildMetricsBar(context, stats, isNepali),
                  loading:
                      () => const SizedBox(
                        height: 100,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                  error: (error, stackTrace) => const SizedBox(height: 100),
                ),
              ),
            ),

            // Tab Bar and Search Bar
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    // Toolbar
                    Row(
                      children: [
                        // Search Field
                        Expanded(
                          child: AppSearchField(
                            controller: _searchController,
                            hintText: AppTranslations.text('search', lang),
                            onChanged: (val) {
                              ref
                                  .read(payrollSearchQueryProvider.notifier)
                                  .setQuery(val);
                            },
                            onClear: () {
                              ref
                                  .read(payrollSearchQueryProvider.notifier)
                                  .setQuery('');
                            },
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Action Buttons
                        FilledButton.icon(
                          onPressed: () => _openPaySalaryDialog(context),
                          icon: const Icon(Icons.payment, size: 18),
                          label: Text(AppTranslations.text('pay_salary', lang)),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () => _openGiveAdvanceDialog(context),
                          icon: const Icon(Icons.handshake_outlined, size: 18),
                          label: Text(
                            AppTranslations.text('give_advance', lang),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Filter Bar (Year, Month, Type, Academic Year)
                    _buildFiltersBar(
                      context,
                      currentYear,
                      currentMonth,
                      currentAcademicYearId,
                      academicYearsAsync,
                      currentType,
                      lang,
                      isNepali,
                    ),
                    const SizedBox(height: 12),

                    // Navigation Tabs (only shown when not in standalone mode)
                    if (widget.fixedTab == null) ...[
                      AppPillTabBar(
                        controller: _tabController,
                        tabs: [
                          Tab(
                            icon: const Icon(Icons.receipt_long, size: 18),
                            text: AppTranslations.text('salary_payments', lang),
                          ),
                          Tab(
                            icon: const Icon(Icons.monetization_on, size: 18),
                            text: AppTranslations.text('salary_advances', lang),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
            ),
          ];
        },
        body:
            widget.fixedTab != null
                ? (widget.fixedTab == 0
                    ? _SalaryPaymentsTab(
                      formatAmount: _formatAmount,
                      getMonthName: (m) => _getMonthName(m, isNepali),
                    )
                    : _SalaryAdvancesTab(formatAmount: _formatAmount))
                : TabBarView(
                  controller: _tabController,
                  children: [
                    _SalaryPaymentsTab(
                      formatAmount: _formatAmount,
                      getMonthName: (m) => _getMonthName(m, isNepali),
                    ),
                    _SalaryAdvancesTab(formatAmount: _formatAmount),
                  ],
                ),
      ),
    );
  }

  Widget _buildMetricsBar(
    BuildContext context,
    PayrollSummaryStats stats,
    bool isNepali,
  ) {
    final theme = Theme.of(context);
    final lang = ref.watch(localeProvider).locale.languageCode;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 700;
        final cardCount = isCompact ? 2 : 4;
        final width =
            (constraints.maxWidth - ((cardCount - 1) * 12)) / cardCount;

        final cards = [
          _MetricCard(
            title: AppTranslations.text('total_expenses', lang),
            subtitle: 'Net Disbursed',
            value: _formatAmount(stats.totalNetPaid),
            icon: Icons.payments,
            color: theme.colorScheme.primary,
            width: width,
          ),
          _MetricCard(
            title: AppTranslations.text('outstanding_advance', lang),
            subtitle: '${stats.activeAdvancesCount} active advances',
            value: _formatAmount(stats.totalOutstandingAdvances),
            icon: Icons.pending_actions,
            color: Colors.deepOrange,
            width: width,
          ),
          _MetricCard(
            title: AppTranslations.text('bonus', lang),
            subtitle: 'Allowances paid',
            value: _formatAmount(stats.totalBonus),
            icon: Icons.card_giftcard,
            color: Colors.green,
            width: width,
          ),
          _MetricCard(
            title: AppTranslations.text('deductions', lang),
            subtitle: 'Std + Adv Recovery',
            value: _formatAmount(
              stats.totalStandardDeductions + stats.totalAdvanceDeductions,
            ),
            icon: Icons.remove_circle_outline,
            color: Colors.amber.shade800,
            width: width,
          ),
        ];

        if (isCompact) {
          return Column(
            children: [
              Row(children: [cards[0], const SizedBox(width: 12), cards[1]]),
              const SizedBox(height: 12),
              Row(children: [cards[2], const SizedBox(width: 12), cards[3]]),
            ],
          );
        }

        return Row(
          children: [
            cards[0],
            const SizedBox(width: 12),
            cards[1],
            const SizedBox(width: 12),
            cards[2],
            const SizedBox(width: 12),
            cards[3],
          ],
        );
      },
    );
  }

  Widget _buildFiltersBar(
    BuildContext context,
    int currentYear,
    int? currentMonth,
    int? currentAcademicYearId,
    AsyncValue<List<AcademicYear>> academicYearsAsync,
    EmployeeType? currentType,
    String lang,
    bool isNepali,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // Academic Year Dropdown
          academicYearsAsync.when(
            data:
                (years) => SizedBox(
                  width: 220,
                  child: AppSearchableSelect<int>.filter(
                    value: currentAcademicYearId,
                    hint: AppTranslations.text('all_academic_years', lang),
                    items:
                        years.map((y) {
                          return SearchableSelectItem<int>(
                            value: y.id,
                            label: y.name + (y.isCurrent ? ' (Active)' : ''),
                            leading: Icon(
                              Icons.school,
                              size: 14,
                              color:
                                  y.isCurrent
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                            ),
                          );
                        }).toList(),
                    onChanged: (val) {
                      ref
                          .read(payrollAcademicYearFilterProvider.notifier)
                          .setAcademicYear(val);
                    },
                  ),
                ),
            loading:
                () => const SizedBox(
                  width: 32,
                  height: 32,
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
            error: (_, _) => const SizedBox.shrink(),
          ),
          const SizedBox(width: 8),

          // Year Dropdown
          SizedBox(
            width: 140,
            child: AppSearchableSelect<int>.filter(
              value: currentYear,
              isClearable: false,
              items: [
                for (
                  int y = DateTime.now().year - 2;
                  y <= DateTime.now().year + 2;
                  y++
                )
                  SearchableSelectItem<int>(value: y, label: 'Year: $y'),
              ],
              onChanged: (val) {
                if (val != null) {
                  ref.read(payrollYearFilterProvider.notifier).setYear(val);
                }
              },
            ),
          ),
          const SizedBox(width: 8),

          // Month Dropdown
          SizedBox(
            width: 150,
            child: AppSearchableSelect<int>.filter(
              value: currentMonth,
              hint: 'All Months',
              items: [
                for (int m = 1; m <= 12; m++)
                  SearchableSelectItem<int>(
                    value: m,
                    label: _getMonthName(m, isNepali),
                  ),
              ],
              onChanged: (val) {
                ref.read(payrollMonthFilterProvider.notifier).setMonth(val);
              },
            ),
          ),
          const SizedBox(width: 8),

          // Employee Type Filter Chips
          FilterChip(
            selected: currentType == null,
            label: const Text('All Staff'),
            onSelected: (_) {
              ref
                  .read(payrollEmployeeTypeFilterProvider.notifier)
                  .setType(null);
            },
          ),
          const SizedBox(width: 6),
          FilterChip(
            selected: currentType == EmployeeType.teacher,
            label: Text(AppTranslations.text('teachers', lang)),
            onSelected: (_) {
              ref
                  .read(payrollEmployeeTypeFilterProvider.notifier)
                  .setType(EmployeeType.teacher);
            },
          ),
          const SizedBox(width: 6),
          FilterChip(
            selected: currentType == EmployeeType.staff,
            label: Text(AppTranslations.text('staff', lang)),
            onSelected: (_) {
              ref
                  .read(payrollEmployeeTypeFilterProvider.notifier)
                  .setType(EmployeeType.staff);
            },
          ),
        ],
      ),
    );
  }

  void _openPaySalaryDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => _PaySalaryDialog(
            formatAmount: _formatAmount,
            getMonthName:
                (m) => _getMonthName(
                  m,
                  ref.read(localeProvider).locale.languageCode == 'ne',
                ),
          ),
    );
  }

  void _openGiveAdvanceDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _GiveAdvanceDialog(formatAmount: _formatAmount),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String value;
  final IconData icon;
  final Color color;
  final double width;

  const _MetricCard({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.icon,
    required this.color,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ==========================================
// SALARY PAYMENTS TAB
// ==========================================

class _SalaryPaymentsTab extends ConsumerWidget {
  final String Function(double) formatAmount;
  final String Function(int) getMonthName;

  const _SalaryPaymentsTab({
    required this.formatAmount,
    required this.getMonthName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentsAsync = ref.watch(salaryPaymentsStreamProvider);
    final lang = ref.watch(localeProvider).locale.languageCode;
    final calendarMode = ref.watch(calendarProvider);
    final isNepali = lang == 'ne';

    return paymentsAsync.when(
      data: (payments) {
        if (payments.isEmpty) {
          return Center(
            child: AppEmptyState.noData(
              title: AppTranslations.text('no_salary_payments', lang),
              icon: Icons.receipt_long_outlined,
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: payments.length,
          itemBuilder: (context, index) {
            final p = payments[index];
            final dateStr = DateTimeUtils.formatDateByMode(
              p.paymentDate,
              mode: calendarMode,
              inNepaliScript: isNepali,
            );

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Row: Avatar, Name, Designation, Net Paid Badge
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor:
                              p.employeeType == EmployeeType.teacher
                                  ? Colors.indigo.withAlpha(30)
                                  : Colors.teal.withAlpha(30),
                          child: Icon(
                            p.employeeType == EmployeeType.teacher
                                ? Icons.school
                                : Icons.badge,
                            color:
                                p.employeeType == EmployeeType.teacher
                                    ? Colors.indigo
                                    : Colors.teal,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.employeeName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                '${p.designation} • ${p.employeeType.name.toUpperCase()}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Net Paid Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withAlpha(25),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.green.withAlpha(80),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                formatAmount(p.netSalary),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: Colors.green,
                                ),
                              ),
                              const Text(
                                'NET PAID',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20),

                    // Financial Breakdown Row
                    Wrap(
                      spacing: 12,
                      runSpacing: 6,
                      children: [
                        _DetailChip(
                          label: 'Period',
                          value: '${getMonthName(p.month)} ${p.year}',
                          icon: Icons.calendar_month,
                        ),
                        _DetailChip(
                          label: 'Basic',
                          value: formatAmount(p.basicSalary),
                          icon: Icons.account_balance_wallet,
                        ),
                        if (p.bonus > 0)
                          _DetailChip(
                            label: 'Bonus',
                            value: '+${formatAmount(p.bonus)}',
                            icon: Icons.add_circle_outline,
                            color: Colors.green,
                          ),
                        if (p.deduction > 0)
                          _DetailChip(
                            label: 'Std Ded.',
                            value: '-${formatAmount(p.deduction)}',
                            icon: Icons.remove_circle_outline,
                            color: Colors.red.shade700,
                          ),
                        if (p.advanceDeduction > 0)
                          _DetailChip(
                            label: 'Adv. Recv.',
                            value: '-${formatAmount(p.advanceDeduction)}',
                            icon: Icons.restore,
                            color: Colors.deepOrange,
                          ),
                        if (p.academicYear != null)
                          _DetailChip(
                            label: 'Session',
                            value: p.academicYear!.name,
                            icon: Icons.school_outlined,
                            color: Colors.indigo,
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Bottom info & Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Paid on $dateStr • ${p.paymentMethod}${p.referenceNumber != null ? ' (${p.referenceNumber})' : ''}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        Row(
                          children: [
                            // View Payslip Button
                            TextButton.icon(
                              onPressed: () => _openPayslip(context, p),
                              icon: const Icon(Icons.receipt, size: 16),
                              label: Text(
                                AppTranslations.text('view_payslip', lang),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            // Delete Button
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                size: 18,
                                color: Colors.red,
                              ),
                              tooltip: 'Delete Payment',
                              onPressed:
                                  () => _confirmDeletePayment(
                                    context,
                                    ref,
                                    p.id,
                                    lang,
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
      loading: () => AppSkeleton.list(count: 5),
      error:
          (err, stack) => Center(
            child: AppErrorView(
              error: err,
              stackTrace: stack,
              onRetry: () => ref.refresh(salaryPaymentsStreamProvider),
            ),
          ),
    );
  }

  void _openPayslip(BuildContext context, SalaryPaymentWithDetails payment) {
    showDialog(
      context: context,
      builder:
          (context) => _PayslipDialog(
            payment: payment,
            formatAmount: formatAmount,
            getMonthName: getMonthName,
          ),
    );
  }

  void _confirmDeletePayment(
    BuildContext context,
    WidgetRef ref,
    int paymentId,
    String lang,
  ) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(AppTranslations.text('delete', lang)),
            content: Text(AppTranslations.text('confirm_delete_payment', lang)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(AppTranslations.text('cancel', lang)),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () async {
                  Navigator.pop(context);
                  final success = await ref
                      .read(payrollControllerProvider.notifier)
                      .deleteSalaryPayment(paymentId);
                  if (context.mounted) {
                    context.showSnackbar(
                      SnackBar(
                        content: Text(
                          success
                              ? 'Salary payment deleted and advance restored'
                              : 'Failed to delete payment',
                        ),
                      ),
                    );
                  }
                },
                child: Text(AppTranslations.text('delete', lang)),
              ),
            ],
          ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  const _DetailChip({
    required this.label,
    required this.value,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? Colors.grey.shade700;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withAlpha(15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: chipColor),
          const SizedBox(width: 4),
          Text(
            '$label: ',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: chipColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// SALARY ADVANCES TAB
// ==========================================

class _SalaryAdvancesTab extends ConsumerWidget {
  final String Function(double) formatAmount;

  const _SalaryAdvancesTab({required this.formatAmount});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final advancesAsync = ref.watch(salaryAdvancesStreamProvider);
    final lang = ref.watch(localeProvider).locale.languageCode;
    final calendarMode = ref.watch(calendarProvider);
    final isNepali = lang == 'ne';
    final activeStatusFilter = ref.watch(payrollAdvanceStatusFilterProvider);

    return Column(
      children: [
        // Status Filter Chips
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              FilterChip(
                selected: activeStatusFilter == 'active',
                label: const Text('Active / Outstanding'),
                onSelected:
                    (_) => ref
                        .read(payrollAdvanceStatusFilterProvider.notifier)
                        .setStatus('active'),
              ),
              const SizedBox(width: 8),
              FilterChip(
                selected: activeStatusFilter == 'settled',
                label: Text(AppTranslations.text('settled', lang)),
                onSelected:
                    (_) => ref
                        .read(payrollAdvanceStatusFilterProvider.notifier)
                        .setStatus('settled'),
              ),
              const SizedBox(width: 8),
              FilterChip(
                selected: activeStatusFilter == 'all',
                label: const Text('All Advances'),
                onSelected:
                    (_) => ref
                        .read(payrollAdvanceStatusFilterProvider.notifier)
                        .setStatus('all'),
              ),
            ],
          ),
        ),

        Expanded(
          child: advancesAsync.when(
            data: (advances) {
              if (advances.isEmpty) {
                return Center(
                  child: AppEmptyState.noData(
                    title: AppTranslations.text('no_salary_advances', lang),
                    icon: Icons.monetization_on_outlined,
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                itemCount: advances.length,
                itemBuilder: (context, index) {
                  final adv = advances[index];
                  final isSettled = adv.isSettled;
                  final progress =
                      adv.amount > 0
                          ? (adv.adjustedAmount / adv.amount).clamp(0.0, 1.0)
                          : 0.0;
                  final dateStr = DateTimeUtils.formatDateByMode(
                    adv.advanceDate,
                    mode: calendarMode,
                    inNepaliScript: isNepali,
                  );

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 1,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header: Employee Name, Status Chip
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    adv.employeeName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  Text(
                                    '${adv.designation} • ${adv.employeeType.name.toUpperCase()}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (adv.academicYear != null) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.indigo.withAlpha(25),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.school_outlined,
                                            size: 12,
                                            color: Colors.indigo,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            adv.academicYear!.name,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.indigo,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          isSettled
                                              ? Colors.green.withAlpha(30)
                                              : Colors.deepOrange.withAlpha(30),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      isSettled ? 'SETTLED' : 'ACTIVE',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color:
                                            isSettled
                                                ? Colors.green
                                                : Colors.deepOrange,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Amounts Row: Original, Adjusted, Remaining
                          Row(
                            children: [
                              Expanded(
                                child: _AmountBlock(
                                  label: 'Original Advance',
                                  value: formatAmount(adv.amount),
                                  color: Colors.blueGrey,
                                ),
                              ),
                              Expanded(
                                child: _AmountBlock(
                                  label: 'Recovered / Adjusted',
                                  value: formatAmount(adv.adjustedAmount),
                                  color: Colors.green,
                                ),
                              ),
                              Expanded(
                                child: _AmountBlock(
                                  label: 'Remaining Balance',
                                  value: formatAmount(adv.remainingAmount),
                                  color:
                                      isSettled
                                          ? Colors.grey
                                          : Colors.deepOrange,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Progress Bar
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 6,
                              backgroundColor: Colors.grey.shade200,
                              valueColor: AlwaysStoppedAnimation(
                                isSettled ? Colors.green : Colors.deepOrange,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Footer Info
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Given on $dateStr via ${adv.paymentMethod}${adv.reason != null ? ' • ${adv.reason}' : ''}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              if (adv.adjustedAmount <= 0.001)
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                    color: Colors.red,
                                  ),
                                  tooltip: 'Delete Advance',
                                  onPressed:
                                      () => _confirmDeleteAdvance(
                                        context,
                                        ref,
                                        adv.id,
                                        lang,
                                      ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
            loading: () => AppSkeleton.list(count: 4),
            error:
                (err, stack) => Center(
                  child: AppErrorView(
                    error: err,
                    stackTrace: stack,
                    onRetry: () => ref.refresh(salaryAdvancesStreamProvider),
                  ),
                ),
          ),
        ),
      ],
    );
  }

  void _confirmDeleteAdvance(
    BuildContext context,
    WidgetRef ref,
    int advanceId,
    String lang,
  ) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(AppTranslations.text('delete', lang)),
            content: Text(AppTranslations.text('confirm_delete_advance', lang)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(AppTranslations.text('cancel', lang)),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () async {
                  Navigator.pop(context);
                  final success = await ref
                      .read(payrollControllerProvider.notifier)
                      .deleteSalaryAdvance(advanceId);
                  if (context.mounted) {
                    context.showSnackbar(
                      SnackBar(
                        content: Text(
                          success
                              ? 'Advance deleted successfully'
                              : 'Failed to delete advance',
                        ),
                      ),
                    );
                  }
                },
                child: Text(AppTranslations.text('delete', lang)),
              ),
            ],
          ),
    );
  }
}

class _AmountBlock extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _AmountBlock({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

// ==========================================
// PAY SALARY DIALOG WITH AUTO-CALCULATE
// ==========================================

class _PaySalaryDialog extends ConsumerStatefulWidget {
  final String Function(double) formatAmount;
  final String Function(int) getMonthName;

  const _PaySalaryDialog({
    required this.formatAmount,
    required this.getMonthName,
  });

  @override
  ConsumerState<_PaySalaryDialog> createState() => _PaySalaryDialogState();
}

class _PaySalaryDialogState extends ConsumerState<_PaySalaryDialog> {
  final _formKey = GlobalKey<FormState>();

  int? _selectedEmployeeId;
  int? _selectedAcademicYearId;
  late int _selectedYear;
  late int _selectedMonth;
  DateTime _paymentDate = DateTime.now();

  final _basicSalaryController = TextEditingController();
  final _bonusController = TextEditingController(text: '0');
  final _bonusReasonController = TextEditingController();
  final _deductionController = TextEditingController(text: '0');
  final _deductionReasonController = TextEditingController();
  final _advanceDeductionController = TextEditingController(text: '0');
  final _referenceNumberController = TextEditingController();
  final _notesController = TextEditingController();

  String _paymentMethod = 'Bank Transfer';
  double _outstandingAdvance = 0.0;
  bool _isLoadingAdvance = false;

  final List<String> _paymentMethods = [
    'Bank Transfer',
    'Cash',
    'Cheque',
    'Online / UPI / QR',
    'eSewa',
    'Khalti',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedYear = now.year;
    _selectedMonth = now.month;
  }

  @override
  void dispose() {
    _basicSalaryController.dispose();
    _bonusController.dispose();
    _bonusReasonController.dispose();
    _deductionController.dispose();
    _deductionReasonController.dispose();
    _advanceDeductionController.dispose();
    _referenceNumberController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double get _basicSalary =>
      double.tryParse(_basicSalaryController.text.trim()) ?? 0.0;
  double get _bonus => double.tryParse(_bonusController.text.trim()) ?? 0.0;
  double get _deduction =>
      double.tryParse(_deductionController.text.trim()) ?? 0.0;
  double get _advanceDeduction =>
      double.tryParse(_advanceDeductionController.text.trim()) ?? 0.0;

  double get _grossSalary =>
      PayrollService.calculateGrossSalary(_basicSalary, _bonus);
  double get _totalDeductions =>
      PayrollService.calculateTotalDeductions(_deduction, _advanceDeduction);
  double get _netSalary => PayrollService.calculateNetSalary(
    _basicSalary,
    _bonus,
    _deduction,
    _advanceDeduction,
  );

  Future<void> _onEmployeeChanged(int? empId, List<Employee> employees) async {
    if (empId != null) {
      final emp = employees.firstWhere((e) => e.id == empId);
      final salary = emp.basicSalary;
      final salaryStr =
          (salary != null && salary > 0)
              ? (salary % 1 == 0
                  ? salary.toInt().toString()
                  : salary.toStringAsFixed(2))
              : '';
      _basicSalaryController.text = salaryStr;
      _advanceDeductionController.text = '0';

      setState(() {
        _selectedEmployeeId = empId;
        _isLoadingAdvance = true;
      });

      final adv = await ref
          .read(payrollServiceProvider)
          .getOutstandingAdvance(empId);
      if (mounted && _selectedEmployeeId == empId) {
        setState(() {
          _outstandingAdvance = adv;
          _isLoadingAdvance = false;
        });
      }
    } else {
      _basicSalaryController.text = '';
      _advanceDeductionController.text = '0';
      setState(() {
        _selectedEmployeeId = null;
        _outstandingAdvance = 0.0;
        _isLoadingAdvance = false;
      });
    }
  }

  void _setFullAdvanceSettlement() {
    final maxDeductible = max(0.0, _grossSalary - _deduction);
    final settlement = min(_outstandingAdvance, maxDeductible);
    _advanceDeductionController.text = settlement.toStringAsFixed(2);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lang = ref.watch(localeProvider).locale.languageCode;
    final calendarMode = ref.watch(calendarProvider);
    final isNepali = lang == 'ne';
    final employeesAsync = ref.watch(allEmployeesStreamProvider);
    final academicYearsAsync = ref.watch(academicYearsStreamProvider);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.payment, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(AppTranslations.text('pay_salary', lang)),
        ],
      ),
      content: SizedBox(
        width: 580,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Employee Dropdown
                employeesAsync.when(
                  data: (employees) {
                    return AppSearchableSelect<int>(
                      value: _selectedEmployeeId,
                      label: AppTranslations.text('employee', lang),
                      prefixIcon: const Icon(Icons.person, size: 20),
                      items:
                          employees.map((emp) {
                            final salaryText =
                                (emp.basicSalary != null &&
                                        emp.basicSalary! > 0)
                                    ? ' - ${widget.formatAmount(emp.basicSalary!)}'
                                    : '';
                            return SearchableSelectItem<int>(
                              value: emp.id,
                              label:
                                  '${emp.name} (${emp.designation}$salaryText)',
                            );
                          }).toList(),
                      onChanged: (val) => _onEmployeeChanged(val, employees),
                      validator:
                          (val) =>
                              val == null ? 'Please select an employee' : null,
                    );
                  },
                  loading: () => const LinearProgressIndicator(),
                  error: (err, _) => Text('Error: $err'),
                ),
                const SizedBox(height: 12),

                // Outstanding Advance Banner if applicable
                if (_selectedEmployeeId != null) ...[
                  if (_isLoadingAdvance)
                    const LinearProgressIndicator()
                  else if (_outstandingAdvance > 0)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.deepOrange.withAlpha(20),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.deepOrange.withAlpha(80),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: Colors.deepOrange,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Outstanding Advance: ${widget.formatAmount(_outstandingAdvance)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.deepOrange,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withAlpha(20),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle_outline,
                            color: Colors.green,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            AppTranslations.text(
                              'no_outstanding_advance',
                              lang,
                            ),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                ],

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
                      prefixIcon: const Icon(Icons.school, size: 20),
                      items:
                          years.map((y) {
                            return SearchableSelectItem<int>(
                              value: y.id,
                              label: y.name + (y.isCurrent ? ' (Active)' : ''),
                            );
                          }).toList(),
                      onChanged: (val) {
                        setState(() => _selectedAcademicYearId = val);
                      },
                    );
                  },
                  loading: () => const LinearProgressIndicator(),
                  error: (_, _) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 12),

                // 2. Pay Period Row (Year & Month)
                Row(
                  children: [
                    // Year
                    Expanded(
                      child: AppSearchableSelect<int>(
                        value: _selectedYear,
                        label: 'Pay Year',
                        prefixIcon: const Icon(Icons.calendar_today, size: 20),
                        items: [
                          for (
                            int y = DateTime.now().year - 2;
                            y <= DateTime.now().year + 2;
                            y++
                          )
                            SearchableSelectItem<int>(value: y, label: '$y'),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedYear = val);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Month
                    Expanded(
                      child: AppSearchableSelect<int>(
                        value: _selectedMonth,
                        label: 'Pay Month',
                        prefixIcon: const Icon(Icons.event, size: 20),
                        items: [
                          for (int m = 1; m <= 12; m++)
                            SearchableSelectItem<int>(
                              value: m,
                              label: widget.getMonthName(m),
                            ),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedMonth = val);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 3. Basic Salary
                TextFormField(
                  controller: _basicSalaryController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: AppTranslations.text('basic_salary', lang),
                    prefixIcon: const Icon(Icons.attach_money, size: 20),
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Enter basic salary';
                    }
                    final n = double.tryParse(val.trim());
                    if (n == null || n <= 0) {
                      return 'Enter valid basic salary > 0';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // 4. Bonus Row (Amount & Reason)
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _bonusController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: AppTranslations.text('bonus', lang),
                          prefixIcon: const Icon(Icons.add_circle, size: 20),
                        ),
                        onChanged: (_) => setState(() {}),
                        validator: (val) {
                          if (val != null && val.trim().isNotEmpty) {
                            final n = double.tryParse(val.trim());
                            if (n == null || n < 0) {
                              return 'Invalid bonus';
                            }
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _bonusReasonController,
                        decoration: InputDecoration(
                          labelText: AppTranslations.text('bonus_reason', lang),
                          hintText: 'e.g. Festival, Overtime',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 5. Standard Deductions Row (Amount & Reason)
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _deductionController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: AppTranslations.text('deductions', lang),
                          prefixIcon: const Icon(Icons.remove_circle, size: 20),
                        ),
                        onChanged: (_) => setState(() {}),
                        validator: (val) {
                          if (val != null && val.trim().isNotEmpty) {
                            final n = double.tryParse(val.trim());
                            if (n == null || n < 0) {
                              return 'Invalid deduction';
                            }
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _deductionReasonController,
                        decoration: InputDecoration(
                          labelText: AppTranslations.text(
                            'deduction_reason',
                            lang,
                          ),
                          hintText: 'e.g. Tax, Provident Fund',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 6. Advance Salary Adjustment Section
                if (_outstandingAdvance > 0) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        AppTranslations.text('advance_deduction', lang),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Row(
                        children: [
                          ActionChip(
                            label: const Text(
                              'None',
                              style: TextStyle(fontSize: 11),
                            ),
                            onPressed: () {
                              _advanceDeductionController.text = '0';
                              setState(() {});
                            },
                          ),
                          const SizedBox(width: 6),
                          ActionChip(
                            label: const Text(
                              'Full Balance',
                              style: TextStyle(fontSize: 11),
                            ),
                            onPressed: _setFullAdvanceSettlement,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _advanceDeductionController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Deduct from advance (one-term or multi-term)',
                      prefixIcon: Icon(Icons.restore, size: 20),
                    ),
                    onChanged: (_) => setState(() {}),
                    validator: (val) {
                      if (val != null && val.trim().isNotEmpty) {
                        final n = double.tryParse(val.trim());
                        if (n == null || n < 0) {
                          return 'Invalid advance deduction';
                        }
                        if (n > _outstandingAdvance + 0.001) {
                          return 'Exceeds remaining advance (${widget.formatAmount(_outstandingAdvance)})';
                        }
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                ],

                // 7. REAL-TIME AUTO-CALCULATION SUMMARY CARD
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withAlpha(15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: theme.colorScheme.primary.withAlpha(60),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Gross Salary:'),
                          Text(
                            widget.formatAmount(_grossSalary),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total Deductions (Std + Adv):',
                            style: TextStyle(color: Colors.red.shade700),
                          ),
                          Text(
                            '-${widget.formatAmount(_totalDeductions)}',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.red.shade700,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            AppTranslations.text('net_salary', lang),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            widget.formatAmount(_netSalary),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // 8. Payment Method & Date Row
                Row(
                  children: [
                    // Payment Date
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _paymentDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2035),
                          );
                          if (picked != null) {
                            setState(() => _paymentDate = picked);
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Disbursement Date',
                            prefixIcon: Icon(Icons.calendar_month, size: 20),
                          ),
                          child: Text(
                            DateTimeUtils.formatDateByMode(
                              _paymentDate,
                              mode: calendarMode,
                              inNepaliScript: isNepali,
                            ),
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

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
                          if (val != null) setState(() => _paymentMethod = val);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 9. Reference Number & Notes
                TextFormField(
                  controller: _referenceNumberController,
                  decoration: InputDecoration(
                    labelText: AppTranslations.text('reference_no', lang),
                    hintText: 'Cheque / Txn / Voucher #',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: AppTranslations.text('notes', lang),
                    hintText: 'Optional payroll disbursement remarks',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppTranslations.text('cancel', lang)),
        ),
        FilledButton(
          onPressed: _submitPayment,
          child: Text(AppTranslations.text('pay_salary', lang)),
        ),
      ],
    );
  }

  Future<void> _submitPayment() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedEmployeeId == null) return;

    if (_netSalary < 0) {
      context.showSnackbar(
        const SnackBar(
          content: Text('Net salary cannot be negative!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final success = await ref
        .read(payrollControllerProvider.notifier)
        .processSalaryPayment(
          employeeId: _selectedEmployeeId!,
          year: _selectedYear,
          month: _selectedMonth,
          paymentDate: _paymentDate,
          basicSalary: _basicSalary,
          bonus: _bonus,
          bonusReason:
              _bonusReasonController.text.trim().isEmpty
                  ? null
                  : _bonusReasonController.text.trim(),
          deduction: _deduction,
          deductionReason:
              _deductionReasonController.text.trim().isEmpty
                  ? null
                  : _deductionReasonController.text.trim(),
          advanceDeduction: _advanceDeduction,
          paymentMethod: _paymentMethod,
          referenceNumber:
              _referenceNumberController.text.trim().isEmpty
                  ? null
                  : _referenceNumberController.text.trim(),
          notes:
              _notesController.text.trim().isEmpty
                  ? null
                  : _notesController.text.trim(),
          academicYearId: _selectedAcademicYearId,
        );

    if (mounted) {
      if (success) {
        Navigator.pop(context);
        context.showSnackbar(
          const SnackBar(content: Text('Salary disbursed successfully!')),
        );
      } else {
        context.showSnackbar(
          const SnackBar(
            content: Text('Failed to disburse salary. Check inputs.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

// ==========================================
// GIVE ADVANCE DIALOG
// ==========================================

class _GiveAdvanceDialog extends ConsumerStatefulWidget {
  final String Function(double) formatAmount;

  const _GiveAdvanceDialog({required this.formatAmount});

  @override
  ConsumerState<_GiveAdvanceDialog> createState() => _GiveAdvanceDialogState();
}

class _GiveAdvanceDialogState extends ConsumerState<_GiveAdvanceDialog> {
  final _formKey = GlobalKey<FormState>();

  int? _selectedEmployeeId;
  int? _selectedAcademicYearId;
  DateTime _advanceDate = DateTime.now();
  final _amountController = TextEditingController();
  final _reasonController = TextEditingController();
  final _referenceNumberController = TextEditingController();
  final _notesController = TextEditingController();
  String _paymentMethod = 'Cash';

  final List<String> _paymentMethods = [
    'Cash',
    'Bank Transfer',
    'Cheque',
    'Online / UPI / QR',
  ];

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    _referenceNumberController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lang = ref.watch(localeProvider).locale.languageCode;
    final calendarMode = ref.watch(calendarProvider);
    final isNepali = lang == 'ne';
    final employeesAsync = ref.watch(allEmployeesStreamProvider);
    final academicYearsAsync = ref.watch(academicYearsStreamProvider);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.handshake_outlined, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(AppTranslations.text('give_advance', lang)),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                      prefixIcon: const Icon(Icons.school, size: 20),
                      items:
                          years.map((y) {
                            return SearchableSelectItem<int>(
                              value: y.id,
                              label: y.name + (y.isCurrent ? ' (Active)' : ''),
                            );
                          }).toList(),
                      onChanged: (val) {
                        setState(() => _selectedAcademicYearId = val);
                      },
                    );
                  },
                  loading: () => const LinearProgressIndicator(),
                  error: (_, _) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 12),

                // Employee Dropdown
                employeesAsync.when(
                  data: (employees) {
                    return AppSearchableSelect<int>(
                      value: _selectedEmployeeId,
                      label: AppTranslations.text('employee', lang),
                      prefixIcon: const Icon(Icons.person, size: 20),
                      items:
                          employees.map((emp) {
                            return SearchableSelectItem<int>(
                              value: emp.id,
                              label: '${emp.name} (${emp.designation})',
                            );
                          }).toList(),
                      onChanged: (val) {
                        setState(() => _selectedEmployeeId = val);
                      },
                      validator:
                          (val) =>
                              val == null ? 'Please select an employee' : null,
                    );
                  },
                  loading: () => const LinearProgressIndicator(),
                  error: (err, _) => Text('Error: $err'),
                ),
                const SizedBox(height: 12),

                // Amount Field
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: AppTranslations.text('amount', lang),
                    prefixIcon: const Icon(Icons.currency_rupee, size: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Enter advance amount';
                    }
                    final n = double.tryParse(val.trim());
                    if (n == null || n <= 0) {
                      return 'Enter valid amount > 0';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Date & Payment Method
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _advanceDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2035),
                          );
                          if (picked != null) {
                            setState(() => _advanceDate = picked);
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Advance Date',
                            prefixIcon: Icon(Icons.calendar_month, size: 20),
                          ),
                          child: Text(
                            DateTimeUtils.formatDateByMode(
                              _advanceDate,
                              mode: calendarMode,
                              inNepaliScript: isNepali,
                            ),
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
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
                          if (val != null) setState(() => _paymentMethod = val);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Reason / Notes
                TextFormField(
                  controller: _reasonController,
                  decoration: const InputDecoration(
                    labelText: 'Reason for Advance',
                    hintText: 'e.g. Medical emergency, Festival, Personal',
                    prefixIcon: Icon(Icons.notes, size: 20),
                  ),
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _referenceNumberController,
                  decoration: InputDecoration(
                    labelText: AppTranslations.text('reference_no', lang),
                    hintText: 'Voucher / Txn ID',
                  ),
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Notes',
                    hintText: 'Agreed repayment terms or remarks',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppTranslations.text('cancel', lang)),
        ),
        FilledButton(
          onPressed: _submitAdvance,
          child: Text(AppTranslations.text('give_advance', lang)),
        ),
      ],
    );
  }

  Future<void> _submitAdvance() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedEmployeeId == null) return;

    final amount = double.parse(_amountController.text.trim());

    final success = await ref
        .read(payrollControllerProvider.notifier)
        .giveSalaryAdvance(
          employeeId: _selectedEmployeeId!,
          amount: amount,
          advanceDate: _advanceDate,
          paymentMethod: _paymentMethod,
          referenceNumber:
              _referenceNumberController.text.trim().isEmpty
                  ? null
                  : _referenceNumberController.text.trim(),
          reason:
              _reasonController.text.trim().isEmpty
                  ? null
                  : _reasonController.text.trim(),
          notes:
              _notesController.text.trim().isEmpty
                  ? null
                  : _notesController.text.trim(),
          academicYearId: _selectedAcademicYearId,
        );

    if (mounted) {
      if (success) {
        Navigator.pop(context);
        context.showSnackbar(
          const SnackBar(content: Text('Salary advance granted successfully!')),
        );
      } else {
        context.showSnackbar(
          const SnackBar(
            content: Text('Failed to grant advance'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

// ==========================================
// FORMAL SALARY PAYSLIP DIALOG
// ==========================================

class _PayslipDialog extends ConsumerWidget {
  final SalaryPaymentWithDetails payment;
  final String Function(double) formatAmount;
  final String Function(int) getMonthName;

  const _PayslipDialog({
    required this.payment,
    required this.formatAmount,
    required this.getMonthName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final lang = ref.watch(localeProvider).locale.languageCode;
    final calendarMode = ref.watch(calendarProvider);
    final isNepali = lang == 'ne';

    final dateStr = DateTimeUtils.formatDateByMode(
      payment.paymentDate,
      mode: calendarMode,
      inNepaliScript: isNepali,
    );

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // School Header
              Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.account_balance,
                      size: 36,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'SCHOOL MANAGEMENT SYSTEM',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                      ),
                    ),
                    Text(
                      'SALARY DISBURSEMENT PAYSLIP',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Divider(),

              // Employee & Period Details Box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    _RowLabel(
                      'Employee Name:',
                      payment.employeeName,
                      boldValue: true,
                    ),
                    const SizedBox(height: 4),
                    _RowLabel(
                      'Designation:',
                      '${payment.designation} (${payment.employeeType.name.toUpperCase()})',
                    ),
                    const SizedBox(height: 4),
                    _RowLabel(
                      'Pay Period:',
                      '${getMonthName(payment.month)} ${payment.year}',
                      boldValue: true,
                    ),
                    if (payment.academicYear != null) ...[
                      const SizedBox(height: 4),
                      _RowLabel('Academic Year:', payment.academicYear!.name),
                    ],
                    const SizedBox(height: 4),
                    _RowLabel('Disbursement Date:', dateStr),
                    const SizedBox(height: 4),
                    _RowLabel(
                      'Payment Method:',
                      '${payment.paymentMethod}${payment.referenceNumber != null ? ' (${payment.referenceNumber})' : ''}',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Earnings & Deductions Tables
              const Text(
                'EARNINGS & ALLOWANCES',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              _ItemRow('Basic Salary', formatAmount(payment.basicSalary)),
              if (payment.bonus > 0)
                _ItemRow(
                  'Bonus / Allowance ${payment.bonusReason != null ? '(${payment.bonusReason})' : ''}',
                  formatAmount(payment.bonus),
                  color: Colors.green,
                ),
              const Divider(height: 12),
              _ItemRow(
                'Gross Earnings',
                formatAmount(payment.grossSalary),
                isBold: true,
              ),

              const SizedBox(height: 14),
              const Text(
                'DEDUCTIONS & ADVANCE RECOVERY',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              if (payment.deduction > 0)
                _ItemRow(
                  'Standard Deductions ${payment.deductionReason != null ? '(${payment.deductionReason})' : ''}',
                  '-${formatAmount(payment.deduction)}',
                  color: Colors.red.shade700,
                ),
              if (payment.advanceDeduction > 0)
                _ItemRow(
                  'Advance Recovery Deducted',
                  '-${formatAmount(payment.advanceDeduction)}',
                  color: Colors.deepOrange,
                ),
              if (payment.totalDeductions <= 0)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    'No deductions applied',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              const Divider(height: 12),
              _ItemRow(
                'Total Deductions',
                '-${formatAmount(payment.totalDeductions)}',
                isBold: true,
                color: Colors.red.shade700,
              ),

              const SizedBox(height: 16),

              // Net Payable Highlight Box
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.green.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green.withAlpha(80)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'NET PAYABLE SALARY:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      formatAmount(payment.netSalary),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Close Button
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(AppTranslations.text('close', lang)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RowLabel extends StatelessWidget {
  final String label;
  final String value;
  final bool boldValue;

  const _RowLabel(this.label, this.value, {this.boldValue = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: boldValue ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}

class _ItemRow extends StatelessWidget {
  final String title;
  final String amount;
  final bool isBold;
  final Color? color;

  const _ItemRow(this.title, this.amount, {this.isBold = false, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
