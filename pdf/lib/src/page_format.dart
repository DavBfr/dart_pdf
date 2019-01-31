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

class PdfPageFormat {
  static const a3 = PdfPageFormat(29.7 * cm, 42 * cm, marginAll: 2.0 * cm);
  static const a4 = PdfPageFormat(21.0 * cm, 29.7 * cm, marginAll: 2.0 * cm);
  static const a5 = PdfPageFormat(14.8 * cm, 21.0 * cm, marginAll: 2.0 * cm);
  static const letter = PdfPageFormat(8.5 * inch, 11.0 * inch, marginAll: inch);
  static const legal = PdfPageFormat(8.5 * inch, 14.0 * inch, marginAll: inch);

  static const point = 1.0;
  static const inch = 72.0;
  static const cm = inch / 2.54;
  static const mm = inch / 25.4;

  final double width;
  final double height;

  final double marginTop;
  final double marginBottom;
  final double marginLeft;
  final double marginRight;

  const PdfPageFormat(this.width, this.height,
      {double marginTop = 0.0,
      double marginBottom = 0.0,
      double marginLeft = 0.0,
      double marginRight = 0.0,
      double marginAll})
      : marginTop = marginAll ?? marginTop,
        marginBottom = marginAll ?? marginBottom,
        marginLeft = marginAll ?? marginLeft,
        marginRight = marginAll ?? marginRight;

  PdfPageFormat copyWith(
      {double width,
      double height,
      double marginTop,
      double marginBottom,
      double marginLeft,
      double marginRight}) {
    return PdfPageFormat(width ?? this.width, height ?? this.height,
        marginTop: marginTop ?? this.marginTop,
        marginBottom: marginBottom ?? this.marginBottom,
        marginLeft: marginLeft ?? this.marginLeft,
        marginRight: marginRight ?? this.marginRight);
  }

  PdfPoint get dimension => PdfPoint(width, height);

  PdfPageFormat get landscape =>
      width >= height ? this : copyWith(width: height, height: width);

  PdfPageFormat get portrait =>
      height >= width ? this : copyWith(width: height, height: width);

  @override
  String toString() {
    return "${width}x$height";
  }
}
