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

import '../pdf.dart';
import 'box_border.dart';
import 'geometry.dart';

import 'widget.dart';

/// A widget that draws a rectilinear grid of lines.
/// The grid is drawn over the [child] widget.
class GridPaper extends SingleChildWidget {
  /// Creates a widget that draws a rectilinear grid lines.
  GridPaper({
    PdfColor color = lineColor,
    double interval = 100,
    int divisions = 5,
    int subdivisions = 2,
    Widget child,
  })  : assert(divisions > 0,
            'The "divisions" property must be greater than zero. If there were no divisions, the grid paper would not paint anything.'),
        assert(subdivisions > 0,
            'The "subdivisions" property must be greater than zero. If there were no subdivisions, the grid paper would not paint anything.'),
        horizontalColor = color,
        verticalColor = color,
        horizontalInterval = interval,
        verticalInterval = interval,
        horizontalDivisions = divisions,
        verticalDivisions = divisions,
        horizontalSubdivisions = subdivisions,
        verticalSubdivisions = subdivisions,
        margin = EdgeInsets.zero,
        horizontalOffset = 0,
        verticalOffset = 0,
        border = const Border(),
        scale = 1,
        opacity = 0.5,
        super(child: child);

  GridPaper.millimeter({
    PdfColor color = lineColor,
    Widget child,
  })  : horizontalColor = color,
        verticalColor = color,
        horizontalInterval = 5 * PdfPageFormat.cm,
        verticalInterval = 5 * PdfPageFormat.cm,
        horizontalDivisions = 5,
        verticalDivisions = 5,
        horizontalSubdivisions = 10,
        verticalSubdivisions = 10,
        margin = EdgeInsets.zero,
        horizontalOffset = 0,
        verticalOffset = 0,
        border = const Border(),
        scale = 1,
        opacity = 0.5,
        super(child: child);

  GridPaper.seyes({
    this.margin = const EdgeInsets.only(
      top: 20 * PdfPageFormat.mm,
      bottom: 10 * PdfPageFormat.mm,
      left: 36 * PdfPageFormat.mm,
      right: 0,
    ),
    Widget child,
  })  : horizontalColor = const PdfColor.fromInt(0xffc8c8de),
        verticalColor = const PdfColor.fromInt(0xffc8c8de),
        horizontalInterval = 8 * PdfPageFormat.mm,
        verticalInterval = 8 * PdfPageFormat.mm,
        horizontalDivisions = 1,
        verticalDivisions = 4,
        horizontalSubdivisions = 1,
        verticalSubdivisions = 1,
        horizontalOffset = 0,
        verticalOffset = 1,
        border = const Border(
            left: BorderSide(
          color: PdfColor.fromInt(0xfff6bbcf),
        )),
        scale = 1,
        opacity = 1,
        super(child: child);

  GridPaper.collegeRuled({
    this.margin = const EdgeInsets.only(
      top: 1 * PdfPageFormat.inch,
      bottom: 0.6 * PdfPageFormat.inch,
      left: 1.25 * PdfPageFormat.inch,
      right: 0,
    ),
    Widget child,
  })  : horizontalColor = lineColor,
        verticalColor = lineColor,
        horizontalInterval = double.infinity,
        verticalInterval = 9 / 32 * PdfPageFormat.inch,
        horizontalDivisions = 1,
        verticalDivisions = 1,
        horizontalSubdivisions = 1,
        verticalSubdivisions = 1,
        horizontalOffset = 0,
        verticalOffset = 1,
        border = const Border(
            left: BorderSide(
          color: PdfColors.red,
        )),
        scale = 1,
        opacity = 1,
        super(child: child);

  GridPaper.quad({
    PdfColor color = lineColor,
    Widget child,
  })  : horizontalColor = color,
        verticalColor = color,
        horizontalInterval = PdfPageFormat.inch,
        verticalInterval = PdfPageFormat.inch,
        horizontalDivisions = 4,
        verticalDivisions = 4,
        horizontalSubdivisions = 1,
        verticalSubdivisions = 1,
        margin = EdgeInsets.zero,
        horizontalOffset = 0,
        verticalOffset = 0,
        border = const Border(),
        scale = 1,
        opacity = 0.5,
        super(child: child);

  GridPaper.engineering({
    PdfColor color = lineColor,
    Widget child,
  })  : horizontalColor = color,
        verticalColor = color,
        horizontalInterval = PdfPageFormat.inch,
        verticalInterval = PdfPageFormat.inch,
        horizontalDivisions = 5,
        verticalDivisions = 5,
        horizontalSubdivisions = 2,
        verticalSubdivisions = 2,
        margin = EdgeInsets.zero,
        horizontalOffset = 0,
        verticalOffset = 0,
        border = const Border(),
        scale = 1,
        opacity = 0.5,
        super(child: child);

  static const lineColor = PdfColor.fromInt(0xffc3e8f3);

  /// The color to draw the horizontal lines in the grid.
  final PdfColor horizontalColor;

  /// The color to draw the vertical lines in the grid.
  final PdfColor verticalColor;

  /// The distance between the primary horizontal lines in the grid, in logical pixels.
  final double horizontalInterval;

  /// The distance between the primary vertical lines in the grid, in logical pixels.
  final double verticalInterval;

  /// The number of major horizontal divisions within each primary grid cell.
  final int horizontalDivisions;

  /// The number of major vertical divisions within each primary grid cell.
  final int verticalDivisions;

  /// The number of minor horizontal divisions within each major division, including the
  /// major division itself.
  final int horizontalSubdivisions;

  /// The number of minor vertical divisions within each major division, including the
  /// major division itself.
  final int verticalSubdivisions;

  /// The margin to apply to the horizontal and vertical lines
  final EdgeInsets margin;

  final int horizontalOffset;

  final int verticalOffset;

  final BoxBorder border;

  final double scale;

  final double opacity;

  @override
  void layout(Context context, BoxConstraints constraints,
      {bool parentUsesSize = false}) {
    box = PdfRect.fromPoints(PdfPoint.zero, constraints.biggest);
    if (child != null) {
      if (constraints.hasBoundedWidth && constraints.hasBoundedHeight) {
        final childConstraints = BoxConstraints(
          maxWidth: constraints.maxWidth - margin.horizontal,
          maxHeight: constraints.maxHeight - margin.vertical,
        );
        child.layout(context, childConstraints, parentUsesSize: false);
      } else {
        child.layout(context, constraints, parentUsesSize: false);
      }

      assert(child.box != null);
      child.box = PdfRect.fromPoints(
          PdfPoint(margin.left, box.top - margin.top - child.box.height),
          child.box.size);
    }
  }

  @override
  void paint(Context context) {
    super.paint(context);
    paintChild(context);

    context.canvas.saveContext();
    context.canvas.setGraphicState(PdfGraphicState(opacity: opacity));
    context.canvas.setStrokeColor(horizontalColor);
    final l = scale;
    final m = l / 2;
    final s = m / 2;

    final allHorizontalDivisions =
        (horizontalDivisions * horizontalSubdivisions).toDouble();
    var n = horizontalOffset;
    for (var x = box.left + margin.left;
        x <= box.right - margin.right;
        x += horizontalInterval / allHorizontalDivisions) {
      context.canvas
        ..setLineWidth((n % (horizontalSubdivisions * horizontalDivisions) == 0)
            ? l
            : (n % horizontalSubdivisions == 0)
                ? m
                : s)
        ..drawLine(x, box.top, x, box.bottom)
        ..strokePath();
      n++;
    }

    context.canvas.setStrokeColor(verticalColor);
    final allVerticalDivisions =
        (verticalDivisions * verticalSubdivisions).toDouble();
    n = verticalOffset;
    for (var y = box.top - margin.top;
        y >= box.bottom + margin.bottom;
        y -= verticalInterval / allVerticalDivisions) {
      context.canvas
        ..setLineWidth((n % (verticalSubdivisions * verticalDivisions) == 0)
            ? l
            : (n % verticalSubdivisions == 0)
                ? m
                : s)
        ..drawLine(box.left, y, box.right, y)
        ..strokePath();
      n++;
    }

    if (border.left.style != BorderStyle.none) {
      context.canvas
        ..setStrokeColor(border.left.color)
        ..setLineWidth(border.left.width)
        ..drawLine(
            box.left + margin.left, box.top, box.left + margin.left, box.bottom)
        ..strokePath();
    }
    if (border.right.style != BorderStyle.none) {
      context.canvas
        ..setStrokeColor(border.right.color)
        ..setLineWidth(border.right.width)
        ..drawLine(box.right - margin.right, box.top, box.right - margin.right,
            box.bottom)
        ..strokePath();
    }
    if (border.top.style != BorderStyle.none) {
      context.canvas
        ..setStrokeColor(border.top.color)
        ..setLineWidth(border.top.width)
        ..drawLine(
            box.left, box.top - margin.top, box.right, box.top - margin.top)
        ..strokePath();
    }
    if (border.bottom.style != BorderStyle.none) {
      context.canvas
        ..setStrokeColor(border.bottom.color)
        ..setLineWidth(border.bottom.width)
        ..drawLine(box.left, box.bottom + margin.bottom, box.right,
            box.bottom + margin.bottom)
        ..strokePath();
    }
  }
}
