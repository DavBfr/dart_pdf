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

import 'package:pdf/pdf.dart';
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
    Document.debug = true;
    RichText.debug = true;
    pdf = Document();

    arabicFont = loadFont('hacen-tunisia.ttf');
    style = TextStyle(font: arabicFont, fontSize: 30);
  });

  group('shaping and reordering are separate steps', () {
    test('shapeLogical shapes without moving anything', () {
      // The same glyphs logicalToVisual produces, in the order they were
      // written. Line breaking, metrics and hyphenation all need logical order;
      // rule L2 belongs to a finished line.
      expect(
        bidi.shapeLogical('محمد').codeUnits,
        bidi.logicalToVisual('محمد').codeUnits.reversed,
      );
      expect(bidi.shapeLogical('السلام').codeUnits, <int>[
        0xFE8D,
        0xFEDF,
        0xFEB4,
        0xFEFC,
        0xFEE1,
      ]);

      // Not one character moves in text that has no strong RTL run, where
      // logicalToVisual reverses the word order outright.
      expect(bidi.shapeLogical('Hello world foo'), 'Hello world foo');
      expect(bidi.logicalToVisual('Hello world foo'), 'foo world Hello');

      // An embedded Latin run keeps its place.
      expect(
        bidi.shapeLogical('إلى the historical'),
        endsWith(' the historical'),
      );
    });

    test('reorderLine applies L2 against the paragraph, not the line', () {
      List<String> visual(List<String> runs, {required bool rtl}) =>
          bidi.reorderLine(runs, rtl: rtl).map((int i) => runs[i]).toList();

      // A Latin run inside an RTL line reads left to right, and the line as a
      // whole reads right to left.
      expect(visual(<String>['إلى', 'the', 'historical'], rtl: true), <String>[
        'the',
        'historical',
        'إلى',
      ]);

      // An all-Latin line is still part of its RTL paragraph: it keeps reading
      // order, and the alignment puts it on the right.
      expect(visual(<String>['old', 'town'], rtl: true), <String>[
        'old',
        'town',
      ]);

      // Pure RTL is a straight reversal.
      expect(visual(<String>['مرحبا', 'بالعالم'], rtl: true), <String>[
        'بالعالم',
        'مرحبا',
      ]);

      // The base direction decides, which is why it has to be the paragraph's.
      expect(visual(<String>['Total:', 'مرحبا', 'today'], rtl: false), <String>[
        'Total:',
        'مرحبا',
        'today',
      ]);
      expect(visual(<String>['Total:', 'مرحبا', 'today'], rtl: true), <String>[
        'today',
        'مرحبا',
        'Total:',
      ]);

      // A number reads left to right wherever it sits.
      expect(visual(<String>['مرحبا', '35', 'أهلا'], rtl: true), <String>[
        'أهلا',
        '35',
        'مرحبا',
      ]);

      expect(bidi.reorderLine(<String>['one'], rtl: true), <int>[0]);
      expect(bidi.reorderLine(<String>[], rtl: true), isEmpty);
    });

    test('isRtlText finds strong right-to-left characters only', () {
      expect(bidi.isRtlText('مرحبا'), isTrue);
      expect(bidi.isRtlText('\uFE8E'), isTrue, reason: 'a presentation form');
      expect(bidi.isRtlText('\u05D0'), isTrue, reason: 'Hebrew');
      expect(bidi.isRtlText('abc'), isFalse);
      expect(bidi.isRtlText('35'), isFalse);
      expect(bidi.isRtlText('(5) = 10'), isFalse);
      expect(
        bidi.isRtlText('\u0660\u0661'),
        isFalse,
        reason: 'Arabic-Indic digits are numbers, not strong RTL',
      );
      expect(bidi.isRtlText(''), isFalse);
    });

    test('hasBidi skips text the algorithm has nothing to do with', () {
      expect(bidi.hasBidi('Hello world'), isFalse);
      expect(bidi.hasBidi('35 + 7 = 42'), isFalse);
      expect(bidi.hasBidi('caf\u00E9 na\u00EFve'), isFalse);
      expect(bidi.hasBidi(''), isFalse);

      expect(bidi.hasBidi('Total: مرحبا'), isTrue);
      expect(bidi.hasBidi('\u05D0'), isTrue, reason: 'Hebrew');
      expect(bidi.hasBidi('\u200F10'), isTrue, reason: 'an explicit RLM');
      expect(bidi.hasBidi('\u200E10'), isTrue, reason: 'an explicit LRM');
      expect(bidi.hasBidi('a\u202Bb'), isTrue, reason: 'an embedding');
      expect(bidi.hasBidi('a\u2067b'), isTrue, reason: 'an isolate');
    });

    test('shapeLogical never throws', () {
      // The same package:bidi normalizer bug B-024 guards logicalToVisual
      // against. Here the text comes back as it went in, so its runs can still
      // be placed and mirrored, only unjoined.
      for (var carrier = 0x0622; carrier <= 0x0626; carrier++) {
        for (final haraka in <int>[0x064C, 0x064E, 0x0650, 0x0670]) {
          final text = String.fromCharCodes(<int>[carrier, haraka]);
          expect(() => bidi.shapeLogical(text), returnsNormally);
          expect(bidi.shapeLogical(text), text);
        }
      }
    });

    test('reversed walks whole code points', () {
      expect(bidi.reversed('abc'), 'cba');
      expect(bidi.reversed('a\u{1F600}b'), 'b\u{1F600}a');
    });
  });

  test('logicalToVisual never throws', () {
    // package:bidi's normalizer indexes its length table out of step with the
    // decomposition of the hamza carriers, so 40 of these 45 pairs threw
    // 'RangeError (length): Not in inclusive range 0..1: 2' out of save(), with
    // no runtime way to turn the call off.
    var shaped = 0;

    for (var carrier = 0x0622; carrier <= 0x0626; carrier++) {
      for (final haraka in <int>[
        0x064B,
        0x064C,
        0x064D,
        0x064E,
        0x064F,
        0x0650,
        0x0651,
        0x0652,
        0x0670,
      ]) {
        final text = String.fromCharCodes(<int>[carrier, haraka]);
        final label =
            'U+${carrier.toRadixString(16)} + U+${haraka.toRadixString(16)}';

        late String visual;
        expect(
          () => visual = bidi.logicalToVisual(text),
          returnsNormally,
          reason: label,
        );
        expect(visual, isNotEmpty, reason: label);
        if (visual != text) {
          shaped++;
        }
      }
    }

    expect(shaped, 45, reason: 'every pair comes back shaped, not raw');
  });

  test('a paragraph of the failing pairs still saves', () async {
    final document = Document();
    document.addPage(
      Page(
        textDirection: TextDirection.rtl,
        pageFormat: const PdfPageFormat(200, 100),
        build: (Context context) => Text('\u0623\u064Fغلق في', style: style),
      ),
    );

    expect(await document.save(), isNotEmpty);
  });

  test('where package:bidi succeeds the output is unchanged', () {
    expect(bidi.logicalToVisual('محمد').codeUnits, <int>[
      0xFEAA,
      0xFEE4,
      0xFEA4,
      0xFEE3,
    ]);
    expect(bidi.logicalToVisual('السلام').codeUnits, <int>[
      0xFEE1,
      0xFEFC,
      0xFEB4,
      0xFEDF,
      0xFE8D,
    ]);
  });

  test('Arabic Diacritics', () {
    final a = ArabicText('السلام', <int>[65249, 65276, 65204, 65247, 65165]);
    final b = ArabicText('السَلَاْمٌ', <int>[
      1612,
      65249,
      1618,
      1614,
      65276,
      1614,
      65204,
      65247,
      65165,
    ]);

    expect(bidi.logicalToVisual(a.original).codeUnits, equals(a.reshaped));
    expect(bidi.logicalToVisual(b.original).codeUnits, equals(b.reshaped));
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
        65227,
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
        65165,
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
        65251,
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
        65235,
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
        65165,
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
        65261,
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
        65165,
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
        65251,
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
        65261,
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
        65165,
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
        65165,
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
        65235,
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
    pdf.addPage(
      Page(
        build: (Context context) => RichText(
          textDirection: TextDirection.rtl,
          text: TextSpan(
            text: 'قهوة\n',
            style: TextStyle(font: arabicFont, fontSize: 30),
            children: const <TextSpan>[
              TextSpan(
                text:
                    'القهوة مشروب يعد من بذور الب المحمصة، وينمو في أكثر من 70 بلداً. خصوصاً في المناطق الاستوائية في أمريكا الشمالية والجنوبية وجنوب شرق آسيا وشبه القارة الهندية وأفريقيا. ويقال أن البن الأخضر هو ثاني أكثر السلع تداولاً في العالم بعد النفط الخام.',
                style: TextStyle(fontSize: 20),
              ),
            ],
          ),
        ),
      ),
    );
  });

  test('Text Widgets Arabic with TextAlign.justify', () {
    pdf.addPage(
      Page(
        build: (Context context) => RichText(
          textDirection: TextDirection.rtl,
          textAlign: TextAlign.justify,
          text: TextSpan(
            text: 'قهوة\n',
            style: TextStyle(font: arabicFont, fontSize: 30),
            children: const <TextSpan>[
              TextSpan(
                text:
                    'القهوة مشروب يعد من بذور الب المحمصة، وينمو في أكثر من 70 بلداً. خصوصاً في المناطق الاستوائية في أمريكا الشمالية والجنوبية وجنوب شرق آسيا وشبه القارة الهندية وأفريقيا. ويقال أن البن الأخضر هو ثاني أكثر السلع تداولاً في العالم بعد النفط الخام.',
                style: TextStyle(fontSize: 20),
              ),
            ],
          ),
        ),
      ),
    );
  });

  test('Text Widgets, Arabic Text with Tashkeel', () {
    pdf.addPage(
      Page(
        textDirection: TextDirection.rtl,
        build: (Context context) => RichText(
          text: TextSpan(
            text: 'الفَرَاشَةُ\n',
            style: TextStyle(font: arabicFont, fontSize: 30),
            children: const <TextSpan>[
              if (true)
                TextSpan(
                  text:
                      'فَرَاشَةٌ مُلَوَّنَةٌ تَطِيْرُ في البُسْتَانِ، حُلْوَةٌ مُهَنْدَمَةٌ تُدْهِشُ الإِنْسَانَ، أَهْدَافُهَا مُحَدَّدَةٌ، حَرَكَاتُها مُرَتَّبَةٌ، تَحُوْمُ بِانْتِظَامٍ،'
                      ' تَحُطُّ فِي نُعُومَةٍ تَنْشُرُ السَّلاَمَ. فَرَاشَةٌ مُلَوَّنَةٌ تَطِيرُ بِلا اُنْقِطَاعٍ، بِالنَّهارِ المُشْرِقِ تَمْلَأُ البِقَاعَ، تُحِبُّ الوَرْدَ '
                      'المَزْرُوعَ، تَلْثُمُهُ فِي وَقْتِ الجُوعِ، تَمْتَصُّ رَحِيْقَ الأَزْهَارِ، تُحْيي جَنْيَ الأَشْجَارِ، مِنْ وَرْدَةٍ لِوَرْدَةٍ، تَطِيْرُ بِانْتِظَامٍ.',
                  style: TextStyle(fontSize: 18),
                ),
            ],
          ),
        ),
      ),
    );
  });

  test(
    'Text Widgets, Mixed Arabic and Latin words should be rendered in order',
    () {
      pdf.addPage(
        Page(
          textDirection: TextDirection.rtl,
          build: (Context context) => RichText(
            text: TextSpan(
              text: 'النصوص ثنائية الإتجاه Bidirectional Text\n',
              style: TextStyle(font: arabicFont, fontSize: 30),
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
                    style: TextStyle(fontSize: 18),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );

  test('Text Widgets Arabic with weak/natural Chars', () {
    pdf.addPage(
      Page(
        build: (Context context) => SizedBox.expand(
          child: RichText(
            textDirection: TextDirection.rtl,
            text: TextSpan(
              style: TextStyle(font: arabicFont, fontSize: 18),
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
          ),
        ),
      ),
    );
  });

  tearDownAll(() async {
    final file = File('arabic.pdf');
    await file.writeAsBytes(await pdf.save());
  });
}
