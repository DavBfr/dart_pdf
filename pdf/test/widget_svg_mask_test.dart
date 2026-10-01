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

/// Save a document holding [svg] and hand back its bytes as text.
Future<String> save(String svg, {PdfPageFormat? format}) async {
  final document = Document(compress: false);
  document.addPage(
    Page(
      pageFormat: format ?? const PdfPageFormat(300, 300, marginAll: 0),
      build: (Context context) => SvgImage(svg: svg),
    ),
  );
  return latin1.decode(await document.save(), allowInvalid: true);
}

/// The /BBox of every Form XObject in [pdf], as four numbers.
List<List<double>> formBoxes(String pdf) => RegExp(r'/BBox\[([^\]]*)\]')
    .allMatches(pdf)
    .map(
      (m) =>
          m.group(1)!.trim().split(RegExp(r'\s+')).map(double.parse).toList(),
    )
    .toList();

/// The page's content stream.
String content(String pdf) {
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

String masked(String viewBox, String geometry) =>
    '''
<svg viewBox="$viewBox" xmlns="http://www.w3.org/2000/svg">
  <mask id="m"><rect $geometry fill="#ffffff"/></mask>
  <rect $geometry fill="#ff0000" mask="url(#m)"/>
</svg>''';

void main() {
  group('a soft mask', () {
    test('gets a /BBox in the space its stream is drawn in', () async {
      // painter.boundingBox is in page points, and the mask's Form XObject is
      // evaluated under the SVG user-space CTM - so the mask was clipped to the
      // first 300x300 *user units* of a 1024-unit drawing. Everything else fell
      // into the /Luminosity black backdrop at alpha 0 and vanished.
      final pdf = await save(
        masked('0 0 1024 1024', 'width="1024" height="1024"'),
      );

      expect(formBoxes(pdf), isNotEmpty);
      final box = formBoxes(pdf).first;
      expect(box[2], greaterThanOrEqualTo(1024));
      expect(box[3], greaterThanOrEqualTo(1024));
    });

    test('covers a negative viewBox origin', () async {
      final pdf = await save(
        masked('-12 -12 24 24', 'x="-12" y="-12" width="24" height="24"'),
      );

      final box = formBoxes(pdf).first;
      expect(box[0], lessThanOrEqualTo(-12));
      expect(box[1], lessThanOrEqualTo(-12));
    });

    test('covers an offset viewBox origin', () async {
      final pdf = await save(
        masked('100 100 24 24', 'x="100" y="100" width="24" height="24"'),
      );

      final box = formBoxes(pdf).first;
      expect(box[0], lessThanOrEqualTo(100));
      expect(box[2], greaterThanOrEqualTo(124));
    });

    test('does not depend on the page size', () async {
      final small = await save(
        masked('0 0 1024 1024', 'width="1024" height="1024"'),
      );
      final a4 = await save(
        masked('0 0 1024 1024', 'width="1024" height="1024"'),
        format: PdfPageFormat.a4,
      );

      // Both cover the whole drawing, whatever the page is.
      for (final pdf in <String>[small, a4]) {
        final box = formBoxes(pdf).first;
        expect(box[2], greaterThanOrEqualTo(1024));
        expect(box[3], greaterThanOrEqualTo(1024));
      }
    });

    test('leaves the mask stream free of a transform', () async {
      final pdf = await save(
        masked('0 0 1024 1024', 'width="1024" height="1024"'),
      );

      // The form is evaluated under the CTM already; setting it again inside
      // would apply it twice.
      final mask = RegExp(
        r'/Subtype/Form.*?stream(.*?)endstream',
        dotAll: true,
      ).firstMatch(pdf)!.group(1)!;
      expect(mask, isNot(contains(' cm')));
    });

    test('an opaque one changes nothing but the graphic state', () async {
      final unmasked = content(
        await save(
          '<svg viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg">'
          '<rect width="1024" height="1024" fill="#ff0000"/></svg>',
        ),
      );
      final withMask = content(
        await save(masked('0 0 1024 1024', 'width="1024" height="1024"')),
      );

      // The same path and the same fill, plus one gs token.
      expect(withMask, contains('1 0 0 rg'));
      expect(withMask, contains('0 0 m 1024 0 l'));
      expect(unmasked, contains('0 0 m 1024 0 l'));
      expect(RegExp(r'/\w+ gs').allMatches(withMask), hasLength(1));
    });
  });

  test('a gradient with stop-opacity gets a user-space mask too', () async {
    final pdf = await save('''
<svg viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg">
  <defs><linearGradient id="g">
    <stop offset="0" stop-color="#ff0000" stop-opacity="0.2"/>
    <stop offset="1" stop-color="#0000ff" stop-opacity="1"/>
  </linearGradient></defs>
  <rect width="1024" height="1024" fill="url(#g)"/>
</svg>''');

    expect(formBoxes(pdf), isNotEmpty);
    final box = formBoxes(pdf).first;
    expect(box[2], greaterThanOrEqualTo(1024));
    expect(box[3], greaterThanOrEqualTo(1024));
  });
}
