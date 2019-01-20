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

  static const black = PdfColor(0.0, 0.0, 0.0);
  static const white = PdfColor(1.0, 1.0, 1.0);
  static const red = PdfColor(0.95686, 0.26274, 0.21176);
  static const pink = PdfColor(0.91372, 0.11764, 0.38823);
  static const purple = PdfColor(0.91372, 0.11764, 0.38823);
  static const deepPurple = PdfColor(0.40392, 0.22745, 0.71765);
  static const indigo = PdfColor(0.24705, 0.31765, 0.70980);
  static const blue = PdfColor(0.12941, 0.58823, 0.95294);
  static const lightBlue = PdfColor(0.01176, 0.66274, 0.95686);
  static const cyan = PdfColor(0.0, 0.73725, 0.83137);
  static const teal = PdfColor(0.0, 0.58823, 0.53333);
  static const green = PdfColor(0.29803, 0.68627, 0.31372);
  static const lightGreen = PdfColor(0.54509, 0.76470, 0.29020);
  static const lime = PdfColor(0.80392, 0.86274, 0.22353);
  static const yellow = PdfColor(1.0, 0.92157, 0.23137);
  static const amber = PdfColor(1.0, 0.75686, 0.02745);
  static const orange = PdfColor(1.0, 0.59608, 0.0);
  static const deepOrange = PdfColor(1.0, 0.34118, 0.13333);
  static const brown = PdfColor(0.47451, 0.33333, 0.28235);
  static const grey = PdfColor(0.61961, 0.61961, 0.61961);
  static const blueGrey = PdfColor(0.37647, 0.49020, 0.54510);

  const PdfColor(this.r, this.g, this.b, [this.a = 1.0]);

  const PdfColor.fromInt(int color)
      : r = (color >> 16 & 0xff) / 255.0,
        g = (color >> 8 & 0xff) / 255.0,
        b = (color & 0xff) / 255.0,
        a = (color >> 24 & 0xff) / 255.0;

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

  String toString() => "$runtimeType($r, $g, $b, $a)";
}
