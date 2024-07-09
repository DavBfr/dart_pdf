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

import 'package:flutter/widgets.dart';
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
    expect(info, isInstanceOf<PrintingInfo>());
  });

  test('layoutPdf', () async {
    expect(
      await Printing.layoutPdf(
        onLayout: (_) => Uint8List(0),
        name: 'doc',
        format: PdfPageFormat.letter,
      ),
      true,
    );
  });

  test('sharePdf', () async {
    expect(
      await Printing.sharePdf(
        bytes: Uint8List(0),
      ),
      true,
    );
  });

  test('pickPrinter', () async {
    expect(
      await Printing.pickPrinter(context: MockContext()),
      null,
    );
  });

  test('directPrintPdf', () async {
    expect(
      await Printing.directPrintPdf(
        onLayout: (_) => Uint8List(0),
        printer: const Printer(url: 'test'),
      ),
      true,
    );
  });

  test('raster', () async {
    expect(
      Printing.raster(Uint8List(0)),
      isInstanceOf<Stream>(),
    );
  });

  test('test image', () async {
    final bytes = Uint8List.fromList([
      137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 1, //
      0, 0, 0, 1, 0, 1, 3, 0, 0, 0, 102, 188, 58, 37, 0, 0, 0, 3, 80, 76, 84,
      69, 181, 208, 208, 99, 4, 22, 234, 0, 0, 0, 31, 73, 68, 65, 84, 104,
      129, 237, 193, 1, 13, 0, 0, 0, 194, 160, 247, 79, 109, 14, 55, 160, 0, 0,
      0, 0, 0, 0, 0, 0, 190, 13, 33, 0, 0, 1, 154, 96, 225, 213, 0, 0, 0, 0, 73,
      69, 78, 68, 174, 66, 96, 130,
    ]);
    final imageProvider = Image.memory(bytes).image;
    expect(await flutterImageProvider(imageProvider), isNotNull);
  });
}

class MockPrinting extends Mock
    with MockPlatformInterfaceMixin
    implements PrintingPlatform {
  @override
  Future<PrintingInfo> info() async => PrintingInfo.unavailable;

  @override
  Future<bool> layoutPdf(
    Printer? printer,
    LayoutCallback onLayout,
    String name,
    PdfPageFormat format,
    bool dynamicLayout,
    bool usePrinterSettings,
    OutputType outputType,
  ) async =>
      true;

  @override
  Future<bool> sharePdf(
    Uint8List bytes,
    String filename,
    Rect bounds,
    String? subject,
    String? body,
    List<String>? emails,
  ) async =>
      true;

  @override
  Future<Printer?> pickPrinter(Rect bounds) async => null;

  @override
  Stream<PdfRaster> raster(
    Uint8List document,
    List<int>? pages,
    double dpi,
  ) async* {}
}

class MockContext extends Mock implements BuildContext {}
