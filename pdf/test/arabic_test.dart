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
}

Document pdf;
Font hacen;
TextStyle style;
TextStyle red;

void main() {
  setUpAll(() {
    Document.debug = false;
    RichText.debug = true;
    pdf = Document();

    final Uint8List fontData = File('hacen-tunisia.ttf').readAsBytesSync();
    hacen = Font.ttf(fontData.buffer.asByteData());
    style = TextStyle(font: hacen, fontSize: 30);
    red = style.copyWith(color: PdfColors.red);
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
      ArabicText('السلام عليكم', 'ﺍﻟﺴﻼﻡ ﻋﻠﻴﻜﻢ'),
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
              child: Stack(
                children: <Widget>[
                  Align(
                    alignment: Alignment.topRight,
                    child: Text(item.reshaped, style: red),
                  ),
                  Align(
                    alignment: Alignment.topRight,
                    child: Text(PdfArabic.convert(item.original), style: style),
                  ),
                ],
              ),
            ),
        ],
      ),
    );

    for (ArabicText item in cases) {
      expect(
        PdfArabic.convert(item.original).codeUnits,
        equals(item.reshaped.codeUnits),
      );
    }
  });

  tearDownAll(() {
    final File file = File('arabic.pdf');
    file.writeAsBytesSync(pdf.save());
  });
}
