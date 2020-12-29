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

Document pdf;

void main() {
  setUpAll(() {
    Document.debug = true;
    pdf = Document();
  });

  test('SVG Widgets Flutter logo', () {
    pdf.addPage(
      Page(
        build: (context) => Center(
          child: FlutterLogo(),
        ),
      ),
    );
  });

  test('SVG Widgets', () {
    print('=' * 120);
    final dir = Directory('../ref/svg');
    if (!dir.existsSync()) {
      return;
    }
    final files = dir
        .listSync()
        .where((file) => file.path.endsWith('.svg'))
        .map<String>((file) => file.path)
        .toList()
          ..sort();

    pdf.addPage(
      MultiPage(
        build: (context) => [
          GridView(
            crossAxisCount: 2,
            childAspectRatio: 1,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            children: files.map<Widget>(
              (file) {
                return Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: PdfColors.blue),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    children: <Widget>[
                      Expanded(
                        child: Center(
                          child: SvgImage(
                            svg: File(file).readAsStringSync(),
                          ),
                        ),
                      ),
                      ClipRect(
                        child: Text(file.substring(file.lastIndexOf('/') + 1)),
                      ),
                    ],
                  ),
                );
              },
            ).toList(),
          )
        ],
      ),
    );
  });

  test('SVG Widgets Text', () {
    pdf.addPage(
      Page(
        build: (context) => SvgImage(
          svg:
              '<?xml version="1.0" standalone="no"?><!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd"><svg viewBox="0 0 1000 300" xmlns="http://www.w3.org/2000/svg" version="1.1"><text x="367.055" y="168.954" font-size="55" fill="dodgerblue" >Hello, PDF</text><rect x="1" y="1" width="998" height="298" fill="none" stroke="purple" stroke-width="2" /></svg>',
        ),
      ),
    );
  });

  test('SVG Widgets Barcode', () {
    pdf.addPage(
      Page(
        build: (context) => SvgImage(
          svg: Barcode.isbn().toSvg('135459869354'),
        ),
      ),
    );
  });

  tearDownAll(() async {
    final file = File('widgets-svg.pdf');
    await file.writeAsBytes(await pdf.save());
  });
}
