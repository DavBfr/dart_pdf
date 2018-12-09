/*
 * Copyright (C) 2017, David PHAM-VAN <dev.nfet.net@gmail.com>
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

part of pdf;

class PdfPageFormat {
  static const a4 = PdfPageFormat(595.28, 841.89);
  static const a3 = PdfPageFormat(841.89, 1190.55);
  static const a5 = PdfPageFormat(420.94, 595.28);
  static const letter = PdfPageFormat(612.0, 792.0);
  static const legal = PdfPageFormat(612.0, 1008.0);

  static const point = 1.0;
  static const inch = 72.0;
  static const cm = inch / 2.54;
  static const mm = inch / 25.4;

  final double width;
  final double height;

  const PdfPageFormat(this.width, this.height);

  PdfPoint get dimension => PdfPoint(width, height);

  PdfPageFormat get landscape =>
      width >= height ? this : PdfPageFormat(height, width);

  PdfPageFormat get portrait =>
      height >= width ? this : PdfPageFormat(height, width);

  @override
  String toString() {
    return "${width}x$height";
  }
}
