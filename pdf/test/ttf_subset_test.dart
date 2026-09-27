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
import 'dart:typed_data';

import 'package:pdf/src/pdf/font/ttf_parser.dart';
import 'package:pdf/src/pdf/font/ttf_writer.dart';
import 'package:pdf/widgets.dart';
import 'package:test/test.dart';

TtfParser _parse(String path) =>
    TtfParser(ByteData.sublistView(File(path).readAsBytesSync()));

void main() {
  test('every character keeps its own glyph when two share a source glyph', () {
    // U+00AF and U+02C9 are canonical duplicates in Roboto: both resolve to
    // the same source glyph. The subsetter used to consume the glyph for the
    // first character and hand an unrelated one to the second.
    final ttf = _parse('roboto.ttf');
    final duplicates = <int>[0x00af, 0x02c9];
    expect(
      ttf.charToGlyphIndexMap[duplicates[0]],
      ttf.charToGlyphIndexMap[duplicates[1]],
      reason: 'the test needs two characters that share a glyph',
    );

    final chars = <int>[0, 0x41, duplicates[0], duplicates[1], 0x42];
    final subset = _parse2(TtfWriter(ttf).withChars(chars));

    for (var cid = 1; cid < chars.length; cid++) {
      final source = ttf.charToGlyphIndexMap[chars[cid]]!;
      expect(
        subset.readGlyph(cid).data,
        ttf.readGlyph(source).data,
        reason: 'CID $cid must carry the glyph of its own character',
      );
    }
  });

  test('a document using canonical duplicates saves', () async {
    final font = Font.ttf(
      File('roboto.ttf').readAsBytesSync().buffer.asByteData(),
    );
    final document = Document(compress: false);
    document.addPage(
      Page(
        build: (Context context) =>
            Text('Δ∆¯ˉΩΩ', style: TextStyle(font: font, fontSize: 20)),
      ),
    );

    await expectLater(document.save(), completes);
  });

  test('unmapped codepoints do not collide on glyph 0', () async {
    // Every codepoint the font does not map resolves to glyph 0, so two of
    // them used to fight over the same subset slot.
    final font = Font.ttf(
      File('open-sans.ttf').readAsBytesSync().buffer.asByteData(),
    );
    final document = Document(compress: false);
    document.addPage(
      Page(
        build: (Context context) => Text(
          '\u{1F600}\u{1F601}️',
          style: TextStyle(font: font, fontSize: 20),
        ),
      ),
    );

    await expectLater(document.save(), completes);
  });

  test('a space is kept as its own empty glyph slot', () {
    final ttf = _parse('roboto.ttf');
    final chars = <int>[0, 0x41, 32, 0x42];
    final subset = _parse2(TtfWriter(ttf).withChars(chars));

    expect(subset.numGlyphs, greaterThanOrEqualTo(chars.length));
    expect(
      subset.readGlyph(3).data,
      ttf.readGlyph(ttf.charToGlyphIndexMap[0x42]!).data,
      reason: 'the character after a space keeps its glyph',
    );
  });

  test('a space is handled by a font that has no space glyph', () async {
    // material.ttf does not map U+0020 at all, so looking the glyph up with a
    // null assertion aborted with a null-check error.
    final ttf = _parse('material.ttf');
    expect(ttf.charToGlyphIndexMap[32], isNull);

    expect(
      () => TtfWriter(ttf).withChars(<int>[0, 32, 0xe000]),
      returnsNormally,
    );

    final font = Font.ttf(
      File('material.ttf').readAsBytesSync().buffer.asByteData(),
    );
    final document = Document(compress: false);
    document.addPage(
      Page(
        build: (Context context) =>
            Text('\ue000 \ue001', style: TextStyle(font: font, fontSize: 20)),
      ),
    );
    await expectLater(document.save(), completes);
  });

  test('a font without a glyf table still produces every CID slot', () {
    // emoji.ttf is a CBDT/CBLC bitmap font: it has no outlines at all, so
    // every glyph index is past the end of the (absent) loca table.
    final ttf = _parse('emoji.ttf');
    final chars = <int>[0, 0x41, 0x42, 0x43];
    final subset = _parse2(TtfWriter(ttf).withChars(chars));

    expect(subset.numGlyphs, greaterThanOrEqualTo(chars.length));
  });
}

TtfParser _parse2(Uint8List bytes) => TtfParser(ByteData.sublistView(bytes));
