/*
 * Copyright (C) 2017, David PHAM-VAN <dev.nfet.net@gmail.com>
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

part of pdf;

class PdfTtfFont extends PdfFont {
  PdfObject unicodeCMap;
  PdfFontDescriptor descriptor;
  PdfArrayObject widthsObject;
  final widths = List<String>();
  final TtfParser font;
  int _charMin;
  int _charMax;

  /// Constructs a [PdfTtfFont]
  PdfTtfFont(PdfDocument pdfDocument, ByteData bytes)
      : font = TtfParser(bytes),
        super._create(pdfDocument, subtype: "/TrueType") {
    PdfObjectStream file = PdfObjectStream(pdfDocument, isBinary: true);
    final data = bytes.buffer.asUint8List();
    file.buf.putBytes(data);
    file.params["/Length1"] = PdfStream.intNum(data.length);

    _charMin = 32;
    _charMax = 255;

    for (var i = _charMin; i <= _charMax; i++) {
      widths.add((glyphAdvance(i) * 1000.0).toString());
    }

    unicodeCMap = PdfObject(pdfDocument);
    descriptor = PdfFontDescriptor(this, file);
    widthsObject = PdfArrayObject(pdfDocument, widths);
  }

  @override
  String get fontName => "/" + font.fontName.replaceAll(" ", "");

  @override
  double glyphAdvance(int charCode) {
    var g = font.charToGlyphIndexMap[charCode];

    if (g == null) {
      return super.glyphAdvance(charCode);
    }

    return (g < font.advanceWidth.length ? font.advanceWidth[g] : null) ??
        super.glyphAdvance(charCode);
  }

  @override
  PdfRect glyphBounds(int charCode) {
    var g = font.charToGlyphIndexMap[charCode];

    if (g == null) {
      return super.glyphBounds(charCode);
    }

    return font.glyphInfoMap[g] ?? super.glyphBounds(charCode);
  }

  @override
  void _prepare() {
    super._prepare();

    params["/BaseFont"] = PdfStream.string(fontName);
    params["/FirstChar"] = PdfStream.intNum(_charMin);
    params["/LastChar"] = PdfStream.intNum(_charMax);
    params["/Widths"] = widthsObject.ref();
    params["/FontDescriptor"] = descriptor.ref();
//    params["/Encoding"] = PdfStream.string("/Identity-H");
//    params["/ToUnicode"] = unicodeCMap.ref();
  }
}
