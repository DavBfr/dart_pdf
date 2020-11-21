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
import 'package:test/test.dart';

void printText(
    PdfPage page, PdfGraphics canvas, String text, PdfFont font, double top) {
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
    ..drawLine(x + metrics.left - deb, y + metrics.ascent,
        x + metrics.right + deb, y + metrics.ascent)
    ..setColor(PdfColors.green)
    ..strokePath()
    ..drawLine(x + metrics.left - deb, y + metrics.descent,
        x + metrics.right + deb, y + metrics.descent)
    ..setColor(PdfColors.purple)
    ..strokePath()
    ..setColor(const PdfColor(0.3, 0.3, 0.3))
    ..drawString(font, fontSize, text, x, y);
}

void printTextTtf(
    PdfPage page, PdfGraphics canvas, String text, File ttfFont, double top) {
  final fontData = ttfFont.readAsBytesSync();
  final font = PdfTtfFont(page.pdfDocument, fontData.buffer.asByteData());

  printText(page, canvas, text, font, top);
}

void main() {
  test('Pdf TrueType', () {
    final pdf = PdfDocument(compress: false);
    final page = PdfPage(pdf, pageFormat: const PdfPageFormat(500, 300));

    final g = page.getGraphics();
    var top = 0;
    const s = 'Hello Lukáča ';

    printTextTtf(page, g, s, File('open-sans.ttf'), 30.0 + 30.0 * top++);
    printTextTtf(page, g, s, File('open-sans-bold.ttf'), 30.0 + 30.0 * top++);
    printTextTtf(page, g, s, File('roboto.ttf'), 30.0 + 30.0 * top++);
    printTextTtf(page, g, s, File('noto-sans.ttf'), 30.0 + 30.0 * top++);
    printTextTtf(
        page, g, '你好 檯號 ', File('genyomintw.ttf'), 30.0 + 30.0 * top++);

    final file = File('ttf.pdf');
    file.writeAsBytesSync(pdf.save());
  });

  test('Font SubSetting', () {
    final fontData = File('open-sans.ttf').readAsBytesSync();
    final font = TtfParser(fontData.buffer.asByteData());
    final ttfWriter = TtfWriter(font);
    final data = ttfWriter.withChars('hçHée'.runes.toList());
    final output = File('${font.fontName}.ttf');
    output.writeAsBytesSync(data);
  });

  test('Font SubSetting CN', () {
    final fontData = File('genyomintw.ttf').readAsBytesSync();
    final font = TtfParser(fontData.buffer.asByteData());
    final ttfWriter = TtfWriter(font);
    final data = ttfWriter.withChars('hçHée 你好 檯號 ☃'.runes.toList());
    final output = File('${font.fontName}.ttf');
    output.writeAsBytesSync(data);
  });
}
