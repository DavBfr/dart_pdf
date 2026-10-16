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
              destination: 'https://github.com/DavBfr/dart_pdf/',
            ),
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
              child: SquareAnnotation(color: PdfColors.red),
            ),
            SizedBox(
              width: 200,
              height: 100,
              child: PolyLineAnnotation(
                points: const [
                  PdfPoint(10, 10),
                  PdfPoint(10, 30),
                  PdfPoint(50, 70),
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
                  PdfPoint(50, 70),
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
    pdf.addPage(
      Page(
        build: (context) =>
            Anchor(child: Text('The destination'), name: 'destination'),
      ),
    );
  });

  group('an ink annotation', () {
    /// The /InkList sub-arrays of a one-annotation document.
    Future<List<List<double>>> strokesOf(List<List<PdfPoint>> points) async {
      final document = Document(compress: false);
      document.addPage(
        Page(
          pageFormat: const PdfPageFormat(200, 200, marginAll: 0),
          build: (Context context) =>
              InkAnnotation(points: points, color: PdfColors.green),
        ),
      );
      final raw = String.fromCharCodes(await document.save());

      final list = RegExp(
        r'/InkList\[(.*?)\]\]',
        dotAll: true,
      ).firstMatch(raw)!.group(1)!;

      return RegExp(r'\[([^\]]*)\]')
          .allMatches('$list]')
          .map(
            (m) => m
                .group(1)!
                .trim()
                .split(RegExp(r'\s+'))
                .where((String t) => t.isNotEmpty)
                .map(double.parse)
                .toList(),
          )
          .toList();
    }

    test('keeps its strokes separate', () async {
      // The accumulator was List.filled(n, <num>[]), which puts the same
      // growable list in every slot - so every stroke was appended to one shared
      // list and /InkList came out as N copies of all the points. A captured
      // signature was drawn N times, with lines joining the strokes.
      final strokes = await strokesOf(const <List<PdfPoint>>[
        <PdfPoint>[PdfPoint(10, 10), PdfPoint(20, 10)],
        <PdfPoint>[PdfPoint(30, 30), PdfPoint(40, 30)],
      ]);

      expect(strokes, hasLength(2));
      expect(strokes[0], hasLength(4));
      expect(strokes[1], hasLength(4));
      expect(strokes[0], isNot(strokes[1]));
    });

    test('holds two numbers per point and no more', () async {
      final strokes = await strokesOf(<List<PdfPoint>>[
        <PdfPoint>[for (var i = 0; i < 2; i++) PdfPoint(10 + i * 1.0, 10)],
        <PdfPoint>[for (var i = 0; i < 3; i++) PdfPoint(20 + i * 1.0, 20)],
        <PdfPoint>[for (var i = 0; i < 5; i++) PdfPoint(30 + i * 1.0, 30)],
      ]);

      expect(strokes.map((List<double> s) => s.length), <int>[4, 6, 10]);
      expect(
        strokes.fold<int>(0, (int sum, List<double> s) => sum + s.length),
        20,
      );
    });

    test('of one stroke is unchanged', () async {
      final strokes = await strokesOf(const <List<PdfPoint>>[
        <PdfPoint>[PdfPoint(10, 10), PdfPoint(20, 20), PdfPoint(30, 30)],
      ]);

      expect(strokes, hasLength(1));
      expect(strokes.single, hasLength(6));
    });
  });

  group('the polygon subtype', () {
    test('is /Polygon when closed and /PolyLine when open', () async {
      // ISO 32000-1 12.5.6.9. The two names were swapped, and the widget builder
      // had no `closed` to pass, so both widgets emitted /PolyLine: a polygon was
      // drawn open and never filled, which made interiorColor inert.
      final document = Document(compress: false);
      document.addPage(
        Page(
          pageFormat: const PdfPageFormat(200, 200, marginAll: 0),
          build: (Context context) => Column(
            children: <Widget>[
              SizedBox(
                width: 200,
                height: 100,
                child: PolygonAnnotation(
                  points: const <PdfPoint>[
                    PdfPoint(10, 10),
                    PdfPoint(60, 10),
                    PdfPoint(60, 40),
                  ],
                  color: PdfColors.red,
                  interiorColor: PdfColors.yellow,
                ),
              ),
              SizedBox(
                width: 200,
                height: 100,
                child: PolyLineAnnotation(
                  points: const <PdfPoint>[
                    PdfPoint(10, 10),
                    PdfPoint(60, 10),
                    PdfPoint(60, 40),
                  ],
                  color: PdfColors.blue,
                ),
              ),
            ],
          ),
        ),
      );
      final raw = String.fromCharCodes(await document.save());

      expect(RegExp(r'/Subtype/Polygon').allMatches(raw), hasLength(1));
      expect(RegExp(r'/Subtype/PolyLine').allMatches(raw), hasLength(1));

      // The interior colour now sits on the dictionary that can use it.
      final polygon = RegExp(
        r'/Type/Annot(?:(?!endobj).)*?/Subtype/Polygon(?:(?!endobj).)*',
        dotAll: true,
      ).firstMatch(raw)!.group(0)!;
      expect(polygon, contains('/IC['));
      expect(
        RegExp(
          r'/IC\[([^\]]*)\]',
        ).firstMatch(polygon)!.group(1)!.trim().split(RegExp(r'\s+')),
        hasLength(3),
      );
    });

    test('follows the flag it is given', () async {
      for (final entry in <bool, String>{
        true: '/Polygon',
        false: '/PolyLine',
      }.entries) {
        final document = PdfDocument(compress: false);
        final page = PdfPage(document, pageFormat: PdfPageFormat.a4);
        PdfAnnot(
          page,
          PdfAnnotPolygon(
            document,
            const <PdfPoint>[PdfPoint(10, 20), PdfPoint(30, 40)],
            rect: const PdfRect(10, 20, 20, 20),
            closed: entry.key,
          ),
        );
        page.getGraphics()
          ..drawBox(const PdfRect(0, 0, 1, 1))
          ..fillPath();

        expect(
          String.fromCharCodes(await document.save()),
          contains('/Subtype${entry.value}'),
          reason: 'closed ${entry.key}',
        );
      }
    });
  });

  tearDownAll(() async {
    final file = File('annotations.pdf');
    await file.writeAsBytes(await pdf.save());
  });
}
