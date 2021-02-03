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
  PdfGraphics canvas,
  int codeUnit,
  PdfFont font,
  PdfPoint size,
) {
  final metricsUnscaled = font.glyphMetrics(codeUnit);
  final fontSizeW = size.x / metricsUnscaled.maxWidth;
  final fontSizeH = size.y / metricsUnscaled.maxHeight;
  final fontSize = min(fontSizeW, fontSizeH);
  final metrics = metricsUnscaled * fontSize;
  final m = metricsUnscaled * font.unitsPerEm.toDouble();

  const deb = 20;
  const s = 5.0;

  final x = (size.x - metrics.maxWidth) / 2.0;
  final y = (size.y - metrics.maxHeight) / 2.0 - metrics.descent;

  int? index;
  if (font is PdfTtfFont) {
    index = font.font.charToGlyphIndexMap[codeUnit];
  }

  canvas
    ..setLineWidth(0.5)
    // Glyph maximum size
    ..drawRect(x, y + metrics.descent, metrics.advanceWidth, metrics.maxHeight)
    ..setStrokeColor(PdfColors.green)
    ..strokePath()
    // Glyph bounding box
    ..drawRect(x + metrics.left, y + metrics.top, metrics.width, metrics.height)
    ..setStrokeColor(PdfColors.amber)
    ..strokePath()
    // Glyph baseline
    ..drawLine(x + metrics.effectiveLeft - deb, y,
        x + metrics.maxWidth + metrics.effectiveLeft + deb, y)
    ..setColor(PdfColors.blue)
    ..strokePath()
    // Drawing Start
    ..drawEllipse(x, y, 5, 5)
    ..setFillColor(PdfColors.black)
    ..fillPath()
    // Next glyph
    ..drawEllipse(x + metrics.advanceWidth, y, 5, 5)
    ..setFillColor(PdfColors.red)
    ..fillPath()
    // Left Bearing
    ..saveContext()
    ..setGraphicState(const PdfGraphicState(opacity: 0.5))
    ..drawEllipse(x + metrics.leftBearing, y, 5, 5)
    ..setFillColor(PdfColors.purple)
    ..fillPath()
    ..restoreContext()
    // The glyph
    ..setFillColor(PdfColors.grey)
    ..drawString(font, fontSize, String.fromCharCode(codeUnit), x, y)
    // Metrics information
    ..setFillColor(PdfColors.black)
    ..drawString(canvas.defaultFont!, s,
        'unicode: 0x${codeUnit.toRadixString(16)}', 10, size.y - 20 - s * 0)
    ..drawString(canvas.defaultFont!, s, 'index: 0x${index!.toRadixString(16)}',
        10, size.y - 20 - s * 1)
    ..drawString(canvas.defaultFont!, s, 'left: ${m.left.toInt()}', 10,
        size.y - 20 - s * 2)
    ..drawString(canvas.defaultFont!, s, 'right: ${m.right.toInt()}', 10,
        size.y - 20 - s * 3)
    ..drawString(canvas.defaultFont!, s, 'top: ${m.top.toInt()}', 10,
        size.y - 20 - s * 4)
    ..drawString(canvas.defaultFont!, s, 'bottom: ${m.bottom.toInt()}', 10,
        size.y - 20 - s * 5)
    ..drawString(canvas.defaultFont!, s,
        'advanceWidth: ${m.advanceWidth.toInt()}', 10, size.y - 20 - s * 6)
    ..drawString(canvas.defaultFont!, s,
        'leftBearing: ${m.leftBearing.toInt()}', 10, size.y - 20 - s * 7);
}

void main() {
  test('Pdf Font Metrics', () async {
    final pdf = Document();

    PdfFont.courier(pdf.document);
    final ttfFont = File('open-sans.ttf');
    final fontData = ttfFont.readAsBytesSync();
    final font = PdfTtfFont(pdf.document, fontData.buffer.asByteData());

    for (var letter in
        //font.font.charToGlyphIndexMap.keys
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz&%!?0123456789'
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
                          printMetrics(canvas, letter, font, size);
                        })));
          }));
    }

    final file = File('metrics.pdf');
    await file.writeAsBytes(await pdf.save());
  });
}
