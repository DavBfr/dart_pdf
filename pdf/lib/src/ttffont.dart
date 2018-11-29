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
    file = PdfObjectStream(pdfDocument, isBinary: true);
    unicodeCMap = PdfUnicodeCmap(pdfDocument);
    descriptor = PdfFontDescriptor(this, file);
    widthsObject = PdfArrayObject(pdfDocument, <String>[]);
  }

  PdfUnicodeCmap unicodeCMap;

  PdfFontDescriptor descriptor;

  PdfObjectStream file;

  PdfArrayObject widthsObject;

  final TtfParser font;

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
    int charMin;
    int charMax;

    super._prepare();

    final TtfWriter ttfWriter = TtfWriter(font);
    final Uint8List data = ttfWriter.withChars(unicodeCMap.cmap);

    file.buf.putBytes(data);
    file.params['/Length1'] = PdfStream.intNum(data.length);

    params['/BaseFont'] = PdfStream.string('/' + fontName);
    params['/FontDescriptor'] = descriptor.ref();
    if (font.unicode) {
      if (params.containsKey('/Encoding')) {
        params.remove('/Encoding');
      }
      params['/ToUnicode'] = unicodeCMap.ref();
      charMin = 0;
      charMax = unicodeCMap.cmap.length - 1;
      for (int i = charMin; i <= charMax; i++) {
        widthsObject.values.add(
            (glyphMetrics(unicodeCMap.cmap[i]).advanceWidth * 1000.0)
                .toInt()
                .toString());
      }
    } else {
      charMin = 32;
      charMax = 255;
      for (int i = charMin; i <= charMax; i++) {
        widthsObject.values
            .add((glyphMetrics(i).advanceWidth * 1000.0).toInt().toString());
      }
    }
    params['/FirstChar'] = PdfStream.intNum(charMin);
    params['/LastChar'] = PdfStream.intNum(charMax);
    params['/Widths'] = widthsObject.ref();
  }

  @override
  PdfStream putText(String text) {
    if (!font.unicode) {
      return super.putText(text);
    }

    final Runes runes = text.runes;
    final List<int> bytes = List<int>();
    for (int rune in runes) {
      int char = unicodeCMap.cmap.indexOf(rune);
      if (char == -1) {
        char = unicodeCMap.cmap.length;
        unicodeCMap.cmap.add(rune);
      }

      bytes.add(char);
    }

    return PdfStream()
      ..putBytes(latin1.encode('('))
      ..putTextBytes(bytes)
      ..putBytes(latin1.encode(')'));
  }

  @override
  PdfFontMetrics stringMetrics(String s) {
    if (s.isEmpty || !font.unicode) {
      return super.stringMetrics(s);
    }

    final Runes runes = s.runes;
    final List<int> bytes = List<int>();
    runes.forEach(bytes.add);

    final Iterable<PdfFontMetrics> metrics = bytes.map(glyphMetrics);
    return PdfFontMetrics.append(metrics);
  }
}
