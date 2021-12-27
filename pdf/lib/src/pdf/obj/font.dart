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

import '../data_types.dart';
import '../document.dart';
import '../font/font_metrics.dart';
import '../font/type1_fonts.dart';
import '../point.dart';
import '../stream.dart';
import 'object_dict.dart';
import 'type1_font.dart';

/// Pdf font object
abstract class PdfFont extends PdfObjectDict {
  /// Constructs a [PdfFont]. This will attempt to map the font from a known
  /// font name to that in Pdf, defaulting to Helvetica if not possible.
  PdfFont.create(PdfDocument pdfDocument, {required this.subtype})
      : super(pdfDocument, type: '/Font') {
    pdfDocument.fonts.add(this);
  }

  /// Monospaced slab serif typeface.
  factory PdfFont.courier(PdfDocument pdfDocument) {
    return PdfType1Font.create(
        pdfDocument, 'Courier', 0.910, -0.220, const <double>[]);
  }

  /// Bold monospaced slab serif typeface.
  factory PdfFont.courierBold(PdfDocument pdfDocument) {
    return PdfType1Font.create(
        pdfDocument, 'Courier-Bold', 0.910, -0.220, const <double>[]);
  }

  /// Bold and Italic monospaced slab serif typeface.
  factory PdfFont.courierBoldOblique(PdfDocument pdfDocument) {
    return PdfType1Font.create(
        pdfDocument, 'Courier-BoldOblique', 0.910, -0.220, const <double>[]);
  }

  /// Italic monospaced slab serif typeface.
  factory PdfFont.courierOblique(PdfDocument pdfDocument) {
    return PdfType1Font.create(
        pdfDocument, 'Courier-Oblique', 0.910, -0.220, const <double>[]);
  }

  /// Neo-grotesque design sans-serif typeface
  factory PdfFont.helvetica(PdfDocument pdfDocument) {
    return PdfType1Font.create(
        pdfDocument, 'Helvetica', 0.931, -0.225, helveticaWidths);
  }

  /// Bold Neo-grotesque design sans-serif typeface
  factory PdfFont.helveticaBold(PdfDocument pdfDocument) {
    return PdfType1Font.create(
        pdfDocument, 'Helvetica-Bold', 0.962, -0.228, helveticaBoldWidths);
  }

  /// Bold and Italic Neo-grotesque design sans-serif typeface
  factory PdfFont.helveticaBoldOblique(PdfDocument pdfDocument) {
    return PdfType1Font.create(pdfDocument, 'Helvetica-BoldOblique', 0.962,
        -0.228, helveticaBoldObliqueWidths);
  }

  /// Italic Neo-grotesque design sans-serif typeface
  factory PdfFont.helveticaOblique(PdfDocument pdfDocument) {
    return PdfType1Font.create(pdfDocument, 'Helvetica-Oblique', 0.931, -0.225,
        helveticaObliqueWidths);
  }

  /// Serif typeface commissioned by the British newspaper The Times
  factory PdfFont.times(PdfDocument pdfDocument) {
    return PdfType1Font.create(
        pdfDocument, 'Times-Roman', 0.898, -0.218, timesWidths);
  }

  /// Bold serif typeface commissioned by the British newspaper The Times
  factory PdfFont.timesBold(PdfDocument pdfDocument) {
    return PdfType1Font.create(
        pdfDocument, 'Times-Bold', 0.935, -0.218, timesBoldWidths);
  }

  /// Bold and Italic serif typeface commissioned by the British newspaper The Times
  factory PdfFont.timesBoldItalic(PdfDocument pdfDocument) {
    return PdfType1Font.create(
        pdfDocument, 'Times-BoldItalic', 0.921, -0.218, timesBoldItalicWidths);
  }

  /// Italic serif typeface commissioned by the British newspaper The Times
  factory PdfFont.timesItalic(PdfDocument pdfDocument) {
    return PdfType1Font.create(
        pdfDocument, 'Times-Italic', 0.883, -0.217, timesItalicWidths);
  }

  /// Complete unaccented serif Greek alphabet (upper and lower case) and a
  /// selection of commonly used mathematical symbols.
  factory PdfFont.symbol(PdfDocument pdfDocument) {
    return PdfType1Font.create(
        pdfDocument, 'Symbol', 1.010, -0.293, symbolWidths);
  }

  /// Hermann Zapf ornament glyphs or spacers, often employed to create box frames
  factory PdfFont.zapfDingbats(PdfDocument pdfDocument) {
    return PdfType1Font.create(
        pdfDocument, 'ZapfDingbats', 0.820, -0.143, zapfDingbatsWidths);
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

  /// Default width of a glyph
  static const double defaultGlyphWidth = 0.600;

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

  /// Calculage the unit size of this string
  PdfPoint stringSize(String s) {
    final metrics = stringMetrics(s);
    return PdfPoint(metrics.width, metrics.height);
  }

  @override
  String toString() => 'Font($fontName)';

  /// Draw some text
  void putText(PdfStream stream, String text) {
    try {
      PdfString(latin1.encode(text), PdfStringFormat.litteral).output(stream);
    } catch (_) {
      assert(() {
        print(_cannotDecodeMessage);
        return true;
      }());

      rethrow;
    }
  }
}
