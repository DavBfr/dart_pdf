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

// ignore_for_file: omit_local_variable_types

part of widget;

/// A horizontal group of cells in a [Table].
@immutable
class TableRow {
  const TableRow({this.children, this.repeat = false});

  /// The widgets that comprise the cells in this row.
  final List<Widget> children;

  /// Repeat this row on all pages
  final bool repeat;
}

enum TableCellVerticalAlignment { bottom, middle, top }

enum TableWidth { min, max }

class TableBorder extends BoxBorder {
  const TableBorder(
      {bool left = true,
      bool top = true,
      bool right = true,
      bool bottom = true,
      this.horizontalInside = true,
      this.verticalInside = true,
      PdfColor color = PdfColors.black,
      double width = 1.0})
      : super(
            left: left,
            top: top,
            right: right,
            bottom: bottom,
            color: color,
            width: width);

  final bool horizontalInside;
  final bool verticalInside;

  void paint(Context context, PdfRect box,
      [List<double> widths, List<double> heights]) {
    super.paintRect(context, box);

    if (verticalInside) {
      double offset = box.x;
      for (double width in widths.sublist(0, widths.length - 1)) {
        offset += width;
        context.canvas.moveTo(offset, box.y);
        context.canvas.lineTo(offset, box.top);
      }
      context.canvas.strokePath();
    }

    if (horizontalInside) {
      double offset = box.top;
      for (double height in heights.sublist(0, heights.length - 1)) {
        offset -= height;
        context.canvas.moveTo(box.x, offset);
        context.canvas.lineTo(box.right, offset);
      }
      context.canvas.strokePath();
    }
  }
}

class _TableContext extends WidgetContext {
  int firstLine = 0;
  int lastLine = 0;
}

/// A widget that uses the table layout algorithm for its children.
class Table extends Widget implements SpanningWidget {
  Table(
      {this.children = const <TableRow>[],
      this.border,
      this.defaultVerticalAlignment = TableCellVerticalAlignment.top,
      this.tableWidth = TableWidth.max})
      : assert(children != null),
        super();

  factory Table.fromTextArray(
      {@required Context context, @required List<List<String>> data}) {
    final List<TableRow> rows = <TableRow>[];
    for (List<String> row in data) {
      final List<Widget> tableRow = <Widget>[];
      if (row == data.first) {
        for (String cell in row) {
          tableRow.add(Container(
              alignment: Alignment.center,
              margin: const EdgeInsets.all(5),
              child: Text(cell, style: Theme.of(context).tableHeader)));
        }
      } else {
        for (String cell in row) {
          tableRow.add(Container(
              margin: const EdgeInsets.all(5),
              child: Text(cell, style: Theme.of(context).tableCell)));
        }
      }
      rows.add(TableRow(children: tableRow, repeat: row == data.first));
    }
    return Table(
        border: const TableBorder(),
        tableWidth: TableWidth.max,
        children: rows);
  }

  @override
  bool get canSpan => true;

  /// The rows of the table.
  final List<TableRow> children;

  final TableBorder border;

  final TableCellVerticalAlignment defaultVerticalAlignment;

  final TableWidth tableWidth;

  final List<double> _widths = <double>[];
  final List<double> _heights = <double>[];

  _TableContext _context = _TableContext();

  @override
  WidgetContext saveContext() {
    return _context;
  }

  @override
  void restoreContext(WidgetContext context) {
    _context = context;
    _context.firstLine = _context.lastLine;
  }

  @override
  void layout(Context context, BoxConstraints constraints,
      {bool parentUsesSize = false}) {
    // Compute required width for all row/columns width flex
    final List<double> flex = <double>[];
    _widths.clear();
    _heights.clear();
    int index = 0;

    for (TableRow row in children) {
      int n = 0;
      for (Widget child in row.children) {
        child.layout(context, const BoxConstraints());
        assert(child.box != null);
        final double calculatedWidth =
            child.box.width == double.infinity ? 0.0 : child.box.width;
        final double childFlex = child is Expanded
            ? child.flex.toDouble()
            : (child.box.width == double.infinity ? 1.0 : 0.0);
        if (flex.length < n + 1) {
          flex.add(childFlex);
          _widths.add(calculatedWidth);
        } else {
          if (childFlex > 0) {
            flex[n] *= childFlex;
          }
          _widths[n] = math.max(_widths[n], calculatedWidth);
        }
        n++;
      }
    }

    if (_widths.isEmpty) {
      box = PdfRect.fromPoints(PdfPoint.zero, constraints.smallest);
      return;
    }

    final double maxWidth = _widths.reduce((double a, double b) => a + b);

    // Compute column widths using flex and estimated width
    if (constraints.hasBoundedWidth) {
      final double totalFlex = flex.reduce((double a, double b) => a + b);
      double flexSpace = 0;
      for (int n = 0; n < _widths.length; n++) {
        if (flex[n] == 0.0) {
          final double newWidth = _widths[n] / maxWidth * constraints.maxWidth;
          if ((tableWidth == TableWidth.max && totalFlex == 0.0) ||
              newWidth < _widths[n]) {
            _widths[n] = newWidth;
          }
          flexSpace += _widths[n];
        }
      }
      final double spacePerFlex = totalFlex > 0.0
          ? ((constraints.maxWidth - flexSpace) / totalFlex)
          : double.nan;

      for (int n = 0; n < _widths.length; n++) {
        if (flex[n] > 0.0) {
          final double newWidth = spacePerFlex * flex[n];
          _widths[n] = newWidth;
        }
      }
    }

    final double totalWidth = _widths.reduce((double a, double b) => a + b);

    // Compute final widths
    double totalHeight = 0;
    index = 0;
    for (TableRow row in children) {
      if (index++ < _context.firstLine && !row.repeat) {
        continue;
      }

      int n = 0;
      double x = 0;

      double lineHeight = 0;
      for (Widget child in row.children) {
        final BoxConstraints childConstraints =
            BoxConstraints.tightFor(width: _widths[n]);
        child.layout(context, childConstraints);
        assert(child.box != null);
        child.box = PdfRect(x, totalHeight, child.box.width, child.box.height);
        x += _widths[n];
        lineHeight = math.max(lineHeight, child.box.height);
        n++;
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
    for (TableRow row in children) {
      if (index++ < _context.firstLine && !row.repeat) {
        continue;
      }

      for (Widget child in row.children) {
        child.box = PdfRect(
            child.box.x,
            totalHeight - child.box.y - child.box.height,
            child.box.width,
            child.box.height);
      }

      if (index >= _context.lastLine) {
        break;
      }
    }

    box = PdfRect(0, 0, totalWidth, totalHeight);
  }

  @override
  void paint(Context context) {
    super.paint(context);

    final Matrix4 mat = Matrix4.identity();
    mat.translate(box.x, box.y);
    context.canvas
      ..saveContext()
      ..setTransform(mat);

    if (_context.lastLine == 0) {
      return;
    }

    int index = 0;
    for (TableRow row in children) {
      if (index++ < _context.firstLine && !row.repeat) {
        continue;
      }
      for (Widget child in row.children) {
        context.canvas
          ..saveContext()
          ..drawRect(
              child.box.x, child.box.y, child.box.width, child.box.height)
          ..clipPath();
        child.paint(context);
        context.canvas.restoreContext();
      }
      if (index >= _context.lastLine) {
        break;
      }
    }
    context.canvas.restoreContext();

    if (border != null) {
      border.paint(context, box, _widths, _heights);
    }
  }
}
