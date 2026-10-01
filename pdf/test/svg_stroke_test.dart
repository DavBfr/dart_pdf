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

import 'package:pdf/pdf.dart';
import 'package:pdf/src/svg/transform.dart';
import 'package:pdf/widgets.dart';
import 'package:test/test.dart';

/// The page content of a 24-unit SVG holding [body].
Future<String> render(String body) async {
  final document = Document(compress: false);
  document.addPage(
    Page(
      pageFormat: const PdfPageFormat(100, 100, marginAll: 0),
      build: (Context context) => SvgImage(
        svg:
            '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
            '$body</svg>',
      ),
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

const corner = 'M2 2 L12 12 L22 2';

void main() {
  group('stroke-linejoin', () {
    test('miter wins over an inherited round', () async {
      // The lookup table keyed miter with a trailing space, so the attribute
      // never matched - and a null lookup is indistinguishable from 'not
      // specified', so the shape inherited the ancestor's join instead.
      final content = await render(
        '<g stroke-linejoin="round"><path d="$corner" stroke="#000000" '
        'stroke-linejoin="miter" fill="none"/></g>',
      );

      expect(content, contains(' 0 j '));
      expect(content, isNot(contains(' 1 j ')));
    });

    test('still inherits when nothing is declared', () async {
      final content = await render(
        '<g stroke-linejoin="round"><path d="$corner" stroke="#000000" '
        'fill="none"/></g>',
      );

      expect(content, contains(' 1 j '));
    });

    test('maps round and bevel as before', () async {
      for (final entry in <String, String>{
        'round': ' 1 j ',
        'bevel': ' 2 j ',
        'miter': ' 0 j ',
      }.entries) {
        final content = await render(
          '<path d="$corner" stroke="#000000" '
          'stroke-linejoin="${entry.key}" fill="none"/>',
        );

        expect(content, contains(entry.value), reason: entry.key);
      }
    });

    test('tolerates surrounding whitespace', () async {
      final content = await render(
        '<g stroke-linejoin="round"><path d="$corner" stroke="#000000" '
        'stroke-linejoin=" miter " fill="none"/></g>',
      );

      expect(content, contains(' 0 j '));
    });

    test('still inherits for an unrecognised value', () async {
      final content = await render(
        '<g stroke-linejoin="round"><path d="$corner" stroke="#000000" '
        'stroke-linejoin="wibble" fill="none"/></g>',
      );

      expect(content, contains(' 1 j '));
    });

    test('maps the SVG 2 keywords to a miter', () async {
      for (final value in <String>['miter-clip', 'arcs']) {
        final content = await render(
          '<g stroke-linejoin="round"><path d="$corner" stroke="#000000" '
          'stroke-linejoin="$value" fill="none"/></g>',
        );

        expect(content, contains(' 0 j '), reason: value);
      }
    });
  });

  group('a zero stroke-width', () {
    test('paints no stroke at all', () async {
      // PDF reads '0 w' as the thinnest line the device can draw; SVG reads
      // stroke-width:0 as 'do not paint the stroke'. The block was entered on the
      // colour alone, so a hairline went out that no browser draws.
      for (final attributes in <String>[
        'stroke="#000000" stroke-width="0"',
        'style="stroke:#000000;stroke-width:0"',
        'stroke="#000000" stroke-width="-1"',
      ]) {
        final content = await render(
          '<path d="M2 2 h20" $attributes fill="none"/>',
        );

        expect(content, isNot(contains(' S ')), reason: attributes);
        expect(content, isNot(contains(' w ')), reason: attributes);
        expect(content, isNot(contains(' RG ')), reason: attributes);
      }
    });

    test('leaves the fill alone', () async {
      final content = await render(
        '<path d="M2 2 h20 v20 h-20 Z" fill="#ff0000" stroke="#000000" '
        'stroke-width="0"/>',
      );

      expect(content, contains('1 0 0 rg'));
      expect(content, contains(' f '));
      expect(content, isNot(contains(' S ')));
    });

    test('does not change a real stroke', () async {
      for (final attributes in <String>[
        'stroke="#000000" stroke-width="1"',
        'stroke="#000000"',
      ]) {
        final content = await render(
          '<path d="M2 2 h20" $attributes fill="none"/>',
        );

        expect(content, contains(' 1 w '), reason: attributes);
        expect(content, contains(' S '), reason: attributes);
      }
    });

    test('paints no stroked text', () async {
      final content = await render(
        '<text x="2" y="12" fill="none" stroke="#000000" '
        'stroke-width="0">Hi</text>',
      );

      expect(content, isNot(contains('1 Tr')));
      expect(content, isNot(contains(' S ')));
    });
  });

  group('a malformed transform', () {
    /// The determinant of the 2x2 part: zero means a collapsed matrix.
    double determinant(String transform) {
      final m = SvgTransform.fromString(transform).matrix!;
      return m.entry(0, 0) * m.entry(1, 1) - m.entry(0, 1) * m.entry(1, 0);
    }

    bool isIdentity(String transform) {
      final m = SvgTransform.fromString(transform).matrix!;
      return m.entry(0, 0) == 1 &&
          m.entry(1, 1) == 1 &&
          m.entry(0, 1) == 0 &&
          m.entry(1, 0) == 0 &&
          m.entry(0, 3) == 0 &&
          m.entry(1, 3) == 0;
    }

    test('with no arguments is ignored', () {
      // matrix() with seven arguments handed List.filled a negative length and
      // threw a RangeError out of pdf.save(); with fewer it was zero-padded into
      // a singular matrix. The others indexed parameterList[0] unguarded.
      for (final transform in <String>[
        'translate()',
        'scale()',
        'rotate()',
        'skewX()',
        'skewY()',
        'matrix()',
      ]) {
        expect(isIdentity(transform), isTrue, reason: transform);
      }
    });

    test('with the wrong argument count is ignored', () {
      for (final transform in <String>[
        'matrix(1,0,0,1,0,0,0)',
        'matrix(1,0,0)',
        'rotate(45,10)',
        'translate(1,2,3)',
        'skewX(1,2)',
      ]) {
        expect(isIdentity(transform), isTrue, reason: transform);
        expect(determinant(transform), isNot(0), reason: transform);
      }
    });

    test('with a non-numeric argument is ignored', () {
      for (final transform in <String>[
        'translate(a,b)',
        'scale(x)',
        'matrix(1,0,0,1,0,q)',
      ]) {
        expect(isIdentity(transform), isTrue, reason: transform);
      }
    });

    test('does not take its valid neighbours with it', () {
      final m = SvgTransform.fromString('translate(10,10) scale()').matrix!;

      expect(m.entry(0, 3), 10);
      expect(m.entry(1, 3), 10);
      expect(m.entry(0, 0), 1);
    });

    test('leaves every valid list exactly as it was', () {
      final expected = <String, List<double>>{
        'translate(10,10)': <double>[1, 0, 0, 1, 10, 10],
        'scale(2)': <double>[2, 0, 0, 2, 0, 0],
        'scale(2,3)': <double>[2, 0, 0, 3, 0, 0],
        'matrix(1,0,0,1,5,5)': <double>[1, 0, 0, 1, 5, 5],
        'translate(10 10)': <double>[1, 0, 0, 1, 10, 10],
      };

      expected.forEach((String transform, List<double> want) {
        final m = SvgTransform.fromString(transform).matrix!;
        expect(
          <double>[
            m.entry(0, 0),
            m.entry(1, 0),
            m.entry(0, 1),
            m.entry(1, 1),
            m.entry(0, 3),
            m.entry(1, 3),
          ],
          want,
          reason: transform,
        );
      });
    });

    test('does not stop the document, on a shape or a gradient', () async {
      for (final transform in <String>[
        'translate()',
        'matrix(1,0,0,1,0,0,0)',
        'translate(a,b)',
      ]) {
        expect(
          await render(
            '<rect width="24" height="24" fill="#ff0000" '
            'transform="$transform"/>',
          ),
          isNot('(no content stream)'),
          reason: 'shape $transform',
        );

        expect(
          await render(
            '<defs><linearGradient id="g" gradientTransform="$transform">'
            '<stop offset="0" stop-color="#ff0000"/>'
            '<stop offset="1" stop-color="#0000ff"/></linearGradient></defs>'
            '<rect width="24" height="24" fill="url(#g)"/>',
          ),
          isNot('(no content stream)'),
          reason: 'gradient $transform',
        );
      }
    });
  });
}
