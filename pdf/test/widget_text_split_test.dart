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
import 'package:pdf/widgets.dart';
import 'package:test/test.dart';

late Font astralFont;

void main() {
  setUpAll(() {
    astralFont = Font.ttf(
      File('genyomintw.ttf').readAsBytesSync().buffer.asByteData(),
    );
  });

  test('a word of non-BMP runes splits on rune boundaries', () async {
    // Twelve U+1F110 are 24 UTF-16 code units, so a binary search over code
    // units lands between a surrogate pair about half the time. Both halves
    // then carry an unpaired surrogate, which no font can map: saving used to
    // throw 'Missing glyph for character U+D83C'.
    final document = Document(compress: false);
    document.addPage(
      Page(
        pageFormat: const PdfPageFormat(120, 400, marginAll: 0),
        theme: ThemeData.withFont(base: astralFont),
        build: (Context context) =>
            Text('\u{1F110}' * 12, style: const TextStyle(fontSize: 20)),
      ),
    );

    await expectLater(document.save(), completes);
  });

  test('every split of a non-BMP word stays well formed', () async {
    // Sweep the widths so the search stops at many different offsets.
    for (var width = 40.0; width <= 200.0; width += 7) {
      final document = Document(compress: false);
      document.addPage(
        Page(
          pageFormat: PdfPageFormat(width, 400, marginAll: 0),
          theme: ThemeData.withFont(base: astralFont),
          build: (Context context) =>
              Text('\u{1F110}' * 9, style: const TextStyle(fontSize: 18)),
        ),
      );
      await expectLater(
        document.save(),
        completes,
        reason: 'width $width must not cut a surrogate pair',
      );
    }
  });

  test('a word that fits is not split because of leading whitespace', () async {
    // Helvetica at 20pt makes 'ABCDEFGH' 111.12pt wide and a space 5.56pt, so
    // the word fits a 113pt page but ' ABCDEFGH' does not. The word used to be
    // hard-split into 'ABCDEFG' and 'H'.
    final document = Document(compress: false);
    document.addPage(
      Page(
        pageFormat: const PdfPageFormat(113, 400, marginAll: 0),
        build: (Context context) => RichText(
          text: const TextSpan(
            text: ' ABCDEFGH',
            style: TextStyle(fontSize: 20),
          ),
        ),
      ),
    );

    final text = latin1.decode(await document.save(), allowInvalid: true);
    expect(text, contains('(ABCDEFGH)'));
  });
}
