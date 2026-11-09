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
import 'package:pdf/widgets.dart' as pw;
import 'package:test/test.dart';

void main() {
  test('page number lookup is stable across repeated reads and copies', () {
    final doc = PdfDocument();
    final first = PdfPage(doc);
    final second = PdfPage(doc);
    final context = pw.Context(document: doc, page: second);
    expect(context.pageNumber, 2);
    for (var i = 0; i < 500; i++) {
      expect(context.pageNumber, 2);
      expect(context.pageLabel, '2');
    }
    expect(context.copyWith().pageNumber, 2);
    expect(pw.Context(document: doc, page: first).pageNumber, 1);
  });

  test('cached page number is invalidated when a page is inserted ahead', () {
    final doc = PdfDocument();
    PdfPage(doc);
    final target = PdfPage(doc);
    final context = pw.Context(document: doc, page: target);
    expect(context.pageNumber, 2);

    final inheritedContext = context.copyWith();
    final inserted = PdfPage(doc, index: 1);
    expect(context.pageNumber, 3);
    expect(inheritedContext.pageNumber, 3);
    expect(pw.Context(document: doc, page: inserted).pageNumber, 2);

    final other = PdfPage(doc);
    expect(context.copyWith(page: other).pageNumber, 4);
    expect(context.pageNumber, 3);
  });

  test('cache is shared by contexts copied before the first lookup', () {
    final doc = PdfDocument();
    final first = PdfPage(doc);
    final target = PdfPage(doc);
    final context = pw.Context(document: doc, page: target);
    final copy = context.copyWith();
    expect(copy.pageNumber, 2);
    expect(context.pageNumber, 2);

    doc.pdfPageList.pages.remove(first);
    expect(context.pageNumber, 1);
    expect(copy.pageNumber, 1);
  });

  test('MultiPage inserted ahead of a page numbers its headers', () {
    final doc = pw.Document();
    final numbers = <int>[];
    doc.addPage(pw.Page(build: (context) => pw.Text('last')));
    doc.addPage(
      pw.MultiPage(
        header: (context) {
          numbers.add(context.pageNumber);
          return pw.Text('${context.pageNumber}');
        },
        footer: (context) => pw.Text(context.pageLabel),
        build: (context) => [
          for (var i = 0; i < 3; i++) pw.Container(height: 600),
        ],
      ),
      index: 0,
    );
    expect(numbers, <int>[1, 2, 3]);
  });
}
