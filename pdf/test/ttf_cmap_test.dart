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
import 'package:test/test.dart';

/// One record of a cmap table, ready to be assembled.
class _Subtable {
  _Subtable({
    required this.platformId,
    required this.encodingId,
    required this.body,
  });

  final int platformId;
  final int encodingId;

  /// The subtable itself, starting at its format field.
  final Uint8List body;
}

/// A format 0 subtable whose glyph for byte i is `glyphs[i]`.
Uint8List _format0(List<int> glyphs) {
  final body = Uint8List(262);
  final view = ByteData.view(body.buffer);
  view.setUint16(0, 0); // format
  view.setUint16(2, 262); // length
  view.setUint16(4, 0); // language
  for (var i = 0; i < 256; i++) {
    body[6 + i] = i < glyphs.length ? glyphs[i] : 0;
  }
  return body;
}

/// A format 4 subtable holding one real segment plus the required terminator.
///
/// When [glyphIdArray] is null the segment maps through idDelta alone;
/// otherwise it maps through the glyph id array, which is where idDelta used to
/// be forgotten.
Uint8List _format4({
  required int startCode,
  required int endCode,
  required int idDelta,
  List<int>? glyphIdArray,
}) {
  // Two segments: the real one, and the 0xFFFF terminator every format 4
  // subtable must end with.
  const segCount = 2;
  final glyphs = glyphIdArray ?? const <int>[];
  final length = 16 + segCount * 8 + glyphs.length * 2;

  final body = Uint8List(length);
  final view = ByteData.view(body.buffer);

  view.setUint16(0, 4); // format
  view.setUint16(2, length);
  view.setUint16(4, 0); // language
  view.setUint16(6, segCount * 2); // segCountX2
  view.setUint16(8, 0); // searchRange
  view.setUint16(10, 0); // entrySelector
  view.setUint16(12, 0); // rangeShift

  // endCode[], then a pad, then startCode[], idDelta[], idRangeOffset[].
  const endBase = 14;
  const startBase = endBase + segCount * 2 + 2;
  const deltaBase = startBase + segCount * 2;
  const rangeBase = deltaBase + segCount * 2;

  view.setUint16(endBase, endCode);
  view.setUint16(endBase + 2, 0xFFFF);
  view.setUint16(startBase, startCode);
  view.setUint16(startBase + 2, 0xFFFF);
  view.setUint16(deltaBase, idDelta);
  view.setUint16(deltaBase + 2, 1);

  if (glyphIdArray == null) {
    view.setUint16(rangeBase, 0);
  } else {
    // The offset is measured from the idRangeOffset entry itself: past both
    // entries of the array, to the first glyph id.
    view.setUint16(rangeBase, segCount * 2);
  }
  view.setUint16(rangeBase + 2, 0);

  for (var i = 0; i < glyphs.length; i++) {
    view.setUint16(rangeBase + segCount * 2 + i * 2, glyphs[i]);
  }

  return body;
}

/// Assemble the smallest sfnt TtfParser accepts, with the given cmap records.
Uint8List _font(List<_Subtable> subtables) {
  // head, name, hmtx, hhea, cmap, maxp: the six TtfParser insists on. Only cmap
  // has meaningful content here.
  final cmapHeader = 4 + subtables.length * 8;
  final cmap = BytesBuilder();
  final header = Uint8List(cmapHeader);
  final headerView = ByteData.view(header.buffer);
  headerView.setUint16(0, 0); // version
  headerView.setUint16(2, subtables.length);

  var offset = cmapHeader;
  for (var i = 0; i < subtables.length; i++) {
    headerView.setUint16(4 + i * 8, subtables[i].platformId);
    headerView.setUint16(6 + i * 8, subtables[i].encodingId);
    headerView.setUint32(8 + i * 8, offset);
    offset += subtables[i].body.length;
  }
  cmap.add(header);
  for (final subtable in subtables) {
    cmap.add(subtable.body);
  }
  final cmapBytes = cmap.toBytes();

  final tables = <String, Uint8List>{
    'cmap': cmapBytes,
    'head': Uint8List(54),
    'hhea': Uint8List(36),
    'hmtx': Uint8List(4),
    'maxp': Uint8List(32),
    'name': Uint8List(6),
  };

  final directory = 12 + tables.length * 16;
  final out = Uint8List(
    directory +
        tables.values.fold<int>(0, (int a, Uint8List b) => a + b.length),
  );
  final view = ByteData.view(out.buffer);

  view.setUint32(0, 0x00010000); // sfnt version
  view.setUint16(4, tables.length);

  var entry = 12;
  var body = directory;
  tables.forEach((String name, Uint8List content) {
    out.setRange(entry, entry + 4, name.codeUnits);
    view.setUint32(entry + 8, body);
    view.setUint32(entry + 12, content.length);
    out.setRange(body, body + content.length, content);
    entry += 16;
    body += content.length;
  });

  return out;
}

TtfParser _parse(List<_Subtable> subtables) =>
    TtfParser(ByteData.view(_font(subtables).buffer));

/// Every font the package bundles for its tests.
const _bundled = <String>[
  'open-sans',
  'open-sans-bold',
  'roboto',
  'noto-sans',
  'genyomintw',
  'hacen-tunisia',
  'material',
  'emoji',
];

TtfParser _bundledFont(String name) {
  final data = File('$name.ttf').readAsBytesSync();
  return TtfParser(data.buffer.asByteData());
}

void main() {
  group('format 0', () {
    test('maps each byte to its own glyph', () {
      // The header is format, length and language, so the array starts six
      // bytes in. It used to be read four bytes in, so every character came
      // back as the glyph of the character two after it: 'ABC abc' rendered as
      // '?@A _`a'.
      final font = _parse(<_Subtable>[
        _Subtable(
          platformId: 1,
          encodingId: 0,
          body: _format0(List<int>.generate(256, (int i) => i)),
        ),
      ]);

      // Keyed through Mac OS Roman, so only the ASCII half keeps its code.
      expect(font.charToGlyphIndexMap[65], 65);
      expect(font.charToGlyphIndexMap[66], 66);
      expect(font.charToGlyphIndexMap[97], 97);
      expect(font.charToGlyphIndexMap.containsKey(0), isFalse);
      expect(font.charToGlyphIndexMap, hasLength(255));
    });

    test('a subtable with the wrong length is skipped', () {
      final body = _format0(List<int>.generate(256, (int i) => i));
      ByteData.view(body.buffer).setUint16(2, 300);

      final font = _parse(<_Subtable>[
        _Subtable(platformId: 1, encodingId: 0, body: body),
      ]);

      expect(font.charToGlyphIndexMap, isEmpty);
    });

    test('a truncated subtable is skipped', () {
      final full = _format0(List<int>.generate(256, (int i) => i));
      final truncated = Uint8List.sublistView(full, 0, 100);

      final font = _parse(<_Subtable>[
        _Subtable(platformId: 1, encodingId: 0, body: truncated),
      ]);

      expect(font.charToGlyphIndexMap, isEmpty);
    });
  });

  group('format 4', () {
    test('applies idDelta to a glyph id array lookup', () {
      // U+0041 to U+0045, idDelta 100, and a zero hole at U+0043.
      final font = _parse(<_Subtable>[
        _Subtable(
          platformId: 3,
          encodingId: 1,
          body: _format4(
            startCode: 0x41,
            endCode: 0x45,
            idDelta: 100,
            glyphIdArray: <int>[1, 2, 0, 4, 5],
          ),
        ),
      ]);

      final map = font.charToGlyphIndexMap;
      expect(map[0x41], 101);
      expect(map[0x42], 102);
      expect(
        map.containsKey(0x43),
        isFalse,
        reason: 'format 4 defines zero as not covered',
      );
      expect(map[0x44], 104);
      expect(map[0x45], 105);
    });

    test('idDelta wraps at 65536', () {
      final font = _parse(<_Subtable>[
        _Subtable(
          platformId: 3,
          encodingId: 1,
          body: _format4(
            startCode: 0x41,
            endCode: 0x41,
            idDelta: 65500,
            glyphIdArray: <int>[100],
          ),
        ),
      ]);

      expect(font.charToGlyphIndexMap[0x41], (100 + 65500) % 65536);
    });

    test('a segment with no glyph id array is unchanged', () {
      final font = _parse(<_Subtable>[
        _Subtable(
          platformId: 3,
          encodingId: 1,
          body: _format4(startCode: 0x41, endCode: 0x43, idDelta: 100),
        ),
      ]);

      final map = font.charToGlyphIndexMap;
      expect(map[0x41], 0x41 + 100);
      expect(map[0x43], 0x43 + 100);
    });
  });

  group('subtable selection', () {
    test('a Unicode subtable beats a Macintosh one', () {
      // Whichever order they are listed in: it used to be whichever came last.
      for (final macFirst in <bool>[true, false]) {
        final mac = _Subtable(
          platformId: 1,
          encodingId: 0,
          body: _format0(List<int>.generate(256, (int i) => 200)),
        );
        final unicode = _Subtable(
          platformId: 3,
          encodingId: 1,
          body: _format4(startCode: 0x41, endCode: 0x41, idDelta: 0),
        );

        final font = _parse(
          macFirst ? <_Subtable>[mac, unicode] : <_Subtable>[unicode, mac],
        );

        expect(
          font.charToGlyphIndexMap[0x41],
          0x41,
          reason: 'mac first: $macFirst',
        );
        expect(font.charToGlyphIndexMap, hasLength(1));
      }
    });

    test('a format 12 Unicode subtable beats a format 4 one', () {
      final font = _parse(<_Subtable>[
        _Subtable(
          platformId: 3,
          encodingId: 1,
          body: _format4(startCode: 0x41, endCode: 0x41, idDelta: 0),
        ),
        _Subtable(
          platformId: 3,
          encodingId: 10,
          body: _format4(startCode: 0x41, endCode: 0x41, idDelta: 500),
        ),
      ]);

      // Both are format 4 here, so (3,1) still wins; the point is that exactly
      // one of them contributes.
      expect(font.charToGlyphIndexMap, hasLength(1));
      expect(font.charToGlyphIndexMap[0x41], 0x41);
    });

    test('a Macintosh subtable is keyed through Mac OS Roman', () {
      final glyphs = List<int>.filled(256, 0);
      glyphs[0xD5] = 42; // the right single quote in Mac OS Roman
      glyphs[0x41] = 7; // and plain ASCII 'A'

      final font = _parse(<_Subtable>[
        _Subtable(platformId: 1, encodingId: 0, body: _format0(glyphs)),
      ]);

      final map = font.charToGlyphIndexMap;
      expect(map[0x2019], 42, reason: 'not U+00D5');
      expect(map.containsKey(0xD5), isFalse);
      expect(map[0x41], 7, reason: 'the ASCII half is unchanged');
    });

    test('a symbol subtable is reachable by its low byte too', () {
      final font = _parse(<_Subtable>[
        _Subtable(
          platformId: 3,
          encodingId: 0,
          body: _format4(startCode: 0xF041, endCode: 0xF041, idDelta: 0),
        ),
      ]);

      final map = font.charToGlyphIndexMap;
      expect(map[0xF041], 0xF041);
      expect(map[0x41], 0xF041, reason: "so drawString('A') finds a glyph");
    });

    test('an encoding that cannot be keyed as Unicode is left alone', () {
      // A ShiftJIS subtable: its keys are neither Unicode nor translatable
      // here, so nothing is mapped and the runes route to fontFallback rather
      // than drawing the wrong glyph.
      final font = _parse(<_Subtable>[
        _Subtable(
          platformId: 3,
          encodingId: 2,
          body: _format4(startCode: 0x41, endCode: 0x41, idDelta: 0),
        ),
      ]);

      expect(font.charToGlyphIndexMap, isEmpty);
    });
  });

  group('the bundled fonts', () {
    test('never map a character to glyph zero', () {
      // Which is what makes containsKey a truthful coverage test, and
      // isRuneSupported answer honestly.
      for (final name in _bundled) {
        expect(
          _bundledFont(name).charToGlyphIndexMap.values,
          isNot(contains(0)),
          reason: name,
        );
      }
    });

    test('Unicode-only fonts are unchanged', () {
      // Recorded from the parser before the change, so a regression in the
      // selection ranking shows up here.
      const expected = <String, int>{
        'open-sans': 883,
        'open-sans-bold': 883,
        'roboto': 878,
        'noto-sans': 2299,
        'genyomintw': 31143,
        'material': 2226,
        'emoji': 1501,
      };

      expected.forEach((String name, int entries) {
        expect(
          _bundledFont(name).charToGlyphIndexMap,
          hasLength(entries),
          reason: name,
        );
      });

      final openSans = _bundledFont('open-sans').charToGlyphIndexMap;
      expect(openSans[0x41], 36);
      expect(openSans[0x61], 67);
      expect(openSans[0xAA], 107, reason: 'a real U+00AA, from Unicode');
      expect(openSans[0x2122], 528);

      final roboto = _bundledFont('roboto').charToGlyphIndexMap;
      expect(roboto[0x41], 35);
      expect(roboto[0x2122], 383);
    });

    test('hacen-tunisia no longer lets its Mac subtable win', () {
      // It carries both a Unicode and a Macintosh subtable. The Mac bytes 0xAA,
      // 0xA1 and 0xA5 used to land on U+00AA, U+00A1 and U+00A5 and shadow the
      // Unicode entries, so Text('ª') drew the trademark glyph and a document
      // holding both threw 'Missing glyph for character'.
      final map = _bundledFont('hacen-tunisia').charToGlyphIndexMap;

      expect(map.containsKey(0x00AA), isFalse);
      expect(map.containsKey(0x00A1), isFalse);
      expect(map.containsKey(0x00A5), isFalse);
      expect(map[0x2122], 178);
      expect(map[0x00B0], 357);
      expect(map[0x2022], 177);
    });
  });
}
