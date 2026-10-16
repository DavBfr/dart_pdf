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
import 'package:pdf/src/svg/viewbox.dart';
import 'package:pdf/widgets.dart';
import 'package:test/test.dart';

/// The page content of a 24-unit SVG holding [body].
Future<String> render(String body) async {
  final document = Document(compress: false);
  document.addPage(
    Page(
      pageFormat: const PdfPageFormat(240, 240, marginAll: 0),
      build: (Context context) => SvgImage(
        svg:
            '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg" '
            'xmlns:xlink="http://www.w3.org/1999/xlink">$body</svg>',
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

void main() {
  group('the viewBox fit', () {
    const viewport = PdfRect(0, 0, 24, 24);

    test('scales uniformly and centres by default', () {
      final matrix = svgViewBoxTransform(
        const PdfRect(0, 0, 50, 100),
        viewport,
        const SvgPreserveAspectRatio(),
      );

      // meet: the smaller scale, so the whole box is visible.
      expect(matrix.entry(0, 0), closeTo(0.24, 1e-9));
      expect(matrix.entry(1, 1), closeTo(0.24, 1e-9));
      // And the slack goes half each side.
      expect(matrix.entry(0, 3), closeTo(6, 1e-9));
      expect(matrix.entry(1, 3), closeTo(0, 1e-9));
    });

    test('stretches when asked to', () {
      final matrix = svgViewBoxTransform(
        const PdfRect(0, 0, 50, 100),
        viewport,
        SvgPreserveAspectRatio.fromString('none'),
      );

      expect(matrix.entry(0, 0), closeTo(0.48, 1e-9));
      expect(matrix.entry(1, 1), closeTo(0.24, 1e-9));
    });

    test('covers the viewport for slice', () {
      final matrix = svgViewBoxTransform(
        const PdfRect(0, 0, 50, 100),
        viewport,
        SvgPreserveAspectRatio.fromString('xMidYMid slice'),
      );

      expect(matrix.entry(0, 0), closeTo(0.48, 1e-9));
      expect(matrix.entry(1, 1), closeTo(0.48, 1e-9));
    });

    test('honours the alignment keyword', () {
      for (final entry in <String, double>{
        'xMinYMid meet': 0,
        'xMidYMid meet': 6,
        'xMaxYMid meet': 12,
      }.entries) {
        final matrix = svgViewBoxTransform(
          const PdfRect(0, 0, 50, 100),
          viewport,
          SvgPreserveAspectRatio.fromString(entry.key),
        );
        expect(
          matrix.entry(0, 3),
          closeTo(entry.value, 1e-9),
          reason: entry.key,
        );
      }
    });

    test('takes a viewBox origin into account', () {
      final matrix = svgViewBoxTransform(
        const PdfRect(10, 20, 24, 24),
        viewport,
        const SvgPreserveAspectRatio(),
      );

      expect(matrix.entry(0, 0), closeTo(1, 1e-9));
      expect(matrix.entry(0, 3), closeTo(-10, 1e-9));
      expect(matrix.entry(1, 3), closeTo(-20, 1e-9));
    });

    test('does nothing with an empty viewBox', () {
      final matrix = svgViewBoxTransform(
        const PdfRect(0, 0, 0, 10),
        viewport,
        const SvgPreserveAspectRatio(),
      );

      expect(matrix.entry(0, 0), 1);
      expect(matrix.entry(1, 1), 1);
    });

    test('falls back to the default for an unrecognised value', () {
      for (final value in <String?>[null, '', 'nonsense', 'defer']) {
        final ratio = SvgPreserveAspectRatio.fromString(value);
        expect(ratio.alignX, 0.5, reason: '$value');
        expect(ratio.alignY, 0.5, reason: '$value');
        expect(ratio.scale, SvgViewBoxScale.meet, reason: '$value');
      }
    });
  });

  group('a symbol used through <use>', () {
    test('is fitted into the use viewport', () async {
      // SvgSymbol never read viewBox or preserveAspectRatio, and SvgUse parsed
      // width and height into dead fields - paintShape applied a translation and
      // nothing else - so a 100-unit symbol drew at 100 units wherever it was
      // used and was mostly clipped away.
      final content = await render(
        '<symbol id="s" viewBox="0 0 100 100">'
        '<rect width="100" height="100" fill="#ff0000"/></symbol>'
        '<use href="#s" width="24" height="24"/>',
      );

      expect(content, contains('0 0 24 24 re W n'));
      expect(content, contains('0.24 0 0 0.24 0 0 cm'));
      expect(content, contains('0 0 m 100 0 l'));
    });

    test('is placed at the x and y it was given', () async {
      final content = await render(
        '<symbol id="s" viewBox="0 0 100 100">'
        '<rect width="100" height="100" fill="#ff0000"/></symbol>'
        '<use href="#s" x="2" y="2" width="20" height="20"/>',
      );

      expect(content, contains('2 2 20 20 re W n'));
      expect(content, contains('0.2 0 0 0.2 2 2 cm'));
    });

    test('is scaled uniformly, stretched or sliced as asked', () async {
      final expected = <String, String>{
        '': '0.24 0 0 0.24 6 0 cm',
        ' preserveAspectRatio="none"': '0.48 0 0 0.24 0 0 cm',
        ' preserveAspectRatio="xMidYMid slice"': '0.48 0 0 0.48 0 -12 cm',
      };

      for (final entry in expected.entries) {
        final content = await render(
          '<symbol id="s" viewBox="0 0 50 100"${entry.key}>'
          '<rect width="50" height="100" fill="#ff0000"/></symbol>'
          '<use href="#s" width="24" height="24"/>',
        );

        expect(content, contains(entry.value), reason: entry.key);
        expect(content, contains('0 0 24 24 re W n'), reason: entry.key);
      }
    });

    test('with no viewBox is clipped but never scaled', () async {
      final content = await render(
        '<symbol id="s"><rect width="100" height="100" fill="#ff0000"/>'
        '</symbol><use href="#s" width="24" height="24"/>',
      );

      expect(content, contains('0 0 24 24 re W n'));
      expect(content, isNot(contains(' 0 0 cm')));
      expect(content, contains('0 0 m 100 0 l'));
    });

    test('without width or height uses the current viewport', () async {
      final content = await render(
        '<symbol id="s" viewBox="0 0 48 48">'
        '<rect width="48" height="48" fill="#ff0000"/></symbol>'
        '<use href="#s"/>',
      );

      // The 24-unit root viewport, so a 48-unit box halves.
      expect(content, contains('0 0 24 24 re W n'));
      expect(content, contains('0.5 0 0 0.5 0 0 cm'));
    });

    test('with a zero width renders nothing', () async {
      final content = await render(
        '<symbol id="s" viewBox="0 0 100 100">'
        '<rect width="100" height="100" fill="#ff0000"/></symbol>'
        '<use href="#s" width="0" height="20"/>',
      );

      expect(content, isNot(contains('1 0 0 rg')));
    });

    test('of a plain group is only translated, as before', () async {
      final content = await render(
        '<g id="g"><rect width="4" height="4" fill="#0000ff"/></g>'
        '<use href="#g" x="5" y="5" width="20" height="20"/>',
      );

      expect(content, contains('1 0 0 1 5 5 cm'));
      expect(content, isNot(contains('re W n 0')));
    });
  });

  group('a nested <svg>', () {
    test('renders at all', () async {
      // SvgOperation.fromXml had no 'svg' case, so the element fell through to
      // return null and SvgGroup dropped it: the subtree vanished with no error,
      // and a document holding only that had no /Contents entry at all.
      final content = await render(
        '<svg width="24" height="24">'
        '<path d="M0 0 H24 V24 H0 Z" fill="#ff0000"/></svg>',
      );

      expect(content, contains('1 0 0 rg'));
      expect(content, contains(' f '));
    });

    test('offsets by its x and y', () async {
      final content = await render(
        '<svg x="8" y="8" width="8" height="8" viewBox="0 0 8 8">'
        '<rect width="8" height="8" fill="#ff0000"/></svg>',
      );

      expect(content, contains('8 8 8 8 re W n'));
      expect(content, contains('1 0 0 1 8 8 cm'));
    });

    test('scales its viewBox into its viewport', () async {
      final content = await render(
        '<svg width="24" height="24" viewBox="0 0 12 12">'
        '<rect width="12" height="12" fill="#ff0000"/></svg>',
      );

      expect(content, contains('2 0 0 2 0 0 cm'));
    });

    test('centres rather than stretching a mismatched viewport', () async {
      final content = await render(
        '<svg width="24" height="12" viewBox="0 0 12 12">'
        '<rect width="12" height="12" fill="#ff0000"/></svg>',
      );

      // Uniform scale 1, and the horizontal slack split in two.
      expect(content, contains('0 0 24 12 re W n'));
      expect(content, contains('1 0 0 1 6 0 cm'));
    });

    test('clips before it transforms', () async {
      final content = await render(
        '<svg width="24" height="24" viewBox="0 0 12 12">'
        '<rect width="12" height="12" fill="#ff0000"/></svg>',
      );

      expect(
        content.indexOf('0 0 24 24 re W n'),
        lessThan(content.indexOf('2 0 0 2 0 0 cm')),
      );
    });

    test('without a size uses the parent viewport', () async {
      final content = await render(
        '<svg viewBox="0 0 48 48">'
        '<rect width="48" height="48" fill="#ff0000"/></svg>',
      );

      expect(content, contains('0 0 24 24 re W n'));
      expect(content, contains('0.5 0 0 0.5 0 0 cm'));
    });

    test('is still pruned by display="none"', () async {
      final content = await render(
        '<svg width="24" height="24" display="none">'
        '<rect width="24" height="24" fill="#ff0000"/></svg>',
      );

      expect(content, isNot(contains('1 0 0 rg')));
    });

    test('renders inside a symbol', () async {
      final content = await render(
        '<symbol id="s" viewBox="0 0 10 10">'
        '<svg width="10" height="10">'
        '<rect width="10" height="10" fill="#ff0000"/></svg></symbol>'
        '<use href="#s" width="24" height="24"/>',
      );

      expect(content, contains('2.4 0 0 2.4 0 0 cm'));
      expect(content, contains('1 0 0 rg'));
    });

    test('resolves percentages against its own viewport', () async {
      final content = await render(
        '<svg width="12" height="12" viewBox="0 0 100 100">'
        '<rect width="50%" height="50%" fill="#ff0000"/></svg>',
      );

      // 50% of the nested viewBox, not of the root's 24 units.
      expect(content, contains('0 0 m 50 0 l 50 50 l 0 50 l'));
    });
  });
}
