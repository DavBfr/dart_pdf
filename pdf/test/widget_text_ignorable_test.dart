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
import 'package:pdf/src/widgets/text_segmentation.dart';
import 'package:pdf/widgets.dart';
import 'package:test/test.dart';

import 'utils.dart';

/// What one laid-out paragraph produced.
class Rendered {
  Rendered(this.content, this.box);

  /// The page's content stream.
  final String content;

  /// The paragraph's own box.
  final PdfRect box;

  /// The payload of each `[<...>]TJ` run, in paint order.
  List<String> get runs => RegExp(
    r'\[<([0-9A-Fa-f]+)>\]TJ',
  ).allMatches(content).map((RegExpMatch m) => m.group(1)!).toList();

  /// How many glyphs were drawn: each CID is four hex digits.
  int get glyphs =>
      runs.fold(0, (int total, String run) => total + run.length ~/ 4);

  /// Whether anything stroked a path, which is what the crossed-box placeholder
  /// for an uncoverable character does.
  bool get hasPlaceholder =>
      content.contains(' re ') && content.contains(' S ');
}

Future<Rendered> render(
  String text,
  Font font, {
  double width = 400,
  double fontSize = 12,
  bool softWrap = true,
}) async {
  final widget = Text(
    text,
    softWrap: softWrap,
    style: TextStyle(font: font, fontSize: fontSize),
  );

  final document = Document(compress: false);
  document.addPage(
    Page(
      pageFormat: PdfPageFormat(width, 600, marginAll: 0),
      build: (Context context) => widget,
    ),
  );

  final bytes = await document.save();
  final pdf = String.fromCharCodes(bytes);
  final start = pdf.indexOf('stream', pdf.indexOf('/Length'));
  final end = pdf.indexOf('endstream', start);

  return Rendered(pdf.substring(start + 6, end), widget.box!);
}

late Font openSans;
late Font roboto;
late Font asian;

void main() {
  setUpAll(() {
    // The debug paint strokes a box around every span, which would be
    // indistinguishable from the placeholder's own stroke.
    Document.debug = false;
    RichText.debug = false;

    openSans = loadFont('open-sans.ttf');
    roboto = loadFont('roboto.ttf');
    asian = loadFont('genyomintw.ttf');
  });

  group('the Default_Ignorable_Code_Point predicate', () {
    test('covers the invisible formatting characters', () {
      for (final rune in <int>[
        0x00AD, // SOFT HYPHEN
        0x034F, // COMBINING GRAPHEME JOINER
        0x061C, // ARABIC LETTER MARK
        0x115F, 0x1160, 0x3164, 0xFFA0, // Hangul fillers
        0x17B4, 0x17B5, // Khmer inherent vowels
        0x180B, 0x180E, 0x180F, // Mongolian variation selectors
        0x200B, 0x200C, 0x200D, 0x200E, 0x200F, // ZWSP, ZWNJ, ZWJ, LRM, RLM
        0x202A, 0x202E, // bidi embedding controls
        0x2060, 0x2066, 0x206F, // word joiner, bidi isolates
        0xFE00, 0xFE0F, // variation selectors
        0xFEFF, // ZWNBSP
        0xFFF0, 0xFFF8,
        0x1BCA0, 0x1D173, 0xE0001, 0xE0100, // supplementary controls
      ]) {
        expect(
          isDefaultIgnorable(rune),
          isTrue,
          reason: 'U+${rune.toRadixString(16).toUpperCase()}',
        );
      }
    });

    test('leaves ordinary characters and real spaces alone', () {
      for (final rune in <int>[
        0x20, 0x09, 0x0A, 0x0D, // whitespace is visible layout, not ignorable
        0x41, 0x61, 0xE9, 0x00A0, 0x2003, 0x3000, 0x2010, 0x2011, 0x002D,
        0x0621, 0x4E2D, 0x1F600,
      ]) {
        expect(
          isDefaultIgnorable(rune),
          isFalse,
          reason: 'U+${rune.toRadixString(16).toUpperCase()}',
        );
      }
    });

    test('strip removes them and returns the string itself otherwise', () {
      expect(
        stripDefaultIgnorable('Bundes­verfassungs­gericht'),
        'Bundesverfassungsgericht',
      );
      expect(stripDefaultIgnorable('a​b‍c'), 'abc');
      expect(stripDefaultIgnorable('️'), '');

      // A supplementary ignorable is two code units; the one after it must not
      // be eaten.
      expect(stripDefaultIgnorable('a\u{E0101}b'), 'ab');
      expect(stripDefaultIgnorable('a\u{1F600}b'), 'a\u{1F600}b');

      const plain = 'Hello World';
      expect(stripDefaultIgnorable(plain), same(plain));

      expect(stripDefaultIgnorable('a­b', keep: <int>{0x00AD}), 'a­b');
    });
  });

  group('a default ignorable in a paragraph', () {
    test('draws no glyph and no placeholder', () async {
      // With no font covering the character the layout fell through to the
      // crossed-box placeholder; with one - open-sans has a glyph for U+00AD -
      // it was measured and painted as a real hyphen.
      for (final font in <Font>[openSans, roboto, asian]) {
        for (final rune in <int>[
          0x0D,
          0xAD,
          0x200B,
          0x200D,
          0x200F,
          0xFE0F,
          0xFEFF,
        ]) {
          final rendered = await render('a${String.fromCharCode(rune)}b', font);
          final label = 'U+${rune.toRadixString(16).toUpperCase()}';

          expect(rendered.hasPlaceholder, isFalse, reason: label);
          expect(rendered.glyphs, 2, reason: '$label: only a and b are drawn');
        }
      }
    });

    test('a soft hyphen that fits costs nothing at all', () async {
      final withShy = await render(
        'Bundes­verfassungs­gericht',
        openSans,
        fontSize: 12,
      );
      final without = await render('Bundesverfassungsgericht', openSans);

      expect(withShy.runs, without.runs, reason: 'the same glyphs in order');
      expect(withShy.box.width, without.box.width);
      expect(withShy.box.height, without.box.height);
    });
  });

  group('a carriage return', () {
    test('terminates a line, alone and as CRLF', () async {
      for (final font in <Font>[openSans, roboto]) {
        final lf = await render('a\nb', font);
        final crlf = await render('a\r\nb', font);
        final cr = await render('a\rb', font);

        expect(crlf.box.height, lf.box.height, reason: 'CRLF is one break');
        expect(cr.box.height, lf.box.height);
        expect(crlf.runs, lf.runs);
        expect(cr.runs, lf.runs);
      }
    });

    test('mixed line endings give one line each', () async {
      for (final font in <Font>[openSans, roboto]) {
        final mixed = await render('line1\r\nline2\rline3\ntail', font);
        final lf = await render('line1\nline2\nline3\ntail', font);

        expect(mixed.runs, hasLength(4));
        expect(mixed.box.height, lf.box.height);
        expect(mixed.runs, lf.runs);
      }
    });
  });
}
