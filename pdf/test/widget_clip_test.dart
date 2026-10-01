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

import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart';
import 'package:test/test.dart';

late Document pdf;

void main() {
  setUpAll(() {
    Document.debug = true;
    pdf = Document();
  });

  test('Clip Widgets ClipRect', () {
    pdf.addPage(
      Page(
        build: (Context context) => ClipRect(
          child: Transform.rotate(
            angle: 0.1,
            child: Container(
              decoration: const BoxDecoration(color: PdfColors.blue),
            ),
          ),
        ),
      ),
    );
  });

  test('Clip Widgets ClipRRect', () {
    pdf.addPage(
      Page(
        build: (Context context) => ClipRRect(
          horizontalRadius: 30,
          verticalRadius: 30,
          child: Container(
            decoration: const BoxDecoration(color: PdfColors.blue),
          ),
        ),
      ),
    );
  });

  test('Clip Widgets ClipOval', () {
    pdf.addPage(
      Page(
        build: (Context context) => ClipOval(
          child: Container(
            decoration: const BoxDecoration(color: PdfColors.blue),
          ),
        ),
      ),
    );
  });

  group('a ClipRRect', () {
    /// The content stream of a 200x200 page holding [child].
    Future<String> stream(Widget child) async {
      final document = Document(compress: false);
      document.addPage(
        Page(
          pageFormat: const PdfPageFormat(200, 200, marginAll: 0),
          build: (Context context) => child,
        ),
      );
      final pdf = String.fromCharCodes(await document.save());
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

    /// The path-construction run starting at [startOf].
    ///
    /// Operands come before their operator in a content stream, so this walks the
    /// tokens and keeps a run only once its operator turns out to be one that
    /// builds a path: a decorated box sets a fill colour before filling, a clip
    /// does not, and neither belongs to the shape being compared.
    String path(String content, String startOf) {
      const construction = <String>{'m', 'l', 'c', 'v', 'y', 'h', 're'};
      final tokens = content
          .substring(content.indexOf(startOf))
          .split(RegExp(r'\s+'));
      final kept = <String>[];
      final pending = <String>[];

      for (final token in tokens) {
        if (double.tryParse(token) != null) {
          pending.add(token);
          continue;
        }
        if (!construction.contains(token)) {
          break;
        }
        kept
          ..addAll(pending)
          ..add(token);
        pending.clear();
      }

      return kept.join(' ');
    }

    test('does not exchange its two radii', () async {
      // drawRRect's fifth argument runs on the y axis and its sixth on the x
      // axis - forms.dart passes radius.y then radius.x - and ClipRRect passed
      // them the other way round. 40 by 5 clipped corners 5 wide and 40 tall.
      final content = await stream(
        ClipRRect(
          horizontalRadius: 40,
          verticalRadius: 5,
          child: Container(
            decoration: const BoxDecoration(color: PdfColors.blue),
          ),
        ),
      );

      expect(content, contains('0 5 m'));
      expect(content, contains('40 0 c'));
      expect(content, isNot(contains('0 40 m')));
    });

    test('clips the path a matching BorderRadius draws', () async {
      final clip = path(
        await stream(
          ClipRRect(
            horizontalRadius: 40,
            verticalRadius: 5,
            child: Container(
              decoration: const BoxDecoration(color: PdfColors.blue),
            ),
          ),
        ),
        '0 5 m',
      );

      final decorated = path(
        await stream(
          Container(
            decoration: const BoxDecoration(
              color: PdfColors.blue,
              borderRadius: BorderRadius.all(Radius.elliptical(40, 5)),
            ),
          ),
        ),
        '0 5 m',
      );

      expect(clip, decorated);
    });

    test('is unchanged when the two radii are equal', () async {
      // The repo's own ClipRRect page uses 30 by 30, which is why this went
      // unnoticed; it has to stay byte-for-byte as it was.
      final content = await stream(
        ClipRRect(
          horizontalRadius: 30,
          verticalRadius: 30,
          child: Container(
            decoration: const BoxDecoration(color: PdfColors.blue),
          ),
        ),
      );

      expect(content, contains('0 30 m'));
      expect(content, contains('30 0 c'));
    });
  });

  group('PageTheme.clip', () {
    // Document.debug paints a page-wide background before anything else, which
    // is a debug aid and not page content - it would sit outside the clip and
    // say nothing about this.
    setUp(() => Document.debug = false);
    tearDown(() => Document.debug = true);

    /// Every page's content stream.
    List<String> contents(String pdf) => <String>[
      for (final m in RegExp(
        r'stream(.*?)endstream',
        dotAll: true,
      ).allMatches(pdf))
        if (m.group(1)!.contains('0 Tr')) m.group(1)!.trim(),
    ];

    /// The clip rectangle a stream opens with, if any.
    String? clipOf(String content) => RegExp(
      r'([-\d.]+ [-\d.]+ [-\d.]+ [-\d.]+) re W n',
    ).firstMatch(content)?.group(1);

    Future<String> page(PageTheme theme) async {
      final document = Document(compress: false);
      document.addPage(
        Page(
          pageTheme: theme,
          build: (Context context) => Container(color: PdfColors.blue),
        ),
      );
      return String.fromCharCodes(await document.save());
    }

    Future<String> multiPage(PageTheme theme) async {
      final document = Document(compress: false);
      document.addPage(
        MultiPage(
          pageTheme: theme,
          header: (Context context) => Text('header'),
          footer: (Context context) => Text('footer'),
          build: (Context context) => <Widget>[
            for (var i = 0; i < 40; i++)
              Container(height: 30, color: PdfColors.blue, child: Text('$i')),
          ],
        ),
      );
      return String.fromCharCodes(await document.save());
    }

    final a4 = PageTheme(
      pageFormat: PdfPageFormat.a4,
      margin: const EdgeInsets.all(50),
      clip: true,
    );

    test('applies to a MultiPage, on every page', () async {
      // MultiPage overrides postProcess wholesale and never calls Page.paint, so
      // the flag was dropped for every page it wrote: over-wide content bled past
      // the margins and over the header and footer, and printers cropped it.
      final streams = contents(await multiPage(a4));

      expect(streams.length, greaterThan(1));
      for (final content in streams) {
        expect(content, contains('50 50 495.27559 741.88976 re'));
        expect(clipOf(content), '50 50 495.27559 741.88976');
      }
    });

    test('clips to the same box a Page does', () async {
      final landscape = PageTheme(
        pageFormat: PdfPageFormat.a4,
        orientation: PageOrientation.landscape,
        margin: const EdgeInsets.fromLTRB(10, 20, 30, 40),
        clip: true,
      );

      for (final theme in <PageTheme>[a4, landscape]) {
        final single = clipOf(contents(await page(theme)).single);
        expect(single, isNotNull);
        for (final content in contents(await multiPage(theme))) {
          expect(clipOf(content), single);
        }
      }

      expect(
        clipOf(contents(await page(landscape)).single),
        '40 30 535.27559 801.88976',
      );
    });

    test('wraps every layer and stays balanced', () async {
      for (final content in contents(await multiPage(a4))) {
        // The clip is the first thing the page does, so nothing - background,
        // header, body, footer, foreground - is painted outside it.
        const painting = <String>{'f', 'f*', 'S', 's', 'B', 'B*', 'W', 'W*'};
        final first = content
            .split(RegExp(r'\s+'))
            .firstWhere(painting.contains, orElse: () => '(none)');
        expect(first, 'W');

        var depth = 0;
        for (final token in content.split(RegExp(r'\s+'))) {
          if (token == 'q') {
            depth++;
          } else if (token == 'Q') {
            depth--;
          }
          expect(depth, greaterThanOrEqualTo(0));
        }
        expect(depth, 0, reason: 'the q/Q depth returns to zero');
      }
    });

    test('is absent when the theme does not ask for it', () async {
      final plain = PageTheme(
        pageFormat: PdfPageFormat.a4,
        margin: const EdgeInsets.all(50),
      );

      for (final content in contents(await multiPage(plain))) {
        expect(clipOf(content), isNull);
      }
    });
  });

  tearDownAll(() async {
    final file = File('widgets-clip.pdf');
    await file.writeAsBytes(await pdf.save());
  });
}
