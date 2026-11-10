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

import 'package:pdf/src/pdf/obj/unicode_cmap.dart';
import 'package:test/test.dart';

void main() {
  test('BMP code points are four hex digits', () {
    expect(utf16beHex(0x41), '0041');
    expect(utf16beHex(0x0915), '0915');
    expect(utf16beHex(0xFFFD), 'FFFD');
  });

  test('supplementary code points are a UTF-16BE surrogate pair', () {
    expect(utf16beHex(0x10000), 'D800DC00');
    expect(utf16beHex(0x1F600), 'D83DDE00');
    expect(utf16beHex(0x10FFFF), 'DBFFDFFF');
  });
}
