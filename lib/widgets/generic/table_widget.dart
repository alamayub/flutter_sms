import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../config/typo_config.dart';
import '../input/text_input.dart';

typedef CellBuilder<T> = String Function(T item);
typedef ActionBuilder<T> = List<Widget> Function(T item, int index);

class TableColumnDefinition<T> {
  final String label;
  final CellBuilder<T> cellBuilder;

  TableColumnDefinition({required this.label, required this.cellBuilder});
}

class TableWidget<T> extends HookConsumerWidget {
  final String title;
  final Function() onAddPressed;
  final List<T> data;
  final List<TableColumnDefinition<T>> columns;
  final ActionBuilder<T> actionBuilder;

  const TableWidget({
    super.key,
    required this.title,
    required this.onAddPressed,
    required this.data,
    required this.columns,
    required this.actionBuilder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rowsPerPage = useState<int>(10);
    final search = useTextEditingController();
    final filteredData = useState<List<T>>(data);

    useEffect(() {
      filteredData.value = data;
      return null;
    }, [data]);

    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: PaginatedDataTable(
              header: TextInput(
                controller: search,
                labelText: 'Search...',
                onChanged: (val) {
                  if (val != null && val.isNotEmpty) {}
                },
              ),
              actions: [
                SizedBox(
                  height: 36,
                  child: TextButton.icon(
                    onPressed: onAddPressed,
                    icon: const Icon(Icons.add_rounded, color: Colors.white),
                    label: Text(
                      title,
                      style: typoConfig.textStyle.smallCaptionSubtitle2
                          .copyWith(color: Colors.white),
                    ),
                  ),
                ),
              ],
              columns: [
                const DataColumn(
                  label: Text('SN'),
                  numeric: true,
                  columnWidth: FixedColumnWidth(40),
                ),
                ...columns.map(
                  (c) => DataColumn(
                    label: Text(c.label),
                    columnWidth: FlexColumnWidth(),
                  ),
                ),
                const DataColumn(
                  label: Text('Actions'),
                  columnWidth: FixedColumnWidth(74),
                ),
              ],
              columnSpacing: 12,
              horizontalMargin: 16,
              headingRowHeight: 30,
              source: _GenericDataSource<T>(
                filteredData.value,
                columns,
                actionBuilder,
              ),
              rowsPerPage: rowsPerPage.value,
              availableRowsPerPage: const [10, 20, 50],
              onRowsPerPageChanged: (value) => rowsPerPage.value = value ?? 10,
            ),
          ),
        );
      },
    );
  }
}

class _GenericDataSource<T> extends DataTableSource {
  final List<T> data;
  final List<TableColumnDefinition<T>> columns;
  final ActionBuilder<T> actionBuilder;

  _GenericDataSource(this.data, this.columns, this.actionBuilder);

  @override
  DataRow getRow(int index) {
    final item = data[index];
    return DataRow(
      cells: [
        DataCell(Text('${index + 1}')),
        ...columns.map((c) => DataCell(Text(c.cellBuilder(item)))),
        DataCell(Row(children: actionBuilder(item, index))),
      ],
    );
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => data.length;

  @override
  int get selectedRowCount => 0;
}
