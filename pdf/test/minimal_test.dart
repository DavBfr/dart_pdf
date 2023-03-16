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

import 'package:pdf/src/priv.dart';
import 'package:test/test.dart';

class BasicObject extends PdfObjectBase {
  const BasicObject(int objser) : super(objser: objser);

  @override
  bool get verbose => true;

  void write(PdfStream os, PdfDataType value) {
    os.putString('$objser $objgen obj\n');
    value.output(this, os, verbose ? 0 : null);
    os.putByte(0x0a);
    os.putString('endobj\n');
  }
}

void main() {
  test('Pdf Minimal', () async {
    final pages = PdfDict({
      '/Type': const PdfName('/Pages'),
      '/Count': const PdfNum(1),
    });

    final page = PdfDict({
      '/Type': const PdfName('/Page'),
      '/Parent': const PdfIndirect(2, 0),
      '/MediaBox': PdfArray.fromNum([0, 0, 595.27559, 841.88976]),
      '/Resources': PdfDict({
        '/ProcSet': PdfArray([
          const PdfName('/PDF'),
        ]),
      }),
      '/Contents': const PdfIndirect(4, 0),
    });

    final content = PdfDictStream(
      data: latin1.encode('30 811.88976 m 200 641.88976 l S'),
    );

    pages['/Kids'] = PdfArray([const PdfIndirect(3, 0)]);

    final catalog = PdfDict({
      '/Type': const PdfName('/Catalog'),
      '/Pages': const PdfIndirect(2, 0),
    });

    final os = PdfStream();

    final xref = PdfXrefTable();

    os.putString('%PDF-1.4\n');
    os.putBytes(const <int>[0x25, 0xC2, 0xA5, 0xC2, 0xB1, 0xC3, 0xAB, 0x0A]);

    xref.add(PdfXref(1, os.offset));
    final cat = const BasicObject(1)..write(os, catalog);
    xref.add(PdfXref(2, os.offset));
    const BasicObject(2).write(os, pages);
    xref.add(PdfXref(3, os.offset));
    const BasicObject(3).write(os, page);
    xref.add(PdfXref(4, os.offset));
    const BasicObject(4).write(os, content);

    final xrefOffset = xref.outputLegacy(
        cat,
        os,
        PdfDict({
          '/Size': PdfNum(xref.offsets.length + 1),
          '/Root': const PdfIndirect(1, 0),
        }));

    os.putString('startxref\n$xrefOffset\n%%EOF\n');

    final file = File('minimal.pdf');
    await file.writeAsBytes(os.output());
  });
}
