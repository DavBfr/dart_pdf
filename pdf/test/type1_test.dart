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

void printText(PdfGraphics g, String text, PdfFont font, double top) {
  text = text + font.fontName;
  final PdfRect r = font.stringBounds(text);
  const double FS = 20.0;
  g.setColor(const PdfColor(0.9, 0.9, 0.9));
  g.drawRect(50.0 + r.x * FS, g.page.pageFormat.height - top + r.y * FS,
      r.width * FS, r.height * FS);
  g.fillPath();
  g.setColor(const PdfColor(0.3, 0.3, 0.3));
  g.drawString(font, FS, text, 50.0, g.page.pageFormat.height - top);
}

void main() {
  test('Pdf', () {
    final PdfDocument pdf = PdfDocument();
    final PdfPage page =
        PdfPage(pdf, pageFormat: const PdfPageFormat(500.0, 430.0));

    final PdfGraphics g = page.getGraphics();
    int top = 0;
    const String s = 'Hello ';

    printText(g, s, PdfFont.courier(pdf), 20.0 + 30.0 * top++);
    printText(g, s, PdfFont.courierBold(pdf), 20.0 + 30.0 * top++);
    printText(g, s, PdfFont.courierOblique(pdf), 20.0 + 30.0 * top++);
    printText(g, s, PdfFont.courierBoldOblique(pdf), 20.0 + 30.0 * top++);

    printText(g, s, PdfFont.helvetica(pdf), 20.0 + 30.0 * top++);
    printText(g, s, PdfFont.helveticaBold(pdf), 20.0 + 30.0 * top++);
    printText(g, s, PdfFont.helveticaOblique(pdf), 20.0 + 30.0 * top++);
    printText(g, s, PdfFont.helveticaBoldOblique(pdf), 20.0 + 30.0 * top++);

    printText(g, s, PdfFont.times(pdf), 20.0 + 30.0 * top++);
    printText(g, s, PdfFont.timesBold(pdf), 20.0 + 30.0 * top++);
    printText(g, s, PdfFont.timesItalic(pdf), 20.0 + 30.0 * top++);
    printText(g, s, PdfFont.timesBoldItalic(pdf), 20.0 + 30.0 * top++);

    printText(g, s, PdfFont.symbol(pdf), 20.0 + 30.0 * top++);
    printText(g, s, PdfFont.zapfDingbats(pdf), 20.0 + 30.0 * top++);

    final File file = File('type1.pdf');
    file.writeAsBytesSync(pdf.save());
  });
}
