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

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:pdf/pdf.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:printing/printing.dart';
import 'package:printing/src/interface.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    final mock = MockPrinting();
    PrintingPlatform.instance = mock;
  });

  test('info', () async {
    final info = await Printing.info();
    expect(info, null);
  });

  test('layoutPdf', () async {
    expect(
      () async => await Printing.layoutPdf(onLayout: null),
      throwsAssertionError,
    );

    expect(
        await Printing.layoutPdf(
          onLayout: (_) => null,
          name: 'doc',
          format: PdfPageFormat.letter,
        ),
        null);
  });

  test('sharePdf', () async {
    expect(
      () async => await Printing.sharePdf(bytes: null),
      throwsAssertionError,
    );

    expect(
      await Printing.sharePdf(
        bytes: Uint8List(0),
      ),
      null,
    );
  });

  test('pickPrinter', () async {
    expect(
      await Printing.pickPrinter(context: null),
      null,
    );
  });

  test('directPrintPdf', () async {
    expect(
      await Printing.directPrintPdf(onLayout: null, printer: null),
      false,
    );

    expect(
      () async => await Printing.directPrintPdf(
        onLayout: null,
        printer: const Printer(url: 'test'),
      ),
      throwsAssertionError,
    );

    expect(
      await Printing.directPrintPdf(
        onLayout: (_) => null,
        printer: const Printer(url: 'test'),
      ),
      null,
    );
  });

  test('convertHtml', () async {
    expect(
      await Printing.convertHtml(html: '<html></html>'),
      null,
    );
  });

  test('raster', () async {
    expect(
      () => Printing.raster(null),
      throwsAssertionError,
    );

    expect(
      Printing.raster(Uint8List(0)),
      null,
    );
  });
}

class MockPrinting extends Mock
    with MockPlatformInterfaceMixin
    implements PrintingPlatform {}
