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

import 'package:test/test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart';

Document pdf;

Widget content(Context context) {
  return ListView(children: contentMultiPage(context));
}

Widget footer(Context context) {
  return Footer(
    trailing: Text('Page ${context.pageNumber}'),
  );
}

Widget header(Context context) {
  return Footer(
    title: Text('Test document'),
  );
}

List<Widget> contentMultiPage(Context context) {
  return List<Widget>.generate(
    150,
    (int n) => Container(
        height: 20,
        child: Text(
          'Hello World $n!',
          style: TextStyle(fontSize: 15),
        )),
  );
}

void main() {
  setUpAll(() {
    Document.debug = true;
    pdf = Document();
  });

  test('Orientation normal', () {
    pdf.addPage(Page(
      clip: true,
      build: content,
    ));
  });

  test('Orientation landscape', () {
    pdf.addPage(Page(
      clip: true,
      pageFormat: PdfPageFormat.standard.portrait,
      orientation: PageOrientation.landscape,
      build: content,
    ));
    pdf.addPage(Page(
      clip: true,
      pageFormat: PdfPageFormat.standard.landscape,
      orientation: PageOrientation.landscape,
      build: content,
    ));
  });

  test('Orientation portrait', () {
    pdf.addPage(Page(
      clip: true,
      pageFormat: PdfPageFormat.standard.portrait,
      orientation: PageOrientation.portrait,
      build: content,
    ));
    pdf.addPage(Page(
      clip: true,
      pageFormat: PdfPageFormat.standard.landscape,
      orientation: PageOrientation.portrait,
      build: content,
    ));
  });

  test('Orientation MultiPage normal', () {
    pdf.addPage(MultiPage(
      build: contentMultiPage,
      header: header,
      footer: footer,
    ));
  });

  test('Orientation MultiPage landscape', () {
    pdf.addPage(MultiPage(
      pageFormat: PdfPageFormat.standard.portrait,
      orientation: PageOrientation.landscape,
      build: contentMultiPage,
      header: header,
      footer: footer,
    ));
    pdf.addPage(MultiPage(
      pageFormat: PdfPageFormat.standard.landscape,
      orientation: PageOrientation.landscape,
      build: contentMultiPage,
      header: header,
      footer: footer,
    ));
  });

  test('Orientation MultiPage portrait', () {
    pdf.addPage(MultiPage(
      pageFormat: PdfPageFormat.standard.portrait,
      orientation: PageOrientation.portrait,
      build: contentMultiPage,
      header: header,
      footer: footer,
    ));
    pdf.addPage(MultiPage(
      pageFormat: PdfPageFormat.standard.landscape,
      orientation: PageOrientation.portrait,
      build: contentMultiPage,
      header: header,
      footer: footer,
    ));
  });

  tearDownAll(() {
    final File file = File('orientation.pdf');
    file.writeAsBytesSync(pdf.save());
  });
}
