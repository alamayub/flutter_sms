import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../../config/responsive.dart';
import '../../config/translations.dart';
import '../../data/app_database.dart';
import '../../providers/academic_year_provider.dart';
import '../../providers/class_section_provider.dart';
import '../../providers/fee_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/student_provider.dart';
import '../../services/fee_service.dart';
import '../../widgets/searchable_select.dart';

class FeeCollectionScreen extends ConsumerStatefulWidget {
  const FeeCollectionScreen({super.key});

  @override
  ConsumerState<FeeCollectionScreen> createState() =>
      _FeeCollectionScreenState();
}

class _FeeCollectionScreenState extends ConsumerState<FeeCollectionScreen>
    with TickerProviderStateMixin {
  late TabController _studentTabController;
  late TabController _schoolTabController;
  final TextEditingController _studentSearchController =
      TextEditingController();
  final Set<int> _selectedFeeIds = {};
  int? _selectedDueMonth;

  @override
  void initState() {
    super.initState();
    _studentTabController = TabController(length: 2, vsync: this);
    _schoolTabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _studentTabController.dispose();
    _schoolTabController.dispose();
    _studentSearchController.dispose();
    super.dispose();
  }

  String _formatCurrency(double amount) {
    return 'Rs. ${NumberFormat('#,##0.00').format(amount)}';
  }

  String _formatDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  Future<void> _pickCustomDateRange(BuildContext context) async {
    final currentRange = ref.read(feeCustomDateRangeProvider);
    final initialRange = DateTimeRange(
      start:
          currentRange.start ??
          DateTime.now().subtract(const Duration(days: 30)),
      end: currentRange.end ?? DateTime.now(),
    );

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: initialRange,
    );

    if (picked != null) {
      ref
          .read(feeCustomDateRangeProvider.notifier)
          .setRange(picked.start, picked.end);
      ref
          .read(feePeriodFilterProvider.notifier)
          .setPeriod(FeePeriodType.custom);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeProvider).locale.languageCode;
    final selectedStudent = ref.watch(selectedStudentForFeeProvider);
    final summaryAsync = ref.watch(feeSummaryStatsProvider);
    final activeYearAsync = ref.watch(activeAcademicYearProvider);
    final academicYearsAsync = ref.watch(academicYearsStreamProvider);
    final selectedYearId = ref.watch(feeAcademicYearFilterProvider);
    final selectedPeriod = ref.watch(feePeriodFilterProvider);
    final customDateRange = ref.watch(feeCustomDateRangeProvider);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.receipt_long, color: Colors.indigo),
            const SizedBox(width: 8),
            Text(
              AppTranslations.text('fee_collection', lang),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: AppTranslations.text('fee_categories', lang),
            icon: const Icon(Icons.tune),
            onPressed: () => _showAddFeeCategoryDialog(context),
          ),
          IconButton(
            tooltip: AppTranslations.text('assign_fee', lang),
            icon: const Icon(Icons.add_card),
            onPressed: () => _showAssignFeeDialog(context, selectedStudent),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // 1. Unified Filters & Action Bar + Global Analytics Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Filter & Action Toolbar Card
                  Card(
                    elevation: 0,
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 10,
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          // Left side: Academic Year Selector + Period Filter Chips
                          Wrap(
                            spacing: 10,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              // Academic Session Dropdown Filter
                              academicYearsAsync.when(
                                data: (years) {
                                  return SizedBox(
                                    width: 220,
                                    child: AppSearchableSelect<int>.filter(
                                      value: selectedYearId,
                                      hint:
                                          activeYearAsync.value?.name ??
                                          AppTranslations.text(
                                            'all_academic_years',
                                            lang,
                                          ),
                                      isClearable: true,
                                      items:
                                          years.map((y) {
                                            return SearchableSelectItem<int>(
                                              value: y.id,
                                              label:
                                                  y.name +
                                                  (y.isCurrent
                                                      ? ' (Active)'
                                                      : ''),
                                              leading: Icon(
                                                Icons.school,
                                                size: 16,
                                                color:
                                                    y.isCurrent
                                                        ? Colors.indigo
                                                        : Colors.grey.shade700,
                                              ),
                                            );
                                          }).toList(),
                                      onChanged: (val) {
                                        ref
                                            .read(
                                              feeAcademicYearFilterProvider
                                                  .notifier,
                                            )
                                            .setAcademicYear(val);
                                      },
                                    ),
                                  );
                                },
                                loading:
                                    () => const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                error: (e, s) => const SizedBox.shrink(),
                              ),

                              // Period filter chips
                              ...FeePeriodType.values.map((period) {
                                final isSelected = selectedPeriod == period;
                                return ChoiceChip(
                                  label: Text(period.label),
                                  selected: isSelected,
                                  selectedColor: Colors.indigo.shade100,
                                  labelStyle: TextStyle(
                                    color:
                                        isSelected
                                            ? Colors.indigo.shade900
                                            : Colors.black87,
                                    fontWeight:
                                        isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                    fontSize: 12,
                                  ),
                                  onSelected: (selected) {
                                    if (selected) {
                                      ref
                                          .read(
                                            feePeriodFilterProvider.notifier,
                                          )
                                          .setPeriod(period);
                                      if (period == FeePeriodType.custom) {
                                        _pickCustomDateRange(context);
                                      }
                                    }
                                  },
                                );
                              }),
                            ],
                          ),

                          // Right side: Action Buttons
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.indigo.shade800,
                                  side: BorderSide(
                                    color: Colors.indigo.shade200,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                icon: const Icon(Icons.group_add, size: 16),
                                label: Text(
                                  AppTranslations.text('bulk_assign_fee', lang),
                                ),
                                onPressed:
                                    () => _showBulkAssignFeeDialog(context),
                              ),
                              FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.indigo,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                icon: const Icon(Icons.add_card, size: 16),
                                label: Text(
                                  AppTranslations.text('assign_fee', lang),
                                ),
                                onPressed:
                                    () => _showAssignFeeDialog(
                                      context,
                                      selectedStudent,
                                    ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Custom date range indicator if custom selected
                  if (selectedPeriod == FeePeriodType.custom &&
                      (customDateRange.start != null ||
                          customDateRange.end != null)) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.indigo.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.indigo.shade200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            size: 14,
                            color: Colors.indigo,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${customDateRange.start != null ? _formatDate(customDateRange.start!) : 'Any'} → ${customDateRange.end != null ? _formatDate(customDateRange.end!) : 'Any'}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.indigo.shade900,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () => _pickCustomDateRange(context),
                            child: const Text(
                              'Change',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.indigo,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),

                  // Analytics Cards
                  summaryAsync.when(
                    data: (summary) => _buildAnalyticsRow(summary, lang),
                    loading:
                        () => const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: CircularProgressIndicator(),
                          ),
                        ),
                    error: (e, _) => Center(child: Text('Error: $e')),
                  ),
                  const SizedBox(height: 16),

                  // Student Lookup & Selection Bar
                  _buildStudentSelector(context, selectedStudent, lang),
                ],
              ),
            ),
          ),

          // 2. Body Area (Student specific ledger OR School-wide Overview)
          if (selectedStudent != null)
            SliverFillRemaining(
              hasScrollBody: true,
              child: _buildStudentLedgerView(context, selectedStudent, lang),
            )
          else
            SliverFillRemaining(
              hasScrollBody: true,
              child: _buildSchoolWideView(context, lang),
            ),
        ],
      ),
    );
  }

  // ==================== ANALYTICS CARDS ====================

  Widget _buildAnalyticsRow(FeeCollectionSummary summary, String lang) {
    final period = ref.watch(feePeriodFilterProvider);
    final periodLabel =
        period == FeePeriodType.allTime
            ? 'All Time'
            : period == FeePeriodType.today
            ? 'Today'
            : period.label;

    return Responsive(
      mobile: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  title: AppTranslations.text('collected_fee', lang),
                  value: _formatCurrency(summary.totalCollected),
                  subtitle:
                      '$periodLabel (${summary.paymentTransactionsCount} txns)',
                  icon: Icons.payments,
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricCard(
                  title: AppTranslations.text('pending_fee', lang),
                  value: _formatCurrency(summary.totalPending),
                  subtitle:
                      '${summary.pendingFeesCount + summary.partialFeesCount} fees pending',
                  icon: Icons.pending_actions,
                  color: Colors.orange.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  title: AppTranslations.text('total_invoiced', lang),
                  value: _formatCurrency(summary.totalInvoiced),
                  subtitle: '${summary.totalFeesCount} fees assessed',
                  icon: Icons.account_balance_wallet,
                  color: Colors.blue.shade700,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricCard(
                  title: AppTranslations.text('total_discount', lang),
                  value: _formatCurrency(summary.totalDiscount),
                  subtitle: 'Scholarships & waivers',
                  icon: Icons.local_offer,
                  color: Colors.purple.shade700,
                ),
              ),
            ],
          ),
        ],
      ),
      desktop: Row(
        children: [
          Expanded(
            child: _buildMetricCard(
              title: AppTranslations.text('collected_fee', lang),
              value: _formatCurrency(summary.totalCollected),
              subtitle:
                  '$periodLabel (${summary.paymentTransactionsCount} payments)',
              icon: Icons.payments,
              color: Colors.green,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildMetricCard(
              title: AppTranslations.text('pending_fee', lang),
              value: _formatCurrency(summary.totalPending),
              subtitle:
                  '${summary.pendingFeesCount + summary.partialFeesCount} unpaid/partial',
              icon: Icons.pending_actions,
              color: Colors.orange.shade800,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildMetricCard(
              title: AppTranslations.text('total_invoiced', lang),
              value: _formatCurrency(summary.totalInvoiced),
              subtitle: '${summary.totalFeesCount} fees assessed',
              icon: Icons.account_balance_wallet,
              color: Colors.blue.shade700,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildMetricCard(
              title: AppTranslations.text('total_discount', lang),
              value: _formatCurrency(summary.totalDiscount),
              subtitle: 'Scholarships / waivers',
              icon: Icons.local_offer,
              color: Colors.purple.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withAlpha(30),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 16, color: color),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ==================== STUDENT SELECTOR BAR ====================

  Widget _buildStudentSelector(
    BuildContext context,
    Student? selectedStudent,
    String lang,
  ) {
    if (selectedStudent != null) {
      // Selected Student Header Banner
      final studentSummaryAsync = ref.watch(
        selectedStudentFinancialSummaryProvider,
      );

      return Card(
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: Colors.indigo.shade200, width: 1.5),
        ),
        color: Colors.indigo.shade50.withAlpha(120),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: Colors.indigo.shade700,
                    child: Text(
                      selectedStudent.name.isNotEmpty
                          ? selectedStudent.name[0].toUpperCase()
                          : 'S',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                selectedStudent.name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.indigo.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                selectedStudent.admissionNumber,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.indigo.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Roll: ${selectedStudent.rollNumber ?? 'N/A'} • Gender: ${selectedStudent.gender}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close Student View',
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () {
                      ref.read(selectedStudentForFeeProvider.notifier).clear();
                    },
                  ),
                ],
              ),
              const Divider(height: 20),

              // Mini student balance breakdown
              studentSummaryAsync.when(
                data: (summary) {
                  if (summary == null) return const SizedBox.shrink();
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStudentChipStat(
                        'Total Due',
                        _formatCurrency(summary.totalPending),
                        Colors.red.shade700,
                      ),
                      _buildStudentChipStat(
                        'Total Paid',
                        _formatCurrency(summary.totalPaid),
                        Colors.green.shade700,
                      ),
                      _buildStudentChipStat(
                        'Assessed',
                        _formatCurrency(summary.totalInvoiced),
                        Colors.blue.shade700,
                      ),
                      _buildStudentChipStat(
                        'Discount',
                        _formatCurrency(summary.totalDiscount),
                        Colors.purple.shade700,
                      ),
                    ],
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (e, s) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 12),
              // Facility badges and Pay Student Fee action
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (selectedStudent.hasTransport)
                        _buildFacilityBadge(
                          icon: Icons.directions_bus,
                          label: 'Transport',
                          color: Colors.blue,
                        ),
                      if (selectedStudent.hasHostel)
                        _buildFacilityBadge(
                          icon: Icons.hotel,
                          label: 'Hostel',
                          color: Colors.orange,
                        ),
                      if (selectedStudent.hasLibrary)
                        _buildFacilityBadge(
                          icon: Icons.local_library,
                          label: 'Library',
                          color: Colors.teal,
                        ),
                      if (!selectedStudent.hasTransport &&
                          !selectedStudent.hasHostel &&
                          !selectedStudent.hasLibrary)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Text(
                            'Standard (No Opted Facilities)',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.payment, size: 18),
                    label: const Text(
                      'Pay Student Fee',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    onPressed:
                        () =>
                            _showPayStudentFeeDialog(context, selectedStudent),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    // Autocomplete Search Bar when NO student is selected
    final studentsListAsync = ref.watch(studentsListStreamProvider);

    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          children: [
            const Icon(Icons.search, color: Colors.indigo),
            const SizedBox(width: 8),
            Expanded(
              child: studentsListAsync.when(
                data: (students) {
                  return Autocomplete<Student>(
                    displayStringForOption:
                        (s) =>
                            '${s.name} (${s.admissionNumber}, Roll: ${s.rollNumber ?? '-'})',
                    optionsBuilder: (textEditingValue) {
                      if (textEditingValue.text.trim().isEmpty) {
                        return const Iterable<Student>.empty();
                      }
                      final query = textEditingValue.text.toLowerCase();
                      return students.map((swd) => swd.student).where((s) {
                        return s.name.toLowerCase().contains(query) ||
                            s.admissionNumber.toLowerCase().contains(query) ||
                            (s.rollNumber?.toString().contains(query) ?? false);
                      });
                    },
                    onSelected: (student) {
                      ref
                          .read(selectedStudentForFeeProvider.notifier)
                          .selectStudent(student);
                    },
                    fieldViewBuilder: (
                      context,
                      controller,
                      focusNode,
                      onFieldSubmitted,
                    ) {
                      return TextField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: InputDecoration(
                          hintText: AppTranslations.text(
                            'select_student',
                            lang,
                          ),
                          hintStyle: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade500,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      );
                    },
                  );
                },
                loading:
                    () => Text(
                      AppTranslations.text('select_student', lang),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade400,
                      ),
                    ),
                error: (e, s) => const Text('Error loading students'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentChipStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
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

  // ==================== STUDENT LEDGER VIEW ====================

  Widget _buildStudentLedgerView(
    BuildContext context,
    Student student,
    String lang,
  ) {
    return Column(
      children: [
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _studentTabController,
            labelColor: Colors.indigo,
            unselectedLabelColor: Colors.grey.shade600,
            indicatorColor: Colors.indigo,
            indicatorWeight: 3,
            tabs: const [
              Tab(
                icon: Icon(Icons.list_alt, size: 18),
                text: 'Assigned Fees & Dues',
              ),
              Tab(icon: Icon(Icons.history, size: 18), text: 'Payment History'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _studentTabController,
            children: [
              _buildAssignedFeesTab(context, student, lang),
              _buildStudentPaymentHistoryTab(context, student, lang),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAssignedFeesTab(
    BuildContext context,
    Student student,
    String lang,
  ) {
    final feesAsync = ref.watch(studentFeesStreamProvider);
    final statusFilter = ref.watch(feeStatusFilterProvider);
    final freqFilter = ref.watch(feeFrequencyFilterProvider);

    return Column(
      children: [
        // Sub-filters for Frequency & Status
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.grey.shade100,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Status Filter Dropdown
                SizedBox(
                  width: 140,
                  child: AppSearchableSelect<String>.filter(
                    value: statusFilter,
                    isClearable: false,
                    items: const [
                      SearchableSelectItem(value: 'all', label: 'All Status'),
                      SearchableSelectItem(value: 'pending', label: 'Pending'),
                      SearchableSelectItem(value: 'partial', label: 'Partial'),
                      SearchableSelectItem(value: 'paid', label: 'Paid'),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        ref
                            .read(feeStatusFilterProvider.notifier)
                            .setStatus(val);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 16),
                const Text('|', style: TextStyle(color: Colors.grey)),
                const SizedBox(width: 16),

                // Frequency Filter Chips
                ...[
                  ('all', 'All Types'),
                  ('one_time', 'One-Time'),
                  ('monthly', 'Monthly'),
                  ('term_wise', 'Term-Wise'),
                  ('yearly', 'Yearly'),
                ].map((pair) {
                  final isSelected = freqFilter == pair.$1;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(pair.$2),
                      selected: isSelected,
                      selectedColor: Colors.indigo.shade100,
                      labelStyle: TextStyle(
                        fontSize: 11,
                        color:
                            isSelected
                                ? Colors.indigo.shade900
                                : Colors.black87,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      onSelected: (_) {
                        ref
                            .read(feeFrequencyFilterProvider.notifier)
                            .setFrequency(pair.$1);
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
        ),

        // Action Toolbar: Pay Student Fee, Admission Package & Select All Dues
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.white,
          child: Row(
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.payment, size: 16),
                label: const Text('Pay Student Fee'),
                onPressed: () => _showPayStudentFeeDialog(context, student),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: Colors.indigo,
                ),
                icon: const Icon(Icons.school, size: 16),
                label: const Text('Admission Package'),
                onPressed:
                    () => _showAssessAdmissionPackageDialog(context, student),
              ),
              const Spacer(),
              feesAsync.maybeWhen(
                data: (fees) {
                  final pendingDues =
                      fees.where((f) => f.remainingAmount > 0.01).toList();
                  if (pendingDues.isEmpty) return const SizedBox.shrink();
                  final allSelected = pendingDues.every(
                    (f) => _selectedFeeIds.contains(f.id),
                  );
                  return TextButton.icon(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: Icon(
                      allSelected
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      size: 16,
                      color: Colors.indigo,
                    ),
                    label: Text(
                      allSelected
                          ? 'Deselect All'
                          : 'Select All Dues (${pendingDues.length})',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.indigo,
                      ),
                    ),
                    onPressed: () {
                      setState(() {
                        if (allSelected) {
                          _selectedFeeIds.clear();
                        } else {
                          _selectedFeeIds.addAll(pendingDues.map((f) => f.id));
                        }
                      });
                    },
                  );
                },
                orElse: () => const SizedBox.shrink(),
              ),
            ],
          ),
        ),

        // Fees List
        Expanded(
          child: feesAsync.when(
            data: (fees) {
              if (fees.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inbox, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 8),
                      Text(
                        AppTranslations.text('no_fees_found', lang),
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigo,
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.payment),
                            label: const Text('Pay Student Fee'),
                            onPressed:
                                () =>
                                    _showPayStudentFeeDialog(context, student),
                          ),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.add),
                            label: Text(
                              AppTranslations.text('assign_fee', lang),
                            ),
                            onPressed:
                                () => _showAssignFeeDialog(context, student),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: fees.length,
                itemBuilder: (context, index) {
                  final feeItem = fees[index];
                  return _buildStudentFeeCard(context, feeItem, lang);
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ),

        // Persistent Multi-Selection Payment Bar
        if (_selectedFeeIds.isNotEmpty)
          feesAsync.maybeWhen(
            data: (fees) {
              final selectedList =
                  fees.where((f) => _selectedFeeIds.contains(f.id)).toList();
              if (selectedList.isEmpty) return const SizedBox.shrink();
              final totalSelected = selectedList.fold<double>(
                0.0,
                (sum, f) => sum + f.remainingAmount,
              );
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  border: Border(
                    top: BorderSide(color: Colors.indigo.shade200),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Colors.indigo.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${selectedList.length} fee${selectedList.length > 1 ? 's' : ''} selected',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Colors.indigo.shade900,
                          ),
                        ),
                        Text(
                          'Total Due: ${_formatCurrency(totalSelected)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => setState(() => _selectedFeeIds.clear()),
                      child: const Text('Clear'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                      ),
                      icon: const Icon(Icons.payment, size: 16),
                      label: const Text('Pay Selected Fees'),
                      onPressed:
                          () => _showCollectMultipleFeesDialog(
                            context,
                            selectedList,
                          ),
                    ),
                  ],
                ),
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
      ],
    );
  }

  Widget _buildStudentFeeCard(
    BuildContext context,
    StudentFeeWithDetails feeItem,
    String lang,
  ) {
    final statusColor =
        feeItem.isPaid
            ? Colors.green
            : feeItem.isPartial
            ? Colors.amber.shade800
            : Colors.red.shade700;

    final pctPaid =
        feeItem.netAmount > 0
            ? (feeItem.paidAmount / feeItem.netAmount).clamp(0.0, 1.0)
            : 1.0;

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color:
              feeItem.isPaid
                  ? Colors.grey.shade200
                  : statusColor.withAlpha(100),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (feeItem.remainingAmount > 0.01)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Checkbox(
                      value: _selectedFeeIds.contains(feeItem.id),
                      activeColor: Colors.indigo,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _selectedFeeIds.add(feeItem.id);
                          } else {
                            _selectedFeeIds.remove(feeItem.id);
                          }
                        });
                      },
                    ),
                  ),
                // Frequency Badge Icon
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    feeItem.frequency == 'one_time'
                        ? Icons.check_circle_outline
                        : feeItem.frequency == 'term_wise'
                        ? Icons.assignment
                        : Icons.calendar_month,
                    color: Colors.indigo,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),

                // Title & Category
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        feeItem.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              feeItem.categoryName,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              feeItem.frequency
                                  .replaceAll('_', ' ')
                                  .toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade800,
                              ),
                            ),
                          ),
                          if (feeItem.academicYear != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.purple.shade50,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.school,
                                    size: 10,
                                    color: Colors.purple.shade800,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    feeItem.academicYear!.name,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.purple.shade800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (feeItem.discountAmount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.purple.shade50,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.stars,
                                    size: 10,
                                    color: Colors.purple.shade800,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    'Scholarship: -${_formatCurrency(feeItem.discountAmount)}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.purple.shade900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (feeItem.dueDate != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Due: ${_formatDate(feeItem.dueDate!)}',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.orange.shade900,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Status Chip
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(30),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    feeItem.status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Financial row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildFeeStatItem(
                  'Assessed',
                  _formatCurrency(feeItem.totalAmount),
                ),
                if (feeItem.discountAmount > 0)
                  _buildFeeStatItem(
                    'Discount',
                    '-${_formatCurrency(feeItem.discountAmount)}',
                    color: Colors.purple.shade700,
                  ),
                _buildFeeStatItem(
                  'Paid',
                  _formatCurrency(feeItem.paidAmount),
                  color: Colors.green.shade700,
                ),
                _buildFeeStatItem(
                  'Remaining',
                  _formatCurrency(feeItem.remainingAmount),
                  color:
                      feeItem.remainingAmount > 0
                          ? Colors.red.shade700
                          : Colors.grey,
                  isBold: true,
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pctPaid,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 10),

            // Bottom Actions (Pay Fee button or Paid indicator)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (feeItem.payments.isNotEmpty)
                  TextButton.icon(
                    icon: const Icon(Icons.receipt, size: 16),
                    label: Text('${feeItem.payments.length} Payments'),
                    onPressed: () => _showFeePaymentBreakdown(context, feeItem),
                  ),
                const SizedBox(width: 8),
                if (feeItem.remainingAmount > 0.01)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.payment, size: 16),
                    label: Text(
                      feeItem.isPartial ? 'Pay Balance' : 'Collect Fee',
                    ),
                    onPressed: () => _showCollectFeeDialog(context, feeItem),
                  )
                else
                  OutlinedButton.icon(
                    icon: const Icon(Icons.print, size: 16),
                    label: const Text('Receipt'),
                    onPressed: () {
                      if (feeItem.payments.isNotEmpty) {
                        _showPrintReceiptDialog(
                          context,
                          feeItem.payments.first,
                          feeItem,
                        );
                      }
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeeStatItem(
    String label,
    String value, {
    Color? color,
    bool isBold = false,
  }) {
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
            fontSize: 12,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            color: color ?? Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildStudentPaymentHistoryTab(
    BuildContext context,
    Student student,
    String lang,
  ) {
    final paymentsAsync = ref.watch(feePaymentsStreamProvider);

    return paymentsAsync.when(
      data: (payments) {
        if (payments.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.receipt_long, size: 48, color: Colors.grey.shade400),
                const SizedBox(height: 8),
                Text(
                  AppTranslations.text('no_payments_found', lang),
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: payments.length,
          itemBuilder: (context, index) {
            final p = payments[index];
            return _buildPaymentCard(context, p, lang);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildPaymentCard(
    BuildContext context,
    FeePaymentWithDetails p,
    String lang,
  ) {
    return Card(
      elevation: 0.8,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: Colors.green.shade50,
          child: Icon(Icons.check, color: Colors.green.shade700),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                p.feeTitle,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                p.receiptNumber,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo.shade800,
                ),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Paid: ${_formatCurrency(p.amount)} • Method: ${p.paymentMethod}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Date: ${_formatDate(p.paymentDate)}${p.referenceNumber != null ? ' • Ref: ${p.referenceNumber}' : ''}${p.academicYear != null ? ' • Session: ${p.academicYear!.name}' : ''}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: AppTranslations.text('view_receipt', lang),
              icon: const Icon(Icons.print, color: Colors.indigo),
              onPressed: () => _showPaymentReceiptModal(context, p),
            ),
            IconButton(
              tooltip: 'Delete Payment',
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _confirmDeletePayment(context, p.id, lang),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== SCHOOL-WIDE OVERVIEW ====================

  Widget _buildSchoolWideView(BuildContext context, String lang) {
    return Column(
      children: [
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _schoolTabController,
            labelColor: Colors.indigo,
            unselectedLabelColor: Colors.grey.shade600,
            indicatorColor: Colors.indigo,
            indicatorWeight: 3,
            tabs: const [
              Tab(
                icon: Icon(Icons.payments, size: 18),
                text: 'Recent Payments',
              ),
              Tab(
                icon: Icon(Icons.pending_actions, size: 18),
                text: 'All Pending Dues',
              ),
              Tab(icon: Icon(Icons.category, size: 18), text: 'Fee Categories'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _schoolTabController,
            children: [
              _buildAllRecentPaymentsTab(context, lang),
              _buildAllPendingDuesTab(context, lang),
              _buildFeeCategoriesTab(context, lang),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAllRecentPaymentsTab(BuildContext context, String lang) {
    final paymentsAsync = ref.watch(feePaymentsStreamProvider);

    return paymentsAsync.when(
      data: (payments) {
        if (payments.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.receipt_long, size: 48, color: Colors.grey.shade400),
                const SizedBox(height: 8),
                Text(
                  AppTranslations.text('no_payments_found', lang),
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: payments.length,
          itemBuilder: (context, index) {
            final p = payments[index];
            return Card(
              elevation: 0.8,
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.indigo.shade50,
                  child: Text(
                    p.studentName.isNotEmpty
                        ? p.studentName[0].toUpperCase()
                        : 'S',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        p.studentName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Text(
                      _formatCurrency(p.amount),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${p.feeTitle} • ${p.receiptNumber}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.indigo.shade900,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_formatDate(p.paymentDate)} via ${p.paymentMethod}${p.academicYear != null ? ' • Session: ${p.academicYear!.name}' : ''} • Cashier: ${p.receivedBy ?? 'Staff'}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                trailing: IconButton(
                  tooltip: AppTranslations.text('view_receipt', lang),
                  icon: const Icon(Icons.print, color: Colors.indigo),
                  onPressed: () => _showPaymentReceiptModal(context, p),
                ),
                onTap: () {
                  // Select this student
                  ref
                      .read(selectedStudentForFeeProvider.notifier)
                      .selectStudent(p.student);
                },
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildAllPendingDuesTab(BuildContext context, String lang) {
    final feesAsync = ref.watch(studentFeesStreamProvider);

    final nepaliMonths = const [
      (1, 'Baishakh (M1)'),
      (2, 'Jestha (M2)'),
      (3, 'Ashadh (M3)'),
      (4, 'Shrawan (M4)'),
      (5, 'Bhadra (M5)'),
      (6, 'Ashwin (M6)'),
      (7, 'Kartik (M7)'),
      (8, 'Mangsir (M8)'),
      (9, 'Poush (M9)'),
      (10, 'Magh (M10)'),
      (11, 'Falgun (M11)'),
      (12, 'Chaitra (M12)'),
    ];

    return Column(
      children: [
        // Month Filter Toolbar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.grey.shade100,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const Icon(Icons.filter_alt, size: 16, color: Colors.indigo),
                const SizedBox(width: 8),
                const Text(
                  'Month Filter:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('All Months'),
                  selected: _selectedDueMonth == null,
                  selectedColor: Colors.indigo.shade100,
                  labelStyle: TextStyle(
                    fontSize: 11,
                    color:
                        _selectedDueMonth == null
                            ? Colors.indigo.shade900
                            : Colors.black87,
                    fontWeight:
                        _selectedDueMonth == null
                            ? FontWeight.bold
                            : FontWeight.normal,
                  ),
                  onSelected: (_) => setState(() => _selectedDueMonth = null),
                ),
                const SizedBox(width: 6),
                ...nepaliMonths.map((m) {
                  final isSelected = _selectedDueMonth == m.$1;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(m.$2),
                      selected: isSelected,
                      selectedColor: Colors.indigo.shade100,
                      labelStyle: TextStyle(
                        fontSize: 11,
                        color:
                            isSelected
                                ? Colors.indigo.shade900
                                : Colors.black87,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      onSelected:
                          (_) => setState(
                            () => _selectedDueMonth = isSelected ? null : m.$1,
                          ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
        if (_selectedDueMonth != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: Colors.amber.shade50,
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 14,
                  color: Colors.amber.shade900,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Filtering dues for ${nepaliMonths.firstWhere((m) => m.$1 == _selectedDueMonth).$2}. Students with covered school fees for this month (e.g. quarterly/half-yearly) are excluded.',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.amber.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: feesAsync.when(
            data: (fees) {
              var pendingOnly =
                  fees.where((f) => f.remainingAmount > 0.01).toList();

              if (_selectedDueMonth != null) {
                final targetMonth = _selectedDueMonth!;
                // Build set of students whose school fee is covered for targetMonth
                final Set<int> coveredStudentIds = {};
                for (final f in fees) {
                  if (!f.isPaid) continue;
                  final isSchoolFee =
                      f.categoryName.toLowerCase().contains('tuition') ||
                      f.categoryName.toLowerCase().contains('school fee') ||
                      f.title.toLowerCase().contains('tuition') ||
                      f.title.toLowerCase().contains('school fee');
                  if (!isSchoolFee) continue;

                  final term = (f.fee.academicTerm ?? '').toLowerCase();
                  final title = f.title.toLowerCase();
                  final freq = f.frequency.toLowerCase();

                  if (f.fee.academicMonth == targetMonth) {
                    coveredStudentIds.add(f.studentId);
                  } else if (freq == 'quarterly' ||
                      term.contains('q') ||
                      title.contains('quarter')) {
                    final qIndex = ((targetMonth - 1) ~/ 3) + 1;
                    if (term.contains('q$qIndex') ||
                        title.contains('q$qIndex') ||
                        title.contains('quarter $qIndex')) {
                      coveredStudentIds.add(f.studentId);
                    }
                  } else if (freq == 'half_yearly' ||
                      term.contains('h') ||
                      title.contains('half')) {
                    final hIndex = targetMonth <= 6 ? 1 : 2;
                    if (term.contains('h$hIndex') ||
                        title.contains('h$hIndex')) {
                      coveredStudentIds.add(f.studentId);
                    }
                  } else if (freq == 'yearly' ||
                      term.contains('year') ||
                      title.contains('annual')) {
                    coveredStudentIds.add(f.studentId);
                  }
                }

                // Exclude students who already covered this month's school fee,
                // or fees specifically designated for a different month.
                pendingOnly =
                    pendingOnly.where((f) {
                      final isSchoolFee =
                          f.categoryName.toLowerCase().contains('tuition') ||
                          f.categoryName.toLowerCase().contains('school fee') ||
                          f.title.toLowerCase().contains('tuition') ||
                          f.title.toLowerCase().contains('school fee');
                      if (isSchoolFee) {
                        if (coveredStudentIds.contains(f.studentId)) {
                          return false;
                        }
                        if (f.fee.academicMonth != null &&
                            f.fee.academicMonth != targetMonth) {
                          return false;
                        }
                      }
                      return true;
                    }).toList();
              }

              if (pendingOnly.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 48,
                        color: Colors.green.shade400,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _selectedDueMonth != null
                            ? 'No outstanding dues for ${nepaliMonths.firstWhere((m) => m.$1 == _selectedDueMonth).$2}!'
                            : 'No outstanding dues! All fees are collected.',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: pendingOnly.length,
                itemBuilder: (context, index) {
                  final f = pendingOnly[index];
                  return Card(
                    elevation: 0.8,
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.orange.shade200),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.orange.shade50,
                        child: Icon(
                          Icons.pending,
                          color: Colors.orange.shade800,
                          size: 20,
                        ),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              f.studentName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Text(
                            _formatCurrency(f.remainingAmount),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.red.shade700,
                            ),
                          ),
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${f.title} (${f.frequency.replaceAll('_', ' ')})',
                              style: const TextStyle(fontSize: 12),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Total: ${_formatCurrency(f.totalAmount)} • Paid: ${_formatCurrency(f.paidAmount)}${f.academicYear != null ? ' • Session: ${f.academicYear!.name}' : ''}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                        ),
                        child: const Text('Collect'),
                        onPressed: () {
                          // Select student & open payment dialog
                          ref
                              .read(selectedStudentForFeeProvider.notifier)
                              .selectStudent(f.student);
                          _showCollectFeeDialog(context, f);
                        },
                      ),
                      onTap: () {
                        ref
                            .read(selectedStudentForFeeProvider.notifier)
                            .selectStudent(f.student);
                      },
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ),
      ],
    );
  }

  Widget _buildFeeCategoriesTab(BuildContext context, String lang) {
    final categoriesAsync = ref.watch(feeCategoriesStreamProvider);

    return categoriesAsync.when(
      data: (categories) {
        return Scaffold(
          floatingActionButton: FloatingActionButton.extended(
            icon: const Icon(Icons.add),
            label: const Text('New Category'),
            backgroundColor: Colors.indigo,
            foregroundColor: Colors.white,
            onPressed: () => _showAddFeeCategoryDialog(context),
          ),
          body: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final cat = categories[index];
              return Card(
                elevation: 0.6,
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.label, color: Colors.indigo),
                  ),
                  title: Text(
                    cat.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    'Frequency: ${cat.frequency.replaceAll('_', ' ')} • Default: ${_formatCurrency(cat.defaultAmount)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  trailing:
                      cat.isSystem
                          ? Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'System',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade800,
                              ),
                            ),
                          )
                          : null,
                ),
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  // ==================== INTERACTIVE DIALOGS ====================

  /// Dialog to Collect Fee with partial or full payment support
  void _showCollectFeeDialog(
    BuildContext context,
    StudentFeeWithDetails feeItem,
  ) {
    double activeDiscount = feeItem.discountAmount;
    final discountAmountController = TextEditingController(
      text: activeDiscount > 0 ? activeDiscount.toStringAsFixed(2) : '',
    );
    final discountPercentController = TextEditingController(
      text:
          (feeItem.totalAmount > 0 && activeDiscount > 0)
              ? ((activeDiscount / feeItem.totalAmount) * 100).toStringAsFixed(
                1,
              )
              : '',
    );
    bool isPercentDiscount = false;
    String selectedScholarshipCategory = 'None';
    final scholarshipReasonController = TextEditingController();

    double calculateCurrentDiscount() {
      if (isPercentDiscount) {
        final pct =
            double.tryParse(discountPercentController.text.trim()) ?? 0.0;
        return ((feeItem.totalAmount * pct) / 100).clamp(
          0.0,
          feeItem.totalAmount,
        );
      } else {
        final amt =
            double.tryParse(discountAmountController.text.trim()) ?? 0.0;
        return amt.clamp(0.0, feeItem.totalAmount);
      }
    }

    double calcDiscount = activeDiscount;
    double netAmount = (feeItem.totalAmount - calcDiscount).clamp(
      0.0,
      double.infinity,
    );
    double remainingDue = (netAmount - feeItem.paidAmount).clamp(
      0.0,
      double.infinity,
    );

    final amountController = TextEditingController(
      text: remainingDue.toStringAsFixed(2),
    );
    final refController = TextEditingController();
    final remarksController = TextEditingController();
    String selectedMethod = 'Cash';
    DateTime paymentDate = DateTime.now();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            calcDiscount = calculateCurrentDiscount();
            netAmount = (feeItem.totalAmount - calcDiscount).clamp(
              0.0,
              double.infinity,
            );
            remainingDue = (netAmount - feeItem.paidAmount).clamp(
              0.0,
              double.infinity,
            );

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  const Icon(Icons.payments, color: Colors.indigo),
                  const SizedBox(width: 8),
                  const Text('Collect Fee Payment'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Fee summary banner
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            feeItem.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Student: ${feeItem.studentName} (${feeItem.admissionNumber})',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const Divider(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Total Fee: ${_formatCurrency(feeItem.totalAmount)}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              Text(
                                'Paid: ${_formatCurrency(feeItem.paidAmount)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green.shade700,
                                ),
                              ),
                            ],
                          ),
                          if (calcDiscount > 0) ...[
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Scholarship/Disc: -${_formatCurrency(calcDiscount)} (${((calcDiscount / feeItem.totalAmount) * 100).toStringAsFixed(1)}%)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.purple.shade700,
                                  ),
                                ),
                                Text(
                                  'Net: ${_formatCurrency(netAmount)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 4),
                          Text(
                            'Remaining Due: ${_formatCurrency(remainingDue)}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color:
                                  remainingDue > 0
                                      ? Colors.red.shade700
                                      : Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Discount / Scholarship Section
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade50.withAlpha(80),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.purple.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.stars,
                                    size: 18,
                                    color: Colors.purple.shade700,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Discount / Scholarship',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: Colors.purple.shade900,
                                    ),
                                  ),
                                ],
                              ),
                              // Mode Switcher (Rs. / %)
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: Colors.purple.shade300,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    InkWell(
                                      onTap: () {
                                        setDialogState(() {
                                          isPercentDiscount = false;
                                          discountAmountController.text =
                                              calcDiscount.toStringAsFixed(2);
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              !isPercentDiscount
                                                  ? Colors.purple.shade700
                                                  : Colors.transparent,
                                          borderRadius:
                                              const BorderRadius.horizontal(
                                                left: Radius.circular(5),
                                              ),
                                        ),
                                        child: Text(
                                          'Rs.',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color:
                                                !isPercentDiscount
                                                    ? Colors.white
                                                    : Colors.purple.shade700,
                                          ),
                                        ),
                                      ),
                                    ),
                                    InkWell(
                                      onTap: () {
                                        setDialogState(() {
                                          isPercentDiscount = true;
                                          final pct =
                                              feeItem.totalAmount > 0
                                                  ? ((calcDiscount /
                                                          feeItem.totalAmount) *
                                                      100)
                                                  : 0.0;
                                          discountPercentController.text = pct
                                              .toStringAsFixed(1);
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              isPercentDiscount
                                                  ? Colors.purple.shade700
                                                  : Colors.transparent,
                                          borderRadius:
                                              const BorderRadius.horizontal(
                                                right: Radius.circular(5),
                                              ),
                                        ),
                                        child: Text(
                                          '%',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color:
                                                isPercentDiscount
                                                    ? Colors.white
                                                    : Colors.purple.shade700,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Quick Scholarship % chips
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                ActionChip(
                                  visualDensity: VisualDensity.compact,
                                  label: const Text(
                                    'None (0%)',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                  onPressed: () {
                                    setDialogState(() {
                                      discountAmountController.text = '0.00';
                                      discountPercentController.text = '0';
                                      selectedScholarshipCategory = 'None';
                                      final newRem = (feeItem.totalAmount -
                                              feeItem.paidAmount)
                                          .clamp(0.0, double.infinity);
                                      amountController.text = newRem
                                          .toStringAsFixed(2);
                                    });
                                  },
                                ),
                                const SizedBox(width: 6),
                                ActionChip(
                                  visualDensity: VisualDensity.compact,
                                  label: const Text(
                                    '10%',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                  onPressed: () {
                                    setDialogState(() {
                                      final amt = feeItem.totalAmount * 0.10;
                                      discountAmountController.text = amt
                                          .toStringAsFixed(2);
                                      discountPercentController.text = '10';
                                      if (selectedScholarshipCategory ==
                                          'None') {
                                        selectedScholarshipCategory =
                                            'Academic Merit Scholarship';
                                      }
                                      final newNet = feeItem.totalAmount - amt;
                                      final newRem = (newNet -
                                              feeItem.paidAmount)
                                          .clamp(0.0, double.infinity);
                                      amountController.text = newRem
                                          .toStringAsFixed(2);
                                    });
                                  },
                                ),
                                const SizedBox(width: 6),
                                ActionChip(
                                  visualDensity: VisualDensity.compact,
                                  label: const Text(
                                    '20%',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                  onPressed: () {
                                    setDialogState(() {
                                      final amt = feeItem.totalAmount * 0.20;
                                      discountAmountController.text = amt
                                          .toStringAsFixed(2);
                                      discountPercentController.text = '20';
                                      if (selectedScholarshipCategory ==
                                          'None') {
                                        selectedScholarshipCategory =
                                            'Academic Merit Scholarship';
                                      }
                                      final newNet = feeItem.totalAmount - amt;
                                      final newRem = (newNet -
                                              feeItem.paidAmount)
                                          .clamp(0.0, double.infinity);
                                      amountController.text = newRem
                                          .toStringAsFixed(2);
                                    });
                                  },
                                ),
                                const SizedBox(width: 6),
                                ActionChip(
                                  visualDensity: VisualDensity.compact,
                                  label: const Text(
                                    '25%',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                  onPressed: () {
                                    setDialogState(() {
                                      final amt = feeItem.totalAmount * 0.25;
                                      discountAmountController.text = amt
                                          .toStringAsFixed(2);
                                      discountPercentController.text = '25';
                                      if (selectedScholarshipCategory ==
                                          'None') {
                                        selectedScholarshipCategory =
                                            'Sibling Concession';
                                      }
                                      final newNet = feeItem.totalAmount - amt;
                                      final newRem = (newNet -
                                              feeItem.paidAmount)
                                          .clamp(0.0, double.infinity);
                                      amountController.text = newRem
                                          .toStringAsFixed(2);
                                    });
                                  },
                                ),
                                const SizedBox(width: 6),
                                ActionChip(
                                  visualDensity: VisualDensity.compact,
                                  label: const Text(
                                    '50% Half',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                  onPressed: () {
                                    setDialogState(() {
                                      final amt = feeItem.totalAmount * 0.50;
                                      discountAmountController.text = amt
                                          .toStringAsFixed(2);
                                      discountPercentController.text = '50';
                                      if (selectedScholarshipCategory ==
                                          'None') {
                                        selectedScholarshipCategory =
                                            'Need-Based / Financial Aid';
                                      }
                                      final newNet = feeItem.totalAmount - amt;
                                      final newRem = (newNet -
                                              feeItem.paidAmount)
                                          .clamp(0.0, double.infinity);
                                      amountController.text = newRem
                                          .toStringAsFixed(2);
                                    });
                                  },
                                ),
                                const SizedBox(width: 6),
                                ActionChip(
                                  visualDensity: VisualDensity.compact,
                                  backgroundColor: Colors.purple.shade100,
                                  label: Text(
                                    '100% Full Free',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.purple.shade900,
                                    ),
                                  ),
                                  onPressed: () {
                                    setDialogState(() {
                                      discountAmountController.text = feeItem
                                          .totalAmount
                                          .toStringAsFixed(2);
                                      discountPercentController.text = '100';
                                      if (selectedScholarshipCategory ==
                                          'None') {
                                        selectedScholarshipCategory =
                                            'Academic Merit Scholarship';
                                      }
                                      amountController.text = '0.00';
                                      selectedMethod = 'Scholarship Waiver';
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Discount input field
                          if (isPercentDiscount)
                            TextField(
                              controller: discountPercentController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText:
                                    'Scholarship / Discount Percentage (%)',
                                suffixText: '%',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              onChanged: (val) {
                                setDialogState(() {
                                  final p = double.tryParse(val) ?? 0.0;
                                  final amt = ((feeItem.totalAmount * p) / 100)
                                      .clamp(0.0, feeItem.totalAmount);
                                  discountAmountController.text = amt
                                      .toStringAsFixed(2);
                                  final newNet = feeItem.totalAmount - amt;
                                  final newRem = (newNet - feeItem.paidAmount)
                                      .clamp(0.0, double.infinity);
                                  amountController.text = newRem
                                      .toStringAsFixed(2);
                                  if (newRem <= 0.01) {
                                    selectedMethod = 'Scholarship Waiver';
                                  }
                                });
                              },
                            )
                          else
                            TextField(
                              controller: discountAmountController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText:
                                    'Scholarship / Discount Amount (Rs.)',
                                prefixText: 'Rs. ',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              onChanged: (val) {
                                setDialogState(() {
                                  final amt = double.tryParse(val) ?? 0.0;
                                  final p =
                                      feeItem.totalAmount > 0
                                          ? ((amt / feeItem.totalAmount) * 100)
                                          : 0.0;
                                  discountPercentController.text = p
                                      .toStringAsFixed(1);
                                  final newNet = feeItem.totalAmount - amt;
                                  final newRem = (newNet - feeItem.paidAmount)
                                      .clamp(0.0, double.infinity);
                                  amountController.text = newRem
                                      .toStringAsFixed(2);
                                  if (newRem <= 0.01) {
                                    selectedMethod = 'Scholarship Waiver';
                                  }
                                });
                              },
                            ),
                          const SizedBox(height: 8),

                          // Scholarship / Discount Category Dropdown
                          AppSearchableSelect<String>(
                            value: selectedScholarshipCategory,
                            label: 'Scholarship / Discount Category',
                            items: const [
                              SearchableSelectItem(
                                value: 'None',
                                label: 'None / General Discount',
                              ),
                              SearchableSelectItem(
                                value: 'Academic Merit Scholarship',
                                label: 'Academic Merit Scholarship',
                              ),
                              SearchableSelectItem(
                                value: 'Need-Based / Financial Aid',
                                label: 'Need-Based / Financial Aid',
                              ),
                              SearchableSelectItem(
                                value: 'Sibling Concession',
                                label: 'Sibling Concession',
                              ),
                              SearchableSelectItem(
                                value: 'Staff Child Concession',
                                label: 'Staff Child Concession',
                              ),
                              SearchableSelectItem(
                                value: 'Sports / Talent Scholarship',
                                label: 'Sports / Talent Scholarship',
                              ),
                              SearchableSelectItem(
                                value: 'Early Payment Concession',
                                label: 'Early Payment Concession',
                              ),
                              SearchableSelectItem(
                                value: 'Management Special Scholarship',
                                label: 'Management Special Scholarship',
                              ),
                              SearchableSelectItem(
                                value: 'Other',
                                label: 'Other (Specify Below)',
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setDialogState(
                                  () => selectedScholarshipCategory = val,
                                );
                              }
                            },
                          ),
                          if (selectedScholarshipCategory == 'Other') ...[
                            const SizedBox(height: 8),
                            TextField(
                              controller: scholarshipReasonController,
                              decoration: const InputDecoration(
                                labelText: 'Custom Scholarship Reason',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Amount field
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText:
                            remainingDue <= 0.01
                                ? 'Payment Amount (Rs. 0 for full scholarship)'
                                : 'Payment Amount (Rs.)',
                        border: const OutlineInputBorder(),
                        prefixText: 'Rs. ',
                        helperText:
                            remainingDue <= 0.01
                                ? 'Full scholarship covers remaining dues'
                                : 'Supports partial payments or full remaining balance',
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Quick percentage chips
                    if (remainingDue > 0.01)
                      Row(
                        children: [
                          ActionChip(
                            label: Text(
                              'Full Remaining (${_formatCurrency(remainingDue)})',
                            ),
                            onPressed: () {
                              setDialogState(() {
                                amountController.text = remainingDue
                                    .toStringAsFixed(2);
                              });
                            },
                          ),
                          const SizedBox(width: 8),
                          ActionChip(
                            label: const Text('Half (50%)'),
                            onPressed: () {
                              setDialogState(() {
                                amountController.text = (remainingDue / 2)
                                    .toStringAsFixed(2);
                              });
                            },
                          ),
                        ],
                      ),
                    const SizedBox(height: 12),

                    // Payment Method Dropdown
                    AppSearchableSelect<String>(
                      value: selectedMethod,
                      label: 'Payment Method',
                      items: const [
                        SearchableSelectItem(value: 'Cash', label: 'Cash'),
                        SearchableSelectItem(
                          value: 'Bank Transfer',
                          label: 'Bank Transfer',
                        ),
                        SearchableSelectItem(value: 'eSewa', label: 'eSewa'),
                        SearchableSelectItem(value: 'Khalti', label: 'Khalti'),
                        SearchableSelectItem(value: 'Cheque', label: 'Cheque'),
                        SearchableSelectItem(
                          value: 'Online',
                          label: 'Online / Card',
                        ),
                        SearchableSelectItem(
                          value: 'Scholarship Waiver',
                          label: 'Scholarship Waiver',
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedMethod = val);
                        }
                      },
                    ),
                    const SizedBox(height: 12),

                    // Reference Number
                    TextField(
                      controller: refController,
                      decoration: const InputDecoration(
                        labelText: 'Reference / Transaction No. (Optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Remarks
                    TextField(
                      controller: remarksController,
                      decoration: const InputDecoration(
                        labelText: 'Remarks / Notes (Optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(
                    remainingDue <= 0.01 &&
                            (double.tryParse(amountController.text.trim()) ??
                                    0.0) <=
                                0.01
                        ? 'Confirm Scholarship Waiver'
                        : 'Confirm Payment',
                  ),
                  onPressed: () async {
                    final enteredAmount =
                        double.tryParse(amountController.text.trim()) ?? 0.0;
                    final effectiveDiscount = calcDiscount;

                    if (effectiveDiscount > feeItem.totalAmount + 0.001) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Discount/scholarship cannot exceed total fee.',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    if (feeItem.paidAmount >
                        (feeItem.totalAmount - effectiveDiscount) + 0.01) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Discount reduces net fee below already paid amount of ${_formatCurrency(feeItem.paidAmount)}.',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    if (remainingDue <= 0.01) {
                      if (enteredAmount < 0 || enteredAmount > 0.01) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Full scholarship applied. Payment amount must be 0.',
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }
                    } else {
                      if (enteredAmount <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter a valid amount > 0.'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      if (enteredAmount > remainingDue + 0.01) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Amount cannot exceed remaining balance of ${_formatCurrency(remainingDue)}',
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }
                    }

                    Navigator.pop(dialogContext);

                    try {
                      String? discountReason;
                      if (selectedScholarshipCategory != 'None') {
                        final customR = scholarshipReasonController.text.trim();
                        discountReason =
                            selectedScholarshipCategory == 'Other'
                                ? (customR.isNotEmpty
                                    ? customR
                                    : 'Other Scholarship')
                                : (customR.isNotEmpty
                                    ? '$selectedScholarshipCategory ($customR)'
                                    : selectedScholarshipCategory);
                      }

                      final payment = await ref
                          .read(feeControllerProvider.notifier)
                          .recordPayment(
                            studentFeeId: feeItem.id,
                            amount: enteredAmount,
                            paymentMethod: selectedMethod,
                            referenceNumber:
                                refController.text.trim().isEmpty
                                    ? null
                                    : refController.text.trim(),
                            remarks:
                                remarksController.text.trim().isEmpty
                                    ? null
                                    : remarksController.text.trim(),
                            paymentDate: paymentDate,
                            academicYearId:
                                feeItem.academicYear?.id ??
                                ref.read(feeAcademicYearFilterProvider),
                            discountAmount: effectiveDiscount,
                            discountReason: discountReason,
                          );

                      if (context.mounted && payment != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              enteredAmount == 0
                                  ? 'Scholarship waiver applied successfully! (${payment.receiptNumber})'
                                  : 'Payment of ${_formatCurrency(enteredAmount)} recorded successfully! (${payment.receiptNumber})',
                            ),
                            backgroundColor: Colors.green,
                            action: SnackBarAction(
                              label: 'View Receipt',
                              textColor: Colors.white,
                              onPressed: () {
                                _showPrintReceiptDialog(
                                  context,
                                  payment,
                                  feeItem,
                                );
                              },
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to record payment: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Breakdown modal for payments on a specific fee
  void _showFeePaymentBreakdown(
    BuildContext context,
    StudentFeeWithDetails feeItem,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    feeItem.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    '${feeItem.payments.length} Payments',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ],
              ),
              const Divider(height: 20),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: feeItem.payments.length,
                  itemBuilder: (context, idx) {
                    final pay = feeItem.payments[idx];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.green,
                        child: Icon(Icons.check, size: 16, color: Colors.white),
                      ),
                      title: Text(
                        '${pay.receiptNumber} • ${_formatCurrency(pay.amount)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '${_formatDate(pay.paymentDate)} via ${pay.paymentMethod}',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.print, color: Colors.indigo),
                        onPressed: () {
                          Navigator.pop(bottomSheetContext);
                          _showPrintReceiptDialog(context, pay, feeItem);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Print Receipt Dialog (Styled official invoice receipt)
  Future<void> _showPrintReceiptDialog(
    BuildContext context,
    FeePayment payment,
    StudentFeeWithDetails feeItem,
  ) async {
    final consolidated = await ref
        .read(feeServiceProvider)
        .getConsolidatedReceiptByNumber(payment.receiptNumber);
    if (!context.mounted) return;
    if (consolidated != null && consolidated.items.length > 1) {
      _showConsolidatedReceiptDialog(context, consolidated);
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // School Letterhead Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.indigo.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.school,
                          size: 32,
                          color: Colors.indigo,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'SCHOOL MANAGEMENT SYSTEM',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              'Fee Collection & Accounts Department',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    color: Colors.indigo.shade50,
                    child: const Center(
                      child: Text(
                        'OFFICIAL FEE RECEIPT',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          fontSize: 12,
                          color: Colors.indigo,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Receipt meta row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Receipt No: ${payment.receiptNumber}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        'Date: ${_formatDate(payment.paymentDate)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Student Details
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Student: ',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              feeItem.studentName,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              'Adm No: ${feeItem.admissionNumber}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              'Roll No: ${feeItem.rollNumber ?? 'N/A'}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            const Spacer(),
                            if (feeItem.academicYear != null)
                              Text(
                                'Session: ${feeItem.academicYear!.name}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Financial Breakdown Table
                  Table(
                    border: TableBorder.all(color: Colors.grey.shade300),
                    children: [
                      TableRow(
                        decoration: BoxDecoration(color: Colors.grey.shade100),
                        children: const [
                          Padding(
                            padding: EdgeInsets.all(8),
                            child: Text(
                              'Fee Description',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.all(8),
                            child: Text(
                              'Amount (Rs.)',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                      TableRow(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text(
                              '${feeItem.title} (${feeItem.frequency})',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text(
                              _formatCurrency(feeItem.totalAmount),
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      if (feeItem.discountAmount > 0)
                        TableRow(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.stars,
                                    size: 12,
                                    color: Colors.purple.shade700,
                                  ),
                                  const SizedBox(width: 4),
                                  const Text(
                                    'Scholarship / Discount',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.purple,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text(
                                '-${_formatCurrency(feeItem.discountAmount)}',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.purple.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      if (feeItem.discountAmount > 0)
                        TableRow(
                          children: [
                            const Padding(
                              padding: EdgeInsets.all(8),
                              child: Text(
                                'Net Payable Fee',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text(
                                _formatCurrency(feeItem.netAmount),
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      TableRow(
                        decoration: BoxDecoration(color: Colors.green.shade50),
                        children: [
                          const Padding(
                            padding: EdgeInsets.all(8),
                            child: Text(
                              'Amount Paid in Receipt',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text(
                              _formatCurrency(payment.amount),
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Totals
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Payment Method: ${payment.paymentMethod}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      Text(
                        'Total Paid: ${_formatCurrency(payment.amount)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Remaining Balance: ${_formatCurrency(feeItem.remainingAmount)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.red.shade700,
                        ),
                      ),
                      Text(
                        'Received By: ${payment.receivedBy ?? 'Cashier'}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  if (payment.remarks != null &&
                      payment.remarks!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Notes: ${payment.remarks}',
                      style: TextStyle(
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),

                  // Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.print, size: 16),
                        label: const Text('Print Receipt'),
                        onPressed: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Receipt ${payment.receiptNumber} sent to printer!',
                              ),
                              backgroundColor: Colors.indigo,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFacilityBadge({
    required IconData icon,
    required String label,
    required MaterialColor color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color.shade700),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color.shade900,
            ),
          ),
        ],
      ),
    );
  }

  /// Interactive modal allowing on-demand fee selection and multi-fee payment
  /// with inputs for discounts and scholarships.
  Future<void> _showPayStudentFeeDialog(
    BuildContext context,
    Student student,
  ) async {
    final feeService = ref.read(feeServiceProvider);
    final categories = await feeService.ensureStandardFeeCategories();
    if (!context.mounted) return;

    final activeYear = ref.read(activeAcademicYearProvider).value;
    final currentYearId =
        ref.read(feeAcademicYearFilterProvider) ?? activeYear?.id ?? 1;

    // Initial rows based on student facilities
    final List<DynamicFeePaymentRow> rows = [];

    // 1. Regular School Fee
    final schoolCat = categories.cast<FeeCategory?>().firstWhere(
      (c) =>
          c!.name.toLowerCase().contains('tuition') ||
          c.name.toLowerCase().contains('school'),
      orElse: () => categories.isNotEmpty ? categories.first : null,
    );
    if (schoolCat != null) {
      rows.add(
        DynamicFeePaymentRow(
          feeCategoryId: schoolCat.id,
          categoryName: schoolCat.name,
          categoryFrequency: schoolCat.frequency,
          initialTitle: schoolCat.name,
          initialAmount:
              schoolCat.defaultAmount > 0 ? schoolCat.defaultAmount : 2500.0,
        ),
      );
    }

    // 2. Transport Fee if student opted
    if (student.hasTransport) {
      final transCat = categories.cast<FeeCategory?>().firstWhere(
        (c) => c!.name.toLowerCase().contains('transport'),
        orElse: () => null,
      );
      if (transCat != null) {
        rows.add(
          DynamicFeePaymentRow(
            feeCategoryId: transCat.id,
            categoryName: transCat.name,
            categoryFrequency: transCat.frequency,
            initialTitle: transCat.name,
            initialAmount:
                transCat.defaultAmount > 0 ? transCat.defaultAmount : 1500.0,
          ),
        );
      }
    }

    // 3. Hostel Fee if student opted
    if (student.hasHostel) {
      final hostelCat = categories.cast<FeeCategory?>().firstWhere(
        (c) => c!.name.toLowerCase().contains('hostel'),
        orElse: () => null,
      );
      if (hostelCat != null) {
        rows.add(
          DynamicFeePaymentRow(
            feeCategoryId: hostelCat.id,
            categoryName: hostelCat.name,
            categoryFrequency: hostelCat.frequency,
            initialTitle: hostelCat.name,
            initialAmount:
                hostelCat.defaultAmount > 0 ? hostelCat.defaultAmount : 4000.0,
          ),
        );
      }
    }

    // 4. Library Fee if student opted
    if (student.hasLibrary) {
      final libCat = categories.cast<FeeCategory?>().firstWhere(
        (c) => c!.name.toLowerCase().contains('library'),
        orElse: () => null,
      );
      if (libCat != null) {
        rows.add(
          DynamicFeePaymentRow(
            feeCategoryId: libCat.id,
            categoryName: libCat.name,
            categoryFrequency: libCat.frequency,
            initialTitle: libCat.name,
            initialAmount:
                libCat.defaultAmount > 0 ? libCat.defaultAmount : 1000.0,
          ),
        );
      }
    }

    String paymentMethod = 'Cash';
    DateTime paymentDate = DateTime.now();
    final refController = TextEditingController();
    final remarksController = TextEditingController();
    bool isSubmitting = false;

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            double totalAssessed = 0.0;
            double totalDiscount = 0.0;
            double totalNet = 0.0;
            double totalPaying = 0.0;

            for (final r in rows) {
              totalAssessed += r.totalAmount;
              totalDiscount += r.discountAmount;
              totalNet += r.netAmount;
              totalPaying += r.paymentAmount;
            }

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 760,
                  maxHeight: 740,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.indigo.shade50,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.payments,
                              color: Colors.indigo,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Pay Student Fee',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '${student.name} • Adm: ${student.admissionNumber}${student.rollNumber != null ? ' • Roll: ${student.rollNumber}' : ''}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.of(dialogContext).pop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Opted Facilities Chips
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          if (student.hasTransport)
                            _buildFacilityBadge(
                              icon: Icons.directions_bus,
                              label: 'Transport Opted',
                              color: Colors.blue,
                            ),
                          if (student.hasHostel)
                            _buildFacilityBadge(
                              icon: Icons.hotel,
                              label: 'Hostel Opted',
                              color: Colors.orange,
                            ),
                          if (student.hasLibrary)
                            _buildFacilityBadge(
                              icon: Icons.local_library,
                              label: 'Library Opted',
                              color: Colors.teal,
                            ),
                          if (!student.hasTransport &&
                              !student.hasHostel &&
                              !student.hasLibrary)
                            Text(
                              'Standard Student (No special facilities opted)',
                              style: TextStyle(
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                                color: Colors.grey.shade600,
                              ),
                            ),
                        ],
                      ),
                      const Divider(height: 20),

                      // Selection Bar & Add Fee Dropdown
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Fee Heads to Pay (${rows.length})',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          PopupMenuButton<FeeCategory>(
                            tooltip: 'Add Fee Type from generic list',
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.indigo.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.indigo.shade200,
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.add,
                                    size: 16,
                                    color: Colors.indigo,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Add Fee Type',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.indigo,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            itemBuilder: (context) {
                              return categories.map((cat) {
                                return PopupMenuItem<FeeCategory>(
                                  value: cat,
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(cat.name),
                                      const SizedBox(width: 12),
                                      Text(
                                        _formatCurrency(cat.defaultAmount),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList();
                            },
                            onSelected: (cat) {
                              setDialogState(() {
                                rows.add(
                                  DynamicFeePaymentRow(
                                    feeCategoryId: cat.id,
                                    categoryName: cat.name,
                                    categoryFrequency: cat.frequency,
                                    initialTitle: cat.name,
                                    initialAmount:
                                        cat.defaultAmount > 0
                                            ? cat.defaultAmount
                                            : 1000.0,
                                  ),
                                );
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Fee rows list
                      Expanded(
                        child:
                            rows.isEmpty
                                ? Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.playlist_add,
                                        size: 40,
                                        color: Colors.grey.shade400,
                                      ),
                                      const SizedBox(height: 8),
                                      const Text(
                                        'No fee heads selected.',
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                )
                                : ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: rows.length,
                                  itemBuilder: (context, idx) {
                                    final r = rows[idx];
                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        side: BorderSide(
                                          color: Colors.grey.shade300,
                                        ),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            // Top row: category badge, frequency & delete
                                            Row(
                                              children: [
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        Colors.indigo.shade50,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          4,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    r.categoryName,
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color:
                                                          Colors
                                                              .indigo
                                                              .shade900,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey.shade100,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          4,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    r.categoryFrequency,
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color:
                                                          Colors.grey.shade700,
                                                    ),
                                                  ),
                                                ),
                                                const Spacer(),
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.delete_outline,
                                                    size: 18,
                                                    color: Colors.red,
                                                  ),
                                                  onPressed: () {
                                                    setDialogState(() {
                                                      rows.removeAt(idx);
                                                    });
                                                  },
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),

                                            // Fee Title
                                            TextFormField(
                                              controller: r.titleController,
                                              decoration: const InputDecoration(
                                                labelText: 'Fee Title',
                                                isDense: true,
                                                border: OutlineInputBorder(),
                                              ),
                                            ),
                                            const SizedBox(height: 8),

                                            // Numbers: Amount, Discount/Scholarship, Paying Now
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: TextFormField(
                                                    controller:
                                                        r.amountController,
                                                    keyboardType:
                                                        TextInputType.number,
                                                    decoration:
                                                        const InputDecoration(
                                                          labelText:
                                                              'Fee Amount',
                                                          isDense: true,
                                                          border:
                                                              OutlineInputBorder(),
                                                        ),
                                                    onChanged: (val) {
                                                      final amt =
                                                          double.tryParse(
                                                            val.trim(),
                                                          ) ??
                                                          0;
                                                      final disc =
                                                          double.tryParse(
                                                            r
                                                                .discountController
                                                                .text
                                                                .trim(),
                                                          ) ??
                                                          0;
                                                      r
                                                          .payAmountController
                                                          .text = (amt - disc)
                                                          .clamp(
                                                            0.0,
                                                            double.infinity,
                                                          )
                                                          .toStringAsFixed(0);
                                                      setDialogState(() {});
                                                    },
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: TextFormField(
                                                    controller:
                                                        r.discountController,
                                                    keyboardType:
                                                        TextInputType.number,
                                                    decoration: InputDecoration(
                                                      labelText:
                                                          'Scholarship / Disc.',
                                                      prefixIcon: Icon(
                                                        Icons.stars,
                                                        size: 16,
                                                        color:
                                                            Colors
                                                                .purple
                                                                .shade700,
                                                      ),
                                                      isDense: true,
                                                      border:
                                                          const OutlineInputBorder(),
                                                    ),
                                                    onChanged: (val) {
                                                      final amt =
                                                          double.tryParse(
                                                            r
                                                                .amountController
                                                                .text
                                                                .trim(),
                                                          ) ??
                                                          0;
                                                      final disc =
                                                          double.tryParse(
                                                            val.trim(),
                                                          ) ??
                                                          0;
                                                      r
                                                          .payAmountController
                                                          .text = (amt - disc)
                                                          .clamp(
                                                            0.0,
                                                            double.infinity,
                                                          )
                                                          .toStringAsFixed(0);
                                                      setDialogState(() {});
                                                    },
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: TextFormField(
                                                    controller:
                                                        r.discountReasonController,
                                                    decoration: const InputDecoration(
                                                      labelText:
                                                          'Scholarship Reason',
                                                      hintText:
                                                          'e.g. Merit, Sibling',
                                                      isDense: true,
                                                      border:
                                                          OutlineInputBorder(),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: TextFormField(
                                                    controller:
                                                        r.payAmountController,
                                                    keyboardType:
                                                        TextInputType.number,
                                                    decoration: InputDecoration(
                                                      labelText: 'Paying Now',
                                                      isDense: true,
                                                      border:
                                                          const OutlineInputBorder(),
                                                      suffixText:
                                                          'Net: ${_formatCurrency(r.netAmount)}',
                                                    ),
                                                    onChanged:
                                                        (_) => setDialogState(
                                                          () {},
                                                        ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                      ),
                      const SizedBox(height: 8),

                      // Payment Metadata Row
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: AppSearchableSelect<String>(
                                value: paymentMethod,
                                label: 'Method',
                                items: const [
                                  SearchableSelectItem(
                                    value: 'Cash',
                                    label: 'Cash',
                                  ),
                                  SearchableSelectItem(
                                    value: 'Bank Transfer',
                                    label: 'Bank Transfer',
                                  ),
                                  SearchableSelectItem(
                                    value: 'Online',
                                    label: 'Online',
                                  ),
                                  SearchableSelectItem(
                                    value: 'eSewa',
                                    label: 'eSewa',
                                  ),
                                  SearchableSelectItem(
                                    value: 'Khalti',
                                    label: 'Khalti',
                                  ),
                                  SearchableSelectItem(
                                    value: 'Cheque',
                                    label: 'Cheque',
                                  ),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setDialogState(() => paymentMethod = val);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: refController,
                                decoration: const InputDecoration(
                                  labelText: 'Ref / Cheque #',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: remarksController,
                                decoration: const InputDecoration(
                                  labelText: 'Remarks / Notes',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Totals Summary & Actions
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.indigo.shade50.withAlpha(120),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.indigo.shade200),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Assessed: ${_formatCurrency(totalAssessed)} • Scholarship: -${_formatCurrency(totalDiscount)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Net Payable: ${_formatCurrency(totalNet)}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text(
                                      'Total Paying:',
                                      style: TextStyle(fontSize: 11),
                                    ),
                                    Text(
                                      _formatCurrency(totalPaying),
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green.shade800,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 16),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.indigo,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                  ),
                                  icon:
                                      isSubmitting
                                          ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                          : const Icon(Icons.check, size: 18),
                                  label: const Text('Pay & Generate Receipt'),
                                  onPressed:
                                      isSubmitting || rows.isEmpty
                                          ? null
                                          : () async {
                                            setDialogState(
                                              () => isSubmitting = true,
                                            );
                                            try {
                                              final itemsToPay =
                                                  rows.map((r) {
                                                    return CreateAndPayFeeItem(
                                                      existingStudentFeeId:
                                                          r.existingStudentFeeId,
                                                      feeCategoryId:
                                                          r.feeCategoryId,
                                                      title:
                                                          r.titleController.text
                                                              .trim(),
                                                      totalAmount:
                                                          r.totalAmount,
                                                      discountAmount:
                                                          r.discountAmount,
                                                      discountReason:
                                                          r
                                                              .discountReasonController
                                                              .text
                                                              .trim(),
                                                      paymentAmount:
                                                          r.paymentAmount,
                                                      academicMonth:
                                                          r.academicMonth,
                                                      academicTerm:
                                                          r.academicTerm,
                                                    );
                                                  }).toList();

                                              final receipt = await feeService
                                                  .createAndPayStudentFees(
                                                    studentId: student.id,
                                                    academicYearId:
                                                        currentYearId,
                                                    feeItems: itemsToPay,
                                                    paymentMethod:
                                                        paymentMethod,
                                                    referenceNumber:
                                                        refController.text
                                                                .trim()
                                                                .isNotEmpty
                                                            ? refController.text
                                                                .trim()
                                                            : null,
                                                    remarks:
                                                        remarksController.text
                                                                .trim()
                                                                .isNotEmpty
                                                            ? remarksController
                                                                .text
                                                                .trim()
                                                            : null,
                                                    paymentDate: paymentDate,
                                                  );

                                              if (dialogContext.mounted) {
                                                Navigator.of(
                                                  dialogContext,
                                                ).pop();
                                              }

                                              ref.invalidate(
                                                studentFeesStreamProvider,
                                              );
                                              ref.invalidate(
                                                feePaymentsStreamProvider,
                                              );
                                              ref.invalidate(
                                                feeSummaryStatsProvider,
                                              );
                                              ref.invalidate(
                                                selectedStudentFinancialSummaryProvider,
                                              );

                                              if (context.mounted) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      'Payment of ${_formatCurrency(receipt.totalPaid)} recorded! (${receipt.receiptNumber})',
                                                    ),
                                                    backgroundColor:
                                                        Colors.green.shade800,
                                                    action: SnackBarAction(
                                                      label: 'View Receipt',
                                                      textColor: Colors.white,
                                                      onPressed:
                                                          () =>
                                                              _showConsolidatedReceiptDialog(
                                                                context,
                                                                receipt,
                                                              ),
                                                    ),
                                                  ),
                                                );
                                                _showConsolidatedReceiptDialog(
                                                  context,
                                                  receipt,
                                                );
                                              }
                                            } catch (e) {
                                              setDialogState(
                                                () => isSubmitting = false,
                                              );
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      'Payment failed: $e',
                                                    ),
                                                    backgroundColor: Colors.red,
                                                  ),
                                                );
                                              }
                                            }
                                          },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showAssessAdmissionPackageDialog(
    BuildContext context,
    Student student,
  ) {
    final activeYear = ref.read(feeAcademicYearFilterProvider) ?? 1;
    String selectedFrequency = 'monthly';
    final admissionController = TextEditingController(text: '5000');
    final dressController = TextEditingController(text: '1500');
    final bookController = TextEditingController(text: '2000');
    final schoolFeeController = TextEditingController(text: '2500');
    final discountController = TextEditingController(text: '0');
    DateTime? dueDate = DateTime.now().add(const Duration(days: 15));

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final admissionAmt =
                double.tryParse(admissionController.text.trim()) ?? 0;
            final dressAmt = double.tryParse(dressController.text.trim()) ?? 0;
            final bookAmt = double.tryParse(bookController.text.trim()) ?? 0;
            final baseSchoolFee =
                double.tryParse(schoolFeeController.text.trim()) ?? 0;

            double multiplier = 1;
            if (selectedFrequency == 'quarterly') {
              multiplier = 3;
            } else if (selectedFrequency == 'half_yearly') {
              multiplier = 6;
            } else if (selectedFrequency == 'yearly') {
              multiplier = 12;
            }

            final totalSchoolFee = baseSchoolFee * multiplier;
            final totalPackage =
                admissionAmt + dressAmt + bookAmt + totalSchoolFee;

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  const Icon(Icons.school, color: Colors.indigo),
                  const SizedBox(width: 8),
                  const Text('Assess Admission Package'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Assess standard admission fees for ${student.name} with 1 click.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 14),
                    AppSearchableSelect<String>(
                      value: selectedFrequency,
                      label: 'School Fee Billing Frequency',
                      items: const [
                        SearchableSelectItem(
                          value: 'monthly',
                          label: 'Monthly (1 Month)',
                        ),
                        SearchableSelectItem(
                          value: 'quarterly',
                          label: 'Quarterly (3 Months)',
                        ),
                        SearchableSelectItem(
                          value: 'half_yearly',
                          label: 'Half-Yearly (6 Months)',
                        ),
                        SearchableSelectItem(
                          value: 'yearly',
                          label: 'Yearly (12 Months)',
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedFrequency = val);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: admissionController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Admission Fee (One-Time)',
                        prefixText: 'Rs. ',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: dressController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Uniform & Dress Fee (One-Time)',
                        prefixText: 'Rs. ',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: bookController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Book & Stationery Fee (Yearly)',
                        prefixText: 'Rs. ',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: schoolFeeController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText:
                            'Base School Fee / month (Total Rs. ${totalSchoolFee.toStringAsFixed(0)})',
                        prefixText: 'Rs. ',
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: discountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Admission Scholarship / Concession',
                        prefixText: 'Rs. ',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.indigo.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.indigo.shade200),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total Package Amount:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            _formatCurrency(totalPackage),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Colors.indigo,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    Navigator.pop(dialogContext);
                    try {
                      final discountAmt =
                          double.tryParse(discountController.text.trim()) ??
                          0.0;
                      await ref
                          .read(feeControllerProvider.notifier)
                          .assessAdmissionPackage(
                            studentId: student.id,
                            academicYearId: activeYear,
                            schoolFeeFrequency: selectedFrequency,
                            customAdmissionFee: admissionAmt,
                            customDressFee: dressAmt,
                            customBookFee: bookAmt,
                            customSchoolFee: baseSchoolFee,
                            defaultDiscount: discountAmt,
                            dueDate: dueDate,
                          );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Admission Package assessed successfully (4 generic fee heads created)!',
                            ),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to assess package: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Assess Package'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Collect Multiple Fees in a single transaction and receipt
  void _showCollectMultipleFeesDialog(
    BuildContext context,
    List<StudentFeeWithDetails> selectedFees,
  ) {
    if (selectedFees.isEmpty) return;

    final student = selectedFees.first.student;
    final Map<int, TextEditingController> discountControllers = {};
    final Map<int, TextEditingController> amountControllers = {};

    for (final f in selectedFees) {
      discountControllers[f.id] = TextEditingController(
        text: f.discountAmount > 0 ? f.discountAmount.toStringAsFixed(2) : '0',
      );
      amountControllers[f.id] = TextEditingController(
        text: f.remainingAmount.toStringAsFixed(2),
      );
    }

    String selectedMethod = 'Cash';
    final refController = TextEditingController();
    final remarksController = TextEditingController();
    DateTime paymentDate = DateTime.now();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            double totalAssessed = 0.0;
            double totalDiscount = 0.0;
            double totalToPay = 0.0;

            for (final f in selectedFees) {
              totalAssessed += f.totalAmount;
              final disc =
                  double.tryParse(
                    discountControllers[f.id]?.text.trim() ?? '0',
                  ) ??
                  0.0;
              final amt =
                  double.tryParse(
                    amountControllers[f.id]?.text.trim() ?? '0',
                  ) ??
                  0.0;
              totalDiscount += disc;
              totalToPay += amt;
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  const Icon(Icons.receipt_long, color: Colors.indigo),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Pay Selected Fees (${selectedFees.length} Items)',
                      style: const TextStyle(fontSize: 17),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 540,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Student Banner
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Student: ${student.name} (Adm: ${student.admissionNumber})',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              '${selectedFees.length} fee heads',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Fee Items Table / Cards
                      ...selectedFees.map((f) {
                        final discCtrl = discountControllers[f.id]!;
                        final amtCtrl = amountControllers[f.id]!;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(10),
                            color: Colors.white,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      f.title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.indigo.shade50,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      f.frequency
                                          .replaceAll('_', ' ')
                                          .toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.indigo.shade800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Assessed: ${_formatCurrency(f.totalAmount)} | Paid: ${_formatCurrency(f.paidAmount)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  Text(
                                    'Remaining Due: ${_formatCurrency(f.remainingAmount)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red.shade700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: discCtrl,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      decoration: const InputDecoration(
                                        labelText: 'Scholarship/Disc (Rs.)',
                                        prefixText: 'Rs. ',
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 8,
                                        ),
                                      ),
                                      onChanged: (val) {
                                        setDialogState(() {
                                          final disc =
                                              double.tryParse(val) ?? 0;
                                          final net = (f.totalAmount - disc)
                                              .clamp(0.0, double.infinity);
                                          final rem = (net - f.paidAmount)
                                              .clamp(0.0, double.infinity);
                                          amtCtrl.text = rem.toStringAsFixed(2);
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      controller: amtCtrl,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      decoration: const InputDecoration(
                                        labelText: 'Pay Now (Rs.)',
                                        prefixText: 'Rs. ',
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 8,
                                        ),
                                      ),
                                      onChanged: (_) => setDialogState(() {}),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 10),

                      // Grand Totals Summary Card
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.indigo.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.indigo.shade200),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Total Assessed:'),
                                Text(_formatCurrency(totalAssessed)),
                              ],
                            ),
                            if (totalDiscount > 0) ...[
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Total Scholarship / Discount:',
                                    style: TextStyle(
                                      color: Colors.purple.shade700,
                                    ),
                                  ),
                                  Text(
                                    '-${_formatCurrency(totalDiscount)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.purple.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const Divider(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Total To Pay Now:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  _formatCurrency(totalToPay),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.indigo,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Payment Details
                      AppSearchableSelect<String>(
                        value: selectedMethod,
                        label: 'Payment Method',
                        items: const [
                          SearchableSelectItem(value: 'Cash', label: 'Cash'),
                          SearchableSelectItem(
                            value: 'Bank Transfer',
                            label: 'Bank Transfer',
                          ),
                          SearchableSelectItem(value: 'eSewa', label: 'eSewa'),
                          SearchableSelectItem(
                            value: 'Khalti',
                            label: 'Khalti',
                          ),
                          SearchableSelectItem(
                            value: 'Cheque',
                            label: 'Cheque',
                          ),
                          SearchableSelectItem(
                            value: 'Online',
                            label: 'Online / Card',
                          ),
                          SearchableSelectItem(
                            value: 'Scholarship Waiver',
                            label: 'Scholarship Waiver',
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => selectedMethod = val);
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: refController,
                        decoration: const InputDecoration(
                          labelText: 'Reference / Transaction No. (Optional)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: remarksController,
                        decoration: const InputDecoration(
                          labelText: 'Remarks / Notes (Optional)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(
                    'Confirm Combined Payment (${_formatCurrency(totalToPay)})',
                  ),
                  onPressed: () async {
                    final allocations = <FeePaymentAllocation>[];
                    for (final f in selectedFees) {
                      final amt =
                          double.tryParse(
                            amountControllers[f.id]?.text.trim() ?? '0',
                          ) ??
                          0.0;
                      final disc =
                          double.tryParse(
                            discountControllers[f.id]?.text.trim() ?? '0',
                          ) ??
                          0.0;

                      if (disc > f.totalAmount + 0.01) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Discount for ${f.title} cannot exceed total fee.',
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      allocations.add(
                        FeePaymentAllocation(
                          studentFeeId: f.id,
                          amount: amt,
                          discountAmount: disc,
                          discountReason: 'Multi-fee payment concession',
                        ),
                      );
                    }

                    Navigator.pop(dialogContext);

                    try {
                      final receipt = await ref
                          .read(feeControllerProvider.notifier)
                          .recordMultiplePayments(
                            studentId: selectedFees.first.studentId,
                            allocations: allocations,
                            paymentMethod: selectedMethod,
                            referenceNumber:
                                refController.text.trim().isEmpty
                                    ? null
                                    : refController.text.trim(),
                            remarks:
                                remarksController.text.trim().isEmpty
                                    ? null
                                    : remarksController.text.trim(),
                            paymentDate: paymentDate,
                            academicYearId:
                                selectedFees.first.academicYear?.id ??
                                ref.read(feeAcademicYearFilterProvider),
                          );

                      setState(() => _selectedFeeIds.clear());

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Consolidated payment of ${_formatCurrency(receipt.totalPaid)} recorded! (${receipt.receiptNumber})',
                            ),
                            backgroundColor: Colors.green,
                            action: SnackBarAction(
                              label: 'View Receipt',
                              textColor: Colors.white,
                              onPressed: () {
                                _showConsolidatedReceiptDialog(
                                  context,
                                  receipt,
                                );
                              },
                            ),
                          ),
                        );
                        _showConsolidatedReceiptDialog(context, receipt);
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to record payments: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Consolidated Receipt Dialog for simultaneous multiple fee payments
  void _showConsolidatedReceiptDialog(
    BuildContext context,
    ConsolidatedFeeReceipt receipt,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // School Letterhead Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.indigo.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.school,
                          size: 32,
                          color: Colors.indigo,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'SCHOOL MANAGEMENT SYSTEM',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              'Accounts & Fee Collection Department',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    color: Colors.indigo.shade50,
                    child: const Center(
                      child: Text(
                        'CONSOLIDATED OFFICIAL FEE RECEIPT',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          fontSize: 12,
                          color: Colors.indigo,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Receipt meta row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Receipt No: ${receipt.receiptNumber}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        'Date: ${_formatDate(receipt.paymentDate)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Student Details
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Student: ',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              receipt.student.name,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              'Adm No: ${receipt.student.admissionNumber}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              'Roll No: ${receipt.student.rollNumber ?? 'N/A'}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            const Spacer(),
                            if (receipt.academicYear != null)
                              Text(
                                'Session: ${receipt.academicYear!.name}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Items Table
                  Table(
                    border: TableBorder.all(color: Colors.grey.shade300),
                    columnWidths: const {
                      0: FlexColumnWidth(3),
                      1: FlexColumnWidth(1.5),
                      2: FlexColumnWidth(1.5),
                      3: FlexColumnWidth(1.5),
                    },
                    children: [
                      TableRow(
                        decoration: BoxDecoration(color: Colors.grey.shade100),
                        children: const [
                          Padding(
                            padding: EdgeInsets.all(6),
                            child: Text(
                              'Fee Head',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.all(6),
                            child: Text(
                              'Assessed',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.all(6),
                            child: Text(
                              'Disc.',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.all(6),
                            child: Text(
                              'Paid (Rs.)',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                      ...receipt.items.map(
                        (item) => TableRow(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(6),
                              child: Text(
                                item.title,
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(6),
                              child: Text(
                                _formatCurrency(item.totalAmount),
                                textAlign: TextAlign.right,
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(6),
                              child: Text(
                                item.discountAmount > 0
                                    ? '-${_formatCurrency(item.discountAmount)}'
                                    : '-',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.purple.shade700,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(6),
                              child: Text(
                                _formatCurrency(item.paidInThisReceipt),
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      TableRow(
                        decoration: BoxDecoration(color: Colors.green.shade50),
                        children: [
                          const Padding(
                            padding: EdgeInsets.all(6),
                            child: Text(
                              'Total Paid Now',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(6),
                            child: Text(
                              _formatCurrency(receipt.totalAssessed),
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(6),
                            child: Text(
                              receipt.totalDiscount > 0
                                  ? '-${_formatCurrency(receipt.totalDiscount)}'
                                  : '-',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.purple.shade700,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(6),
                            child: Text(
                              _formatCurrency(receipt.totalPaid),
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Summary row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Method: ${receipt.paymentMethod}${receipt.referenceNumber != null ? ' (Ref: ${receipt.referenceNumber})' : ''}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      Text(
                        'Net Paid: ${_formatCurrency(receipt.totalPaid)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Remaining Balance: ${_formatCurrency(receipt.remainingBalance)}',
                        style: TextStyle(
                          fontSize: 11,
                          color:
                              receipt.remainingBalance > 0.01
                                  ? Colors.red.shade700
                                  : Colors.green.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Received By: ${receipt.receivedBy}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  if (receipt.remarks != null &&
                      receipt.remarks!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Notes: ${receipt.remarks}',
                      style: TextStyle(
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),

                  // Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.print, size: 16),
                        label: const Text('Print Receipt'),
                        onPressed: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Consolidated Receipt ${receipt.receiptNumber} sent to printer!',
                              ),
                              backgroundColor: Colors.indigo,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showPaymentReceiptModal(
    BuildContext context,
    FeePaymentWithDetails p,
  ) async {
    final consolidated = await ref
        .read(feeServiceProvider)
        .getConsolidatedReceiptByNumber(p.receiptNumber);
    if (!context.mounted) return;
    if (consolidated != null && consolidated.items.length > 1) {
      _showConsolidatedReceiptDialog(context, consolidated);
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.indigo.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.school,
                          size: 32,
                          color: Colors.indigo,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Text(
                          'OFFICIAL FEE RECEIPT',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Receipt: ${p.receiptNumber}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text('Date: ${_formatDate(p.paymentDate)}'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('Student: ${p.studentName} (${p.admissionNumber})'),
                  Text('Fee: ${p.feeTitle}'),
                  if (p.academicYear != null)
                    Text('Session: ${p.academicYear!.name}'),
                  Text('Payment Method: ${p.paymentMethod}'),
                  if (p.referenceNumber != null)
                    Text('Reference: ${p.referenceNumber}'),
                  if (p.payment.remarks != null &&
                      p.payment.remarks!.isNotEmpty)
                    Text(
                      'Notes: ${p.payment.remarks}',
                      style: TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Assessed Fee:'),
                      Text(_formatCurrency(p.fee.totalAmount)),
                    ],
                  ),
                  if (p.feeDiscountAmount > 0) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.stars,
                              size: 13,
                              color: Colors.purple.shade700,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Scholarship / Discount:',
                              style: TextStyle(color: Colors.purple.shade700),
                            ),
                          ],
                        ),
                        Text(
                          '-${_formatCurrency(p.feeDiscountAmount)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.purple.shade700,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Amount Paid in Receipt:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        _formatCurrency(p.amount),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.print, size: 16),
                        label: const Text('Print Receipt'),
                        onPressed: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Receipt ${p.receiptNumber} sent to printer!',
                              ),
                              backgroundColor: Colors.indigo,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _confirmDeletePayment(BuildContext context, int paymentId, String lang) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Void / Delete Payment'),
          content: Text(
            AppTranslations.text('confirm_delete_fee_payment', lang),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
              onPressed: () async {
                Navigator.pop(dialogContext);
                try {
                  await ref
                      .read(feeControllerProvider.notifier)
                      .deletePayment(paymentId);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Payment deleted and student balance restored.',
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to delete payment: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  /// Dialog to Assign Fee to a Student
  void _showAssignFeeDialog(BuildContext context, Student? preselectedStudent) {
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    final discountController = TextEditingController(text: '0.0');
    final notesController = TextEditingController();
    int? selectedCatId;
    int? targetStudentId = preselectedStudent?.id;
    int? selectedYearId =
        ref.read(feeAcademicYearFilterProvider) ??
        ref.read(activeAcademicYearProvider).value?.id;
    DateTime dueDate = DateTime.now().add(const Duration(days: 30));

    final categoriesAsync = ref.watch(feeCategoriesStreamProvider);
    final studentsAsync = ref.watch(studentsListStreamProvider);
    final academicYearsAsync = ref.watch(academicYearsStreamProvider);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text('Assign Fee to Student'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Academic Year selector
                    academicYearsAsync.when(
                      data: (years) {
                        if (selectedYearId == null && years.isNotEmpty) {
                          selectedYearId =
                              years
                                  .firstWhere(
                                    (y) => y.isCurrent,
                                    orElse: () => years.first,
                                  )
                                  .id;
                        }
                        return AppSearchableSelect<int?>(
                          value: selectedYearId,
                          label: 'Academic Session / Year',
                          prefixIcon: const Icon(Icons.school, size: 18),
                          items:
                              years.map((y) {
                                return SearchableSelectItem<int?>(
                                  value: y.id,
                                  label:
                                      y.name + (y.isCurrent ? ' (Active)' : ''),
                                );
                              }).toList(),
                          onChanged: (val) {
                            setDialogState(() => selectedYearId = val);
                          },
                        );
                      },
                      loading: () => const LinearProgressIndicator(),
                      error: (e, s) => const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 12),

                    // Student selection if not preselected
                    if (preselectedStudent == null)
                      studentsAsync.when(
                        data: (students) {
                          return AppSearchableSelect<int>(
                            value: targetStudentId,
                            label: 'Select Student',
                            items:
                                students.map((swd) {
                                  return SearchableSelectItem<int>(
                                    value: swd.student.id,
                                    label:
                                        '${swd.student.name} (${swd.student.admissionNumber})',
                                  );
                                }).toList(),
                            onChanged: (val) {
                              setDialogState(() => targetStudentId = val);
                            },
                          );
                        },
                        loading: () => const LinearProgressIndicator(),
                        error: (e, s) => const SizedBox.shrink(),
                      ),
                    if (preselectedStudent == null) const SizedBox(height: 12),

                    // Category dropdown
                    categoriesAsync.when(
                      data: (cats) {
                        return AppSearchableSelect<int>(
                          value: selectedCatId,
                          label: 'Fee Category',
                          items:
                              cats.map((c) {
                                return SearchableSelectItem<int>(
                                  value: c.id,
                                  label: '${c.name} (${c.frequency})',
                                );
                              }).toList(),
                          onChanged: (val) {
                            setDialogState(() {
                              selectedCatId = val;
                              final cat = cats.firstWhere((c) => c.id == val);
                              if (titleController.text.trim().isEmpty) {
                                titleController.text = cat.name;
                              }
                              if (amountController.text.trim().isEmpty ||
                                  amountController.text == '0.0') {
                                amountController.text = cat.defaultAmount
                                    .toStringAsFixed(2);
                              }
                            });
                          },
                        );
                      },
                      loading: () => const LinearProgressIndicator(),
                      error: (e, s) => const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Fee Title',
                        hintText: 'e.g. Baishakh Tuition Fee, Uniform Set',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Total Amount (Rs.)',
                        border: OutlineInputBorder(),
                        prefixText: 'Rs. ',
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: discountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Discount / Scholarship (Rs.)',
                        border: OutlineInputBorder(),
                        prefixText: 'Rs. ',
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: notesController,
                      decoration: const InputDecoration(
                        labelText: 'Notes (Optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Assign Fee'),
                  onPressed: () async {
                    if (targetStudentId == null || selectedCatId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Please select both a student and a fee category.',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    final title = titleController.text.trim();
                    final amount =
                        double.tryParse(amountController.text.trim()) ?? 0.0;
                    final discount =
                        double.tryParse(discountController.text.trim()) ?? 0.0;

                    if (title.isEmpty || amount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Please enter valid title and amount > 0.',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    Navigator.pop(dialogContext);

                    try {
                      await ref
                          .read(feeControllerProvider.notifier)
                          .assignFee(
                            studentId: targetStudentId!,
                            feeCategoryId: selectedCatId!,
                            title: title,
                            totalAmount: amount,
                            discountAmount: discount,
                            dueDate: dueDate,
                            academicYearId: selectedYearId,
                            notes:
                                notesController.text.trim().isEmpty
                                    ? null
                                    : notesController.text.trim(),
                          );

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Fee assigned successfully!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to assign fee: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Dialog to Bulk Assign Fee to an Entire Class (and optional Section)
  void _showBulkAssignFeeDialog(BuildContext context) {
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    final discountController = TextEditingController(text: '0.0');
    final notesController = TextEditingController();
    int? selectedClassId;
    int? selectedSectionId;
    int? selectedCatId;
    int? selectedYearId =
        ref.read(feeAcademicYearFilterProvider) ??
        ref.read(activeAcademicYearProvider).value?.id;
    DateTime dueDate = DateTime.now().add(const Duration(days: 30));

    final classesAsync = ref.watch(classesWithSectionsStreamProvider);
    final categoriesAsync = ref.watch(feeCategoriesStreamProvider);
    final academicYearsAsync = ref.watch(academicYearsStreamProvider);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: const [
                  Icon(Icons.group_add, color: Colors.indigo),
                  SizedBox(width: 8),
                  Text('Bulk Assign Fee to Class'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Academic Year selector
                    academicYearsAsync.when(
                      data: (years) {
                        if (selectedYearId == null && years.isNotEmpty) {
                          selectedYearId =
                              years
                                  .firstWhere(
                                    (y) => y.isCurrent,
                                    orElse: () => years.first,
                                  )
                                  .id;
                        }
                        return AppSearchableSelect<int?>(
                          value: selectedYearId,
                          label: 'Academic Session / Year',
                          prefixIcon: const Icon(Icons.school, size: 18),
                          items:
                              years.map((y) {
                                return SearchableSelectItem<int?>(
                                  value: y.id,
                                  label:
                                      y.name + (y.isCurrent ? ' (Active)' : ''),
                                );
                              }).toList(),
                          onChanged: (val) {
                            setDialogState(() => selectedYearId = val);
                          },
                        );
                      },
                      loading: () => const LinearProgressIndicator(),
                      error: (e, s) => const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 12),

                    // Class Dropdown
                    classesAsync.when(
                      data: (classes) {
                        return Column(
                          children: [
                            AppSearchableSelect<int>(
                              value: selectedClassId,
                              label: 'Select Class',
                              prefixIcon: const Icon(Icons.class_, size: 18),
                              items:
                                  classes.map((c) {
                                    return SearchableSelectItem<int>(
                                      value: c.schoolClass.id,
                                      label: c.schoolClass.displayName,
                                    );
                                  }).toList(),
                              onChanged: (val) {
                                setDialogState(() {
                                  selectedClassId = val;
                                  selectedSectionId = null;
                                });
                              },
                            ),
                            if (selectedClassId != null) ...[
                              const SizedBox(height: 12),
                              Builder(
                                builder: (context) {
                                  final selectedClass = classes.firstWhere(
                                    (c) => c.schoolClass.id == selectedClassId,
                                  );
                                  return AppSearchableSelect<int?>(
                                    value: selectedSectionId,
                                    label: 'Section (Optional - All if empty)',
                                    prefixIcon: const Icon(
                                      Icons.group,
                                      size: 18,
                                    ),
                                    items: [
                                      const SearchableSelectItem<int?>(
                                        value: null,
                                        label: 'All Sections',
                                      ),
                                      ...selectedClass.sections.map((s) {
                                        return SearchableSelectItem<int?>(
                                          value: s.id,
                                          label: 'Section ${s.name}',
                                        );
                                      }),
                                    ],
                                    onChanged: (val) {
                                      setDialogState(
                                        () => selectedSectionId = val,
                                      );
                                    },
                                  );
                                },
                              ),
                            ],
                          ],
                        );
                      },
                      loading: () => const LinearProgressIndicator(),
                      error: (e, s) => const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 12),

                    // Fee Category dropdown
                    categoriesAsync.when(
                      data: (cats) {
                        return AppSearchableSelect<int>(
                          value: selectedCatId,
                          label: 'Fee Category',
                          items:
                              cats.map((c) {
                                return SearchableSelectItem<int>(
                                  value: c.id,
                                  label: '${c.name} (${c.frequency})',
                                );
                              }).toList(),
                          onChanged: (val) {
                            setDialogState(() {
                              selectedCatId = val;
                              final cat = cats.firstWhere((c) => c.id == val);
                              if (titleController.text.trim().isEmpty) {
                                titleController.text = cat.name;
                              }
                              if (amountController.text.trim().isEmpty ||
                                  amountController.text == '0.0') {
                                amountController.text = cat.defaultAmount
                                    .toStringAsFixed(2);
                              }
                            });
                          },
                        );
                      },
                      loading: () => const LinearProgressIndicator(),
                      error: (e, s) => const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Fee Title',
                        hintText:
                            'e.g. Baishakh Tuition Fee, Annual Sports Fee',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Total Amount (Rs.)',
                        border: OutlineInputBorder(),
                        prefixText: 'Rs. ',
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: discountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Default Discount (Rs.)',
                        border: OutlineInputBorder(),
                        prefixText: 'Rs. ',
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: notesController,
                      decoration: const InputDecoration(
                        labelText: 'Notes (Optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Assign to Class'),
                  onPressed: () async {
                    if (selectedClassId == null || selectedCatId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Please select a class and a fee category.',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    final title = titleController.text.trim();
                    final amount =
                        double.tryParse(amountController.text.trim()) ?? 0.0;
                    final discount =
                        double.tryParse(discountController.text.trim()) ?? 0.0;

                    if (title.isEmpty || amount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Please enter valid title and amount > 0.',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    Navigator.pop(dialogContext);

                    try {
                      final count = await ref
                          .read(feeControllerProvider.notifier)
                          .bulkAssignFee(
                            classId: selectedClassId!,
                            sectionId: selectedSectionId,
                            academicYearId: selectedYearId,
                            feeCategoryId: selectedCatId!,
                            title: title,
                            totalAmount: amount,
                            discountAmount: discount,
                            dueDate: dueDate,
                            notes:
                                notesController.text.trim().isEmpty
                                    ? null
                                    : notesController.text.trim(),
                          );

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Fee successfully assigned to $count student(s)!',
                            ),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to assign fee: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Dialog to Add a Fee Category
  void _showAddFeeCategoryDialog(BuildContext context) {
    final nameController = TextEditingController();
    final amountController = TextEditingController(text: '0.0');
    final descController = TextEditingController();
    String frequency = 'monthly';

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text('Add Fee Category'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Category Name',
                        hintText: 'e.g. Library Fee, Computer Lab',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    AppSearchableSelect<String>(
                      value: frequency,
                      label: 'Payment Frequency',
                      items: const [
                        SearchableSelectItem(
                          value: 'one_time',
                          label: 'One-Time (Admission, Dress)',
                        ),
                        SearchableSelectItem(
                          value: 'monthly',
                          label: 'Monthly (Tuition, Bus)',
                        ),
                        SearchableSelectItem(
                          value: 'quarterly',
                          label: 'Quarterly',
                        ),
                        SearchableSelectItem(
                          value: 'half_yearly',
                          label: 'Half-Yearly',
                        ),
                        SearchableSelectItem(value: 'yearly', label: 'Yearly'),
                        SearchableSelectItem(
                          value: 'term_wise',
                          label: 'Term-Wise (Exams)',
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => frequency = val);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Default Amount (Rs.)',
                        border: OutlineInputBorder(),
                        prefixText: 'Rs. ',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descController,
                      decoration: const InputDecoration(
                        labelText: 'Description (Optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Create Category'),
                  onPressed: () async {
                    final name = nameController.text.trim();
                    final defAmount =
                        double.tryParse(amountController.text.trim()) ?? 0.0;
                    if (name.isEmpty) return;

                    Navigator.pop(dialogContext);

                    try {
                      final service = ref.read(feeServiceProvider);
                      await service.createFeeCategory(
                        name: name,
                        frequency: frequency,
                        defaultAmount: defAmount,
                        description:
                            descController.text.trim().isEmpty
                                ? null
                                : descController.text.trim(),
                      );
                      ref.invalidate(feeCategoriesStreamProvider);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Fee category created!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to create category: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class DynamicFeePaymentRow {
  final int? existingStudentFeeId;
  final int feeCategoryId;
  final String categoryName;
  final String categoryFrequency;
  final TextEditingController titleController;
  final TextEditingController amountController;
  final TextEditingController discountController;
  final TextEditingController discountReasonController;
  final TextEditingController payAmountController;
  final int? academicMonth;
  final String? academicTerm;

  DynamicFeePaymentRow({
    this.existingStudentFeeId,
    required this.feeCategoryId,
    required this.categoryName,
    required this.categoryFrequency,
    required String initialTitle,
    required double initialAmount,
    double initialDiscount = 0.0,
    String? initialDiscountReason,
    double? initialPayAmount,
    this.academicMonth,
    this.academicTerm,
  }) : titleController = TextEditingController(text: initialTitle),
       amountController = TextEditingController(
         text: initialAmount.toStringAsFixed(0),
       ),
       discountController = TextEditingController(
         text: initialDiscount > 0 ? initialDiscount.toStringAsFixed(0) : '0',
       ),
       discountReasonController = TextEditingController(
         text: initialDiscountReason ?? '',
       ),
       payAmountController = TextEditingController(
         text: (initialPayAmount ??
                 (initialAmount - initialDiscount).clamp(0.0, double.infinity))
             .toStringAsFixed(0),
       );

  double get totalAmount =>
      double.tryParse(amountController.text.trim()) ?? 0.0;
  double get discountAmount =>
      double.tryParse(discountController.text.trim()) ?? 0.0;
  double get netAmount =>
      (totalAmount - discountAmount).clamp(0.0, double.infinity);
  double get paymentAmount =>
      double.tryParse(payAmountController.text.trim()) ?? netAmount;
}
