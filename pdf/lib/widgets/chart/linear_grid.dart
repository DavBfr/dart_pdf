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

typedef GridAxisFormat = String Function(double value);

class LinearGrid extends ChartGrid {
  LinearGrid({
    @required this.xAxis,
    @required this.yAxis,
    this.xMargin = 10,
    this.yMargin = 2,
    this.textStyle,
    this.lineWidth = 1,
    this.color = PdfColors.black,
    this.separatorLineWidth = .5,
    this.drawXDivisions = false,
    this.drawYDivisions = true,
    this.separatorColor = PdfColors.grey,
    this.xAxisFormat = _defaultFormat,
    this.yAxisFormat = _defaultFormat,
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
  final bool drawXDivisions;
  final bool drawYDivisions;
  final GridAxisFormat xAxisFormat;
  final GridAxisFormat yAxisFormat;

  TextStyle style;
  PdfFont font;
  PdfRect gridBox;
  double xOffset;
  double xTotal;
  double yOffset;
  double yTotal;

  static String _defaultFormat(double v) => v.toString();

  static bool _isSortedAscending(List<double> list) {
    double prev = list.first;
    for (final double elem in list) {
      if (prev > elem) {
        return false;
      }
      prev = elem;
    }
    return true;
  }

  @override
  void layout(Context context, PdfPoint size) {
    style = Theme.of(context).defaultTextStyle.merge(textStyle);
    font = style.font.getFont(context);

    double xMaxWidth = 0;
    double xMaxHeight = 0;
    for (final double value in xAxis) {
      final PdfFontMetrics metrics =
          font.stringMetrics(xAxisFormat(value)) * style.fontSize;
      xMaxWidth = math.max(xMaxWidth, metrics.width);
      xMaxHeight = math.max(xMaxHeight, metrics.maxHeight);
    }

    double yMaxWidth = 0;
    double yMaxHeight = 0;
    for (final double value in yAxis) {
      final PdfFontMetrics metrics =
          font.stringMetrics(yAxisFormat(value)) * style.fontSize;
      yMaxWidth = math.max(yMaxWidth, metrics.width);
      yMaxHeight = math.max(yMaxHeight, metrics.maxHeight);
    }

    gridBox = PdfRect.fromLTRB(
      yMaxWidth + xMargin,
      xMaxHeight + yMargin,
      size.x - xMaxWidth / 2,
      size.y - yMaxHeight / 2,
    );

    xOffset = xAxis.reduce(math.min);
    yOffset = yAxis.reduce(math.min);
    xTotal = xAxis.reduce(math.max) - xOffset;
    yTotal = yAxis.reduce(math.max) - yOffset;
  }

  @override
  PdfPoint tochart(PdfPoint p) {
    return PdfPoint(
      gridBox.left + gridBox.width * (p.x - xOffset) / xTotal,
      gridBox.bottom + gridBox.height * (p.y - yOffset) / yTotal,
    );
  }

  double get xAxisOffset => gridBox.bottom;

  double get yAxisOffset => gridBox.left;

  void _drawAxis(Context context, PdfPoint size) {
    context.canvas
      ..moveTo(size.x, gridBox.bottom)
      ..lineTo(gridBox.left - xMargin / 2, gridBox.bottom)
      ..moveTo(gridBox.left, gridBox.bottom)
      ..lineTo(gridBox.left, size.y)
      ..setStrokeColor(color)
      ..setLineWidth(lineWidth)
      ..setLineCap(PdfLineCap.joinMiter)
      ..strokePath();
  }

  void _drawYDivisions(Context context, PdfPoint size) {
    for (final double y in yAxis.sublist(1)) {
      final PdfPoint p = tochart(PdfPoint(0, y));
      context.canvas.drawLine(
        gridBox.left,
        p.y,
        size.x,
        p.y,
      );
    }

    context.canvas
      ..setStrokeColor(separatorColor)
      ..setLineWidth(separatorLineWidth)
      ..setLineCap(PdfLineCap.joinMiter)
      ..strokePath();
  }

  void _drawXDivisions(Context context, PdfPoint size) {
    for (final double x in xAxis.sublist(1)) {
      final PdfPoint p = tochart(PdfPoint(x, 0));
      context.canvas.drawLine(
        p.x,
        size.y,
        p.x,
        gridBox.bottom,
      );
    }

    context.canvas
      ..setStrokeColor(separatorColor)
      ..setLineWidth(separatorLineWidth)
      ..setLineCap(PdfLineCap.joinMiter)
      ..strokePath();
  }

  void _drawYValues(Context context, PdfPoint size) {
    for (final double y in yAxis) {
      final String v = yAxisFormat(y);
      final PdfFontMetrics metrics = font.stringMetrics(v) * style.fontSize;
      final PdfPoint p = tochart(PdfPoint(0, y));

      context.canvas
        ..setColor(style.color)
        ..drawString(
          style.font.getFont(context),
          style.fontSize,
          v,
          gridBox.left - xMargin - metrics.width,
          p.y - (metrics.ascent + metrics.descent) / 2,
        );
    }
  }

  void _drawXValues(Context context, PdfPoint size) {
    for (final double x in xAxis) {
      final String v = xAxisFormat(x);
      final PdfFontMetrics metrics = font.stringMetrics(v) * style.fontSize;
      final PdfPoint p = tochart(PdfPoint(x, 0));

      context.canvas
        ..setColor(style.color)
        ..drawString(
          style.font.getFont(context),
          style.fontSize,
          v,
          p.x - metrics.width / 2,
          -metrics.descent,
        );
    }
  }

  @override
  void paintBackground(Context context, PdfPoint size) {}

  @override
  void paint(Context context, PdfPoint size) {
    if (drawXDivisions) {
      _drawXDivisions(context, size);
    }
    if (drawYDivisions) {
      _drawYDivisions(context, size);
    }
  }

  @override
  void paintForeground(Context context, PdfPoint size) {
    _drawAxis(context, size);
    _drawXValues(context, size);
    _drawYValues(context, size);
  }

  @override
  void clip(Context context, PdfPoint size) {
    context.canvas
      ..saveContext()
      ..drawRect(
        gridBox.left,
        gridBox.bottom,
        size.x - gridBox.left,
        size.y - gridBox.bottom,
      )
      ..clipPath();
  }

  @override
  void unClip(Context context, PdfPoint size) {
    context.canvas.restoreContext();
  }
}
