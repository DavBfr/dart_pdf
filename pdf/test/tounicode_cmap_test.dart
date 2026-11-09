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

import 'package:pdf/pdf.dart';
import 'package:pdf/src/pdf/obj/unicode_cmap.dart';
import 'package:test/test.dart';

void main() {
  test('ToUnicode maps large Hebrew character sets in 100-entry blocks', () {
    final map = PdfUnicodeCmap(PdfDocument(), false);
    map.cmap.addAll(List<int>.generate(204, (i) => 0x05d0 + i));
    map.cmap.add(0x1f642); // A supplementary-plane Unicode scalar.
    map.prepare();

    final content = ascii.decode(map.buf.output());
    final entries = RegExp(
      r'(\d+) beginbfchar',
    ).allMatches(content).map((match) => int.parse(match.group(1)!)).toList();
    expect(entries, [100, 100, 6]);
    expect(RegExp(r'endbfchar').allMatches(content).length, 3);
    expect(content, contains('<0001> <05D0>'));
    expect(content, contains('<00CD> <D83DDE42>'));
  });

  test('protect masks only the output and preserves the glyph mapping', () {
    final map = PdfUnicodeCmap(PdfDocument(), true);
    map.cmap.addAll([0x05d0, 0x05d1, 0x1f642]);
    final original = List<int>.from(map.cmap);
    map.prepare();

    final content = ascii.decode(map.buf.output());
    expect(map.cmap, original);
    expect(content, contains('<0001> <0020>'));
    expect(content, contains('<0002> <0020>'));
    expect(content, contains('<0003> <0020>'));
  });

  test('ToUnicode block boundaries and UTF-16 edge values', () {
    List<int> blocks(int length) {
      final map = PdfUnicodeCmap(PdfDocument(), false);
      map.cmap.addAll(List<int>.filled(length - 1, 0x41));
      map.prepare();
      return RegExp(r'(\d+) beginbfchar')
          .allMatches(ascii.decode(map.buf.output()))
          .map((match) => int.parse(match.group(1)!))
          .toList();
    }

    expect(blocks(100), [100]);
    expect(blocks(101), [100, 1]);

    final map = PdfUnicodeCmap(PdfDocument(), false);
    map.cmap.addAll([0xffff, 0x10000, 0x10ffff]);
    map.prepare();
    final content = ascii.decode(map.buf.output());
    expect(content, contains('<0001> <FFFF>'));
    expect(content, contains('<0002> <D800DC00>'));
    expect(content, contains('<0003> <DBFFDFFF>'));
  });
}
