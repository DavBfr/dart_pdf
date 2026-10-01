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
class Laid {
  Laid(this.lines, this.box);

  /// The text of each line, in top-to-bottom order, with the words of a line
  /// joined by the gaps the layout left between them.
  ///
  /// Separators are never drawn, so a line reads as its words run together.
  final List<String> lines;

  /// The paragraph's own box.
  final PdfRect box;
}

String _fromUtf16Be(String hex) => String.fromCharCodes(<int>[
  for (var i = 0; i + 4 <= hex.length; i += 4)
    int.parse(hex.substring(i, i + 4), radix: 16),
]);

/// Lay [text] out and read back what was drawn.
///
/// The runs come out of the content stream as CID strings, so they are decoded
/// through the font's own ToUnicode CMap: what the test reads is what a reader
/// would extract.
Future<Laid> layOut(
  String text,
  Font font, {
  double width = 80,
  double fontSize = 20,
  bool softWrap = true,
  LineSplitter? lineSplitter,
}) async {
  final widget = Text(
    text,
    softWrap: softWrap,
    lineSplitter: lineSplitter,
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

  final toUnicode = <int, String>{};
  for (final entry in RegExp(
    r'<([0-9A-F]{4})> <([0-9A-F]+)>',
  ).allMatches(pdf)) {
    toUnicode[int.parse(entry.group(1)!, radix: 16)] = _fromUtf16Be(
      entry.group(2)!,
    );
  }

  // One entry per drawn run: its baseline and its decoded text.
  final runs = <double, StringBuffer>{};
  for (final run in RegExp(
    r'([-\d.]+) ([-\d.]+) Td \[<([0-9A-Fa-f]+)>\]TJ',
  ).allMatches(pdf)) {
    final y = double.parse(run.group(2)!);
    final cids = run.group(3)!.toUpperCase();
    final buffer = runs.putIfAbsent(y, () => StringBuffer());
    for (var i = 0; i + 4 <= cids.length; i += 4) {
      buffer.write(toUnicode[int.parse(cids.substring(i, i + 4), radix: 16)]);
    }
  }

  final baselines = runs.keys.toList()
    ..sort((double a, double b) => b.compareTo(a));

  return Laid(<String>[
    for (final y in baselines) runs[y]!.toString(),
  ], widget.box!);
}

late Font openSans;
late Font asian;

void main() {
  setUpAll(() {
    Document.debug = false;
    RichText.debug = false;

    openSans = loadFont('open-sans.ttf');
    asian = loadFont('genyomintw.ttf');
  });

  group('the tokenizer', () {
    test('mirrors split and carries every separator', () {
      for (final line in <String>[
        'AAAA BBBB',
        'A  B',
        ' A',
        'A ',
        'A',
        '',
        '   ',
        'a\tb c',
      ]) {
        final chunks = tokenize(line);
        expect(
          chunks.map((TextChunk c) => c.text),
          line.split(breakableWhitespace),
          reason: 'runs must be exactly what split returns for "$line"',
        );
        expect(
          chunks.map((TextChunk c) => '${c.text}${c.separator}').join(),
          line,
          reason: 'nothing may be lost',
        );
        expect(chunks.last.separator, isEmpty);
      }
    });

    test('does not break at a non-breaking space', () {
      for (final rune in <int>[0x00A0, 0x2007, 0x202F]) {
        expect(
          tokenize('AAAA${String.fromCharCode(rune)}BBBB').single.text,
          'AAAA${String.fromCharCode(rune)}BBBB',
          reason: 'U+${rune.toRadixString(16).toUpperCase()}',
        );
      }
    });
  });

  group('a non-breaking space', () {
    test('is not a break opportunity', () async {
      // open-sans at 20pt: 'AAAA' is 50.6pt and 'BBBB' 51.8pt, so a box of 80
      // holds one of them. A space breaks between the two; the non-breaking
      // forms must not, and the token is hard-split somewhere past them
      // instead.
      final breaking = await layOut('AAAA BBBB', openSans);
      expect(breaking.lines, <String>['AAAA', 'BBBB']);

      for (final rune in <int>[0x00A0, 0x2007, 0x202F, 0xFEFF]) {
        final joined = await layOut(
          'AAAA${String.fromCharCode(rune)}BBBB',
          openSans,
        );
        final label = 'U+${rune.toRadixString(16).toUpperCase()}';

        expect(joined.lines, hasLength(greaterThan(1)), reason: label);
        expect(
          joined.lines.first,
          isNot('AAAA'),
          reason: '$label must not break the two apart',
        );
        expect(joined.lines.first, startsWith('AAAA'), reason: label);
      }
    });

    test('is drawn, and advances by its own width', () async {
      final laid = await layOut('AAAA BBBB', openSans, width: 400);

      expect(laid.lines, <String>['AAAA BBBB'], reason: 'one drawn run');

      // 50.625 + 5.1953 + 51.8359, the three advances open-sans reports.
      expect(laid.box.width, closeTo(107.656, 0.01));
    });
  });

  group('breakable whitespace', () {
    test('still breaks a line', () async {
      for (final rune in <int>[
        0x0020,
        0x0009,
        0x1680,
        0x2000,
        0x2003,
        0x2009,
        0x205F,
        0x3000,
      ]) {
        final laid = await layOut(
          'AAAA${String.fromCharCode(rune)}BBBB',
          openSans,
        );
        expect(laid.lines, <String>[
          'AAAA',
          'BBBB',
        ], reason: 'U+${rune.toRadixString(16).toUpperCase()}');
      }
    });

    test('advances by its own width, not by a space', () async {
      // An em space is an em wide. The gap used to be measured once from a
      // literal ' ' and charged for every separator whatever it was.
      final em = await layOut('A B', openSans, width: 400, softWrap: false);
      expect(em.box.width, closeTo(45.615, 0.01)); // was 30.81

      // An ideographic space in a font that has one: 20pt at 20pt.
      final ideographic = await layOut(
        'か　な',
        asian,
        width: 400,
        softWrap: false,
      );
      expect(ideographic.box.width, closeTo(60.0, 0.01)); // was 44.9219
    });

    test('a separator the font cannot draw still advances', () async {
      // open-sans maps neither U+0009 nor U+3000, and no font maps a tab. A
      // plain space is what the layout charged for every separator before, so
      // it is what an unmappable one falls back to.
      final tab = await layOut('A\tB', openSans, width: 400, softWrap: false);
      final space = await layOut('A B', openSans, width: 400, softWrap: false);

      expect(tab.box.width, closeTo(space.box.width, 0.0001));
      expect(tab.box.width, greaterThan(0));
    });
  });

  group('break opportunities inside a word', () {
    test('are found where the text says, and nowhere else', () {
      List<String> at(String run) => tokenize(run).single.breaks
          .map((TextBreak b) => '${b.offset}${b.hyphen ? 'h' : ''}')
          .toList();

      // A hyphen breaks after itself.
      expect(tokenize('Hello-World').single.text, 'Hello-World');
      expect(at('Hello-World'), <String>['6']);
      expect(at('a-b-c'), <String>['2', '4']);

      // Not run-initial, so a sign stays with its number, and not before a
      // digit, so a range stays whole.
      expect(at('-5'), isEmpty);
      expect(at('3-4'), isEmpty);
      expect(at('3-4-x'), <String>['4']);

      // Nothing to break away from a trailing hyphen.
      expect(at('Hello-'), isEmpty);

      // A soft hyphen is dropped and remembered; a zero-width space is dropped.
      expect(tokenize('Bundes\u00ADgericht').single.text, 'Bundesgericht');
      expect(at('Bundes\u00ADgericht'), <String>['6h']);
      expect(tokenize('Hello\u200BWorld').single.text, 'HelloWorld');
      expect(at('Hello\u200BWorld'), <String>['5']);
      expect(at('\u00ADabc'), isEmpty, reason: 'run-initial');

      // A word joiner takes the next opportunity away, and is dropped itself.
      expect(tokenize('a-\u2060b').single.text, 'a-b');
      expect(at('a-\u2060b'), isEmpty);
      expect(at('a\u00AD\u2060b'), isEmpty);
      expect(at('a\u200B\u2060b'), isEmpty);

      // U+2010 breaks, U+2011 never does.
      expect(at('a\u2010b'), <String>['2']);
      expect(at('a\u2011b'), isEmpty);

      // Nothing to find in ordinary text.
      expect(at('Hello'), isEmpty);
    });

    test('a hyphenated word breaks only after a hyphen', () async {
      // 'Hello-' is 54.6pt at 20pt and 'Hello-World-' 117.1pt, so these widths
      // take one or two segments. The token used to fall straight to a width
      // search, which cut it wherever it happened to land.
      for (final width in <double>[90, 100, 110, 130, 150]) {
        final laid = await layOut(
          'Hello-World-this-should-break-at-dashes',
          openSans,
          width: width,
        );

        expect(laid.lines.length, greaterThan(1), reason: 'width $width');
        for (final line in laid.lines) {
          expect(line, isNot(startsWith('-')), reason: 'width $width');
        }
        for (final line in laid.lines.take(laid.lines.length - 1)) {
          expect(
            line,
            endsWith('-'),
            reason: 'width $width: a line may only end at a hyphen',
          );
        }
      }
    });

    test('a hyphen before a digit is not one', () async {
      // 'aaaa-' is 50.9pt, 'aaaa-1111' 96.7pt and 'aaaa-1111a' 107.8pt. With the
      // opportunity suppressed the width search fills the line instead.
      final digits = await layOut('aaaa-1111aaaa', openSans, width: 100);
      expect(digits.lines.first, 'aaaa-1111');

      final letters = await layOut('aaaa-bbbbaaaa', openSans, width: 100);
      expect(letters.lines.first, 'aaaa-');
    });

    test('a word with no opportunity is still hard-split', () async {
      final laid = await layOut('AAAAAAAAAAAA', openSans, width: 90);

      expect(laid.lines.length, greaterThan(1));
      expect(laid.lines.join(), 'AAAAAAAAAAAA');
      for (final line in laid.lines) {
        expect(line, isNot(contains('-')));
      }
    });

    test('a zero-width space breaks and draws nothing', () async {
      // At 80pt a width search would cut after 'HelloWo', so landing on 'Hello'
      // is the opportunity being used rather than a coincidence.
      final narrow = await layOut('Hello\u200BWorld', openSans, width: 80);
      expect(narrow.lines, <String>['Hello', 'World']);

      final wide = await layOut('Hello\u200BWorld', openSans, width: 200);
      expect(wide.lines, <String>['HelloWorld']);
    });

    test('a soft hyphen is drawn only where the break is taken', () async {
      // 'Bundes-' is 77.0pt and 'verfassungs-' 117.9pt.
      final wrapped = await layOut(
        'Bundes\u00ADverfassungs\u00ADgericht',
        openSans,
        width: 130,
      );
      expect(wrapped.lines, <String>['Bundes-', 'verfassungs-', 'gericht']);

      // Where it fits, it costs nothing and shows nothing.
      final whole = await layOut(
        'Bundes\u00ADverfassungs\u00ADgericht',
        openSans,
        width: 400,
        softWrap: false,
      );
      final plain = await layOut(
        'Bundesverfassungsgericht',
        openSans,
        width: 400,
        softWrap: false,
      );

      expect(whole.lines, <String>['Bundesverfassungsgericht']);
      expect(whole.box.width, closeTo(plain.box.width, 0.0001));
      expect(whole.lines.single, isNot(contains('-')));
    });
  });

  test('a caller-supplied lineSplitter still decides everything', () async {
    // The default no longer breaks at a non-breaking space, but a splitter that
    // wants to still can, and its runs are charged one space each as before.
    final laid = await layOut(
      'AAAA BBBB',
      openSans,
      lineSplitter: (String line) => line.split(RegExp(r'\s')),
    );

    expect(laid.lines, <String>['AAAA', 'BBBB']);

    // And it drops a soft hyphen without turning it into a break of its own.
    final shy = await layOut(
      'Bundes\u00ADverfassungs\u00ADgericht',
      openSans,
      width: 400,
      softWrap: false,
      lineSplitter: (String line) => line.split(RegExp(r'\s')),
    );
    expect(shy.lines, <String>['Bundesverfassungsgericht']);
  });
}
