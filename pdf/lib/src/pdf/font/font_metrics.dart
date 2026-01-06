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

import '../point.dart';
import '../rect.dart';

/// Describe dimensions for glyphs in a font
@immutable
class PdfFontMetrics {
  /// Create a PdfFontMetrics object
  const PdfFontMetrics({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    double? ascent,
    double? descent,
    double? advanceWidth,
    double? leftBearing,
  })  : ascent = ascent ?? bottom,
        descent = descent ?? top,
        advanceWidth = advanceWidth ?? right - left,
        leftBearing = leftBearing ?? left;

  /// Add another metric
  factory PdfFontMetrics.append(
    Iterable<PdfFontMetrics> metrics, {
    double letterSpacing = 0,
  }) {
    if (metrics.isEmpty) {
      return PdfFontMetrics.zero;
    }

    double? left;
    double? top;
    var right = 0.0;
    double? bottom;
    double? ascent;
    double? descent;
    late double lastBearing;
    double? firstBearing;
    late double spacing;

    for (final metric in metrics) {
      firstBearing ??= metric.leftBearing;
      left ??= metric.left;
      spacing = metric.advanceWidth > 0 ? letterSpacing : 0.0;
      right += metric.advanceWidth + spacing;
      lastBearing = metric.rightBearing;

      top = math.min(top ?? metric.top, metric.top);
      bottom = math.max(bottom ?? metric.bottom, metric.bottom);
      descent = math.min(descent ?? metric.descent, metric.descent);
      ascent = math.max(ascent ?? metric.ascent, metric.ascent);
    }

    return PdfFontMetrics(
      left: left!,
      top: top!,
      right: right - lastBearing - spacing,
      bottom: bottom!,
      ascent: ascent,
      descent: descent,
      advanceWidth: right - spacing,
      leftBearing: firstBearing,
    );
  }

  /// Zero-sized dimensions
  static const PdfFontMetrics zero =
      PdfFontMetrics(left: 0, top: 0, right: 0, bottom: 0);

  /// Left most of the bounding box
  final double left;

  /// Top most of the bounding box
  final double top;

  /// Bottom most of the bounding box
  final double bottom;

  /// Right most of the bounding box
  final double right;

  /// Spans the distance between the baseline and the top of the glyph that
  /// reaches farthest from the baseline
  final double ascent;

  /// Spans the distance between the baseline and the lowest descending glyph
  final double descent;

  /// distance to move right to draw the next glyph
  final double advanceWidth;

  /// Width of the glyph
  double get width => right - left;

  /// Height of the glyph
  double get height => bottom - top;

  /// Maximum Width any glyph from this font can have
  double get maxWidth =>
      math.max(advanceWidth, right) + math.max(-leftBearing, 0.0);

  /// Maximum Height any glyph from this font can have
  double get maxHeight => ascent - descent;

  /// Real left position. The glyph may overflow on the left
  double get effectiveLeft => math.min(leftBearing, 0);

  /// Starting point
  final double leftBearing;

  /// Ending point
  double get rightBearing => advanceWidth - right;

  /// Get the unit size of this string
  PdfPoint get size => PdfPoint(width, height);

  @override
  String toString() =>
      'PdfFontMetrics(left:$left, top:$top, right:$right, bottom:$bottom, ascent:$ascent, descent:$descent, advanceWidth:$advanceWidth, leftBearing:$leftBearing, rightBearing:$rightBearing)';

  /// Make a copy of this object
  PdfFontMetrics copyWith({
    double? left,
    double? top,
    double? right,
    double? bottom,
    double? ascent,
    double? descent,
    double? advanceWidth,
    double? leftBearing,
  }) {
    return PdfFontMetrics(
      left: left ?? this.left,
      top: top ?? this.top,
      right: right ?? this.right,
      bottom: bottom ?? this.bottom,
      ascent: ascent ?? this.ascent,
      descent: descent ?? this.descent,
      advanceWidth: advanceWidth ?? this.advanceWidth,
      leftBearing: leftBearing ?? this.leftBearing,
    );
  }

  /// Multiply this metrics object with a font size
  PdfFontMetrics operator *(double factor) {
    return copyWith(
      left: left * factor,
      top: top * factor,
      right: right * factor,
      bottom: bottom * factor,
      ascent: ascent * factor,
      descent: descent * factor,
      advanceWidth: advanceWidth * factor,
      leftBearing: leftBearing * factor,
    );
  }

  /// Get the bounding box
  PdfRect toPdfRect() => PdfRect.fromLBRT(left, top, right, bottom);
}
