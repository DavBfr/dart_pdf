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

// ignore_for_file: omit_local_variable_types

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart';

Document pdf;
Font ttf;
Font ttfBold;

Iterable<TextDecoration> permute(
    List<TextDecoration> prefix, List<TextDecoration> remaining) sync* {
  yield TextDecoration.combine(prefix);
  if (remaining.isNotEmpty) {
    for (TextDecoration decoration in remaining) {
      final List<TextDecoration> next = List<TextDecoration>.from(remaining);
      next.remove(decoration);
      yield* permute(prefix + <TextDecoration>[decoration], next);
    }
  }
}

void main() {
  setUpAll(() {
    Document.debug = true;
    RichText.debug = true;
    final Uint8List fontData = File('open-sans.ttf').readAsBytesSync();
    ttf = Font.ttf(fontData.buffer.asByteData());
    final Uint8List fontDataBold = File('open-sans-bold.ttf').readAsBytesSync();
    ttfBold = Font.ttf(fontDataBold.buffer.asByteData());
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
    pdf.addPage(MultiPage(
        build: (Context context) => <Widget>[
              Text(
                'Text with\nsoft wrap\nenabled',
                softWrap: true,
              ),
              Text(
                'Text with\nsoft wrap\ndisabled',
                softWrap: false,
              ),
            ]));
  });

  test('Text Widgets Alignement', () {
    final String para = LoremText().paragraph(40);

    final List<Widget> widgets = <Widget>[];
    for (TextAlign align in TextAlign.values) {
      widgets.add(
        Text(
          '$align:\n' + para,
          textAlign: align,
          softWrap: true,
        ),
      );
    }

    pdf.addPage(MultiPage(build: (Context context) => widgets));
  });

  test('Text Widgets lineSpacing', () {
    final String para = LoremText().paragraph(40);

    final List<Widget> widgets = <Widget>[];
    for (double spacing = 0.0; spacing < 10.0; spacing += 2.0) {
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
    final String para = LoremText().paragraph(40);

    final List<Widget> widgets = <Widget>[];
    for (double spacing = 0.0; spacing < 10.0; spacing += 2.0) {
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
    final String para = LoremText().paragraph(40);

    final List<Widget> widgets = <Widget>[];
    for (double spacing = 0.0; spacing < 10.0; spacing += 2.0) {
      widgets.add(
        Text(para, style: TextStyle(font: ttf, letterSpacing: spacing)),
      );
      widgets.add(
        SizedBox(height: 30),
      );
    }

    pdf.addPage(MultiPage(build: (Context context) => widgets));
  });

  test('Text Widgets background', () {
    final String para = LoremText().paragraph(40);
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
    final List<Widget> widgets = <Widget>[];
    final List<TextDecoration> decorations = <TextDecoration>[
      TextDecoration.underline,
      TextDecoration.lineThrough,
      TextDecoration.overline
    ];

    final Set<TextDecoration> decorationSet = Set<TextDecoration>.from(
      permute(
        <TextDecoration>[],
        decorations,
      ),
    );

    for (TextDecorationStyle decorationStyle in TextDecorationStyle.values) {
      for (TextDecoration decoration in decorationSet) {
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
    final math.Random rnd = math.Random(42);
    final String para = LoremText(random: rnd).paragraph(40);

    final List<TextSpan> spans = <TextSpan>[];
    for (String word in para.split(' ')) {
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

  test('Text Widgets Arabic', () {
    final Uint8List fontData = File('hacen-tunisia.ttf').readAsBytesSync();
    final Font ttf = Font.ttf(fontData.buffer.asByteData());

    pdf.addPage(Page(
      build: (Context context) => RichText(
        textDirection: TextDirection.rtl,
        text: TextSpan(
          text: 'قهوة\n',
          style: TextStyle(
            font: ttf,
            fontSize: 30,
          ),
          children: const <TextSpan>[
            TextSpan(
              text:
                  'القهوة مشروب يعد من بذور الب المحمصة، وينمو في أكثر من 70 لداً. خصوصاً في المناطق الاستوائية في أمريكا الشمالية والجنوبية وجنوب شرق آسيا وشبه القارة الهندية وأفريقيا. ويقال أن البن الأخضر هو ثاني أكثر السلع تداولاً في العالم بعد النفط الخام.',
              style: TextStyle(
                fontSize: 20,
              ),
            ),
          ],
        ),
      ),
    ));
  });

  tearDownAll(() {
    final File file = File('widgets-text.pdf');
    file.writeAsBytesSync(pdf.save());
  });
}
