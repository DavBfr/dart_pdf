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

import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart';
import 'package:test/test.dart';

/// Every degenerate input that used to put a number a reader cannot parse into
/// the content stream. One entry per shape, built uncompressed so the stream can
/// be read back token by token.
final corpus = <String, Future<Uint8List> Function()>{
  'a Stack on an unbounded axis': () => _page(
    Row(
      children: <Widget>[
        Stack(
          children: <Widget>[Container(width: 20, height: 20, color: black)],
        ),
      ],
    ),
  ),
  'a Stack with no children at all': () =>
      _page(Row(children: <Widget>[Stack(children: <Widget>[])])),
  'a Stack asked to expand where it cannot': () => _page(
    Row(
      children: <Widget>[
        Stack(
          fit: StackFit.expand,
          children: <Widget>[Container(color: black)],
        ),
      ],
    ),
  ),
  'progress indicators falling back': () => _page(
    Row(
      children: <Widget>[
        LinearProgressIndicator(value: 0.5, fallbackWidth: 50),
        CircularProgressIndicator(
          value: 0.5,
          fallbackWidth: 20,
          fallbackHeight: 20,
        ),
      ],
    ),
  ),
  'a Table whose columns all measure zero': () => _page(
    Table(
      border: TableBorder.all(),
      children: <TableRow>[
        TableRow(children: <Widget>[SizedBox(), SizedBox()]),
        TableRow(children: <Widget>[SizedBox(), SizedBox()]),
      ],
    ),
  ),
  'a Table of zero-width columns, min': () => _page(
    Table(
      tableWidth: TableWidth.min,
      border: TableBorder.all(),
      children: <TableRow>[
        TableRow(children: <Widget>[SizedBox(), SizedBox()]),
      ],
    ),
  ),
  'a decorated TableRow with no children': () => _page(
    Table(
      children: <TableRow>[
        TableRow(
          decoration: const BoxDecoration(color: PdfColors.grey),
          children: <Widget>[],
        ),
        TableRow(children: <Widget>[Text('a'), Text('b')]),
      ],
    ),
  ),
  'a Table squeezed below its longest word': () => _page(
    SizedBox(
      width: 60,
      child: Table(
        border: TableBorder.all(),
        children: <TableRow>[
          TableRow(
            children: <Widget>[Text('ATLANTICA'), Text('MEDITERRANEAN')],
          ),
        ],
      ),
    ),
  ),
  'a chart axis of one value': () => _page(
    Chart(
      grid: CartesianGrid(
        xAxis: FixedAxis<int>(<int>[3]),
        yAxis: FixedAxis<int>(<int>[7]),
      ),
      datasets: <Dataset>[
        LineDataSet(data: const <PointChartValue>[PointChartValue(3, 7)]),
      ],
    ),
  ),
  'a chart axis of equal values': () => _page(
    Chart(
      grid: CartesianGrid(
        xAxis: FixedAxis<int>(<int>[5, 5, 5]),
        yAxis: FixedAxis<int>(<int>[2, 2]),
      ),
      datasets: <Dataset>[
        BarDataSet(data: const <PointChartValue>[PointChartValue(5, 2)]),
      ],
    ),
  ),
  'a chart axis of no values': () => _page(
    Chart(
      grid: CartesianGrid(
        xAxis: FixedAxis<int>(<int>[]),
        yAxis: FixedAxis<int>(<int>[]),
      ),
      datasets: <Dataset>[LineDataSet(data: const <PointChartValue>[])],
    ),
  ),
  'a pie chart of one slice': () => _page(
    SizedBox(
      width: 200,
      height: 200,
      child: Chart(
        grid: PieGrid(),
        datasets: <Dataset>[PieDataSet(value: 37.5, color: PdfColors.blue)],
      ),
    ),
  ),
  'a pie chart of nothing but zeroes': () => _page(
    SizedBox(
      width: 200,
      height: 200,
      child: Chart(
        grid: PieGrid(),
        datasets: <Dataset>[
          PieDataSet(value: 0, color: PdfColors.blue),
          PieDataSet(value: 0, color: PdfColors.red),
        ],
      ),
    ),
  ),
  'text at font size zero': () => _page(
    Column(
      children: <Widget>[
        Text('zero', style: const TextStyle(fontSize: 0)),
        RichText(
          text: const TextSpan(
            text: 'zero',
            style: TextStyle(fontSize: 0, letterSpacing: 2, wordSpacing: 3),
          ),
        ),
      ],
    ),
  ),
  'an image with no area': () => _page(
    Image(RawImage(bytes: _pixel, width: 1, height: 1), width: 0, height: 20),
  ),
  'a gradient of one colour on a circle': () => _page(
    Container(
      width: 100,
      height: 100,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: <PdfColor>[PdfColors.red]),
      ),
    ),
  ),
  'a gradient of no colours': () => _page(
    Column(
      children: <Widget>[
        Container(
          width: 100,
          height: 50,
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: <PdfColor>[]),
          ),
        ),
        Container(width: 10, height: 10, color: black),
      ],
    ),
  ),
  'a gradient of three stops': () => _page(
    Container(
      width: 100,
      height: 50,
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          colors: <PdfColor>[PdfColors.red, PdfColors.green, PdfColors.blue],
          stops: <double>[0, 0.3, 1],
        ),
      ),
    ),
  ),
  'an arc whose radii are too small': () {
    final document = PdfDocument(compress: false);
    final page = PdfPage(document, pageFormat: PdfPageFormat.a4);
    page.getGraphics()
      ..moveTo(100, 400)
      ..bezierArc(100, 400, 10, 10, 200, 400, sweep: true)
      ..bezierArc(200, 400, 50, 50, 100, 400, large: true)
      ..strokePath();
    return document.save();
  },
  'an annotation appearance stream': () => _page(
    Column(
      children: <Widget>[
        Checkbox(name: 'check', value: true),
        TextField(name: 'field', width: 100, height: 20),
      ],
    ),
  ),
  'a whitespace-only paragraph': () =>
      _page(Column(children: <Widget>[Text('   '), Text(''), Text('after')])),
};

const black = PdfColors.black;

final _pixel = Uint8List.fromList(<int>[0xff, 0x00, 0x00, 0xff]);

Future<Uint8List> _page(Widget child) {
  final document = Document(compress: false);
  document.addPage(
    Page(pageFormat: PdfPageFormat.a4, build: (Context context) => child),
  );
  return document.save();
}

/// The streams that hold PDF operators. A content stream written uncompressed is
/// printable ASCII throughout; font programs and image samples are not, and
/// their bytes are no more meaningful as tokens than as text.
List<String> contentStreams(List<int> bytes) {
  final found = <String>[];
  const start = <int>[115, 116, 114, 101, 97, 109]; // 'stream'
  for (var i = 0; i + start.length < bytes.length; i++) {
    var hit = true;
    for (var j = 0; j < start.length; j++) {
      if (bytes[i + j] != start[j]) {
        hit = false;
        break;
      }
    }
    if (!hit || (i > 0 && bytes[i - 1] == 100)) {
      continue; // 'endstream'
    }

    var end = i + start.length;
    while (end < bytes.length) {
      if (bytes[end] == 101 &&
          end + 9 <= bytes.length &&
          String.fromCharCodes(bytes.sublist(end, end + 9)) == 'endstream') {
        break;
      }
      end++;
    }

    final body = bytes.sublist(i + start.length, end);
    if (body.every(
      (int b) => b == 9 || b == 10 || b == 13 || (b >= 32 && b < 127),
    )) {
      found.add(String.fromCharCodes(body));
    }
    i = end;
  }
  return found;
}

void main() {
  setUpAll(() {
    Document.debug = true;
    RichText.debug = true;
  });

  group('no number a reader cannot parse', () {
    // A viewer that meets NaN, Infinity or 1e+21 in a content stream drops the
    // whole stream, so the page comes out blank with no error anywhere. These are
    // every input in this milestone that used to produce one.
    for (final entry in corpus.entries) {
      test('from ${entry.key}', () async {
        final bytes = await entry.value();
        final streams = contentStreams(bytes);

        expect(streams, isNotEmpty, reason: 'nothing was drawn');

        for (final stream in streams) {
          for (final token in stream.split(RegExp(r'\s+'))) {
            expect(token, isNot('NaN'));
            expect(token, isNot('nan'));
            expect(token, isNot('Infinity'));
            expect(token, isNot('-Infinity'));
            expect(
              token,
              isNot(matches(RegExp(r'^[-+]?[\d.]+[eE][-+]?\d+$'))),
              reason: 'exponent notation is not PDF number syntax',
            );
          }
        }
      });
    }
  });

  group('every rectangle', () {
    // /BBox and /Rect are [llx lly urx ury] - lower left then upper right - and
    // the writers and the reader used to disagree about which.
    for (final entry in corpus.entries) {
      test('in ${entry.key} runs lower left to upper right', () async {
        final pdf = String.fromCharCodes(await entry.value());
        var found = 0;

        for (final m in RegExp(
          r'/(?:BBox|Rect|MediaBox|CropBox)\s*\[([-\d.\s]+)\]',
        ).allMatches(pdf)) {
          final v = m
              .group(1)!
              .trim()
              .split(RegExp(r'\s+'))
              .map(double.parse)
              .toList();
          expect(v, hasLength(4), reason: m.group(0));
          expect(v[0], lessThanOrEqualTo(v[2]), reason: m.group(0));
          expect(v[1], lessThanOrEqualTo(v[3]), reason: m.group(0));
          for (final n in v) {
            expect(n.isFinite, isTrue, reason: m.group(0));
          }
          found++;
        }

        expect(found, greaterThan(0), reason: 'the page /MediaBox at least');
      });
    }
  });
}
