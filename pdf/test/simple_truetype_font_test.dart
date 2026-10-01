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

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:test/test.dart';

/// Builds a one-page document with [text] in an embedded TrueType font and
/// returns the raw PDF, so the font dictionaries and content streams can be
/// matched directly.
Future<String> buildPdf(String text, {required bool simple}) async {
  final data = File('open-sans.ttf').readAsBytesSync();
  final ttf = pw.Font.ttf(data.buffer.asByteData());

  // Uncompressed so the output is greppable. This changes the stream filters
  // only, not the font structure under test.
  final doc = pw.Document(compress: false, simpleTrueTypeFonts: simple);
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (_) => pw.Text(text, style: pw.TextStyle(font: ttf, fontSize: 12)),
    ),
  );
  return String.fromCharCodes(await doc.save());
}

/// The `/Widths` array of the simple font: 224 numbers, one per code from
/// /FirstChar 32 to /LastChar 255.
List<int> widthsOf(String pdf) {
  for (final object in RegExp(r'\d+ 0 obj\s*\[([0-9 ]+)\]').allMatches(pdf)) {
    final numbers = object
        .group(1)!
        .trim()
        .split(RegExp(r'\s+'))
        .map(int.parse)
        .toList();
    if (numbers.length == 224) {
      return numbers;
    }
  }

  throw StateError('no 224-entry /Widths array in the document');
}

/// The bytes of the first `[(...)]TJ` run.
List<int> firstRun(String pdf) {
  final start = pdf.indexOf('[(');
  final end = pdf.indexOf(')]TJ', start);
  expect(start, greaterThan(0));
  return pdf.substring(start + 2, end).codeUnits;
}

void main() {
  test('embeds a CID /Type0 font by default', () async {
    final pdf = await buildPdf('Hello World', simple: false);

    expect(pdf, contains('/Subtype/Type0'));
    expect(pdf, contains('/Identity-H'));
    expect(pdf, contains('/CIDFontType2'));
  });

  test('simpleTrueTypeFonts embeds a simple /TrueType font', () async {
    final pdf = await buildPdf('Hello World', simple: true);

    expect(pdf, contains('/Subtype/TrueType'));
    expect(pdf, contains('/FirstChar 32'));
    expect(pdf, contains('/LastChar 255'));
    expect(pdf, isNot(contains('/Type0')), reason: 'no CID wrapper remains');
    expect(pdf, isNot(contains('/Identity-H')));
    expect(pdf, isNot(contains('/CIDFontType2')));
  });

  test('simple fonts write single-byte literals, not hex CIDs', () async {
    final pdf = await buildPdf('Hello World', simple: true);

    // Text is laid out as one run per word.
    expect(pdf, contains('[(Hello)]TJ'));
    expect(pdf, contains('[(World)]TJ'));

    // putText() has to return after delegating to super. Without it the hex
    // CID string is appended on top of the literal and every run is written
    // twice.
    expect(
      RegExp(r'\[\([^)]*\)\]TJ\s*<[0-9a-fA-F]+>').hasMatch(pdf),
      isFalse,
      reason: 'text must not be emitted twice',
    );
  });

  test('simple fonts are nonsymbolic, CID fonts stay symbolic', () async {
    // A symbolic font is defined to use its built-in encoding, so declaring
    // /Flags 4 alongside /WinAnsiEncoding contradicts itself and a consumer
    // may ignore /Encoding entirely.
    final simple = await buildPdf('Hello World', simple: true);
    expect(simple, contains('/Flags 32'));

    final cid = await buildPdf('Hello World', simple: false);
    expect(cid, contains('/Flags 4'));
  });

  test('an en dash is written and measured, not thrown on', () async {
    // save() used to fail with 'ArgumentError: Invalid argument (string):
    // Contains invalid characters' for anything above 0x7F that WinAnsi holds
    // and Latin-1 does not, because the simple path encodes with the shared
    // PdfFont encoder.
    final pdf = await buildPdf('a\u2013b', simple: true);

    expect(firstRun(pdf), <int>[0x61, 0x96, 0x62]);

    final widths = widthsOf(pdf);
    expect(
      widths[0x96 - 32],
      greaterThan(0),
      reason: 'the en dash has a width',
    );
    expect(widths[0x41 - 32], greaterThan(0), reason: 'A still has one');

    // Every code in 0x80-0x9F used to be measured as its C1 control, which no
    // font has a glyph for, so all 32 widths came out zero.
    var defined = 0;
    for (var code = 0x80; code <= 0x9F; code++) {
      if (widths[code - 32] > 0) {
        defined++;
      }
    }
    expect(defined, greaterThan(20), reason: 'WinAnsi defines 27 of the 32');

    for (final hole in <int>[0x81, 0x8D, 0x8F, 0x90, 0x9D]) {
      expect(
        widths[hole - 32],
        0,
        reason: 'WinAnsi has no glyph at 0x${hole.toRadixString(16)}',
      );
    }
  });

  test('a rune outside WinAnsi falls back instead of throwing', () async {
    // U+0101 is in open-sans but has no WinAnsi code, so the simple path cannot
    // write it at all. It used to reach putText, where the encode threw out of
    // save(); now it is reported unsupported and drawn like any other missing
    // character.
    final pdf = await buildPdf('a\u0101b', simple: true);

    expect(firstRun(pdf), <int>[0x61]);
    expect(pdf, contains(' re '), reason: 'the placeholder box is drawn');

    // And the same rune is written normally by the CID path.
    final cid = await buildPdf('a\u0101b', simple: false);
    expect(cid, isNot(contains(' re ')));
  });

  test('a partial view embeds only its own bytes', () async {
    // The whole backing buffer used to be embedded while /Length1 described only
    // the view, so the stream and the number that says how long it is disagreed:
    // 1,093,112 bytes of font data for a /Length1 of 93,112.
    final font = File('open-sans.ttf').readAsBytesSync();

    Future<String> pdfFor(ByteData data) async {
      final doc = pw.Document(compress: false, simpleTrueTypeFonts: true);
      doc.addPage(
        pw.Page(
          build: (_) =>
              pw.Text('Ab', style: pw.TextStyle(font: pw.Font.ttf(data))),
        ),
      );
      return String.fromCharCodes(await doc.save());
    }

    // Just the embedded font: the rest of the document carries a random /ID.
    String fontStream(String pdf) {
      final start = pdf.indexOf('/Length1 ');
      final end = pdf.indexOf('endstream', start);
      expect(start, greaterThan(0));
      expect(end, greaterThan(start));
      return pdf.substring(start, end);
    }

    final buffer = Uint8List(64 + font.length)
      ..fillRange(0, 64, 0x5A)
      ..setRange(64, 64 + font.length, font);

    final fromView = await pdfFor(
      ByteData.view(buffer.buffer, 64, font.length),
    );
    final fromWhole = await pdfFor(font.buffer.asByteData());

    expect(
      fontStream(fromView),
      fontStream(fromWhole),
      reason: 'a view must embed exactly what the whole buffer embeds',
    );

    final declared = RegExp(r'/Length1 (\d+)').firstMatch(fromView);
    expect(declared, isNotNull);
    expect(int.parse(declared!.group(1)!), font.length);
  });
}
