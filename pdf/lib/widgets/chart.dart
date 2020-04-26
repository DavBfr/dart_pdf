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

bool _isSortedAscending(List<double> list) {
  double prev = list.first;
  for (double elem in list) {
    if (prev > elem) {
      return false;
    }
    prev = elem;
  }
  return true;
}

class Chart extends Widget {
  Chart({
    @required this.grid,
    @required this.data,
  });

  final ChartGrid grid;

  final List<DataSet> data;

  PdfPoint _computeSize(BoxConstraints constraints) {
    if (constraints.isTight) {
      return constraints.smallest;
    }

    double width = constraints.maxWidth;
    double height = constraints.maxHeight;

    const double aspectRatio = 1;

    if (!width.isFinite) {
      width = height * aspectRatio;
    }

    if (!height.isFinite) {
      height = width * aspectRatio;
    }

    return constraints.constrain(PdfPoint(width, height));
  }

  @override
  void layout(Context context, BoxConstraints constraints,
      {bool parentUsesSize = false}) {
    box = PdfRect.fromPoints(PdfPoint.zero, _computeSize(constraints));

    grid.layout(context, box.size);
  }

  @override
  void paint(Context context) {
    super.paint(context);

    final Matrix4 mat = Matrix4.identity();
    mat.translate(box.x, box.y);
    context.canvas
      ..saveContext()
      ..setTransform(mat);

    grid.paintBackground(context, box.size);
    for (DataSet dataSet in data) {
      dataSet.paintBackground(context, grid);
    }
    for (DataSet dataSet in data) {
      dataSet.paintForeground(context, grid);
    }
    grid.paintForeground(context, box.size);
    context.canvas.restoreContext();
  }
}

abstract class ChartGrid {
  void layout(Context context, PdfPoint size);
  void paintBackground(Context context, PdfPoint size);
  void paintForeground(Context context, PdfPoint size);

  PdfPoint tochart(PdfPoint p);
}

class LinearGrid extends ChartGrid {
  LinearGrid({
    @required this.xAxis,
    @required this.yAxis,
    this.xMargin = 10,
    this.yMargin = 2,
    this.textStyle,
    this.lineWidth = 1,
    this.color = PdfColors.black,
    this.separatorLineWidth = 1,
    this.separatorColor = PdfColors.grey,
  })  : assert(_isSortedAscending(xAxis)),
        assert(_isSortedAscending(yAxis));

  final List<double> xAxis;
  final List<double> yAxis;
  final double xMargin;
  final double yMargin;
  final TextStyle textStyle;
  final double lineWidth;
  final PdfColor color;
  final double separatorLineWidth;
  final PdfColor separatorColor;

  TextStyle style;
  PdfFont font;
  PdfFontMetrics xAxisFontMetric;
  PdfFontMetrics yAxisFontMetric;
  PdfRect gridBox;
  double xOffset;
  double xTotal;
  double yOffset;
  double yTotal;

  @override
  PdfPoint tochart(PdfPoint p) {
    return PdfPoint(
      gridBox.left + gridBox.width * (p.x - xOffset) / xTotal,
      gridBox.bottom + gridBox.height * (p.y - yOffset) / yTotal,
    );
  }

  @override
  void layout(Context context, PdfPoint size) {
    style = Theme.of(context).defaultTextStyle.merge(textStyle);
    font = style.font.getFont(context);

    xAxisFontMetric =
        font.stringMetrics(xAxis.reduce(math.max).toStringAsFixed(1)) *
            (style.fontSize);
    yAxisFontMetric =
        font.stringMetrics(yAxis.reduce(math.max).toStringAsFixed(1)) *
            (style.fontSize);

    gridBox = PdfRect.fromLTRB(
        yAxisFontMetric.width + xMargin,
        xAxisFontMetric.height + yMargin,
        size.x - xAxisFontMetric.width / 2,
        size.y - yAxisFontMetric.height / 2);

    xOffset = xAxis.reduce(math.min);
    yOffset = yAxis.reduce(math.min);
    xTotal = xAxis.reduce(math.max) - xOffset;
    yTotal = yAxis.reduce(math.max) - yOffset;
  }

  @override
  void paintBackground(Context context, PdfPoint size) {
    xAxis.asMap().forEach((int i, double x) {
      context.canvas
        ..setColor(style.color)
        ..drawString(
          style.font.getFont(context),
          style.fontSize,
          x.toStringAsFixed(1),
          gridBox.left +
              gridBox.width * i / (xAxis.length - 1) -
              xAxisFontMetric.width / 2,
          0,
        );
    });

    for (double y in yAxis.where((double y) => y != yAxis.first)) {
      final double textWidth =
          (font.stringMetrics(y.toStringAsFixed(1)) * (style.fontSize)).width;
      final double yPos = gridBox.bottom + gridBox.height * y / yAxis.last;
      context.canvas
        ..setColor(style.color)
        ..drawString(
          style.font.getFont(context),
          style.fontSize,
          y.toStringAsFixed(1),
          xAxisFontMetric.width / 2 - textWidth / 2,
          yPos - font.ascent,
        );

      context.canvas.drawLine(
          gridBox.left,
          yPos + font.descent + font.ascent - separatorLineWidth / 2,
          gridBox.right,
          yPos + font.descent + font.ascent - separatorLineWidth / 2);
    }
    context.canvas
      ..setStrokeColor(separatorColor)
      ..setLineWidth(separatorLineWidth)
      ..strokePath();

    context.canvas
      ..setStrokeColor(color)
      ..setLineWidth(lineWidth)
      ..drawLine(gridBox.left, gridBox.bottom, gridBox.right, gridBox.bottom)
      ..drawLine(gridBox.left, gridBox.bottom, gridBox.left, gridBox.top)
      ..strokePath();
  }

  @override
  void paintForeground(Context context, PdfPoint size) {}
}

@immutable
abstract class ChartValue {
  const ChartValue();
}

class LineChartValue extends ChartValue {
  const LineChartValue(this.x, this.y);
  final double x;
  final double y;

  PdfPoint get point => PdfPoint(x, y);
}

abstract class DataSet {
  void paintBackground(Context context, ChartGrid grid);
  void paintForeground(Context context, ChartGrid grid);
}

class LineDataSet extends DataSet {
  LineDataSet({
    @required this.data,
    this.pointColor = PdfColors.blue,
    this.pointSize = 3,
    this.lineColor = PdfColors.blue,
    this.lineWidth = 2,
    this.drawLine = true,
    this.drawPoints = true,
  }) : assert(drawLine || drawPoints);

  final List<LineChartValue> data;
  final PdfColor pointColor;
  final double pointSize;
  final PdfColor lineColor;
  final double lineWidth;
  final bool drawLine;
  final bool drawPoints;

  double maxValue;

  @override
  void paintBackground(Context context, ChartGrid grid) {
    if (drawLine) {
      LineChartValue lastValue;
      for (LineChartValue value in data) {
        if (lastValue != null) {
          final PdfPoint p1 = grid.tochart(lastValue.point);
          final PdfPoint p2 = grid.tochart(value.point);
          context.canvas.drawLine(p1.x, p1.y, p2.x, p2.y);
        }
        lastValue = value;
      }

      context.canvas
        ..setStrokeColor(lineColor)
        ..setLineWidth(lineWidth)
        ..setLineCap(PdfLineCap.joinRound)
        ..setLineJoin(PdfLineCap.joinRound)
        ..strokePath();
    }

    if (drawPoints) {
      for (LineChartValue value in data) {
        final PdfPoint p = grid.tochart(value.point);
        context.canvas
          ..setColor(pointColor)
          ..drawEllipse(p.x, p.y, pointSize, pointSize)
          ..fillPath();
      }
    }
  }

  @override
  void paintForeground(Context context, ChartGrid grid) {}
}
