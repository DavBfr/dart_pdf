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

import 'base.dart';
import 'stream.dart';

class PdfName extends PdfDataType {
  const PdfName(this.value);

  final String value;

  @override
  void output(PdfStream s, [int? indent]) {
    assert(value[0] == '/');
    final bytes = <int>[];
    for (final c in value.codeUnits) {
      assert(c < 0xff && c > 0x00);

      if (c < 0x21 ||
          c > 0x7E ||
          c == 0x23 ||
          (c == 0x2f && bytes.isNotEmpty) ||
          c == 0x5b ||
          c == 0x5d ||
          c == 0x28 ||
          c == 0x3c ||
          c == 0x3e) {
        bytes.add(0x23);
        final x = c.toRadixString(16).padLeft(2, '0');
        bytes.addAll(x.codeUnits);
      } else {
        bytes.add(c);
      }
    }
    s.putBytes(bytes);
  }

  @override
  bool operator ==(Object other) {
    if (other is PdfName) {
      return value == other.value;
    }

    return false;
  }

  @override
  int get hashCode => value.hashCode;
}
