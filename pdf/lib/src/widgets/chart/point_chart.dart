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
import '../basic.dart';
import '../geometry.dart';
import '../widget.dart';
import 'chart.dart';

enum ValuePosition { left, top, right, bottom, auto }

typedef LegendBuildCallback = Widget Function(Context context);

class PointChartValue extends ChartValue {
  const PointChartValue(this.x, this.y);
  final double x;
  final double y;

  PdfPoint get point => PdfPoint(x, y);
}

class PointDataSet<T extends PointChartValue> extends Dataset {
  PointDataSet({
    required this.data,
    String? legend,
    this.pointSize = 3,
    PdfColor color = PdfColors.blue,
    PdfColor? borderColor,
    double borderWidth = 1.5,
    this.drawPoints = true,
    this.shape,
    this.buildValue,
    this.valuePosition = ValuePosition.auto,
  }) : super(
          legend: legend,
          color: color,
          borderColor: borderColor,
          borderWidth: borderWidth,
        );

  final List<T> data;

  final bool drawPoints;

  final double pointSize;

  final LegendBuildCallback? shape;

  final Widget Function(Context context, T value)? buildValue;

  final ValuePosition valuePosition;

  double get delta => pointSize * .5;

  @override
  void layout(Context context, BoxConstraints constraints,
      {bool parentUsesSize = false}) {
    box = PdfRect.fromPoints(PdfPoint.zero, constraints.biggest);
  }

  ValuePosition automaticValuePosition(
    PdfPoint point,
    PdfPoint size,
    PdfPoint? previous,
    PdfPoint? next,
  ) {
    // Usually on top, except on the edges

    if (point.x - size.x / 2 < box!.left) {
      return ValuePosition.right;
    }

    if (point.x + size.x / 2 > box!.right) {
      return ValuePosition.left;
    }

    if (point.y + size.y + delta > box!.top) {
      return ValuePosition.bottom;
    }

    return ValuePosition.top;
  }

  @override
  Future<void> paintForeground(Context context) async {
    super.paintForeground(context);

    if (data.isEmpty) {
      return;
    }

    final grid = Chart.of(context).grid;

    if (drawPoints) {
      if (shape == null) {
        for (final value in data) {
          final p = grid.toChart(value.point);
          context.canvas.drawEllipse(p.x, p.y, pointSize, pointSize);
        }

        context.canvas
          ..setColor(color)
          ..fillPath();
      } else {
        for (final value in data) {
          final p = grid.toChart(value.point);

          Widget.draw(
            SizedBox.square(
              dimension: pointSize * 2,
              child: await shape!(context),
            ),
            offset: p,
            alignment: Alignment.center,
            context: context,
          );
        }
      }
    }

    if (buildValue != null) {
      PdfPoint? previous;
      var index = 1;

      for (final value in data) {
        final p = grid.toChart(value.point);

        final size = Widget.measure(
          buildValue!(context, value),
          context: context,
        );

        final PdfPoint offset;
        var pos = valuePosition;
        if (pos == ValuePosition.auto) {
          final next =
              index < data.length ? grid.toChart(data[index++].point) : null;
          pos = automaticValuePosition(p, size, previous, next);
        }

        switch (pos) {
          case ValuePosition.left:
            offset = PdfPoint(p.x - size.x / 2 - pointSize - delta, p.y);
            break;
          case ValuePosition.top:
            offset = PdfPoint(p.x, p.y + size.y / 2 + pointSize + delta);
            break;
          case ValuePosition.right:
            offset = PdfPoint(p.x + size.x / 2 + pointSize + delta, p.y);
            break;
          case ValuePosition.bottom:
            offset = PdfPoint(p.x, p.y - size.y / 2 - pointSize - delta);
            break;
          case ValuePosition.auto:
            assert(false, 'We have an issue here');
            offset = p;
            break;
        }

        Widget.draw(
          buildValue!(context, value),
          offset: offset,
          alignment: Alignment.center,
          context: context,
        );

        previous = p;
      }
    }
  }

  @override
  Widget legendShape(Context context) {
    return shape == null ? super.legendShape(context) : shape!(context);
  }
}
