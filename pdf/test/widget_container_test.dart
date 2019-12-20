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
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart';

Document pdf;

PdfImage generateBitmap(PdfDocument pdf, int w, int h) {
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

  return PdfImage(
    pdf,
    image: bm.buffer.asUint8List(),
    width: w,
    height: h,
  );
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
    final PdfImage image = generateBitmap(pdf.document, 100, 200);

    final List<Widget> widgets = <Widget>[];
    for (BoxShape shape in BoxShape.values) {
      for (BoxFit fit in BoxFit.values) {
        widgets.add(
          Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: shape,
              borderRadius: 10,
              image: DecorationImage(image: image, fit: fit),
            ),
            width: 100,
            height: 100,
            child: Container(
              width: 70,
              color: PdfColors.yellow,
              child: Text(
                '$fit\n$shape',
                textAlign: TextAlign.center,
                textScaleFactor: 0.6,
              ),
            ),
          ),
        );
      }
    }

    pdf.addPage(MultiPage(
        build: (Context context) => <Widget>[
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: widgets,
              )
            ]));
  });

  test('Container Widgets BoxShape Border', () {
    pdf.addPage(Page(
      build: (Context context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            Container(
              height: 200.0,
              width: 200.0,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                border: BoxBorder(
                    bottom: true,
                    top: true,
                    left: true,
                    right: true,
                    color: PdfColors.blue,
                    width: 3),
              ),
            ),
            Container(
              height: 200.0,
              width: 200.0,
              decoration: const BoxDecoration(
                shape: BoxShape.rectangle,
                borderRadius: 40,
                border: BoxBorder(
                    bottom: true,
                    top: true,
                    left: true,
                    right: true,
                    color: PdfColors.blue,
                    width: 3),
              ),
            ),
          ],
        ),
      ),
    ));
  });

  tearDownAll(() {
    final File file = File('widgets-container.pdf');
    file.writeAsBytesSync(pdf.save());
  });
}
