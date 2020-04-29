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

class BarDataSet extends DataSet {
  BarDataSet({
    @required this.data,
    this.borderColor,
    this.borderWidth = 1.5,
    this.color = PdfColors.blue,
    this.drawBorder = true,
    this.drawSurface = true,
    this.surfaceOpacity = 1,
    this.width = 20,
    this.offset = 0,
    this.margin = 5,
  }) : assert(drawBorder || drawSurface);

  final List<LineChartValue> data;
  final double width;
  final double offset;
  final double margin;

  final bool drawBorder;
  final PdfColor borderColor;
  final double borderWidth;

  final bool drawSurface;
  final PdfColor color;
  final double surfaceOpacity;

  void _drawSurface(Context context, ChartGrid grid, LineChartValue value) {
    final double y = (grid is LinearGrid) ? grid.xAxisOffset : 0;
    final PdfPoint p = grid.tochart(value.point);

    context.canvas.drawRect(p.x + offset - width / 2, y, width, p.y);
  }

  @override
  void paintBackground(Context context, ChartGrid grid) {}

  @override
  void paintForeground(Context context, ChartGrid grid) {
    if (data.isEmpty) {
      return;
    }

    if (data.isEmpty) {
      return;
    }

    if (drawSurface) {
      for (final LineChartValue value in data) {
        _drawSurface(context, grid, value);
      }

      if (surfaceOpacity != 1) {
        context.canvas
          ..saveContext()
          ..setGraphicState(
            PdfGraphicState(opacity: surfaceOpacity),
          );
      }

      context.canvas
        ..setFillColor(color)
        ..fillPath();

      if (surfaceOpacity != 1) {
        context.canvas.restoreContext();
      }
    }

    if (drawBorder) {
      for (final LineChartValue value in data) {
        _drawSurface(context, grid, value);
      }

      context.canvas
        ..setStrokeColor(borderColor ?? color)
        ..setLineWidth(borderWidth)
        ..strokePath();
    }
  }
}
