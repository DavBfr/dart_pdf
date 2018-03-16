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

class PDFFont extends PDFObject {
  /// The PDF type of the font, usually /Type1
  final String subtype;

  /// The font's real name
  String baseFont;

  /// Constructs a PDFFont. This will attempt to map the font from a known
  /// Java font name to that in PDF, defaulting to Helvetica if not possible.
  ///
  /// @param name The document name, ie /F1
  /// @param type The pdf type, ie /Type1
  /// @param font The font name, ie Helvetica
  /// @param style The java.awt.Font style, ie: Font.PLAIN
  PDFFont(PDFDocument pdfDocument, {this.subtype = "/Type1", this.baseFont = "/Helvetica"}) : super(pdfDocument, "/Font") {
    pdfDocument.fonts.add(this);
  }

  String get name => "/F$objser";

  /// @param os OutputStream to send the object to
  @override
  void prepare() {
    super.prepare();

    params["/Subtype"] = PDFStream.string(subtype);
    params["/Name"] = PDFStream.string(name);
    params["/BaseFont"] = PDFStream.string(baseFont);
    params["/Encoding"] = PDFStream.string("/WinAnsiEncoding");
  }

  double glyphAdvance(int charCode) {
    return 0.454;
  }

  PDFRect glyphBounds(int charCode) {
    return const PDFRect(0.0, 0.0, 0.4, 1.0);
  }

  PDFRect stringBounds(String s) {
    var chars = LATIN1.encode(s);

    if (chars.length == 0) return const PDFRect(0.0, 0.0, 0.0, 0.0);

    var n = 0;
    var c = chars[n];
    var r = glyphBounds(c);
    var x = r.x;
    var y = r.y;
    var h = r.h;
    var w = n == chars.length - 1 ? r.w : glyphAdvance(c);

    while (++n < chars.length) {
      c = chars[n];
      r = glyphBounds(c);
      if (r.y < y) y = r.y;
      if (r.h > h) h = r.h;
      w += n == chars.length - 1 ? r.w : glyphAdvance(c);
    }

    return new PDFRect(x, y, w, h);
  }

  PDFPoint stringSize(String s) {
    var chars = LATIN1.encode(s);

    var w = 0.0;
    var h = 0.0;

    for (var c in chars) {
      var r = glyphBounds(c);
      if (r.h > h) h = r.h;
      w += glyphAdvance(c);
    }

    return new PDFPoint(w, h);
  }
}
