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
  PdfFontDescriptor(this.ttfFont, this.file)
      : super(ttfFont.pdfDocument, '/FontDescriptor');

  final PdfObjectStream file;

  final PdfTtfFont ttfFont;

  @override
  void _prepare() {
    super._prepare();

    params['/FontName'] = PdfStream.string('/' + ttfFont.fontName);
    params['/FontFile2'] = file.ref();
    params['/Flags'] = PdfStream.intNum(32);
    params['/FontBBox'] = PdfStream()
      ..putIntArray(<int>[
        (ttfFont.font.xMin / ttfFont.font.unitsPerEm * 1000).toInt(),
        (ttfFont.font.yMin / ttfFont.font.unitsPerEm * 1000).toInt(),
        (ttfFont.font.xMax / ttfFont.font.unitsPerEm * 1000).toInt(),
        (ttfFont.font.yMax / ttfFont.font.unitsPerEm * 1000).toInt()
      ]);
    params['/Ascent'] = PdfStream.intNum((ttfFont.ascent * 1000).toInt());
    params['/Descent'] = PdfStream.intNum((ttfFont.descent * 1000).toInt());
    params['/ItalicAngle'] = PdfStream.intNum(0);
    params['/CapHeight'] = PdfStream.intNum(10);
    params['/StemV'] = PdfStream.intNum(79);
  }
}
