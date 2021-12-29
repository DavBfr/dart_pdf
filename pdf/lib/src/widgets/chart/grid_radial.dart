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

import 'package:meta/meta.dart';
import 'package:pdf/pdf.dart';

import '../geometry.dart';
import '../widget.dart';
import 'chart.dart';

@experimental
class RadialGrid extends ChartGrid {
  RadialGrid();

  late PdfRect gridBox;

  @override
  void layout(Context context, BoxConstraints constraints,
      {bool parentUsesSize = false}) {
    super.layout(context, constraints, parentUsesSize: parentUsesSize);

    final datasets = Chart.of(context).datasets;
    final size = constraints.biggest;

    gridBox = PdfRect(0, 0, size.x, size.y);

    for (final dataset in datasets) {
      dataset.layout(context, BoxConstraints.tight(gridBox.size));
    }
  }

  @override
  PdfPoint toChart(PdfPoint p) {
    const z = 3.0;
    return PdfPoint(
      z * p.y * math.cos(p.x / 7 * math.pi * 2) + gridBox.width / 2,
      z * p.y * math.sin(p.x / 7 * math.pi * 2) + gridBox.height / 2,
    );
  }

  void paintBackground(Context context) {}

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
    for (final dataSet in datasets) {
      dataSet.paintBackground(context);
    }
    context.canvas.restoreContext();
    paintBackground(context);
    clip(context, box!.size);
    for (final dataSet in datasets) {
      dataSet.paint(context);
    }
    context.canvas.restoreContext();
  }
}
