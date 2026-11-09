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
}
