import 'package:bidi/bidi.dart' as bidi;
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

const Map<int, int> _arabicDiacritics = <int, int>{
  0x064B: 0x064B, // Fathatan
  0x064C: 0x064C, // Dammatan
  0x064D: 0x064D, // Kasratan
  0x064E: 0x064E, // Fatha
  0x064F: 0x064F, // Damma
  0x0650: 0x0650, // Kasra
  0x0651: 0x0651, // Shadda
  0x0652: 0x0652, // Sukun
  0x0670: 0x0670, // Dagger alif
  0xFC5E: 0xFC5E, // Shadda + Dammatan
  0xFC5F: 0xFC5F, // Shadda + Kasratan
  0xFC60: 0xFC60, // Shadda + Fatha
  0xFC61: 0xFC61, // Shadda + Damma
  0xFC62: 0xFC62, // Shadda + Kasra
  0xFC63: 0xFC63, // Shadda + Dagger alif
  // 1548: 1548,
};

bool isArabicDiacriticValue(int letter) {
  return _arabicDiacritics.containsValue(letter);
}

/// Applies THE BIDIRECTIONAL ALGORITHM using (https://pub.dev/packages/bidi)
String logicalToVisual(String input) {
  final buffer = StringBuffer();
  final paragraphs = bidi.splitStringToParagraphs(input);
  for (final paragraph in paragraphs) {
    final endsWithNewLine = paragraph.paragraphSeparator == 10;
    final endIndex = paragraph.bidiText.length - (endsWithNewLine ? 1 : 0);
    final visual = String.fromCharCodes(paragraph.bidiText, 0, endIndex);
    buffer.write(visual.split(' ').reversed.join(' '));
    if (endsWithNewLine) {
      buffer.writeln();
    }
  }
  return buffer.toString();
}
