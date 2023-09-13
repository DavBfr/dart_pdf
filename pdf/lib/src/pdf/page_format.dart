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

import 'point.dart';

class PdfPageFormat {
  const PdfPageFormat(this.width, this.height,
      {double marginTop = 0.0,
      double marginBottom = 0.0,
      double marginLeft = 0.0,
      double marginRight = 0.0,
      double? marginAll})
      : assert(width > 0),
        assert(height > 0),
        marginTop = marginAll ?? marginTop,
        marginBottom = marginAll ?? marginBottom,
        marginLeft = marginAll ?? marginLeft,
        marginRight = marginAll ?? marginRight;

  static const PdfPageFormat a3 =
      PdfPageFormat(29.7 * cm, 42 * cm, marginAll: 2.0 * cm);
  static const PdfPageFormat a4 =
      PdfPageFormat(21.0 * cm, 29.7 * cm, marginAll: 2.0 * cm);
  static const PdfPageFormat a5 =
      PdfPageFormat(14.8 * cm, 21.0 * cm, marginAll: 2.0 * cm);
  static const PdfPageFormat a6 =
      PdfPageFormat(105 * mm, 148 * mm, marginAll: 1.0 * cm);
  static const PdfPageFormat letter =
      PdfPageFormat(8.5 * inch, 11.0 * inch, marginAll: inch);
  static const PdfPageFormat legal =
      PdfPageFormat(8.5 * inch, 14.0 * inch, marginAll: inch);

  static const PdfPageFormat roll57 =
      PdfPageFormat(57 * mm, double.infinity, marginAll: 5 * mm);
  static const PdfPageFormat roll80 =
      PdfPageFormat(80 * mm, double.infinity, marginAll: 5 * mm);

  static const PdfPageFormat undefined =
      PdfPageFormat(double.infinity, double.infinity);

  static const PdfPageFormat standard = a4;

  static const double point = 1.0;
  static const double inch = 72.0;
  static const double cm = inch / 2.54;
  static const double mm = inch / 25.4;

  final double width;
  final double height;

  final double marginTop;
  final double marginBottom;
  final double marginLeft;
  final double marginRight;

  PdfPageFormat copyWith(
      {double? width,
      double? height,
      double? marginTop,
      double? marginBottom,
      double? marginLeft,
      double? marginRight}) {
    return PdfPageFormat(width ?? this.width, height ?? this.height,
        marginTop: marginTop ?? this.marginTop,
        marginBottom: marginBottom ?? this.marginBottom,
        marginLeft: marginLeft ?? this.marginLeft,
        marginRight: marginRight ?? this.marginRight);
  }

  /// Total page dimensions
  PdfPoint get dimension => PdfPoint(width, height);

  /// Total page width excluding margins
  double get availableWidth => width - marginLeft - marginRight;

  /// Total page height excluding margins
  double get availableHeight => height - marginTop - marginBottom;

  /// Total page dimensions excluding margins
  PdfPoint get availableDimension => PdfPoint(availableWidth, availableHeight);

  PdfPageFormat get landscape =>
      width >= height ? this : copyWith(width: height, height: width);

  PdfPageFormat get portrait =>
      height >= width ? this : copyWith(width: height, height: width);

  PdfPageFormat applyMargin({
    double? left,
    double? top,
    double? right,
    double? bottom,
  }) =>
      copyWith(
        marginLeft: left ?? marginLeft,
        marginTop: top ?? marginTop,
        marginRight: right ?? marginRight,
        marginBottom: bottom ?? marginBottom,
      );

  @override
  String toString() {
    return '$runtimeType ${width}x$height margins:$marginLeft, $marginTop, $marginRight, $marginBottom';
  }

  @override
  bool operator ==(Object other) {
    if (other is! PdfPageFormat) {
      return false;
    }

    return other.width == width &&
        other.height == height &&
        other.marginLeft == marginLeft &&
        other.marginTop == marginTop &&
        other.marginRight == marginRight &&
        other.marginBottom == marginBottom;
  }

  @override
  int get hashCode => toString().hashCode;
}
