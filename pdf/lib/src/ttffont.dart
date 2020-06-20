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

  @override
  String get subtype => font.unicode ? '/Type0' : super.subtype;

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

    if (PdfArabic._isArabicDiacriticValue(charCode)) {
      final PdfFontMetrics metric = font.glyphInfoMap[g] ?? PdfFontMetrics.zero;
      return metric.copyWith(advanceWidth: 0);
    }

    return font.glyphInfoMap[g] ?? PdfFontMetrics.zero;
  }

  void _buildTrueType(Map<String, PdfStream> params) {
    int charMin;
    int charMax;

    file.buf.putBytes(font.bytes.buffer.asUint8List());
    file.params['/Length1'] = PdfStream.intNum(font.bytes.lengthInBytes);

    params['/BaseFont'] = PdfStream.string('/' + fontName);
    params['/FontDescriptor'] = descriptor.ref();
    charMin = 32;
    charMax = 255;
    for (int i = charMin; i <= charMax; i++) {
      widthsObject.values
          .add((glyphMetrics(i).advanceWidth * 1000.0).toInt().toString());
    }
    params['/FirstChar'] = PdfStream.intNum(charMin);
    params['/LastChar'] = PdfStream.intNum(charMax);
    params['/Widths'] = widthsObject.ref();
  }

  void _buildType0(Map<String, PdfStream> params) {
    int charMin;
    int charMax;

    final TtfWriter ttfWriter = TtfWriter(font);
    final Uint8List data = ttfWriter.withChars(unicodeCMap.cmap);
    file.buf.putBytes(data);
    file.params['/Length1'] = PdfStream.intNum(data.length);

    final PdfStream descendantFont = PdfStream.dictionary(<String, PdfStream>{
      '/Type': PdfStream.string('/Font'),
      '/BaseFont': PdfStream.string('/' + fontName),
      '/FontFile2': file.ref(),
      '/FontDescriptor': descriptor.ref(),
      '/W': PdfStream.array(<PdfStream>[
        PdfStream.intNum(0),
        widthsObject.ref(),
      ]),
      '/CIDToGIDMap': PdfStream.string('/Identity'),
      '/DW': PdfStream.string('1000'),
      '/Subtype': PdfStream.string('/CIDFontType2'),
      '/CIDSystemInfo': PdfStream.dictionary(<String, PdfStream>{
        '/Supplement': PdfStream.intNum(0),
        '/Registry': PdfStream()..putText('Adobe'),
        '/Ordering': PdfStream()..putText('Identity-H'),
      })
    });

    params['/BaseFont'] = PdfStream.string('/' + fontName);
    params['/Encoding'] = PdfStream.string('/Identity-H');
    params['/DescendantFonts'] = PdfStream()
      ..putArray(<PdfStream>[descendantFont]);
    params['/ToUnicode'] = unicodeCMap.ref();

    charMin = 0;
    charMax = unicodeCMap.cmap.length - 1;
    for (int i = charMin; i <= charMax; i++) {
      widthsObject.values.add(
          (glyphMetrics(unicodeCMap.cmap[i]).advanceWidth * 1000.0)
              .toInt()
              .toString());
    }
  }

  @override
  void _prepare() {
    super._prepare();

    if (font.unicode) {
      _buildType0(params);
    } else {
      _buildTrueType(params);
    }
  }

  @override
  PdfStream putText(String text) {
    if (!font.unicode) {
      return super.putText(text);
    }

    final Runes runes = text.runes;
    final PdfStream stream = PdfStream();
    stream.putBytes(latin1.encode('<'));
    for (int rune in runes) {
      int char = unicodeCMap.cmap.indexOf(rune);
      if (char == -1) {
        char = unicodeCMap.cmap.length;
        unicodeCMap.cmap.add(rune);
      }

      stream.putBytes(latin1.encode(char.toRadixString(16).padLeft(4, '0')));
    }
    stream.putBytes(latin1.encode('>'));
    return stream;
  }

  @override
  PdfFontMetrics stringMetrics(String s) {
    if (s.isEmpty || !font.unicode) {
      return super.stringMetrics(s);
    }

    final Runes runes = s.runes;
    final List<int> bytes = <int>[];
    runes.forEach(bytes.add);

    final Iterable<PdfFontMetrics> metrics = bytes.map(glyphMetrics);
    return PdfFontMetrics.append(metrics);
  }
}
