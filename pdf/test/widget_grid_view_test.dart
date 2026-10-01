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
import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart';
import 'package:test/test.dart';

late Document pdf;

void main() {
  setUpAll(() {
    Document.debug = true;
    RichText.debug = true;
    pdf = Document();
  });

  test('Pdf Widgets GridView empty', () {
    pdf.addPage(
      MultiPage(
        build: (Context context) => <Widget>[
          GridView(crossAxisCount: 1, childAspectRatio: 1),
        ],
      ),
    );
  });

  test('Pdf Widgets GridView Vertical', () {
    pdf.addPage(
      MultiPage(
        build: (Context context) => <Widget>[
          GridView(
            crossAxisCount: 3,
            childAspectRatio: 1,
            direction: Axis.vertical,
            children: List<Widget>.generate(
              20,
              (int index) => Center(child: Text('$index')),
            ),
          ),
        ],
      ),
    );
  });

  test('Pdf Widgets GridView Horizontal', () {
    pdf.addPage(
      Page(
        build: (Context context) => GridView(
          crossAxisCount: 5,
          direction: Axis.horizontal,
          childAspectRatio: 1,
          children: List<Widget>.generate(
            20,
            (int index) => Center(child: Text('$index')),
          ),
        ),
      ),
    );
  });

  test('a GridView cell taller than the page terminates', () async {
    // childAspectRatio 4 with two columns makes each cell ~964pt tall, more
    // than the 728pt A4 body: the row count used to floor to zero, so nothing
    // was placed and MultiPage asked for another page for ever.
    final document = Document(compress: false);
    document.addPage(
      MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (Context context) => <Widget>[
          GridView(
            crossAxisCount: 2,
            childAspectRatio: 4,
            children: List<Widget>.generate(8, (int i) => Text('C$i')),
          ),
        ],
      ),
    );

    final text = latin1.decode(await document.save(), allowInvalid: true);
    expect(document.document.pdfPageList.pages.length, lessThanOrEqualTo(8));
    for (var i = 0; i < 8; i++) {
      expect(
        '(C$i)'.allMatches(text).length,
        1,
        reason: 'cell $i must be drawn exactly once',
      );
    }
  });

  test('a spanning GridView adds no trailing blank page', () async {
    final document = Document(compress: false);
    document.addPage(
      MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (Context context) => <Widget>[
          GridView(
            crossAxisCount: 2,
            childAspectRatio: 1,
            children: List<Widget>.generate(20, (int i) => Text('G$i')),
          ),
        ],
      ),
    );

    final text = latin1.decode(await document.save(), allowInvalid: true);
    expect(document.document.pdfPageList.pages.length, 4);
    for (var i = 0; i < 20; i++) {
      expect('(G$i)'.allMatches(text).length, 1, reason: 'cell $i once');
    }
  });

  test('an exhausted GridView reports no more widgets', () async {
    final grid = GridView(
      crossAxisCount: 2,
      childAspectRatio: 1,
      children: List<Widget>.generate(4, (int i) => Text('E$i')),
    );
    final document = Document(compress: false);
    document.addPage(
      MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (Context context) => <Widget>[grid],
      ),
    );
    await document.save();

    expect(grid.hasMoreWidgets, isFalse);
  });

  test('an empty GridView lays out to nothing', () async {
    final document = Document(compress: false);
    document.addPage(
      Page(
        pageFormat: PdfPageFormat.a4,
        build: (Context context) => GridView(
          crossAxisCount: 2,
          childAspectRatio: 1,
          children: const <Widget>[],
        ),
      ),
    );

    await expectLater(document.save(), completes);
  });

  group('a GridView under rtl', () {
    /// Lay a grid of [count] children out alone on a 200x200 page and return its
    /// own box followed by the box of every child that was placed.
    Future<List<PdfRect>> layout(
      TextDirection direction, {
      required int crossAxisCount,
      required int count,
      double spacing = 0,
      EdgeInsetsGeometry padding = EdgeInsets.zero,
      Axis axis = Axis.vertical,
    }) async {
      late GridView grid;
      final document = Document(compress: false);
      document.addPage(
        Page(
          pageFormat: const PdfPageFormat(200, 200, marginAll: 0),
          textDirection: direction,
          build: (Context context) => grid = GridView(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 1,
            direction: axis,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            padding: padding,
            children: <Widget>[
              // The grid hands every child tight constraints, so a child cannot
              // be narrower than its cell however it is written - the centring
              // term in the placement is always zero in practice.
              for (var i = 0; i < count; i++) Container(color: PdfColors.blue),
            ],
          ),
        ),
      );
      await document.save();

      return <PdfRect>[
        grid.box!,
        for (final child in grid.children)
          if (child.box != null) child.box!,
      ];
    }

    /// Assert that the rtl boxes are the ltr boxes mirrored about the padded
    /// band, and that none of them leaves it. Child boxes are in the grid's own
    /// coordinates, and the grid shrinks to its content, so the band runs from
    /// the resolved left padding across the box's content width.
    void expectMirrored(
      List<PdfRect> ltr,
      List<PdfRect> rtl,
      EdgeInsetsGeometry padding, {
      required String what,
    }) {
      final padLtr = padding.resolve(TextDirection.ltr);
      final padRtl = padding.resolve(TextDirection.rtl);
      final band = ltr.first.width - padLtr.horizontal;

      expect(
        rtl.first.width - padRtl.horizontal,
        closeTo(band, 1e-9),
        reason: '$what: the two bands are not the same width',
      );
      expect(rtl, hasLength(ltr.length), reason: what);
      expect(ltr.length, greaterThan(1), reason: '$what: nothing was placed');

      for (var i = 1; i < ltr.length; i++) {
        final fromStart = ltr[i].x - padLtr.left;
        expect(
          rtl[i].x,
          closeTo(padRtl.left + band - fromStart - ltr[i].width, 1e-9),
          reason: '$what: child $i',
        );
        expect(rtl[i].y, closeTo(ltr[i].y, 1e-9), reason: '$what: child $i y');
        expect(
          rtl[i].x,
          greaterThanOrEqualTo(padRtl.left - 1e-9),
          reason: '$what: child $i is left of the band',
        );
        expect(
          rtl[i].x + rtl[i].width,
          lessThanOrEqualTo(padRtl.left + band + 1e-9),
          reason: '$what: child $i is right of the band',
        );
      }
    }

    const paddings = <EdgeInsetsGeometry>[
      EdgeInsets.zero,
      EdgeInsets.only(left: 12, right: 4),
      EdgeInsetsDirectional.only(start: 12, end: 4),
    ];

    test('mirrors the vertical layout exactly', () async {
      // The rtl position was written as a second expression that had to agree
      // with the ltr one for every cell count, spacing and padding - and only
      // did for crossAxisCount 3 with no spacing, no padding and full-cell
      // children. With crossAxisCount 1 the child landed 400pt right of where it
      // belongs, well off a 200pt page.
      for (var cross = 1; cross <= 6; cross++) {
        for (final spacing in <double>[0, 8]) {
          for (final padding in paddings) {
            final what = 'vertical, $cross columns, spacing $spacing, $padding';
            expectMirrored(
              await layout(
                TextDirection.ltr,
                crossAxisCount: cross,
                count: cross,
                spacing: spacing,
                padding: padding,
              ),
              await layout(
                TextDirection.rtl,
                crossAxisCount: cross,
                count: cross,
                spacing: spacing,
                padding: padding,
              ),
              padding,
              what: what,
            );
          }
        }
      }
    });

    test('mirrors the horizontal layout exactly', () async {
      // Axis.horizontal mirrors on the main axis, and that branch right-aligned
      // in the band, losing the centring term and twice the left padding.
      for (var cross = 1; cross <= 6; cross++) {
        for (final spacing in <double>[0, 8]) {
          for (final padding in paddings) {
            final what = 'horizontal, $cross rows, spacing $spacing, $padding';
            expectMirrored(
              await layout(
                TextDirection.ltr,
                crossAxisCount: cross,
                count: cross * 2,
                spacing: spacing,
                padding: padding,
                axis: Axis.horizontal,
              ),
              await layout(
                TextDirection.rtl,
                crossAxisCount: cross,
                count: cross * 2,
                spacing: spacing,
                padding: padding,
                axis: Axis.horizontal,
              ),
              padding,
              what: what,
            );
          }
        }
      }
    });

    test('leaves the three-column full-cell case where it was', () async {
      // The one configuration the old expression got right, and the one the
      // existing rtl_layout_test pages use.
      final rtl = await layout(TextDirection.rtl, crossAxisCount: 3, count: 3);

      expect(rtl.skip(1).map((PdfRect r) => r.x), <Matcher>[
        closeTo(400 / 3, 1e-9),
        closeTo(200 / 3, 1e-9),
        closeTo(0, 1e-9),
      ]);
    });
  });

  tearDownAll(() async {
    final file = File('widgets-gridview.pdf');
    await file.writeAsBytes(await pdf.save());
  });
}
