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

import 'geometry.dart';
import 'widget.dart';

class CircularProgressIndicator extends Widget {
  CircularProgressIndicator(
      {required this.value,
      this.color,
      this.strokeWidth = 4.0,
      this.backgroundColor});

  final double value;

  final PdfColor? color;

  final PdfColor? backgroundColor;

  final double strokeWidth;

  @override
  void layout(Context context, BoxConstraints constraints,
      {bool parentUsesSize = false}) {
    box = PdfRect.fromPoints(PdfPoint.zero, constraints.biggest);
  }

  @override
  void paint(Context context) {
    super.paint(context);

    final adjustedValue = value.clamp(0.00001, .99999);
    final rx = box!.width / 2;
    final ry = box!.height / 2;
    const angleStart = math.pi / 2;
    final angleEnd = angleStart - math.pi * 2 * adjustedValue;
    final startTop = PdfPoint(
      box!.x + rx + math.cos(angleStart) * rx,
      box!.y + ry + math.sin(angleStart) * ry,
    );
    final endTop = PdfPoint(
      box!.x + rx + math.cos(angleEnd) * rx,
      box!.y + ry + math.sin(angleEnd) * ry,
    );
    final startBottom = PdfPoint(
      box!.x + rx + math.cos(angleStart) * (rx - strokeWidth),
      box!.y + ry + math.sin(angleStart) * (ry - strokeWidth),
    );
    final endBottom = PdfPoint(
      box!.x + rx + math.cos(angleEnd) * (rx - strokeWidth),
      box!.y + ry + math.sin(angleEnd) * (ry - strokeWidth),
    );

    if (backgroundColor != null && value < 1) {
      context.canvas
        ..moveTo(startTop.x, startTop.y)
        ..bezierArc(startTop.x, startTop.y, rx, ry, endTop.x, endTop.y,
            large: adjustedValue < .5, sweep: true)
        ..lineTo(endBottom.x, endBottom.y)
        ..bezierArc(endBottom.x, endBottom.y, rx - strokeWidth,
            ry - strokeWidth, startBottom.x, startBottom.y,
            large: adjustedValue < .5)
        ..lineTo(startTop.x, startTop.y)
        ..setFillColor(backgroundColor)
        ..fillPath();
    }

    if (value > 0) {
      context.canvas
        ..moveTo(startTop.x, startTop.y)
        ..bezierArc(startTop.x, startTop.y, rx, ry, endTop.x, endTop.y,
            large: adjustedValue > .5)
        ..lineTo(endBottom.x, endBottom.y)
        ..bezierArc(endBottom.x, endBottom.y, rx - strokeWidth,
            ry - strokeWidth, startBottom.x, startBottom.y,
            large: adjustedValue > .5, sweep: true)
        ..lineTo(startTop.x, startTop.y)
        ..setFillColor(color ?? PdfColors.indigo)
        ..fillPath();
    }
  }
}
