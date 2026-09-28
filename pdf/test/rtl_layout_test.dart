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

import 'dart:io';
import 'dart:math' as math;

import 'package:pdf/pdf.dart';
import 'package:pdf/src/pdf/font/bidi_utils.dart' as bidi;
import 'package:pdf/src/pdf/options.dart';
import 'package:pdf/src/widgets/text_segmentation.dart';
import 'package:pdf/widgets.dart';
import 'package:test/test.dart';

import 'utils.dart';

late Document pdf;

final _blueBox = Container(width: 50, height: 50, color: PdfColors.blue);

final _redBox = Container(width: 50, height: 50, color: PdfColors.red);

final _yellowBox = Container(width: 50, height: 50, color: PdfColors.yellow);

/// The text each page of [bytes] draws, as one string per page.
///
/// Every `[(...)]TJ` run of a page, concatenated, so one entry covers one
/// paragraph however many words it was split into. The standard-14 fonts write
/// their runs as literal strings, so this is readable text.
List<String> drawnPages(List<int> bytes) {
  final pdf = String.fromCharCodes(bytes);
  final pages = <String>[];

  for (final block in RegExp(
    r'stream\n(.*?)endstream',
    dotAll: true,
  ).allMatches(pdf)) {
    final body = block.group(1)!;
    if (!body.contains('TJ')) {
      continue;
    }
    pages.add(
      RegExp(
        r'\[\(([^)]*)\)\]TJ',
      ).allMatches(body).map((RegExpMatch m) => m.group(1)!).join(),
    );
  }

  return pages;
}

String _fromUtf16Be(String hex) => String.fromCharCodes(<int>[
  for (var i = 0; i + 4 <= hex.length; i += 4)
    int.parse(hex.substring(i, i + 4), radix: 16),
]);

/// The words of each laid-out line, left to right, decoded through the font's
/// own ToUnicode CMap.
///
/// One entry per baseline, top line first.
List<List<String>> laidOutLines(List<int> bytes) {
  final pdf = String.fromCharCodes(bytes);

  final toUnicode = <int, String>{};
  for (final entry in RegExp(
    r'<([0-9A-F]{4})> <([0-9A-F]+)>',
  ).allMatches(pdf)) {
    toUnicode[int.parse(entry.group(1)!, radix: 16)] = _fromUtf16Be(
      entry.group(2)!,
    );
  }

  final lines = <double, List<List<double>>>{};
  final words = <String>[];

  for (final run in RegExp(
    r'([-\d.]+) ([-\d.]+) Td \[<([0-9A-Fa-f]+)>\]TJ',
  ).allMatches(pdf)) {
    final cids = run.group(3)!.toUpperCase();
    final text = StringBuffer();
    for (var i = 0; i + 4 <= cids.length; i += 4) {
      text.write(toUnicode[int.parse(cids.substring(i, i + 4), radix: 16)]);
    }

    lines.putIfAbsent(double.parse(run.group(2)!), () => <List<double>>[]).add(
      <double>[double.parse(run.group(1)!), words.length.toDouble()],
    );
    words.add(text.toString());
  }

  final baselines = lines.keys.toList()
    ..sort((double a, double b) => b.compareTo(a));

  return <List<String>>[
    for (final baseline in baselines)
      <String>[
        for (final run
            in lines[baseline]!..sort(
              (List<double> a, List<double> b) => a.first.compareTo(b.first),
            ))
          words[run.last.toInt()],
      ],
  ];
}

/// Lay [text] out on an RTL page of [width] and read the lines back.
Future<List<List<String>>> rtlLines(String text, double width) async {
  final document = Document(compress: false);
  document.addPage(
    Page(
      pageFormat: PdfPageFormat(width, 300, marginAll: 0),
      textDirection: TextDirection.rtl,
      build: (Context context) => Text(
        text,
        style: TextStyle(font: loadFont('hacen-tunisia.ttf'), fontSize: 20),
      ),
    ),
  );

  return laidOutLines(await document.save());
}

/// These read the output of the bidi pipeline, which a build with
/// -Duse_arabic=true replaces with arabic.convert.
const legacyArabic = useArabic
    ? 'the legacy arabic.convert path is in use'
    : null;

void main() {
  setUpAll(() {
    Document.debug = true;
    pdf = Document();
  });

  group('an arabic run inside an english paragraph', () {
    /// The drawn runs of an LTR page, left to right, as code-unit lists.
    Future<List<List<int>>> ltrRuns(String text) async {
      final document = Document(compress: false);
      document.addPage(
        Page(
          pageFormat: const PdfPageFormat(400, 120, marginAll: 0),
          build: (Context context) => Text(
            text,
            style: TextStyle(font: loadFont('hacen-tunisia.ttf'), fontSize: 20),
          ),
        ),
      );

      final lines = laidOutLines(await document.save());
      expect(lines, hasLength(1));
      return lines.single.map((String word) => word.codeUnits).toList();
    }

    test('is shaped and put in visual order', () async {
      // The bidi pass ran only when the resolved direction was rtl, and
      // Directionality defaults to ltr, so an Arabic fragment in an English
      // sentence got no reordering, no shaping and no control removal.
      expect(await ltrRuns('x \u0627 \u0628 y'), <List<int>>[
        <int>[0x78], // x
        <int>[0xFE8F], // the second Arabic word comes first on the page
        <int>[0xFE8D],
        <int>[0x79], // y
      ]);
    });

    test('keeps its place between the words around it', () async {
      expect(await ltrRuns('Total: \u0645 today'), <List<int>>[
        'Total:'.codeUnits,
        <int>[0xFEE1], // shaped, where the raw U+0645 used to be drawn
        'today'.codeUnits,
      ]);
    });

    test('a paragraph with nothing bidirectional is left alone', () async {
      expect(await ltrRuns('Hello world foo'), <List<int>>[
        'Hello'.codeUnits,
        'world'.codeUnits,
        'foo'.codeUnits,
      ]);
    });
  });

  group('a joined arabic word', () {
    test('has a real width and is drawn right to left', () async {
      // hacen-tunisia joins through GSUB and its cmap carries only the base
      // letters and the isolated forms, so every medial and final glyph came out
      // as .notdef with no width: two words overlapped at the same x.
      final shaped = bidi.shapeLogical('مرحبا بالعالم').split(' ');
      final lines = await rtlLines('مرحبا بالعالم', 400);

      expect(lines, <List<String>>[
        <String>[bidi.reversed(shaped[1]), bidi.reversed(shaped[0])],
      ]);
    });

    test('measures more than nothing', () async {
      final widget = Text(
        'مرحبا',
        style: TextStyle(font: loadFont('hacen-tunisia.ttf'), fontSize: 20),
      );

      final document = Document();
      document.addPage(
        Page(
          pageFormat: const PdfPageFormat(400, 120, marginAll: 0),
          textDirection: TextDirection.rtl,
          build: (Context context) => widget,
        ),
      );
      await document.save();

      // The five glyphs of a shaped 'مرحبا' at 20pt. It used to measure 0.0,
      // because four of the five were not in the cmap at all.
      expect(widget.box!.width, greaterThan(30));
      expect(widget.box!.width, lessThan(120));
    });
  }, skip: legacyArabic);

  group('a wrapped right-to-left paragraph', () {
    // hacen-tunisia has the isolated Arabic forms but no medial or final ones,
    // so these use one-letter words: they shape to an isolated form the font
    // actually carries and therefore have a real width.
    test('keeps an embedded Latin run in reading order', () async {
      // Rule L2 reorders a line once its breaks are known. It used to be applied
      // to the whole paragraph, whose word order was then reversed, and the line
      // breaker saw that: line 1 came out as 'historical old town ا' and 'the'
      // was left behind on line 2.
      final lines = await rtlLines(
        '\u0627 the historical old town \u0628',
        150,
      );

      expect(lines, <List<String>>[
        <String>['the', 'historical', 'old', '\uFE8D'],
        <String>['\uFE8F', 'town'],
      ]);
    }, skip: legacyArabic);

    test('is unchanged where it does not wrap', () async {
      final lines = await rtlLines(
        '\u0627 the historical old town \u0628',
        400,
      );

      expect(lines, <List<String>>[
        <String>['\uFE8F', 'the', 'historical', 'old', 'town', '\uFE8D'],
      ]);
    }, skip: legacyArabic);

    test('carries a link across the whole run it covers', () async {
      // _getBox took the decoration's first and last span as its left and right
      // edge. The spans are in logical order, so for a right-to-left run the
      // first one is the rightmost and the rect came out narrower than the text
      // it belongs to - a link that is not clickable over most of its words.
      final document = Document(compress: false);
      document.addPage(
        Page(
          pageFormat: const PdfPageFormat(400, 120, marginAll: 0),
          textDirection: TextDirection.rtl,
          build: (Context context) => RichText(
            text: TextSpan(
              style: TextStyle(
                font: loadFont('hacen-tunisia.ttf'),
                fontSize: 20,
              ),
              children: <TextSpan>[
                const TextSpan(text: 'x '),
                TextSpan(
                  text: '\u0627 \u0628',
                  annotation: AnnotationLink('https://example.com'),
                ),
                const TextSpan(text: ' y'),
              ],
            ),
          ),
        ),
      );

      final bytes = await document.save();
      final pdf = String.fromCharCodes(bytes);

      final rect = RegExp(r'/Rect\s*\[([-\d. ]+)\]')
          .firstMatch(pdf)!
          .group(1)!
          .trim()
          .split(RegExp(r'\s+'))
          .map(double.parse)
          .toList();
      expect(rect, hasLength(4));

      // Where the two linked words were actually drawn.
      final xs = <double>[];
      for (final run in RegExp(
        r'([-\d.]+) [-\d.]+ Td \[<([0-9A-Fa-f]+)>\]TJ',
      ).allMatches(pdf)) {
        if (<String>['0002', '0003'].contains(run.group(2)!.toLowerCase())) {
          xs.add(double.parse(run.group(1)!));
        }
      }
      expect(xs, hasLength(2), reason: 'both linked words are drawn');

      expect(
        rect[0],
        lessThanOrEqualTo(xs.reduce(math.min) + 1),
        reason: 'the link reaches the leftmost word',
      );
      expect(
        rect[2],
        greaterThanOrEqualTo(xs.reduce(math.max)),
        reason: 'and the rightmost',
      );
    });

    test('puts pure right-to-left words on the lines they belong to', () async {
      // Each line holds the logical words it should, in visual order.
      final lines = await rtlLines(
        '\u0627 \u0628 \u062A \u062B \u062C \u062D \u062E \u062F',
        60,
      );

      expect(lines, <List<String>>[
        <String>['\uFE99', '\uFE95', '\uFE8F', '\uFE8D'],
        <String>['\uFEA9', '\uFEA5', '\uFEA1', '\uFE9D'],
      ]);
    }, skip: legacyArabic);
  });

  test('an explicit bidi mark still reorders the paragraph', () async {
    // A default ignorable is dropped after the bidi reordering, not before, so
    // an explicit LRM or RLM keeps doing its job. This string reorders one way
    // if the mark is still there when the bidi pass runs and the other way if
    // it has already been taken out.
    const source = '\u200F123 abc';

    final afterBidi = stripDefaultIgnorable(bidi.logicalToVisual(source));
    final beforeBidi = bidi.logicalToVisual(stripDefaultIgnorable(source));
    expect(afterBidi, '123 abc');
    expect(beforeBidi, 'abc 123');

    final document = Document(compress: false);

    // The paragraph under test, then the two candidate orders drawn straight:
    // an LTR paragraph runs no bidi pass of its own.
    for (final entry in <String, TextDirection>{
      source: TextDirection.rtl,
      afterBidi: TextDirection.ltr,
      beforeBidi: TextDirection.ltr,
    }.entries) {
      document.addPage(
        Page(
          pageFormat: const PdfPageFormat(400, 100, marginAll: 0),
          build: (Context context) =>
              Text(entry.key, textDirection: entry.value),
        ),
      );
    }

    final pages = drawnPages(await document.save());
    expect(pages, hasLength(3));
    expect(pages[0], pages[1], reason: 'stripped after the bidi pass');
    expect(pages[0], isNot(pages[2]), reason: 'not before it');
  }, skip: legacyArabic);

  test('RTL Text', () {
    pdf.addPage(
      Page(
        textDirection: TextDirection.rtl,
        pageFormat: const PdfPageFormat(150, 50),
        build: (Context context) => Text('RTL Text'),
      ),
    );
  });
  test('RTL Text TextAlign.end', () {
    pdf.addPage(
      Page(
        textDirection: TextDirection.rtl,
        pageFormat: const PdfPageFormat(150, 50),
        build: (Context context) => SizedBox(
          width: 150,
          child: Text('RTL Text : TextAlign.end', textAlign: TextAlign.end),
        ),
      ),
    );
  });

  test('RTL Text TextAlign.left', () {
    pdf.addPage(
      Page(
        textDirection: TextDirection.rtl,
        pageFormat: const PdfPageFormat(150, 50),
        build: (Context context) => SizedBox(
          width: 150,
          child: Text('RTL Text : TextAlign.left', textAlign: TextAlign.left),
        ),
      ),
    );
  });

  test('LTR Text', () {
    pdf.addPage(
      Page(
        textDirection: TextDirection.ltr,
        pageFormat: const PdfPageFormat(150, 50),
        build: (Context context) => Text('LTR Text'),
      ),
    );
  });
  test('LTR Text TextAlign.end', () {
    pdf.addPage(
      Page(
        textDirection: TextDirection.ltr,
        pageFormat: const PdfPageFormat(150, 50),
        build: (Context context) => SizedBox(
          width: 150,
          child: Text('RTL Text : TextAlign.end', textAlign: TextAlign.end),
        ),
      ),
    );
  });

  test('LTR Text TextAlign.right', () {
    pdf.addPage(
      Page(
        textDirection: TextDirection.ltr,
        pageFormat: const PdfPageFormat(150, 50),
        build: (Context context) => SizedBox(
          width: 150,
          child: Text('LTR Text : TextAlign.right', textAlign: TextAlign.right),
        ),
      ),
    );
  });

  test(
    'Should render a blue box followed by a red box ordered RTL aligned right',
    () {
      pdf.addPage(
        Page(
          textDirection: TextDirection.rtl,
          pageFormat: const PdfPageFormat(150, 50),
          build: (Context context) => TestAnnotation(
            anno: 'RTL Row',
            child: Row(children: [_blueBox, _redBox]),
          ),
        ),
      );
    },
  );

  test(
    'Should render a blue box followed by a red box ordered RTL with aligned center',
    () {
      pdf.addPage(
        Page(
          textDirection: TextDirection.rtl,
          pageFormat: const PdfPageFormat(150, 50),
          build: (Context context) => TestAnnotation(
            anno: 'RTL Row MainAlignment.center',
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [_blueBox, _redBox],
            ),
          ),
        ),
      );
    },
  );

  test(
    'Should render a blue box followed by a red box ordered RTL with CrossAxisAlignment.end aligned right',
    () {
      pdf.addPage(
        Page(
          pageFormat: const PdfPageFormat(150, 100),
          textDirection: TextDirection.rtl,
          build: (Context context) => TestAnnotation(
            anno: 'RTL Row CrossAlignment.end',
            child: SizedBox(
              width: 150,
              height: 100,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [_blueBox, _redBox],
              ),
            ),
          ),
        ),
      );
    },
  );
  test(
    'Should render a blue box followed by a red box ordered LTR aligned left',
    () {
      pdf.addPage(
        Page(
          pageFormat: const PdfPageFormat(150, 50),
          build: (Context context) => TestAnnotation(
            anno: 'LTR Row',
            child: Row(children: [_blueBox, _redBox]),
          ),
        ),
      );
    },
  );
  test(
    'Should render a blue box followed by a red box ordered TTB aligned right',
    () {
      pdf.addPage(
        Page(
          textDirection: TextDirection.rtl,
          pageFormat: const PdfPageFormat(150, 150),
          build: (Context context) => TestAnnotation(
            anno: 'RTL Column crossAlignment.start',
            child: SizedBox(
              width: 150,
              height: 150,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [_blueBox, _redBox],
              ),
            ),
          ),
        ),
      );
    },
  );
  test(
    'Should render a blue box followed by a red box ordered TTB aligned left',
    () {
      pdf.addPage(
        Page(
          textDirection: TextDirection.ltr,
          pageFormat: const PdfPageFormat(150, 150),
          build: (Context context) => TestAnnotation(
            anno: 'LTR Column crossAlignment.start',
            child: SizedBox(
              width: 150,
              height: 150,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [_blueBox, _redBox],
              ),
            ),
          ),
        ),
      );
    },
  );

  test('Wrap Should render blue,red,yellow ordered RTL', () {
    pdf.addPage(
      Page(
        textDirection: TextDirection.rtl,
        pageFormat: const PdfPageFormat(150, 150),
        build: (Context context) => TestAnnotation(
          anno: 'RTL Wrap',
          child: SizedBox(
            width: 150,
            height: 150,
            child: Wrap(children: [_blueBox, _redBox, _yellowBox]),
          ),
        ),
      ),
    );
  });

  test('Wrap Should render blue,red,yellow ordered LTR', () {
    pdf.addPage(
      Page(
        textDirection: TextDirection.ltr,
        pageFormat: const PdfPageFormat(150, 150),
        build: (Context context) => TestAnnotation(
          anno: 'LTR Wrap',
          child: SizedBox(
            width: 150,
            height: 150,
            child: Wrap(children: [_blueBox, _redBox, _yellowBox]),
          ),
        ),
      ),
    );
  });
  test('Wrap Should render blue,red,yellow ordered RTL aligned center', () {
    pdf.addPage(
      Page(
        textDirection: TextDirection.rtl,
        pageFormat: const PdfPageFormat(150, 150),
        build: (Context context) => TestAnnotation(
          anno: 'RTL Wrap WrapAlignment.center',
          child: SizedBox(
            width: 150,
            height: 150,
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              runAlignment: WrapAlignment.center,
              children: [_blueBox, _redBox, _yellowBox],
            ),
          ),
        ),
      ),
    );
  });

  test('Wrap Should render blue,red,yellow ordered RTL aligned bottom', () {
    pdf.addPage(
      Page(
        textDirection: TextDirection.rtl,
        pageFormat: const PdfPageFormat(150, 150),
        build: (Context context) => TestAnnotation(
          anno: 'RTL Wrap WrapAlignment.end',
          child: SizedBox(
            width: 150,
            height: 150,
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              runAlignment: WrapAlignment.end,
              children: [_blueBox, _redBox, _yellowBox],
            ),
          ),
        ),
      ),
    );
  });

  test('RTL Page Should render child aligned right', () {
    pdf.addPage(
      Page(
        textDirection: TextDirection.rtl,
        pageFormat: const PdfPageFormat(150, 150),
        build: (Context context) {
          return TestAnnotation(anno: 'RTL Page', child: _blueBox);
        },
      ),
    );
  });

  test('LTR Page Should render child aligned left', () {
    pdf.addPage(
      Page(
        textDirection: TextDirection.ltr,
        pageFormat: const PdfPageFormat(150, 150),
        build: (Context context) {
          return TestAnnotation(anno: 'LTR Page', child: _blueBox);
        },
      ),
    );
  });

  test('RTL Multi Page Should render child aligned right', () {
    pdf.addPage(
      MultiPage(
        textDirection: TextDirection.rtl,
        pageFormat: const PdfPageFormat(150, 150),
        build: (Context context) {
          return [
            Text('RTL MultiPage', style: const TextStyle(fontSize: 9)),
            ListView(
              children: [for (int i = 0; i < 15; i++) Text('List item')],
            ),
          ];
        },
      ),
    );
  });

  test('LTR Multi Page Should render child aligned left', () {
    pdf.addPage(
      MultiPage(
        textDirection: TextDirection.ltr,
        pageFormat: const PdfPageFormat(150, 150),
        build: (Context context) {
          return [
            Text('LTR MultiPage', style: const TextStyle(fontSize: 9)),
            ListView(
              children: [for (int i = 0; i < 15; i++) Text('List item')],
            ),
          ];
        },
      ),
    );
  });

  test('Should render a blue box padded from right', () {
    pdf.addPage(
      Page(
        textDirection: TextDirection.rtl,
        pageFormat: const PdfPageFormat(150, 150),
        build: (Context context) {
          return TestAnnotation(
            anno: 'RTL Padded start',
            child: Padding(
              padding: const EdgeInsetsDirectional.only(start: 20),
              child: _blueBox,
            ),
          );
        },
      ),
    );
  });

  test('Should render a blue box padded from left', () {
    pdf.addPage(
      Page(
        textDirection: TextDirection.ltr,
        pageFormat: const PdfPageFormat(150, 150),
        build: (Context context) {
          return TestAnnotation(
            anno: 'LTR Padded start',
            child: Padding(
              padding: const EdgeInsetsDirectional.only(start: 20),
              child: _blueBox,
            ),
          );
        },
      ),
    );
  });

  test('Should render a blue box aligned center right', () {
    pdf.addPage(
      Page(
        textDirection: TextDirection.rtl,
        pageFormat: const PdfPageFormat(150, 150),
        build: (Context context) {
          return TestAnnotation(
            anno: 'RTL Align directional.centerStart',
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: _blueBox,
            ),
          );
        },
      ),
    );
  });

  test('Should render a blue box aligned center left', () {
    pdf.addPage(
      Page(
        textDirection: TextDirection.ltr,
        pageFormat: const PdfPageFormat(150, 150),
        build: (Context context) {
          return TestAnnotation(
            anno: 'LTR Align directional.centerStart',
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: _blueBox,
            ),
          );
        },
      ),
    );
  });

  test('Should render a box with top-right curved corner', () {
    pdf.addPage(
      Page(
        textDirection: TextDirection.rtl,
        pageFormat: const PdfPageFormat(150, 150),
        build: (Context context) {
          return TestAnnotation(
            anno: 'RTL RadiusDirectional.only topStart',
            child: Container(
              margin: const EdgeInsets.only(top: 11),
              decoration: const BoxDecoration(
                color: PdfColors.blue,
                borderRadius: BorderRadiusDirectional.only(
                  topStart: Radius.circular(20),
                ),
              ),
              width: 150,
              height: 150,
            ),
          );
        },
      ),
    );
  });

  test('Should render a box with right curved corners', () {
    pdf.addPage(
      Page(
        textDirection: TextDirection.rtl,
        pageFormat: const PdfPageFormat(150, 150),
        build: (Context context) {
          return TestAnnotation(
            anno: 'RTL RadiusDirectional.horizontal start',
            child: Container(
              margin: const EdgeInsets.only(top: 11),
              decoration: const BoxDecoration(
                color: PdfColors.blue,
                borderRadius: BorderRadiusDirectional.horizontal(
                  start: Radius.circular(20),
                ),
              ),
              width: 150,
              height: 150,
            ),
          );
        },
      ),
    );
  });

  test('Should render a box with left curved corners', () {
    pdf.addPage(
      Page(
        textDirection: TextDirection.ltr,
        pageFormat: const PdfPageFormat(150, 150),
        build: (Context context) {
          return TestAnnotation(
            anno: 'LTR RadiusDirectional.horizontal end',
            child: Container(
              margin: const EdgeInsets.only(top: 11),
              decoration: const BoxDecoration(
                color: PdfColors.blue,
                borderRadius: BorderRadiusDirectional.horizontal(
                  end: Radius.circular(20),
                ),
              ),
              width: 150,
              height: 150,
            ),
          );
        },
      ),
    );
  });

  test('Should render a box with top-left curved corner', () {
    pdf.addPage(
      Page(
        textDirection: TextDirection.ltr,
        pageFormat: const PdfPageFormat(150, 150),
        build: (Context context) {
          return TestAnnotation(
            anno: 'LTR RadiusDirectional.only topEnd',
            child: Container(
              margin: const EdgeInsets.only(top: 11),
              decoration: const BoxDecoration(
                color: PdfColors.blue,
                borderRadius: BorderRadiusDirectional.only(
                  topEnd: Radius.circular(20),
                ),
              ),
              width: 150,
              height: 150,
            ),
          );
        },
      ),
    );
  });

  test('Should render Grid with run alignment right', () {
    pdf.addPage(
      Page(
        textDirection: TextDirection.rtl,
        pageFormat: const PdfPageFormat(150, 150),
        build: (Context context) {
          return TestAnnotation(
            anno: 'RTL GridView Axis.vertical',
            child: GridView(
              crossAxisCount: 3,
              childAspectRatio: 1,
              direction: Axis.vertical,
              children: [
                for (int i = 0; i < 7; i++)
                  Container(
                    color: [
                      PdfColors.blue,
                      PdfColors.red,
                      PdfColors.yellow,
                    ][i % 3],
                  ),
              ],
            ),
          );
        },
      ),
    );
  });

  test('Should render Grid with run alignment left', () {
    pdf.addPage(
      Page(
        textDirection: TextDirection.ltr,
        pageFormat: const PdfPageFormat(150, 150),
        build: (Context context) {
          return TestAnnotation(
            anno: 'LTR GridView Axis.vertical',
            child: GridView(
              crossAxisCount: 3,
              childAspectRatio: 1,
              direction: Axis.vertical,
              children: [
                for (int i = 0; i < 7; i++)
                  Container(
                    color: [
                      PdfColors.blue,
                      PdfColors.red,
                      PdfColors.yellow,
                    ][i % 3],
                  ),
              ],
            ),
          );
        },
      ),
    );
  });
  test('Should render Grid (horizontal) with run alignment right', () {
    pdf.addPage(
      Page(
        textDirection: TextDirection.rtl,
        pageFormat: const PdfPageFormat(150, 150),
        build: (Context context) {
          return TestAnnotation(
            anno: 'RTL GridView Axis.horizontal',
            child: GridView(
              crossAxisCount: 3,
              childAspectRatio: 1,
              direction: Axis.horizontal,
              children: [
                for (int i = 0; i < 7; i++)
                  Container(
                    color: [
                      PdfColors.blue,
                      PdfColors.red,
                      PdfColors.yellow,
                    ][i % 3],
                  ),
              ],
            ),
          );
        },
      ),
    );
  });

  test('Should render Grid (horizontal) with run alignment left', () {
    pdf.addPage(
      Page(
        textDirection: TextDirection.ltr,
        pageFormat: const PdfPageFormat(150, 150),
        build: (Context context) {
          return TestAnnotation(
            anno: 'LTR GridView Axis.horizontal',
            child: GridView(
              crossAxisCount: 3,
              childAspectRatio: 1,
              direction: Axis.horizontal,
              children: [
                for (int i = 0; i < 7; i++)
                  Container(
                    color: [
                      PdfColors.blue,
                      PdfColors.red,
                      PdfColors.yellow,
                    ][i % 3],
                  ),
              ],
            ),
          );
        },
      ),
    );
  });

  test('RTL Stack, should directional child to right44', () {
    pdf.addPage(
      Page(
        textDirection: TextDirection.rtl,
        pageFormat: const PdfPageFormat(150, 150),
        build: (Context context) {
          return TestAnnotation(
            anno: 'RTL Stack PositionDirectional.start',
            child: Stack(
              children: [PositionedDirectional(start: 0, child: _blueBox)],
            ),
          );
        },
      ),
    );
  });

  test('LTR Stack, should directional child to right44', () {
    pdf.addPage(
      Page(
        textDirection: TextDirection.ltr,
        pageFormat: const PdfPageFormat(150, 150),
        build: (Context context) {
          return TestAnnotation(
            anno: 'LTR Stack PositionDirectional.start',
            child: Stack(
              children: [PositionedDirectional(start: 0, child: _blueBox)],
            ),
          );
        },
      ),
    );
  });

  tearDownAll(() async {
    final file = File('rtl-layout.pdf');
    await file.writeAsBytes(await pdf.save());
  });
}

class TestAnnotation extends StatelessWidget {
  TestAnnotation({required this.anno, required this.child});

  final String anno;
  final Widget child;

  @override
  Widget build(Context context) {
    return Stack(
      children: [
        child,
        Positioned(
          top: 0,
          right: 0,
          left: 0,
          child: Container(
            color: PdfColors.white,
            child: Text(
              anno,
              style: const TextStyle(color: PdfColors.black, fontSize: 9),
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }
}
