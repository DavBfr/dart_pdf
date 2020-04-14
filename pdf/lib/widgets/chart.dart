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
    this.width = 500,
    this.height = 250,
    this.fit = BoxFit.contain,
  });

  final double width;
  final double height;
  final BoxFit fit;
  final Grid grid;
  final List<DataSet> data;
  PdfRect gridBox;

  @override
  void layout(Context context, BoxConstraints constraints,
      {bool parentUsesSize = false}) {
    final double w = constraints.hasBoundedWidth
        ? constraints.maxWidth
        : constraints.constrainWidth(width.toDouble());
    final double h = constraints.hasBoundedHeight
        ? constraints.maxHeight
        : constraints.constrainHeight(height.toDouble());

    final FittedSizes sizes =
        applyBoxFit(fit, PdfPoint(width, height), PdfPoint(w, h));

    box = PdfRect.fromPoints(PdfPoint.zero, sizes.destination);
    grid.layout(context, box);
    for (DataSet dataSet in data) {
      dataSet.layout(context, grid.gridBox);
    }
  }

  @override
  void paint(Context context) {
    super.paint(context);

    final Matrix4 mat = Matrix4.identity();
    mat.translate(box.x, box.y);
    context.canvas
      ..saveContext()
      ..setTransform(mat);

    grid.paint(context, box);
    for (DataSet dataSet in data) {
      dataSet.paint(context, grid);
    }
    context.canvas.restoreContext();
  }
}

abstract class Grid {
  PdfRect gridBox;
  double xOffset;
  double xTotal;
  double yOffset;
  double yTotal;

  void layout(Context context, PdfRect box);
  void paint(Context context, PdfRect box);
}

class LinearGrid extends Grid {
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

  TextStyle style;
  PdfFont font;
  PdfFontMetrics xAxisFontMetric;
  PdfFontMetrics yAxisFontMetric;
  double separatorLineWidth;
  PdfColor separatorColor;

  @override
  void layout(Context context, PdfRect box) {
    style = Theme.of(context).defaultTextStyle.merge(textStyle);
    font = style.font.getFont(context);

    xAxisFontMetric =
        font.stringMetrics(xAxis.reduce(math.max).toStringAsFixed(1)) *
            (style.fontSize);
    yAxisFontMetric =
        font.stringMetrics(yAxis.reduce(math.max).toStringAsFixed(1)) *
            (style.fontSize);

    gridBox = PdfRect.fromLTRB(
        box.left + yAxisFontMetric.width + xMargin,
        box.bottom + xAxisFontMetric.height + yMargin,
        box.right - xAxisFontMetric.width / 2,
        box.top - yAxisFontMetric.height / 2);

    xOffset = xAxis.reduce(math.min);
    yOffset = yAxis.reduce(math.min);
    xTotal = xAxis.reduce(math.max) - xOffset;
    yTotal = yAxis.reduce(math.max) - yOffset;
  }

  @override
  void paint(Context context, PdfRect box) {
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
}

class ChartValue {
  ChartValue(this.x, this.y);
  final double x;
  final double y;
}

abstract class DataSet {
  void layout(Context context, PdfRect box);
  void paint(Context context, Grid grid);
}

class LineDataSet extends DataSet {
  LineDataSet({
    @required this.data,
    this.pointColor = PdfColors.green,
    this.pointSize = 8,
    this.lineColor = PdfColors.blue,
    this.lineWidth = 2,
    this.drawLine = true,
    this.drawPoints = true,
    this.lineStartingPoint,
  }) : assert(drawLine || drawPoints);

  final List<ChartValue> data;
  final PdfColor pointColor;
  final double pointSize;
  final PdfColor lineColor;
  final double lineWidth;
  final bool drawLine;
  final bool drawPoints;
  final ChartValue lineStartingPoint;

  double maxValue;

  @override
  void layout(Context context, PdfRect box) {}

  @override
  void paint(Context context, Grid grid) {
    if (drawLine) {
      ChartValue lastValue = lineStartingPoint;
      for (ChartValue value in data) {
        if (lastValue != null) {
          context.canvas.drawLine(
            grid.gridBox.left +
                grid.gridBox.width * (lastValue.x - grid.xOffset) / grid.xTotal,
            grid.gridBox.bottom +
                grid.gridBox.height *
                    (lastValue.y - grid.yOffset) /
                    grid.yTotal,
            grid.gridBox.left +
                grid.gridBox.width * (value.x - grid.xOffset) / grid.xTotal,
            grid.gridBox.bottom +
                grid.gridBox.height * (value.y - grid.yOffset) / grid.yTotal,
          );
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
      for (ChartValue value in data) {
        context.canvas
          ..setColor(pointColor)
          ..drawEllipse(
              grid.gridBox.left +
                  grid.gridBox.width * (value.x - grid.xOffset) / grid.xTotal,
              grid.gridBox.bottom +
                  grid.gridBox.height * (value.y - grid.yOffset) / grid.yTotal,
              pointSize,
              pointSize)
          ..fillPath();
      }
    }
  }
}
