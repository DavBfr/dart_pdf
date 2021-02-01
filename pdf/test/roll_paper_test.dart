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

  test('Pdf Roll Paper', () async {
    pdf.addPage(Page(
      pageFormat: PdfPageFormat.roll80,
      build: (Context? context) => Padding(
        padding: const EdgeInsets.all(30),
        child: Center(
          child: Text('Hello World!'),
        ),
      ),
    ));
  });

  test('Pdf Automatic Paper', () async {
    pdf.addPage(Page(
        pageFormat: PdfPageFormat.undefined,
        build: (Context? context) => Text('Hello World!')));
  });

  tearDownAll(() async {
    final file = File('roll-paper.pdf');
    await file.writeAsBytes(await pdf.save());
  });
}
