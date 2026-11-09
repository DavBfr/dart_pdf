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

import 'package:pdf/pdf.dart';
import 'package:test/test.dart';

void main() {
  group('PdfStream', () {
    test('putStream copies written bytes, not spare capacity', () {
      final source = PdfStream()..putBytes([1, 2, 3]);
      final target = PdfStream()
        ..putByte(9)
        ..putStream(source)
        ..putByte(8);

      expect(target.offset, 5);
      expect(target.output(), [9, 1, 2, 3, 8]);
    });

    test('putStream also supports appending the stream to itself', () {
      final stream = PdfStream()..putBytes([1, 2, 3]);
      stream.putStream(stream);

      expect(stream.offset, 6);
      expect(stream.output(), [1, 2, 3, 1, 2, 3]);
    });
  });
}
