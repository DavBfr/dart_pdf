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
import 'dart:typed_data';

import 'package:pdf/src/pdf/font/indic.dart' as indic;
import 'package:pdf/src/pdf/font/universal_shaper.dart' as shaper;
import 'package:pdf/widgets.dart';
import 'package:test/test.dart';

import 'utils.dart';

late Document pdf;
Font? malayalamFont;
TextStyle? style;

Future<Font> _loadMalayalamFont() async {
  // Try to load a local copy first
  const localPaths = [
    'NotoSansMalayalam-Regular.ttf',
    'test/NotoSansMalayalam-Regular.ttf',
  ];

  for (final path in localPaths) {
    final file = File(path);
    if (file.existsSync()) {
      final data = file.readAsBytesSync();
      return Font.ttf(data.buffer.asByteData());
    }
  }

  // Download from Google Fonts (static version)
  final data = await download(
    'https://raw.githubusercontent.com/googlefonts/noto-fonts/main/hinted/ttf/NotoSansMalayalam/NotoSansMalayalam-Regular.ttf',
    suffix: '.ttf',
  );
  if (data.length < 100) {
    throw Exception('Downloaded font file is too small (${data.length} bytes)');
  }
  return Font.ttf(data.buffer.asByteData());
}

void main() {
  setUpAll(() async {
    Document.debug = true;
    RichText.debug = true;
    pdf = Document();

    malayalamFont = await _loadMalayalamFont();
    style = TextStyle(font: malayalamFont, fontSize: 24);
  });

  group('Malayalam character processing', () {
    test('containsMalayalam detects Malayalam text', () {
      expect(shaper.containsComplexScript('മലയാളം'), isTrue);
      expect(shaper.containsComplexScript('Hello'), isFalse);
      expect(shaper.containsComplexScript('Hello മലയാളം World'), isTrue);
    });

    test('reorder preserves simple consonant', () {
      // Single consonant: ക (0x0D15)
      final result = indic.reorder([0x0D15]);
      expect(result, equals([0x0D15]));
    });

    test('reorder handles consonant + post-base matra', () {
      // കാ = ക + ാ (consonant + aa matra, post-base)
      final result = indic.reorder([0x0D15, 0x0D3E]);
      expect(result, equals([0x0D15, 0x0D3E]));
    });

    test('reorder moves pre-base matra before consonant', () {
      // കെ = ക + െ → should reorder to െ + ക
      final result = indic.reorder([0x0D15, 0x0D46]);
      expect(result, equals([0x0D46, 0x0D15]));
    });

    test('reorder decomposes two-part matra', () {
      // കൊ = ക + ൊ → should decompose to െ + ക + ാ
      final result = indic.reorder([0x0D15, 0x0D4A]);
      expect(result.length, equals(3));
      // Pre-base part (െ) should come first
      expect(result[0], equals(0x0D46));
      // Then the consonant (ക)
      expect(result[1], equals(0x0D15));
      // Then the post-base part (ാ)
      expect(result[2], equals(0x0D3E));
    });

    test('reorder preserves conjuncts', () {
      // ക + ് + ക = kka conjunct
      final result = indic.reorder([0x0D15, 0x0D4D, 0x0D15]);
      expect(result, equals([0x0D15, 0x0D4D, 0x0D15]));
    });

    test('reorder handles conjunct + pre-base matra', () {
      // ക + ് + കെ = kke → should reorder matra before cluster
      final result = indic.reorder([0x0D15, 0x0D4D, 0x0D15, 0x0D46]);
      // Expected: െ + ക + ് + ക
      expect(result[0], equals(0x0D46));
      expect(result[1], equals(0x0D15));
      expect(result[2], equals(0x0D4D));
      expect(result[3], equals(0x0D15));
    });

    test('reorder handles full word: മലയാളം', () {
      // മലയാളം = മ(0D2E) ല(0D32) യ(0D2F) ാ(0D3E) ള(0D33) 0D02(anusvara)
      // Wait, actually: മ + ല + യ + ാ + ള + ം
      final input = 'മലയാളം'.runes.toList();
      final result = indic.reorder(input);
      // All characters should still be present
      expect(result.length, equals(input.length));
    });
  });

  group('Malayalam PDF generation', () {
    test('Simple Malayalam text', () {
      pdf.addPage(
        Page(
          build: (Context context) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('മലയാളം', style: style),
              SizedBox(height: 10),
              Text('കേരളം', style: style),
              SizedBox(height: 10),
              Text('നമസ്കാരം', style: style),
            ],
          ),
        ),
      );
    });

    test('Malayalam conjuncts', () {
      pdf.addPage(
        Page(
          build: (Context context) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Conjuncts:', style: TextStyle(fontSize: 18)),
              SizedBox(height: 10),
              Text('ക്ക ങ്ക ച്ച ട്ട ത്ത പ്പ', style: style),
              SizedBox(height: 10),
              Text('ന്ന ണ്ണ മ്മ ല്ല', style: style),
              SizedBox(height: 10),
              Text('ക്ഷ ങ്ങ ഞ്ഞ ണ്ട', style: style),
            ],
          ),
        ),
      );
    });

    test('Malayalam vowel signs', () {
      pdf.addPage(
        Page(
          build: (Context context) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Vowel signs:', style: TextStyle(fontSize: 18)),
              SizedBox(height: 10),
              // Post-base: കാ കി കീ കു കൂ
              Text('കാ കി കീ കു കൂ', style: style),
              SizedBox(height: 10),
              // Pre-base: കെ കേ കൈ
              Text('കെ കേ കൈ', style: style),
              SizedBox(height: 10),
              // Two-part: കൊ കോ കൌ
              Text('കൊ കോ കൌ', style: style),
            ],
          ),
        ),
      );
    });

    test('Mixed Malayalam and English', () {
      pdf.addPage(
        Page(
          build: (Context context) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Kerala (കേരളം) is a state in India.',
                style: style,
              ),
              SizedBox(height: 10),
              Text(
                'Malayalam (മലയാളം) is the official language.',
                style: style,
              ),
            ],
          ),
        ),
      );
    });

    test('Malayalam paragraph', () {
      pdf.addPage(
        Page(
          build: (Context context) => RichText(
            text: TextSpan(
              text: 'മലയാളം\n',
              style: TextStyle(font: malayalamFont, fontSize: 28),
              children: [
                TextSpan(
                  text:
                      'മലയാളം ഒരു ദ്രാവിഡ ഭാഷയാണ്. '
                      'ഇന്ത്യയിലെ കേരള സംസ്ഥാനത്തിലും '
                      'ലക്ഷദ്വീപിലും പോണ്ടിച്ചേരിയിലെ '
                      'മാഹിയിലും സംസാരിക്കുന്നു.',
                  style: TextStyle(
                    font: malayalamFont,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  });

  tearDownAll(() async {
    final file = File('malayalam.pdf');
    await file.writeAsBytes(await pdf.save());
  });
}
