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

@immutable
abstract class ChartValue {
  const ChartValue();
}

abstract class DataSet {
  void paintBackground(Context context, ChartGrid grid);
  void paintForeground(Context context, ChartGrid grid);
}
