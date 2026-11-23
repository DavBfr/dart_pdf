/*
 * Copyright (C) 2026, phantome001 <phantome001@users.noreply.github.com>
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

import 'package:pdf/src/pdf/font/bidi_utils.dart' as bidi;
import 'package:test/test.dart';

void main() {
  group('basicToIsolatedMappings Arabic presentation forms', () {
    test('Alef maksura maps to its own isolated form', () {
      expect(bidi.basicToIsolatedMappings[0x0649], 0xFEEF);
    });

    test('Yeh maps to the Yeh isolated form', () {
      expect(bidi.basicToIsolatedMappings[0x064A], 0xFEF1);
    });

    test('Yeh does not reuse the Alef maksura isolated form', () {
      expect(bidi.basicToIsolatedMappings[0x064A], isNot(0xFEEF));
      expect(bidi.basicToIsolatedMappings[0x0649],
          isNot(bidi.basicToIsolatedMappings[0x064A]));
    });

    test('existing mappings remain intact', () {
      expect(bidi.basicToIsolatedMappings[0x0627], 0xFE8D);
      expect(bidi.basicToIsolatedMappings[0x0628], 0xFE8F);
      expect(bidi.basicToIsolatedMappings.length, greaterThan(25));
    });
  });
}
