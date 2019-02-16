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
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  test('Pdf', () {
    final Uint32List img = Uint32List(10 * 10);
    img.fillRange(0, img.length - 1, 0x12345678);

    final PdfDocument pdf = PdfDocument();
    pdf.info = PdfInfo(pdf,
        author: 'David PHAM-VAN',
        creator: 'David PHAM-VAN',
        title: 'My Title',
        subject: 'My Subject');
    final PdfPage page =
        PdfPage(pdf, pageFormat: const PdfPageFormat(500.0, 300.0));

    final PdfGraphics g = page.getGraphics();

    g.saveContext();
    Matrix4 tm = Matrix4.identity();
    tm.translate(10.0, 290.0);
    tm.scale(1.0, -1.0);
    g.setTransform(tm);
    g.setColor(const PdfColor(0.0, 0.0, 0.0));
    g.drawShape(
        'M37 0H9C6.24 0 4 2.24 4 5v38c0 2.76 2.24 5 5 5h28c2.76 0 5-2.24 5-5V5c0-2.76-2.24-5-5-5zM23 46c-1.66 0-3-1.34-3-3s1.34-3 3-3 3 1.34 3 3-1.34 3-3 3zm15-8H8V6h30v32z',
        stroke: false);
    g.fillPath();
    g.restoreContext();

    g.saveContext();
    tm = Matrix4.identity();
    tm.translate(200.0, 290.0);
    tm.scale(.1, -.1);
    g.setTransform(tm);
    g.setColor(const PdfColor(0.0, 0.0, 0.0));
    g.drawShape(
        'M300,200 h-150 a150,150 0 1,0 150,-150 z M275,175 v-150 a150,150 0 0,0 -150,150 z');
    g.restoreContext();

    final PdfFont font1 = g.defaultFont;

    final Uint8List data = File('open-sans.ttf').readAsBytesSync();
    final PdfTtfFont font2 = PdfTtfFont(pdf, data.buffer.asByteData());
    const String s = 'Hello World!';
    final PdfRect r = font2.stringBounds(s);
    const double FS = 20.0;
    g.setColor(const PdfColor(0.0, 1.0, 1.0));
    g.drawRect(50.0 + r.x * FS, 30.0 + r.y * FS, r.width * FS, r.height * FS);
    g.fillPath();
    g.setColor(const PdfColor(0.3, 0.3, 0.3));
    g.drawString(font2, FS, s, 50.0, 30.0);

    g.setColor(const PdfColor(1.0, 0.0, 0.0));
    g.drawString(font2, 20.0, 'Hé (Olà)', 50.0, 10.0);
    g.drawLine(30.0, 30.0, 200.0, 200.0);
    g.strokePath();
    g.setColor(const PdfColor(1.0, 0.0, 0.0));
    g.drawRect(300.0, 150.0, 50.0, 50.0);
    g.fillPath();
    g.setColor(const PdfColor(0.0, 0.5, 0.0));
    final PdfImage image =
        PdfImage(pdf, image: img.buffer.asUint8List(), width: 10, height: 10);
    for (double i = 10.0; i < 90.0; i += 5.0) {
      g.saveContext();
      final Matrix4 tm = Matrix4.identity();
      tm.rotateZ(i * pi / 360.0);
      tm.translate(300.0, -100.0);
      g.setTransform(tm);
      g.drawString(font1, 12.0, 'Hello $i', 20.0, 100.0);
      g.drawImage(image, 100.0, 100.0);
      g.restoreContext();
    }

    final File file = File('complex.pdf');
    file.writeAsBytesSync(pdf.save());
  });
}
