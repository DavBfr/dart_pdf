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

// ignore_for_file: omit_local_variable_types

part of pdf;

abstract class PdfFont extends PdfObject {
  /// Constructs a [PdfFont]. This will attempt to map the font from a known
  /// font name to that in Pdf, defaulting to Helvetica if not possible.
  ///
  /// @param name The document name, ie /F1
  /// @param subtype The pdf type, ie /Type1
  /// @param baseFont The font name, ie /Helvetica
  PdfFont._create(PdfDocument pdfDocument, {@required this.subtype})
      : assert(subtype != null),
        super(pdfDocument, '/Font') {
    pdfDocument.fonts.add(this);
  }

  factory PdfFont.courier(PdfDocument pdfDocument) {
    return PdfType1Font._create(
        pdfDocument, 'Courier', 0.910, -0.220, const <double>[]);
  }

  factory PdfFont.courierBold(PdfDocument pdfDocument) {
    return PdfType1Font._create(
        pdfDocument, 'Courier-Bold', 0.910, -0.220, const <double>[]);
  }

  factory PdfFont.courierBoldOblique(PdfDocument pdfDocument) {
    return PdfType1Font._create(
        pdfDocument, 'Courier-BoldOblique', 0.910, -0.220, const <double>[]);
  }

  factory PdfFont.courierOblique(PdfDocument pdfDocument) {
    return PdfType1Font._create(
        pdfDocument, 'Courier-Oblique', 0.910, -0.220, const <double>[]);
  }

  factory PdfFont.helvetica(PdfDocument pdfDocument) {
    return PdfType1Font._create(
        pdfDocument, 'Helvetica', 0.931, -0.225, _helveticaWidths);
  }

  factory PdfFont.helveticaBold(PdfDocument pdfDocument) {
    return PdfType1Font._create(
        pdfDocument, 'Helvetica-Bold', 0.962, -0.228, _helveticaBoldWidths);
  }

  factory PdfFont.helveticaBoldOblique(PdfDocument pdfDocument) {
    return PdfType1Font._create(pdfDocument, 'Helvetica-BoldOblique', 0.962,
        -0.228, _helveticaBoldObliqueWidths);
  }

  factory PdfFont.helveticaOblique(PdfDocument pdfDocument) {
    return PdfType1Font._create(pdfDocument, 'Helvetica-Oblique', 0.931, -0.225,
        _helveticaObliqueWidths);
  }

  factory PdfFont.times(PdfDocument pdfDocument) {
    return PdfType1Font._create(
        pdfDocument, 'Times-Roman', 0.898, -0.218, _timesWidths);
  }

  factory PdfFont.timesBold(PdfDocument pdfDocument) {
    return PdfType1Font._create(
        pdfDocument, 'Times-Bold', 0.935, -0.218, _timesBoldWidths);
  }

  factory PdfFont.timesBoldItalic(PdfDocument pdfDocument) {
    return PdfType1Font._create(
        pdfDocument, 'Times-BoldItalic', 0.921, -0.218, _timesBoldItalicWidths);
  }

  factory PdfFont.timesItalic(PdfDocument pdfDocument) {
    return PdfType1Font._create(
        pdfDocument, 'Times-Italic', 0.883, -0.217, _timesItalicWidths);
  }

  factory PdfFont.symbol(PdfDocument pdfDocument) {
    return PdfType1Font._create(
        pdfDocument, 'Symbol', 1.010, -0.293, _symbolWidths);
  }

  factory PdfFont.zapfDingbats(PdfDocument pdfDocument) {
    return PdfType1Font._create(
        pdfDocument, 'ZapfDingbats', 0.820, -0.143, _zapfDingbatsWidths);
  }

  /// The df type of the font, usually /Type1
  final String subtype;

  String get name => '/F$objser';

  String get fontName => null;

  double get ascent => null;

  double get descent => null;

  static const double defaultGlyphWidth = 0.600;

  /// @param os OutputStream to send the object to
  @override
  void _prepare() {
    super._prepare();

    params['/Subtype'] = PdfStream.string(subtype);
    params['/Name'] = PdfStream.string(name);
    params['/Encoding'] = PdfStream.string('/WinAnsiEncoding');
  }

  @Deprecated('Use `glyphMetrics` instead')
  double glyphAdvance(int charCode) => glyphMetrics(charCode).advanceWidth;

  PdfFontMetrics glyphMetrics(int charCode);

  @Deprecated('Use `glyphMetrics` instead')
  PdfRect glyphBounds(int charCode) => glyphMetrics(charCode).toPdfRect();

  PdfFontMetrics stringMetrics(String s) {
    if (s.isEmpty) {
      return PdfFontMetrics.zero;
    }

    try {
      final Uint8List chars = latin1.encode(s);
      final Iterable<PdfFontMetrics> metrics = chars.map(glyphMetrics);
      return PdfFontMetrics.append(metrics);
    } catch (e) {
      assert(false, '''\n---------------------------------------------
Can not decode the string to Latin1.
This font does not support Unicode characters.
If you want to use strings other than Latin strings, use a TrueType (TTF) font instead.
See https://github.com/DavBfr/dart_pdf/wiki/Fonts-Management
---------------------------------------------''');
      rethrow;
    }
  }

  @Deprecated('Use `stringMetrics` instead')
  PdfRect stringBounds(String s) => stringMetrics(s).toPdfRect();

  PdfPoint stringSize(String s) {
    final PdfFontMetrics metrics = stringMetrics(s);
    return PdfPoint(metrics.width, metrics.height);
  }

  @override
  String toString() => 'Font($fontName)';

  PdfStream putText(String text) {
    try {
      return PdfStream()
        ..putBytes(latin1.encode('('))
        ..putTextBytes(latin1.encode(text))
        ..putBytes(latin1.encode(')'));
    } catch (e) {
      assert(false, '''\n---------------------------------------------
Can not decode the string to Latin1.
This font does not support Unicode characters.
If you want to use strings other than Latin strings, use a TrueType (TTF) font instead.
See https://github.com/DavBfr/dart_pdf/wiki/Fonts-Management
---------------------------------------------''');
      rethrow;
    }
  }
}
