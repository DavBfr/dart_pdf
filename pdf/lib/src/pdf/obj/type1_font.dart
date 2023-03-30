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

import '../../priv.dart';
import '../document.dart';
import '../font/font_metrics.dart';
import '../format/object_base.dart';
import 'font.dart';
import 'object_dict.dart';
import 'ttffont.dart';

/// Type 1 font object.
/// this font is a default PDF font available in all PDF readers,
/// but it's only compatible with western latin languages.
///
/// To use other languages, use a [PdfTtfFont] that contains the
/// glyph for the language you will use.
///
/// see https://github.com/DavBfr/dart_pdf/wiki/Fonts-Management
class PdfType1Font extends PdfFont {
  /// Constructs a [PdfTtfFont]
  PdfType1Font.create(PdfDocument pdfDocument,
      {required this.fontName,
      required this.ascent,
      required this.descent,
      required List<int> fontBBox,
      double italicAngle = 0,
      required int capHeight,
      required int stdHW,
      required int stdVW,
      bool isFixedPitch = false,
      int? missingWidth,
      this.widths = const <double>[]})
      : assert(() {
          // ignore: avoid_print
          print(
              '$fontName has no Unicode support see https://github.com/DavBfr/dart_pdf/wiki/Fonts-Management');
          return true;
        }()),
        super.create(pdfDocument, subtype: '/Type1') {
    params['/BaseFont'] = PdfName('/$fontName');
    if (settings.version.index >= PdfVersion.pdf_1_5.index) {
      params['/FirstChar'] = const PdfNum(0);
      params['/LastChar'] = const PdfNum(256);
      params['/Widths'] = PdfArray.fromNum(widths.map((e) => e * 1000));

      final fontDescriptor = PdfObjectDict(pdfDocument, type: '/FontDescriptor')
        ..params['/FontName'] = PdfName('/$fontName')
        ..params['/Flags'] = PdfNum(32 + (isFixedPitch ? 1 : 0))
        ..params['/FontBBox'] = PdfArray.fromNum(fontBBox)
        ..params['/Ascent'] = PdfNum((ascent * 1000).toInt())
        ..params['/Descent'] = PdfNum((descent * 1000).toInt())
        ..params['/ItalicAngle'] = PdfNum(italicAngle)
        ..params['/CapHeight'] = PdfNum(capHeight)
        ..params['/StemV'] = PdfNum(stdVW)
        ..params['/StemH'] = PdfNum(stdHW);
      if (missingWidth != null) {
        fontDescriptor.params['/MissingWidth'] = PdfNum(missingWidth);
      }

      params['/FontDescriptor'] = fontDescriptor.ref();
    }
  }

  @override
  final String fontName;

  @override
  final double ascent;

  @override
  final double descent;

  @override
  int get unitsPerEm => 1000;

  /// Width of each glyph
  final List<double> widths;

  @override
  PdfFontMetrics glyphMetrics(int charCode) {
    if (!isRuneSupported(charCode)) {
      throw Exception(
          'Unable to display U+${charCode.toRadixString(16)} with $fontName');
    }

    return PdfFontMetrics(
        left: 0,
        top: descent,
        right: charCode < widths.length
            ? widths[charCode]
            : PdfFont.defaultGlyphWidth,
        bottom: ascent);
  }

  @override
  bool isRuneSupported(int charCode) {
    return charCode >= 0x00 && charCode <= 0xff;
  }
}
