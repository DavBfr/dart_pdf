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

class PdfType1Font extends PdfFont {
  /// Constructs a [PdfTtfFont]
  PdfType1Font._create(PdfDocument pdfDocument, this.fontName, this.ascent,
      this.descent, this.widths)
      : super._create(pdfDocument, subtype: '/Type1');

  /// The font's real name
  @override
  final String fontName;

  @override
  final double ascent;

  @override
  final double descent;

  final List<double> widths;

  /// @param os OutputStream to send the object to
  @override
  void _prepare() {
    super._prepare();

    params['/BaseFont'] = PdfStream.string('/' + fontName);
  }

  @override
  PdfFontMetrics glyphMetrics(int charCode) {
    return PdfFontMetrics(
        left: 0.0,
        top: descent,
        right: charCode < widths.length
            ? widths[charCode]
            : PdfFont.defaultGlyphWidth,
        bottom: ascent);
  }
}
