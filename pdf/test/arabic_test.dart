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
import 'package:pdf/src/pdf/font/bidi_utils.dart' as bidi;
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
    Document.debug = false;
    RichText.debug = true;
    pdf = Document();

    arabicFont = loadFont('test/fonts/hacen-tunisia.ttf');
    // arabicFont = loadFont('test/fonts/arial.ttf');
    style = TextStyle(font: arabicFont, fontSize: 30);
  });

  test('Arabic Diacritics', () {
    final a = ArabicText('السلام', <int>[65249, 65276, 65204, 65247, 65165]);
    final b = ArabicText('السَلَاْمٌ', <int>[1612, 65249, 1618, 1614, 65276, 1614, 65204, 65247, 65165]);

    expect(
      bidi.logicalToVisual(a.original).codeUnits,
      equals(a.reshaped),
    );
    expect(
      bidi.logicalToVisual(b.original).codeUnits,
      equals(b.reshaped),
    );
  });

  test('Arabic Default Reshaping', () {
    final cases = <ArabicText>[
      ArabicText('الـــسَلاْمُ عَلَيْكُمْ', <int>[
        1615,
        65249,
        1618,
        65276,
        1614,
        65204,
        1600,
        1600,
        1600,
        65247,
        65165,
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
        65165,
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
        65165,
        32,
        65266,
        65259,
        32,
        1615,
        65198,
        65180,
        65243,
        65155,
        32,
        1616,
        65173,
        65166,
        65232,
        65248,
        65247,
        65165
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
        65261,
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
        65173,
        65166,
        65232,
        65248,
        65247,
        65165,
        32,
        65172,
        65268,
        65251,
        65166,
        65204,
        65247,
        65165,
      ]),
      ArabicText('العربية لغةٌ رسميةٌ في', <int>[
        65172,
        65268,
        65169,
        65198,
        65228,
        65247,
        65165,
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
        65197,
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
        65245,
        65261,
        65193,
        32,
        1616,
        65254,
        65219,
        65262,
        65247,
        65165,
        32,
        64610,
        65266,
        65169,
        65198,
        65228,
        65247,
        65165
      ]),
      ArabicText('إضافة إلىّٰ كونها لغة؟', <int>[
        65172,
        65235,
        65166,
        65215,
        65159,
        32,
        64611,
        65264,
        65247,
        65159,
        32,
        65166,
        65260,
        65255,
        65262,
        65243,
        32,
        1567,
        65172,
        65232,
        65247,
      ]),
      ArabicText('رسمية في تشاد وإريتريا', <int>[
        65172,
        65268,
        65252,
        65203,
        65197,
        32,
        65266,
        65235,
        32,
        65193,
        65166,
        65208,
        65175,
        32,
        65166,
        65267,
        65198,
        65176,
        65267,
        65197,
        65159,
        65261
      ]),
      ArabicText('وإسرائيل. وهي إحدى اللغات', <int>[
        46,
        65246,
        65268,
        65163,
        65165,
        65198,
        65203,
        65159,
        65261,
        32,
        65266,
        65259,
        65261,
        32,
        65263,
        65194,
        65187,
        65159,
        32,
        65173,
        65166,
        65232,
        65248,
        65247,
        65165
      ]),
      ArabicText('الرسمية الست في منظمة', <int>[
        65172,
        65268,
        65252,
        65203,
        65198,
        65247,
        65165,
        32,
        65174,
        65204,
        65247,
        65165,
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
        65165,
        32,
        1548,
        65171,
        65194,
        65188,
        65176,
        65252,
        65247,
        65165,
        32,
        65246,
        65236,
        65176,
        65188,
        1615,
        65267,
        65261
      ]),
      ArabicText('باليوم العالمي للغة العربية', <int>[
        65249,
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
        65165,
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
        65165
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
        65193,
        32,
        65263,
        65198,
        65243,
        65196,
        65243,
        32,
        65193,
        65166,
        65252,
        65176,
        65227,
        65165
      ]),
      ArabicText('العربية بين لغات العمل في', <int>[
        65172,
        65268,
        65169,
        65198,
        65228,
        65247,
        65165,
        32,
        65254,
        65268,
        65169,
        32,
        65173,
        65166,
        65232,
        65247,
        32,
        65246,
        65252,
        65228,
        65247,
        65165,
        32,
        65266,
        65235
      ]),
      ArabicText('الأمم المتحدة.', <int>[
        65250,
        65251,
        65271,
        65165,
        32,
        46,
        65171,
        65194,
        65188,
        65176,
        65252,
        65247,
        65165,
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
        bidi.logicalToVisual(item.original).codeUnits,
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
                  'القهوة مشروب يعد من بذور الب المحمصة، وينمو في أكثر من 70 بلداً. خصوصاً في المناطق الاستوائية في أمريكا الشمالية والجنوبية وجنوب شرق آسيا وشبه القارة الهندية وأفريقيا. ويقال أن البن الأخضر هو ثاني أكثر السلع تداولاً في العالم بعد النفط الخام.',
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
                  'القهوة مشروب يعد من بذور الب المحمصة، وينمو في أكثر من 70 بلداً. خصوصاً في المناطق الاستوائية في أمريكا الشمالية والجنوبية وجنوب شرق آسيا وشبه القارة الهندية وأفريقيا. ويقال أن البن الأخضر هو ثاني أكثر السلع تداولاً في العالم بعد النفط الخام.',
              style: TextStyle(
                fontSize: 20,
              ),
            ),
          ],
        ),
      ),
    ));
  });

  test('Text Widgets, Arabic Text with Tashkeel', () {
    pdf.addPage(Page(
      textDirection: TextDirection.rtl,
      build: (Context context) => RichText(
        text: TextSpan(
          text: 'الفَرَاشَةُ\n',
          style: TextStyle(
            font: arabicFont,
            fontSize: 30,
          ),
          children: const <TextSpan>[
            if (true)
              TextSpan(
                text:
                    'فَرَاشَةٌ مُلَوَّنَةٌ تَطِيْرُ في البُسْتَانِ، حُلْوَةٌ مُهَنْدَمَةٌ تُدْهِشُ الإِنْسَانَ، أَهْدَافُهَا مُحَدَّدَةٌ، حَرَكَاتُها مُرَتَّبَةٌ، تَحُوْمُ بِانْتِظَامٍ،'
                    ' تَحُطُّ فِي نُعُومَةٍ تَنْشُرُ السَّلاَمَ. فَرَاشَةٌ مُلَوَّنَةٌ تَطِيرُ بِلا اُنْقِطَاعٍ، بِالنَّهارِ المُشْرِقِ تَمْلَأُ البِقَاعَ، تُحِبُّ الوَرْدَ '
                    'المَزْرُوعَ، تَلْثُمُهُ فِي وَقْتِ الجُوعِ، تَمْتَصُّ رَحِيْقَ الأَزْهَارِ، تُحْيي جَنْيَ الأَشْجَارِ، مِنْ وَرْدَةٍ لِوَرْدَةٍ، تَطِيْرُ بِانْتِظَامٍ.',
                style: TextStyle(
                  fontSize: 18,
                ),
              ),
          ],
        ),
      ),
    ));
  });

  test('Text Widgets, Mixed Arabic and Latin words should be rendered in order', () {
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
            if (true)
              TextSpan(
                text: r'''
الكلمات اللاتينية المضافة إلى نص عربي يجب أن توضع في الترتيب الصحيح Right Order مهما كان موضعها في النص.
 في منتصفها In the middle of the sentence حيث يكون بعدها كلام عربي
أو في نهاية النص At the end of the sentence
أيضا ترتيب الأرقام والرموز يجب  1 أن 2 يكون 3 صحيحاً$.
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

  test('Text Widgets Arabic with weak/natural Chars', () {
    pdf.addPage(Page(
      build: (Context context) => SizedBox.expand(
          child: RichText(
        textDirection: TextDirection.rtl,
        text: TextSpan(
          style: TextStyle(
            font: arabicFont,
            fontSize: 18,
          ),
          children: const <TextSpan>[
            TextSpan(
              text: '''
اضف العدد (5) إلى العدد (40)
ثم اطرح منه العدد (10)
الناتج = 35
جملة (if) الشرطية:
كلمة عربية (بين قوسين)
حاصل العملية  (5 * 2) + (2 - 4) يساوي 12
العدد 9 > 5 والعدد 9 < 10
                    ''',
            ),
          ],
        ),
      )),
    ));
  });

  tearDownAll(() async {
    final file = File('arabic.pdf');
    await file.writeAsBytes(await pdf.save());
  });
}
