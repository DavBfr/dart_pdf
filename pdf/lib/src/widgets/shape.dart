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

import 'package:pdf/src/widgets/geometry.dart';
import 'package:pdf/src/pdf/point.dart';
import 'package:pdf/src/widgets/widget.dart';

import '../../pdf.dart';

class Circle extends Widget {
  Circle({this.fillColor, this.strokeColor, this.strokeWidth = 1.0});

  final PdfColor? fillColor;
  final PdfColor? strokeColor;
  final double strokeWidth;

  @override
  void layout(Context context, BoxConstraints constraints,
      {bool parentUsesSize = false}) {
    box = PdfRect.fromPoints(PdfPoint.zero, constraints.biggest);
  }

  @override
  void paint(Context context) {
    super.paint(context);

    final canvas = context.canvas;

    canvas.saveContext();

    if (fillColor != null) {
      canvas.setFillColor(fillColor!);
    }
    if (strokeColor != null) {
      canvas.setStrokeColor(strokeColor);
    }

    canvas.setLineWidth(strokeWidth);

    canvas.drawEllipse(
        box!.width / 2, box!.height / 2, box!.width / 2, box!.height / 2);

    if (strokeColor != null && fillColor != null) {
      canvas.fillAndStrokePath();
    } else if (strokeColor != null) {
      canvas.strokePath();
    } else {
      canvas.fillPath();
    }

    canvas.restoreContext();
  }
}

class Rectangle extends Widget {
  Rectangle({this.fillColor, this.strokeColor, this.strokeWidth = 1.0});

  final PdfColor? fillColor;
  final PdfColor? strokeColor;
  final double strokeWidth;

  @override
  void layout(Context context, BoxConstraints constraints,
      {bool parentUsesSize = false}) {
    box = PdfRect.fromPoints(PdfPoint.zero, constraints.biggest);
  }

  @override
  void paint(Context context) {
    super.paint(context);

    final canvas = context.canvas;

    canvas.saveContext();

    if (fillColor != null) {
      canvas.setFillColor(fillColor!);
    }
    if (strokeColor != null) {
      canvas.setStrokeColor(strokeColor);
    }

    canvas.setLineWidth(strokeWidth);

    canvas.drawRect(0, 0, box!.width, box!.height);

    if (strokeColor != null && fillColor != null) {
      canvas.fillAndStrokePath();
    } else if (strokeColor != null) {
      canvas.strokePath();
    } else {
      canvas.fillPath();
    }

    canvas.restoreContext();
  }
}

class Polygon extends Widget {
  Polygon(
      {required this.points,
      this.fillColor,
      this.strokeColor,
      this.strokeWidth = 1.0,
      this.close = true});

  final List<PdfPoint> points;
  final PdfColor? fillColor;
  final PdfColor? strokeColor;
  final double strokeWidth;
  final bool close;

  @override
  void layout(Context context, BoxConstraints constraints,
      {bool parentUsesSize = false}) {
    box = PdfRect.fromPoints(PdfPoint.zero, constraints.biggest);
  }

  @override
  void paint(Context context) {
    super.paint(context);

    // Make sure there are enough points to draw anything
    if (points.length < 3) {
      return;
    }

    final canvas = context.canvas;

    canvas.saveContext();

    if (fillColor != null) {
      canvas.setFillColor(fillColor!);
    }
    if (strokeColor != null) {
      canvas.setStrokeColor(strokeColor);
    }

    canvas.setLineWidth(strokeWidth);

    // Flip the points on the Y axis.
    final flippedPoints = points.map((e) => PdfPoint(e.x, box!.height - e.y)).toList();

    canvas.moveTo(flippedPoints[0].x, flippedPoints[0].y);
    for (var i = 0; i < flippedPoints.length; i++) {
      canvas.lineTo(flippedPoints[i].x, flippedPoints[i].y);
    }

    if (close) {
      canvas.closePath();
    }

    if (strokeColor != null && fillColor != null) {
      canvas.fillAndStrokePath();
    } else if (strokeColor != null) {
      canvas.strokePath();
    } else {
      canvas.fillPath();
    }

    canvas.restoreContext();
  }
}

class InkList extends Widget {
  InkList({required this.points, this.strokeColor, this.strokeWidth = 1.0});

  final List<List<PdfPoint>> points;
  final PdfColor? strokeColor;
  final double strokeWidth;

  @override
  void layout(Context context, BoxConstraints constraints,
      {bool parentUsesSize = false}) {
    box = PdfRect.fromPoints(PdfPoint.zero, constraints.biggest);
  }

  @override
  void paint(Context context) {
    super.paint(context);

    final canvas = context.canvas;

    canvas.saveContext();

    if (strokeColor != null) {
      canvas.setStrokeColor(strokeColor);
    }

    canvas.setLineWidth(strokeWidth);

    // Flip the points on the Y axis.

    for (var subLineIndex = 0; subLineIndex < points.length; subLineIndex++) {
      final flippedPoints = points[subLineIndex].map((e) => PdfPoint(e.x, box!.height - e.y)).toList();
      canvas.moveTo(flippedPoints[0].x, flippedPoints[0].y);
      for (var i = 0; i < flippedPoints.length; i++) {
        canvas.lineTo(flippedPoints[i].x, flippedPoints[i].y);
      }
    }

    canvas.strokePath();

    canvas.restoreContext();
  }
}
