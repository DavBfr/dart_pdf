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
import 'package:test/test.dart';

void main() {
  late Uint8List fontBytes;

  setUpAll(() {
    fontBytes = File('open-sans.ttf').readAsBytesSync();
  });

  TtfParser parse(Uint8List bytes) =>
      TtfParser(Uint8List.fromList(bytes).buffer.asByteData());

  test('TTF subset remaps compound glyph components', () {
    final ttf = parse(fontBytes);
    final eAcute = ttf.charToGlyphIndexMap[0xe9]!;
    final components = ttf.readGlyph(eAcute).compounds;
    expect(components, isNotEmpty);

    final subset = parse(TtfWriter(ttf).withChars([0, 32, 0xe9, 0x65]));

    // Requested characters keep their position, components not requested
    // are appended after them.
    expect(subset.glyphOffsets.length, 4 + components.length - 1);
    final compound = subset.readGlyph(2);
    expect(compound.compounds, hasLength(components.length));
    for (var i = 0; i < components.length; i++) {
      final mapped = compound.compounds[i];
      expect(mapped, lessThan(subset.glyphOffsets.length));
      expect(subset.readGlyph(mapped).data, ttf.readGlyph(components[i]).data);
    }
    // The base letter is shared with the requested 'e' glyph.
    expect(compound.compounds, contains(3));
  });

  test('TTF subset handles a compound glyph that references itself', () {
    final ttf = parse(fontBytes);
    final eAcute = ttf.charToGlyphIndexMap[0xe9]!;
    expect(ttf.readGlyph(eAcute).compounds, isNotEmpty);

    // Point the first component of the compound glyph back to itself.
    final patched = Uint8List.fromList(fontBytes);
    final start =
        ttf.tableOffsets[TtfParser.glyf_table]! + ttf.glyphOffsets[eAcute];
    ByteData.sublistView(patched).setUint16(start + 12, eAcute);

    final subset = parse(TtfWriter(parse(patched)).withChars([0, 32, 0xe9]));
    expect(subset.readGlyph(2).compounds.first, 2);
  });
}
