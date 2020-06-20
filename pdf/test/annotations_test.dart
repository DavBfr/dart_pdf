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

// ignore_for_file: omit_local_variable_types

import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:test/test.dart';

void main() {
  test('Pdf Annotations', () {
    final PdfDocument pdf = PdfDocument();
    final PdfPage page =
        PdfPage(pdf, pageFormat: const PdfPageFormat(500, 300));
    final PdfPage page1 =
        PdfPage(pdf, pageFormat: const PdfPageFormat(500, 300));

    pdf.pdfNames.addDest('target', page1, posY: 100);

    final PdfGraphics g = page.getGraphics();

    PdfAnnot(
      page,
      const PdfAnnotText(
        rect: PdfRect(100, 100, 50, 50),
        content: 'Hello',
      ),
    );

    PdfAnnot(
      page,
      const PdfAnnotNamedLink(
        dest: 'target',
        rect: PdfRect(100, 150, 50, 50),
      ),
    );
    g.drawRect(100, 150, 50, 50);
    g.strokePath();

    PdfAnnot(
      page,
      const PdfAnnotUrlLink(
        rect: PdfRect(100, 250, 50, 50),
        url: 'https://github.com/DavBfr/dart_pdf/',
      ),
    );
    g.drawRect(100, 250, 50, 50);
    g.strokePath();

    final File file = File('annotations.pdf');
    file.writeAsBytesSync(pdf.save());
  });
}
