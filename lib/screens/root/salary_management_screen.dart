import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../config/theme.dart' show ColorConstants;
import '../../models/salary_status.dart';
import '../../providers/salary_provider.dart';
import '../../widgets/generic/table_widget.dart';

class SalaryManagementScreen extends ConsumerWidget {
  const SalaryManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(selectedMonthProvider);
    final salaryData = ref.watch(staffSalariesProvider);

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ListTile(
              dense: true,
              tileColor: ColorConstants.scafoldBG,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                  helpText: 'Pick a month',
                );
                if (picked != null) {
                  ref.read(selectedMonthProvider.notifier).state = picked;
                }
              },
              title: const Text('Selected Month'),
              subtitle: Text(DateFormat.yMMMM().format(selectedDate)),
              trailing: const Icon(Icons.calendar_month, size: 20),
            ),
          ),
          Expanded(
            child: salaryData.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (list) {
                if (list.isEmpty) {
                  return const Center(child: Text('No staff data found.'));
                }

                return TableWidget<SalaryStatus>(
                  isSearchable: false,
                  title: '',
                  data: list,
                  columns: [
                    TableColumnDefinition(
                      label: 'Name',
                      cellBuilder: (s) => s.fullName,
                    ),
                    TableColumnDefinition(
                      label: 'Phone',
                      cellBuilder: (s) => s.phoneNumber,
                    ),
                    TableColumnDefinition(
                      numeric: true,
                      label: 'Salary',
                      cellBuilder: (s) => 'रु${s.salary.toStringAsFixed(2)}',
                    ),
                    TableColumnDefinition(
                      numeric: true,
                      label: 'Date',
                      cellBuilder:
                          (s) =>
                              s.paymentDate != null
                                  ? DateFormat.yMMMd().format(
                                    DateTime.parse(s.paymentDate!),
                                  )
                                  : '--:--',
                    ),
                  ],
                  actionBuilder:
                      (s, i) => [
                        GestureDetector(
                          onTap:
                              () => ref
                                  .read(salaryProvider.notifier)
                                  .updateSalaryStatus(s),
                          child: Tooltip(
                            message: s.isPaid ? 'Paid' : 'Click to Pay',
                            child: Row(
                              children: [
                                Icon(
                                  s.isPaid
                                      ? Icons.check_circle
                                      : Icons.check_circle_outline,
                                  size: 15,
                                  color: s.isPaid ? Colors.green : Colors.red,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  s.isPaid ? 'Paid' : 'Unpaid',
                                  style: TextStyle(
                                    color: s.isPaid ? Colors.green : Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
