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

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart';
import 'package:test/test.dart';

import 'utils.dart';

Document pdf;
Font icons;

void main() {
  setUpAll(() {
    Document.debug = true;
    pdf = Document();
    icons = loadFont('material.ttf');
  });

  test('Icon Widgets', () {
    pdf.addPage(
      MultiPage(
        theme: ThemeData.withFont(icons: icons),
        build: (Context context) {
          final iconList = <IconData>[];
          final pdfFont = icons.getFont(context);
          if (pdfFont is PdfTtfFont) {
            iconList.addAll(
              pdfFont.font.charToGlyphIndexMap.keys
                  .where((e) => e > 0x7f && e < 0xe05d)
                  .map((e) => IconData(e)),
            );
          }

          return <Widget>[
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                ...iconList.map<Widget>(
                  (e) => Column(children: [
                    Icon(e, size: 50, color: PdfColors.blueGrey),
                    Text('0x${e.codePoint.toRadixString(16)}'),
                  ]),
                ),
              ],
            ),
          ];
        },
      ),
    );
  });

  tearDownAll(() {
    final file = File('widgets-icons.pdf');
    file.writeAsBytesSync(pdf.save());
  });
}
