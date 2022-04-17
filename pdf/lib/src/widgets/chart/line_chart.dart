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

import '../../../pdf.dart';
import '../geometry.dart';
import '../page.dart';
import '../widget.dart';
import 'chart.dart';
import 'grid_cartesian.dart';
import 'point_chart.dart';

@Deprecated('Use PointChartValue')
class LineChartValue extends PointChartValue {
  const LineChartValue(double x, double y) : super(x, y);
}

class LineDataSet<T extends PointChartValue> extends PointDataSet<T> {
  LineDataSet({
    required List<T> data,
    String? legend,
    PdfColor? pointColor,
    double pointSize = 3,
    PdfColor color = PdfColors.blue,
    this.lineWidth = 2,
    this.drawLine = true,
    this.lineColor,
    bool drawPoints = true,
    BuildCallback? shape,
    Widget Function(Context context, T value)? buildValue,
    ValuePosition valuePosition = ValuePosition.auto,
    this.drawSurface = false,
    this.surfaceOpacity = .2,
    this.surfaceColor,
    this.isCurved = false,
    this.smoothness = 0.35,
  })  : assert(drawLine || drawPoints || drawSurface),
        super(
          legend: legend,
          color: pointColor ?? color,
          data: data,
          drawPoints: drawPoints,
          pointSize: pointSize,
          buildValue: buildValue,
          shape: shape,
          valuePosition: valuePosition,
        );

  final bool drawLine;
  final PdfColor? lineColor;
  final double lineWidth;

  final bool drawSurface;
  final PdfColor? surfaceColor;
  final double surfaceOpacity;

  final bool isCurved;
  final double smoothness;

  @override
  void layout(Context context, BoxConstraints constraints,
      {bool parentUsesSize = false}) {
    box = PdfRect.fromPoints(PdfPoint.zero, constraints.biggest);
  }

  void _drawLine(Context context, ChartGrid grid, bool moveTo) {
    if (data.length < 2) {
      return;
    }

    var t = const PdfPoint(0, 0);

    final p = grid.toChart(data.first.point);
    if (moveTo) {
      context.canvas.moveTo(p.x, p.y);
    } else {
      context.canvas.lineTo(p.x, p.y);
    }

    for (var i = 1; i < data.length; i++) {
      final p = grid.toChart(data[i].point);

      if (!isCurved) {
        context.canvas.lineTo(p.x, p.y);
        continue;
      }

      final pp = grid.toChart(data[i - 1].point);
      final pn = grid.toChart(data[i + 1 < data.length ? i + 1 : i].point);

      final c1 = PdfPoint(pp.x + t.x, pp.y + t.y);

      t = PdfPoint(
          (pn.x - pp.x) / 2 * smoothness, (pn.y - pp.y) / 2 * smoothness);

      final c2 = PdfPoint(p.x - t.x, p.y - t.y);

      context.canvas.curveTo(c1.x, c1.y, c2.x, c2.y, p.x, p.y);
    }
  }

  void _drawSurface(Context context, ChartGrid grid) {
    if (data.length < 2) {
      return;
    }

    final y = (grid is CartesianGrid) ? grid.xAxisOffset : 0.0;
    _drawLine(context, grid, true);

    final pe = grid.toChart(data.last.point);
    context.canvas.lineTo(pe.x, y);
    final pf = grid.toChart(data.first.point);
    context.canvas.lineTo(pf.x, y);
  }

  @override
  void paintBackground(Context context) {
    if (data.isEmpty) {
      return;
    }

    final grid = Chart.of(context).grid;

    if (drawSurface) {
      _drawSurface(context, grid);

      if (surfaceOpacity != 1) {
        context.canvas
          ..saveContext()
          ..setGraphicState(
            PdfGraphicState(opacity: surfaceOpacity),
          );
      }

      context.canvas
        ..setFillColor(surfaceColor ?? color)
        ..fillPath();

      if (surfaceOpacity != 1) {
        context.canvas.restoreContext();
      }
    }
  }

  @override
  void paint(Context context) {
    super.paint(context);

    if (data.isEmpty) {
      return;
    }

    final grid = Chart.of(context).grid;

    if (drawLine) {
      _drawLine(context, grid, true);

      context.canvas
        ..setStrokeColor(lineColor ?? color)
        ..setLineWidth(lineWidth)
        ..setLineCap(PdfLineCap.round)
        ..setLineJoin(PdfLineJoin.round)
        ..strokePath();
    }
  }

  @override
  ValuePosition automaticValuePosition(
    PdfPoint point,
    PdfPoint size,
    PdfPoint? previous,
    PdfPoint? next,
  ) {
    if (point.y - size.y - delta < box!.bottom) {
      return ValuePosition.top;
    }

    if (previous != null &&
        previous.y > point.y &&
        next != null &&
        next.y > point.y) {
      return ValuePosition.bottom;
    }

    if (previous != null &&
        previous.y < point.y &&
        next != null &&
        next.y > point.y) {
      return ValuePosition.left;
    }

    if (previous != null &&
        previous.y > point.y &&
        next != null &&
        next.y < point.y) {
      return ValuePosition.right;
    }

    return super.automaticValuePosition(point, size, previous, next);
  }
}
