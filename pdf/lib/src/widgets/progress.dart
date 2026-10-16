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

import '../../pdf.dart';
import 'geometry.dart';
import 'widget.dart';

class CircularProgressIndicator extends Widget {
  CircularProgressIndicator({
    required this.value,
    this.color,
    this.strokeWidth = 4.0,
    this.backgroundColor,
    this.fallbackWidth,
    this.fallbackHeight,
  });

  /// The value of this progress indicator.
  /// A value of 0.0 means no progress and 1.0 means that progress is complete.
  final double value;

  /// The progress indicator's color
  final PdfColor? color;

  /// The progress indicator's background color.
  final PdfColor? backgroundColor;

  final double strokeWidth;

  /// The size to take on an axis the parent leaves unbounded.
  final double? fallbackWidth;

  /// The size to take on an axis the parent leaves unbounded.
  final double? fallbackHeight;

  @override
  void layout(
    Context context,
    BoxConstraints constraints, {
    bool parentUsesSize = false,
  }) {
    // constraints.biggest is infinite on an unbounded axis, which is exactly what
    // a non-flex child of a Row is given. The infinite radius then reached
    // .ceil() in the arc and threw 'Unsupported operation: Infinity or NaN
    // toInt'.
    box = PdfRect.fromPoints(
      PdfPoint.zero,
      PdfPoint(
        _bounded(
          constraints.hasBoundedWidth,
          constraints.maxWidth,
          fallbackWidth,
          'width',
        ),
        _bounded(
          constraints.hasBoundedHeight,
          constraints.maxHeight,
          fallbackHeight,
          'height',
        ),
      ),
    );
  }

  double _bounded(
    bool bounded,
    double maximum,
    double? fallback,
    String axis,
  ) => bounded
      ? maximum
      : (fallback ??
            (throw PdfException(
              'CircularProgressIndicator has an unbounded $axis. Give it a '
              'fallback${axis[0].toUpperCase()}${axis.substring(1)}, or a '
              'parent that constrains it.',
            )));

  @override
  void paint(Context context) {
    super.paint(context);

    final adjustedValue = value.clamp(0.00001, .99999);
    final rx = box!.width / 2;
    final ry = box!.height / 2;
    const angleStart = math.pi / 2;
    final angleEnd = angleStart - math.pi * 2 * adjustedValue;
    final startTop = PdfPoint(
      box!.left + rx + math.cos(angleStart) * rx,
      box!.bottom + ry + math.sin(angleStart) * ry,
    );
    final endTop = PdfPoint(
      box!.left + rx + math.cos(angleEnd) * rx,
      box!.bottom + ry + math.sin(angleEnd) * ry,
    );
    final startBottom = PdfPoint(
      box!.left + rx + math.cos(angleStart) * (rx - strokeWidth),
      box!.bottom + ry + math.sin(angleStart) * (ry - strokeWidth),
    );
    final endBottom = PdfPoint(
      box!.left + rx + math.cos(angleEnd) * (rx - strokeWidth),
      box!.bottom + ry + math.sin(angleEnd) * (ry - strokeWidth),
    );

    if (backgroundColor != null && value < 1) {
      context.canvas
        ..moveTo(startTop.x, startTop.y)
        ..bezierArc(
          startTop.x,
          startTop.y,
          rx,
          ry,
          endTop.x,
          endTop.y,
          large: adjustedValue < .5,
          sweep: true,
        )
        ..lineTo(endBottom.x, endBottom.y)
        ..bezierArc(
          endBottom.x,
          endBottom.y,
          rx - strokeWidth,
          ry - strokeWidth,
          startBottom.x,
          startBottom.y,
          large: adjustedValue < .5,
        )
        ..lineTo(startTop.x, startTop.y)
        ..setFillColor(backgroundColor)
        ..fillPath();
    }

    if (value > 0) {
      context.canvas
        ..moveTo(startTop.x, startTop.y)
        ..bezierArc(
          startTop.x,
          startTop.y,
          rx,
          ry,
          endTop.x,
          endTop.y,
          large: adjustedValue > .5,
        )
        ..lineTo(endBottom.x, endBottom.y)
        ..bezierArc(
          endBottom.x,
          endBottom.y,
          rx - strokeWidth,
          ry - strokeWidth,
          startBottom.x,
          startBottom.y,
          large: adjustedValue > .5,
          sweep: true,
        )
        ..lineTo(startTop.x, startTop.y)
        ..setFillColor(color ?? PdfColors.indigo)
        ..fillPath();
    }
  }
}

/// A material design linear progress indicator, also known as a progress bar.
class LinearProgressIndicator extends Widget {
  /// Creates a linear progress indicator.
  LinearProgressIndicator({
    required this.value,
    this.backgroundColor,
    this.valueColor,
    this.minHeight,
    this.fallbackWidth,
  });

  /// The progress indicator's background color.
  final PdfColor? backgroundColor;

  /// The minimum height of the line used to draw the indicator.
  final double? minHeight;

  /// The value of this progress indicator.
  /// A value of 0.0 means no progress and 1.0 means that progress is complete.
  final double value;

  /// The progress indicator's color
  final PdfColor? valueColor;

  /// The width to take when the parent leaves the width unbounded.
  final double? fallbackWidth;

  @override
  void layout(
    Context context,
    BoxConstraints constraints, {
    bool parentUsesSize = false,
  }) {
    // The width used to be `minWidth: double.infinity` as an 'as wide as
    // possible' sentinel, and BoxConstraints.enforce keeps that infinity when the
    // incoming maxWidth is unbounded - which is what a non-flex child of a Row
    // gets. The stream then carried 'Infinity 4.936 Infinity 4 re'.
    final width = constraints.hasBoundedWidth
        ? constraints.maxWidth
        : (fallbackWidth ??
              (throw PdfException(
                'LinearProgressIndicator has an unbounded width. Give it a '
                'fallbackWidth, or a parent that constrains it.',
              )));

    box = PdfRect.fromPoints(
      PdfPoint.zero,
      BoxConstraints(
        minWidth: width,
        maxWidth: width,
        minHeight: minHeight ?? 4.0,
      ).enforce(constraints).smallest,
    );
  }

  @override
  void paint(Context context) {
    super.paint(context);

    final vc = value.clamp(0.0, 1.0);
    final _valueColor = valueColor ?? PdfColors.blue;
    final _backgroundColor = backgroundColor ?? _valueColor.shade(0.1);

    if (vc < 1.0) {
      final epsilon = vc == 0 ? 0 : 0.01;
      context.canvas
        ..drawRect(
          box!.left + box!.width * vc - epsilon,
          box!.bottom,
          box!.width * (1 - vc) + epsilon,
          box!.height,
        )
        ..setFillColor(_backgroundColor)
        ..fillPath();
    }

    if (vc > 0.0) {
      context.canvas
        ..drawRect(box!.left, box!.bottom, box!.width * vc, box!.height)
        ..setFillColor(_valueColor)
        ..fillPath();
    }
  }
}
