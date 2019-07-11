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

import 'package:pdf/pdf.dart';
import 'package:test/test.dart';
import 'package:pdf/widgets.dart';

Document pdf;
Font openSans;
Font openSansBold;
Font roboto;
Font notoSans;
Font genyomintw;

Font loadFont(String filename) {
  final Uint8List data = File(filename).readAsBytesSync();
  return Font.ttf(data.buffer.asByteData());
}

void main() {
  setUpAll(() {
    Document.debug = true;
    RichText.debug = true;

    openSans = loadFont('open-sans.ttf');
    openSansBold = loadFont('open-sans-bold.ttf');
    roboto = loadFont('roboto.ttf');
    notoSans = loadFont('noto-sans.ttf');
    genyomintw = loadFont('genyomintw.ttf');

    pdf = Document();
  });

  test('Theme FontStyle', () {
    final TextStyle style = TextStyle(
        font: roboto,
        fontBold: openSansBold,
        fontNormal: openSans,
        fontItalic: notoSans,
        fontBoldItalic: genyomintw,
        fontWeight: FontWeight.bold,
        fontSize: 20,
        color: PdfColors.blue);

    pdf.addPage(Page(
      build: (Context context) => ListView(
        children: <Widget>[
          Text(
            style.font.fontName,
            style: style,
          ),
        ],
      ),
    ));
  });

  tearDownAll(() {
    final File file = File('widgets-theme.pdf');
    file.writeAsBytesSync(pdf.save());
  });
}
