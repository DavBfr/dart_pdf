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
import 'package:test/test.dart';

void main() {
  test('Pdf', () {
    var pdf = PdfDocument();
    var page = PdfPage(pdf, pageFormat: const PdfPageFormat(500.0, 300.0));

    var g = page.getGraphics();
    var ttf = PdfTtfFont(
        pdf,
        (File("open-sans.ttf").readAsBytesSync() as Uint8List)
            .buffer
            .asByteData());
    var s = "Hello World!";
    var r = ttf.stringBounds(s);
    const FS = 20.0;
    g.setColor(PdfColor(0.0, 1.0, 1.0));
    g.drawRect(50.0 + r.x * FS, 30.0 + r.y * FS, r.width * FS, r.height * FS);
    g.fillPath();
    g.setColor(PdfColor(0.3, 0.3, 0.3));
    g.drawString(ttf, FS, s, 50.0, 30.0);

    var roboto = PdfTtfFont(
        pdf,
        (File("roboto.ttf").readAsBytesSync() as Uint8List)
            .buffer
            .asByteData());

    r = roboto.stringBounds(s);
    g.setColor(PdfColor(0.0, 1.0, 1.0));
    g.drawRect(50.0 + r.x * FS, 130.0 + r.y * FS, r.width * FS, r.height * FS);
    g.fillPath();
    g.setColor(PdfColor(0.3, 0.3, 0.3));
    g.drawString(roboto, FS, s, 50.0, 130.0);

    var file = File('file2.pdf');
    file.writeAsBytesSync(pdf.save());
  });
}
