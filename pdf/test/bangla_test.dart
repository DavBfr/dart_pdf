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

// ignore_for_file: omit_local_variable_types

import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart';
import 'package:test/test.dart';

Document pdf;
Font font;
TextStyle style;

void main() {
  setUpAll(() {
    Document.debug = false;
    RichText.debug = true;
    pdf = Document();

    final Uint8List fontData = File('siyamrupali.ttf').readAsBytesSync();
    font = Font.ttf(fontData.buffer.asByteData());
    style = TextStyle(font: font, fontSize: 30);
  });

  test('Bangla text', () {
    pdf.addPage(
      Page(
        pageFormat: PdfPageFormat.a4,
        build: (Context context) => Text(
          'পরীক্ষার রুটিন ও সময়সূচী',
          style: TextStyle(font: font, fontSize: 30),
        ),
      ),
    );
  });

  tearDownAll(() {
    final File file = File('bangla.pdf');
    file.writeAsBytesSync(pdf.save());
  });
}
