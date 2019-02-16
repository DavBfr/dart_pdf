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
class PdfRect {
  const PdfRect(this.x, this.y, this.width, this.height);

  factory PdfRect.fromLTRB(
      double left, double top, double right, double bottom) {
    return PdfRect(left, top, right - left, bottom - top);
  }

  factory PdfRect.fromPoints(PdfPoint offset, PdfPoint size) {
    return PdfRect(offset.x, offset.y, size.x, size.y);
  }

  final double x, y, width, height;

  static const PdfRect zero = PdfRect(0.0, 0.0, 0.0, 0.0);

  double get left => x;
  double get bottom => y;
  double get right => x + width;
  double get top => y + height;

  @deprecated
  double get l => left;
  @deprecated
  double get b => bottom;
  @deprecated
  double get r => right;
  @deprecated
  double get t => top;
  @deprecated
  double get w => width;
  @deprecated
  double get h => height;

  @override
  String toString() => 'PdfRect($x, $y, $width, $height)';

  PdfRect operator *(double factor) {
    return PdfRect(x * factor, y * factor, width * factor, height * factor);
  }

  PdfPoint get offset => PdfPoint(x, y);
  PdfPoint get size => PdfPoint(width, height);

  PdfPoint get topLeft => PdfPoint(x, y);
  PdfPoint get topRight => PdfPoint(right, y);
  PdfPoint get bottomLeft => PdfPoint(x, top);
  PdfPoint get bottomRight => PdfPoint(right, top);
}
