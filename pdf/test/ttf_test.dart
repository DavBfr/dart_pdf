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

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/src/pdf/font/ttf_writer.dart';
import 'package:test/test.dart';

void printText(
  PdfPage page,
  PdfGraphics canvas,
  String text,
  PdfFont font,
  double top,
) {
  text = text + font.fontName;
  const fontSize = 20.0;
  final metrics = font.stringMetrics(text) * fontSize;

  const deb = 5;

  const x = 50.0;
  final y = page.pageFormat.height - top;

  canvas
    ..drawRect(x + metrics.left, y + metrics.top, metrics.width, metrics.height)
    ..setColor(const PdfColor(0.9, 0.9, 0.9))
    ..fillPath()
    ..drawLine(x + metrics.left - deb, y, x + metrics.right + deb, y)
    ..setColor(PdfColors.blue)
    ..strokePath()
    ..drawLine(
      x + metrics.left - deb,
      y + metrics.ascent,
      x + metrics.right + deb,
      y + metrics.ascent,
    )
    ..setColor(PdfColors.green)
    ..strokePath()
    ..drawLine(
      x + metrics.left - deb,
      y + metrics.descent,
      x + metrics.right + deb,
      y + metrics.descent,
    )
    ..setColor(PdfColors.purple)
    ..strokePath()
    ..setColor(const PdfColor(0.3, 0.3, 0.3))
    ..drawString(font, fontSize, text, x, y);
}

void printTextTtf(
  PdfPage page,
  PdfGraphics canvas,
  String text,
  File ttfFont,
  double top,
) {
  final fontData = ttfFont.readAsBytesSync();
  final font = PdfTtfFont(page.pdfDocument, fontData.buffer.asByteData());

  printText(page, canvas, text, font, top);
}

void main() {
  test('Pdf TrueType', () async {
    final pdf = PdfDocument();
    final page = PdfPage(pdf, pageFormat: const PdfPageFormat(500, 300));

    final g = page.getGraphics();
    var top = 0;
    const s = 'Hello Lukáča ';

    printTextTtf(page, g, s, File('open-sans.ttf'), 30.0 + 30.0 * top++);
    printTextTtf(page, g, s, File('open-sans-bold.ttf'), 30.0 + 30.0 * top++);
    printTextTtf(page, g, s, File('roboto.ttf'), 30.0 + 30.0 * top++);
    printTextTtf(page, g, s, File('noto-sans.ttf'), 30.0 + 30.0 * top++);
    printTextTtf(
      page,
      g,
      '你好 檯號 ',
      File('genyomintw.ttf'),
      30.0 + 30.0 * top++,
    );

    final file = File('ttf.pdf');
    await file.writeAsBytes(await pdf.save());
  });

  test('Font SubSetting', () {
    final fontData = File('open-sans.ttf').readAsBytesSync();
    final font = TtfParser(fontData.buffer.asByteData());
    final ttfWriter = TtfWriter(font);
    final data = ttfWriter.withChars('hçHée'.runes.toList());
    final output = File('${font.fontName}.ttf');
    output.writeAsBytesSync(data);
  });

  test('Font SubSetting CN', () {
    final fontData = File('genyomintw.ttf').readAsBytesSync();
    final font = TtfParser(fontData.buffer.asByteData());
    final ttfWriter = TtfWriter(font);
    final data = ttfWriter.withChars('hçHée 你好 檯號 ☃'.runes.toList());
    final output = File('${font.fontName}.ttf');
    output.writeAsBytesSync(data);
  });

  group('readGlyph', () {
    const fonts = <String>[
      'open-sans',
      'roboto',
      'noto-sans',
      'hacen-tunisia',
      'genyomintw',
    ];

    test('returns nothing for a glyph loca says is empty', () {
      // An empty glyph has loca[i] == loca[i + 1], so the start offset points at
      // the next glyph's record and the readers used to return its outline. Every
      // blank in every one of these fonts came back drawn.
      for (final name in fonts) {
        final font = TtfParser(
          File('$name.ttf').readAsBytesSync().buffer.asByteData(),
        );

        for (var g = 0; g < font.glyphOffsets.length; g++) {
          if (font.glyphSizes[g] > 0) {
            continue;
          }

          final glyph = font.readGlyph(g);
          expect(glyph.data, isEmpty, reason: '$name glyph $g');
          expect(glyph.compounds, isEmpty, reason: '$name glyph $g');
        }
      }
    });

    test('never returns more than loca says the glyph occupies', () {
      for (final name in fonts) {
        final font = TtfParser(
          File('$name.ttf').readAsBytesSync().buffer.asByteData(),
        );

        for (var g = 0; g < font.glyphOffsets.length; g++) {
          expect(
            font.readGlyph(g).data.length,
            lessThanOrEqualTo(math.max(font.glyphSizes[g], 0)),
            reason: '$name glyph $g',
          );
        }
      }
    });

    test('an empty glyph is not its neighbour', () {
      final font = TtfParser(
        File('open-sans.ttf').readAsBytesSync().buffer.asByteData(),
      );

      // Glyph 97 is U+00A0, the no-break space; 98 is U+00A1. readGlyph(97) used
      // to return 98's outline, byte for byte.
      expect(font.glyphSizes[97], 0);
      expect(font.readGlyph(97).data, isEmpty);
      expect(font.readGlyph(98).data, hasLength(font.glyphSizes[98]));
      expect(font.readGlyph(97).data, isNot(font.readGlyph(98).data));
    });

    test('a subset keeps the empty glyphs empty', () {
      final data = File('open-sans.ttf').readAsBytesSync();
      final font = TtfParser(data.buffer.asByteData());

      // 0x00A0 is a no-break space and 0x200B a zero-width space: both empty.
      final subset = TtfWriter(
        font,
      ).withChars(<int>[0x41, 0x00A0, 0x200B, 0x42]);
      final reparsed = TtfParser(subset.buffer.asByteData());

      expect(reparsed.glyphSizes.where((int s) => s == 0), hasLength(2));
      for (var g = 0; g < reparsed.glyphOffsets.length; g++) {
        if (reparsed.glyphSizes[g] == 0) {
          expect(reparsed.readGlyph(g).data, isEmpty);
        }
      }
    });
  });

  group('a sliced view', () {
    /// The same font, as a view starting [pad] bytes into a larger buffer.
    TtfParser padded(String name, int pad) {
      final font = File('$name.ttf').readAsBytesSync();
      final buffer = Uint8List(pad + font.length + 7)
        // Something other than zeros in front, so a parse that ignores the
        // offset reads nonsense rather than accidentally working.
        ..fillRange(0, pad, 0x5A)
        ..setRange(pad, pad + font.length, font);

      return TtfParser(ByteData.view(buffer.buffer, pad, font.length));
    }

    test('parses identically to offset zero', () {
      // Every accessor is view-relative but the reach-throughs to the backing
      // buffer were absolute, so this threw a FormatException decoding table
      // tags, or silently parsed a shifted window.
      final base = TtfParser(
        File('open-sans.ttf').readAsBytesSync().buffer.asByteData(),
      );

      for (final pad in <int>[1, 8, 4096]) {
        final view = padded('open-sans', pad);

        expect(view.fontName, base.fontName, reason: 'pad $pad');
        expect(view.numGlyphs, base.numGlyphs, reason: 'pad $pad');
        expect(view.tableOffsets, base.tableOffsets, reason: 'pad $pad');
        expect(view.tableSize, base.tableSize, reason: 'pad $pad');
        expect(
          view.charToGlyphIndexMap,
          base.charToGlyphIndexMap,
          reason: 'pad $pad',
        );
      }
    });

    test('reads every glyph identically', () {
      final base = TtfParser(
        File('open-sans.ttf').readAsBytesSync().buffer.asByteData(),
      );
      final view = padded('open-sans', 8);

      for (var g = 0; g < base.glyphOffsets.length; g++) {
        expect(
          view.readGlyph(g).data,
          base.readGlyph(g).data,
          reason: 'glyph $g',
        );
      }
    });

    test('subsets identically', () {
      final base = TtfParser(
        File('open-sans.ttf').readAsBytesSync().buffer.asByteData(),
      );
      final view = padded('open-sans', 4096);
      const chars = <int>[0x41, 0x42, 0x61, 0x62, 0x20];

      expect(
        TtfWriter(view).withChars(chars),
        TtfWriter(base).withChars(chars),
      );
    });

    test('fontData is exactly the view', () {
      final font = File('open-sans.ttf').readAsBytesSync();
      final view = padded('open-sans', 8);

      expect(view.fontData, hasLength(font.length));
      expect(view.fontData, font);
    });

    test('an emoji font reads the same bitmaps', () {
      final base = TtfParser(
        File('emoji.ttf').readAsBytesSync().buffer.asByteData(),
      );
      final view = padded('emoji', 8);

      expect(view.bitmapOffsets.keys, base.bitmapOffsets.keys);
      for (final glyph in base.bitmapOffsets.keys) {
        expect(
          view.getBitmap(glyph)?.data,
          base.getBitmap(glyph)?.data,
          reason: 'glyph $glyph',
        );
      }
    });
  });
}
