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

class PDFPageFormat {
  static const A4 = const [595.28, 841.89];
  static const A3 = const [841.89, 1190.55];
  static const A5 = const [420.94, 595.28];
  static const LETTER = const [612.0, 792.0];
  static const LEGAL = const [612.0, 1008.0];

  static const PT = 1.0;
  static const IN = 72.0;
  static const CM = IN / 2.54;
  static const MM = IN / 25.4;

  double width;
  double height;
  double imageableX = 10.0;
  double imageableY = 10.0;
  double imageableWidth = 300.0;
  double imageableHeight = 300.0;
  int orientation = 0;

  PDFPageFormat([List<double> format]) {
    if (format == null || format.length != 2) format = A4;

    width = format[0];
    height = format[1];
  }

  double getWidth() => width;
  double getHeight() => height;

  void setOrientation(int orientation) {
    this.orientation = orientation;
  }

  int getOrientation() => orientation;
}
