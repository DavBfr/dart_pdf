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

class PdfType1Font extends PdfFont {
  /// The font's real name
  final String fontName;
  final double ascent;
  final double descent;
  final List<double> widths;

  /// Constructs a [PdfTtfFont]
  PdfType1Font._create(PdfDocument pdfDocument, this.fontName, this.ascent,
      this.descent, this.widths)
      : super._create(pdfDocument, subtype: "/Type1") {}

  /// @param os OutputStream to send the object to
  @override
  void _prepare() {
    super._prepare();

    params["/BaseFont"] = PdfStream.string("/" + fontName);
  }

  @override
  double glyphAdvance(int charCode) {
    if (charCode > widths.length) {
      return super.glyphAdvance(charCode);
    }

    return widths[charCode];
  }

  @override
  PdfRect glyphBounds(int charCode) {
    return PdfRect(0.0, descent, glyphAdvance(charCode), ascent);
  }
}
