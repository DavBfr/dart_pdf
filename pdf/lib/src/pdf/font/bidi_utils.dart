import 'dart:math' as math;

import 'package:bidi/bidi.dart' as bidi;

import 'arabic.dart' as arabic;

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
  0x0627: 0xFE8D, // ا
  0x0628: 0xFE8F, // ب
  0x062A: 0xFE95, // ت
  0x062B: 0xFE99, // ث
  0x062C: 0xFE9D, // ج
  0x062D: 0xFEA1, // ح
  0x062E: 0xFEA5, // خ
  0x062F: 0xFEA9, // د
  0x0630: 0xFEAB, // ذ
  0x0631: 0xFEAD, // ر
  0x0632: 0xFEAF, // ز
  0x0633: 0xFEB1, // س
  0x0634: 0xFEB5, // ش
  0x0635: 0xFEB9, // ص
  0x0636: 0xFEBD, // ض
  0x0637: 0xFEC1, // ط
  0x0638: 0xFEC5, // ظ
  0x0639: 0xFEC9, // ع
  0x063A: 0xFECD, // غ
  0x0641: 0xFED1, // ف
  0x0642: 0xFED5, // ق
  0x0643: 0xFED9, // ك
  0x0644: 0xFEDD, // ل
  0x0645: 0xFEE1, // م
  0x0646: 0xFEE5, // ن
  0x0647: 0xFEE9, // ه
  0x0648: 0xFEED, // و
  0x064A: 0xFEEF, // ي
  0x0621: 0xFE80, // ء
  0x0622: 0xFE81, // آ
  0x0623: 0xFE83, // أ
  0x0624: 0xFE85, // ؤ
  0x0625: 0xFE87, // إ
  0x0626: 0xFE89, // ئ
  0x0629: 0xFE93, // ة
};

/// Applies THE BIDIRECTIONAL ALGORITHM using (https://pub.dev/packages/bidi)
///
/// Never throws. package:bidi's normalizer indexes its length table out of step
/// with the decomposition of U+0622-U+0626, so a hamza carrier followed by a
/// haraka - 40 of the 45 pairs - threw `RangeError (length): Not in inclusive
/// range 0..1: 2` out of `Document.save()`, with no runtime way to opt out of
/// the call. On failure the text is shaped without the reordering, which is a
/// different rendering but still Arabic; returning the logical string would draw
/// it reversed and unjoined.
String logicalToVisual(String input) {
  try {
    return _logicalToVisual(input);
  } catch (e) {
    assert(() {
      // ignore: avoid_print
      print('Unable to apply the bidi algorithm to "$input": $e');
      return true;
    }());

    return arabic.convert(input);
  }
}

String _logicalToVisual(String input) {
  final buffer = StringBuffer();
  final paragraphs = bidi.BidiString.fromLogical(input).paragraphs;
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

/// Shape [input] for rendering without reordering it.
///
/// The characters come back in logical order, which is what line breaking,
/// metrics and hyphenation need: UAX #9 rule L2 reorders a *line*, once its
/// breaks are known, and that is [reorderLine]'s job. [logicalToVisual] reorders
/// the whole paragraph instead and then reverses its word order; the two
/// reversals cancel only while every word of a run stays on one line.
///
/// Never throws: on failure the text is shaped by [arabic.convert], as in
/// [logicalToVisual].
String shapeLogical(String input) {
  try {
    final buffer = StringBuffer();

    for (final paragraph in bidi.BidiString.fromLogical(input).paragraphs) {
      final visual = paragraph.bidiText;
      final indices = paragraph.indices;
      final endsWithNewLine = paragraph.separator == 10;

      // bidiText carries the separator, indices does not, and a ligature such as
      // lam-alef turns two source characters into one, so the two lengths do not
      // have to agree.
      final count = math.min(
        indices.length,
        visual.length - (endsWithNewLine ? 1 : 0),
      );

      // indices[i] is the source position of the character now at visual
      // position i, so ordering the visual positions by it undoes the reorder
      // and leaves the shaping in place.
      final order = List<int>.generate(count, (int i) => i)
        ..sort((int a, int b) => indices[a].compareTo(indices[b]));

      buffer.write(
        String.fromCharCodes(<int>[for (final i in order) visual[i]]),
      );
      if (endsWithNewLine) {
        buffer.writeln();
      }
    }

    return buffer.toString();
  } catch (e) {
    assert(() {
      // ignore: avoid_print
      print('Unable to shape "$input": $e');
      return true;
    }());

    return arabic.convert(input);
  }
}

/// [text] with its characters in the opposite order.
String reversed(String text) =>
    String.fromCharCodes(text.runes.toList().reversed);

/// Whether [text] holds a strong right-to-left character.
///
/// Arabic-Indic digits are deliberately not strong: a number reads left to right
/// wherever it sits, so a run of them must not be mirrored.
bool isRtlText(String text) {
  for (final rune in text.runes) {
    if (rune < 0x0590) {
      continue;
    }
    if ((rune >= 0x0660 && rune <= 0x0669) ||
        (rune >= 0x06F0 && rune <= 0x06F9)) {
      continue;
    }
    if ((rune >= 0x0590 && rune <= 0x05FF) || // Hebrew
        (rune >= 0x0600 && rune <= 0x08FF) || // Arabic, Syriac, Thaana, NKo
        (rune >= 0xFB1D && rune <= 0xFDFF) || // Hebrew, Arabic forms A
        (rune >= 0xFE70 && rune <= 0xFEFF) || // Arabic forms B
        (rune >= 0x10800 && rune <= 0x10FFF) ||
        (rune >= 0x1E800 && rune <= 0x1EFFF)) {
      return true;
    }
  }

  return false;
}

/// Apply UAX #9 rule L2 to one line: the logical indices of [runs] in visual
/// left-to-right order.
///
/// [rtl] is the *paragraph's* base direction, not the line's. A line is
/// reordered against its paragraph - an all-Latin line inside an Arabic
/// paragraph is still part of that paragraph - and package:bidi picks the base
/// from the first strong character it sees, so the level is forced with an
/// embedding control. The control is removed again on the way out, which shifts
/// every index by the one character it occupied.
///
/// Returns the identity order if the algorithm cannot account for every run.
List<int> reorderLine(List<String> runs, {required bool rtl}) {
  final order = List<int>.generate(runs.length, (int i) => i);
  if (runs.length < 2) {
    return order;
  }

  // The line as one string, with each run's place in it.
  final line = StringBuffer(rtl ? '\u202B' : '\u202A');
  final starts = List<int>.filled(runs.length, 0);
  var at = 1;

  for (var run = 0; run < runs.length; run++) {
    if (run > 0) {
      line.write(' ');
      at++;
    }
    starts[run] = at;
    at += runs[run].length;
    line.write(runs[run]);
  }

  List<int> indices;
  try {
    indices = bidi.BidiString.fromLogical(
      line.toString(),
    ).paragraphs.first.indices;
  } catch (e) {
    assert(() {
      // ignore: avoid_print
      print('Unable to reorder "$line": $e');
      return true;
    }());

    return order;
  }

  // The leftmost place each run reaches. Runs cannot interleave under L2, so
  // that is enough to order them.
  final leftmost = List<int>.filled(runs.length, -1);

  for (var visual = 0; visual < indices.length; visual++) {
    final logical = indices[visual];

    for (var run = 0; run < runs.length; run++) {
      if (logical >= starts[run] && logical < starts[run] + runs[run].length) {
        if (leftmost[run] < 0) {
          leftmost[run] = visual;
        }
        break;
      }
    }
  }

  if (leftmost.contains(-1)) {
    assert(() {
      // ignore: avoid_print
      print('Unable to place every run of "$line"');
      return true;
    }());

    return order;
  }

  order.sort(
    (int a, int b) => leftmost[a] != leftmost[b]
        ? leftmost[a].compareTo(leftmost[b])
        : a.compareTo(b),
  );

  return order;
}
