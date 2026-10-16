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

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart';
import 'package:test/test.dart';

/// One annotation dictionary, picked apart.
class Annot {
  Annot(this.body);

  final String body;

  String get subtype =>
      RegExp(r'/Subtype\s*(/\w+)').firstMatch(body)!.group(1)!;

  PdfRect get rect {
    final v = _numbers(
      RegExp(r'/Rect\[([^\]]*)\]').firstMatch(body)!.group(1)!,
    );
    return PdfRect.fromLBRT(v[0], v[1], v[2], v[3]);
  }

  /// The vertices, as x/y pairs.
  List<PdfPoint> get vertices {
    final match = RegExp(r'/Vertices\[([^\]]*)\]').firstMatch(body);
    return match == null ? <PdfPoint>[] : _points(match.group(1)!);
  }

  /// One list of points per ink stroke.
  List<List<PdfPoint>> get inkList {
    final match = RegExp(r'/InkList\[(.*?)\]\]').firstMatch(body);
    if (match == null) {
      return <List<PdfPoint>>[];
    }

    return RegExp(r'\[([^\]]*)\]')
        .allMatches('${match.group(1)!}]')
        .map((m) => _points(m.group(1)!))
        .toList();
  }

  static List<double> _numbers(String body) => body
      .trim()
      .split(RegExp(r'\s+'))
      .where((String s) => s.isNotEmpty)
      .map(double.parse)
      .toList();

  static List<PdfPoint> _points(String body) {
    final v = _numbers(body);
    return <PdfPoint>[
      for (var i = 0; i + 1 < v.length; i += 2) PdfPoint(v[i], v[i + 1]),
    ];
  }
}

/// Every annotation dictionary in [pdf].
List<Annot> annotations(String pdf) => RegExp(
  r'<</Type/Annot(.*?)>>\s*(stream|endobj)',
  dotAll: true,
).allMatches(pdf).map((m) => Annot(m.group(1)!)).toList();

/// Save a one-page document holding [child].
Future<String> build(
  Widget child, {
  PdfPageFormat format = const PdfPageFormat(200, 200, marginAll: 0),
}) async {
  final document = Document(compress: false);
  document.addPage(Page(pageFormat: format, build: (Context context) => child));
  return String.fromCharCodes(await document.save());
}

const triangle = <PdfPoint>[PdfPoint(10, 5), PdfPoint(60, 5), PdfPoint(60, 15)];

void main() {
  test('a polygon annotation lands where its shape is drawn', () async {
    // The widget layer handed the object layer un-flipped points, and the object
    // layer flipped them against its own /Rect - on coordinates already in page
    // space - so every vertex ended up at about -pageY, below the MediaBox. The
    // page still painted; the annotation was dead.
    final pdf = await build(
      PolygonAnnotation(points: triangle, color: PdfColors.red),
    );
    final annot = annotations(pdf).single;

    expect(pdf, contains('/Vertices[10 195 60 195 60 185]'));
    expect(pdf, contains('/Rect[10 185 60 195]'));
    expect(annot.vertices, hasLength(3));
  });

  test('its vertices are the points its sibling widget paints', () async {
    // The Polygon widget paints at (x, box.height - y); the annotation has to
    // name the same places.
    final pdf = await build(
      Stack(
        children: <Widget>[
          Polygon(points: triangle, strokeColor: PdfColors.red),
          PolygonAnnotation(points: triangle, color: PdfColors.red),
        ],
      ),
    );

    final painted = RegExp(r'([\d.]+) ([\d.]+) m').firstMatch(pdf)!;
    expect(
      annotations(pdf).single.vertices.first.x,
      double.parse(painted.group(1)!),
    );
    expect(
      annotations(pdf).single.vertices.first.y,
      double.parse(painted.group(2)!),
    );
  });

  test('every vertex is inside the page and inside its own rect', () async {
    for (final annotation in <Widget>[
      PolygonAnnotation(points: triangle, color: PdfColors.red),
      PolyLineAnnotation(points: triangle, color: PdfColors.blue),
      InkAnnotation(
        points: const <List<PdfPoint>>[
          <PdfPoint>[PdfPoint(10, 5), PdfPoint(20, 5)],
          <PdfPoint>[PdfPoint(30, 25), PdfPoint(40, 35)],
        ],
        color: PdfColors.green,
      ),
    ]) {
      // Top, middle and bottom of a column, so the page offset varies.
      final pdf = await build(
        Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            SizedBox(width: 200, height: 60, child: annotation),
            SizedBox(width: 200, height: 60, child: annotation),
            SizedBox(width: 200, height: 60, child: annotation),
          ],
        ),
      );

      final found = annotations(pdf);
      expect(found, hasLength(3), reason: '$annotation');

      for (final annot in found) {
        final points = <PdfPoint>[
          ...annot.vertices,
          ...annot.inkList.expand((List<PdfPoint> stroke) => stroke),
        ];
        expect(points, isNotEmpty, reason: annot.body);

        for (final point in points) {
          final where = '${annot.subtype} $point in ${annot.rect}';
          expect(point.x, inInclusiveRange(0, 200), reason: where);
          expect(point.y, inInclusiveRange(0, 200), reason: where);
          expect(
            point.x,
            inInclusiveRange(annot.rect.left, annot.rect.right),
            reason: where,
          );
          expect(
            point.y,
            inInclusiveRange(annot.rect.bottom, annot.rect.top),
            reason: where,
          );
        }
      }
    }
  });

  test('a directly built annotation is emitted verbatim', () async {
    // Page space is what /Vertices means, so the object layer transforms nothing.
    final document = PdfDocument(compress: false);
    final page = PdfPage(document, pageFormat: PdfPageFormat.a4);
    PdfAnnot(
      page,
      PdfAnnotPolygon(document, const <PdfPoint>[
        PdfPoint(10, 20),
        PdfPoint(30, 40),
      ], rect: const PdfRect(10, 20, 20, 20)),
    );
    page.getGraphics()
      ..drawBox(const PdfRect(0, 0, 1, 1))
      ..fillPath();

    final pdf = String.fromCharCodes(await document.save());
    expect(pdf, contains('/Vertices[10 20 30 40]'));
  });
}
