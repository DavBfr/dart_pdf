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
import 'package:pdf/widgets.dart';
import 'package:test/test.dart';

/// Lay a gradient out alone on a small page and return the raw PDF.
Future<String> gradient(Gradient gradient) async {
  final document = Document(compress: false);
  document.addPage(
    Page(
      pageFormat: const PdfPageFormat(200, 200),
      build: (Context context) => Container(
        width: 100,
        height: 50,
        decoration: BoxDecoration(gradient: gradient),
      ),
    ),
  );
  return String.fromCharCodes(await document.save());
}

/// The body of every function dictionary in [pdf].
List<String> functions(String pdf) => RegExp(
  r'/FunctionType[^>]*',
).allMatches(pdf).map((m) => m.group(0)!).toList();

void main() {
  test('a two stop gradient interpolates linearly', () async {
    // /Order was written from a field that meant components per sample, so every
    // gradient carried /Order 3 - cubic - over the two samples it interpolates.
    // Cubic interpolation needs four. /Order 1 is the default and is not written.
    final pdf = await gradient(
      const LinearGradient(colors: <PdfColor>[PdfColors.red, PdfColors.blue]),
    );

    expect(pdf, isNot(contains('/Order')));
    expect(functions(pdf), hasLength(1));
    expect(functions(pdf).single, contains('/Size[2]'));
    expect(functions(pdf).single, contains('/Range[0 1 0 1 0 1]'));
    expect(functions(pdf).single, contains('/BitsPerSample 8'));
  });

  test('a stitching function has no /Order at all', () async {
    // /Order has no meaning in a FunctionType 3 dictionary; it was hard-coded.
    final pdf = await gradient(
      const LinearGradient(
        colors: <PdfColor>[PdfColors.red, PdfColors.green, PdfColors.blue],
        stops: <double>[0, 0.3, 1],
      ),
    );

    final stitching = functions(
      pdf,
    ).where((String f) => f.startsWith('/FunctionType 3'));

    expect(stitching, hasLength(1));
    expect(stitching.single, isNot(contains('/Order')));
    expect(stitching.single, contains('/Bounds[0.3]'));
    expect(pdf, isNot(contains('/Order')));
  });

  test('fromColors sizes itself from the colours it was given', () {
    for (final count in <int>[2, 3, 5]) {
      final document = PdfDocument();
      final fn = PdfFunction.fromColors(
        document,
        List<PdfColor>.generate(count, (int i) => PdfColors.red),
      )..prepare();

      expect(fn.params['/Size'].toString(), '[$count]', reason: '$count');
      expect(fn.buf.output(), hasLength(count * 3), reason: '$count');
      expect(fn.params.containsKey('/Order'), isFalse, reason: '$count');
    }
  });

  test('the smask transfer function is two samples of one output', () {
    final fn = PdfFunction(PdfDocument(), data: <int>[255, 0])..prepare();

    expect(fn.params['/Size'].toString(), '[2]');
    expect(fn.params['/Range'].toString(), '[0 1]');
    expect(fn.params.containsKey('/Order'), isFalse);
  });

  test('an order the spec does not define fails loudly', () {
    expect(
      () => PdfFunction(PdfDocument(), data: <int>[0, 255], order: 2),
      throwsA(isA<PdfException>()),
    );
    expect(
      () => PdfFunction(PdfDocument(), data: <int>[0, 255], order: 0),
      throwsA(isA<PdfException>()),
    );
  });

  test('cubic interpolation needs four samples', () {
    expect(
      () => PdfFunction(PdfDocument(), data: <int>[0, 255], order: 3).prepare(),
      throwsA(isA<PdfException>()),
    );

    final fn = PdfFunction(
      PdfDocument(),
      data: <int>[0, 85, 170, 255],
      order: 3,
    )..prepare();

    expect(fn.params['/Size'].toString(), '[4]');
    expect(fn.params['/Order'].toString(), '3');
  });

  test('a four bit sample counts two samples to the byte', () {
    final fn = PdfFunction(
      PdfDocument(),
      data: <int>[0x0f, 0xf0],
      bitsPerSample: 4,
    )..prepare();

    expect(fn.params['/Size'].toString(), '[4]');
    expect(fn.params['/BitsPerSample'].toString(), '4');
  });
}
