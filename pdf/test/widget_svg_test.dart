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

  test('SVG Widgets BoxFit.cover and alignment', () {
    const svg =
        '<?xml version="1.0" encoding="utf-8"?><svg version="1.1" viewBox="10 20 200 200" xmlns="http://www.w3.org/2000/svg"><circle style="fill-opacity: 0.19; fill: rgb(0, 94, 255);" cx="110" cy="120" r="90"/><rect x="10" y="20" width="200" height="200" stroke="blue" fill="none"/><line style="stroke: black;" x1="110" y1="110" x2="110" y2="130"/><line style="stroke: black" x1="100" y1="120" x2="120" y2="120"/></svg>';

    pdf.addPage(
      Page(
        build: (context) => Column(
          children: [
            GridView(
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.3,
              children: [
                for (final align in <Alignment>[
                  Alignment.topLeft,
                  Alignment.topCenter,
                  Alignment.topRight,
                  Alignment.centerLeft,
                  Alignment.center,
                  Alignment.centerRight,
                  Alignment.bottomLeft,
                  Alignment.bottomCenter,
                  Alignment.bottomRight,
                ])
                  SvgImage(
                    svg: svg,
                    fit: BoxFit.cover,
                    alignment: align,
                  ),
              ],
            ),
            SizedBox(height: 10),
            SizedBox(
              width: 180,
              child: GridView(
                crossAxisCount: 3,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 3.3,
                children: [
                  for (final align in <Alignment>[
                    Alignment.topLeft,
                    Alignment.topCenter,
                    Alignment.topRight,
                    Alignment.centerLeft,
                    Alignment.center,
                    Alignment.centerRight,
                    Alignment.bottomLeft,
                    Alignment.bottomCenter,
                    Alignment.bottomRight,
                  ])
                    SvgImage(
                      svg: svg,
                      fit: BoxFit.cover,
                      alignment: align,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  });

  tearDownAll(() async {
    final file = File('widgets-svg.pdf');
    await file.writeAsBytes(await pdf.save());
  });
}
