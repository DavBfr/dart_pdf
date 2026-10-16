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

/// Lay [child] out on an A4 page and return the raw PDF.
Future<String> build(Widget child) async {
  final document = Document(compress: false);
  document.addPage(
    Page(pageFormat: PdfPageFormat.a4, build: (Context context) => child),
  );
  return String.fromCharCodes(await document.save());
}

/// The width and height of every `re` rectangle in [pdf].
List<List<double>> rects(String pdf) =>
    RegExp(r'[-\d.]+ [-\d.]+ ([-\d.]+) ([-\d.]+) re')
        .allMatches(pdf)
        .map(
          (RegExpMatch m) => <double>[
            double.parse(m.group(1)!),
            double.parse(m.group(2)!),
          ],
        )
        .toList();

void main() {
  group('a progress indicator with no width to fill', () {
    test('says so instead of writing Infinity', () async {
      // LinearProgressIndicator used minWidth: double.infinity as an 'as wide as
      // possible' sentinel, and BoxConstraints.enforce keeps that infinity when
      // the incoming maxWidth is unbounded - which is what a non-flex child of a
      // Row is given. The stream carried 'Infinity 4.936 Infinity 4 re'.
      await expectLater(
        build(
          Row(
            children: <Widget>[Text('x'), LinearProgressIndicator(value: .5)],
          ),
        ),
        throwsA(
          isA<PdfException>().having(
            (PdfException e) => e.message,
            'message',
            allOf(
              contains('LinearProgressIndicator'),
              contains('fallbackWidth'),
            ),
          ),
        ),
      );

      // The circular one reached .ceil() with an infinite radius and threw
      // 'Unsupported operation: Infinity or NaN toInt', naming no widget.
      await expectLater(
        build(Row(children: <Widget>[CircularProgressIndicator(value: .5)])),
        throwsA(
          isA<PdfException>().having(
            (PdfException e) => e.message,
            'message',
            contains('CircularProgressIndicator'),
          ),
        ),
      );
    });

    test('takes its fallback size when it has one', () async {
      final linear = await build(
        Row(
          children: <Widget>[
            LinearProgressIndicator(value: .5, fallbackWidth: 50),
          ],
        ),
      );
      expect(linear, isNot(contains('Infinity')));
      expect(linear, isNot(contains('NaN')));
      expect(
        rects(linear).map((List<double> r) => r.first).reduce((a, b) => a + b),
        closeTo(50, 0.02),
      );

      final circular = await build(
        Row(
          children: <Widget>[
            CircularProgressIndicator(
              value: .5,
              fallbackWidth: 20,
              fallbackHeight: 20,
            ),
          ],
        ),
      );
      expect(circular, isNot(contains('Infinity')));
      expect(circular, isNot(contains('NaN')));
    });
  });

  group('a progress indicator in a bounded parent', () {
    test('fills the width it was given', () async {
      final half = await build(
        SizedBox(width: 200, child: LinearProgressIndicator(value: .5)),
      );
      final bars = rects(half);
      expect(bars, hasLength(2), reason: 'the value and the remainder');
      expect(
        bars.map((List<double> r) => r.first).reduce((a, b) => a + b),
        closeTo(200, 0.02),
      );
      for (final bar in bars) {
        expect(bar.last, 4, reason: 'the default height');
      }

      for (final value in <double>[0, 1]) {
        final full = await build(
          SizedBox(width: 200, child: LinearProgressIndicator(value: value)),
        );
        expect(rects(full), <List<double>>[
          <double>[200, 4],
        ], reason: 'value $value is one rectangle');
      }
    });

    test('a circular one saves', () async {
      final pdf = await build(
        SizedBox(
          width: 40,
          height: 40,
          child: CircularProgressIndicator(value: .5),
        ),
      );

      expect(pdf, isNot(contains('Infinity')));
      expect(pdf, isNot(contains('NaN')));
    });
  });
}
