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
import 'package:pdf/widgets.dart';
import 'package:test/test.dart';

/// The page content of a 100-unit SVG holding [body].
Future<String> render(String body) async {
  final document = Document(compress: false);
  document.addPage(
    Page(
      pageFormat: const PdfPageFormat(100, 100, marginAll: 0),
      build: (Context context) => SvgImage(
        svg:
            '<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">'
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

/// A clipPath definition plus the element it clips.
String clipped(
  String clipAttributes,
  String clipBody, {
  String element =
      '<rect width="100" height="100" fill="#ff0000" '
      'clip-path="url(#c)"/>',
}) =>
    '<defs><clipPath id="c"$clipAttributes>$clipBody</clipPath></defs>$element';

void main() {
  group('a clipPath in objectBoundingBox units', () {
    test('clips the same region as the user-space equivalent', () async {
      // The referenced clipPath's clipPathUnits was never read, so fractions of
      // the bounding box went out as user units and clipped the artwork to about
      // a one-unit sliver - the content disappeared with no error.
      final fractions = await render(
        clipped(
          ' clipPathUnits="objectBoundingBox"',
          '<rect width="0.5" height="1"/>',
        ),
      );
      final units = await render(
        clipped('', '<rect width="50" height="100"/>'),
      );

      // The fractional path is scaled by the box, so it covers the same half.
      expect(fractions, contains('100 0 0 100 0 0 cm'));
      expect(fractions, contains('0 0 m 0.5 0 l 0.5 1 l'));
      expect(units, contains('0 0 m 50 0 l 50 100 l'));
      expect(units, isNot(contains(' cm q 0 0 m')));
    });

    test('scales and offsets by the box it clips', () async {
      final content = await render(
        clipped(
          ' clipPathUnits="objectBoundingBox"',
          '<rect width="0.5" height="1"/>',
          element:
              '<rect x="20" y="30" width="60" height="40" fill="#ff0000" '
              'clip-path="url(#c)"/>',
        ),
      );

      expect(content, contains('60 0 0 40 20 30 cm'));
    });

    test('clips everything away for an empty box', () async {
      // An empty group's bounding box comes back as infinities.
      final content = await render(
        clipped(
          ' clipPathUnits="objectBoundingBox"',
          '<rect width="0.5" height="1"/>',
          element: '<g clip-path="url(#c)"></g>',
        ),
      );

      expect(content, isNot(contains('NaN')));
      expect(content, isNot(contains('Infinity')));
    });
  });

  group('clip-rule', () {
    test('emits the even-odd operator when asked', () async {
      for (final attributes in <String>[
        ' clip-rule="evenodd"',
        ' style="clip-rule:evenodd"',
      ]) {
        final content = await render(
          clipped(attributes, '<rect width="50" height="100"/>'),
        );

        expect(content, contains('W* n'), reason: attributes);
      }
    });

    test('emits the nonzero operator otherwise', () async {
      for (final attributes in <String>['', ' clip-rule="nonzero"']) {
        final content = await render(
          clipped(attributes, '<rect width="50" height="100"/>'),
        );

        expect(content, contains('W n'), reason: attributes);
        expect(content, isNot(contains('W* n')), reason: attributes);
      }
    });
  });

  test('a userSpaceOnUse clip is unchanged', () async {
    for (final attributes in <String>['', ' clipPathUnits="userSpaceOnUse"']) {
      final content = await render(
        clipped(attributes, '<rect width="50" height="100"/>'),
      );

      expect(
        content,
        contains('q 0 0 m 50 0 l 50 100 l 0 100 l 0 0 l h Q W n'),
        reason: attributes,
      );
    }
  });

  test('a clip-path to a missing id means no clip', () async {
    final content = await render(
      '<rect width="100" height="100" fill="#ff0000" clip-path="url(#nope)"/>',
    );

    expect(content, contains('1 0 0 rg'));
    expect(RegExp(r' W\*? n').allMatches(content), hasLength(1));
  });
}
