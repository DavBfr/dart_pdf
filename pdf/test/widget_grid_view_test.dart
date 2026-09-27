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

  tearDownAll(() async {
    final file = File('widgets-gridview.pdf');
    await file.writeAsBytes(await pdf.save());
  });
}
