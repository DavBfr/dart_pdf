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

import 'dart:typed_data';

import 'package:pdf/src/pdf/data_types.dart';
import 'package:test/test.dart';

void main() {
  test('PdfDataTypes Bool ', () {
    expect(const PdfBool(true).toString(), 'true');
    expect(const PdfBool(false).toString(), 'false');
  });

  test('PdfDataTypes Name ', () {
    expect(const PdfName('/Test').toString(), '/Test');
    expect(const PdfName('/Type 1').toString(), '/Type#201');
    expect(const PdfName('/Num#1').toString(), '/Num#231');
  });

  test('PdfDataTypes Num', () {
    expect(const PdfNum(0).toString(), '0');
    expect(const PdfNum(.5).toString(), '0.5');
    expect(const PdfNum(50).toString(), '50');
    expect(const PdfNum(50.1).toString(), '50.1');
  });

  test('PdfDataTypes NumList', () {
    expect(const PdfNumList([0, 1, 2, 3]).toString(), '0 1 2 3');
  });

  test('PdfDataTypes String', () {
    expect(PdfString.fromString('test').toString(), '(test)');
    expect(PdfString.fromString('Zoé').toString(), '(Zoé)');
    expect(PdfString.fromString('\r\n\t\b\f)()(\\').toString(),
        r'(\r\n\t\b\f\)\(\)\(\\)');
    expect(
      PdfString.fromString('你好').toList(),
      <int>[40, 254, 255, 79, 96, 89, 125, 41],
    );
    expect(
      PdfString.fromDate(DateTime.fromMillisecondsSinceEpoch(1583606302000))
          .toString(),
      '(D:20200307183822Z)',
    );
    expect(
      PdfString(
        Uint8List.fromList(const <int>[0, 1, 2, 3, 4, 5, 6]),
        PdfStringFormat.binary,
      ).toString(),
      '<00010203040506>',
    );
  });

  test('PdfDataTypes Name', () {
    expect(const PdfName('/Hello').toString(), '/Hello');
  });

  test('PdfDataTypes Null', () {
    expect(const PdfNull().toString(), 'null');
  });

  test('PdfDataTypes Indirect', () {
    expect(const PdfIndirect(30, 4).toString(), '30 4 R');
  });

  test('PdfDataTypes Array', () {
    expect(PdfArray().toString(), '[]');
    expect(
      PdfArray([const PdfNum(1), const PdfNum(2)]).toString(),
      '[1 2]',
    );
    expect(
      PdfArray([
        const PdfName('/Name'),
        const PdfName('/Other'),
        const PdfBool(false),
        const PdfNum(2.5),
        const PdfNull(),
        PdfString.fromString('helło'),
        PdfArray(),
        PdfDict(),
      ]).toString(),
      '[/Name/Other false 2.5 null(þÿ\x00h\x00e\x00l\x01B\x00o)[]<<>>]',
    );
  });

  test('PdfDataTypes Dict', () {
    expect(PdfDict().toString(), '<<>>');

    expect(
      PdfDict({
        '/Name': const PdfName('/Value'),
        '/Bool': const PdfBool(true),
        '/Num': const PdfNum(42),
        '/String': PdfString.fromString('hello'),
        '/Null': const PdfNull(),
        '/Indirect': const PdfIndirect(55, 0),
        '/Array': PdfArray(),
        '/Dict': PdfDict(),
      }).toString(),
      '<</Name/Value/Bool true/Num 42/String(hello)/Null null/Indirect 55 0 R/Array[]/Dict<<>>>>',
    );
  });
}
