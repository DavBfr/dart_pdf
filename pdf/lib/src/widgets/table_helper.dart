/*
 * Copyright (C) 2017, David PHAM-VAN <dev.nfet.net@gmail.com>
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import 'box_border.dart';
import 'container.dart';
import 'decoration.dart';
import 'geometry.dart';
import 'table.dart';
import 'text.dart';
import 'text_style.dart';
import 'theme.dart';
import 'widget.dart';

typedef OnCell = Widget? Function(int index, dynamic data, int rowNum);
typedef OnCellTextStyle =
    TextStyle? Function(int index, dynamic data, int rowNum);

mixin TableHelper {
  static TextAlign _textAlign(Alignment align) {
    if (align.x == 0) {
      return TextAlign.center;
    } else if (align.x < 0) {
      return TextAlign.left;
    } else {
      return TextAlign.right;
    }
  }

  static Table fromTextArray({
    Context? context,
    required List<List<dynamic>> data,
    EdgeInsetsGeometry cellPadding = const EdgeInsets.all(5),
    double cellHeight = 0,
    AlignmentGeometry cellAlignment = Alignment.topLeft,
    Map<int, AlignmentGeometry>? cellAlignments,
    TextStyle? cellStyle,
    TextStyle? oddCellStyle,
    OnCellFormat? cellFormat,
    OnCellDecoration? cellDecoration,
    int headerCount = 1,
    List<dynamic>? headers,
    EdgeInsetsGeometry? headerPadding,
    EdgeInsetsGeometry? headerMargin,
    double? headerHeight,
    AlignmentGeometry headerAlignment = Alignment.center,
    Map<int, AlignmentGeometry>? headerAlignments,
    TextStyle? headerStyle,
    OnCellFormat? headerFormat,
    TableBorder? border = const TableBorder(
      left: BorderSide(),
      right: BorderSide(),
      top: BorderSide(),
      bottom: BorderSide(),
      horizontalInside: BorderSide(),
      verticalInside: BorderSide(),
    ),
    Map<int, TableColumnWidth>? columnWidths,
    TableColumnWidth defaultColumnWidth = const IntrinsicColumnWidth(),
    TableWidth tableWidth = TableWidth.max,
    BoxDecoration? headerDecoration,
    BoxDecoration? headerCellDecoration,
    BoxDecoration? rowDecoration,
    BoxDecoration? oddRowDecoration,
    TextDirection? headerDirection,
    TextDirection? tableDirection,
    OnCell? cellBuilder,
    OnCellTextStyle? textStyleBuilder,
  }) {
    assert(headerCount >= 0);

    if (context != null) {
      final theme = Theme.of(context);
      headerStyle ??= theme.tableHeader;
      cellStyle ??= theme.tableCell;
    }

    headerPadding ??= cellPadding;
    headerHeight ??= cellHeight;
    oddRowDecoration ??= rowDecoration;
    oddCellStyle ??= cellStyle;
    cellAlignments ??= const <int, Alignment>{};
    headerAlignments ??= cellAlignments;

    final rows = <TableRow>[];

    var rowNum = 0;
    if (headers != null) {
      final tableRow = <Widget>[];

      for (final dynamic cell in headers) {
        tableRow.add(
          Container(
            alignment: headerAlignments[tableRow.length] ?? headerAlignment,
            padding: headerPadding,
            margin: headerMargin,
            decoration: headerCellDecoration,
            constraints: BoxConstraints(minHeight: headerHeight),
            child: cell is Widget
                ? cell
                : Text(
                    headerFormat == null
                        ? cell.toString()
                        : headerFormat(tableRow.length, cell),
                    style: headerStyle,
                    textDirection: headerDirection,
                  ),
          ),
        );
      }
      rows.add(
        TableRow(
          children: tableRow,
          repeat: true,
          decoration: headerDecoration,
        ),
      );
      rowNum++;
    }

    final textDirection = context == null
        ? TextDirection.ltr
        : Directionality.of(context);
    for (final row in data) {
      final tableRow = <Widget>[];
      final isOdd = (rowNum - headerCount) % 2 != 0;
      if (rowNum < headerCount) {
        for (final dynamic cell in row) {
          final align = headerAlignments[tableRow.length] ?? headerAlignment;
          final textAlign = _textAlign(align.resolve(textDirection));

          tableRow.add(
            Container(
              alignment: align,
              padding: headerPadding,
              constraints: BoxConstraints(minHeight: headerHeight),
              child: cell is Widget
                  ? cell
                  : Text(
                      headerFormat == null
                          ? cell.toString()
                          : headerFormat(tableRow.length, cell),
                      style: headerStyle,
                      textAlign: textAlign,
                      textDirection: headerDirection,
                    ),
            ),
          );
        }
      } else {
        for (final dynamic cell in row) {
          final align = cellAlignments[tableRow.length] ?? cellAlignment;
          tableRow.add(
            Container(
              alignment: align,
              padding: cellPadding,
              margin: headerMargin,
              constraints: BoxConstraints(minHeight: cellHeight),
              decoration: cellDecoration == null
                  ? null
                  : cellDecoration(tableRow.length, cell, rowNum),
              child: cell is Widget
                  ? cell
                  : cellBuilder?.call(tableRow.length, cell, rowNum) ??
                        Text(
                          cellFormat == null
                              ? cell.toString()
                              : cellFormat(tableRow.length, cell),
                          style:
                              textStyleBuilder?.call(
                                tableRow.length,
                                cell,
                                rowNum,
                              ) ??
                              (isOdd ? oddCellStyle : cellStyle),
                          textAlign: _textAlign(align.resolve(textDirection)),
                          textDirection: tableDirection,
                        ),
            ),
          );
        }
      }

      var decoration = isOdd ? oddRowDecoration : rowDecoration;
      if (rowNum < headerCount) {
        decoration = headerDecoration;
      }

      rows.add(
        TableRow(
          children: tableRow,
          repeat: rowNum < headerCount,
          decoration: decoration,
        ),
      );
      rowNum++;
    }
    return Table(
      border: border,
      tableWidth: tableWidth,
      children: rows,
      columnWidths: columnWidths,
      defaultColumnWidth: defaultColumnWidth,
      defaultVerticalAlignment: TableCellVerticalAlignment.full,
    );
  }
}
