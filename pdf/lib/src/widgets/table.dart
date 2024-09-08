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
    this.columnSpans,
  });

  /// The widgets that comprise the cells in this row.
  final List<Widget> children;

  /// Repeat this row on all pages
  final bool repeat;

  final BoxDecoration? decoration;

  final TableCellVerticalAlignment? verticalAlignment;

  final Map<int, int>? columnSpans;
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
  int firstLine = 0;
  int lastLine = 0;

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

  List<Widget> _getFilledChildrenFromColumnSpans(TableRow row) {
    if (row.columnSpans == null) {
      return row.children;
    }
    final filledChildren = <Widget>[];
    var n = 0;
    // TODO(Gustl22): Handle intrinsic column widths:
    //  Currently, every cell is calculated by filling the remaining spanned
    //  cells with empty containers and then sum up their calculated widths.
    for (final child in row.children) {
      // Columns, which are currently spanned.
      final columnSpan = row.columnSpans![n] ?? 1;
      filledChildren.add(child);
      if (columnSpan > 1) {
        filledChildren
            .addAll(Iterable.generate(columnSpan - 1, (index) => Container()));
      }
      n += columnSpan;
    }
    return filledChildren;
  }

  List<double?> _getSpannedWidths(List<double?> widths, TableRow row) {
    final spannedWidths = <double?>[];
    var n = 0;
    for (var i = 0; i < row.children.length; i++) {
      final columnSpan = row.columnSpans?[n] ?? 1;
      final indices = Iterable.generate(columnSpan, (span) => n + span);
      final width = indices.fold<double?>(null, (prev, curIndex) {
        final current = widths[curIndex];
        if (prev == null && current == null) {
          return null;
        }
        return (prev ?? 0) + (current ?? 0);
      });
      spannedWidths.add(width);
      n += columnSpan;
    }
    return spannedWidths;
  }

  @override
  void layout(Context context, BoxConstraints constraints,
      {bool parentUsesSize = false}) {
    // Compute required width for all row/columns width flex
    final flex = <double?>[];
    final widths = <double?>[];
    _heights.clear();
    var index = 0;

    for (final row in children) {
      var n = 0;
      for (final child in _getFilledChildrenFromColumnSpans(row)) {
        final columnWidth = columnWidths != null && columnWidths![n] != null
            ? columnWidths![n]!
            : defaultColumnWidth;
        final columnLayout = columnWidth.layout(child, context, constraints);
        if (flex.length < n + 1) {
          flex.add(columnLayout.flex);
          widths.add(columnLayout.width);
        } else {
          if (columnLayout.flex! > 0) {
            flex[n] = math.max(flex[n]!, columnLayout.flex!);
          }
          widths[n] = math.max(widths[n]!, columnLayout.width!);
        }
        n++;
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

    // Compute final widths
    var totalHeight = 0.0;
    index = 0;
    for (final row in children) {
      if (index++ < _context.firstLine && !row.repeat) {
        continue;
      }

      final spannedWidths = _getSpannedWidths(widths, row);

      var n = 0;
      var x = 0.0;

      var lineHeight = 0.0;

      for (final child in row.children) {
        final childConstraints =
            BoxConstraints.tightFor(width: spannedWidths[n]);
        child.layout(context, childConstraints);
        assert(child.box != null);
        child.box =
            PdfRect(x, totalHeight, child.box!.width, child.box!.height);
        x += spannedWidths[n]!;
        lineHeight = math.max(lineHeight, child.box!.height);
        n++;
      }

      final align = row.verticalAlignment ?? defaultVerticalAlignment;

      if (align == TableCellVerticalAlignment.full) {
        // Compute the layout again to give the full height to all cells
        n = 0;
        x = 0;
        for (final child in row.children) {
          final childConstraints = BoxConstraints.tightFor(
              width: spannedWidths[n], height: lineHeight);
          child.layout(context, childConstraints);
          assert(child.box != null);
          child.box =
              PdfRect(x, totalHeight, child.box!.width, child.box!.height);
          x += spannedWidths[n]!;
          n++;
        }
      }

      if (totalHeight + lineHeight > constraints.maxHeight) {
        index--;
        break;
      }
      totalHeight += lineHeight;
      _heights.add(lineHeight);
    }
    _context.lastLine = index;

    // Compute final y position
    index = 0;
    var heightIndex = 0;
    for (final row in children) {
      if (index++ < _context.firstLine && !row.repeat) {
        continue;
      }

      final align = row.verticalAlignment ?? defaultVerticalAlignment;

      for (final child in row.children) {
        double? childY;

        switch (align) {
          case TableCellVerticalAlignment.bottom:
            childY = totalHeight - child.box!.y - _getHeight(heightIndex);
            break;
          case TableCellVerticalAlignment.middle:
            childY = totalHeight -
                child.box!.y -
                (_getHeight(heightIndex) + child.box!.height) / 2;
            break;
          case TableCellVerticalAlignment.top:
          case TableCellVerticalAlignment.full:
            childY = totalHeight - child.box!.y - child.box!.height;
            break;
        }

        child.box = PdfRect(
          child.box!.x,
          childY,
          child.box!.width,
          child.box!.height,
        );
      }

      if (index >= _context.lastLine) {
        break;
      }
      heightIndex++;
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

    var index = 0;
    for (final row in children) {
      if (index++ < _context.firstLine && !row.repeat) {
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
        if (border?.verticalInside.style.paint == true &&
            cell != row.children.first) {
          border!.verticalInside.style.setStyle(context);

          context.canvas.moveTo(cellBox.x, cellBox.bottom);
          context.canvas.lineTo(cellBox.x, cellBox.top);
          context.canvas.setStrokeColor(border!.verticalInside.color);
          context.canvas.setLineWidth(border!.verticalInside.width);
          context.canvas.strokePath();

          border!.verticalInside.style.unsetStyle(context);
        }
        if (border?.horizontalInside.style.paint == true &&
            row != children.first) {
          border!.horizontalInside.style.setStyle(context);
          context.canvas.moveTo(cellBox.left, cellBox.top);
          context.canvas.lineTo(cellBox.right, cellBox.top);
          context.canvas.setStrokeColor(border!.horizontalInside.color);
          context.canvas.setLineWidth(border!.horizontalInside.width);
          context.canvas.strokePath();
          border!.horizontalInside.style.unsetStyle(context);
        }
      }
      if (index >= _context.lastLine) {
        break;
      }
    }

    index = 0;
    for (final row in children) {
      if (index++ < _context.firstLine && !row.repeat) {
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

      if (index >= _context.lastLine) {
        break;
      }
    }

    context.canvas.restoreContext();

    // Paint outside borders
    if (border != null) {
      border!.paint(context, box!);
    }
  }

  double _getHeight(int heightIndex) {
    return (heightIndex >= 0 && heightIndex < _heights.length)
        ? _heights[heightIndex]
        : 0.0;
  }
}
