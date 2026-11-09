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
  test('TTF subset writes valid sfnt binary-search header fields', () {
    final fontBytes = File('open-sans.ttf').readAsBytesSync();
    final parser = TtfParser(fontBytes.buffer.asByteData());
    final bytes = TtfWriter(parser).withChars('Hello'.runes.toList());
    final header = ByteData.sublistView(bytes);

    final numTables = header.getUint16(4);
    expect(numTables, greaterThan(0));

    var powerOfTwo = 1;
    var log2 = 0;
    while (powerOfTwo * 2 <= numTables) {
      powerOfTwo *= 2;
      log2++;
    }

    expect(header.getUint16(6), powerOfTwo * 16);
    expect(header.getUint16(8), log2);
    expect(header.getUint16(10), numTables * 16 - powerOfTwo * 16);
  });
}
