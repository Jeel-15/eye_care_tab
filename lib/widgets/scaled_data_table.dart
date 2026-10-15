import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';

/// One column of a [ScaledDataTable] — a fixed natural width plus the
/// header label shown above it.
class ScaledTableColumn {
  final String label;
  final double width;
  final TextAlign headerAlign;

  /// This table should fill the screen. Spare width is shared by every column
  /// except a [hug] column, so the sidebar opening does not leave a hole in
  /// only the first column.
  final bool grow;

  /// Size this column to its widest cell. The horizontal scroll then ends
  /// at that cell, instead of running into unused column width.
  final bool hug;

  const ScaledTableColumn(this.label, this.width, {this.headerAlign = TextAlign.left, this.grow = false, this.hug = false});
}

/// Fixed-width columns that fill the screen when there is room, and scroll
/// sideways only as far as the last cell.
///
/// When a table is marked [ScaledTableColumn.grow], leftover width is shared
/// across the data columns in proportion to their natural width. A
/// [ScaledTableColumn.hug] column stays as wide as its buttons, so the
/// horizontal scroll still ends there. Opening or closing the side rail
/// resizes the whole row together.
class ScaledDataTable extends StatelessWidget {
  final List<ScaledTableColumn> columns;
  final List<List<Widget>> rows;
  final String emptyMessage;
  final double gap;
  final double rowHPad;
  final double rowVPad;

  const ScaledDataTable({
    super.key,
    required this.columns,
    required this.rows,
    required this.emptyMessage,
    this.gap = 10,
    this.rowHPad = 16,
    this.rowVPad = 12,
  });

  TableColumnWidth _columnWidth(ScaledTableColumn column) {
    if (column.hug) return const IntrinsicColumnWidth();
    // Any grow column means the whole table fills the rail. Share the spare
    // width across every data column, not only the first one.
    if (!column.hug && columns.any((c) => c.grow)) {
      return MaxColumnWidth(FixedColumnWidth(column.width), FlexColumnWidth(column.width));
    }
    return FixedColumnWidth(column.width);
  }

  Widget _cell(int index, Widget child) {
    final last = index == columns.length - 1;
    return Padding(
      padding: EdgeInsets.fromLTRB(index == 0 ? rowHPad : gap / 2, rowVPad, last ? rowHPad : gap / 2, rowVPad),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final viewport = constraints.maxWidth;
      final table = SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: viewport.isFinite ? viewport : 0),
          child: Table(
            columnWidths: {for (var i = 0; i < columns.length; i++) i: _columnWidth(columns[i])},
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              TableRow(
                decoration: const BoxDecoration(color: Color(0xFFF4F8FB)),
                children: [
                  for (var i = 0; i < columns.length; i++)
                    _cell(
                      i,
                      Text(
                        columns[i].label,
                        textAlign: columns[i].headerAlign,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.tableHeader,
                      ),
                    ),
                ],
              ),
              for (final cells in rows)
                TableRow(
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.primaryA08))),
                  children: [for (var i = 0; i < columns.length; i++) _cell(i, cells[i])],
                ),
            ],
          ),
        ),
      );
      if (rows.isNotEmpty) return table;
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        table,
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Center(child: Text(emptyMessage, style: AppTextStyles.tableMeta)),
        ),
      ]);
    });
  }
}
