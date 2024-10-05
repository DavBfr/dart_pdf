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

import 'dart:math' as math;

import 'package:meta/meta.dart';
import 'package:vector_math/vector_math_64.dart';

import '../../pdf.dart';
import '../../widgets.dart';

/// A horizontal group of cells in a [Table].
@immutable
class TableRow {
  const TableRow({
    required this.children,
    this.repeat = false,
    this.verticalAlignment,
    this.decoration,
  });

  /// The widgets that comprise the cells in this row.
  final List<Widget> children;

  /// Repeat this row on all pages
  final bool repeat;

  final BoxDecoration? decoration;

  final TableCellVerticalAlignment? verticalAlignment;
}

class TableCell extends StatelessWidget {
  TableCell({
    required this.child,
    this.columnSpan = 1,
    this.rowSpan = 1,
  })  : assert(columnSpan >= 1, 'A table cell must at least span one column'),
        assert(rowSpan >= 1, 'A table cell must at least span one row');

  final Widget child;

  final int columnSpan;
  final int rowSpan;

  @override
  Widget build(Context context) {
    return child;
  }
}

enum TableCellVerticalAlignment { bottom, middle, top, full }

enum TableWidth { min, max }

class TableBorder extends Border {
  /// Creates a border for a table.
  const TableBorder({
    BorderSide left = BorderSide.none,
    BorderSide top = BorderSide.none,
    BorderSide right = BorderSide.none,
    BorderSide bottom = BorderSide.none,
    this.horizontalInside = BorderSide.none,
    this.verticalInside = BorderSide.none,
  }) : super(top: top, bottom: bottom, left: left, right: right);

  /// A uniform border with all sides the same color and width.
  factory TableBorder.all({
    PdfColor color = PdfColors.black,
    double width = 1.0,
    BorderStyle style = BorderStyle.solid,
  }) {
    final side = BorderSide(color: color, width: width, style: style);
    return TableBorder(
        top: side,
        right: side,
        bottom: side,
        left: side,
        horizontalInside: side,
        verticalInside: side);
  }

  /// Creates a border for a table where all the interior sides use the same styling and all the exterior sides use the same styling.
  factory TableBorder.symmetric({
    BorderSide inside = BorderSide.none,
    BorderSide outside = BorderSide.none,
  }) {
    return TableBorder(
      top: outside,
      right: outside,
      bottom: outside,
      left: outside,
      horizontalInside: inside,
      verticalInside: inside,
    );
  }

  final BorderSide horizontalInside;
  final BorderSide verticalInside;
}

class TableContext extends WidgetContext {
  /// First line to be rendered (inclusive).
  int firstLine = 0;

  /// Last line to be rendered (exclusive).
  int lastLine = 1;

  @override
  void apply(TableContext other) {
    firstLine = other.firstLine;
    lastLine = other.lastLine;
  }

  @override
  WidgetContext clone() {
    return TableContext()..apply(this);
  }

  @override
  String toString() => '$runtimeType firstLine: $firstLine lastLine: $lastLine';
}

class ColumnLayout {
  ColumnLayout(this.width, this.flex);

  final double? width;
  final double? flex;
}

abstract class TableColumnWidth {
  const TableColumnWidth();

  ColumnLayout layout(
      Widget child, Context context, BoxConstraints constraints);
}

class IntrinsicColumnWidth extends TableColumnWidth {
  const IntrinsicColumnWidth({this.flex});

  final double? flex;

  @override
  ColumnLayout layout(
      Widget child, Context context, BoxConstraints constraints) {
    if (flex != null) {
      return ColumnLayout(0, flex);
    }

    child.layout(context, const BoxConstraints());
    assert(child.box != null);
    final calculatedWidth =
        child.box!.width == double.infinity ? 0.0 : child.box!.width;
    final childFlex = flex ??
        (child is Expanded
            ? child.flex.toDouble()
            : (child.box!.width == double.infinity ? 1 : 0));
    return ColumnLayout(calculatedWidth, childFlex);
  }
}

class FixedColumnWidth extends TableColumnWidth {
  const FixedColumnWidth(this.width);

  final double width;

  @override
  ColumnLayout layout(
      Widget child, Context context, BoxConstraints? constraints) {
    return ColumnLayout(width, 0);
  }
}

class FlexColumnWidth extends TableColumnWidth {
  const FlexColumnWidth([this.flex = 1.0]);

  final double flex;

  @override
  ColumnLayout layout(
      Widget child, Context context, BoxConstraints? constraints) {
    return ColumnLayout(0, flex);
  }
}

class FractionColumnWidth extends TableColumnWidth {
  const FractionColumnWidth(this.value);

  final double value;

  @override
  ColumnLayout layout(
      Widget child, Context context, BoxConstraints? constraints) {
    return ColumnLayout(constraints!.maxWidth * value, 0);
  }
}

typedef OnCellFormat = String Function(int index, dynamic data);
typedef OnCellDecoration = BoxDecoration Function(
    int index, dynamic data, int rowNum);

/// A widget that uses the table layout algorithm for its children.
class Table extends Widget with SpanningWidget {
  Table({
    this.children = const <TableRow>[],
    this.border,
    this.defaultVerticalAlignment = TableCellVerticalAlignment.top,
    this.columnWidths,
    this.defaultColumnWidth = const IntrinsicColumnWidth(),
    this.tableWidth = TableWidth.max,
  }) : super();

  @Deprecated('Use TableHelper.fromTextArray() instead.')
  factory Table.fromTextArray({
    Context? context,
    required List<List<dynamic>> data,
    EdgeInsets cellPadding = const EdgeInsets.all(5),
    double cellHeight = 0,
    Alignment cellAlignment = Alignment.topLeft,
    Map<int, Alignment>? cellAlignments,
    TextStyle? cellStyle,
    TextStyle? oddCellStyle,
    OnCellFormat? cellFormat,
    OnCellDecoration? cellDecoration,
    int headerCount = 1,
    List<dynamic>? headers,
    EdgeInsets? headerPadding,
    double? headerHeight,
    Alignment headerAlignment = Alignment.center,
    Map<int, Alignment>? headerAlignments,
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
  }) =>
      TableHelper.fromTextArray(
        context: context,
        data: data,
        cellPadding: cellPadding,
        cellHeight: cellHeight,
        cellAlignment: cellAlignment,
        cellAlignments: cellAlignments,
        cellStyle: cellStyle,
        oddCellStyle: oddCellStyle,
        cellFormat: cellFormat,
        cellDecoration: cellDecoration,
        headerCount: headerCount = 1,
        headers: headers,
        headerPadding: headerPadding,
        headerHeight: headerHeight,
        headerAlignment: headerAlignment,
        headerAlignments: headerAlignments,
        headerStyle: headerStyle,
        headerFormat: headerFormat,
        border: border,
        columnWidths: columnWidths,
        defaultColumnWidth: defaultColumnWidth,
        tableWidth: tableWidth,
        headerDecoration: headerDecoration,
        headerCellDecoration: headerCellDecoration,
        rowDecoration: rowDecoration,
        oddRowDecoration: oddRowDecoration,
      );

  @override
  bool get canSpan => true;

  @override
  bool get hasMoreWidgets => true;

  /// The rows of the table.
  final List<TableRow> children;

  final TableBorder? border;

  final TableCellVerticalAlignment defaultVerticalAlignment;

  final TableWidth tableWidth;

  final List<double> _heights = <double>[];

  final TableContext _context = TableContext();

  final TableColumnWidth defaultColumnWidth;
  final Map<int, TableColumnWidth>? columnWidths;

  @override
  WidgetContext saveContext() {
    return _context;
  }

  @override
  void restoreContext(TableContext context) {
    _context.apply(context);
    _context.firstLine = _context.lastLine;
  }

  /// Get column and row spans of the table per unspanned cell (col-span, row-span).
  /// Also provide the according index of a spanned cell in [children], if present.
  List<List<(int, int, int?)>> _getTableSpanMatrix() {
    final tableSpans = <List<(int, int, int?)>>[];
    var previousSpansOfRow = <(int, int, int?)>[];
    for (final row in children) {
      var unspannedColIndex = 0;
      final spansOfRow = <(int, int, int?)>[];
      for (var spannedColIndex = 0;
          // <= , because we have to look one column ahead to check if the cell from the previous row had a rowspan.
          spannedColIndex <= row.children.length;
          spannedColIndex++) {
        if (previousSpansOfRow.length > unspannedColIndex) {
          final (previousColSpan, previousRowSpan, previousCell) =
              previousSpansOfRow[unspannedColIndex];
          if (previousRowSpan > 1) {
            // Add cell spans from previous row
            for (var colSpan = previousColSpan; colSpan > 0; colSpan--) {
              spansOfRow.add((colSpan, previousRowSpan - 1, null));
              unspannedColIndex++;
            }
          }
        }
        if (spannedColIndex < row.children.length) {
          final child = row.children[spannedColIndex];
          if (child is TableCell) {
            for (var colSpan = child.columnSpan; colSpan > 0; colSpan--) {
              // Define col and row span for this and remember for the following rows, on each column
              spansOfRow.add((
                colSpan,
                child.rowSpan,
                colSpan == child.columnSpan ? spannedColIndex : null
              ));
              unspannedColIndex++;
            }
          } else {
            // Just a regular cell
            spansOfRow.add((1, 1, spannedColIndex));
            unspannedColIndex++;
          }
        }
      }
      tableSpans.add(spansOfRow);
      previousSpansOfRow = spansOfRow;
    }
    return tableSpans;
  }

  double? _getSpannedWidth(int colIndex, int colSpan, List<double?> widths) {
    final indices = Iterable.generate(colSpan, (span) => colIndex + span);
    return indices.fold<double?>(null, (prev, curIndex) {
      final current = widths[curIndex];
      if (prev == null && current == null) {
        return null;
      }
      return (prev ?? 0) + (current ?? 0);
    });
  }

  @override
  void layout(
    Context context,
    BoxConstraints constraints, {
    bool parentUsesSize = false,
  }) {
    // Compute required width for all row/columns width flex
    final flex = <double?>[];
    final widths = <double?>[];
    _heights.clear();

    final tableCells = _getTableSpanMatrix();
    for (var rowIndex = 0; rowIndex < tableCells.length; rowIndex++) {
      final unspannedRow = tableCells[rowIndex];
      for (var unspannedColIndex = 0;
          unspannedColIndex < unspannedRow.length;
          unspannedColIndex++) {
        final spannedColIndex = unspannedRow[unspannedColIndex].$3;
        final columnWidth =
            columnWidths != null && columnWidths![unspannedColIndex] != null
                ? columnWidths![unspannedColIndex]!
                : defaultColumnWidth;
        // TODO(Gustl22): Handle intrinsic column widths:
        //  Currently, every cell is calculated by filling the remaining spanned
        //  cells with empty containers and then sum up their calculated widths.
        final columnLayout = columnWidth.layout(
            spannedColIndex == null
                ? Container()
                : children[rowIndex].children[spannedColIndex],
            context,
            constraints);
        if (flex.length < unspannedColIndex + 1) {
          flex.add(columnLayout.flex);
          widths.add(columnLayout.width);
        } else {
          if (columnLayout.flex! > 0) {
            flex[unspannedColIndex] =
                math.max(flex[unspannedColIndex]!, columnLayout.flex!);
          }
          widths[unspannedColIndex] =
              math.max(widths[unspannedColIndex]!, columnLayout.width!);
        }
      }
    }

    if (widths.isEmpty) {
      box = PdfRect.fromPoints(PdfPoint.zero, constraints.smallest);
      return;
    }

    final maxWidth = widths.reduce((double? a, double? b) => a! + b!);

    // Compute column widths using flex and estimated width
    if (constraints.hasBoundedWidth) {
      final totalFlex = flex.reduce((double? a, double? b) => a! + b!)!;
      var flexSpace = 0.0;
      for (var n = 0; n < widths.length; n++) {
        if (flex[n] == 0.0) {
          final newWidth = widths[n]! / maxWidth! * constraints.maxWidth;
          if ((tableWidth == TableWidth.max && totalFlex == 0.0) ||
              newWidth < widths[n]!) {
            widths[n] = newWidth;
          }
          flexSpace += widths[n]!;
        }
      }
      final spacePerFlex = totalFlex > 0.0
          ? ((constraints.maxWidth - flexSpace) / totalFlex)
          : double.nan;

      for (var n = 0; n < widths.length; n++) {
        if (flex[n]! > 0.0) {
          final newWidth = spacePerFlex * flex[n]!;
          widths[n] = newWidth;
        }
      }
    }

    final totalWidth = widths.reduce((double? a, double? b) => a! + b!)!;

    // Compute widths and heights
    var totalHeight = 0.0;

    for (var rowIndex = 0; rowIndex < children.length; rowIndex++) {
      final row = children[rowIndex];
      if (rowIndex < _context.firstLine && !row.repeat) {
        continue;
      }

      var lineHeight = 0.0;
      final unspannedRow = tableCells[rowIndex];
      var x = 0.0;
      for (var colIndex = 0; colIndex < unspannedRow.length; colIndex++) {
        final (colSpan, rowSpan, spannedColIndex) = unspannedRow[colIndex];

        if (spannedColIndex != null) {
          final cell = children[rowIndex].children[spannedColIndex];
          assert(colSpan >= 1);
          final spannedWidth = _getSpannedWidth(colIndex, colSpan, widths);
          final childConstraints = BoxConstraints.tightFor(width: spannedWidth);
          cell.layout(context, childConstraints);
          assert(cell.box != null);
          cell.box = cell.box!.copyWith(x: x, y: totalHeight);
          // Ignore row-spanned cells for now
          if (rowSpan <= 1) {
            lineHeight = math.max(lineHeight, cell.box!.height);
          }
        }
        assert(widths[colIndex]! > 0.0);
        x += widths[colIndex]!;
      }

      if (totalHeight + lineHeight > constraints.maxHeight) {
        _context.lastLine = rowIndex;
        break;
      } else {
        _context.lastLine = rowIndex + 1;
      }
      totalHeight += lineHeight;
      _heights.add(lineHeight);
    }

    // Compute distributed row height in a second round, now that the single cell heights are known.
    // See: https://www.w3.org/TR/css-tables-3/#height-distribution
    totalHeight = 0.0;
    // Save all rows incl. the repeated once.
    var pageRowIndex = 0;
    for (var rowIndex = 0;
        rowIndex < children.length && rowIndex < _context.lastLine;
        rowIndex++) {
      final row = children[rowIndex];
      if (rowIndex < _context.firstLine && !row.repeat) {
        continue;
      }

      var lineHeight = _getHeight(pageRowIndex);
      final unspannedRow = tableCells[rowIndex];

      var x = 0.0;
      for (var colIndex = 0; colIndex < unspannedRow.length; colIndex++) {
        final (colSpan, rowSpan, spannedColIndex) = unspannedRow[colIndex];

        if (spannedColIndex != null) {
          final cell = children[rowIndex].children[spannedColIndex];

          // Calculate cells again
          final spannedWidth = _getSpannedWidth(colIndex, colSpan, widths);
          final childConstraints = BoxConstraints.tightFor(width: spannedWidth);
          cell.layout(context, childConstraints);
          assert(cell.box != null);
          cell.box = cell.box!.copyWith(x: x, y: totalHeight);
          assert(rowSpan >= 1);
          if (rowSpan > 1) {
            final rowSpannedHeight = _getSpannedHeight(pageRowIndex, rowSpan);
            final remainingRowLineHeight = cell.box!.height - rowSpannedHeight;
            if (remainingRowLineHeight > 0) {
              // Add remaining row line height, if cell is spanning over multiple rows
              final distributedCellHeight = remainingRowLineHeight / rowSpan;
              lineHeight += distributedCellHeight;
              for (var r = pageRowIndex; r < pageRowIndex + rowSpan; r++) {
                _heights[r] += distributedCellHeight;
              }
            }
          } else {
            lineHeight = math.max(lineHeight, cell.box!.height);
          }
        }
        x += widths[colIndex]!;
      }

      _heights[pageRowIndex] = lineHeight;

      final align = row.verticalAlignment ?? defaultVerticalAlignment;

      if (align == TableCellVerticalAlignment.full) {
        // Compute the layout again to give the full height to all cells in this row (as lineHeight may has changed on later columns)
        x = 0;
        for (var colIndex = 0; colIndex < unspannedRow.length; colIndex++) {
          final (colSpan, rowSpan, spannedColIndex) = unspannedRow[colIndex];
          if (spannedColIndex != null) {
            final cell = children[rowIndex].children[spannedColIndex];
            final spannedWidth = _getSpannedWidth(colIndex, colSpan, widths);
            final rowSpannedHeight = _getSpannedHeight(pageRowIndex, rowSpan);
            final childConstraints = BoxConstraints.tightFor(
                width: spannedWidth, height: rowSpannedHeight);
            cell.layout(context, childConstraints);
            assert(cell.box != null);
            cell.box = cell.box!.copyWith(x: x, y: totalHeight);
          }
          x += widths[colIndex]!;
        }
      }

      if (totalHeight + lineHeight > constraints.maxHeight) {
        // In the second run, heights can still grow (but not shrink), so check again
        _context.lastLine = rowIndex;
        break;
      }
      totalHeight += lineHeight;
      pageRowIndex++;
    }

    pageRowIndex = 0;
    // Compute final y position
    for (var rowIndex = 0;
        rowIndex < children.length && rowIndex < _context.lastLine;
        rowIndex++) {
      final row = children[rowIndex];
      if (rowIndex < _context.firstLine && !row.repeat) {
        continue;
      }

      final align = row.verticalAlignment ?? defaultVerticalAlignment;

      for (final child in row.children) {
        double? childY;
        final rowSpan = child is TableCell ? child.rowSpan : 1;

        // Inverse height, now that the totalHeight is known.
        switch (align) {
          case TableCellVerticalAlignment.bottom:
            childY = totalHeight -
                child.box!.y -
                _getSpannedHeight(pageRowIndex, rowSpan);
            break;
          case TableCellVerticalAlignment.middle:
            childY = totalHeight -
                child.box!.y -
                (_getSpannedHeight(pageRowIndex, rowSpan) + child.box!.height) /
                    2;
            break;
          case TableCellVerticalAlignment.top:
          case TableCellVerticalAlignment.full:
            childY = totalHeight - child.box!.y - child.box!.height;
            break;
        }

        child.box = child.box!.copyWith(y: childY);
      }
      pageRowIndex++;
    }

    box = PdfRect(0, 0, totalWidth, totalHeight);
  }

  @override
  void paint(Context context) {
    super.paint(context);

    if (_context.lastLine == 0) {
      return;
    }

    final mat = Matrix4.identity();
    mat.translate(box!.x, box!.y);
    context.canvas
      ..saveContext()
      ..setTransform(mat);

    for (var rowIndex = 0;
        rowIndex < children.length && rowIndex < _context.lastLine;
        rowIndex++) {
      final row = children[rowIndex];
      if (rowIndex < _context.firstLine && !row.repeat) {
        continue;
      }

      if (row.decoration != null) {
        var y = double.infinity;
        var h = 0.0;
        for (final child in row.children) {
          y = math.min(y, child.box!.y);
          h = math.max(h, child.box!.height);
        }
        row.decoration!.paint(
          context,
          PdfRect(0, y, box!.width, h),
          PaintPhase.background,
        );
      }

      for (final cell in row.children) {
        final cellBox = cell.box!;
        context.canvas
          ..saveContext()
          ..drawRect(cellBox.x, cellBox.y, cellBox.width, cellBox.height)
          ..clipPath();
        cell.paint(context);
        context.canvas.restoreContext();
      }
    }

    for (var rowIndex = 0;
        rowIndex < children.length && rowIndex < _context.lastLine;
        rowIndex++) {
      final row = children[rowIndex];
      if (rowIndex < _context.firstLine && !row.repeat) {
        continue;
      }

      if (row.decoration != null) {
        var y = double.infinity;
        var h = 0.0;
        for (final child in row.children) {
          y = math.min(y, child.box!.y);
          h = math.max(h, child.box!.height);
        }
        row.decoration!.paint(
          context,
          PdfRect(0, y, box!.width, h),
          PaintPhase.foreground,
        );
      }
    }

    if (border != null) {
      // Paint inside borders
      final tableCells = _getTableSpanMatrix();
      var pageRowIndex = 0;
      for (var rowIndex = 0;
          rowIndex < children.length && rowIndex < _context.lastLine;
          rowIndex++) {
        final row = children[rowIndex];
        if (rowIndex < _context.firstLine && !row.repeat) {
          continue;
        }

        // Cell top may is different from the inner cellBox.top because of their alignment.
        final rowTop = box!.height - _getSpannedHeight(0, pageRowIndex);

        for (var spannedColIndex = 0;
            spannedColIndex < row.children.length;
            spannedColIndex++) {
          final cell = row.children[spannedColIndex];
          final cellBox = cell.box!;
          if (border!.verticalInside.style.paint &&
              spannedColIndex != tableCells[rowIndex].first.$3) {
            border!.verticalInside.style.setStyle(context);

            // Use the height(s) of the (spanned) row to determine the bottom of box,
            // otherwise it will draw gaps for cells which have a smaller height.
            context.canvas.moveTo(
                cellBox.x,
                rowTop -
                    (cell is TableCell
                        ? _getSpannedHeight(pageRowIndex, cell.rowSpan)
                        : _getHeight(pageRowIndex)));
            context.canvas.lineTo(cellBox.x, rowTop);
            context.canvas.setStrokeColor(border!.verticalInside.color);
            context.canvas.setLineWidth(border!.verticalInside.width);
            context.canvas.strokePath();
            border!.verticalInside.style.unsetStyle(context);
          }
          if (border!.horizontalInside.style.paint && row != children.first) {
            border!.horizontalInside.style.setStyle(context);
            context.canvas.moveTo(cellBox.left, rowTop);
            context.canvas.lineTo(cellBox.right, rowTop);
            context.canvas.setStrokeColor(border!.horizontalInside.color);
            context.canvas.setLineWidth(border!.horizontalInside.width);
            context.canvas.strokePath();
            border!.horizontalInside.style.unsetStyle(context);
          }
        }
        pageRowIndex++;
      }
    }
    context.canvas.restoreContext();

    if (border != null) {
      // Paint outside border
      border!.paint(context, box!);
    }
  }

  double _getHeight(int heightIndex) {
    return (heightIndex >= 0 && heightIndex < _heights.length)
        ? _heights[heightIndex]
        : 0.0;
  }

  double _getSpannedHeight(int startIndex, int length) {
    if (length <= 0) {
      return 0;
    }
    return _heights
        .sublist(startIndex, startIndex + length)
        .reduce((prev, next) => prev + next);
  }
}
