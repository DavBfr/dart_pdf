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

import 'dart:convert';

import '../document.dart';
import '../font/font_metrics.dart';
import '../font/type1_fonts.dart';
import '../format/dict.dart';
import '../format/name.dart';
import '../format/stream.dart';
import '../format/string.dart';
import '../point.dart';
import 'object.dart';
import 'type1_font.dart';

/// Pdf font object
abstract class PdfFont extends PdfObject<PdfDict> {
  /// Constructs a [PdfFont]. This will attempt to map the font from a known
  /// font name to that in Pdf, defaulting to Helvetica if not possible.
  PdfFont.create(PdfDocument pdfDocument, {required this.subtype})
      : super(
          pdfDocument,
          params: PdfDict({
            '/Type': const PdfName('/Font'),
          }),
        ) {
    pdfDocument.fonts.add(this);
  }

  /// Monospaced slab serif typeface.
  factory PdfFont.courier(PdfDocument pdfDocument) {
    return PdfType1Font.create(
      pdfDocument,
      fontName: 'Courier',
      ascent: 0.910,
      descent: -0.220,
      fontBBox: [-23, -250, 715, 805],
      capHeight: 562,
      stdHW: 84,
      stdVW: 106,
      isFixedPitch: true,
    );
  }

  /// Bold monospaced slab serif typeface.
  factory PdfFont.courierBold(PdfDocument pdfDocument) {
    return PdfType1Font.create(
      pdfDocument,
      fontName: 'Courier-Bold',
      ascent: 0.910,
      descent: -0.220,
      fontBBox: [-113, -250, 749, 801],
      capHeight: 562,
      stdHW: 51,
      stdVW: 51,
      isFixedPitch: true,
    );
  }

  /// Bold and Italic monospaced slab serif typeface.
  factory PdfFont.courierBoldOblique(PdfDocument pdfDocument) {
    return PdfType1Font.create(
      pdfDocument,
      fontName: 'Courier-BoldOblique',
      ascent: 0.910,
      descent: -0.220,
      fontBBox: [-57, -250, 869, 801],
      capHeight: 562,
      italicAngle: -12,
      isFixedPitch: true,
      stdHW: 84,
      stdVW: 106,
    );
  }

  /// Italic monospaced slab serif typeface.
  factory PdfFont.courierOblique(PdfDocument pdfDocument) {
    return PdfType1Font.create(
      pdfDocument,
      fontName: 'Courier-Oblique',
      ascent: 0.910,
      descent: -0.220,
      fontBBox: [-27, -250, 849, 805],
      capHeight: 562,
      isFixedPitch: true,
      italicAngle: -12,
      stdHW: 51,
      stdVW: 51,
    );
  }

  /// Neo-grotesque design sans-serif typeface
  factory PdfFont.helvetica(PdfDocument pdfDocument) {
    return PdfType1Font.create(
      pdfDocument,
      fontName: 'Helvetica',
      ascent: 0.931,
      descent: -0.225,
      widths: helveticaWidths,
      fontBBox: [-166, -225, 1000, 931],
      capHeight: 718,
      stdHW: 76,
      stdVW: 88,
    );
  }

  /// Bold Neo-grotesque design sans-serif typeface
  factory PdfFont.helveticaBold(PdfDocument pdfDocument) {
    return PdfType1Font.create(
      pdfDocument,
      fontName: 'Helvetica-Bold',
      ascent: 0.962,
      descent: -0.228,
      widths: helveticaBoldWidths,
      fontBBox: [-170, -228, 1003, 962],
      capHeight: 718,
      stdHW: 118,
      stdVW: 140,
    );
  }

  /// Bold and Italic Neo-grotesque design sans-serif typeface
  factory PdfFont.helveticaBoldOblique(PdfDocument pdfDocument) {
    return PdfType1Font.create(
      pdfDocument,
      fontName: 'Helvetica-BoldOblique',
      ascent: 0.962,
      descent: -0.228,
      widths: helveticaBoldObliqueWidths,
      italicAngle: -12,
      fontBBox: [-170, -228, 1114, 962],
      capHeight: 718,
      stdHW: 118,
      stdVW: 140,
    );
  }

  /// Italic Neo-grotesque design sans-serif typeface
  factory PdfFont.helveticaOblique(PdfDocument pdfDocument) {
    return PdfType1Font.create(
      pdfDocument,
      fontName: 'Helvetica-Oblique',
      ascent: 0.931,
      descent: -0.225,
      widths: helveticaObliqueWidths,
      italicAngle: -12,
      fontBBox: [-170, -225, 1116, 931],
      capHeight: 718,
      stdHW: 76,
      stdVW: 88,
    );
  }

  /// Serif typeface commissioned by the British newspaper The Times
  factory PdfFont.times(PdfDocument pdfDocument) {
    return PdfType1Font.create(
      pdfDocument,
      fontName: 'Times-Roman',
      ascent: 0.898,
      descent: -0.218,
      widths: timesWidths,
      fontBBox: [-168, -218, 1000, 898],
      capHeight: 662,
      stdHW: 28,
      stdVW: 84,
    );
  }

  /// Bold serif typeface commissioned by the British newspaper The Times
  factory PdfFont.timesBold(PdfDocument pdfDocument) {
    return PdfType1Font.create(
      pdfDocument,
      fontName: 'Times-Bold',
      ascent: 0.935,
      descent: -0.218,
      widths: timesBoldWidths,
      fontBBox: [-168, -218, 1000, 935],
      capHeight: 676,
      stdHW: 44,
      stdVW: 139,
    );
  }

  /// Bold and Italic serif typeface commissioned by the British newspaper The Times
  factory PdfFont.timesBoldItalic(PdfDocument pdfDocument) {
    return PdfType1Font.create(
      pdfDocument,
      fontName: 'Times-BoldItalic',
      ascent: 0.921,
      descent: -0.218,
      widths: timesBoldItalicWidths,
      italicAngle: -15,
      fontBBox: [-200, -218, 996, 921],
      capHeight: 669,
      stdHW: 42,
      stdVW: 121,
    );
  }

  /// Italic serif typeface commissioned by the British newspaper The Times
  factory PdfFont.timesItalic(PdfDocument pdfDocument) {
    return PdfType1Font.create(
      pdfDocument,
      fontName: 'Times-Italic',
      ascent: 0.883,
      descent: -0.217,
      widths: timesItalicWidths,
      italicAngle: -15.5,
      fontBBox: [-169, -217, 1010, 883],
      capHeight: 653,
      stdHW: 32,
      stdVW: 76,
    );
  }

  /// Complete unaccented serif Greek alphabet (upper and lower case) and a
  /// selection of commonly used mathematical symbols.
  factory PdfFont.symbol(PdfDocument pdfDocument) {
    return PdfType1Font.create(
      pdfDocument,
      fontName: 'Symbol',
      ascent: 1.010,
      descent: -0.293,
      widths: symbolWidths,
      fontBBox: [-180, -293, 1090, 1010],
      capHeight: 653,
      stdHW: 92,
      stdVW: 85,
    );
  }

  /// Hermann Zapf ornament glyphs or spacers, often employed to create box frames
  factory PdfFont.zapfDingbats(PdfDocument pdfDocument) {
    return PdfType1Font.create(
      pdfDocument,
      fontName: 'ZapfDingbats',
      ascent: 0.820,
      descent: -0.143,
      widths: zapfDingbatsWidths,
      fontBBox: [-1, -143, 981, 820],
      capHeight: 653,
      stdHW: 28,
      stdVW: 90,
    );
  }

  static const String _cannotDecodeMessage =
      '''---------------------------------------------
Cannot decode the string to Latin1.
This font does not support Unicode characters.
If you want to use strings other than Latin strings, use a TrueType (TTF) font instead.
See https://github.com/DavBfr/dart_pdf/wiki/Fonts-Management
---------------------------------------------''';

  /// The df type of the font, usually /Type1
  final String subtype;

  /// Internal name
  String get name => '/F$objser';

  /// The font's real name
  String get fontName;

  /// Spans the distance between the baseline and the top of the glyph that
  /// reaches farthest from the baseline
  double get ascent;

  /// Spans the distance between the baseline and the lowest descending glyph
  double get descent;

  /// Internal units per
  int get unitsPerEm;

  @override
  void prepare() {
    super.prepare();

    params['/Subtype'] = PdfName(subtype);
    params['/Name'] = PdfName(name);
    params['/Encoding'] = const PdfName('/WinAnsiEncoding');
  }

  /// Calculate the [PdfFontMetrics] for this glyph
  PdfFontMetrics glyphMetrics(int charCode);

  /// is this Rune supported by this font
  bool isRuneSupported(int charCode);

  /// Calculate the [PdfFontMetrics] for this string
  PdfFontMetrics stringMetrics(String s, {double letterSpacing = 0}) {
    if (s.isEmpty) {
      return PdfFontMetrics.zero;
    }

    try {
      final chars = latin1.encode(s);
      final metrics = chars.map(glyphMetrics);
      return PdfFontMetrics.append(metrics, letterSpacing: letterSpacing);
    } catch (_) {
      assert(() {
        print(_cannotDecodeMessage);
        return true;
      }());

      rethrow;
    }
  }

  /// Calculate the unit size of this string
  @Deprecated('Use stringMetrics(s).size instead.')
  PdfPoint stringSize(String s) => stringMetrics(s).size;

  @override
  String toString() => 'Font($fontName)';

  /// Draw some text
  void putText(PdfStream stream, String text) {
    try {
      PdfString(latin1.encode(text),
              format: PdfStringFormat.literal, encrypted: false)
          .output(this, stream);
    } catch (_) {
      assert(() {
        print(_cannotDecodeMessage);
        return true;
      }());

      rethrow;
    }
  }
}
