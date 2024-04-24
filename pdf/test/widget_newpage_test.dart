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

Widget footer(Context context) {
  return Footer(
    trailing: Container(
      height: 25,
      child: Text('Page ${context.pageNumber}'),
    ),
  );
}

Widget header(Context context) {
  return Container(
    height: 20,
    child: Text('Test document'),
  );
}

List<Widget> contentWithPageBreak(double? freeSpace) {
  return [
    Container(
      color: const PdfColor(0.75, 0.75, 0.75),
      height: 50,
      width: 100,
      child: Text('Page 1'),
    ),
    Container(
      color: const PdfColor(0.6, 0.6, 0.6),
      height: 40,
      width: 100,
    ),
    Container(
      color: const PdfColor(0.5, 0.5, 0.5),
      height: 20,
      width: 100,
    ),
    NewPage(freeSpace: freeSpace),
    Text('Page 2'),
  ];
}

void main() {
  setUpAll(() {
    Document.debug = true;
    RichText.debug = true;
    pdf = Document();
  });

  const pageFormatWithoutMargins = PdfPageFormat(200.0, 200.0);
  const pageFormatWithMargins =
      PdfPageFormat(200.0, 200.0, marginTop: 10, marginBottom: 20);

  // PageHeight - Content Height
  // 200 - 110 = 90 available space
  test('PageBreak normal on page without margins', () {
    pdf.addPage(MultiPage(
      pageFormat: pageFormatWithoutMargins,
      build: (_) => contentWithPageBreak(null),
    ));
  });

  test('No PageBreak, because enough space available', () {
    pdf.addPage(MultiPage(
      pageFormat: pageFormatWithoutMargins,
      build: (_) => contentWithPageBreak(90),
    ));
  });

  test('PageBreak because more free space needed', () {
    pdf.addPage(MultiPage(
      pageFormat: pageFormatWithoutMargins,
      build: (_) => contentWithPageBreak(91),
    ));
  });

  // PageHeight - Margins - Content Height
  // 200 - 10 - 20 - 20 - 25 - 110 = 15
  test('PageBreak normal on page with margins, header and footer', () {
    pdf.addPage(MultiPage(
      pageFormat: pageFormatWithMargins,
      build: (_) => contentWithPageBreak(null),
      header: header,
      footer: footer,
    ));
  });

  test('No PageBreak, because enough space available', () {
    pdf.addPage(MultiPage(
      pageFormat: pageFormatWithMargins,
      build: (_) => contentWithPageBreak(15.0),
      header: header,
      footer: footer,
    ));
  });

  test('PageBreak because more free space needed', () {
    pdf.addPage(MultiPage(
      pageFormat: pageFormatWithMargins,
      build: (_) => contentWithPageBreak(16.0),
      header: header,
      footer: footer,
    ));
  });

  tearDownAll(() async {
    final file = File('widgets-newpage.pdf');
    await file.writeAsBytes(await pdf.save());
  });
}
