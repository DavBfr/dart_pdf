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

class LineChartValue extends ChartValue {
  const LineChartValue(this.x, this.y);
  final double x;
  final double y;

  PdfPoint get point => PdfPoint(x, y);
}

class LineDataSet extends DataSet {
  LineDataSet({
    @required this.data,
    this.pointColor,
    this.pointSize = 3,
    this.color = PdfColors.blue,
    this.lineWidth = 2,
    this.drawLine = true,
    this.drawPoints = true,
    this.isCurved = false,
    this.smoothness = 0.35,
  }) : assert(drawLine || drawPoints);

  final List<LineChartValue> data;
  final PdfColor pointColor;
  final double pointSize;
  final PdfColor color;
  final double lineWidth;
  final bool drawLine;
  final bool drawPoints;
  final bool isCurved;
  final double smoothness;

  void _drawLine(Context context, ChartGrid grid) {
    if (data.length < 2) {
      return;
    }

    PdfPoint t = const PdfPoint(0, 0);

    final PdfPoint p = grid.tochart(data.first.point);
    context.canvas.moveTo(p.x, p.y);

    for (int i = 1; i < data.length; i++) {
      final PdfPoint p = grid.tochart(data[i].point);

      if (!isCurved) {
        context.canvas.lineTo(p.x, p.y);
        continue;
      }

      final PdfPoint pp = grid.tochart(data[i - 1].point);
      final PdfPoint pn =
          grid.tochart(data[i + 1 < data.length ? i + 1 : i].point);

      final PdfPoint c1 = PdfPoint(pp.x + t.x, pp.y + t.y);

      t = PdfPoint(
          (pn.x - pp.x) / 2 * smoothness, (pn.y - pp.y) / 2 * smoothness);

      final PdfPoint c2 = PdfPoint(p.x - t.x, p.y - t.y);

      context.canvas.curveTo(c1.x, c1.y, c2.x, c2.y, p.x, p.y);
    }
  }

  void _drawPoints(Context context, ChartGrid grid) {
    for (final LineChartValue value in data) {
      final PdfPoint p = grid.tochart(value.point);
      context.canvas.drawEllipse(p.x, p.y, pointSize, pointSize);
    }
  }

  @override
  void paintBackground(Context context, ChartGrid grid) {}

  @override
  void paintForeground(Context context, ChartGrid grid) {
    if (data.isEmpty) {
      return;
    }

    if (drawLine) {
      _drawLine(context, grid);

      context.canvas
        ..setStrokeColor(color)
        ..setLineWidth(lineWidth)
        ..setLineCap(PdfLineCap.joinRound)
        ..setLineJoin(PdfLineCap.joinRound)
        ..strokePath();
    }

    if (drawPoints) {
      _drawPoints(context, grid);

      context.canvas
        ..setColor(pointColor ?? color)
        ..fillPath();
    }
  }
}
