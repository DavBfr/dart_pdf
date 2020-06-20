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
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart';
import 'package:test/test.dart';

class ArabicText {
  ArabicText(this.original, this._reshaped);

  final String original;
  final String _reshaped;

  String get reshaped => _reshaped.split('').reversed.join('');
  String get originalRev => original.split('').reversed.join('');
}

Document pdf;
Font arabicFont;
TextStyle style;

void main() {
  setUpAll(() {
    Document.debug = false;
    RichText.debug = true;
    pdf = Document();

    final Uint8List fontData = File('assets/arial.ttf').readAsBytesSync();
    arabicFont = Font.ttf(fontData.buffer.asByteData());
    style = TextStyle(font: arabicFont, fontSize: 30);
  });

  test('Arabic Diacritics', () {
    final ArabicText a = ArabicText('السلام', 'ﺍﻟﺴﻼﻡ');
    final ArabicText b = ArabicText('السَلَاْمٌ', 'ﺍﻟﺴﻼﻡ');

    expect(
      PdfArabic.convert(a.original).codeUnits,
      equals(a.reshaped.codeUnits),
    );
    expect(
      PdfArabic.convert(b.original).codeUnits,
      equals(b.reshaped.codeUnits),
    );
  });

  test('Arabic Default Reshaping', () {
    final List<ArabicText> cases = <ArabicText>[
      ArabicText('السَلَاْمٌ عَلَيْكُمْ', 'ﺍﻟﺴﻼﻡ ﻋﻠﻴﻜﻢ'),
      ArabicText(
          'اللغة العربية هي أكثر اللغات', 'ﺍﻟﻠﻐﺔ ﺍﻟﻌﺮﺑﻴﺔ ﻫﻲ ﺃﻛﺜﺮ ﺍﻟﻠﻐﺎﺕ'),
      ArabicText('تحدثاً ونطقاً ضمن مجموعة', 'ﺗﺤﺪﺛﺎ ﻭﻧﻄﻘﺎ ﺿﻤﻦ ﻣﺠﻤﻮﻋﺔ'),
      ArabicText('اللغات السامية', 'ﺍﻟﻠﻐﺎﺕ ﺍﻟﺴﺎﻣﻴﺔ'),
      ArabicText('العربية لغة رسمية في', 'ﺍﻟﻌﺮﺑﻴﺔ ﻟﻐﺔ ﺭﺳﻤﻴﺔ ﻓﻲ'),
      ArabicText('كل دول الوطن العربي', 'ﻛﻞ ﺩﻭﻝ ﺍﻟﻮﻃﻦ ﺍﻟﻌﺮﺑﻲ'),
      ArabicText('إضافة إلى كونها لغة', 'ﺇﺿﺎﻓﺔ ﺇﻟﻰ ﻛﻮﻧﻬﺎ ﻟﻐﺔ'),
      ArabicText('رسمية في تشاد وإريتريا', 'ﺭﺳﻤﻴﺔ ﻓﻲ ﺗﺸﺎﺩ ﻭﺇﺭﻳﺘﺮﻳﺎ'),
      ArabicText('وإسرائيل. وهي إحدى اللغات', 'ﻭﺇﺳﺮﺍﺋﻴﻞ. ﻭﻫﻲ ﺇﺣﺪﻯ ﺍﻟﻠﻐﺎﺕ'),
      ArabicText('الرسمية الست في منظمة', 'ﺍﻟﺮﺳﻤﻴﺔ ﺍﻟﺴﺖ ﻓﻲ ﻣﻨﻈﻤﺔ'),
      ArabicText('الأمم المتحدة، ويُحتفل', 'ﺍﻷﻣﻢ ،ﺍﻟﻤﺘﺤﺪﺓ ﻭﻳﺤﺘﻔﻞ'),
      ArabicText('باليوم العالمي للغة العربية', 'ﺑﺎﻟﻴﻮﻡ ﺍﻟﻌﺎﻟﻤﻲ ﻟﻠﻐﺔ ﺍﻟﻌﺮﺑﻴﺔ'),
      ArabicText('في 18 ديسمبر كذكرى اعتماد', 'ﻓﻲ 81 ﺩﻳﺴﻤﺒﺮ ﻛﺬﻛﺮﻯ ﺍﻋﺘﻤﺎﺩ'),
      ArabicText('العربية بين لغات العمل في', 'ﺍﻟﻌﺮﺑﻴﺔ ﺑﻴﻦ ﻟﻐﺎﺕ ﺍﻟﻌﻤﻞ ﻓﻲ'),
      ArabicText('الأمم المتحدة.', 'ﺍﻷﻣﻢ ﺍﻟﻤﺘﺤﺪﺓ.'),
    ];

    pdf.addPage(
      MultiPage(
        build: (Context context) => <Widget>[
          for (ArabicText item in cases)
            Padding(
              padding: const EdgeInsets.only(bottom: 15),
              child: Text(
                item.original + '\n',
                textDirection: TextDirection.rtl,
                style: style,
              ),
            ),
        ],
      ),
    );

    for (ArabicText item in cases) {
      try {
        expect(
          PdfArabic.convert(item.original, diacritic: true)
              .split(' ')
              .reversed
              .join(' ')
              .codeUnits,
          equals(item.originalRev.codeUnits),
        );
      } catch (e) {
        print(item.original);
        print(e);
      }
    }
  });

  test('Text Widgets Arabic', () {
    final Uint8List fontData = File('assets/arial.ttf').readAsBytesSync();
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
    final File file = File('arabic.pdf');
    file.writeAsBytesSync(pdf.save());
  });
}
