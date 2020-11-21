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
import 'dart:math';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart';
import 'package:test/test.dart';

void printMetrics(
    PdfGraphics canvas, String text, PdfFont font, PdfPoint size) {
  final metricsUnscales = font.stringMetrics(text);
  final fontSizeW = size.x / metricsUnscales.maxWidth;
  final fontSizeH = size.y / metricsUnscales.maxHeight;
  final fontSize = min(fontSizeW, fontSizeH);
  final metrics = metricsUnscales * fontSize;

  const deb = 20;

  final x = (size.x - metrics.maxWidth) / 2.0;
  final y = (size.y - metrics.maxHeight) / 2.0 - metrics.descent;

  canvas
    ..setLineWidth(0.5)
    ..drawRect(x, y + metrics.descent, metrics.advanceWidth, metrics.maxHeight)
    ..setStrokeColor(PdfColors.green)
    ..strokePath()
    ..drawRect(x + metrics.left, y + metrics.top, metrics.width, metrics.height)
    ..setStrokeColor(PdfColors.amber)
    ..strokePath()
    ..drawLine(x + metrics.effectiveLeft - deb, y,
        x + metrics.maxWidth + metrics.effectiveLeft + deb, y)
    ..setColor(PdfColors.blue)
    ..strokePath()
    ..drawEllipse(x, y, 5, 5)
    ..setFillColor(PdfColors.black)
    ..fillPath()
    ..drawEllipse(x + metrics.advanceWidth, y, 5, 5)
    ..setFillColor(PdfColors.red)
    ..fillPath()
    ..setFillColor(PdfColors.grey)
    ..drawString(font, fontSize, text, x, y);
}

void main() {
  test('Pdf Font Metrics', () {
    final pdf = Document();

    final ttfFont = File('open-sans.ttf');
    final fontData = ttfFont.readAsBytesSync();
    final font = PdfTtfFont(pdf.document, fontData.buffer.asByteData());

    for (var letter
        in 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz&%!?0123456789'
            .codeUnits) {
      pdf.addPage(Page(
          pageFormat: const PdfPageFormat(500, 500, marginAll: 20),
          build: (Context context) {
            return ConstrainedBox(
                constraints: const BoxConstraints.expand(),
                child: FittedBox(
                    child: CustomPaint(
                        size: const PdfPoint(200, 200),
                        painter: (PdfGraphics canvas, PdfPoint size) {
                          printMetrics(
                              canvas, String.fromCharCode(letter), font, size);
                        })));
          }));
    }

    final file = File('metrics.pdf');
    file.writeAsBytesSync(pdf.save());
  });
}
