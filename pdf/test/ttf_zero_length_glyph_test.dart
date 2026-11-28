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

import 'package:pdf/pdf.dart';
import 'package:pdf/src/pdf/font/ttf_writer.dart';
import 'package:test/test.dart';

void main() {
  test('readGlyph returns no outline for a zero-length glyph', () {
    final font = TtfParser(
      File('noto-sans.ttf').readAsBytesSync().buffer.asByteData(),
    );
    final space = font.charToGlyphIndexMap[0x20]!;

    expect(font.glyphSizes[space], 0);
    expect(font.readGlyph(space).data, isEmpty);
  });

  // An empty glyph has loca[i] == loca[i + 1], so its offset points at the
  // next glyph's outline, which must not be read or embedded.
  test('Empty glyphs have no outline', () {
    for (final name in ['open-sans.ttf', 'roboto.ttf', 'noto-sans.ttf']) {
      final ttf = TtfParser(File(name).readAsBytesSync().buffer.asByteData());
      for (final char in [0x20, 0xa0, 0x2009, 0x200b, 0x202f]) {
        final glyphIndex = ttf.charToGlyphIndexMap[char];
        if (glyphIndex == null || ttf.glyphSizes[glyphIndex] != 0) {
          continue;
        }
        expect(
          ttf.readGlyph(glyphIndex).data,
          isEmpty,
          reason: '$name U+${char.toRadixString(16)}',
        );
      }
    }
  });

  test('Font SubSetting keeps empty glyphs empty', () {
    final fontData = File('open-sans.ttf').readAsBytesSync();
    final ttf = TtfParser(fontData.buffer.asByteData());
    // No-break, thin and zero-width spaces have their own empty glyph in
    // Open Sans, right before an outlined one.
    final chars = '1 7 2​0'.runes.toList();
    final subset = TtfParser(
      TtfWriter(ttf).withChars(chars).buffer.asByteData(),
    );

    // Glyph i of the subset is the glyph of chars[i].
    for (var i = 0; i < chars.length; i++) {
      final original = ttf.charToGlyphIndexMap[chars[i]]!;
      expect(
        subset.glyphSizes[i] == 0,
        ttf.glyphSizes[original] == 0,
        reason: 'U+${chars[i].toRadixString(16)}',
      );
    }
  });
}
