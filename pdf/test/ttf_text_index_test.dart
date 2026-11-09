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
import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:test/test.dart';

void main() {
  test('TTF text reuses Unicode CIDs across repeated runs', () {
    final bytes = File('open-sans.ttf').readAsBytesSync();
    final font = PdfTtfFont(PdfDocument(), bytes.buffer.asByteData());
    expect(font.font.unicode, isTrue);

    final first = PdfStream();
    font.putText(first, 'אבבא');
    expect(latin1.decode(first.output()), '<0001000200020001>');
    expect(font.unicodeCMap.cmap, [0, 0x05d0, 0x05d1]);

    final second = PdfStream();
    font.putText(second, 'בא');
    expect(latin1.decode(second.output()), '<00020001>');
    expect(font.unicodeCMap.cmap.length, 3);

    // Direct append to the public cmap should remain compatible.
    font.unicodeCMap.cmap.add(0x05d2);
    final third = PdfStream();
    font.putText(third, 'ג');
    expect(latin1.decode(third.output()), '<0003>');
    expect(font.unicodeCMap.cmap.length, 4);
  });

  test('TTF text rejects CIDs beyond the two-byte range', () {
    final bytes = File('open-sans.ttf').readAsBytesSync();
    final font = PdfTtfFont(PdfDocument(), bytes.buffer.asByteData());

    // CID 0 is reserved, so 0xffff distinct runes fill CIDs 1..0xffff.
    final full = String.fromCharCodes(
      List.generate(0xffff, (i) => 0x10000 + i),
    );
    font.putText(PdfStream(), full);
    expect(font.unicodeCMap.cmap.length, 0x10000);

    expect(
      () => font.putText(PdfStream(), String.fromCharCode(0x30000)),
      throwsStateError,
    );
    // The rejected rune must not leave a dangling cmap entry.
    expect(font.unicodeCMap.cmap.length, 0x10000);
  });
}
