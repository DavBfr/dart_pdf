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

// Text segmentation for the line breaker: which code points are invisible and
// where a line may be broken.

/// Whether [rune] has the Unicode `Default_Ignorable_Code_Point` property.
///
/// These are the invisible formatting characters - soft hyphen, zero-width
/// space, the joiners, the bidi marks and controls, the variation selectors and
/// the fillers. A renderer must not draw them and must not draw anything in
/// their place. The text layout used to treat every one of them as ordinary
/// text: with no font covering it the character became a crossed-box
/// placeholder, and with one - open-sans has a glyph for U+00AD - it was
/// measured and painted as a real hyphen.
bool isDefaultIgnorable(int rune) {
  // Cheap reject for the overwhelming majority of text.
  if (rune < 0x00AD) {
    return false;
  }

  switch (rune) {
    case 0x00AD: // SOFT HYPHEN
    case 0x034F: // COMBINING GRAPHEME JOINER
    case 0x061C: // ARABIC LETTER MARK
    case 0x3164: // HANGUL FILLER
    case 0xFEFF: // ZERO WIDTH NO-BREAK SPACE
    case 0xFFA0: // HALFWIDTH HANGUL FILLER
      return true;
  }

  return (rune >= 0x115F && rune <= 0x1160) || // Hangul fillers
      (rune >= 0x17B4 && rune <= 0x17B5) || // Khmer inherent vowels
      (rune >= 0x180B && rune <= 0x180F) || // Mongolian variation selectors
      (rune >= 0x200B && rune <= 0x200F) || // ZWSP, ZWNJ, ZWJ, LRM, RLM
      (rune >= 0x202A && rune <= 0x202E) || // bidi embedding controls
      (rune >= 0x2060 && rune <= 0x206F) || // word joiner, bidi isolates
      (rune >= 0xFE00 && rune <= 0xFE0F) || // variation selectors
      (rune >= 0xFFF0 && rune <= 0xFFF8) ||
      (rune >= 0x1BCA0 && rune <= 0x1BCA3) || // shorthand format controls
      (rune >= 0x1D173 && rune <= 0x1D17A) || // musical format controls
      (rune >= 0xE0000 && rune <= 0xE0FFF); // tags, variation selectors sup.
}

/// [text] with every default-ignorable code point removed.
///
/// Returns [text] itself when there is nothing to remove, which is the common
/// case, so ordinary text costs one scan and no allocation.
String stripDefaultIgnorable(String text, {Set<int> keep = const <int>{}}) {
  StringBuffer? out;
  var start = 0;
  var at = 0;

  for (final rune in text.runes) {
    final length = rune > 0xFFFF ? 2 : 1;
    if (isDefaultIgnorable(rune) && !keep.contains(rune)) {
      out ??= StringBuffer();
      out.write(text.substring(start, at));
      start = at + length;
    }
    at += length;
  }

  if (out == null) {
    return text;
  }

  out.write(text.substring(start));
  return out.toString();
}
