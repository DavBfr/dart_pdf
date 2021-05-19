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

import 'package:pdf/pdf.dart';

import '../flex.dart';
import '../geometry.dart';
import '../widget.dart';
import 'chart.dart';
import 'grid_axis.dart';

class CartesianGrid extends ChartGrid {
  CartesianGrid({
    required GridAxis xAxis,
    required GridAxis yAxis,
  })  : _xAxis = xAxis..direction = Axis.horizontal,
        _yAxis = yAxis..direction = Axis.vertical;

  final GridAxis _xAxis;
  final GridAxis _yAxis;

  late PdfRect gridBox;

  @override
  void layout(Context context, BoxConstraints constraints,
      {bool parentUsesSize = false}) {
    super.layout(context, constraints, parentUsesSize: parentUsesSize);

    final datasets = Chart.of(context).datasets;
    final size = constraints.biggest;

    // In simple conditions, this loop will run only 2 times.
    var count = 5;
    while (count-- > 0) {
      _xAxis.crossAxisPosition = _yAxis.axisPosition;
      _xAxis.axisPosition =
          math.max(_xAxis.axisPosition, _yAxis.crossAxisPosition);
      _xAxis.layout(context, constraints);
      assert(_xAxis.box != null);
      _yAxis.crossAxisPosition = _xAxis.axisPosition;
      _yAxis.axisPosition =
          math.max(_yAxis.axisPosition, _xAxis.crossAxisPosition);
      _yAxis.layout(context, constraints);
      assert(_yAxis.box != null);
      if (_yAxis.crossAxisPosition == _xAxis.axisPosition &&
          _xAxis.crossAxisPosition == _yAxis.axisPosition) {
        break;
      }
    }

    final width = _yAxis.axisPosition;
    final height = _xAxis.axisPosition;
    gridBox = PdfRect(width, height, size.x - width, size.y - height);

    for (final dataset in datasets) {
      dataset.layout(context, BoxConstraints.tight(gridBox.size));
      dataset.box =
          PdfRect.fromPoints(PdfPoint(width, height), dataset.box!.size);
    }
  }

  @override
  PdfPoint toChart(PdfPoint p) {
    return PdfPoint(
      _xAxis.toChart(p.x),
      _yAxis.toChart(p.y),
    );
  }

  double get xAxisOffset => _xAxis.axisPosition;

  double get yAxisOffset => _yAxis.axisPosition;

  void paintBackground(Context context) {
    _xAxis.paintBackground(context);
    _yAxis.paintBackground(context);
  }

  void clip(Context context, PdfPoint size) {
    context.canvas
      ..saveContext()
      ..drawBox(gridBox)
      ..clipPath();
  }

  @override
  void paint(Context context) {
    super.paint(context);

    final datasets = Chart.of(context).datasets;

    clip(context, box!.size);
    for (var dataSet in datasets) {
      dataSet.paintBackground(context);
    }
    context.canvas.restoreContext();
    paintBackground(context);
    clip(context, box!.size);
    for (var dataSet in datasets) {
      dataSet.paint(context);
    }
    context.canvas.restoreContext();
    _xAxis.paint(context);
    _yAxis.paint(context);
  }
}
