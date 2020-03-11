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
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pdf;
import 'package:printing/printing.dart';

pdf.Document doc;
pdf.Font ttf;

void main() {
  final String path =
      Directory.current.path.split('/').last == 'test' ? '..' : '.';
  const MethodChannel channel = MethodChannel('net.nfet.printing');
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    channel.setMockMethodCallHandler((MethodCall methodCall) async {
      print(methodCall);
      return '1';
    });
  });

  tearDown(() {
    channel.setMockMethodCallHandler(null);
  });

  test('convertHtml', () async {
    // expect(await Printing.platformVersion, '42');
  });

  test('pdfImageFromImageProvider(FileImage)', () async {
    final PdfImage image = await pdfImageFromImageProvider(
        pdf: doc.document, image: FileImage(File('$path/example.png')));

    doc.addPage(
      pdf.Page(
        build: (pdf.Context context) => pdf.Center(
          child: pdf.Container(
            child: pdf.Image(image),
          ),
        ),
      ),
    );
  });

  setUpAll(() {
    pdf.Document.debug = true;
    pdf.RichText.debug = true;
    final Uint8List fontData =
        File('$path/../pdf/open-sans.ttf').readAsBytesSync();
    ttf = pdf.Font.ttf(fontData.buffer.asByteData());
    doc = pdf.Document();
  });

  tearDownAll(() {
    final File file = File('printing.pdf');
    file.writeAsBytesSync(doc.save());
  });
}
