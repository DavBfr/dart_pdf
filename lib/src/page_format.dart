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
  static const A4 = const PDFPageFormat(595.28, 841.89);
  static const A3 = const PDFPageFormat(841.89, 1190.55);
  static const A5 = const PDFPageFormat(420.94, 595.28);
  static const LETTER = const PDFPageFormat(612.0, 792.0);
  static const LEGAL = const PDFPageFormat(612.0, 1008.0);

  static const PT = 1.0;
  static const IN = 72.0;
  static const CM = IN / 2.54;
  static const MM = IN / 25.4;

  final double width;
  final double height;

  const PDFPageFormat(this.width, this.height);
}
