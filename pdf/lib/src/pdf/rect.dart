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

import 'package:meta/meta.dart';

import 'point.dart';

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

  static const PdfRect zero = PdfRect(0, 0, 0, 0);

  double get left => x;

  double get bottom => y;

  double get right => x + width;

  double get top => y + height;

  @Deprecated('type => horizontalCenter')
  double get horizondalCenter => horizontalCenter;

  double get horizontalCenter => x + width / 2;

  double get verticalCenter => y + height / 2;

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

  /// Returns a new rectangle with edges moved outwards by the given delta.
  PdfRect inflate(double delta) {
    return PdfRect.fromLTRB(
        left - delta, top - delta, right + delta, bottom + delta);
  }

  /// Returns a new rectangle with edges moved inwards by the given delta.
  PdfRect deflate(double delta) => inflate(-delta);

  PdfRect copyWith({
    double? x,
    double? y,
    double? width,
    double? height,
  }) {
    return PdfRect(
      x ?? this.x,
      y ?? this.y,
      width ?? this.width,
      height ?? this.height,
    );
  }
}
