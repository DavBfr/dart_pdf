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
}
