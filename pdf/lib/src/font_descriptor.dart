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

class PdfFontDescriptor extends PdfObject {
  PdfFontDescriptor(
    this.ttfFont,
    this.file,
  )   : assert(ttfFont != null),
        assert(file != null),
        super(ttfFont.pdfDocument, '/FontDescriptor');

  final PdfObjectStream file;

  final PdfTtfFont ttfFont;

  @override
  void _prepare() {
    super._prepare();

    params['/FontName'] = PdfName('/' + ttfFont.fontName);
    params['/FontFile2'] = file.ref();
    params['/Flags'] = PdfNum(ttfFont.font.unicode ? 4 : 32);
    params['/FontBBox'] = PdfArray.fromNum(<int>[
      (ttfFont.font.xMin / ttfFont.font.unitsPerEm * 1000).toInt(),
      (ttfFont.font.yMin / ttfFont.font.unitsPerEm * 1000).toInt(),
      (ttfFont.font.xMax / ttfFont.font.unitsPerEm * 1000).toInt(),
      (ttfFont.font.yMax / ttfFont.font.unitsPerEm * 1000).toInt()
    ]);
    params['/Ascent'] = PdfNum((ttfFont.ascent * 1000).toInt());
    params['/Descent'] = PdfNum((ttfFont.descent * 1000).toInt());
    params['/ItalicAngle'] = const PdfNum(0);
    params['/CapHeight'] = const PdfNum(10);
    params['/StemV'] = const PdfNum(79);
  }
}
