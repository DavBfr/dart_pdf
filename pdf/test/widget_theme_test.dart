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

late Document pdf;
Font? openSans;
Font? openSansBold;
Font? roboto;
Font? notoSans;
Font? genyomintw;

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
    final style = TextStyle(
        font: roboto,
        fontBold: openSansBold,
        fontNormal: openSans,
        fontItalic: notoSans,
        fontBoldItalic: genyomintw,
        fontWeight: FontWeight.bold,
        fontSize: 20,
        color: PdfColors.blue);

    pdf.addPage(Page(
      build: (Context? context) => ListView(
        children: <Widget>[
          Text(
            style.font!.fontName!,
            style: style,
          ),
        ],
      ),
    ));
  });

  test('Theme Page 1', () {
    final theme = ThemeData.withFont(base: roboto);

    pdf.addPage(Page(
      theme: theme,
      build: (Context? context) => Center(
        child: Text('Hello'),
      ),
    ));
  });

  test('Theme Page 2', () {
    final theme = ThemeData.base().copyWith(
      tableHeader: TextStyle(font: openSansBold),
      tableCell: TextStyle(font: roboto),
    );

    pdf.addPage(Page(
      theme: theme,
      build: (Context? context) => Center(
        child: Table.fromTextArray(context: context, data: <List<String>>[
          <String>['Header', '123'],
          <String>['Cell', '456']
        ]),
      ),
    ));
  });

  test('Theme Page 3', () {
    pdf.addPage(Page(
      build: (Context? context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            Text('Hello default'),
            Theme(
              data: ThemeData.withFont(
                base: roboto,
              ),
              child: Text('Hello themed'),
            ),
          ],
        ),
      ),
    ));
  });

  test('Theme Page 4', () {
    pdf.addPage(Page(
        pageFormat: PdfPageFormat.a4,
        orientation: PageOrientation.portrait,
        margin: const EdgeInsets.all(8.0),
        theme: ThemeData(
          defaultTextStyle: TextStyle(font: Font.courier(), fontSize: 10.0),
        ),
        build: (Context? context) {
          return Center(child: Text('Text'));
        }));
  });

  tearDownAll(() async {
    final file = File('widgets-theme.pdf');
    await file.writeAsBytes(await pdf.save());
  });
}
