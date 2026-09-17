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

  tearDownAll(() async {
    final file = File('widgets-text.pdf');
    await file.writeAsBytes(await pdf.save());
  });
}
