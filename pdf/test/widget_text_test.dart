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
Font? ttf;
Font? ttfBold;
Font? asian;

Iterable<TextDecoration> permute(
    List<TextDecoration> prefix, List<TextDecoration> remaining) sync* {
  yield TextDecoration.combine(prefix);
  if (remaining.isNotEmpty) {
    for (var decoration in remaining) {
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
    pdf = Document();
  });

  test('Text Widgets Quotes', () {
    pdf.addPage(Page(
        build: (Context context) => Text('Text containing \' or " works!')));
  });

  test('Text Widgets Unicode Quotes', () {
    pdf.addPage(Page(
        build: (Context context) => Text('Text containing ’ and ” works!',
            style: TextStyle(font: ttf))));
  });

  test('Text Widgets softWrap', () {
    final para = LoremText().paragraph(40);

    pdf.addPage(
      MultiPage(
        build: (Context context) => <Widget>[
          Text(
            'Text with\nsoft wrap\nenabled',
            softWrap: true,
          ),
          Text(
            'Text with\nsoft wrap\ndisabled',
            softWrap: false,
          ),
          SizedBox(
            width: 120,
            child: Text(
              para,
              softWrap: false,
            ),
          ),
          SizedBox(
            width: 120,
            child: Text(
              para,
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  });

  test('Text Widgets Alignement', () {
    final para = LoremText().paragraph(40);

    final widgets = <Widget>[];
    for (var align in TextAlign.values) {
      widgets.add(
        Text(
          '$align:\n' + para,
          textAlign: align,
        ),
      );
    }

    pdf.addPage(MultiPage(build: (Context context) => widgets));
  });

  test('Text Widgets lineSpacing', () {
    final para = LoremText().paragraph(40);

    final widgets = <Widget>[];
    for (var spacing = 0.0; spacing < 10.0; spacing += 2.0) {
      widgets.add(
        Text(para, style: TextStyle(font: ttf, lineSpacing: spacing)),
      );
      widgets.add(
        SizedBox(height: 30),
      );
    }

    pdf.addPage(MultiPage(build: (Context context) => widgets));
  });

  test('Text Widgets wordSpacing', () {
    final para = LoremText().paragraph(40);

    final widgets = <Widget>[];
    for (var spacing = 0.0; spacing < 10.0; spacing += 2.0) {
      widgets.add(
        Text(para, style: TextStyle(font: ttf, wordSpacing: spacing)),
      );
      widgets.add(
        SizedBox(height: 30),
      );
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
      widgets.add(
        SizedBox(height: 30),
      );
    }

    pdf.addPage(MultiPage(build: (Context context) => widgets));
  });

  test('Text Widgets background', () {
    final para = LoremText().paragraph(40);
    pdf.addPage(MultiPage(
        build: (Context context) => <Widget>[
              Text(
                para,
                style: TextStyle(
                  font: ttf,
                  background: const BoxDecoration(color: PdfColors.purple50),
                ),
              ),
            ]));
  });

  test('Text Widgets decoration', () {
    final widgets = <Widget>[];
    final decorations = <TextDecoration>[
      TextDecoration.underline,
      TextDecoration.lineThrough,
      TextDecoration.overline
    ];

    final decorationSet = Set<TextDecoration>.from(
      permute(
        <TextDecoration>[],
        decorations,
      ),
    );

    for (var decorationStyle in TextDecorationStyle.values) {
      for (var decoration in decorationSet) {
        widgets.add(
          Text(
            decoration.toString().replaceAll('.', ' '),
            style: TextStyle(
                font: ttf,
                decoration: decoration,
                decorationColor: PdfColors.red,
                decorationStyle: decorationStyle),
          ),
        );
        widgets.add(
          SizedBox(height: 5),
        );
      }
    }

    pdf.addPage(MultiPage(build: (Context context) => widgets));
  });

  test('Text Widgets RichText', () {
    final rnd = math.Random(42);
    final para = LoremText(random: rnd).paragraph(40);

    final spans = <TextSpan>[];
    for (var word in para.split(' ')) {
      spans.add(
        TextSpan(
          text: '$word',
          style: TextStyle(
              font: ttf,
              fontSize: rnd.nextDouble() * 20 + 20,
              color:
                  PdfColors.primaries[rnd.nextInt(PdfColors.primaries.length)]),
        ),
      );
      spans.add(const TextSpan(text: ' '));
    }

    pdf.addPage(MultiPage(
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
                            font: ttfBold, fontSize: 40, color: PdfColors.blue),
                        children: <InlineSpan>[
                          const TextSpan(text: '*', baseline: 20),
                          WidgetSpan(child: PdfLogo(), baseline: -10),
                        ]),
                    TextSpan(
                      text: ' world!\n',
                      children: spans,
                    ),
                    WidgetSpan(
                        child: PdfLogo(),
                        annotation: AnnotationUrl(
                          'https://github.com/DavBfr/dart_pdf',
                        )),
                  ],
                ),
              ),
            ]));
  });

  test('Text Widgets RichText Multiple lang', () {
    pdf.addPage(Page(
      build: (Context context) => RichText(
        text: TextSpan(
          text: 'Hello ',
          style: TextStyle(
            font: ttf,
            fontSize: 20,
          ),
          children: <InlineSpan>[
            TextSpan(
              text: '中文',
              style: TextStyle(font: asian),
            ),
            const TextSpan(
              text: ' world!',
            ),
          ],
        ),
      ),
    ));
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
          child: Text(
            para,
            textAlign: TextAlign.justify,
          ),
        ),
      ),
    );
  });

  tearDownAll(() async {
    final file = File('widgets-text.pdf');
    await file.writeAsBytes(await pdf.save());
  });
}
