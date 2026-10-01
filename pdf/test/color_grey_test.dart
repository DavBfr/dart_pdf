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

import 'dart:convert';

import 'package:pdf/pdf.dart';
import 'package:test/test.dart';

void main() {
  test('PdfColorGrey is written as DeviceGray in the content stream', () async {
    final pdf = PdfDocument(compress: false);
    final page = PdfPage(pdf, pageFormat: PdfPageFormat.a4);
    final g = page.getGraphics();
    g.setFillColor(const PdfColorGrey(0.25));
    g.setStrokeColor(const PdfColorGrey(0.75));
    // Page content is only written when something is actually drawn.
    g.drawRect(10, 10, 100, 100);
    g.fillPath();
    g.drawRect(10, 10, 100, 100);
    g.strokePath();

    final content = latin1.decode(await pdf.save());
    expect(content, contains('0.25 g'));
    expect(content, contains('0.75 G'));
    expect(content, isNot(contains(' rg')));
    expect(content, isNot(contains(' RG')));
  });

  test('PdfColorGrey annotation colour is a one-component array', () async {
    final pdf = PdfDocument(compress: false);
    final page = PdfPage(pdf, pageFormat: PdfPageFormat.a4);
    PdfAnnot(
      page,
      PdfAnnotSquare(
        rect: const PdfRect(10, 10, 50, 50),
        color: const PdfColorGrey(0.5),
        interiorColor: const PdfColorCmyk(0, 0, 0, 1),
      ),
    );

    final content = latin1.decode(await pdf.save());
    // 1 component = DeviceGray, 3 = DeviceRGB, 4 = DeviceCMYK (PDF 32000-1, 12.5.2)
    expect(content, matches(RegExp(r'/C\s*\[\s*0\.5\s*\]')));
    expect(content, matches(RegExp(r'/IC\s*\[\s*0 0 0 1\s*\]')));
  });
}
