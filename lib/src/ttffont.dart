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

class PDFTTFFont extends PDFFont {
  PDFObject unicodeCMap;
  PDFFontDescriptor descriptor;
  PDFArrayObject widthsObject;
  final widths = new List<String>();
  TtfFont _font;
  int _charMin;
  int _charMax;

  /// Constructs a PDFTTFFont
  PDFTTFFont(PDFDocument pdfDocument, Uint8List bytes)
      : super(pdfDocument, subtype: "/TrueType") {
    _font = new TtfParser().parse(bytes);
    baseFont = "/" + _font.name.fontName.replaceAll(" ", "");

    PDFObjectStream file = new PDFObjectStream(pdfDocument, isBinary: true);
    file.buf.putBytes(bytes);
    file.params["/Length1"] = PDFStream.intNum(bytes.length);

    _charMin = 32;
    _charMax = 255;

    for (var i = _charMin; i <= _charMax; i++) {
      widths.add((glyphAdvance(i) * 1000.0).toString());
    }

    unicodeCMap = new PDFObject(pdfDocument);
    descriptor = new PDFFontDescriptor(this, file, _font);
    widthsObject = new PDFArrayObject(pdfDocument, widths);
  }

  @override
  double glyphAdvance(int charCode) {
    var g = _font.cmap.charToGlyphIndexMap[charCode];

    if (g == null) {
      return super.glyphAdvance(charCode);
    }

    return _font.hmtx.metrics[g].advanceWidth / _font.head.unitsPerEm;
  }

  @override
  PDFRect glyphBounds(int charCode) {
    var g = _font.cmap.charToGlyphIndexMap[charCode];

    if (g == null) {
      return super.glyphBounds(charCode);
    }

    var info = _font.glyf.glyphInfoMap[g];
    return new PDFRect(
        info.xMin.toDouble() / _font.head.unitsPerEm,
        info.yMin.toDouble() / _font.head.unitsPerEm,
        (info.xMax - info.xMin).toDouble() / _font.head.unitsPerEm,
        (info.yMax - info.yMin).toDouble() / _font.head.unitsPerEm);
  }

  @override
  void prepare() {
    super.prepare();

    params["/FirstChar"] = PDFStream.intNum(_charMin);
    params["/LastChar"] = PDFStream.intNum(_charMax);
    params["/Widths"] = widthsObject.ref();
    params["/FontDescriptor"] = descriptor.ref();
//    params["/Encoding"] = PDFStream.string("/Identity-H");
//    params["/ToUnicode"] = unicodeCMap.ref();
  }
}
