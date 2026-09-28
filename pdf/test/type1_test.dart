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
import 'package:pdf/src/pdf/font/win_ansi.dart' as win_ansi;
import 'package:pdf/widgets.dart' as pw;
import 'package:test/test.dart';

/// The 27 codes where /WinAnsiEncoding differs from Latin-1, transcribed from
/// PDF 32000-1 Annex D.2 rather than read back out of the table under test.
const Map<int, int> winAnsiC1 = <int, int>{
  0x80: 0x20AC, // Euro
  0x82: 0x201A, // quotesinglbase
  0x83: 0x0192, // florin
  0x84: 0x201E, // quotedblbase
  0x85: 0x2026, // ellipsis
  0x86: 0x2020, // dagger
  0x87: 0x2021, // daggerdbl
  0x88: 0x02C6, // circumflex
  0x89: 0x2030, // perthousand
  0x8A: 0x0160, // Scaron
  0x8B: 0x2039, // guilsinglleft
  0x8C: 0x0152, // OE
  0x8E: 0x017D, // Zcaron
  0x91: 0x2018, // quoteleft
  0x92: 0x2019, // quoteright
  0x93: 0x201C, // quotedblleft
  0x94: 0x201D, // quotedblright
  0x95: 0x2022, // bullet
  0x96: 0x2013, // endash
  0x97: 0x2014, // emdash
  0x98: 0x02DC, // tilde
  0x99: 0x2122, // trademark
  0x9A: 0x0161, // scaron
  0x9B: 0x203A, // guilsinglright
  0x9C: 0x0153, // oe
  0x9E: 0x017E, // zcaron
  0x9F: 0x0178, // Ydieresis
};

/// The five codes WinAnsi leaves without a glyph.
const Set<int> winAnsiHoles = <int>{0x81, 0x8D, 0x8F, 0x90, 0x9D};

/// One page of [text] in Helvetica, uncompressed so the content stream can be
/// read directly.
Future<Uint8List> helveticaPage(String text) async {
  final doc = pw.Document(compress: false);
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (_) => pw.Text(
        text,
        style: pw.TextStyle(font: pw.Font.helvetica(), fontSize: 12),
      ),
    ),
  );
  return doc.save();
}

/// The page's content stream, which is the first one in the file.
String contentStream(Uint8List pdf) {
  final s = String.fromCharCodes(pdf);
  final start = s.indexOf('stream', s.indexOf('/Length'));
  final end = s.indexOf('endstream', start);
  expect(start, greaterThan(0));
  expect(end, greaterThan(start));
  return s.substring(start + 6, end);
}

/// The bytes of the first `[(...)]TJ` run.
List<int> firstRun(Uint8List pdf) {
  final s = String.fromCharCodes(pdf);
  final start = s.indexOf('[(');
  final end = s.indexOf(')]TJ', start);
  expect(start, greaterThan(0));
  return pdf.sublist(start + 2, end);
}

void printText(
  PdfPage page,
  PdfGraphics canvas,
  String text,
  PdfFont font,
  double top,
) {
  text = text + font.fontName;
  const fontSize = 20.0;
  final metrics = font.stringMetrics(text) * fontSize;

  const deb = 5;

  const x = 50.0;
  final y = page.pageFormat.height - top;

  canvas
    ..drawRect(x + metrics.left, y + metrics.top, metrics.width, metrics.height)
    ..setColor(const PdfColor(0.9, 0.9, 0.9))
    ..fillPath()
    ..drawLine(x + metrics.left - deb, y, x + metrics.right + deb, y)
    ..setColor(PdfColors.blue)
    ..strokePath()
    ..drawLine(
      x + metrics.left - deb,
      y + metrics.ascent,
      x + metrics.right + deb,
      y + metrics.ascent,
    )
    ..setColor(PdfColors.green)
    ..strokePath()
    ..drawLine(
      x + metrics.left - deb,
      y + metrics.descent,
      x + metrics.right + deb,
      y + metrics.descent,
    )
    ..setColor(PdfColors.purple)
    ..strokePath()
    ..setColor(const PdfColor(0.3, 0.3, 0.3))
    ..drawString(font, fontSize, text, x, y);
}

void main() {
  test('Pdf Type1 Embedded Fonts', () async {
    final pdf = PdfDocument();
    final page = PdfPage(pdf, pageFormat: const PdfPageFormat(500, 430));

    final g = page.getGraphics();
    var top = 0;
    const s = 'Hello ';

    printText(page, g, s, PdfFont.courier(pdf), 20.0 + 30.0 * top++);
    printText(page, g, s, PdfFont.courierBold(pdf), 20.0 + 30.0 * top++);
    printText(page, g, s, PdfFont.courierOblique(pdf), 20.0 + 30.0 * top++);
    printText(page, g, s, PdfFont.courierBoldOblique(pdf), 20.0 + 30.0 * top++);

    printText(page, g, s, PdfFont.helvetica(pdf), 20.0 + 30.0 * top++);
    printText(page, g, s, PdfFont.helveticaBold(pdf), 20.0 + 30.0 * top++);
    printText(page, g, s, PdfFont.helveticaOblique(pdf), 20.0 + 30.0 * top++);
    printText(
      page,
      g,
      s,
      PdfFont.helveticaBoldOblique(pdf),
      20.0 + 30.0 * top++,
    );

    printText(page, g, s, PdfFont.times(pdf), 20.0 + 30.0 * top++);
    printText(page, g, s, PdfFont.timesBold(pdf), 20.0 + 30.0 * top++);
    printText(page, g, s, PdfFont.timesItalic(pdf), 20.0 + 30.0 * top++);
    printText(page, g, s, PdfFont.timesBoldItalic(pdf), 20.0 + 30.0 * top++);

    final file = File('type1.pdf');
    await file.writeAsBytes(await pdf.save());
  });

  group('the WinAnsi table', () {
    test('holds 27 glyphs over 0x80-0x9F and five holes', () {
      for (var code = 0x80; code <= 0x9F; code++) {
        expect(
          win_ansi.runeOfCode[code],
          winAnsiHoles.contains(code) ? win_ansi.undefined : winAnsiC1[code],
          reason: 'code 0x${code.toRadixString(16)}',
        );
      }
      expect(winAnsiC1, hasLength(27));
      expect(winAnsiHoles, hasLength(5));
    });

    test('is the identity outside 0x80-0x9F', () {
      for (var code = 0; code < 256; code++) {
        if (code >= 0x80 && code <= 0x9F) {
          continue;
        }
        expect(win_ansi.runeOfCode[code], code);
      }
      expect(win_ansi.runeOfCode, hasLength(256));
    });

    test('every defined code round-trips through encode', () {
      // Criterion: for every code with a defined target, encoding that target
      // rune gives the code back - so what a consumer decodes out of the byte we
      // write is the character the caller asked for.
      for (var code = 0; code < 256; code++) {
        final rune = win_ansi.runeOfCode[code];
        if (rune == win_ansi.undefined) {
          continue;
        }
        expect(
          win_ansi.encode(String.fromCharCode(rune)),
          <int>[code],
          reason:
              'U+${rune.toRadixString(16)} must encode back to '
              '0x${code.toRadixString(16)}',
        );
        expect(win_ansi.codeOfRune(rune), code);
      }
    });

    test('a rune outside the encoding is named in the exception', () {
      expect(
        () => win_ansi.encode('\u0100'),
        throwsA(
          isA<PdfException>().having(
            (PdfException e) => e.message,
            'message',
            contains('U+0100'),
          ),
        ),
      );
    });
  });

  group('a standard-14 font', () {
    test('supports every WinAnsi glyph and no C1 control', () {
      // The encoding was addressed as Latin-1, so all 27 typographic glyphs were
      // reported unsupported - the widget layer drew each one as a crossed box -
      // while the C1 controls in their place were reported supported.
      final font = PdfFont.helvetica(PdfDocument());

      for (final rune in winAnsiC1.values) {
        expect(
          font.isRuneSupported(rune),
          isTrue,
          reason: 'U+${rune.toRadixString(16)}',
        );
      }
      for (var rune = 0x80; rune <= 0x9F; rune++) {
        expect(
          font.isRuneSupported(rune),
          isFalse,
          reason: 'U+${rune.toRadixString(16)} is a C1 control',
        );
      }
      expect(font.isRuneSupported(0x0100), isFalse);
      expect(font.isRuneSupported(0x41), isTrue);
      expect(font.isRuneSupported(0xE9), isTrue);
    });

    test('measures the typographic glyphs at their real widths', () {
      // The width tables are indexed by WinAnsi code, so the rune was the wrong
      // index for all 27: an en dash was measured as widths[0x2013], out of
      // range, or rejected outright.
      final font = PdfFont.helvetica(PdfDocument());

      expect(font.stringMetrics('\u2013').advanceWidth, closeTo(0.556, 1e-9));
      expect(font.glyphMetrics(0x2013).advanceWidth, closeTo(0.556, 1e-9));
      expect(font.glyphMetrics(0x2014).advanceWidth, closeTo(1.0, 1e-9));
      expect(font.glyphMetrics(0x2022).advanceWidth, closeTo(0.35, 1e-9));
      expect(font.glyphMetrics(0x20AC).advanceWidth, closeTo(0.655, 1e-9));
      expect(font.glyphMetrics(0x41).advanceWidth, closeTo(0.667, 1e-9));

      expect(() => font.glyphMetrics(0x0100), throwsA(isA<PdfException>()));
    });

    test('writes the WinAnsi byte instead of a placeholder', () async {
      final pdf = await helveticaPage('a\u2013b\u2019c');

      expect(firstRun(pdf), <int>[0x61, 0x96, 0x62, 0x92, 0x63]);

      // The crossed box is 'm/l/re ... S'. Two of them used to sit between the
      // three one-character runs the placeholders split the text into.
      final content = contentStream(pdf);
      expect(content, isNot(contains(' re ')), reason: 'no placeholder box');
      expect(content, isNot(contains(' S ')), reason: 'no placeholder stroke');
      expect(content.split('TJ'), hasLength(2), reason: 'one unbroken run');
    });

    test('leaves ASCII exactly as it was', () async {
      final pdf = await helveticaPage('Hello');

      expect(firstRun(pdf), 'Hello'.codeUnits);
    });
  });
}
