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
import 'package:pdf/widgets.dart';
import 'package:test/test.dart';

late Document pdf;

void main() {
  setUpAll(() {
    Document.debug = true;
    RichText.debug = true;
    pdf = Document();
  });

  test('Pdf Link Annotations', () async {
    pdf.addPage(
      Page(
        build: (context) => Column(
          children: [
            Link(child: Text('A link'), destination: 'destination'),
            UrlLink(
                child: Text('GitHub'),
                destination: 'https://github.com/DavBfr/dart_pdf/'),
          ],
        ),
      ),
    );
  });

  test('Pdf Shape Annotations', () async {
    pdf.addPage(
      Page(
        build: (context) => Wrap(
          spacing: 20,
          runSpacing: 20,
          children: [
            SizedBox(
              width: 200,
              height: 200,
              child: CircleAnnotation(
                color: PdfColors.blue,
                author: 'David PHAM-VAN',
              ),
            ),
            SizedBox(
              width: 200,
              height: 200,
              child: SquareAnnotation(
                color: PdfColors.red,
              ),
            ),
            SizedBox(
              width: 200,
              height: 100,
              child: PolyLineAnnotation(
                points: const [
                  PdfPoint(10, 10),
                  PdfPoint(10, 30),
                  PdfPoint(50, 70)
                ],
                color: PdfColors.purple,
              ),
            ),
            SizedBox(
              width: 200,
              height: 100,
              child: PolygonAnnotation(
                points: const [
                  PdfPoint(10, 10),
                  PdfPoint(10, 30),
                  PdfPoint(50, 70)
                ],
                color: PdfColors.orange,
              ),
            ),
            SizedBox(
              width: 200,
              height: 100,
              child: InkAnnotation(
                points: const [
                  [PdfPoint(10, 10), PdfPoint(10, 30), PdfPoint(50, 70)],
                  [PdfPoint(100, 10), PdfPoint(100, 30), PdfPoint(150, 70)],
                ],
                color: PdfColors.green,
              ),
            ),
          ],
        ),
      ),
    );
  });

  test('Pdf Anchor Annotation', () async {
    pdf.addPage(Page(
      build: (context) =>
          Anchor(child: Text('The destination'), name: 'destination'),
    ));
  });

  tearDownAll(() async {
    final file = File('annotations.pdf');
    await file.writeAsBytes(await pdf.save());
  });
}
