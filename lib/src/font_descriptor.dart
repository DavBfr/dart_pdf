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

class PDFFontDescriptor extends PDFObject {
  final PDFObjectStream file;
  final TtfFont font;
  final PDFTTFFont ttfFont;

  PDFFontDescriptor(this.ttfFont, this.file, this.font)
      : super(ttfFont.pdfDocument, "/FontDescriptor");

  @override
  void prepare() {
    super.prepare();

    params["/FontName"] = PDFStream.string(ttfFont.baseFont);
    params["/FontFile2"] = file.ref();
    params["/Flags"] = PDFStream.intNum(32);
    params["/FontBBox"] = new PDFStream()
      ..putStringArray([font.head.xMin, font.head.yMin, font.head.xMax, font.head.yMax]);
    params["/Ascent"] = PDFStream.intNum(font.hhea.ascent);
    params["/Descent"] = PDFStream.intNum(font.hhea.descent);
    params["/ItalicAngle"] = PDFStream.intNum(0);
    params["/CapHeight"] = PDFStream.intNum(10);
    params["/StemV"] = PDFStream.intNum(79);
  }
}
