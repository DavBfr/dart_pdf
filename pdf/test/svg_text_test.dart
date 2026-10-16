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

/// The page content of a 400x200 SVG holding [body].
Future<String> render(String body) async {
  final document = Document(compress: false);
  document.addPage(
    Page(
      pageFormat: const PdfPageFormat(400, 200, marginAll: 0),
      build: (Context context) => SvgImage(
        svg:
            '<svg viewBox="0 0 400 200" xmlns="http://www.w3.org/2000/svg">'
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

/// Every text run the stream shows, as `text@x`, in the order it is drawn.
List<String> runs(String content) => RegExp(
  // Each run is its own q...Q block, so this must not cross one - nor match the
  // root SVG transform, which is not inside a q of its own.
  r'q 1 0 -0 -1 ([-\d.]+) ([-\d.]+) cm[^Q]*?\[\((.*?)\)\]TJ',
).allMatches(content).map((m) => '${m.group(3)}@${m.group(1)}').toList();

void main() {
  group('a <text> with a <tspan>', () {
    test('draws its runs in document order', () async {
      // Every text node was joined into one string and each <tspan> became a
      // child drawn afterwards, so 'AB<tspan>CD</tspan>EF' drew 'ABEF' and then
      // 'CD' - and the first tspan started at the parent's whole advance width
      // whatever stood before it.
      final content = await render(
        '<text x="5" y="30" font-size="35">AB<tspan>CD</tspan>EF</text>',
      );

      expect(runs(content), <String>['AB@5', 'CD@51.69', 'EF@102.23']);
    });

    test('keeps the space before the tspan', () async {
      // Each node was trimmed, so the space vanished and the tspan moved left.
      final content = await render(
        '<text x="5" y="30" font-size="35">Custom <tspan>fonts</tspan></text>',
      );

      expect(runs(content), <String>['Custom @5', 'fonts@135.305']);
    });

    test('starts a new chunk at an absolute x', () async {
      final content = await render(
        '<text x="5" y="30" font-size="35">AB<tspan x="200">CD</tspan></text>',
      );

      expect(runs(content), <String>['AB@5', 'CD@200']);
    });

    test('adds dx to the cursor rather than replacing it', () async {
      final content = await render(
        '<text x="5" y="30" font-size="35">AB<tspan dx="10">CD</tspan></text>',
      );

      expect(runs(content), <String>['AB@5', 'CD@61.69']);
    });
  });

  group('white space', () {
    test('is collapsed by default', () async {
      final content = await render(
        '<text x="5" y="30" font-size="35">A\n\tB</text>',
      );

      expect(runs(content), <String>['A B@5']);
    });

    test('never reaches the stream as a newline or a tab', () async {
      for (final body in <String>[
        '<text x="5" y="30">A\nB</text>',
        '<text x="5" y="30" xml:space="preserve">A\nB</text>',
        '<text x="5" y="30">A\tB</text>',
      ]) {
        final content = await render(body);

        expect(content, isNot(contains('(A\nB)')), reason: body);
        expect(content, isNot(contains('(A\tB)')), reason: body);
      }
    });

    test('is kept with xml:space="preserve"', () async {
      final content = await render(
        '<text x="5" y="30" font-size="35" xml:space="preserve">'
        '  A  B  </text>',
      );

      expect(runs(content), <String>['  A  B  @5']);
    });

    test('is inherited from an ancestor', () async {
      final content = await render(
        '<g xml:space="preserve"><text x="5" y="30" font-size="35">'
        '  A  </text></g>',
      );

      expect(runs(content), <String>['  A  @5']);
    });

    test('drops only the leading space of a chunk', () async {
      final content = await render(
        '<text x="5" y="30" font-size="35">  A <tspan> B</tspan></text>',
      );

      expect(runs(content), <String>['A @5', ' B@38.075']);
    });
  });

  group('text-anchor', () {
    test('shifts the whole chunk by its advance width', () async {
      final middle = await render(
        '<text x="100" y="30" font-size="35" text-anchor="middle">ABCD</text>',
      );
      final start = await render(
        '<text x="100" y="30" font-size="35">ABCD</text>',
      );
      final end = await render(
        '<text x="100" y="30" font-size="35" text-anchor="end">ABCD</text>',
      );

      expect(runs(start), <String>['ABCD@100']);
      expect(runs(middle), <String>['ABCD@51.385']);
      expect(runs(end), <String>['ABCD@2.77']);
    });

    test('shifts a chunk made of several runs once', () async {
      final content = await render(
        '<text x="100" y="30" font-size="35" text-anchor="middle">'
        'AB<tspan>CD</tspan></text>',
      );

      // Both runs move by the same amount, and stay adjacent.
      final positions = runs(
        content,
      ).map((String r) => double.parse(r.split('@').last)).toList();
      expect(positions, hasLength(2));
      expect(positions[1] - positions[0], closeTo(46.69, 0.01));
    });
  });

  group('a non-text child', () {
    test('is not drawn', () async {
      // Every XmlElement child became a tspan, so a <desc> was rendered as text.
      final content = await render(
        '<text x="5" y="30" font-size="35">Hi<desc>SECRET</desc></text>',
      );

      expect(content, isNot(contains('SECRET')));
      expect(runs(content), <String>['Hi@5']);
    });

    test('does not stop the runs around it', () async {
      final content = await render(
        '<text x="5" y="30" font-size="35">A<title>T</title>'
        '<tspan>B</tspan></text>',
      );

      expect(content, isNot(contains('(T)')));
      expect(runs(content), hasLength(2));
    });
  });

  test('a plain <text> is unchanged', () async {
    final content = await render(
      '<text x="5" y="30" font-size="35">Hello</text>',
    );

    expect(runs(content), <String>['Hello@5']);
    expect(content, contains('/F5 35 Tf'));
  });
}
