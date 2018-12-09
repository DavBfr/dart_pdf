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
      PdfColor color = PdfColor.black,
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

  @override
  void paintBorders(Context context, PdfRect box,
      [List<double> widths, List<double> heights]) {
    super.paintBorders(context, box);

    if (verticalInside) {
      var offset = box.x;
      for (var width in widths.sublist(0, widths.length - 1)) {
        offset += width;
        context.canvas.moveTo(offset, box.y);
        context.canvas.lineTo(offset, box.top);
      }
      context.canvas.strokePath();
    }

    if (horizontalInside) {
      var offset = box.top;
      for (var height in heights.sublist(0, heights.length - 1)) {
        offset -= height;
        context.canvas.moveTo(box.x, offset);
        context.canvas.lineTo(box.right, offset);
      }
      context.canvas.strokePath();
    }
  }
}

class _TableContext extends WidgetContext {
  var firstLine = 0;
  var lastLine = 0;
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

  @override
  bool get canSpan => true;

  /// The rows of the table.
  final List<TableRow> children;

  final TableBorder border;

  final TableCellVerticalAlignment defaultVerticalAlignment;

  final TableWidth tableWidth;

  final _widths = List<double>();
  final _heights = List<double>();

  var _context = _TableContext();

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
      {parentUsesSize = false}) {
    // Compute required width for all row/columns width flex
    final flex = List<double>();
    _widths.clear();
    _heights.clear();
    var index = 0;

    for (var row in children) {
      var n = 0;
      for (var child in row.children) {
        child.layout(context, BoxConstraints());
        final calculatedWidth =
            child.box.width == double.infinity ? 0.0 : child.box.width;
        final childFlex = child._flex.toDouble();
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

    final maxWidth = _widths.reduce((a, b) => a + b);

    // Compute column widths using flex and estimated width
    if (constraints.hasBoundedWidth) {
      final totalFlex = flex.reduce((a, b) => a + b);
      var flexSpace = 0.0;
      for (var n = 0; n < _widths.length; n++) {
        if (flex[n] == 0.0) {
          var newWidth = _widths[n] / maxWidth * constraints.maxWidth;
          if ((tableWidth == TableWidth.max && totalFlex == 0.0) ||
              newWidth < _widths[n]) {
            _widths[n] = newWidth;
          }
          flexSpace += _widths[n];
        }
      }
      final spacePerFlex = totalFlex > 0.0
          ? ((constraints.maxWidth - flexSpace) / totalFlex)
          : double.nan;

      for (var n = 0; n < _widths.length; n++) {
        if (flex[n] > 0.0) {
          var newWidth = spacePerFlex * flex[n];
          _widths[n] = newWidth;
        }
      }
    }

    final totalWidth = _widths.reduce((a, b) => a + b);

    // Compute final widths
    var totalHeight = 0.0;
    index = 0;
    for (var row in children) {
      if (index++ < _context.firstLine && !row.repeat) continue;

      var n = 0;
      var x = 0.0;

      var lineHeight = 0.0;
      for (var child in row.children) {
        final childConstraints = BoxConstraints.tightFor(width: _widths[n]);
        child.layout(context, childConstraints);
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
    for (var row in children) {
      if (index++ < _context.firstLine && !row.repeat) continue;

      for (var child in row.children) {
        child.box = PdfRect(
            child.box.x,
            totalHeight - child.box.y - child.box.height,
            child.box.width,
            child.box.height);
      }

      if (index >= _context.lastLine) break;
    }

    box = PdfRect(0.0, 0.0, totalWidth, totalHeight);
  }

  @override
  void paint(Context context) {
    super.paint(context);

    final mat = Matrix4.identity();
    mat.translate(box.x, box.y);
    context.canvas
      ..saveContext()
      ..setTransform(mat);

    var index = 0;
    for (var row in children) {
      if (index++ < _context.firstLine && !row.repeat) continue;
      for (var child in row.children) {
        child.paint(context);
      }
      if (index >= _context.lastLine) break;
    }
    context.canvas.restoreContext();

    if (border != null) {
      border.paintBorders(context, box, _widths, _heights);
    }
  }

  factory Table.fromTextArray(
      {@required Context context, @required List<List<String>> data}) {
    final rows = List<TableRow>();
    for (var row in data) {
      final tableRow = List<Widget>();
      if (row == data.first) {
        for (var cell in row) {
          tableRow.add(Container(
              alignment: Alignment.center,
              margin: EdgeInsets.all(5),
              child: Text(cell, style: Theme.of(context).tableHeader)));
        }
      } else {
        for (var cell in row) {
          tableRow.add(Container(
              margin: EdgeInsets.all(5),
              child: Text(cell, style: Theme.of(context).tableCell)));
        }
      }
      rows.add(TableRow(children: tableRow, repeat: row == data.first));
    }
    return Table(
        border: TableBorder(), tableWidth: TableWidth.max, children: rows);
  }
}
