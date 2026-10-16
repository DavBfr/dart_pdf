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

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart';
import 'package:test/test.dart';

/// [EdgeInsets] has no value equality, so compare the four edges.
Matcher isInsets(double left, double top, double right, double bottom) =>
    predicate<EdgeInsetsGeometry>((EdgeInsetsGeometry insets) {
      final resolved = insets.resolve(TextDirection.ltr);
      return (resolved.left - left).abs() < 1e-6 &&
          (resolved.top - top).abs() < 1e-6 &&
          (resolved.right - right).abs() < 1e-6 &&
          (resolved.bottom - bottom).abs() < 1e-6;
    }, 'EdgeInsets.fromLTRB($left, $top, $right, $bottom)');

void main() {
  group('PageTheme.copyWith', () {
    test('does not rotate a rotated margin again', () {
      // copyWith fed the margin getter back into the constructor, which stores
      // it raw - and the getter is what rotates the edges when the orientation
      // is forced. So every call cycled the four margins one quarter turn,
      // moving and resizing the content box. Symmetric margins hid it.
      final base = PageTheme(
        pageFormat: PdfPageFormat.a4,
        orientation: PageOrientation.landscape,
        margin: const EdgeInsets.fromLTRB(10, 20, 30, 40),
      );

      expect(base.mustRotate, isTrue);
      expect(base.margin, isInsets(40, 10, 20, 30));
      expect(base.copyWith().margin, isInsets(40, 10, 20, 30));
      expect(base.copyWith().copyWith().margin, isInsets(40, 10, 20, 30));
      expect(
        base.copyWith().copyWith().copyWith().margin,
        isInsets(40, 10, 20, 30),
      );
    });

    test('keeps an unrotated margin as it is', () {
      final base = PageTheme(
        pageFormat: PdfPageFormat.a4,
        margin: const EdgeInsets.fromLTRB(10, 20, 30, 40),
      );

      expect(base.mustRotate, isFalse);
      expect(base.margin, isInsets(10, 20, 30, 40));
      expect(base.copyWith().margin, isInsets(10, 20, 30, 40));
      expect(
        base.copyWith(margin: const EdgeInsets.all(5)).margin,
        isInsets(5, 5, 5, 5),
      );
    });

    test('leaves an implicit margin implicit', () {
      // With no margin of its own a theme tracks the page format's. Copying the
      // getter froze whatever the old format said, so a derived theme kept the
      // old margins after being given a new format.
      for (final orientation in <PageOrientation>[
        PageOrientation.natural,
        PageOrientation.landscape,
      ]) {
        final base = PageTheme(
          pageFormat: PdfPageFormat.a4,
          orientation: orientation,
        );

        final m = PdfPageFormat.a4.marginLeft;
        expect(base.copyWith().margin, isInsets(m, m, m, m));
        expect(
          base
              .copyWith(
                pageFormat: const PdfPageFormat(400, 600, marginAll: 99),
              )
              .margin,
          isInsets(99, 99, 99, 99),
          reason: '$orientation',
        );
      }
    });

    test('takes a directional margin and keeps it directional', () {
      // The parameter was EdgeInsets?, narrower than the field, so a directional
      // margin could not be passed back in at all.
      final base = PageTheme(pageFormat: PdfPageFormat.a4);
      final derived = base.copyWith(
        margin: const EdgeInsetsDirectional.fromSTEB(1, 2, 3, 4),
      );

      expect(derived.margin, isA<EdgeInsetsDirectional>());
      expect(derived.margin, isInsets(1, 2, 3, 4));
      expect(
        derived
            .copyWith(textDirection: TextDirection.rtl)
            .margin!
            .resolve(TextDirection.rtl),
        isInsets(3, 2, 1, 4),
      );
    });

    test('copies every other field', () {
      ThemeData? theme;
      final base = PageTheme(
        pageFormat: PdfPageFormat.a5,
        orientation: PageOrientation.portrait,
        clip: true,
        textDirection: TextDirection.rtl,
        theme: theme,
        margin: const EdgeInsets.all(7),
      );
      final copy = base.copyWith();

      expect(copy.pageFormat, base.pageFormat);
      expect(copy.orientation, base.orientation);
      expect(copy.clip, base.clip);
      expect(copy.textDirection, base.textDirection);
      expect(copy.theme, base.theme);
      expect(copy.margin, isInsets(7, 7, 7, 7));
    });
  });

  test('a page from a derived theme has the same content box', () async {
    // What the defect actually cost: deriving a per-page theme moved the content.
    final base = PageTheme(
      pageFormat: PdfPageFormat.a4,
      orientation: PageOrientation.landscape,
      margin: const EdgeInsets.fromLTRB(10, 20, 30, 40),
    );

    Future<String> render(PageTheme theme) async {
      final document = Document(compress: false);
      document.addPage(
        Page(
          pageTheme: theme,
          build: (Context context) => Container(color: PdfColors.blue),
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

    expect(await render(base.copyWith()), await render(base));
  });
}
