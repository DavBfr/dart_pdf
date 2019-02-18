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

part of pdf;

@immutable
class PdfFontMetrics {
  const PdfFontMetrics(
      {@required this.left,
      @required this.top,
      @required this.right,
      @required this.bottom,
      double ascent,
      double descent,
      double advanceWidth})
      : ascent = ascent ?? bottom,
        descent = descent ?? top,
        advanceWidth = advanceWidth ?? right - left,
        assert(left != null),
        assert(top != null),
        assert(right != null),
        assert(bottom != null),
        assert(left <= right),
        assert(top <= bottom),
        assert((descent ?? top) <= (ascent ?? bottom));

  factory PdfFontMetrics.append(Iterable<PdfFontMetrics> metrics) {
    if (metrics.isEmpty) {
      return PdfFontMetrics.zero;
    }

    double left;
    double top;
    double right = 0.0;
    double bottom;
    double ascent;
    double descent;
    double lastBearing;

    for (PdfFontMetrics metric in metrics) {
      left ??= metric.left;
      right += metric.advanceWidth;
      lastBearing = metric.rightBearing;

      top = math.min(top ?? metric.top, metric.top);
      bottom = math.max(bottom ?? metric.bottom, metric.bottom);
      descent = math.min(descent ?? metric.descent, metric.descent);
      ascent = math.max(ascent ?? metric.ascent, metric.ascent);
    }

    return PdfFontMetrics(
        left: left,
        top: top,
        right: right - lastBearing,
        bottom: bottom,
        ascent: ascent,
        descent: descent,
        advanceWidth: right);
  }

  static const PdfFontMetrics zero =
      PdfFontMetrics(left: 0.0, top: 0.0, right: 0.0, bottom: 0.0);

  final double left;

  final double top;

  final double bottom;

  final double right;

  final double ascent;

  final double descent;

  final double advanceWidth;

  double get width => right - left;

  double get height => bottom - top;

  double get maxHeight => ascent - descent;

  double get maxWidth =>
      math.max(advanceWidth, right) + math.max(-leftBearing, 0.0);

  double get effectiveLeft => math.min(leftBearing, 0.0);

  double get leftBearing => left;

  double get rightBearing => advanceWidth - right;

  @override
  String toString() =>
      'PdfFontMetrics(left:$left, top:$top, right:$right, bottom:$bottom, ascent:$ascent, descent:$descent, advanceWidth:$advanceWidth)';

  PdfFontMetrics copyWith(
      {double left,
      double top,
      double right,
      double bottom,
      double ascent,
      double descent,
      double advanceWidth}) {
    return PdfFontMetrics(
        left: left ?? this.left,
        top: top ?? this.top,
        right: right ?? this.right,
        bottom: bottom ?? this.bottom,
        ascent: ascent ?? this.ascent,
        descent: descent ?? this.descent,
        advanceWidth: advanceWidth ?? this.advanceWidth);
  }

  PdfFontMetrics operator *(double factor) {
    return copyWith(
      left: left * factor,
      top: top * factor,
      right: right * factor,
      bottom: bottom * factor,
      ascent: ascent * factor,
      descent: descent * factor,
      advanceWidth: advanceWidth * factor,
    );
  }

  PdfRect toPdfRect() => PdfRect.fromLTRB(left, top, right, bottom);
}
