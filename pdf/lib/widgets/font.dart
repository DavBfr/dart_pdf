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

part of widget;

enum Type1Fonts {
  courier,
  courierBold,
  courierBoldOblique,
  courierOblique,
  helvetica,
  helveticaBold,
  helveticaBoldOblique,
  helveticaOblique,
  times,
  timesBold,
  timesBoldItalic,
  timesItalic,
  symbol,
  zapfDingbats
}

/// Lazy font declaration, registers the font in the document only if needed.
/// Tries to register a font only once
class Font {
  Font() : font = null;

  Font.type1(this.font) : assert(font != null);

  factory Font.courier() => Font.type1(Type1Fonts.courier);
  factory Font.courierBold() => Font.type1(Type1Fonts.courierBold);
  factory Font.courierBoldOblique() =>
      Font.type1(Type1Fonts.courierBoldOblique);
  factory Font.courierOblique() => Font.type1(Type1Fonts.courierOblique);
  factory Font.helvetica() => Font.type1(Type1Fonts.helvetica);
  factory Font.helveticaBold() => Font.type1(Type1Fonts.helveticaBold);
  factory Font.helveticaBoldOblique() =>
      Font.type1(Type1Fonts.helveticaBoldOblique);
  factory Font.helveticaOblique() => Font.type1(Type1Fonts.helveticaOblique);
  factory Font.times() => Font.type1(Type1Fonts.times);
  factory Font.timesBold() => Font.type1(Type1Fonts.timesBold);
  factory Font.timesBoldItalic() => Font.type1(Type1Fonts.timesBoldItalic);
  factory Font.timesItalic() => Font.type1(Type1Fonts.timesItalic);
  factory Font.symbol() => Font.type1(Type1Fonts.symbol);
  factory Font.zapfDingbats() => Font.type1(Type1Fonts.zapfDingbats);

  final Type1Fonts font;

  @protected
  PdfFont buildFont(PdfDocument pdfDocument) {
    const Map<Type1Fonts, String> type1Map = <Type1Fonts, String>{
      Type1Fonts.courier: 'Courier',
      Type1Fonts.courierBold: 'Courier-Bold',
      Type1Fonts.courierBoldOblique: 'Courier-BoldOblique',
      Type1Fonts.courierOblique: 'Courier-Oblique',
      Type1Fonts.helvetica: 'Helvetica',
      Type1Fonts.helveticaBold: 'Helvetica-Bold',
      Type1Fonts.helveticaBoldOblique: 'Helvetica-BoldOblique',
      Type1Fonts.helveticaOblique: 'Helvetica-Oblique',
      Type1Fonts.times: 'Times-Roman',
      Type1Fonts.timesBold: 'Times-Bold',
      Type1Fonts.timesBoldItalic: 'Times-BoldItalic',
      Type1Fonts.timesItalic: 'Times-Italic',
      Type1Fonts.symbol: 'Symbol',
      Type1Fonts.zapfDingbats: 'ZapfDingbats'
    };

    final String fontName = type1Map[font];
    final PdfFont existing = pdfDocument.fonts.firstWhere(
      (PdfFont font) => font.subtype == '/Type1' && font.fontName == fontName,
      orElse: () => null,
    );

    if (existing != null) {
      return existing;
    }

    switch (font) {
      case Type1Fonts.courier:
        return PdfFont.courier(pdfDocument);
      case Type1Fonts.courierBold:
        return PdfFont.courierBold(pdfDocument);
      case Type1Fonts.courierBoldOblique:
        return PdfFont.courierBoldOblique(pdfDocument);
      case Type1Fonts.courierOblique:
        return PdfFont.courierOblique(pdfDocument);
      case Type1Fonts.helvetica:
        return PdfFont.helvetica(pdfDocument);
      case Type1Fonts.helveticaBold:
        return PdfFont.helveticaBold(pdfDocument);
      case Type1Fonts.helveticaBoldOblique:
        return PdfFont.helveticaBoldOblique(pdfDocument);
      case Type1Fonts.helveticaOblique:
        return PdfFont.helveticaOblique(pdfDocument);
      case Type1Fonts.times:
        return PdfFont.times(pdfDocument);
      case Type1Fonts.timesBold:
        return PdfFont.timesBold(pdfDocument);
      case Type1Fonts.timesBoldItalic:
        return PdfFont.timesBoldItalic(pdfDocument);
      case Type1Fonts.timesItalic:
        return PdfFont.timesItalic(pdfDocument);
      case Type1Fonts.symbol:
        return PdfFont.symbol(pdfDocument);
      case Type1Fonts.zapfDingbats:
        return PdfFont.zapfDingbats(pdfDocument);
    }
    return PdfFont.helvetica(pdfDocument);
  }

  PdfFont _pdfFont;

  PdfFont getFont(Context context) {
    if (_pdfFont == null) {
      final PdfDocument pdfDocument = context.document;
      _pdfFont = buildFont(pdfDocument);
    }

    return _pdfFont;
  }
}

class TtfFont extends Font {
  TtfFont(this.data);

  final ByteData data;
  @override
  PdfFont buildFont(PdfDocument pdfDocument) {
    return PdfTtfFont(pdfDocument, data);
  }
}
