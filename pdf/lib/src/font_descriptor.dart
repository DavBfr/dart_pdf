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

class PdfFontDescriptor extends PdfObject {
  final PdfObjectStream file;
  final PdfTtfFont ttfFont;

  PdfFontDescriptor(this.ttfFont, this.file)
      : super(ttfFont.pdfDocument, "/FontDescriptor");

  @override
  void _prepare() {
    super._prepare();

    params["/FontName"] = PdfStream.string(ttfFont.baseFont);
    params["/FontFile2"] = file.ref();
    params["/Flags"] = PdfStream.intNum(32);
    params["/FontBBox"] = PdfStream()
      ..putStringArray([
        ttfFont.font.xMin,
        ttfFont.font.yMin,
        ttfFont.font.xMax,
        ttfFont.font.yMax
      ]);
    params["/Ascent"] = PdfStream.intNum(ttfFont.font.ascent);
    params["/Descent"] = PdfStream.intNum(ttfFont.font.descent);
    params["/ItalicAngle"] = PdfStream.intNum(0);
    params["/CapHeight"] = PdfStream.intNum(10);
    params["/StemV"] = PdfStream.intNum(79);
  }
}
