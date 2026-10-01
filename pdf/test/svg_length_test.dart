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

import 'dart:convert';
import 'dart:math' as math;

import 'package:pdf/pdf.dart';
import 'package:pdf/src/svg/parser.dart';
import 'package:pdf/widgets.dart';
import 'package:test/test.dart';

/// The page content of a document holding [svg].
Future<String> render(String svg, {Widget Function(Widget)? wrap}) async {
  final document = Document(compress: false);
  final image = SvgImage(svg: svg);
  document.addPage(
    Page(
      pageFormat: const PdfPageFormat(240, 240, marginAll: 0),
      build: (Context context) => wrap == null ? image : wrap(image),
    ),
  );
  final pdf = latin1.decode(await document.save(), allowInvalid: true);
  for (final m in RegExp(
    r'stream(.*?)endstream',
    dotAll: true,
  ).allMatches(pdf)) {
    if (m.group(1)!.contains('0 Tr')) {
      return m.group(1)!.trim();
    }
  }
  return '(no content stream)';
}

String svg(String body, {String attributes = 'viewBox="0 0 24 24"'}) =>
    '<svg $attributes xmlns="http://www.w3.org/2000/svg">$body</svg>';

void main() {
  group('a percentage length', () {
    const viewport = PdfPoint(200, 100);

    test('is a fraction of the viewport, per axis', () {
      // SVG 1.1 7.10. sizeValue has no viewport to work from, so it divided by
      // 100 and gave a bare fraction: width="100%" came out as 1.0 point.
      final half = SvgNumeric('50%', null);

      expect(half.sizeIn(viewport, SvgAxis.horizontal), 100);
      expect(half.sizeIn(viewport, SvgAxis.vertical), 50);
      expect(
        half.sizeIn(viewport, SvgAxis.diagonal),
        closeTo(math.sqrt((200 * 200 + 100 * 100) / 2) / 2, 1e-9),
      );
    });

    test('with no viewport is still a bare fraction', () {
      // Which is what a gradient coordinate wants.
      expect(SvgNumeric('50%', null).sizeIn(null, SvgAxis.horizontal), 0.5);
      expect(SvgNumeric('50%', null).sizeValue, 0.5);
    });

    test('leaves absolute units alone', () {
      for (final entry in <String, double>{
        '12': 12,
        '12px': 12,
        '12pt': 12,
        '1mm': PdfPageFormat.mm,
        '1cm': PdfPageFormat.cm,
        '1in': PdfPageFormat.inch,
      }.entries) {
        for (final axis in SvgAxis.values) {
          expect(
            SvgNumeric(entry.key, null).sizeIn(viewport, axis),
            closeTo(entry.value, 1e-9),
            reason: '${entry.key} on $axis',
          );
        }
      }
    });
  });

  group('percentage geometry', () {
    test('sizes a rect against the viewBox', () async {
      final content = await render(
        svg('<rect width="50%" height="50%" fill="#ff0000"/>'),
      );

      // 50% of a 24x24 viewBox is 12x12.
      expect(content, contains('0 0 m 12 0 l 12 12 l 0 12 l'));
    });

    test('centres a circle and sizes its radius', () async {
      final content = await render(
        svg('<circle cx="50%" cy="50%" r="25%" fill="#ff0000"/>'),
      );

      // Centre (12,12), r = 25% of sqrt((24^2+24^2)/2) = 6.
      expect(content, contains('6 12 m'));
      expect(content, contains('18 12 c'));
    });

    test('sizes a stroke on the diagonal basis', () async {
      final content = await render(
        svg(
          '<line x1="0" y1="0" x2="24" y2="24" stroke="#ff0000" '
          'stroke-width="10%"/>',
        ),
      );

      expect(content, contains('2.4 w'));
    });
  });

  group('a percentage root size', () {
    const body = '<rect width="24" height="24" fill="#ff0000"/>';
    const attributes = 'width="100%" height="100%" viewBox="0 0 24 24"';

    test('fills the page it is given', () async {
      // The whole 240x240 page, scaled ten times, not a 1x1pt speck.
      final content = await render(svg(body, attributes: attributes));

      expect(content, contains('0 0 240 240 re W n'));
      expect(content, contains('10 0 -0 -10 0 240 cm'));
    });

    test('fills a box it is given', () async {
      final content = await render(
        svg(body, attributes: attributes),
        wrap: (Widget child) => SizedBox(width: 100, height: 100, child: child),
      );

      expect(content, contains('0 0 100 100 re W n'));
      expect(content, contains('4.16667 0 -0 -4.16667 0 100 cm'));
    });

    test('falls back to the viewBox when the box is unbounded', () async {
      final content = await render(
        svg(body, attributes: attributes),
        wrap: (Widget child) => Row(children: <Widget>[child]),
      );

      // 24 points, the viewBox size, at scale 1.
      expect(content, contains('0 0 24 24 re W n'));
      expect(content, contains('1 0 -0 -1 0 24 cm'));
    });

    test('an absolute root size is unchanged', () async {
      final content = await render(
        svg(body, attributes: 'width="48" height="48" viewBox="0 0 24 24"'),
      );

      // The clip box is wherever the widget landed; its size and scale are what
      // this is about.
      expect(content, matches(RegExp(r'0 \d+ 48 48 re W n')));
      expect(content, contains('2 0 -0 -2 0 240 cm'));
    });
  });

  test('a gradient still reads a percentage as a fraction', () async {
    // objectBoundingBox coordinates and stop offsets are fractions, not lengths.
    final content = await render(
      svg(
        '<defs><linearGradient id="g">'
        '<stop offset="50%" stop-color="#ff0000"/>'
        '<stop offset="100%" stop-color="#0000ff"/>'
        '</linearGradient></defs>'
        '<rect width="24" height="24" fill="url(#g)"/>',
      ),
    );

    expect(content, contains('/Pattern cs'));
    expect(content, contains(' scn '));
  });
}
