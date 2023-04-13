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

import 'package:pdf/src/pdf/font/arabic.dart' as arabic;
import 'package:pdf/widgets.dart';
import 'package:test/test.dart';

import 'utils.dart';

class ArabicText {
  ArabicText(this.original, this.reshaped);

  final String original;
  final List<int> reshaped;

  String get originalRev => original.split('').reversed.join('');
}

late Document pdf;
Font? arabicFont;
TextStyle? style;

void main() {
  setUpAll(() {
    Document.debug = true;
    RichText.debug = true;
    pdf = Document();

    arabicFont = loadFont('hacen-tunisia.ttf');
    style = TextStyle(font: arabicFont, fontSize: 30);
  });

  test('Arabic Diacritics', () {
    final a = ArabicText('السلام', <int>[1605, 65276, 65204, 65247, 1575]);
    final b = ArabicText('السَلَاْمٌ',
        <int>[1612, 1605, 1618, 1614, 65276, 1614, 65204, 65247, 1575]);

    expect(
      arabic.convert(a.original).codeUnits,
      equals(a.reshaped),
    );
    expect(
      arabic.convert(b.original).codeUnits,
      equals(b.reshaped),
    );
  });

  test('Arabic Default Reshaping', () {
    final cases = <ArabicText>[
      ArabicText('الـــسَلاْمُ عَلَيْكُمْ', <int>[
        1615,
        1605,
        1618,
        65276,
        1614,
        65204,
        1600,
        1600,
        1600,
        65247,
        1575,
        32,
        1618,
        65250,
        1615,
        65244,
        1618,
        65268,
        1614,
        65248,
        1614,
        65227
      ]),
      ArabicText('الــلغـة العــربيَّة هي أكثرُ اللغاتِ', <int>[
        65172,
        1600,
        65232,
        65248,
        1600,
        1600,
        65247,
        1575,
        32,
        65172,
        64608,
        65268,
        65169,
        65198,
        1600,
        1600,
        65228,
        65247,
        1575,
        32,
        65266,
        65259,
        32,
        1615,
        65198,
        65180,
        65243,
        1571,
        32,
        1616,
        1578,
        65166,
        65232,
        65248,
        65247,
        1575
      ]),
      ArabicText('تحدُّثاً ونُطقاً ضِمْنَ مَجمُوعَة', <int>[
        1611,
        65166,
        65179,
        64609,
        65194,
        65188,
        65175,
        32,
        1611,
        65166,
        65240,
        65220,
        1615,
        65255,
        1608,
        32,
        1614,
        65254,
        1618,
        65252,
        1616,
        65215,
        32,
        65172,
        1614,
        65227,
        65262,
        1615,
        65252,
        65184,
        1614,
        65251
      ]),
      ArabicText('اللغات السامية', <int>[
        1578,
        65166,
        65232,
        65248,
        65247,
        1575,
        32,
        65172,
        65268,
        65251,
        65166,
        65204,
        65247,
        1575
      ]),
      ArabicText('العربية لغةٌ رسميةٌ في', <int>[
        65172,
        65268,
        65169,
        65198,
        65228,
        65247,
        1575,
        32,
        1612,
        65172,
        65232,
        65247,
        32,
        1612,
        65172,
        65268,
        65252,
        65203,
        1585,
        32,
        65266,
        65235
      ]),
      ArabicText('كلِّ دولِ الوطنِ العربيِّ', <int>[
        64610,
        65246,
        65243,
        32,
        1616,
        1604,
        1608,
        1583,
        32,
        1616,
        65254,
        65219,
        65262,
        65247,
        1575,
        32,
        64610,
        65266,
        65169,
        65198,
        65228,
        65247,
        1575
      ]),
      ArabicText('إضافة إلىّٰ كونها لغة؟', <int>[
        65172,
        65235,
        65166,
        65215,
        1573,
        32,
        64611,
        65264,
        65247,
        1573,
        32,
        65166,
        65260,
        65255,
        65262,
        65243,
        32,
        65172,
        65232,
        65247,
        1567
      ]),
      ArabicText('رسمية في تشاد وإريتريا', <int>[
        65172,
        65268,
        65252,
        65203,
        1585,
        32,
        65266,
        65235,
        32,
        1583,
        65166,
        65208,
        65175,
        32,
        65166,
        65267,
        65198,
        65176,
        65267,
        1585,
        1573,
        1608
      ]),
      ArabicText('وإسرائيل. وهي إحدى اللغات', <int>[
        46,
        65246,
        65268,
        65163,
        1575,
        65198,
        65203,
        1573,
        1608,
        32,
        65266,
        65259,
        1608,
        32,
        1609,
        65194,
        65187,
        1573,
        32,
        1578,
        65166,
        65232,
        65248,
        65247,
        1575
      ]),
      ArabicText('الرسمية الست في منظمة', <int>[
        65172,
        65268,
        65252,
        65203,
        65198,
        65247,
        1575,
        32,
        65174,
        65204,
        65247,
        1575,
        32,
        65266,
        65235,
        32,
        65172,
        65252,
        65224,
        65256,
        65251
      ]),
      ArabicText('الأمم المتحدة، ويُحتفل', <int>[
        65250,
        65251,
        65271,
        1575,
        32,
        1577,
        65194,
        65188,
        65176,
        65252,
        65247,
        1575,
        1548,
        32,
        65246,
        65236,
        65176,
        65188,
        1615,
        65267,
        1608
      ]),
      ArabicText('باليوم العالمي للغة العربية', <int>[
        1605,
        65262,
        65268,
        65247,
        65166,
        65169,
        32,
        65266,
        65252,
        65247,
        65166,
        65228,
        65247,
        1575,
        32,
        65172,
        65232,
        65248,
        65247,
        32,
        65172,
        65268,
        65169,
        65198,
        65228,
        65247,
        1575
      ]),
      ArabicText('في 18 ديسمبر كذكرى اعتماد', <int>[
        65266,
        65235,
        32,
        49,
        56,
        32,
        65198,
        65170,
        65252,
        65204,
        65267,
        1583,
        32,
        1609,
        65198,
        65243,
        65196,
        65243,
        32,
        1583,
        65166,
        65252,
        65176,
        65227,
        1575
      ]),
      ArabicText('العربية بين لغات العمل في', <int>[
        65172,
        65268,
        65169,
        65198,
        65228,
        65247,
        1575,
        32,
        65254,
        65268,
        65169,
        32,
        1578,
        65166,
        65232,
        65247,
        32,
        65246,
        65252,
        65228,
        65247,
        1575,
        32,
        65266,
        65235
      ]),
      ArabicText('الأمم المتحدة.', <int>[
        65250,
        65251,
        65271,
        1575,
        32,
        46,
        1577,
        65194,
        65188,
        65176,
        65252,
        65247,
        1575,
      ]),
    ];

    pdf.addPage(
      MultiPage(
        crossAxisAlignment: CrossAxisAlignment.end,
        build: (Context context) => <Widget>[
          for (ArabicText item in cases)
            Padding(
              padding: const EdgeInsets.only(bottom: 15),
              child: Text(
                item.original,
                textDirection: TextDirection.rtl,
                style: style,
              ),
            ),
        ],
      ),
    );

    for (final item in cases) {
      expect(
        arabic.convert(item.original).codeUnits,
        equals(item.reshaped),
      );
    }
  });

  test('Text Widgets Arabic', () {
    pdf.addPage(Page(
      build: (Context context) => RichText(
        textDirection: TextDirection.rtl,
        text: TextSpan(
          text: 'قهوة\n',
          style: TextStyle(
            font: arabicFont,
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

  test('Text Widgets Arabic with TextAlign.justify', () {
    pdf.addPage(Page(
      build: (Context context) => RichText(
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.justify,
        text: TextSpan(
          text: 'قهوة\n',
          style: TextStyle(
            font: arabicFont,
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

  test(
      'Text Widgets, Mixed Arabic and Latin words should be rendered in order ',
      () {
    pdf.addPage(Page(
      textDirection: TextDirection.rtl,
      build: (Context context) => RichText(
        text: TextSpan(
          text: 'النصوص ثنائية الإتجاه Bidirectional Text\n',
          style: TextStyle(
            font: arabicFont,
            fontSize: 30,
          ),
          children: const <TextSpan>[
            TextSpan(
              text: r'''
الكلمات اللاتينية المضافة إلى نص عربي يجب أن توضع في الترتيب الصحيح Right Order مهما كان موضعها في النص.
At the Beginning of the sentence في بداية الجملة
أو في منتصفها In the middle of the sentence حيث يكون بعدها كلام عربي
أو في نهاية النص At the end of the sentence
أيضا ترتيب الأرقام والرموز يجب 1 أن 2 يكون 3 صحيحاً$.
ولا ننسى أيضا فواصل السطور Line breakers حيث وجودها في موضعها الصحيح مهم جدا في النصوص ثنائية الاتجاه Bidirectional
              ''',
              style: TextStyle(
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
    ));
  });

  tearDownAll(() async {
    final file = File('arabic.pdf');
    await file.writeAsBytes(await pdf.save());
  });
}
