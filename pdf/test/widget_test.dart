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

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart';
import 'package:test/test.dart';

void main() {
  late Document pdf;
  TextStyle? symbol;
  late ImageProvider im;

  setUpAll(() {
    Document.debug = true;

    final defaultFont = File('open-sans.ttf').readAsBytesSync();
    final defaultFontBold = File('open-sans-bold.ttf').readAsBytesSync();

    pdf = Document(
        title: 'Widgets Test',
        theme: ThemeData.withFont(
          base: Font.ttf(defaultFont.buffer.asByteData()),
          bold: Font.ttf(defaultFontBold.buffer.asByteData()),
        ));

    symbol = TextStyle(font: Font.zapfDingbats());

    final imData = zlib.decode(base64.decode(
        'eJz7//8/w388uOTCT6a4Ez96Q47++I+OI479mEVALyNU7z9seuNP/mAm196Ekz8YR+0dWHtBmJC9S+7/Zog89iMIKLYaHQPVJGLTD7MXpDfq+I9goNhPdPPDjv3YlnH6Jye6+2H21l/6yeB/4HsSDr1bQXrRwq8HqHcGyF6QXp9933N0tn/7Y7vn+/9gLPaih0PDlV9MIAzVm6ez7dsfzW3f/oMwzAx0e7FhoJutdbcj9MKw9frnL2J2POfBpxeEg478YLba/X0Wsl6lBXf+s0bP/s8ePXeWePJCvPEJNYMRZIYWSO/cq/9Z/Nv+M4bO+M8YDjFDJGkhzvSE7A6jRTdnsQR2wfXCMLHuMC5byyidvGgWE5JeZDOIcYdR+TpmkBno+mFmAAC+DGhl'));
    im = RawImage(bytes: Uint8List.fromList(imData), width: 16, height: 20);
  });

  test('Pdf Widgets page 1', () {
    pdf.addPage(Page(
        pageFormat: const PdfPageFormat(400, 400),
        margin: const EdgeInsets.all(10),
        build: (Context context) => Column(children: <Widget>[
              Container(
                padding: const EdgeInsets.all(5),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: PdfColors.amber,
                  border: Border.all(width: 2),
                ),
                child: Text(
                  'Hello World',
                  textScaleFactor: 2,
                  textAlign: TextAlign.center,
                ),
              ),
              Align(
                alignment: Alignment.topLeft,
                child: Link(
                  destination: 'anchor',
                  child: Text(
                    'Internal link',
                    style: const TextStyle(
                      color: PdfColors.blue,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
              Padding(padding: const EdgeInsets.all(5)),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  Image(im),
                  PdfLogo(),
                  Column(
                    children: <Widget>[
                      Text('(', style: symbol),
                      Text('4', style: symbol),
                    ],
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: 30, top: 20),
                child: Lorem(textAlign: TextAlign.justify),
              ),
              Expanded(
                child: FittedBox(
                  child: Transform.rotateBox(
                    angle: 0.2,
                    child: Text(
                      'Expanded',
                      tightBounds: true,
                    ),
                  ),
                ),
              ),
              Container(
                decoration:
                    const BoxDecoration(border: Border(top: BorderSide())),
                child: Text(
                  "That's all Folks!",
                  tightBounds: true,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).defaultTextStyle.copyWith(
                        font: Font.timesBoldItalic(),
                      ),
                  textScaleFactor: 3,
                ),
              ),
            ])));
  });

  test('Pdf Widgets page 2', () {
    pdf.addPage(
      Page(
        pageFormat: const PdfPageFormat(400, 400),
        margin: const EdgeInsets.all(10),
        build: (Context context) => Center(
          child: GridView(
            crossAxisCount: 3,
            direction: Axis.vertical,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            padding: const EdgeInsets.all(10),
            children: List<Widget>.generate(
              9,
              (int n) => FittedBox(
                child: Text('${n + 1}', tightBounds: true),
              ),
            ),
          ),
        ),
      ),
    );
  });

  test(
    'Pdf Widgets page 3',
    () {
      pdf.addPage(
        MultiPage(
          pageFormat: const PdfPageFormat(400, 200),
          margin: const EdgeInsets.all(10),
          build: (Context context) => <Widget>[
            Table.fromTextArray(
              context: context,
              cellPadding: const EdgeInsets.all(3),
              data: <List<String>>[
                <String>['Company', 'Contact', 'Country'],
                <String>['Alfreds Futterkiste', 'Maria Anders', 'Germany'],
                <String>[
                  'Centro comercial Moctezuma',
                  'Francisco Chang',
                  'Mexico'
                ],
                <String>['Ernst Handel', 'Roland Mendel', 'Austria'],
                <String>['Island Trading', 'Helen Bennett', 'UK'],
                <String>[
                  'Laughing Bacchus Winecellars',
                  'Yoshi Tannamuri',
                  'Canada'
                ],
                <String>[
                  'Magazzini Alimentari Riuniti',
                  'Giovanni Rovelli',
                  'Italy'
                ],
                <String>[
                  'Spaceage Stereo',
                  'Igor Cavalcanti Pereira',
                  'Brasil'
                ],
                <String>['Team Uno', 'Frantisek Stefánek', 'Czech Republic'],
                <String>["Isaly's", 'Michelle J. Kristensen', 'Danmark'],
                <String>['Albers', 'Marjolaine Laramée', 'France'],
                <String>['Dynatronics Accessories', "Cong Ch'en", 'China'],
                <String>['York Steak House', 'Outi Vuorinen', 'Finland'],
                <String>['Weathervane', 'Else Jeremiassen', 'Iceland'],
              ],
            ),
            Anchor(name: 'anchor', child: Text('Anchor')),
          ],
        ),
      );
    },
  );

  test(
    'Pdf Widgets page 4',
    () {
      pdf.addPage(
        Page(
          pageFormat: const PdfPageFormat(400, 200),
          margin: const EdgeInsets.all(10),
          build: (Context context) => Stack(
            overflow: Overflow.visible,
            // fit: StackFit.expand,
            // alignment: Alignment.bottomRight,
            children: <Widget>[
              Positioned(
                  right: 10,
                  top: 10,
                  child: CustomPaint(
                      size: const PdfPoint(50, 50),
                      painter: (PdfGraphics canvas, PdfPoint size) {
                        canvas
                          ..setColor(PdfColors.indigo)
                          ..drawRRect(0, 0, size.x, size.y, 10, 10)
                          ..fillPath();
                      })),
              Positioned(
                  left: 10,
                  bottom: 10,
                  child: RichText(
                    text: TextSpan(
                      text: 'Hello ',
                      style: Theme.of(context).defaultTextStyle,
                      children: <TextSpan>[
                        TextSpan(
                            text: 'bold',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                                color: PdfColors.blue)),
                        const TextSpan(
                          text: ' world!',
                        ),
                      ],
                    ),
                  )),
              Positioned(
                  right: 10,
                  bottom: 10,
                  child: UrlLink(
                      child: Text(
                        'https://github.com/DavBfr/dart_pdf/',
                        style: const TextStyle(
                          color: PdfColors.grey,
                          fontSize: 8,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                      destination: 'https://github.com/DavBfr/dart_pdf/')),
              Positioned(
                left: 10,
                top: 10,
                child: Container(
                  width: 100,
                  height: 100,
                  child: Stack(
                    alignment: Alignment.center,
                    fit: StackFit.expand,
                    children: <Widget>[
                      Center(child: Text('30%', textScaleFactor: 1.5)),
                      CircularProgressIndicator(
                          value: .3,
                          backgroundColor: PdfColors.grey300,
                          strokeWidth: 15),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  tearDownAll(() async {
    final file = File('widgets.pdf');
    await file.writeAsBytes(await pdf.save());
  });
}
