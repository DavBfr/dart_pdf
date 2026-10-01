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
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart';
import 'package:test/test.dart';

/// Save a document holding [svg] and hand back its bytes.
Future<Uint8List> save(String svg) {
  final document = Document(compress: false);
  document.addPage(
    Page(
      pageFormat: const PdfPageFormat(100, 100, marginAll: 0),
      build: (Context context) => SvgImage(svg: svg),
    ),
  );
  return document.save();
}

/// The page's content stream.
Future<String> render(String svg) async {
  final pdf = latin1.decode(await save(svg), allowInvalid: true);
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

String svg(String body) => '''
<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"
     xmlns:xlink="http://www.w3.org/1999/xlink">$body</svg>''';

void main() {
  group('a cyclic use', () {
    // Children are built lazily, so the expansion runs during paint and the
    // overflow surfaced from pdf.save() as a StackOverflowError - an Error, which
    // a try/catch around the build does not usually see, so the isolate died.
    final cycles = <String, String>{
      'self reference': '<g id="a"><use href="#a"/></g>',
      'mutual reference':
          '<g id="a"><use href="#b"/></g><g id="b"><use href="#a"/></g>',
      'use referencing itself': '<use id="u" href="#u"/>',
      'xlink form': '<g id="a"><use xlink:href="#a"/></g>',
      'three-step cycle':
          '<g id="a"><use href="#b"/></g>'
          '<g id="b"><use href="#c"/></g><g id="c"><use href="#a"/></g>',
    };

    cycles.forEach((String name, String body) {
      test('through $name renders instead of overflowing', () async {
        expect(await save(svg(body)), isNotEmpty, reason: name);
      });
    });

    test('does not stop the content around it', () async {
      final content = await render(
        svg(
          '<g id="a"><rect width="4" height="4" fill="#ff0000"/>'
          '<use href="#a"/></g>',
        ),
      );

      // Exactly one rect path: the cycle contributes nothing, the rest draws.
      expect(RegExp(r'0 0 m 4 0 l').allMatches(content), hasLength(1));
      expect(content, contains('1 0 0 rg'));
    });
  });

  group('a use with no usable href', () {
    final broken = <String, String>{
      'an empty href': '<use href=""/>',
      'a lone hash': '<use href="#"/>',
      'an external reference': '<use href="other.svg#a"/>',
      'a missing id': '<use href="#nothing"/>',
      'no href at all': '<use x="1" y="1"/>',
    };

    broken.forEach((String name, String body) {
      test('with $name renders nothing and throws nothing', () async {
        // substring(1) used to run on whatever was there.
        expect(await save(svg(body)), isNotEmpty, reason: name);
      });
    });
  });

  test('an acyclic use graph is unchanged', () async {
    // The diamond: one element used twice, through a group that is itself used.
    final diamond = svg(
      '<g id="a"><rect width="4" height="4" fill="#0000ff"/></g>'
      '<g id="b"><use href="#a"/><use href="#a" x="6"/></g>'
      '<use href="#b" y="6"/>',
    );
    final content = await render(diamond);

    // Five rect paths: #a draws where it stands, #b draws it twice, and
    // <use href="#b"> draws #b again - every expansion still happens.
    expect(RegExp(r'0 0 m 4 0 l').allMatches(content), hasLength(5));
    expect(content, contains('0 0 1 rg'));
  });

  test('a deep use chain terminates', () async {
    // Each level references the one before it, so an unbounded expansion would
    // double at every step.
    final body = StringBuffer('<g id="l0"><rect width="1" height="1"/></g>');
    for (var i = 1; i <= 20; i++) {
      body.write('<g id="l$i"><use href="#l${i - 1}"/></g>');
    }
    body.write('<use href="#l20"/>');

    final bytes = await save(svg(body.toString()));
    expect(bytes, isNotEmpty);
    expect(bytes.length, lessThan(1 << 20), reason: 'no exponential blow-up');
  });
}
