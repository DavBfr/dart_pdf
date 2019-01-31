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
  final double x, y, w, h;

  static const zero = PdfRect(0.0, 0.0, 0.0, 0.0);

  const PdfRect(this.x, this.y, this.w, this.h);

  factory PdfRect.fromLTRB(
      double left, double top, double right, double bottom) {
    return PdfRect(left, top, right - left, bottom - top);
  }

  factory PdfRect.fromPoints(PdfPoint offset, PdfPoint size) {
    return PdfRect(offset.x, offset.y, size.x, size.y);
  }

  double get l => x;
  double get b => y;
  double get r => x + w;
  double get t => y + h;

  @override
  String toString() => "PdfRect($x, $y, $w, $h)";

  PdfRect operator *(double factor) {
    return PdfRect(x * factor, y * factor, w * factor, h * factor);
  }

  PdfPoint get offset => PdfPoint(x, y);
  PdfPoint get size => PdfPoint(w, h);

  PdfPoint get topLeft => PdfPoint(x, y);
  PdfPoint get topRight => PdfPoint(r, y);
  PdfPoint get bottomLeft => PdfPoint(x, t);
  PdfPoint get bottomRight => PdfPoint(r, t);
}
