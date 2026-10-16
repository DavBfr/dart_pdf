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

/// The uncompressed page content of a document holding [svg].
Future<String> _render(String svg) async {
  final document = Document(compress: false);
  document.addPage(
    Page(
      pageFormat: const PdfPageFormat(100, 100, marginAll: 0),
      build: (Context context) => SvgImage(svg: svg),
    ),
  );
  return latin1.decode(await document.save(), allowInvalid: true);
}

void main() {
  test('fill="currentColor" resolves against the color property', () async {
    final text = await _render('''
<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
  <g color="#ff0000">
    <rect x="10" y="10" width="50" height="50" fill="currentColor"/>
  </g>
</svg>''');

    // A filled path and the red the keyword resolves to.
    expect(text, contains('1 0 0 rg'));
    expect(text, contains(' h f '), reason: 'the path is filled');
  });

  test('currentColor is inherited and case insensitive', () async {
    final text = await _render('''
<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
  <g color="rgb(0, 255, 0)">
    <g>
      <rect x="10" y="10" width="50" height="50" fill="currentcolor"/>
    </g>
  </g>
</svg>''');

    expect(text, contains('0 1 0 rg'));
  });

  test('currentColor without a color property paints black', () async {
    final text = await _render('''
<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
  <rect x="10" y="10" width="50" height="50" fill="currentColor"/>
</svg>''');

    expect(text, contains('0 0 0 rg'));
  });

  test('an unparsable stop-color does not crash the document', () async {
    await expectLater(
      _render('''
<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="g">
      <stop offset="0" stop-color="notacolor"/>
      <stop offset="1" stop-color="#0000ff"/>
    </linearGradient>
  </defs>
  <rect x="0" y="0" width="100" height="100" fill="url(#g)"/>
</svg>'''),
      completes,
    );
  });

  test('a gradient on an ancestor group is inherited', () async {
    final text = await _render('''
<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="g">
      <stop offset="0" stop-color="#ff0000"/>
      <stop offset="1" stop-color="#0000ff"/>
    </linearGradient>
  </defs>
  <g fill="url(#g)">
    <rect x="0" y="0" width="100" height="100"/>
  </g>
</svg>''');

    // A shading pattern is set up and used, rather than the shape going
    // unpainted because the inherited paint server was erased.
    expect(text, contains('/Pattern cs'));
    expect(text, contains('/Shading'));
  });

  test('a missing paint server falls back instead of crashing', () async {
    await expectLater(
      _render('''
<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
  <rect x="0" y="0" width="100" height="100" fill="url(#gone)"/>
</svg>'''),
      completes,
    );

    final text = await _render('''
<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
  <rect x="0" y="0" width="100" height="100" fill="url(#gone) #00ff00"/>
</svg>''');
    expect(text, contains('0 1 0 rg'), reason: 'the fallback colour is used');
  });

  test('fill="transparent" paints nothing', () async {
    final text = await _render('''
<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
  <rect x="0" y="0" width="100" height="100" fill="transparent"/>
</svg>''');

    expect(
      text,
      isNot(contains('1 1 1 rg')),
      reason: 'transparent must not paint opaque white',
    );
  });

  test('a colour alpha becomes a fill opacity', () async {
    final text = await _render('''
<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
  <rect x="0" y="0" width="100" height="100" fill="rgba(255, 0, 0, 0.5)"/>
</svg>''');

    expect(text, contains('1 0 0 rg'));
    // A graphic state carrying the alpha, and only for the fill.
    expect(text, contains('/ca 0.5'));
    expect(text, isNot(contains('/CA 0.5')));
  });
}
