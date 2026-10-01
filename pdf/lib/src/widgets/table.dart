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
      verticalInside: side,
    );
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

  void paintTable(
    Context context,
    PdfRect box, [
    List<double?>? widths,
    List<double>? heights,
  ]) {
    super.paint(context, box);

    if (verticalInside.style.paint) {
      verticalInside.style.setStyle(context);
      var offset = box.left;
      for (final width in widths!.sublist(0, widths.length - 1)) {
        offset += width!;
        context.canvas.moveTo(offset, box.bottom);
        context.canvas.lineTo(offset, box.top);
      }
      context.canvas.setStrokeColor(verticalInside.color);
      context.canvas.setLineWidth(verticalInside.width);
      context.canvas.strokePath();

      verticalInside.style.unsetStyle(context);
    }

    if (horizontalInside.style.paint) {
      horizontalInside.style.setStyle(context);
      var offset = box.top;
      for (final height in heights!.sublist(0, heights.length - 1)) {
        offset -= height;
        context.canvas.moveTo(box.left, offset);
        context.canvas.lineTo(box.right, offset);
      }
      context.canvas.setStrokeColor(horizontalInside.color);
      context.canvas.setLineWidth(horizontalInside.width);
      context.canvas.strokePath();
      horizontalInside.style.unsetStyle(context);
    }
  }
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
  bool isSameAs(TableContext other) =>
      firstLine == other.firstLine && lastLine == other.lastLine;

  @override
  String toString() => '$runtimeType firstLine: $firstLine lastLine: $lastLine';
}

class ColumnLayout {
  ColumnLayout(this.width, this.flex, {double? minWidth})
    : minWidth = minWidth ?? width;

  final double width;
  final double flex;

  /// The narrowest this column can be without its content being cut.
  ///
  /// Defaults to [width]: a widget that cannot report a minimum is taken to be
  /// as unbreakable as it is wide.
  final double minWidth;
}

abstract class TableColumnWidth {
  const TableColumnWidth();

  ColumnLayout layout(
    Widget child,
    Context context,
    BoxConstraints constraints,
  );
}

class IntrinsicColumnWidth extends TableColumnWidth {
  const IntrinsicColumnWidth({this.flex});

  final double? flex;

  @override
  ColumnLayout layout(
    Widget child,
    Context context,
    BoxConstraints constraints,
  ) {
    if (flex != null) {
      return ColumnLayout(0, flex!);
    }

    child.layout(context, const BoxConstraints());
    assert(child.box != null);
    final maxContent = child.box!.width;
    final calculatedWidth = maxContent == double.infinity ? 0.0 : maxContent;
    final childFlex =
        flex ??
        (child is Expanded
            ? child.flex.toDouble()
            : (maxContent == double.infinity ? 1 : 0));

    // The narrowest the cell can be without a word being cut in half. Every
    // wrapper between here and the text still adds its padding, because this is
    // an ordinary layout pass.
    child.layout(
      context.inheritFrom(const MinContentWidth()),
      const BoxConstraints(),
    );
    final minContent = child.box!.width;

    return ColumnLayout(
      calculatedWidth,
      childFlex,
      minWidth: minContent.isFinite
          ? math.min(minContent, calculatedWidth)
          : calculatedWidth,
    );
  }
}

class FixedColumnWidth extends TableColumnWidth {
  const FixedColumnWidth(this.width);

  final double width;

  @override
  ColumnLayout layout(
    Widget child,
    Context context,
    BoxConstraints? constraints,
  ) {
    return ColumnLayout(width, 0);
  }
}

class FlexColumnWidth extends TableColumnWidth {
  const FlexColumnWidth([this.flex = 1.0]);

  final double flex;

  @override
  ColumnLayout layout(
    Widget child,
    Context context,
    BoxConstraints? constraints,
  ) {
    return ColumnLayout(0, flex);
  }
}

class FractionColumnWidth extends TableColumnWidth {
  const FractionColumnWidth(this.value);

  final double value;

  @override
  ColumnLayout layout(
    Widget child,
    Context context,
    BoxConstraints? constraints,
  ) {
    return ColumnLayout(constraints!.maxWidth * value, 0);
  }
}

typedef OnCellFormat = String Function(int index, dynamic data);
typedef OnCellDecoration =
    BoxDecoration Function(int index, dynamic data, int rowNum);

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
  }) => TableHelper.fromTextArray(
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
    headerCount: headerCount,
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
  bool get hasMoreWidgets => _context.lastLine < children.length;

  /// [hasMoreWidgets] is exact after any layout, so MultiPage can skip its
  /// unbounded probe.
  @override
  bool get reportsCompletion => true;

  /// The rows of the table.
  final List<TableRow> children;

  final TableBorder? border;

  final TableCellVerticalAlignment defaultVerticalAlignment;

  final TableWidth tableWidth;

  final List<double> _widths = <double>[];
  final List<double> _heights = <double>[];

  /// The column widths from the last layout, and what they were computed for.
  ///
  /// The measure pass depends only on the incoming maxWidth, the theme and the
  /// text direction, and it used to run again on every page: a MultiPage whose
  /// body is one Table re-measured every cell for every page, which made output
  /// quadratic in the row count - 2000 rows took the best part of a minute.
  List<double>? _cachedWidths;
  double? _cachedMaxWidth;
  ThemeData? _cachedTheme;
  TextDirection? _cachedDirection;

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

  @override
  void layout(
    Context context,
    BoxConstraints constraints, {
    bool parentUsesSize = false,
  }) {
    _heights.clear();

    final theme = Theme.of(context);
    final direction = Directionality.of(context);
    final cached = _cachedWidths;
    var index = 0;

    if (cached != null &&
        _cachedMaxWidth == constraints.maxWidth &&
        identical(_cachedTheme, theme) &&
        _cachedDirection == direction) {
      _widths
        ..clear()
        ..addAll(cached);
    } else {
      // Compute required width for all row/columns width flex
      final flex = <double>[];
      final mins = <double>[];
      _widths.clear();

      for (final row in children) {
        for (var index = 0; index < row.children.length; index++) {
          final child = row.children[index];
          final columnWidth = columnWidths?[index] ?? defaultColumnWidth;
          final columnLayout = columnWidth.layout(child, context, constraints);

          if (index >= flex.length) {
            flex.add(columnLayout.flex);
            _widths.add(columnLayout.width);
            mins.add(columnLayout.minWidth);
          } else {
            if (columnLayout.flex > 0) {
              flex[index] = math.max(flex[index], columnLayout.flex);
            }
            _widths[index] = math.max(_widths[index], columnLayout.width);
            mins[index] = math.max(mins[index], columnLayout.minWidth);
          }
        }
      }

      final maxWidth = _widths.fold(0.0, (sum, element) => sum + element);

      // Compute column widths using flex and estimated width
      if (_widths.isNotEmpty && constraints.hasBoundedWidth) {
        final totalFlex = flex.reduce((double? a, double? b) => a! + b!);
        var flexSpace = 0.0;

        if (maxWidth > 0) {
          // The narrowest the inflexible columns can be, and the widest they want.
          var totalMin = 0.0;
          var totalMax = 0.0;
          for (var n = 0; n < _widths.length; n++) {
            if (flex[n] == 0.0) {
              totalMin += mins[n];
              totalMax += _widths[n];
            }
          }

          // CSS automatic table layout. Every column used to be rescaled by the
          // same factor with no per-column floor, so an overflowing table squeezed
          // a short column below the width of one word and the cell hard-split it:
          // 'ATLANTICA' came out as ATLANTI then CA. Now each column keeps at least
          // what its longest word needs, and what is left over is shared in
          // proportion to how much more each column wanted.
          final available = constraints.maxWidth;
          final overflowing = totalMax > available && totalMin < totalMax;

          for (var n = 0; n < _widths.length; n++) {
            if (flex[n] != 0.0) {
              continue;
            }

            final double newWidth;
            if (!overflowing) {
              newWidth = _widths[n] / maxWidth * available;
            } else if (totalMin <= available) {
              newWidth =
                  mins[n] +
                  (_widths[n] - mins[n]) *
                      (available - totalMin) /
                      (totalMax - totalMin);
            } else {
              // Not even the minimums fit: they are scaled down together, which is
              // the only thing left that keeps the widths summing to the width
              // there is.
              newWidth = mins[n] / totalMin * available;
            }

            if ((tableWidth == TableWidth.max && totalFlex == 0.0) ||
                newWidth < _widths[n]) {
              _widths[n] = newWidth;
            }
            flexSpace += _widths[n];
          }
        } else if (tableWidth == TableWidth.max && totalFlex == 0.0) {
          // Every column measured zero, so there is nothing to scale in
          // proportion: the division was 0.0/0.0 and the NaN landed in the widths,
          // in the table box, in every cell box and in drawRect. There is still an
          // available width to fill, so it is shared out evenly. TableWidth.min
          // and the flex path keep width 0, as they did.
          final even = constraints.maxWidth / _widths.length;
          for (var n = 0; n < _widths.length; n++) {
            _widths[n] = even;
            flexSpace += even;
          }
        }
        final spacePerFlex = totalFlex > 0.0
            ? ((constraints.maxWidth - flexSpace) / totalFlex)
            : double.nan;

        for (var n = 0; n < _widths.length; n++) {
          if (flex[n] > 0.0) {
            final newWidth = spacePerFlex * flex[n];
            _widths[n] = newWidth;
          }
        }
      }

      _cachedWidths = List<double>.of(_widths);
      _cachedMaxWidth = constraints.maxWidth;
      _cachedTheme = theme;
      _cachedDirection = direction;
    }

    if (_widths.isEmpty) {
      box = PdfRect.fromPoints(PdfPoint.zero, constraints.smallest);
      return;
    }

    final totalWidth = _widths.fold(0.0, (sum, element) => sum + element);

    // Compute final widths
    var totalHeight = 0.0;
    index = 0;
    for (final row in children) {
      if (index++ < _context.firstLine && !row.repeat) {
        continue;
      }

      var n = 0;
      var x = 0.0;

      var lineHeight = 0.0;
      for (final child in row.children) {
        final childConstraints = BoxConstraints.tightFor(width: _widths[n]);
        child.layout(context, childConstraints);
        assert(child.box != null);
        child.box = PdfRect(
          x,
          totalHeight,
          child.box!.width,
          child.box!.height,
        );
        x += _widths[n];
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
            width: _widths[n],
            height: lineHeight,
          );
          child.layout(context, childConstraints);
          assert(child.box != null);
          child.box = PdfRect(
            x,
            totalHeight,
            child.box!.width,
            child.box!.height,
          );
          x += _widths[n];
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
            childY = totalHeight - child.box!.bottom - _getHeight(heightIndex);
            break;
          case TableCellVerticalAlignment.middle:
            childY =
                totalHeight -
                child.box!.bottom -
                (_getHeight(heightIndex) + child.box!.height) / 2;
            break;
          case TableCellVerticalAlignment.top:
          case TableCellVerticalAlignment.full:
            childY = totalHeight - child.box!.bottom - child.box!.height;
            break;
        }

        child.box = PdfRect(
          child.box!.left,
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
    mat.translateByDouble(box!.left, box!.bottom, 0, 1);
    context.canvas
      ..saveContext()
      ..setTransform(mat);

    var index = 0;
    var heightIndex = 0;
    var yTop = box!.height;
    for (final row in children) {
      if (index++ < _context.firstLine && !row.repeat) {
        continue;
      }

      if (row.decoration != null) {
        row.decoration!.paint(
          context,
          _rowBand(row.children, yTop, heightIndex),
          PaintPhase.background,
        );
      }

      for (final child in row.children) {
        context.canvas
          ..saveContext()
          ..drawRect(
            child.box!.left,
            child.box!.bottom,
            child.box!.width,
            child.box!.height,
          )
          ..clipPath();
        child.paint(context);
        context.canvas.restoreContext();
      }
      if (index >= _context.lastLine) {
        break;
      }
      yTop -= _getHeight(heightIndex);
      heightIndex++;
    }

    index = 0;
    heightIndex = 0;
    yTop = box!.height;
    for (final row in children) {
      if (index++ < _context.firstLine && !row.repeat) {
        continue;
      }

      if (row.decoration != null) {
        row.decoration!.paint(
          context,
          _rowBand(row.children, yTop, heightIndex),
          PaintPhase.foreground,
        );
      }

      if (index >= _context.lastLine) {
        break;
      }
      yTop -= _getHeight(heightIndex);
      heightIndex++;
    }

    context.canvas.restoreContext();

    if (border != null) {
      border!.paintTable(context, box!, _widths, _heights);
    }
  }

  /// The band row [heightIndex] fills, in the table's own coordinates.
  ///
  /// Both decoration phases used to seed the band as y = infinity, h = 0 and
  /// lower y only inside the children loop, so a row with an empty children list
  /// left y infinite: the stream carried `0 Infinity <w> 0 re` and poppler
  /// dropped everything drawn after it. Layout already treats such a row as a
  /// legal zero-height band, and [top] is where that band sits.
  PdfRect _rowBand(List<Widget> cells, double top, int heightIndex) {
    var y = double.infinity;
    var h = 0.0;

    for (final cell in cells) {
      y = math.min(y, cell.box!.bottom);
      h = math.max(h, cell.box!.height);
    }

    if (!y.isFinite || !h.isFinite) {
      return PdfRect(0, top - _getHeight(heightIndex), box!.width, 0);
    }

    return PdfRect(0, y, box!.width, h);
  }

  double _getHeight(int heightIndex) {
    return (heightIndex >= 0 && heightIndex < _heights.length)
        ? _heights[heightIndex]
        : 0.0;
  }
}
