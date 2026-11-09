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

import 'package:pdf/src/priv.dart';
import 'package:test/test.dart';

void main() {
  PdfStream createXref({int leadingBytes = 0}) {
    final stream = PdfStream();
    if (leadingBytes > 0) {
      stream.putBytes(Uint8List(leadingBytes));
    }
    final root = PdfObjectBase(
      objser: 1,
      params: PdfDict(),
      settings: const PdfSettings(),
    );
    final xref = PdfXrefTable(lastObjectId: 2)..objects.add(root);
    xref.output(root, stream);
    return stream;
  }

  int startXref(PdfStream stream) {
    final text = latin1.decode(stream.output());
    final match = RegExp(r'startxref\s+(\d+)').firstMatch(text);
    expect(match, isNotNull);
    return int.parse(match!.group(1)!);
  }

  test('compressed xref offsets at powers of 256 use sufficient bytes', () {
    final baseOffset = startXref(createXref());

    for (final (targetOffset, expectedWidth) in [(256, 2), (65536, 3)]) {
      expect(baseOffset, lessThan(targetOffset));
      final stream = createXref(leadingBytes: targetOffset - baseOffset);
      expect(startXref(stream), targetOffset);

      final text = latin1.decode(stream.output());
      final width = RegExp(r'/W\s*\[\s*1\s+(\d+)\s+1\s*\]').firstMatch(text);
      expect(width, isNotNull);
      expect(int.parse(width!.group(1)!), expectedWidth);
    }
  });
}
