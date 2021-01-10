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

  test('SVG Decoration', () {
    const svg =
        '<?xml version="1.0" encoding="UTF-8"?><svg version="1.1" viewBox="10 20 200 200" xmlns="http://www.w3.org/2000/svg"><defs><linearGradient id="c" x1="104.74" x2="124.51" y1="139.75" y2="207.77" gradientUnits="userSpaceOnUse"><stop stop-color="#00b11f" offset="0"/><stop stop-color="#b7feb2" offset="1"/></linearGradient><radialGradient id="b" cx="111.9" cy="-15.337" r="109.52" gradientTransform="matrix(-1.3031 .011643 -.009978 -1.1168 257.57 3.3384)" gradientUnits="userSpaceOnUse"><stop stop-color="#2b005f" offset="0"/><stop stop-color="#000d2f" stop-opacity=".96863" offset="1"/></radialGradient><radialGradient id="a" cx="44.694" cy="60.573" r="18.367" gradientTransform="matrix(1.3554 -.02668 .025662 1.3036 -17.437 -17.229)" gradientUnits="userSpaceOnUse"><stop stop-color="#fff" offset="0"/><stop stop-color="#fff" offset=".26769"/><stop offset="1"/></radialGradient></defs><rect x="1.0204" y="15.918" width="219.05" height="137.96" fill="url(#b)"/><path d="m7.3366 145.63c18.171-6.1454 39.144-16.294 58.552-17.914 9.8733-0.82444 17.181 2.9663 26.609 3.7683 6.6883 0.5689 13.518-1.197 20.165-1.628 6.1933-0.40163 12.496 0.51633 18.68 0 14.232-1.1883 28.257-5.7867 41.947-9.5924 4.7147-1.3106 9.3415-3.1133 14.216-3.7037 9.5303-1.1544 17.923 2.038 26.533 2.038l-1.0187 108.26-206.51-4.6042z" fill="url(#c)"/><ellipse cx="49.864" cy="56.735" rx="18.367" ry="18.231" fill="url(#a)"/></svg> ';

    pdf.addPage(
      Page(
        build: (context) => Container(
          decoration: const BoxDecoration(
            color: PdfColors.blue100,
            image: DecorationSvgImage(svg: svg),
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(20),
          child: PdfLogo(),
        ),
      ),
    );
  });

  tearDownAll(() async {
    final file = File('widgets-svg.pdf');
    await file.writeAsBytes(await pdf.save());
  });
}
