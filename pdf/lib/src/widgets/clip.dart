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

import 'package:vector_math/vector_math_64.dart';

import '../../pdf.dart';
import 'widget.dart';

class ClipRect extends SingleChildWidget {
  ClipRect({Widget? child}) : super(child: child);

  @override
  void debugPaint(Context context) {
    context.canvas
      ..setStrokeColor(PdfColors.deepPurple)
      ..setLineWidth(1)
      ..drawBox(box!)
      ..strokePath();
  }

  @override
  void paint(Context context) {
    super.paint(context);

    if (child != null) {
      final mat = Matrix4.identity();
      mat.translateByDouble(box!.left, box!.bottom, 0, 1);
      context.canvas
        ..saveContext()
        ..drawBox(box!)
        ..clipPath()
        ..setTransform(mat);
      child!.paint(context);
      context.canvas.restoreContext();
    }
  }
}

class ClipRRect extends SingleChildWidget {
  ClipRRect({
    Widget? child,
    this.horizontalRadius = 0,
    this.verticalRadius = 0,
  }) : super(child: child);

  final double horizontalRadius;
  final double verticalRadius;

  @override
  void debugPaint(Context context) {
    context.canvas
      ..setStrokeColor(PdfColors.deepPurple)
      ..setLineWidth(1)
      ..drawRRect(box!.left, box!.bottom, box!.width, box!.height,
          horizontalRadius, verticalRadius)
      ..strokePath();
  }

  @override
  void paint(Context context) {
    super.paint(context);

    if (child != null) {
      final mat = Matrix4.identity();
      mat.translateByDouble(box!.left, box!.bottom, 0, 1);
      context.canvas
        ..saveContext()
        ..drawRRect(box!.left, box!.bottom, box!.width, box!.height,
            horizontalRadius, verticalRadius)
        ..clipPath()
        ..setTransform(mat);
      child!.paint(context);
      context.canvas.restoreContext();
    }
  }
}

class ClipOval extends SingleChildWidget {
  ClipOval({Widget? child}) : super(child: child);

  @override
  void debugPaint(Context context) {
    final rx = box!.width / 2.0;
    final ry = box!.height / 2.0;

    context.canvas
      ..setStrokeColor(PdfColors.deepPurple)
      ..setLineWidth(1)
      ..drawEllipse(box!.left + rx, box!.bottom + ry, rx, ry)
      ..strokePath();
  }

  @override
  void paint(Context context) {
    super.paint(context);

    final rx = box!.width / 2.0;
    final ry = box!.height / 2.0;

    if (child != null) {
      final mat = Matrix4.identity();
      mat.translateByDouble(box!.left, box!.bottom, 0, 1);
      context.canvas
        ..saveContext()
        ..drawEllipse(box!.left + rx, box!.bottom + ry, rx, ry)
        ..clipPath()
        ..setTransform(mat);
      child!.paint(context);
      context.canvas.restoreContext();
    }
  }
}
