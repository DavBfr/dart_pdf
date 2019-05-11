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
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart';

Document pdf;

Uint32List generateBitmap(int w, int h) {
  final Uint32List bm = Uint32List(w * h);
  final double dw = w.toDouble();
  final double dh = h.toDouble();
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      bm[y * w + x] = (math.sin(x / dw) * 256).toInt() |
          (math.sin(y / dh) * 256).toInt() << 8 |
          (math.sin(x / dw * y / dh) * 256).toInt() << 16 |
          0xff000000;
    }
  }

  return bm;
}

void main() {
  setUpAll(() {
    Document.debug = true;
    pdf = Document();
  });

  test('Container Widgets Flat', () {
    pdf.addPage(Page(
      build: (Context context) => Container(
            alignment: Alignment.center,
            margin: const EdgeInsets.all(30),
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
                color: PdfColors.blue,
                borderRadius: 20,
                border: BoxBorder(
                  color: PdfColors.blue800,
                  top: true,
                  left: true,
                  right: true,
                  bottom: true,
                  width: 2,
                )),
            width: 200,
            height: 400,
            // child: Placeholder(),
          ),
    ));
  });

  test('Container Widgets Image', () {
    final Uint32List img = generateBitmap(100, 100);
    final PdfImage image = PdfImage(pdf.document,
        image: img.buffer.asUint8List(), width: 100, height: 100);

    pdf.addPage(Page(
      build: (Context context) => Container(
            alignment: Alignment.center,
            margin: const EdgeInsets.all(30),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              image: DecorationImage(image: image, fit: BoxFit.cover),
            ),
            width: 200,
            height: 400,
            // child: Placeholder(),
          ),
    ));
  });

  tearDownAll(() {
    final File file = File('widgets-container.pdf');
    file.writeAsBytesSync(pdf.save());
  });
}
