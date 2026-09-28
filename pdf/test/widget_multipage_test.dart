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

List<Widget> lines = <Widget>[];

void main() {
  setUpAll(() {
    Document.debug = true;
    RichText.debug = true;

    for (var i = 0; i < 200; i++) {
      lines.add(Text('Line $i'));
    }
  });

  test('Pdf Widgets MultiPage', () async {
    Document.debug = true;

    final pdf = Document();

    pdf.addPage(MultiPage(build: (Context context) => lines));

    final file = File('widgets-multipage.pdf');
    await file.writeAsBytes(await pdf.save());

    final file1 = File('widgets-multipage-1.pdf');
    await file1.writeAsBytes(await pdf.save());
  });

  test('Pdf Widgets MonoPage', () async {
    Document.debug = true;

    final pdf = Document();

    pdf.addPage(Page(build: (Context context) => Column(children: lines)));

    final file = File('widgets-monopage.pdf');
    await file.writeAsBytes(await pdf.save());

    final file1 = File('widgets-monopage-1.pdf');
    await file1.writeAsBytes(await pdf.save());
  });

  test('a Column still spans across pages', () async {
    final rows = List<Widget>.generate(
      120,
      (int i) => Text('Row$i', style: const TextStyle(fontSize: 12)),
    );
    final document = Document(compress: false);
    document.addPage(
      MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (Context context) => <Widget>[Column(children: rows)],
      ),
    );

    final text = latin1.decode(await document.save(), allowInvalid: true);
    expect(document.document.pdfPageList.pages.length, 3);
    for (var i = 0; i < 120; i++) {
      expect(
        '(Row$i)'.allMatches(text).length,
        1,
        reason: 'row $i must be drawn exactly once',
      );
    }
  });

  test('a Column nested in a Column terminates', () async {
    final rows = List<Widget>.generate(
      120,
      (int i) => Text('Nested$i', style: const TextStyle(fontSize: 12)),
    );
    final document = Document(compress: false);
    document.addPage(
      MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (Context context) => <Widget>[
          Column(children: <Widget>[Column(children: rows)]),
        ],
      ),
    );

    final text = latin1.decode(await document.save(), allowInvalid: true);
    for (var i = 0; i < 120; i++) {
      expect(text, contains('(Nested$i)'), reason: 'row $i must be drawn');
    }
  });

  test('MultiPage spans a Wrap that reuses a child instance', () async {
    final spacer = SizedBox(width: 20);
    final children = <Widget>[];
    for (var i = 0; i < 12; i++) {
      children.add(Container(width: 60, height: 20, child: Text('I$i')));
      if (i != 11) {
        children.add(spacer);
      }
    }

    final document = Document(compress: false);
    document.addPage(
      MultiPage(
        pageFormat: const PdfPageFormat(240, 70, marginAll: 10),
        build: (Context context) => <Widget>[Wrap(children: children)],
      ),
    );

    final text = latin1.decode(await document.save(), allowInvalid: true);
    for (var i = 0; i < 12; i++) {
      expect(text, contains('(I$i)'), reason: 'item $i must be painted');
    }
  });
  test('a blank Text with less than a line left does not loop', () async {
    // A blank paragraph lays out one zero-span line now. TextOverflow.span would
    // hand that line to the next page, where it has no height to give back, so
    // nothing would ever make progress.
    final pdf = Document();
    pdf.addPage(
      MultiPage(
        maxPages: 4,
        pageFormat: const PdfPageFormat(200, 60, marginAll: 4),
        build: (Context context) => <Widget>[
          Text(
            'a\nb\nc',
            overflow: TextOverflow.span,
            style: const TextStyle(fontSize: 12),
          ),
          Text(
            '   ',
            overflow: TextOverflow.span,
            style: const TextStyle(fontSize: 12),
          ),
          Text('tail', style: const TextStyle(fontSize: 12)),
        ],
      ),
    );

    await expectLater(pdf.save(), completes);
  });
  test('TextStyle.height pushes a paragraph onto more pages', () async {
    Future<int> pages(double height) async {
      final pdf = Document();
      pdf.addPage(
        MultiPage(
          pageFormat: const PdfPageFormat(200, 60, marginAll: 4),
          build: (Context context) => <Widget>[
            Text(
              'The quick brown fox jumps over the lazy dog and keeps running '
              'for a while yet, and then a while longer still',
              overflow: TextOverflow.span,
              style: TextStyle(fontSize: 10, height: height),
            ),
          ],
        ),
      );
      await pdf.save();
      return pdf.document.pdfPageList.pages.length;
    }

    // The paragraph fits one 60pt page at its natural line height and needs two
    // at twice that.
    expect(await pages(1), 1);
    expect(await pages(2), 2);
  });
}
