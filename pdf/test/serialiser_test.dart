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
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/src/priv.dart';
import 'package:test/test.dart';

/// The bytes [value] serialises to.
List<int> stringBytes(String value) {
  final stream = PdfStream();
  PdfString.fromString(value).output(
    PdfObjectBase<PdfDataType>(
      objser: 1,
      params: const PdfNull(),
      settings: const PdfSettings(),
    ),
    stream,
  );
  return stream.output();
}

/// The bytes a name serialises to, as text.
String nameText(String value) {
  final stream = PdfStream();
  PdfName(value).output(
    PdfObjectBase<PdfDataType>(
      objser: 1,
      params: const PdfNull(),
      settings: const PdfSettings(),
    ),
    stream,
  );
  return latin1.decode(stream.output());
}

void main() {
  group('a PdfString', () {
    test('keeps a non-BMP character as a surrogate pair', () {
      // The encoder walked UTF-16 code units while its branch conditions were
      // written for code points, so every surrogate fell to the else and became
      // U+FFFD: an emoji in a title came out as two replacement characters.
      expect(stringBytes('\u{1F600}'), <int>[
        40,
        0xFE,
        0xFF,
        0xD8,
        0x3D,
        0xDE,
        0x00,
        41,
      ]);
      expect(stringBytes('\u{20BB7}'), <int>[
        40,
        0xFE,
        0xFF,
        0xD8,
        0x42,
        0xDF,
        0xB7,
        41,
      ]);
    });

    test('leaves a BMP string exactly as it was', () {
      expect(stringBytes('你好'), <int>[40, 254, 255, 79, 96, 89, 125, 41]);
    });

    test('still takes the Latin-1 path with no BOM', () {
      for (final value in <String>['test', 'Zoé']) {
        final bytes = stringBytes(value);
        expect(bytes, isNot(contains(0xFE)), reason: value);
        expect(bytes, isNot(contains(0xFF)), reason: value);
      }
    });

    test('replaces an unpaired surrogate with one character', () {
      expect(stringBytes(String.fromCharCode(0xD800)), <int>[
        40,
        0xFE,
        0xFF,
        0xFF,
        0xFD,
        41,
      ]);
    });

    test('always encodes an even number of bytes', () {
      for (final value in <String>[
        '\u{1F600}',
        'a\u{1F600}b',
        '你好',
        '\u{10FFFF}',
        'mixed 文字 \u{1F4A9}',
      ]) {
        // Minus the two parentheses, and minus the two BOM bytes.
        final bytes = stringBytes(value);
        expect((bytes.length - 2) % 2, 0, reason: value);
      }
    });

    test('reaches the document', () async {
      final document = PdfDocument(compress: false);
      PdfPage(document, pageFormat: PdfPageFormat.a4);
      document.info = PdfInfo(document, title: 'Invoice \u{1F600}');

      final bytes = await document.save();
      expect(bytes, containsAllInOrder(<int>[0xD8, 0x3D, 0xDE, 0x00]));
      expect(
        List<int>.generate(
          bytes.length - 1,
          (int i) => i,
        ).any((int i) => bytes[i] == 0xFF && bytes[i + 1] == 0xFD),
        isFalse,
        reason: 'no replacement character anywhere',
      );
    });
  });

  group('a PdfName', () {
    test('escapes the UTF-8 bytes of a non-ASCII character', () {
      // Each UTF-16 code unit was treated as a PDF byte, so '#' could be
      // followed by four hex digits - a name that reads back as something else -
      // and a non-BMP character emitted both of its surrogate halves.
      expect(nameText('/Accént'), '/Acc#c3#a9nt');
      expect(nameText('/yÿ'), '/y#c3#bf');
      expect(nameText('/Ch中'), '/Ch#e4#b8#ad');
      expect(nameText('/e\u{1F600}'), '/e#f0#9f#98#80');
    });

    test('never writes a # without exactly two hex digits', () {
      for (final value in <String>[
        '/Test',
        '/Accént',
        '/Ch中',
        '/e\u{1F600}',
        '/שלום',
        '/Type 1',
        '/Num#1',
      ]) {
        final text = nameText(value);
        for (final m in RegExp('#').allMatches(text)) {
          expect(
            text.substring(m.start, m.start + 3),
            matches(RegExp(r'^#[0-9a-f]{2}$')),
            reason: '$value -> $text',
          );
        }
      }
    });

    test('leaves ASCII exactly as it was', () {
      expect(nameText('/Test'), '/Test');
      expect(nameText('/Type 1'), '/Type#201');
      expect(nameText('/Num#1'), '/Num#231');
      expect(nameText('/a/b'), '/a#2fb');
    });

    test('refuses a null byte', () {
      expect(() => nameText('/a\u0000b'), throwsA(isA<PdfException>()));
    });
  });

  group('PdfStream.putStream', () {
    test('copies only the bytes the source holds', () {
      // It copied the backing array, which _ensureCapacity over-allocates in
      // 64KB steps - so a three-byte source arrived as 65536 bytes of which
      // 65533 were NUL.
      final source = PdfStream()..putString('abc');
      final destination = PdfStream()..putStream(source);

      expect(destination.offset, 3);
      expect(destination.output(), <int>[97, 98, 99]);
    });

    test('adds the source offset to the destination offset', () {
      for (final length in <int>[0, 1, 1000, 70000]) {
        final source = PdfStream()..putBytes(Uint8List(length));
        final destination = PdfStream()..putString('xy');

        destination.putStream(source);

        expect(destination.offset, 2 + length, reason: '$length');
        expect(destination.output(), hasLength(2 + length), reason: '$length');
      }
    });

    test('concatenates the two outputs', () {
      final a = PdfStream()..putString('hello ');
      final b = PdfStream()..putString('world');
      final both = PdfStream()
        ..putStream(a)
        ..putStream(b);

      expect(latin1.decode(both.output()), 'hello world');
    });

    test('splices a whole document without trailing NULs', () async {
      final document = PdfDocument(compress: false);
      PdfPage(document, pageFormat: PdfPageFormat.a4);
      final inner = PdfStream();
      await document.write(inner);

      final outer = PdfStream()..putStream(inner);

      expect(outer.offset, inner.offset);
      expect(latin1.decode(outer.output()).trimRight(), endsWith('%%EOF'));
      expect(outer.output().last, isNot(0));
    });
  });

  group('the xref stream field width', () {
    test('is the exact byte width of the largest offset', () {
      // ceil(log2(x)) is one bit short for a power of two, which crosses a byte
      // boundary at 2^8, 2^16 and 2^24 - so an xref stream starting exactly at
      // byte 65536 recorded its own offset as 65536 & 0xFFFF, which is 0.
      for (final entry in <int, int>{
        1: 1,
        255: 1,
        256: 2,
        65535: 2,
        65536: 3,
        16777215: 3,
        16777216: 4,
      }.entries) {
        expect(
          (entry.key.bitLength + 7) ~/ 8,
          entry.value,
          reason: '${entry.key}',
        );
      }
    });

    /// Where the xref stream of a document padded with [padding] bytes starts,
    /// and the whole file as text.
    Future<List<Object>> build(int padding) async {
      final document = PdfDocument(compress: false);
      final page = PdfPage(document, pageFormat: PdfPageFormat.a4);
      page.getGraphics()
        ..drawBox(const PdfRect(0, 0, 10, 10))
        ..setFillColor(PdfColors.red)
        ..fillPath();
      document.info = PdfInfo(document, title: 'x' * padding);

      final text = latin1.decode(await document.save(), allowInvalid: true);
      final startxref = int.parse(
        RegExp(r'startxref\s+(\d+)').allMatches(text).last.group(1)!,
      );

      return <Object>[startxref, text];
    }

    test('records an offset that is a power of 256 correctly', () async {
      // Pad the title until the xref stream starts at exactly byte 65536. One
      // more character of title is one more byte of file, so the first probe
      // says how much padding that needs.
      final base = (await build(0)).first as int;
      final want = 65536 - base;
      expect(
        want,
        greaterThan(0),
        reason: 'a blank document is already larger',
      );

      for (var padding = want - 40; padding <= want + 40; padding++) {
        final result = await build(padding);
        if (result.first != 65536) {
          continue;
        }

        final text = result.last as String;
        final w = RegExp(r'/W\[(\d+) (\d+) (\d+)\]').firstMatch(text)!;
        expect(
          int.parse(w.group(2)!),
          greaterThanOrEqualTo(3),
          reason: 'the offset field has to be able to hold 65536',
        );
        return;
      }

      fail('no padding near $want put the xref stream at byte 65536');
    });
  });
}
