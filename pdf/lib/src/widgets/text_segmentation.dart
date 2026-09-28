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

/// Every whitespace character the text layout handles, breakable or not.
///
/// Dart's `\s` without U+FEFF, which [stripDefaultIgnorable] has already
/// removed by the time any of this runs.
final RegExp whitespace = RegExp(r'[ \t\n\v\f\r\u0085   -     　]');

/// Whitespace at which a line may be broken.
///
/// [whitespace] minus U+00A0, U+2007 and U+202F. Those three are non-breaking
/// by definition - UAX #14 gives them the GL class - and are the documented way
/// to hold two words together, yet Dart's `\s` matches all of them, so the
/// default splitter broke lines at exactly the characters an author reaches for
/// to stop it. U+FEFF, the fourth, is dropped as a default ignorable.
final RegExp breakableWhitespace = RegExp(r'[ \t\n\v\f\r\u0085  -  -    　]');

/// The default ignorables the tokenizer consumes itself.
///
/// A soft hyphen and a zero-width space are break opportunities, and a word
/// joiner takes one away, so they have to survive [stripDefaultIgnorable] and
/// reach [tokenize], which drops them once it has read them.
const Set<int> breakControls = <int>{0x00AD, 0x200B, 0x2060};

/// Somewhere inside a run where a line may be broken.
class TextBreak {
  const TextBreak(this.offset, {this.hyphen = false});

  /// Where the tail begins, as a UTF-16 offset into the run's text.
  final int offset;

  /// Whether taking this break has to put a hyphen at the end of the head.
  ///
  /// True for a soft hyphen, which is drawn only where it is used.
  final bool hyphen;

  @override
  String toString() => 'TextBreak($offset${hyphen ? ' + hyphen' : ''})';
}

/// A run of text and the whitespace that follows it.
class TextChunk {
  const TextChunk(
    this.text,
    this.separator, [
    this.breaks = const <TextBreak>[],
  ]);

  /// What is drawn, if the whole run fits on the line.
  final String text;

  /// The whitespace between this run and the next, empty at the end of a line.
  ///
  /// It is never drawn: it only advances the pen, by its own width in the font
  /// being used rather than by a U+0020's.
  final String separator;

  /// Where the run itself may be broken, in ascending order.
  final List<TextBreak> breaks;

  @override
  String toString() =>
      'TextChunk("$text" + ${separator.length} separator, $breaks)';
}

/// The characters that can start or stop a break inside a run.
final RegExp _mayBreak = RegExp(r'[\u002D\u00AD\u200B\u2010\u2060]');

/// Find the break opportunities inside one whitespace-delimited run, and drop
/// the invisible characters that mark them.
///
/// An overflowing run used to fall straight to a width search with no notion of
/// where a break belongs, so a hyphenated word was cut wherever the search
/// landed, a soft hyphen was drawn as a real hyphen and never broke, and a
/// zero-width space did nothing at all.
TextChunk _withBreaks(String run, String separator) {
  if (!_mayBreak.hasMatch(run)) {
    return TextChunk(run, separator);
  }

  final text = StringBuffer();
  final breaks = <TextBreak>[];

  for (var i = 0; i < run.length; i++) {
    final unit = run.codeUnitAt(i);

    // A word joiner right after a candidate forbids the break there. It is a
    // default ignorable, so it is dropped either way.
    final joined = i + 1 < run.length && run.codeUnitAt(i + 1) == 0x2060;

    switch (unit) {
      case 0x00AD: // SOFT HYPHEN: drawn only where the break is taken
        if (text.isNotEmpty && !joined) {
          breaks.add(TextBreak(text.length, hyphen: true));
        }
        continue;
      case 0x200B: // ZERO WIDTH SPACE: never drawn
        if (text.isNotEmpty && !joined) {
          breaks.add(TextBreak(text.length));
        }
        continue;
      case 0x2060: // WORD JOINER: never drawn
        continue;
      case 0x002D: // HYPHEN-MINUS
      case 0x2010: // HYPHEN
        text.writeCharCode(unit);
        // Not run-initial, so '-5' keeps its sign, and not before a digit, so a
        // range like '3-4' stays whole. A trailing hyphen has nothing to break
        // away from it.
        final next = i + 1 < run.length ? run.codeUnitAt(i + 1) : 0;
        if (text.length > 1 &&
            !joined &&
            i + 1 < run.length &&
            !(next >= 0x30 && next <= 0x39)) {
          breaks.add(TextBreak(text.length));
        }
        continue;
    }

    text.writeCharCode(unit);
  }

  return TextChunk(text.toString(), separator, breaks);
}

/// Split [line] at every breakable whitespace character, keeping each separator
/// with the run it follows.
///
/// The runs are exactly what `String.split` returns - one character delimits, so
/// a run of whitespace, or whitespace at either end, yields empty runs - except
/// that the separator is carried rather than discarded, so it can be measured
/// instead of being charged as a U+0020 whatever it was.
List<TextChunk> tokenize(String line) {
  final chunks = <TextChunk>[];
  var start = 0;

  for (final match in breakableWhitespace.allMatches(line)) {
    chunks.add(
      _withBreaks(line.substring(start, match.start), match.group(0)!),
    );
    start = match.end;
  }
  chunks.add(_withBreaks(line.substring(start), ''));

  return chunks;
}
