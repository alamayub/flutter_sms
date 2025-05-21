import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../config/theme.dart' show ColorConstants;
import '../../config/typo_config.dart';
import '../input/text_input.dart';

typedef CellBuilder<T> = String Function(T item);
typedef ActionBuilder<T> = List<Widget> Function(T item, int index);

class TableColumnDefinition<T> {
  final bool numeric;
  final String label;
  final CellBuilder<T> cellBuilder;

  TableColumnDefinition({
    this.numeric = false,
    required this.label,
    required this.cellBuilder,
  });
}

class TableWidget<T> extends HookConsumerWidget {
  final String title;
  final Function()? onAddPressed;
  final List<T> data;
  final List<TableColumnDefinition<T>> columns;
  final ActionBuilder<T> actionBuilder;
  final bool isSearchable;

  const TableWidget({
    super.key,
    required this.title,
    this.onAddPressed,
    required this.data,
    required this.columns,
    required this.actionBuilder,
    this.isSearchable = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final search = useTextEditingController();
    final filteredData = useState<List<T>>(data);

    useEffect(() {
      filteredData.value = data;
      return null;
    }, [data]);

    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            if (isSearchable && onAddPressed != null) ...[
              Container(
                width: constraints.maxWidth,
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    if (isSearchable)
                      Expanded(
                        child: SizedBox(
                          width: 300,
                          child: TextInput(
                            controller: search,
                            labelText: 'Search...',
                            onChanged: (val) {
                              if (val != null && val.isNotEmpty) {
                              } else {
                                filteredData.value = data;
                              }
                            },
                          ),
                        ),
                      ),
                    const SizedBox(width: 12),
                    if (onAddPressed != null)
                      TextButton.icon(
                        onPressed: onAddPressed,
                        icon: const Icon(
                          Icons.add_rounded,
                          color: Colors.white,
                        ),
                        label: Text(
                          title,
                          style: typoConfig.textStyle.smallCaptionSubtitle2
                              .copyWith(color: Colors.white),
                        ),
                        style: TextButton.styleFrom(
                          backgroundColor: ColorConstants.primary,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Container(
                    constraints: BoxConstraints(
                      minWidth: constraints.maxWidth - 32,
                    ),
                    child: DataTable(
                      columnSpacing: 16,
                      headingRowHeight: 30,
                      dataRowMinHeight: 30,
                      columns: [
                        const DataColumn(label: Text('SN'), numeric: true),
                        ...columns.map(
                          (c) => DataColumn(
                            label: Text(
                              c.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            numeric: c.numeric,
                          ),
                        ),
                        const DataColumn(label: Text('Actions')),
                      ],
                      rows: List<DataRow>.generate(filteredData.value.length, (
                        index,
                      ) {
                        final item = filteredData.value[index];
                        return DataRow(
                          cells: [
                            DataCell(Text('${index + 1}')),
                            ...columns.map(
                              (c) => DataCell(Text(c.cellBuilder(item))),
                            ),
                            DataCell(Row(children: actionBuilder(item, index))),
                          ],
                        );
                      }),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }
}
