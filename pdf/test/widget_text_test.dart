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
import 'package:pdf/widgets.dart';
import 'package:test/test.dart';

import 'utils.dart';

/// The CID payload of each `[<...>]TJ` run, in paint order.
List<String> cidRuns(String pdf) => RegExp(
  r'\[<([0-9A-Fa-f]+)>\]TJ',
).allMatches(pdf).map((RegExpMatch m) => m.group(1)!.toUpperCase()).toList();

/// How many runs each baseline carries, top line first.
List<int> runsPerLine(String pdf) {
  final lines = <double, int>{};

  for (final run in RegExp(
    r'[-\d.]+ ([-\d.]+) Td \[<[0-9A-Fa-f]+>\]TJ',
  ).allMatches(pdf)) {
    final y = double.parse(run.group(1)!);
    lines[y] = (lines[y] ?? 0) + 1;
  }

  final baselines = lines.keys.toList()
    ..sort((double a, double b) => b.compareTo(a));
  return <int>[for (final y in baselines) lines[y]!];
}

/// One right-to-left page of [text], uncompressed.
Future<String> fallbackPage(
  String text, {
  required Font font,
  List<Font> fontFallback = const <Font>[],
  double width = 400,
}) async {
  final document = Document(compress: false);
  document.addPage(
    Page(
      pageFormat: PdfPageFormat(width, 200, marginAll: 0),
      textDirection: TextDirection.rtl,
      build: (Context context) => Text(
        text,
        style: TextStyle(font: font, fontFallback: fontFallback, fontSize: 20),
      ),
    ),
  );

  return String.fromCharCodes(await document.save());
}

late Document pdf;
late Font ttf;
late Font ttfBold;
late Font asian;
late Font emoji;

Iterable<TextDecoration> permute(
  List<TextDecoration> prefix,
  List<TextDecoration> remaining,
) sync* {
  yield TextDecoration.combine(prefix);
  if (remaining.isNotEmpty) {
    for (final decoration in remaining) {
      final next = List<TextDecoration>.from(remaining);
      next.remove(decoration);
      yield* permute(prefix + <TextDecoration>[decoration], next);
    }
  }
}

void main() {
  setUpAll(() {
    Document.debug = true;
    RichText.debug = true;

    ttf = loadFont('open-sans.ttf');
    ttfBold = loadFont('open-sans-bold.ttf');
    asian = loadFont('genyomintw.ttf');
    emoji = loadFont('emoji.ttf');
    pdf = Document();
  });

  test('Text Widgets Quotes', () {
    pdf.addPage(
      Page(build: (Context context) => Text('Text containing \' or " works!')),
    );
  });

  test('Text Widgets Unicode Quotes', () {
    pdf.addPage(
      Page(
        build: (Context context) =>
            Text('Text containing ’ and ” works!', style: TextStyle(font: ttf)),
      ),
    );
  });

  test('Text Widgets softWrap', () {
    final para = LoremText().paragraph(40);

    pdf.addPage(
      MultiPage(
        build: (Context context) => <Widget>[
          Text('Text with\nsoft wrap\nenabled', softWrap: true),
          Text('Text with\nsoft wrap\ndisabled', softWrap: false),
          SizedBox(width: 120, child: Text(para, softWrap: false)),
          SizedBox(width: 120, child: Text(para, softWrap: true)),
        ],
      ),
    );
  });

  test(
    'Text Widgets lineSplitter keeps the default wrapping behavior',
    () async {
      // 自定义 splitter 复刻默认的按空白切分时，排版结果必须与默认完全一致。
      final para = LoremText().paragraph(20);
      const width = 150.0;

      final doc = Document();
      late RichText def;
      late RichText custom;
      doc.addPage(
        Page(
          pageFormat: PdfPageFormat(200, 400),
          build: (Context context) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                width: width,
                child: def = RichText(
                  text: TextSpan(
                    text: para,
                    style: TextStyle(font: ttf, fontSize: 10),
                  ),
                  lineSplitter: null,
                ),
              ),
              SizedBox(
                width: width,
                child: custom = RichText(
                  text: TextSpan(
                    text: para,
                    style: TextStyle(font: ttf, fontSize: 10),
                  ),
                  lineSplitter: (line) => line.split(RegExp(r'\s')),
                ),
              ),
            ],
          ),
        ),
      );
      await doc.save();

      expect(def.box, isNotNull);
      expect(custom.box, isNotNull);
      expect(
        custom.box!.height,
        def.box!.height,
        reason: '默认空白切分的 splitter 不得改变换行结果',
      );
    },
  );

  /// Text runs `(x, y)` drawn on the first page, extracted from the
  /// uncompressed content stream. Used to assert the produced line breaks.
  List<(double, double)> textRuns(List<int> bytes) {
    final raw = String.fromCharCodes(bytes);
    return [
      for (final m in RegExp(r'([\d.]+) ([\d.]+) Td').allMatches(raw))
        (double.parse(m[1]!), double.parse(m[2]!)),
    ];
  }

  /// Runs of the topmost line (largest y), sorted by x.
  List<(double, double)> firstLine(List<int> bytes) {
    final runs = textRuns(bytes);
    final top = runs.map((r) => r.$2).reduce(math.max);
    return runs.where((r) => (r.$2 - top).abs() < 0.01).toList()
      ..sort((a, b) => a.$1.compareTo(b.$1));
  }

  test(
    'Text Widgets lineSplitter: CJK fills the line after a short prefix',
    () async {
      // 混排短前缀 + 无空格 CJK：默认把整段 CJK 当作一个词 —— 它能独占一行，
      // 于是被整体挪到下一行，首行只剩 `- `（这正是 dart_pdf#1726 报告的
      // "could break from the first word"）。提供断行器后 CJK 逐字断行 → 首行填满。
      const cjk = '字体排印学是研究字体与排版的学问涉及字形设计';
      const margin = 8.0;
      const pageWidth = 140.0;

      Future<List<int>> render(LineSplitter? splitter) async {
        final doc = Document(compress: false);
        doc.addPage(
          Page(
            pageFormat: PdfPageFormat(pageWidth, 120, marginAll: margin),
            build: (Context context) => RichText(
              text: TextSpan(
                text: '- $cjk',
                style: TextStyle(
                  font: asian,
                  fontSize: 8,
                  // 逐字断行时字间不插空格 → 空格宽度清零。
                  wordSpacing: splitter == null ? 1 : 0,
                ),
              ),
              lineSplitter: splitter,
            ),
          ),
        );
        return await doc.save();
      }

      final def = firstLine(await render(null));
      final custom = firstLine(await render((line) => line.split('')));

      expect(def, hasLength(1), reason: '默认实现把整段 CJK 挪到下一行，首行只剩前缀');
      expect(def.single.$1, margin, reason: '孤立前缀从左边距开始');

      expect(custom.length, greaterThan(1), reason: '逐字断行后首行应包含前缀与其后的多个字');
      expect(custom.first.$1, margin, reason: '首行仍从左边距开始');
      // 首行填满：最后一个字明显越过默认实现的首行（只有前缀那一个字宽）。
      expect(
        custom.last.$1,
        greaterThan(def.last.$1 + 50),
        reason: '首行应被填满而不是只放前缀',
      );
      // 不超过版心。
      expect(
        custom.last.$1,
        lessThanOrEqualTo(pageWidth - margin + 0.01),
        reason: '行宽不得超过版心',
      );
    },
  );

  test('Text Widgets Alignement', () {
    final para = LoremText().paragraph(40);

    final widgets = <Widget>[];
    for (final align in TextAlign.values) {
      widgets.add(Text('$align:\n$para', textAlign: align));
    }

    pdf.addPage(MultiPage(build: (Context context) => widgets));
  });

  test('Text Widgets lineSpacing', () {
    final para = LoremText().paragraph(40);

    final widgets = <Widget>[];
    for (var spacing = 0.0; spacing < 10.0; spacing += 2.0) {
      widgets.add(
        Text(
          para,
          style: TextStyle(font: ttf, lineSpacing: spacing),
        ),
      );
      widgets.add(SizedBox(height: 30));
    }

    pdf.addPage(MultiPage(build: (Context context) => widgets));
  });

  test('Text Widgets wordSpacing', () {
    final para = LoremText().paragraph(40);

    final widgets = <Widget>[];
    for (var spacing = 0.0; spacing < 10.0; spacing += 2.0) {
      widgets.add(
        Text(
          para,
          style: TextStyle(font: ttf, wordSpacing: spacing),
        ),
      );
      widgets.add(SizedBox(height: 30));
    }

    pdf.addPage(MultiPage(build: (Context context) => widgets));
  });

  test('Text Widgets letterSpacing', () {
    final para = LoremText().paragraph(40);

    final widgets = <Widget>[];
    for (var spacing = -1.0; spacing < 8.0; spacing += 2.0) {
      widgets.add(
        Text(
          '[$spacing] $para',
          style: TextStyle(font: ttf, letterSpacing: spacing),
        ),
      );
      widgets.add(SizedBox(height: 30));
    }

    pdf.addPage(MultiPage(build: (Context context) => widgets));
  });

  test('Text Widgets background', () {
    final para = LoremText().paragraph(40);
    pdf.addPage(
      MultiPage(
        build: (Context context) => <Widget>[
          Text(
            para,
            style: TextStyle(
              font: ttf,
              background: const BoxDecoration(color: PdfColors.purple50),
            ),
          ),
        ],
      ),
    );
  });

  test('Text Widgets decoration', () {
    final widgets = <Widget>[];
    final decorations = <TextDecoration>[
      TextDecoration.underline,
      TextDecoration.lineThrough,
      TextDecoration.overline,
    ];

    final decorationSet = Set<TextDecoration>.from(
      permute(<TextDecoration>[], decorations),
    );

    for (final decorationStyle in TextDecorationStyle.values) {
      for (final decoration in decorationSet) {
        widgets.add(
          Text(
            decoration.toString().replaceAll('.', ' '),
            style: TextStyle(
              font: ttf,
              decoration: decoration,
              decorationColor: PdfColors.red,
              decorationStyle: decorationStyle,
            ),
          ),
        );
        widgets.add(SizedBox(height: 5));
      }
    }

    pdf.addPage(MultiPage(build: (Context context) => widgets));
  });

  test('Text Widgets RichText', () {
    final rnd = math.Random(42);
    final para = LoremText(random: rnd).paragraph(40);

    final spans = <TextSpan>[];
    for (final word in para.split(' ')) {
      spans.add(
        TextSpan(
          text: word,
          style: TextStyle(
            font: ttf,
            fontSize: rnd.nextDouble() * 20 + 20,
            color: PdfColors.primaries[rnd.nextInt(PdfColors.primaries.length)],
          ),
        ),
      );
      spans.add(const TextSpan(text: ' '));
    }

    pdf.addPage(
      MultiPage(
        build: (Context context) => <Widget>[
          RichText(
            text: TextSpan(
              text: 'Hello ',
              style: TextStyle(
                font: ttf,
                fontSize: 20,
                decoration: TextDecoration.underline,
              ),
              children: <InlineSpan>[
                TextSpan(
                  text: 'bold',
                  style: TextStyle(
                    font: ttfBold,
                    fontSize: 40,
                    color: PdfColors.blue,
                  ),
                  children: <InlineSpan>[
                    const TextSpan(text: '*', baseline: 20),
                    WidgetSpan(child: PdfLogo(), baseline: -10),
                  ],
                ),
                TextSpan(text: ' world!\n', children: spans),
                WidgetSpan(
                  child: PdfLogo(),
                  annotation: AnnotationUrl(
                    'https://github.com/DavBfr/dart_pdf',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  });

  test('Text Widgets RichText Multiple lang', () {
    pdf.addPage(
      Page(
        build: (Context context) => RichText(
          text: TextSpan(
            text: 'Hello ',
            style: TextStyle(font: ttf, fontSize: 20),
            children: <InlineSpan>[
              TextSpan(
                text: '中文',
                style: TextStyle(font: asian),
              ),
              const TextSpan(text: ' world!'),
            ],
          ),
        ),
      ),
    );
  });

  test('Text Widgets RichText maxLines', () {
    final rnd = math.Random(42);
    final para = LoremText(random: rnd).paragraph(30);

    pdf.addPage(
      Page(
        build: (Context context) => RichText(
          maxLines: 3,
          text: TextSpan(
            text: para,
            children: List<TextSpan>.generate(
              4,
              (index) => TextSpan(text: para),
            ),
          ),
        ),
      ),
    );
  });

  test('Text Widgets RichText overflow.span', () {
    final rnd = math.Random(42);
    final para = LoremText(random: rnd).paragraph(100);

    pdf.addPage(
      MultiPage(
        pageFormat: const PdfPageFormat(600, 200, marginAll: 10),
        build: (Context context) => [
          SizedBox(height: 90, width: 20),
          RichText(
            overflow: TextOverflow.span,
            textAlign: TextAlign.justify,
            text: TextSpan(
              text: para,
              children: [
                const TextSpan(text: ' '),
                const TextSpan(
                  text: 'Underline',
                  style: TextStyle(decoration: TextDecoration.underline),
                ),
                const TextSpan(text: '. '),
                TextSpan(text: para),
                TextSpan(text: para),
                TextSpan(text: para),
              ],
            ),
          ),
        ],
      ),
    );
  });

  test('Text Widgets Justify multiple paragraphs', () {
    const para =
        'This is the first paragraph with a small nice text.\nHere is a new line.\nAnother one.\nAnd finally a long paragraph to finish this test with a three lines text that finishes well.';

    pdf.addPage(
      Page(
        build: (Context context) => SizedBox(
          width: 200,
          child: Text(para, textAlign: TextAlign.justify),
        ),
      ),
    );
  });

  test('Text Widgets Emojis', () {
    pdf.addPage(
      Page(
        build: (Context context) => Text(
          'Hello 🐈! Dancing 💃🏃',
          style: TextStyle(fontSize: 30, fontFallback: [emoji]),
        ),
      ),
    );
  });

  group('the minimum content width', () {
    /// The narrowest [widget] can be, and the widest it wants to be.
    Future<List<double>> widths(Widget widget) async {
      late double min;
      late double max;

      final document = Document();
      document.addPage(
        Page(
          build: (Context context) {
            widget.layout(
              context.inheritFrom(const MinContentWidth()),
              const BoxConstraints(),
            );
            min = widget.box!.width;
            widget.layout(context, const BoxConstraints());
            max = widget.box!.width;
            return SizedBox();
          },
        ),
      );
      await document.save();

      return <double>[min, max];
    }

    test('is the widest piece that cannot be broken', () async {
      // The table solver needs a floor per column, and this is it: the narrowest
      // a paragraph can be without a word being cut in half.
      final oneWord = await widths(Text('hello'));
      expect(oneWord.first, oneWord.last, reason: 'nothing to break');

      final twoWords = await widths(Text('hello world'));
      expect(twoWords.first, lessThan(twoWords.last));
      expect(
        twoWords.first,
        (await widths(Text('world'))).first,
        reason: 'the wider of the two words',
      );

      // A newline is already a break, so it does not widen the minimum.
      final newline = await widths(Text('hello\nworldwide'));
      expect(newline.first, (await widths(Text('worldwide'))).first);
      expect(newline.first, newline.last);
    });

    test('counts letterSpacing', () async {
      final plain = await widths(Text('hello world'));
      final spaced = await widths(
        Text('hello world', style: const TextStyle(letterSpacing: 2)),
      );

      // 'world' is five letters, so four gaps of 2pt.
      expect(spaced.first, closeTo(plain.first + 8, 1e-9));
    });

    test('breaks at a hyphen, and keeps the hyphen', () async {
      final hyphenated = await widths(Text('some-thing'));
      expect(hyphenated.first, lessThan(hyphenated.last));
      expect(
        hyphenated.first,
        (await widths(Text('some-'))).first,
        reason: 'the head of the break carries its hyphen',
      );
    });
  });

  group('TextStyle.height', () {
    const paragraph =
        'The quick brown fox jumps over the lazy dog and keeps running for a '
        'while';

    /// The box height of [paragraph] in a 200pt column.
    Future<double> heightOf({
      double? height,
      double lineSpacing = 0,
      TextStyle? style,
    }) async {
      late RichText laid;
      final document = Document();
      document.addPage(
        Page(
          pageFormat: const PdfPageFormat(400, 900, marginAll: 0),
          build: (Context context) => SizedBox(
            width: 200,
            child: laid = RichText(
              text: TextSpan(
                text: paragraph,
                style:
                    style ??
                    TextStyle(
                      font: ttf,
                      fontSize: 10,
                      height: height,
                      lineSpacing: lineSpacing,
                    ),
              ),
            ),
          ),
        ),
      );
      await document.save();
      return laid.box!.height;
    }

    test('scales the line height by exactly that much', () async {
      // The field was declared, defaulted and carried by copyWith, apply and
      // merge, and read by no layout code at all: the same paragraph measured
      // the same at height null, 0.5, 1, 2, 4 and 10.
      final base = await heightOf(height: 1);

      for (final factor in <double>[0.5, 1, 1.5, 2, 3, 10]) {
        expect(
          await heightOf(height: factor),
          closeTo(base * factor, 1e-9),
          reason: 'height $factor',
        );
      }
    });

    test('unset, 1 and the theme default all mean the same', () async {
      final base = await heightOf(height: 1);

      expect(await heightOf(), closeTo(base, 1e-9), reason: 'null');
      expect(
        await heightOf(style: TextStyle(font: ttf, fontSize: 10)),
        closeTo(base, 1e-9),
      );
    });

    test('is a multiple, where lineSpacing is absolute points', () async {
      // Two lines in this column, so one gap between them.
      final natural = await heightOf(height: 1) / 2;

      expect(
        await heightOf(height: 2, lineSpacing: 3),
        closeTo(2 * natural * 2 + 3, 1e-9),
      );
    });

    test('a line takes the largest of its spans', () async {
      late RichText laid;
      final document = Document();
      document.addPage(
        Page(
          pageFormat: const PdfPageFormat(400, 300, marginAll: 0),
          build: (Context context) => laid = RichText(
            text: TextSpan(
              style: TextStyle(font: ttf, fontSize: 10),
              children: <TextSpan>[
                const TextSpan(text: 'one '),
                TextSpan(
                  text: 'two',
                  style: TextStyle(font: ttf, fontSize: 10, height: 2),
                ),
              ],
            ),
          ),
        ),
      );
      await document.save();

      final single = await heightOf(height: 1) / 2;
      expect(laid.box!.height, closeTo(2 * single, 1e-9));
    });

    test('an empty line scales too', () async {
      late RichText laid;
      Future<double> blankLines(double height) async {
        final document = Document();
        document.addPage(
          Page(
            pageFormat: const PdfPageFormat(400, 300, marginAll: 0),
            build: (Context context) => laid = RichText(
              text: TextSpan(
                text: 'a\n\nb',
                style: TextStyle(font: ttf, fontSize: 10, height: height),
              ),
            ),
          ),
        );
        await document.save();
        return laid.box!.height;
      }

      expect(await blankLines(2), closeTo(2 * await blankLines(1), 1e-9));
    });

    test('apply can scale it', () {
      // The assert here read `heightFactor == 1.0 && heightDelta == 0.0`, which
      // refused to scale a height that was set, unlike the three fields beside
      // it. An inheriting style, because apply() does not carry lineSpacing and
      // so cannot be called on a style that has inherit false at all - a defect
      // of its own, not this one.
      expect(const TextStyle(height: 1).apply(heightFactor: 2).height, 2.0);
      expect(const TextStyle(height: 2).apply(heightDelta: 1).height, 3.0);
      // And, like the three fields beside it, scaling a height that is not set
      // is a mistake worth an assert.
      expect(
        () => const TextStyle().apply(heightFactor: 2),
        throwsA(isA<AssertionError>()),
      );
      expect(const TextStyle().apply().height, isNull);
    });
  });

  group('a paragraph of nothing but whitespace', () {
    /// The box [child] lays out to.
    Future<PdfRect> boxOf(RichText Function() child) async {
      late RichText laid;
      final document = Document();
      document.addPage(
        Page(
          pageFormat: const PdfPageFormat(400, 300, marginAll: 0),
          build: (Context context) {
            laid = child();
            return laid;
          },
        ),
      );
      await document.save();
      return laid.box!;
    }

    Future<PdfRect> textBox(String text) =>
        boxOf(() => Text(text, style: TextStyle(font: ttf, fontSize: 12)));

    test('reserves one line', () async {
      // A whitespace-only string yields only empty runs, which move the pen but
      // create no word, so no line was ever appended: offsetY never advanced and
      // the box came out 0 x 0. A table row of empty cells collapsed to a
      // hairline and a Text(' ') spacer added no width at all.
      final line = (await textBox('X')).height;
      expect(line, closeTo(16.341796875, 1e-9));

      expect((await textBox('')).width, 0.0);
      expect((await textBox('')).height, closeTo(line, 1e-9));

      expect((await textBox(' ')).width, closeTo(3.1171875, 1e-9));
      expect((await textBox(' ')).height, closeTo(line, 1e-9));

      expect((await textBox('  ')).width, closeTo(6.234375, 1e-9));
      expect((await textBox('  ')).height, closeTo(line, 1e-9));
    });

    test('leaves everything that did lay out alone', () async {
      expect((await textBox('X')).width, closeTo(6.92578125, 1e-9));
      expect((await textBox('a b')).width, closeTo(17.14453125, 1e-9));

      final newline = await textBox('\n');
      expect(newline.width, 0.0);
      expect(newline.height, closeTo(16.341796875, 1e-9));

      final blankLine = await textBox('a\n\nb');
      expect(blankLine.width, closeTo(7.353515625, 1e-9));
      expect(blankLine.height, closeTo(49.025390625, 1e-9));

      // A span with no text at all is still nothing.
      final empty = await boxOf(
        () => RichText(
          text: TextSpan(style: TextStyle(font: ttf, fontSize: 12)),
        ),
      );
      expect(empty.width, 0.0);
      expect(empty.height, 0.0);
    });

    test('works as a spacer in a Row', () async {
      late RichText post;
      final document = Document();
      document.addPage(
        Page(
          pageFormat: const PdfPageFormat(400, 300, marginAll: 0),
          build: (Context context) => Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
              Text('pre', style: TextStyle(font: ttf, fontSize: 12)),
              Text(' ', style: TextStyle(font: ttf, fontSize: 12)),
              post = Text('post', style: TextStyle(font: ttf, fontSize: 12)),
            ],
          ),
        ),
      );
      await document.save();

      // Where 'pre post' as one paragraph puts 'post'. The spacer used to add
      // nothing, so the two words ran together.
      final joined = Document(compress: false);
      joined.addPage(
        Page(
          pageFormat: const PdfPageFormat(400, 300, marginAll: 0),
          build: (Context context) =>
              Text('pre post', style: TextStyle(font: ttf, fontSize: 12)),
        ),
      );
      final xs = RegExp(r'([-\d.]+) [-\d.]+ Td \[<')
          .allMatches(String.fromCharCodes(await joined.save()))
          .map((RegExpMatch m) => double.parse(m.group(1)!))
          .toList();

      expect(xs, hasLength(2));
      expect(post.box!.x, closeTo(xs.last, 0.001));
    });
  });

  group('maxLines with a line broken by a WidgetSpan', () {
    /// The distinct text baselines [child] paints, and its own box.
    Future<List<Object>> layOut(Widget Function() child) async {
      late RichText laid;
      final document = Document(compress: false);
      document.addPage(
        Page(
          pageFormat: const PdfPageFormat(100, 300, marginAll: 0),
          build: (Context context) {
            final widget = child();
            laid = widget as RichText;
            return widget;
          },
        ),
      );

      final pdf = String.fromCharCodes(await document.save());
      final baselines = RegExp(
        r'[-\d.]+ ([-\d.]+) Td \[\(',
      ).allMatches(pdf).map((RegExpMatch m) => m.group(1)!).toSet();

      return <Object>[baselines.length, laid.box!.height];
    }

    test('lays out exactly maxLines lines', () async {
      // The WidgetSpan branch tested `lines.length > _maxLines`, above the line
      // reset, where both text branches test `>=` below it. So one line too many
      // was built, and on the way out offsetY had not advanced for it: the box
      // came out a line short of what was painted and the surplus line landed on
      // top of whatever followed.
      for (final maxLines in <int>[1, 2, 3]) {
        final withWidgets = await layOut(
          () => RichText(
            maxLines: maxLines,
            text: TextSpan(
              style: const TextStyle(fontSize: 10),
              children: <InlineSpan>[
                for (var i = 0; i < 6; i++) ...<InlineSpan>[
                  TextSpan(text: 'W$i'),
                  WidgetSpan(
                    child: SizedBox(
                      width: 60,
                      height: 8,
                      child: Container(color: PdfColors.grey),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );

        expect(
          withWidgets.first,
          maxLines,
          reason: 'maxLines $maxLines: one baseline per line',
        );

        // And the box covers exactly those lines, as a text-only paragraph of
        // the same height does.
        final textOnly = await layOut(
          () => RichText(
            maxLines: maxLines,
            text: const TextSpan(
              style: TextStyle(fontSize: 10),
              text: 'aaaaaa bbbbbb cccccc dddddd eeeeee ffffff',
            ),
          ),
        );

        expect(withWidgets.last, textOnly.last, reason: 'maxLines $maxLines');
      }
    });

    test('holds when the break falls on an emoji', () async {
      for (final maxLines in <int>[1, 2]) {
        final laid = await layOut(
          () => RichText(
            maxLines: maxLines,
            text: TextSpan(
              style: TextStyle(fontSize: 10, fontFallback: <Font>[emoji]),
              text: 'aaa 🐈 bbb 🐈 ccc 🐈 ddd 🐈 eee',
            ),
          ),
        );

        expect(laid.first, maxLines, reason: 'maxLines $maxLines');
      }
    });
  });

  group('letterSpacing at a span boundary', () {
    /// The x of each `Td` that precedes a literal text run.
    Future<List<double>> positions(
      List<String> parts, {
      double letterSpacing = 0,
      TextAlign? textAlign,
      double width = 600,
    }) async {
      final document = Document(compress: false);
      document.addPage(
        Page(
          pageFormat: PdfPageFormat(width, 120, marginAll: 0),
          build: (Context context) => SizedBox(
            width: width,
            child: RichText(
              textAlign: textAlign,
              text: TextSpan(
                style: TextStyle(fontSize: 20, letterSpacing: letterSpacing),
                children: <TextSpan>[
                  for (final part in parts) TextSpan(text: part),
                ],
              ),
            ),
          ),
        ),
      );

      final pdf = String.fromCharCodes(await document.save());
      return RegExp(r'([-\d.]+) [-\d.]+ Td \[\(')
          .allMatches(pdf)
          .map((RegExpMatch m) => double.parse(m.group(1)!))
          .toList();
    }

    test('adds no gap of its own', () async {
      // The end-of-span statement read `-= gap - letterSpacing`, which parses as
      // -(gap) + spacing rather than -(gap + spacing), so the pen sat two letter
      // spacings too far right after every span.
      expect(
        await positions(<String>['AAA', 'BBB', 'CCC'], letterSpacing: 5),
        <double>[0, 55.02, 110.04],
      );
    });

    test('is unchanged at zero, which is the default', () async {
      expect(await positions(<String>['AAA', 'BBB', 'CCC']), <double>[
        0,
        40.02,
        80.04,
      ]);
    });

    test('splitting text into spans does not move it', () async {
      for (final spacing in <double>[0, 2, 5]) {
        final whole = await positions(<String>[
          'AAA BBB CCC',
        ], letterSpacing: spacing);
        final split = await positions(<String>[
          'AAA ',
          'BBB ',
          'CCC',
        ], letterSpacing: spacing);

        expect(split, whole, reason: 'letterSpacing $spacing');
      }
    });

    test('a centred line of several spans sits where one span does', () async {
      // Centring divides what the line measured, so a span boundary that moved
      // the pen moved the whole line off centre.
      for (final align in <TextAlign>[
        TextAlign.center,
        TextAlign.right,
        TextAlign.left,
      ]) {
        final whole = await positions(
          <String>['AAA BBB CCC'],
          letterSpacing: 5,
          textAlign: align,
          width: 300,
        );
        final split = await positions(
          <String>['AAA ', 'BBB ', 'CCC'],
          letterSpacing: 5,
          textAlign: align,
          width: 300,
        );

        expect(split, whole, reason: '$align');
        if (align == TextAlign.center) {
          expect(whole.first, greaterThan(0), reason: 'it did move');
        }
      }
    });
  });

  group('a run served by a fallback font', () {
    late Font arabicFont;

    setUpAll(() {
      arabicFont = loadFont('hacen-tunisia.ttf');
    });

    test('is one span, and joins', () async {
      // A span was emitted for each unsupported rune on its own, and shaping
      // works on a span, so a one-character span could only ever produce the
      // isolated form: 'محمد' came out as four unjoined letters in four runs.
      for (final word in <String>['محمد', 'مرحبا']) {
        final viaFallback = cidRuns(
          await fallbackPage(word, font: ttf, fontFallback: <Font>[arabicFont]),
        );
        final asBase = cidRuns(await fallbackPage(word, font: arabicFont));

        expect(viaFallback, hasLength(1), reason: word);
        expect(
          viaFallback.single.length ~/ 4,
          word.length,
          reason: '$word: one glyph per letter',
        );
        expect(
          viaFallback,
          asBase,
          reason: '$word: the same run the base font would draw',
        );
      }
    });

    test('is joined the way the shaper says', () async {
      // U+FEAA U+FEE4 U+FEA4 U+FEE3: dal final, meem medial, hah initial, meem
      // isolated, which is 'محمد' shaped and in visual order.
      final pdf = await fallbackPage(
        'محمد',
        font: ttf,
        fontFallback: <Font>[arabicFont],
      );

      final toUnicode = <int, int>{};
      for (final entry in RegExp(
        r'<([0-9A-F]{4})> <([0-9A-F]{4})>',
      ).allMatches(pdf)) {
        toUnicode[int.parse(entry.group(1)!, radix: 16)] = int.parse(
          entry.group(2)!,
          radix: 16,
        );
      }

      final cids = cidRuns(pdf).single;
      expect(
        <int>[
          for (var i = 0; i + 4 <= cids.length; i += 4)
            toUnicode[int.parse(cids.substring(i, i + 4), radix: 16)]!,
        ],
        <int>[0xFEAA, 0xFEE4, 0xFEA4, 0xFEE3],
      );
    });

    test('a mixed sentence is one run per script', () async {
      final runs = cidRuns(
        await fallbackPage(
          'Hello مرحبا world',
          font: ttf,
          fontFallback: <Font>[arabicFont],
        ),
      );

      expect(runs, hasLength(3), reason: 'Hello, the Arabic word, world');
      expect(runs[1].length ~/ 4, 5, reason: 'the Arabic word is whole');
    });

    test('wraps on word boundaries, not inside words', () async {
      // Each letter used to be its own word, so a line could break anywhere
      // inside the Arabic and justify stretched the gaps between its letters.
      final pdf = await fallbackPage(
        'Hello مرحبا world',
        font: ttf,
        fontFallback: <Font>[arabicFont],
        width: 140,
      );

      final runs = cidRuns(pdf);
      expect(runs, hasLength(3), reason: 'still three words');
      expect(runsPerLine(pdf).reduce((int a, int b) => a + b), 3);
      expect(runs.map((String run) => run.length ~/ 4), <int>[
        5,
        5,
        5,
      ], reason: 'Hello, the five Arabic letters, world - none of them split');
    });

    test('an emoji ends the run either side of it', () async {
      final emojiFont = loadFont('emoji.ttf');
      final runs = cidRuns(
        await fallbackPage(
          'م\u{1F600}م',
          font: ttf,
          fontFallback: <Font>[arabicFont, emojiFont],
        ),
      );

      expect(runs, hasLength(2));
      expect(runs.every((String run) => run.length == 4), isTrue);
    });

    test('a rune no font covers ends it too', () async {
      // U+0E01 is Thai: neither open-sans nor hacen-tunisia has it.
      final runs = cidRuns(
        await fallbackPage(
          'م\u0E01م',
          font: ttf,
          fontFallback: <Font>[arabicFont],
        ),
      );

      expect(runs, hasLength(2));
    });

    test('every rune ends up in exactly one span', () async {
      // The coverage assert inside _preProcessSpans is what this exercises: the
      // runs have to tile the source text with nothing dropped or repeated.
      final random = math.Random(20260929);
      const pool = <int>[
        0x61,
        0x62,
        0x20,
        0x645,
        0x631,
        0x62D,
        0x0E01,
        0x1F600,
        0x0A,
        0xFE0F,
        0x00AD,
        0x30,
      ];

      for (var round = 0; round < 40; round++) {
        final runes = <int>[
          for (var i = 0; i < 1 + random.nextInt(12); i++)
            pool[random.nextInt(pool.length)],
        ];

        await expectLater(
          fallbackPage(
            String.fromCharCodes(runes),
            font: ttf,
            fontFallback: <Font>[arabicFont, emoji],
          ),
          completes,
          reason: runes.map((int r) => r.toRadixString(16)).join(','),
        );
      }
    });
  });

  tearDownAll(() async {
    final file = File('widgets-text.pdf');
    await file.writeAsBytes(await pdf.save());
  });
}
