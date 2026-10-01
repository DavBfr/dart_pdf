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
import 'dart:typed_data';

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

  test('Flex Widgets ListView', () {
    pdf.addPage(
      Page(
        build: (Context context) => ListView(
          spacing: 20,
          padding: const EdgeInsets.all(10),
          children: <Widget>[Text('Line 1'), Text('Line 2'), Text('Line 3')],
        ),
      ),
    );
  });

  test('Flex Widgets ListView.builder', () {
    pdf.addPage(
      Page(
        build: (Context context) => ListView.builder(
          itemBuilder: (Context context, int index) => Text('Line $index'),
          itemCount: 30,
          spacing: 2,
          reverse: true,
        ),
      ),
    );
  });

  test('Flex Widgets ListView.separated', () {
    pdf.addPage(
      Page(
        build: (Context context) => ListView.separated(
          separatorBuilder: (Context context, int index) => Container(
            color: PdfColors.grey,
            height: 0.5,
            margin: const EdgeInsets.symmetric(vertical: 10),
          ),
          itemBuilder: (Context context, int index) => Text('Line $index'),
          itemCount: 10,
        ),
      ),
    );
  });

  test('Flex Widgets Spacer', () {
    pdf.addPage(
      Page(
        build: (Context context) => Column(
          children: <Widget>[
            Text('Begin'),
            Spacer(), // Defaults to a flex of one.
            Text('Middle'),
            // Gives twice the space between Middle and End than Begin and Middle.
            Spacer(flex: 2),
            // Expanded(flex: 2, child: SizedBox.shrink()),
            Text('End'),
          ],
        ),
      ),
    );
  });

  test('MultiPage Spacer', () {
    pdf.addPage(
      MultiPage(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        build: (Context context) => <Widget>[
          for (int i = 0; i < 60; i++) Text('Begin $i'),
          Spacer(), // Defaults to a flex of one.
          Text('Middle'),
          // Gives twice the space between Middle and End than Begin and Middle.
          Spacer(flex: 2),
          // Expanded(flex: 2, child: SizedBox.shrink()),
          Text('End'),
        ],
      ),
    );
  });

  test('an Expanded Image with an explicit width fits its slot', () async {
    // Image.layout used an explicit width verbatim, so the child came out wider
    // than the flex slot: 'childSize <= maxChildExtent' at flex.dart:392 in
    // debug, a silent overlap in release.
    final document = Document();
    document.addPage(
      Page(
        pageFormat: PdfPageFormat.a4,
        build: (Context context) => Row(
          children: <Widget>[
            Expanded(
              child: Image(
                RawImage(
                  bytes: Uint32List(100 * 50).buffer.asUint8List(),
                  width: 100,
                  height: 50,
                ),
                width: 400,
              ),
            ),
            Expanded(child: Text('x')),
          ],
        ),
      ),
    );

    await expectLater(document.save(), completes);
  });

  group('CrossAxisAlignment.stretch', () {
    Future<String> build(Widget child) async {
      final document = Document(compress: false);
      document.addPage(
        Page(pageFormat: PdfPageFormat.a4, build: (Context context) => child),
      );
      return String.fromCharCodes(await document.save());
    }

    test('is refused when the cross axis is unbounded', () async {
      // Both stretch branches tightened the cross axis to the incoming maximum
      // without checking it was finite, and a Flex hands a non-flex child an
      // unbounded cross axis by design. So a stretched Flex nested inside one
      // running the other way wrote '0 0 Infinity 20 re' - viewers drop the
      // drawing - and with asserts on save() died inside PdfNum naming no widget.
      await expectLater(
        build(
          Row(
            children: <Widget>[
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[Container(height: 20, color: PdfColors.red)],
              ),
            ],
          ),
        ),
        throwsA(
          isA<PdfException>().having(
            (PdfException e) => e.message,
            'message',
            allOf(contains('stretch'), contains('width')),
          ),
        ),
      );

      await expectLater(
        build(
          Column(
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[Container(width: 30, color: PdfColors.blue)],
              ),
            ],
          ),
        ),
        throwsA(
          isA<PdfException>().having(
            (PdfException e) => e.message,
            'message',
            allOf(contains('stretch'), contains('height')),
          ),
        ),
      );
    });

    test('a flex child is refused the same way', () async {
      await expectLater(
        build(
          Row(
            children: <Widget>[
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Expanded(child: Container(height: 20, color: PdfColors.red)),
                ],
              ),
            ],
          ),
        ),
        throwsA(isA<PdfException>()),
      );
    });

    test('a bounded cross axis still stretches', () async {
      final pdf = await build(
        SizedBox(
          width: 100,
          height: 100,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[Container(height: 20, color: PdfColors.red)],
          ),
        ),
      );

      expect(pdf, contains('/Contents'));
      expect(
        RegExp(r'[-\d.]+ [-\d.]+ 100 20 re').hasMatch(pdf),
        isTrue,
        reason: 'the child fills the 100pt cross axis',
      );
      expect(pdf, isNot(contains('Infinity')));
      expect(pdf, isNot(contains('NaN')));
    });
  });

  tearDownAll(() async {
    final file = File('widgets-flex.pdf');
    await file.writeAsBytes(await pdf.save());
  });
}
