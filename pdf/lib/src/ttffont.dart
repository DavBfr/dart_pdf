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
  /// Constructs a [PdfTtfFont]
  PdfTtfFont(PdfDocument pdfDocument, ByteData bytes)
      : font = TtfParser(bytes),
        super._create(pdfDocument, subtype: '/TrueType') {
    final PdfObjectStream file = PdfObjectStream(pdfDocument, isBinary: true);
    final Uint8List data = bytes.buffer.asUint8List();
    file.buf.putBytes(data);
    file.params['/Length1'] = PdfStream.intNum(data.length);

    _charMin = 32;
    _charMax = 255;

    final List<String> widths = <String>[];

    for (int i = _charMin; i <= _charMax; i++) {
      widths.add((glyphMetrics(i).advanceWidth * 1000.0).toInt().toString());
    }

    unicodeCMap = PdfObject(pdfDocument);
    descriptor = PdfFontDescriptor(this, file);
    widthsObject = PdfArrayObject(pdfDocument, widths);
  }

  PdfObject unicodeCMap;

  PdfFontDescriptor descriptor;

  PdfArrayObject widthsObject;

  final TtfParser font;

  int _charMin;

  int _charMax;

  @override
  String get fontName => font.fontName;

  @override
  double get ascent => font.ascent.toDouble() / font.unitsPerEm;

  @override
  double get descent => font.descent.toDouble() / font.unitsPerEm;

  @override
  PdfFontMetrics glyphMetrics(int charCode) {
    final int g = font.charToGlyphIndexMap[charCode];

    if (g == null) {
      return PdfFontMetrics.zero;
    }

    return font.glyphInfoMap[g] ?? PdfFontMetrics.zero;
  }

  @override
  void _prepare() {
    super._prepare();

    params['/BaseFont'] = PdfStream.string('/' + fontName);
    params['/FirstChar'] = PdfStream.intNum(_charMin);
    params['/LastChar'] = PdfStream.intNum(_charMax);
    params['/Widths'] = widthsObject.ref();
    params['/FontDescriptor'] = descriptor.ref();
//    params['/Encoding'] = PdfStream.string('/Identity-H');
//    params['/ToUnicode'] = unicodeCMap.ref();
  }
}
