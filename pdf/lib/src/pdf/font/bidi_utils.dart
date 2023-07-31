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


/// Arabic characters that have different unicode values
/// but should point to the same glyph.
const Map<int, int> basicToIsolatedMappings = {
  0x0627: 0xFE8D,  // ا
  0x0628: 0xFE8F,  // ب
  0x062A: 0xFE95,  // ت
  0x062B: 0xFE99,  // ث
  0x062C: 0xFE9D,  // ج
  0x062D: 0xFEA1,  // ح
  0x062E: 0xFEA5,  // خ
  0x062F: 0xFEA9,  // د
  0x0630: 0xFEAB,  // ذ
  0x0631: 0xFEAD,  // ر
  0x0632: 0xFEAF,  // ز
  0x0633: 0xFEB1,  // س
  0x0634: 0xFEB5,  // ش
  0x0635: 0xFEB9,  // ص
  0x0636: 0xFEBD,  // ض
  0x0637: 0xFEC1,  // ط
  0x0638: 0xFEC5,  // ظ
  0x0639: 0xFEC9,  // ع
  0x063A: 0xFECD,  // غ
  0x0641: 0xFED1,  // ف
  0x0642: 0xFED5,  // ق
  0x0643: 0xFED9,  // ك
  0x0644: 0xFEDD,  // ل
  0x0645: 0xFEE1,  // م
  0x0646: 0xFEE5,  // ن
  0x0647: 0xFEE9,  // ه
  0x0648: 0xFEED,  // و
  0x064A: 0xFEEF,  // ي
  0x0621: 0xFE80,  // ء
  0x0622: 0xFE81,  // آ
  0x0623: 0xFE83,  // أ
  0x0624: 0xFE85,  // ؤ
  0x0625: 0xFE87,  // إ
  0x0626: 0xFE89,  // ئ
  0x0629: 0xFE93,  // ة
};


/// Applies THE BIDIRECTIONAL ALGORITHM using (https://pub.dev/packages/bidi)
String logicalToVisual(String input) {
  final buffer = StringBuffer();
  final paragraphs = bidi.splitStringToParagraphs(input);
  for (final paragraph in paragraphs) {
    final endsWithNewLine = paragraph.separator == 10;
    final endIndex = paragraph.bidiText.length - (endsWithNewLine ? 1 : 0);
    final visual = String.fromCharCodes(paragraph.bidiText, 0, endIndex);
    buffer.write(visual.split(' ').reversed.join(' '));
    if (endsWithNewLine) {
      buffer.writeln();
    }
  }
  return buffer.toString();
}
