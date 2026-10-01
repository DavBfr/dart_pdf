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

import '../../base/exceptions.dart';

// The /WinAnsiEncoding table, which is what every simple font in this package
// declares in its font dictionary.
//
// Simple fonts used to be addressed as Latin-1. The two encodings agree
// everywhere but 0x80-0x9F, where Latin-1 has the C1 controls and WinAnsi has 27
// typographic glyphs - the dashes, the curly quotes, the bullet, the ellipsis,
// the euro and the trademark among them. Addressing a WinAnsi font as Latin-1
// therefore reported every one of those characters unsupported and let the C1
// controls through in their place.

/// The value used for a code WinAnsi leaves without a glyph, and returned by
/// [codeOfRune] for a rune the encoding cannot name.
const int undefined = -1;

/// The 27 codes where WinAnsi differs from Latin-1.
///
/// PDF 32000-1 Annex D.2. The five codes it omits - 0x81, 0x8D, 0x8F, 0x90 and
/// 0x9D - have no glyph in WinAnsi at all.
const Map<int, int> _c1 = <int, int>{
  0x80: 0x20AC, // Euro
  0x82: 0x201A, // quotesinglbase
  0x83: 0x0192, // florin
  0x84: 0x201E, // quotedblbase
  0x85: 0x2026, // ellipsis
  0x86: 0x2020, // dagger
  0x87: 0x2021, // daggerdbl
  0x88: 0x02C6, // circumflex
  0x89: 0x2030, // perthousand
  0x8A: 0x0160, // Scaron
  0x8B: 0x2039, // guilsinglleft
  0x8C: 0x0152, // OE
  0x8E: 0x017D, // Zcaron
  0x91: 0x2018, // quoteleft
  0x92: 0x2019, // quoteright
  0x93: 0x201C, // quotedblleft
  0x94: 0x201D, // quotedblright
  0x95: 0x2022, // bullet
  0x96: 0x2013, // endash
  0x97: 0x2014, // emdash
  0x98: 0x02DC, // tilde
  0x99: 0x2122, // trademark
  0x9A: 0x0161, // scaron
  0x9B: 0x203A, // guilsinglright
  0x9C: 0x0153, // oe
  0x9E: 0x017E, // zcaron
  0x9F: 0x0178, // Ydieresis
};

/// The Unicode rune each of the 256 WinAnsi codes stands for, or [undefined].
///
/// Outside 0x80-0x9F the code is the rune, which is what makes the encoding
/// look like Latin-1 for most text.
final List<int> runeOfCode = List<int>.generate(
  256,
  (int code) => code >= 0x80 && code <= 0x9F ? (_c1[code] ?? undefined) : code,
  growable: false,
);

final Map<int, int> _codeOfRune = <int, int>{
  for (var code = 0; code < runeOfCode.length; code++)
    if (runeOfCode[code] != undefined) runeOfCode[code]: code,
};

/// The WinAnsi code for [rune], or [undefined] if the encoding has no glyph for
/// it.
int codeOfRune(int rune) => _codeOfRune[rune] ?? undefined;

/// Encode [text] as WinAnsi bytes, one per rune.
///
/// Throws a [PdfException] naming the first rune the encoding cannot express.
Uint8List encode(String text) {
  final runes = text.runes;
  final out = Uint8List(runes.length);

  var i = 0;
  for (final rune in runes) {
    final code = codeOfRune(rune);
    if (code == undefined) {
      throw PdfException(
        'Cannot encode U+${rune.toRadixString(16).toUpperCase().padLeft(4, '0')} '
        'with WinAnsiEncoding. This font covers the WinAnsi character set only. '
        'To use other characters, use a TrueType (TTF) font instead. '
        'See https://github.com/DavBfr/dart_pdf/wiki/Fonts-Management',
      );
    }
    out[i++] = code;
  }

  return out;
}
