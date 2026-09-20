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

/// Download a Noto Sans font for the given script
Future<Font> _downloadFont(String fontName) async {
  // Try local first
  final localPaths = [
    '$fontName.ttf',
    'test/$fontName.ttf',
  ];

  for (final path in localPaths) {
    final file = File(path);
    if (file.existsSync()) {
      final data = file.readAsBytesSync();
      return Font.ttf(data.buffer.asByteData());
    }
  }

  // Download from Google Fonts (static version)
  final url =
      'https://raw.githubusercontent.com/googlefonts/noto-fonts/main/hinted/ttf/$fontName/$fontName-Regular.ttf';
  final data = await download(url, suffix: '.ttf');
  if (data.length < 100) {
    throw Exception('Downloaded $fontName is too small (${data.length} bytes)');
  }
  return Font.ttf(data.buffer.asByteData());
}

void main() {
  setUpAll(() {
    Document.debug = true;
    RichText.debug = true;
    pdf = Document();
  });

  // ─── Script Detection Tests ───────────────────────────────────────

  group('Script detection', () {
    test('detects Devanagari', () {
      expect(indic.detectScript(0x0915)?.name, equals('Devanagari'));
      expect(shaper.containsComplexScript('नमस्ते'), isTrue);
    });

    test('detects Bengali', () {
      expect(indic.detectScript(0x0995)?.name, equals('Bengali'));
      expect(shaper.containsComplexScript('বাংলা'), isTrue);
    });

    test('detects Tamil', () {
      expect(indic.detectScript(0x0B95)?.name, equals('Tamil'));
      expect(shaper.containsComplexScript('தமிழ்'), isTrue);
    });

    test('detects Telugu', () {
      expect(indic.detectScript(0x0C15)?.name, equals('Telugu'));
      expect(shaper.containsComplexScript('తెలుగు'), isTrue);
    });

    test('detects Kannada', () {
      expect(indic.detectScript(0x0C95)?.name, equals('Kannada'));
      expect(shaper.containsComplexScript('ಕನ್ನಡ'), isTrue);
    });

    test('detects Malayalam', () {
      expect(indic.detectScript(0x0D15)?.name, equals('Malayalam'));
      expect(shaper.containsComplexScript('മലയാളം'), isTrue);
    });

    test('detects Gujarati', () {
      expect(indic.detectScript(0x0A95)?.name, equals('Gujarati'));
      expect(shaper.containsComplexScript('ગુજરાતી'), isTrue);
    });

    test('detects Gurmukhi', () {
      expect(indic.detectScript(0x0A15)?.name, equals('Gurmukhi'));
      expect(shaper.containsComplexScript('ਪੰਜਾਬੀ'), isTrue);
    });

    test('detects Oriya', () {
      expect(indic.detectScript(0x0B15)?.name, equals('Oriya'));
      expect(shaper.containsComplexScript('ଓଡ଼ିଆ'), isTrue);
    });

    test('does not detect Latin', () {
      expect(shaper.containsComplexScript('Hello World'), isFalse);
    });

    test('detects mixed text', () {
      expect(
        shaper.containsComplexScript('Hello नमस्ते World'),
        isTrue,
      );
    });

    test('detects Thai', () {
      expect(shaper.containsComplexScript('สวัสดี'), isTrue);
    });

    test('detects Khmer', () {
      expect(shaper.containsComplexScript('សួស្តី'), isTrue);
    });
  });

  // ─── Character Reordering Tests ───────────────────────────────────

  group('Indic character reordering', () {
    test('Malayalam pre-base matra reordering', () {
      // കെ = ക(0D15) + െ(0D46) → should reorder to െ + ക
      final result = indic.reorder([0x0D15, 0x0D46]);
      expect(result, equals([0x0D46, 0x0D15]));
    });

    test('Malayalam two-part matra decomposition', () {
      // കൊ = ക(0D15) + ൊ(0D4A) → െ + ക + ാ
      final result = indic.reorder([0x0D15, 0x0D4A]);
      expect(result.length, equals(3));
      expect(result[0], equals(0x0D46)); // െ
      expect(result[1], equals(0x0D15)); // ക
      expect(result[2], equals(0x0D3E)); // ാ
    });

    test('Devanagari pre-base matra reordering', () {
      // कि = क(0915) + ि(093F) → should reorder to ि + क
      final result = indic.reorder([0x0915, 0x093F]);
      expect(result, equals([0x093F, 0x0915]));
    });

    test('Bengali pre-base matra reordering', () {
      // কি = ক(0995) + ি(09BF) → should reorder to ি + ক
      final result = indic.reorder([0x0995, 0x09BF]);
      expect(result, equals([0x09BF, 0x0995]));
    });

    test('Tamil pre-base matra reordering', () {
      // கெ = க(0B95) + ெ(0BC6) → should reorder to ெ + க
      final result = indic.reorder([0x0B95, 0x0BC6]);
      expect(result, equals([0x0BC6, 0x0B95]));
    });

    test('Tamil two-part matra decomposition', () {
      // கொ = க(0B95) + ொ(0BCA) → ெ(0BC6) + க + ா(0BBE)
      final result = indic.reorder([0x0B95, 0x0BCA]);
      expect(result.length, equals(3));
      expect(result[0], equals(0x0BC6)); // ெ
      expect(result[1], equals(0x0B95)); // க
      expect(result[2], equals(0x0BBE)); // ா
    });

    test('Conjuncts preserved across scripts', () {
      // Malayalam: ക + ് + ക
      final ml = indic.reorder([0x0D15, 0x0D4D, 0x0D15]);
      expect(ml, equals([0x0D15, 0x0D4D, 0x0D15]));

      // Devanagari: क + ् + क
      final hi = indic.reorder([0x0915, 0x094D, 0x0915]);
      expect(hi, equals([0x0915, 0x094D, 0x0915]));

      // Tamil: க + ் + க
      final ta = indic.reorder([0x0B95, 0x0BCD, 0x0B95]);
      expect(ta, equals([0x0B95, 0x0BCD, 0x0B95]));
    });
  });

  // ─── PDF Generation Tests (per script) ─────────────────────────────

  group('Malayalam PDF', () {
    late Font font;

    setUpAll(() async {
      font = await _downloadFont('NotoSansMalayalam');
    });

    test('renders Malayalam text', () {
      final style = TextStyle(font: font, fontSize: 20);
      pdf.addPage(Page(
        build: (ctx) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Malayalam (മലയാളം)', style: style),
            SizedBox(height: 8),
            Text('മലയാളം ഒരു ദ്രാവിഡ ഭാഷയാണ്', style: style),
            SizedBox(height: 8),
            Text('Conjuncts: ക്ക ന്ന ട്ട ത്ത പ്പ ക്ഷ', style: style),
            SizedBox(height: 8),
            Text('Vowel signs: കെ കേ കൈ കൊ കോ കൌ', style: style),
          ],
        ),
      ));
    });
  });

  group('Devanagari PDF', () {
    late Font font;

    setUpAll(() async {
      font = await _downloadFont('NotoSansDevanagari');
    });

    test('renders Devanagari text', () {
      final style = TextStyle(font: font, fontSize: 20);
      pdf.addPage(Page(
        build: (ctx) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Devanagari (देवनागरी)', style: style),
            SizedBox(height: 8),
            Text('नमस्ते! हिन्दी भारत की राजभाषा है।', style: style),
            SizedBox(height: 8),
            Text('Conjuncts: क्ष त्र ज्ञ श्र', style: style),
          ],
        ),
      ));
    });
  });

  group('Bengali PDF', () {
    late Font font;

    setUpAll(() async {
      font = await _downloadFont('NotoSansBengali');
    });

    test('renders Bengali text', () {
      final style = TextStyle(font: font, fontSize: 20);
      pdf.addPage(Page(
        build: (ctx) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bengali (বাংলা)', style: style),
            SizedBox(height: 8),
            Text('নমস্কার! বাংলা একটি ভাষা।', style: style),
            SizedBox(height: 8),
            Text('Conjuncts: ক্ষ ত্র জ্ঞ শ্র', style: style),
          ],
        ),
      ));
    });
  });

  group('Tamil PDF', () {
    late Font font;

    setUpAll(() async {
      font = await _downloadFont('NotoSansTamil');
    });

    test('renders Tamil text', () {
      final style = TextStyle(font: font, fontSize: 20);
      pdf.addPage(Page(
        build: (ctx) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tamil (தமிழ்)', style: style),
            SizedBox(height: 8),
            Text('வணக்கம்! தமிழ் ஒரு மொழி.', style: style),
            SizedBox(height: 8),
            Text('Vowel signs: கா கி கீ கு கூ கெ கே கை கொ கோ', style: style),
          ],
        ),
      ));
    });
  });

  group('Telugu PDF', () {
    late Font font;

    setUpAll(() async {
      font = await _downloadFont('NotoSansTelugu');
    });

    test('renders Telugu text', () {
      final style = TextStyle(font: font, fontSize: 20);
      pdf.addPage(Page(
        build: (ctx) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Telugu (తెలుగు)', style: style),
            SizedBox(height: 8),
            Text('నమస్కారం! తెలుగు ఒక భాష.', style: style),
          ],
        ),
      ));
    });
  });

  group('Kannada PDF', () {
    late Font font;

    setUpAll(() async {
      font = await _downloadFont('NotoSansKannada');
    });

    test('renders Kannada text', () {
      final style = TextStyle(font: font, fontSize: 20);
      pdf.addPage(Page(
        build: (ctx) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Kannada (ಕನ್ನಡ)', style: style),
            SizedBox(height: 8),
            Text('ನಮಸ್ಕಾರ! ಕನ್ನಡ ಒಂದು ಭಾಷೆ.', style: style),
          ],
        ),
      ));
    });
  });

  group('Gujarati PDF', () {
    late Font font;

    setUpAll(() async {
      font = await _downloadFont('NotoSansGujarati');
    });

    test('renders Gujarati text', () {
      final style = TextStyle(font: font, fontSize: 20);
      pdf.addPage(Page(
        build: (ctx) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Gujarati (ગુજરાતી)', style: style),
            SizedBox(height: 8),
            Text('નમસ્તે! ગુજરાતી એક ભાષા છે.', style: style),
          ],
        ),
      ));
    });
  });

  group('Gurmukhi PDF', () {
    late Font font;

    setUpAll(() async {
      font = await _downloadFont('NotoSansGurmukhi');
    });

    test('renders Gurmukhi text', () {
      final style = TextStyle(font: font, fontSize: 20);
      pdf.addPage(Page(
        build: (ctx) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Gurmukhi (ਗੁਰਮੁਖੀ)', style: style),
            SizedBox(height: 8),
            Text('ਸਤ ਸ੍ਰੀ ਅਕਾਲ! ਪੰਜਾਬੀ ਇੱਕ ਭਾਸ਼ਾ ਹੈ।', style: style),
          ],
        ),
      ));
    });
  });

  group('Oriya PDF', () {
    late Font font;

    setUpAll(() async {
      font = await _downloadFont('NotoSansOriya');
    });

    test('renders Oriya text', () {
      final style = TextStyle(font: font, fontSize: 20);
      pdf.addPage(Page(
        build: (ctx) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Oriya (ଓଡ଼ିଆ)', style: style),
            SizedBox(height: 8),
            Text('ନମସ୍କାର! ଓଡ଼ିଆ ଏକ ଭାଷା।', style: style),
          ],
        ),
      ));
    });
  });

  // ─── Mixed Script Tests ─────────────────────────────────────────────

  group('Mixed script rendering', () {
    late Font devaFont;
    late Font malaFont;

    setUpAll(() async {
      devaFont = await _downloadFont('NotoSansDevanagari');
      malaFont = await _downloadFont('NotoSansMalayalam');
    });

    test('Devanagari mixed with Latin', () {
      final style = TextStyle(font: devaFont, fontSize: 20);
      pdf.addPage(Page(
        build: (ctx) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mixed Scripts Test', style: TextStyle(fontSize: 18)),
            SizedBox(height: 10),
            // Latin + Devanagari + Latin in one span
            Text('Hello नमस्ते World', style: style),
            SizedBox(height: 8),
            Text('India (भारत) is great', style: style),
            SizedBox(height: 8),
            Text('1234 हिन्दी 5678', style: style),
          ],
        ),
      ));
    });

    test('Malayalam mixed with Latin', () {
      final style = TextStyle(font: malaFont, fontSize: 20);
      pdf.addPage(Page(
        build: (ctx) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Kerala (കേരളം) is beautiful', style: style),
            SizedBox(height: 8),
            Text('100% മലയാളം supported!', style: style),
          ],
        ),
      ));
    });
  });

  // ─── Save PDF ──────────────────────────────────────────────────────

  tearDownAll(() async {
    final file = File('complex_scripts.pdf');
    await file.writeAsBytes(await pdf.save());
  });
}
