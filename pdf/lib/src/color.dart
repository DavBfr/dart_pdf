/*
 * Copyright (C) 2017, David PHAM-VAN <dev.nfet.net@gmail.com>
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General  License for more details.
 *
 * You should have received a copy of the GNU Lesser General
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

part of pdf;

class PdfColor {
  final double a;
  final double r;
  final double g;
  final double b;

  static var black = PdfColor(0.0, 0.0, 0.0);

  const PdfColor(this.r, this.g, this.b, [this.a = 1.0]);

  factory PdfColor.fromInt(int color) {
    return PdfColor((color >> 16 & 0xff) / 255.0, (color >> 8 & 0xff) / 255.0,
        (color & 0xff) / 255.0, (color >> 24 & 0xff) / 255.0);
  }

  factory PdfColor.fromHex(String color) {
    return PdfColor(
        (int.parse(color.substring(0, 1), radix: 16) >> 16 & 0xff) / 255.0,
        (int.parse(color.substring(2, 3), radix: 16) >> 8 & 0xff) / 255.0,
        (int.parse(color.substring(4, 5), radix: 16) & 0xff) / 255.0,
        (int.parse(color.substring(6, 7), radix: 16) >> 24 & 0xff) / 255.0);
  }

  int toInt() =>
      ((((a * 255.0).round() & 0xff) << 24) |
          (((r * 255.0).round() & 0xff) << 16) |
          (((g * 255.0).round() & 0xff) << 8) |
          (((b * 255.0).round() & 0xff) << 0)) &
      0xFFFFFFFF;
}
