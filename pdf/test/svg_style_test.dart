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
import 'package:xml/xml.dart';

/// Save a document holding [svg] and hand back its bytes as text.
Future<String> save(String svg) async {
  final document = Document(compress: false);
  document.addPage(
    Page(
      pageFormat: const PdfPageFormat(100, 100, marginAll: 0),
      build: (Context context) => SvgImage(svg: svg),
    ),
  );
  return latin1.decode(await document.save(), allowInvalid: true);
}

/// The page content, or a marker when the page has none.
Future<String> render(String svg) async {
  final pdf = await save(svg);
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
    '<svg $attributes xmlns="http://www.w3.org/2000/svg" '
    'xmlns:xlink="http://www.w3.org/1999/xlink">$body</svg>';

/// An element carrying [style], after convertStyle has run over it.
XmlElement styled(String style) {
  final document = XmlDocument.parse(
    '<path style="${style.replaceAll('"', '&quot;')}"/>',
  );
  SvgParser.convertStyle(document.rootElement);
  return document.rootElement;
}

void main() {
  group('convertStyle', () {
    test('skips a declaration with no colon in it', () {
      // It called .first on the matches of each fragment, which throws
      // 'Bad state: No element' out of Document.save() when there is no match.
      final element = styled('fill:#ff0000;stroke');

      expect(element.getAttribute('fill'), '#ff0000');
      expect(element.getAttribute('stroke'), isNull);
    });

    test('keeps the neighbours of a malformed declaration', () {
      expect(
        styled('-inkscape-stuff;fill:#ff0000').getAttribute('fill'),
        '#ff0000',
      );
      expect(styled('foo;;;fill:#ff0000').getAttribute('fill'), '#ff0000');
      expect(styled('fill:#ff0000;foo').getAttribute('fill'), '#ff0000');
    });

    test('does not split a semicolon inside quotes', () {
      final element = styled("font-family:'A;B';fill:#ff0000");

      expect(element.getAttribute('font-family'), "'A;B'");
      expect(element.getAttribute('fill'), '#ff0000');
    });

    test('does not split a semicolon inside a function', () {
      final element = styled(
        'background:url(data:image/png;base64,AAAA);fill:#ff0000',
      );

      expect(
        element.getAttribute('background'),
        'url(data:image/png;base64,AAAA)',
      );
      expect(element.getAttribute('fill'), '#ff0000');
    });

    test('handles whitespace, newlines and trailing semicolons', () {
      final element = styled('  fill : #ff0000 ;\r\n  stroke:#00ff00;  ');

      expect(element.getAttribute('fill'), '#ff0000');
      expect(element.getAttribute('stroke'), '#00ff00');
    });

    test('is idempotent', () {
      final element = styled('fill:#ff0000');
      final before = element.toXmlString();
      SvgParser.convertStyle(element);

      expect(element.toXmlString(), before);
    });

    test('never throws, whatever it is handed', () {
      final random = math.Random(20260101);
      const alphabet = r""" ;:'"()-_abc0#%/\,.{}<>=""";

      for (var i = 0; i < 2000; i++) {
        final length = random.nextInt(24);
        final style = String.fromCharCodes(<int>[
          for (var c = 0; c < length; c++)
            alphabet.codeUnitAt(random.nextInt(alphabet.length)),
        ]);

        expect(() => styled(style), returnsNormally, reason: style);
      }
    });
  });

  group('a malformed style attribute', () {
    final cases = <String>[
      'fill:#ff0000;stroke',
      '-inkscape-stuff;fill:#ff0000',
      "font-family:'A;B';fill:#ff0000",
      'background:url(data:image/png;base64,AAAA);fill:#ff0000',
      'fill:#ff0000;;',
    ];

    for (final style in cases) {
      test('does not stop the document: $style', () async {
        final content = await render(
          svg('<path d="M0 0 H24 V24 H0 Z" style="$style"/>'),
        );

        expect(content, contains('1 0 0 rg'), reason: style);
      });
    }

    test('with no colon anywhere still saves', () async {
      expect(
        await save(svg('<path d="M0 0 H1 V1 Z" style="foo"/>')),
        isNotEmpty,
      );
    });
  });

  group('a hidden element', () {
    test('is not painted when style says display:none', () async {
      // Every drawing tool exports a hidden layer this way, and the two tests
      // read raw XML attributes while style was flattened later, from
      // SvgBrush.fromXml - so the style form never worked and the hidden layer
      // was painted over the visible artwork.
      final content = await render(
        svg(
          '<path d="M0 0 H24 V24 H0 Z" fill="#ff0000" '
          'style="display:none"/>',
        ),
      );

      expect(content, isNot(contains('1 0 0 rg')));
    });

    test('is not painted when style says visibility:hidden', () async {
      final content = await render(
        svg(
          '<path d="M0 0 H24 V24 H0 Z" fill="#ff0000" '
          'style="visibility:hidden"/>',
        ),
      );

      expect(content, isNot(contains('1 0 0 rg')));
    });

    test('prunes its whole subtree', () async {
      final content = await render(
        svg(
          '<g style="display:none"><g><path d="M0 0 H24 V24 H0 Z" '
          'fill="#ff0000"/></g></g>'
          '<path d="M0 0 H4 V4 H0 Z" fill="#0000ff"/>',
        ),
      );

      expect(content, isNot(contains('1 0 0 rg')));
      expect(content, contains('0 0 1 rg'), reason: 'the sibling still draws');
    });

    test('is honoured inside a longer declaration list', () async {
      final content = await render(
        svg(
          '<path d="M0 0 H24 V24 H0 Z" '
          'style="opacity:1;display:none;stroke-width:2"/>',
        ),
      );

      expect(content, isNot(contains(' f ')));
    });

    test('empties the page when it is the root', () async {
      for (final attributes in <String>[
        'viewBox="0 0 24 24" style="display:none"',
        'viewBox="0 0 24 24" display="none"',
        'viewBox="0 0 24 24" style="visibility:hidden"',
      ]) {
        final content = await render(
          svg(
            '<path d="M0 0 H24 V24 H0 Z" fill="#ff0000"/>',
            attributes: attributes,
          ),
        );

        expect(content, isNot(contains('1 0 0 rg')), reason: attributes);
      }
    });

    test('renders nothing through a <use>', () async {
      final content = await render(
        svg(
          '<path id="p" d="M0 0 H24 V24 H0 Z" fill="#ff0000" '
          'style="display:none"/><use href="#p"/>',
        ),
      );

      expect(content, isNot(contains('1 0 0 rg')));
    });
  });

  test('style still beats the presentation attribute', () async {
    final content = await render(
      svg('<path d="M0 0 H24 V24 H0 Z" fill="#ff0000" style="fill:#0000ff"/>'),
    );

    expect(content, contains('0 0 1 rg'));
    expect(content, isNot(contains('1 0 0 rg')));
  });
}
