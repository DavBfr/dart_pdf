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

late Document pdf;

final _blueBox = Container(
  width: 50,
  height: 50,
  color: PdfColors.blue,
);

final _redBox = Container(
  width: 50,
  height: 50,
  color: PdfColors.red,
);

final _yellowBox = Container(
  width: 50,
  height: 50,
  color: PdfColors.yellow,
);

void main() {
  setUpAll(() {
    Document.debug = true;
    pdf = Document();
  });

  test('RTL Text', () {
    pdf.addPage(
      Page(
        textDirection: TextDirection.rtl,
        pageFormat: const PdfPageFormat(150, 50),
        build: (Context context) => Text(
          'RTL Text',
        ),
      ),
    );
  });
  test('RTL Text TextAlign.end', () {
    pdf.addPage(
      Page(
        textDirection: TextDirection.rtl,
        pageFormat: const PdfPageFormat(150, 50),
        build: (Context context) => SizedBox(
          width: 150,
          child: Text(
            'RTL Text : TextAlign.end',
            textAlign: TextAlign.end,
          ),
        ),
      ),
    );
  });

  test('RTL Text TextAlign.left', () {
    pdf.addPage(
      Page(
        textDirection: TextDirection.rtl,
        pageFormat: const PdfPageFormat(150, 50),
        build: (Context context) => SizedBox(
          width: 150,
          child: Text(
            'RTL Text : TextAlign.left',
            textAlign: TextAlign.left,
          ),
        ),
      ),
    );
  });

  test('LTR Text', () {
    pdf.addPage(
      Page(
        textDirection: TextDirection.ltr,
        pageFormat: const PdfPageFormat(150, 50),
        build: (Context context) => Text(
          'LTR Text',
        ),
      ),
    );
  });
  test('LTR Text TextAlign.end', () {
    pdf.addPage(
      Page(
        textDirection: TextDirection.ltr,
        pageFormat: const PdfPageFormat(150, 50),
        build: (Context context) => SizedBox(
          width: 150,
          child: Text(
            'RTL Text : TextAlign.end',
            textAlign: TextAlign.end,
          ),
        ),
      ),
    );
  });

  test('LTR Text TextAlign.right', () {
    pdf.addPage(
      Page(
        textDirection: TextDirection.ltr,
        pageFormat: const PdfPageFormat(150, 50),
        build: (Context context) => SizedBox(
          width: 150,
          child: Text(
            'LTR Text : TextAlign.right',
            textAlign: TextAlign.right,
          ),
        ),
      ),
    );
  });

  test(
      'Should render a blue box followed by a red box ordered RTL aligned right',
      () {
    pdf.addPage(
      Page(
        textDirection: TextDirection.rtl,
        pageFormat: const PdfPageFormat(150, 50),
        build: (Context context) => TestAnnotation(
          anno: 'RTL Row',
          child: Row(
            children: [_blueBox, _redBox],
          ),
        ),
      ),
    );
  });

  test(
      'Should render a blue box followed by a red box ordered RTL with aligned center',
      () {
    pdf.addPage(
      Page(
        textDirection: TextDirection.rtl,
        pageFormat: const PdfPageFormat(150, 50),
        build: (Context context) => TestAnnotation(
          anno: 'RTL Row MainAlignment.center',
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [_blueBox, _redBox],
          ),
        ),
      ),
    );
  });

  test(
      'Should render a blue box followed by a red box ordered RTL with CrossAxisAlignment.end aligned right',
      () {
    pdf.addPage(
      Page(
        pageFormat: const PdfPageFormat(150, 100),
        textDirection: TextDirection.rtl,
        build: (Context context) => TestAnnotation(
          anno: 'RTL Row CrossAlignment.end',
          child: SizedBox(
            width: 150,
            height: 100,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [_blueBox, _redBox],
            ),
          ),
        ),
      ),
    );
  });
  test(
      'Should render a blue box followed by a red box ordered LTR aligned left',
      () {
    pdf.addPage(
      Page(
        pageFormat: const PdfPageFormat(150, 50),
        build: (Context context) => TestAnnotation(
          anno: 'LTR Row',
          child: Row(
            children: [_blueBox, _redBox],
          ),
        ),
      ),
    );
  });
  test(
      'Should render a blue box followed by a red box ordered TTB aligned right',
      () {
    pdf.addPage(
      Page(
        textDirection: TextDirection.rtl,
        pageFormat: const PdfPageFormat(150, 150),
        build: (Context context) => TestAnnotation(
          anno: 'RTL Column crossAlignment.start',
          child: SizedBox(
            width: 150,
            height: 150,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [_blueBox, _redBox],
            ),
          ),
        ),
      ),
    );
  });
  test(
      'Should render a blue box followed by a red box ordered TTB aligned left',
      () {
    pdf.addPage(
      Page(
        textDirection: TextDirection.ltr,
        pageFormat: const PdfPageFormat(150, 150),
        build: (Context context) => TestAnnotation(
          anno: 'LTR Column crossAlignment.start',
          child: SizedBox(
            width: 150,
            height: 150,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [_blueBox, _redBox],
            ),
          ),
        ),
      ),
    );
  });

  test('Wrap Should render blue,red,yellow ordered RTL', () {
    pdf.addPage(
      Page(
        textDirection: TextDirection.rtl,
        pageFormat: const PdfPageFormat(150, 150),
        build: (Context context) => TestAnnotation(
          anno: 'RTL Wrap',
          child: SizedBox(
            width: 150,
            height: 150,
            child: Wrap(
              children: [_blueBox, _redBox, _yellowBox],
            ),
          ),
        ),
      ),
    );
  });

  test('Wrap Should render blue,red,yellow ordered LTR', () {
    pdf.addPage(
      Page(
        textDirection: TextDirection.ltr,
        pageFormat: const PdfPageFormat(150, 150),
        build: (Context context) => TestAnnotation(
          anno: 'LTR Wrap',
          child: SizedBox(
            width: 150,
            height: 150,
            child: Wrap(
              children: [_blueBox, _redBox, _yellowBox],
            ),
          ),
        ),
      ),
    );
  });
  test('Wrap Should render blue,red,yellow ordered RTL aligned center', () {
    pdf.addPage(
      Page(
        textDirection: TextDirection.rtl,
        pageFormat: const PdfPageFormat(150, 150),
        build: (Context context) => TestAnnotation(
          anno: 'RTL Wrap WrapAlignment.center',
          child: SizedBox(
            width: 150,
            height: 150,
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              runAlignment: WrapAlignment.center,
              children: [_blueBox, _redBox, _yellowBox],
            ),
          ),
        ),
      ),
    );
  });

  test('Wrap Should render blue,red,yellow ordered RTL aligned bottom', () {
    pdf.addPage(
      Page(
        textDirection: TextDirection.rtl,
        pageFormat: const PdfPageFormat(150, 150),
        build: (Context context) => TestAnnotation(
          anno: 'RTL Wrap WrapAlignment.end',
          child: SizedBox(
              width: 150,
              height: 150,
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                runAlignment: WrapAlignment.end,
                children: [_blueBox, _redBox, _yellowBox],
              )),
        ),
      ),
    );
  });

  test('RTL Page Should render child aligned right', () {
    pdf.addPage(
      Page(
        textDirection: TextDirection.rtl,
        pageFormat: const PdfPageFormat(150, 150),
        build: (Context context) {
          return TestAnnotation(
            anno: 'RTL Page',
            child: _blueBox,
          );
        },
      ),
    );
  });

  test('LTR Page Should render child aligned left', () {
    pdf.addPage(
      Page(
        textDirection: TextDirection.ltr,
        pageFormat: const PdfPageFormat(150, 150),
        build: (Context context) {
          return TestAnnotation(
            anno: 'LTR Page',
            child: _blueBox,
          );
        },
      ),
    );
  });

  test('RTL Multi Page Should render child aligned right', () {
    pdf.addPage(
      MultiPage(
        textDirection: TextDirection.rtl,
        pageFormat: const PdfPageFormat(150, 150),
        build: (Context context) {
          return [
            Text('RTL MultiPage', style: const TextStyle(fontSize: 9)),
            ListView(
              children: [
                for (int i = 0; i < 15; i++) Text('List item'),
              ],
            ),
          ];
        },
      ),
    );
  });

  test('LTR Multi Page Should render child aligned left', () {
    pdf.addPage(
      MultiPage(
        textDirection: TextDirection.ltr,
        pageFormat: const PdfPageFormat(150, 150),
        build: (Context context) {
          return [
            Text('LTR MultiPage', style: const TextStyle(fontSize: 9)),
            ListView(children: [
              for (int i = 0; i < 15; i++) Text('List item'),
            ]),
          ];
        },
      ),
    );
  });

  test('Should render a blue box padded from right', () {
    pdf.addPage(
      Page(
        textDirection: TextDirection.rtl,
        pageFormat: const PdfPageFormat(150, 150),
        build: (Context context) {
          return TestAnnotation(
            anno: 'RTL Padded start',
            child: Padding(
              padding: const EdgeInsetsDirectional.only(start: 20),
              child: _blueBox,
            ),
          );
        },
      ),
    );
  });

  test('Should render a blue box padded from left', () {
    pdf.addPage(
      Page(
        textDirection: TextDirection.ltr,
        pageFormat: const PdfPageFormat(150, 150),
        build: (Context context) {
          return TestAnnotation(
            anno: 'LTR Padded start',
            child: Padding(
              padding: const EdgeInsetsDirectional.only(start: 20),
              child: _blueBox,
            ),
          );
        },
      ),
    );
  });

  test('Should render a blue box aligned center right', () {
    pdf.addPage(
      Page(
        textDirection: TextDirection.rtl,
        pageFormat: const PdfPageFormat(150, 150),
        build: (Context context) {
          return TestAnnotation(
            anno: 'RTL Align directional.centerStart',
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: _blueBox,
            ),
          );
        },
      ),
    );
  });

  test('Should render a blue box aligned center left', () {
    pdf.addPage(
      Page(
        textDirection: TextDirection.ltr,
        pageFormat: const PdfPageFormat(150, 150),
        build: (Context context) {
          return TestAnnotation(
            anno: 'LTR Align directional.centerStart',
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: _blueBox,
            ),
          );
        },
      ),
    );
  });

  test('Should render a box with top-right curved corner', () {
    pdf.addPage(
      Page(
        textDirection: TextDirection.rtl,
        pageFormat: const PdfPageFormat(150, 150),
        build: (Context context) {
          return TestAnnotation(
            anno: 'RTL RadiusDirectional.only topStart',
            child: Container(
              margin: const EdgeInsets.only(top: 11),
              decoration: const BoxDecoration(
                color: PdfColors.blue,
                borderRadius: BorderRadiusDirectional.only(
                  topStart: Radius.circular(20),
                ),
              ),
              width: 150,
              height: 150,
            ),
          );
        },
      ),
    );
  });

  test('Should render a box with right curved corners', () {
    pdf.addPage(
      Page(
        textDirection: TextDirection.rtl,
        pageFormat: const PdfPageFormat(150, 150),
        build: (Context context) {
          return TestAnnotation(
            anno: 'RTL RadiusDirectional.horizontal start',
            child: Container(
              margin: const EdgeInsets.only(top: 11),
              decoration: const BoxDecoration(
                color: PdfColors.blue,
                borderRadius: BorderRadiusDirectional.horizontal(
                  start: Radius.circular(20),
                ),
              ),
              width: 150,
              height: 150,
            ),
          );
        },
      ),
    );
  });

  test('Should render a box with left curved corners', () {
    pdf.addPage(
      Page(
        textDirection: TextDirection.ltr,
        pageFormat: const PdfPageFormat(150, 150),
        build: (Context context) {
          return TestAnnotation(
            anno: 'LTR RadiusDirectional.horizontal end',
            child: Container(
              margin: const EdgeInsets.only(top: 11),
              decoration: const BoxDecoration(
                color: PdfColors.blue,
                borderRadius: BorderRadiusDirectional.horizontal(
                  end: Radius.circular(20),
                ),
              ),
              width: 150,
              height: 150,
            ),
          );
        },
      ),
    );
  });

  test('Should render a box with top-left curved corner', () {
    pdf.addPage(
      Page(
        textDirection: TextDirection.ltr,
        pageFormat: const PdfPageFormat(150, 150),
        build: (Context context) {
          return TestAnnotation(
            anno: 'LTR RadiusDirectional.only topEnd',
            child: Container(
              margin: const EdgeInsets.only(top: 11),
              decoration: const BoxDecoration(
                color: PdfColors.blue,
                borderRadius: BorderRadiusDirectional.only(
                  topEnd: Radius.circular(20),
                ),
              ),
              width: 150,
              height: 150,
            ),
          );
        },
      ),
    );
  });

  test('Should render Grid with run alignment right', () {
    pdf.addPage(
      Page(
        textDirection: TextDirection.rtl,
        pageFormat: const PdfPageFormat(150, 150),
        build: (Context context) {
          return TestAnnotation(
            anno: 'RTL GridView Axis.vertical',
            child: GridView(
              crossAxisCount: 3,
              childAspectRatio: 1,
              direction: Axis.vertical,
              children: [
                for (int i = 0; i < 7; i++)
                  Container(
                    color: [
                      PdfColors.blue,
                      PdfColors.red,
                      PdfColors.yellow
                    ][i % 3],
                  ),
              ],
            ),
          );
        },
      ),
    );
  });

  test('Should render Grid with run alignment left', () {
    pdf.addPage(
      Page(
        textDirection: TextDirection.ltr,
        pageFormat: const PdfPageFormat(150, 150),
        build: (Context context) {
          return TestAnnotation(
            anno: 'LTR GridView Axis.vertical',
            child: GridView(
              crossAxisCount: 3,
              childAspectRatio: 1,
              direction: Axis.vertical,
              children: [
                for (int i = 0; i < 7; i++)
                  Container(
                    color: [
                      PdfColors.blue,
                      PdfColors.red,
                      PdfColors.yellow
                    ][i % 3],
                  ),
              ],
            ),
          );
        },
      ),
    );
  });
  test('Should render Grid (horizontal) with run alignment right', () {
    pdf.addPage(
      Page(
        textDirection: TextDirection.rtl,
        pageFormat: const PdfPageFormat(150, 150),
        build: (Context context) {
          return TestAnnotation(
            anno: 'RTL GridView Axis.horizontal',
            child: GridView(
              crossAxisCount: 3,
              childAspectRatio: 1,
              direction: Axis.horizontal,
              children: [
                for (int i = 0; i < 7; i++)
                  Container(
                    color: [
                      PdfColors.blue,
                      PdfColors.red,
                      PdfColors.yellow
                    ][i % 3],
                  ),
              ],
            ),
          );
        },
      ),
    );
  });

  test('Should render Grid (horizontal) with run alignment left', () {
    pdf.addPage(
      Page(
        textDirection: TextDirection.ltr,
        pageFormat: const PdfPageFormat(150, 150),
        build: (Context context) {
          return TestAnnotation(
            anno: 'LTR GridView Axis.horizontal',
            child: GridView(
              crossAxisCount: 3,
              childAspectRatio: 1,
              direction: Axis.horizontal,
              children: [
                for (int i = 0; i < 7; i++)
                  Container(
                    color: [
                      PdfColors.blue,
                      PdfColors.red,
                      PdfColors.yellow
                    ][i % 3],
                  ),
              ],
            ),
          );
        },
      ),
    );
  });

  test('RTL Stack, should directional child to right44', () {
    pdf.addPage(
      Page(
        textDirection: TextDirection.rtl,
        pageFormat: const PdfPageFormat(150, 150),
        build: (Context context) {
          return TestAnnotation(
            anno: 'RTL Stack PositionDirectional.start',
            child: Stack(children: [
              PositionedDirectional(
                start: 0,
                child: _blueBox,
              )
            ]),
          );
        },
      ),
    );
  });

  test('LTR Stack, should directional child to right44', () {
    pdf.addPage(
      Page(
        textDirection: TextDirection.ltr,
        pageFormat: const PdfPageFormat(150, 150),
        build: (Context context) {
          return TestAnnotation(
            anno: 'LTR Stack PositionDirectional.start',
            child: Stack(children: [
              PositionedDirectional(
                start: 0,
                child: _blueBox,
              )
            ]),
          );
        },
      ),
    );
  });

  tearDownAll(() async {
    final file = File('rtl-layout.pdf');
    await file.writeAsBytes(await pdf.save());
  });
}

class TestAnnotation extends StatelessWidget {
  TestAnnotation({required this.anno, required this.child});

  final String anno;
  final Widget child;

  @override
  Widget build(Context context) {
    return Stack(children: [
      child,
      Positioned(
        top: 0,
        right: 0,
        left: 0,
        child: Container(
          color: PdfColors.white,
          child: Text(
            anno,
            style: const TextStyle(color: PdfColors.black, fontSize: 9),
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    ]);
  }
}
