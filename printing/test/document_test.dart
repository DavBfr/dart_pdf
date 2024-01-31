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

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

late pw.Document doc;
pw.Font? ttf;

void main() {
  final path = Directory.current.path.split('/').last == 'test' ? '..' : '.';
  const channel = MethodChannel('net.nfet.printing');
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      // ignore: avoid_print
      print(methodCall);
      return '1';
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('flutterImageProvider(FileImage)', () async {
    final image =
        await flutterImageProvider(FileImage(File('$path/example.png')));

    doc.addPage(
      pw.Page(
        build: (pw.Context context) => pw.Center(
          child: pw.Container(
            child: pw.Image(image),
          ),
        ),
      ),
    );
  });

  setUpAll(() {
    pw.Document.debug = true;
    pw.RichText.debug = true;
    final fontData = File('$path/../pdf/open-sans.ttf').readAsBytesSync();
    ttf = pw.Font.ttf(fontData.buffer.asByteData());
    doc = pw.Document();
  });

  tearDownAll(() async {
    final file = File('printing.pdf');
    await file.writeAsBytes(await doc.save());
  });
}
