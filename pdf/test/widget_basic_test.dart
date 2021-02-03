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

import 'package:test/test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart';

late Document pdf;

void main() {
  setUpAll(() {
    Document.debug = true;
    pdf = Document();
  });

  test('Basic Widgets Align 1', () {
    pdf.addPage(Page(
        build: (Context context) => Align(
              alignment: Alignment.bottomRight,
              child: SizedBox(width: 100, height: 100, child: PdfLogo()),
            )));
  });

  test('Basic Widgets Align 2', () {
    pdf.addPage(Page(
        build: (Context context) => Align(
              alignment: const Alignment(0.8, 0.2),
              child: SizedBox(width: 100, height: 100, child: PdfLogo()),
            )));
  });

  test('Basic Widgets AspectRatio', () {
    pdf.addPage(Page(
        build: (Context context) => AspectRatio(
              aspectRatio: 1.618,
              child: Placeholder(),
            )));
  });

  test('Basic Widgets Center', () {
    pdf.addPage(Page(
        build: (Context context) => Center(
              child: SizedBox(width: 100, height: 100, child: PdfLogo()),
            )));
  });

  test('Basic Widgets ConstrainedBox', () {
    pdf.addPage(Page(
      build: (Context context) => ConstrainedBox(
          constraints: const BoxConstraints.tightFor(height: 300),
          child: Placeholder()),
    ));
  });

  test('Basic Widgets CustomPaint', () {
    pdf.addPage(Page(
        build: (Context context) => CustomPaint(
              size: const PdfPoint(200, 200),
              painter: (PdfGraphics canvas, PdfPoint size) {
                canvas
                  ..drawEllipse(size.x / 2, size.y / 2, size.x / 2, size.y / 2)
                  ..setFillColor(PdfColors.blue)
                  ..fillPath();
              },
            )));
    pdf.addPage(Page(
        build: (Context context) => CustomPaint(
              size: const PdfPoint(200, 200),
              painter: (PdfGraphics canvas, PdfPoint size) {
                canvas
                  ..drawEllipse(size.x / 2, size.y / 2, size.x / 2, size.y / 2)
                  ..setFillColor(PdfColors.blue)
                  ..fillPath();
              },
              child: PdfLogo(),
            )));
  });

  test('Basic Widgets FittedBox', () {
    pdf.addPage(Page(
        build: (Context context) => Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                mainAxisSize: MainAxisSize.max,
                children: <Widget>[
                  SizedBox(
                      height: 100,
                      width: 100,
                      child: FittedBox(
                          fit: BoxFit.contain,
                          child: SizedBox(
                              width: 100, height: 50, child: Placeholder()))),
                  SizedBox(
                      height: 100,
                      width: 100,
                      child: FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                              width: 100, height: 50, child: Placeholder()))),
                  SizedBox(
                      height: 100,
                      width: 100,
                      child: FittedBox(
                          fit: BoxFit.fill,
                          child: SizedBox(
                              width: 100, height: 50, child: Placeholder()))),
                  SizedBox(
                      height: 100,
                      width: 100,
                      child: FittedBox(
                          fit: BoxFit.fitWidth,
                          child: SizedBox(
                              width: 100, height: 50, child: Placeholder()))),
                  SizedBox(
                      height: 100,
                      width: 100,
                      child: FittedBox(
                          fit: BoxFit.fitHeight,
                          child: SizedBox(
                              width: 100, height: 50, child: Placeholder()))),
                  SizedBox(
                      height: 100,
                      width: 100,
                      child: FittedBox(
                          fit: BoxFit.none,
                          child: SizedBox(
                              width: 100, height: 50, child: Placeholder()))),
                  SizedBox(
                      height: 100,
                      width: 100,
                      child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: SizedBox(
                              width: 100, height: 50, child: Placeholder()))),
                ])));
  });

  test('Basic Widgets LimitedBox', () {
    pdf.addPage(Page(
        build: (Context context) => ListView(
              children: <Widget>[
                LimitedBox(
                  maxHeight: 40,
                  child: Placeholder(),
                ),
              ],
            )));
  });

  test('Basic Widgets Padding', () {
    pdf.addPage(Page(
        build: (Context context) => Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: PdfLogo(),
              ),
            )));
  });

  test('Basic Widgets SizedBox', () {
    pdf.addPage(Page(
        build: (Context context) => SizedBox(
              width: 200,
              height: 100,
              child: Placeholder(),
            )));
  });

  test('Basic Widgets Transform', () {
    pdf.addPage(Page(
        build: (Context context) => Transform.scale(
              scale: 0.5,
              child: Transform.rotate(
                angle: 0.1,
                child: Placeholder(),
              ),
            )));
  });

  test('Basic Widgets Transform rotateBox', () {
    pdf.addPage(Page(
        build: (Context context) => Center(
              child: Transform.rotateBox(
                angle: 3.1416 / 2,
                child: Text('Hello'),
              ),
            )));
  });

  tearDownAll(() async {
    final file = File('widgets-basic.pdf');
    await file.writeAsBytes(await pdf.save());
  });
}
