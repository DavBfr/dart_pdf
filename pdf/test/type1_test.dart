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
        page, g, s, PdfFont.helveticaBoldOblique(pdf), 20.0 + 30.0 * top++);

    printText(page, g, s, PdfFont.times(pdf), 20.0 + 30.0 * top++);
    printText(page, g, s, PdfFont.timesBold(pdf), 20.0 + 30.0 * top++);
    printText(page, g, s, PdfFont.timesItalic(pdf), 20.0 + 30.0 * top++);
    printText(page, g, s, PdfFont.timesBoldItalic(pdf), 20.0 + 30.0 * top++);

    printText(page, g, s, PdfFont.symbol(pdf), 20.0 + 30.0 * top++);
    printText(page, g, s, PdfFont.zapfDingbats(pdf), 20.0 + 30.0 * top++);

    final file = File('type1.pdf');
    await file.writeAsBytes(await pdf.save());
  });
}
