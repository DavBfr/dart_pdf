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
import 'package:pdf/src/priv.dart';
import 'package:test/test.dart';

void main() {
  test('Pdf Minimal', () async {
    var objser = 1;

    const settings = PdfSettings(
      verbose: true,
      version: PdfVersion.pdf_1_4,
    );

    final pages = PdfObjectBase(
        objser: objser++,
        settings: settings,
        params: PdfDict({
          '/Type': const PdfName('/Pages'),
          '/Count': const PdfNum(1),
        }));

    final content = PdfObjectBase(
        objser: objser++,
        settings: settings,
        params: PdfDictStream(
          data: latin1.encode('30 811.88976 m 200 641.88976 l S'),
        ));

    final page = PdfObjectBase(
        objser: objser++,
        settings: settings,
        params: PdfDict({
          '/Type': const PdfName('/Page'),
          '/Parent': pages.ref(),
          '/MediaBox': PdfArray.fromNum([0, 0, 595.27559, 841.88976]),
          '/Resources': PdfDict({
            '/ProcSet': PdfArray([
              const PdfName('/PDF'),
            ]),
          }),
          '/Contents': content.ref(),
        }));

    pages.params['/Kids'] = PdfArray([page.ref()]);

    final catalog = PdfObjectBase(
        objser: objser++,
        settings: settings,
        params: PdfDict({
          '/Type': const PdfName('/Catalog'),
          '/Pages': pages.ref(),
        }));

    final os = PdfStream();

    final xref = PdfXrefTable();
    xref.objects.addAll([
      catalog,
      pages,
      page,
      content,
    ]);

    xref.output(catalog, os);

    final file = File('minimal.pdf');
    await file.writeAsBytes(os.output());
  });
}
