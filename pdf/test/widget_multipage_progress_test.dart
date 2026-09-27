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

/// A spanning widget that fills every page it is given and never reports
/// being finished, while appearing to make progress each time. Only the total
/// page ceiling can stop it.
class _EndlessSpan extends Widget with SpanningWidget {
  final _EndlessContext _context = _EndlessContext();

  @override
  bool get canSpan => true;

  @override
  bool get hasMoreWidgets => true;

  @override
  void layout(
    Context context,
    BoxConstraints constraints, {
    bool parentUsesSize = false,
  }) {
    _context.step++;
    final height = constraints.hasBoundedHeight
        ? constraints.maxHeight
        : constraints.maxWidth * 4;
    box = PdfRect(0, 0, constraints.maxWidth, height);
  }

  @override
  WidgetContext saveContext() => _context;

  @override
  void restoreContext(_EndlessContext context) {}
}

class _EndlessContext extends WidgetContext {
  int step = 0;

  @override
  void apply(_EndlessContext other) => step = other.step;

  @override
  WidgetContext clone() => _EndlessContext()..apply(this);

  @override
  bool isSameAs(_EndlessContext other) => step == other.step;

  @override
  String toString() => '$runtimeType step:$step';
}

/// A spanning widget that always claims to need more room and never consumes
/// anything: the shape that used to allocate pages for ever.
class _StuckSpan extends Widget with SpanningWidget {
  final _EndlessContext _context = _EndlessContext();

  @override
  bool get canSpan => true;

  @override
  bool get hasMoreWidgets => true;

  @override
  void layout(
    Context context,
    BoxConstraints constraints, {
    bool parentUsesSize = false,
  }) {
    final available = constraints.hasBoundedHeight
        ? constraints.maxHeight
        : constraints.maxWidth * 4;
    box = PdfRect(0, 0, constraints.maxWidth, available + 10);
  }

  @override
  WidgetContext saveContext() => _context;

  @override
  void restoreContext(_EndlessContext context) {}
}

void main() {
  test('a Column holding a child taller than the page terminates', () async {
    final document = Document(compress: false);
    document.addPage(
      MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (Context context) => <Widget>[
          Column(
            children: <Widget>[
              SizedBox(height: 2000),
              Text('after', style: const TextStyle(fontSize: 12)),
            ],
          ),
        ],
      ),
    );

    final text = latin1.decode(await document.save(), allowInvalid: true);
    expect(document.document.pdfPageList.pages.length, lessThan(10));
    expect(text, contains('(after)'));
  });

  test('a Column longer than maxPages pages is not a stall', () async {
    // 1500 rows need far more than the default maxPages of 20. The guard
    // counts pages produced without progress, not pages produced.
    final document = Document(compress: false);
    document.addPage(
      MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (Context context) => <Widget>[
          Column(
            children: List<Widget>.generate(
              1500,
              (int i) => Text('L$i', style: const TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
    );

    await expectLater(document.save(), completes);
    expect(document.document.pdfPageList.pages.length, greaterThan(20));
  });

  test('a child sized to exactly the available height fits one page', () {
    // The fit test compared two floats that differ only by rounding, so a
    // child sized to availableHeight was rejected for 21 of these 120 cases.
    const formats = <String, PdfPageFormat>{
      'a3': PdfPageFormat.a3,
      'a4': PdfPageFormat.a4,
      'a5': PdfPageFormat.a5,
      'a6': PdfPageFormat.a6,
      'letter': PdfPageFormat.letter,
      'legal': PdfPageFormat.legal,
    };
    const margins = <String, double>{
      '0': 0,
      '1pt': 1,
      '1mm': PdfPageFormat.mm,
      '2mm': 2 * PdfPageFormat.mm,
      '3mm': 3 * PdfPageFormat.mm,
      '5mm': 5 * PdfPageFormat.mm,
      '1cm': PdfPageFormat.cm,
      '2cm': 2 * PdfPageFormat.cm,
      '0.25in': 0.25 * PdfPageFormat.inch,
      '0.5in': 0.5 * PdfPageFormat.inch,
      '1in': PdfPageFormat.inch,
      '36pt': 36,
      '48pt': 48,
      '72pt': 72,
    };

    for (final format in formats.entries) {
      for (final margin in margins.entries) {
        final pageFormat = format.value.copyWith(
          marginTop: margin.value,
          marginBottom: margin.value,
          marginLeft: margin.value,
          marginRight: margin.value,
        );
        final document = Document(compress: false);
        document.addPage(
          MultiPage(
            pageFormat: pageFormat,
            build: (Context context) => <Widget>[
              Container(
                width: pageFormat.availableWidth,
                height: pageFormat.availableHeight,
              ),
            ],
          ),
        );
        expect(
          document.document.pdfPageList.pages.length,
          1,
          reason: '${format.key} with ${margin.key} margins must be one page',
        );
      }
    }
  });

  test('a child taller than the header and footer band is reported', () {
    // 661.89pt are free once a 60pt header and a 60pt footer are laid out, but
    // the retry compared against the whole page body, so a 700pt child was
    // moved to a new page for ever.
    final document = Document(compress: false);

    expect(
      () => document.addPage(
        MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const EdgeInsets.all(30),
          header: (Context context) => SizedBox(height: 60, child: Text('H')),
          footer: (Context context) => SizedBox(height: 60, child: Text('F')),
          build: (Context context) => <Widget>[
            Row(children: <Widget>[Expanded(child: SizedBox(height: 700))]),
          ],
        ),
      ),
      throwsA(
        isA<PdfException>()
            .having(
              (PdfException e) => e is PdfTooBigPageException,
              'is not a page-count error',
              isFalse,
            )
            .having(
              (PdfException e) => e.toString(),
              'names the available band',
              contains('661.890pt'),
            ),
      ),
    );
    expect(document.document.pdfPageList.pages.length, lessThan(3));
  });

  test('a child fitting the band under a header is placed on one page', () {
    final document = Document(compress: false);
    document.addPage(
      MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const EdgeInsets.all(30),
        header: (Context context) => SizedBox(height: 60, child: Text('H')),
        footer: (Context context) => SizedBox(height: 60, child: Text('F')),
        build: (Context context) => <Widget>[
          Row(children: <Widget>[Expanded(child: SizedBox(height: 661))]),
        ],
      ),
    );

    expect(document.document.pdfPageList.pages.length, 1);
  });

  test('a widget that never places anything raises instead of looping', () {
    final document = Document(compress: false);

    expect(
      () => document.addPage(
        MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (Context context) => <Widget>[_StuckSpan()],
        ),
      ),
      throwsA(isA<PdfException>()),
    );
    // The old guard only gave up after maxPages pages had been allocated.
    expect(document.document.pdfPageList.pages.length, lessThan(3));
  });

  test('a widget that never finishes is bounded by the page ceiling', () {
    final document = Document(compress: false);

    expect(
      () => document.addPage(
        MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (Context context) => <Widget>[_EndlessSpan()],
        ),
      ),
      throwsA(
        isA<PdfTooBigPageException>().having(
          (PdfTooBigPageException e) => e.toString(),
          'names the page ceiling',
          contains('10000'),
        ),
      ),
    );
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('a spanning Column adds no trailing empty page', () async {
    // 3 rows of 100pt exactly fill the 300pt body, so the old code appended an
    // empty fragment on a fourth page.
    const format = PdfPageFormat(300, 320, marginAll: 10);
    final document = Document(compress: false);
    document.addPage(
      MultiPage(
        pageFormat: format,
        build: (Context context) => <Widget>[
          Column(
            children: List<Widget>.generate(
              6,
              (int i) => SizedBox(
                height: 100,
                child: Text('P$i', style: const TextStyle(fontSize: 10)),
              ),
            ),
          ),
        ],
      ),
    );

    final text = latin1.decode(await document.save(), allowInvalid: true);
    expect(document.document.pdfPageList.pages.length, 2);
    for (var i = 0; i < 6; i++) {
      expect('(P$i)'.allMatches(text).length, 1, reason: 'row $i once');
    }
  });
}
