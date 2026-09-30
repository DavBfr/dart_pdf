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

import 'dart:async';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/src/priv.dart';
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
    expect(const PdfNum(1e20).toString(), '100000000000000000000');
  });

  test('PdfDataTypes NumList', () {
    expect(const PdfNumList([0, 1, 2, 3]).toString(), '0 1 2 3');
  });

  test('PdfDataTypes String', () {
    expect(PdfString.fromString('test').toString(), '(test)');
    expect(PdfString.fromString('Zoé').toString(), '(Zoé)');
    expect(
      PdfString.fromString('\r\n\t\b\f)()(\\').toString(),
      r'(\r\n\t\b\f\)\(\)\(\\)',
    );
    expect(PdfString.fromString('你好').toList(), <int>[
      40,
      254,
      255,
      79,
      96,
      89,
      125,
      41,
    ]);
    expect(
      PdfString.fromDate(
        DateTime.fromMillisecondsSinceEpoch(1583606302000),
      ).toString(),
      '(D:20200307183822Z)',
    );
    expect(
      PdfString(
        Uint8List.fromList(const <int>[0, 1, 2, 3, 4, 5, 6]),
        format: PdfStringFormat.binary,
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
    expect(PdfArray([const PdfNum(1), const PdfNum(2)]).toString(), '[1 2]');
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
      PdfDict.values({
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
  test('PdfNum writes no number a reader cannot parse', () {
    // toStringAsFixed returns 'NaN', 'Infinity' or exponent notation, and ISO
    // 32000-1 7.3.3 has syntax for none of them, so the reader dropped the whole
    // operator or dictionary entry. Asserts were the only guard, and release
    // builds strip them - and these used to throw here, too.
    expect(const PdfNum(double.nan).toString(), '0');
    expect(const PdfNum(double.infinity).toString(), '0');
    expect(const PdfNum(double.negativeInfinity).toString(), '0');

    expect(const PdfNum(1e21).toString(), '1000000000000000000000');
    expect(const PdfNum(-1e21).toString(), '-1000000000000000000000');

    final grammar = RegExp(r'^-?[0-9]+(\.[0-9]+)?$');
    for (final value in <num>[
      0,
      .5,
      50.1,
      1e20,
      1e21,
      3.4e38,
      1e300,
      -1e21,
      double.nan,
      double.infinity,
      double.negativeInfinity,
      5,
      -7,
    ]) {
      final written = PdfNum(value).toString();
      expect(grammar.hasMatch(written), isTrue, reason: '$value -> "$written"');
    }

    // And through the list, which shares the formatting.
    expect(
      const PdfNumList(<num>[1, double.nan, 1e21]).toString(),
      '1 0 1000000000000000000000',
    );
  });
  test('a /MediaBox of huge numbers stays parsable', () async {
    final pdf = PdfDocument(compress: false);
    PdfPage(pdf, pageFormat: const PdfPageFormat(1e22, 1e22));

    final bytes = await pdf.save();
    final box = RegExp(
      r'/MediaBox\s*\[([^\]]*)\]',
    ).firstMatch(String.fromCharCodes(bytes))!.group(1)!;

    // HEAD wrote '0 0 1e+22 1e+22'.
    final grammar = RegExp(r'^-?[0-9]+(\.[0-9]+)?$');
    final operands = box.trim().split(RegExp(r'\s+'));
    expect(operands, hasLength(4));
    for (final operand in operands) {
      expect(grammar.hasMatch(operand), isTrue, reason: operand);
    }
  });
  test('a non-finite number is reported when verbose is on', () {
    // The assert that used to throw here is gone, so this is what replaces it:
    // a diagnostic that does not corrupt the document.
    String? capture(bool verbose) {
      String? message;
      runZoned(
        () {
          final document = PdfDocument(verbose: verbose);
          final page = PdfPage(document, pageFormat: PdfPageFormat.a4);
          const PdfNum(double.nan).output(page, PdfStream(), null);
        },
        zoneSpecification: ZoneSpecification(
          print: (Zone self, ZoneDelegate parent, Zone zone, String line) {
            message ??= line;
          },
        ),
      );
      return message;
    }

    expect(capture(false), isNull);
    expect(capture(true), contains('NaN'));
  });
}
