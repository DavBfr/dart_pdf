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

import 'dart:typed_data';

import 'ttf_parser.dart';

class TtcParser {
  TtcParser(ByteData bytes) : bytes = UnmodifiableByteDataView(bytes) {
    final tag = bytes.getUint32(0);
    if (tag != 0x74746366) {
      throw Exception('Not a TrueType Collection');
    }

    final majorVersion = bytes.getUint16(4);
    final minorVersion = bytes.getUint16(6);

    if ((majorVersion != 2 && majorVersion != 1) || minorVersion != 0) {
      throw Exception(
          'Unsupported TrueType Collection version $majorVersion.$minorVersion');
    }
  }

  final UnmodifiableByteDataView bytes;

  int get numFonts => bytes.getUint32(8);

  TtfParser getFont(int index) => TtfParser(bytes.buffer
      .asByteData(bytes.offsetInBytes + bytes.getUint32(index * 4 + 12)));
}
