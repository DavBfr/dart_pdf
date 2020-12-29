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

import 'package:pdf/widgets.dart';
import 'package:test/test.dart';

Document pdf;

Widget barcode(
  Barcode barcode,
  String data, {
  double width = 200,
  double height = 80,
}) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: <Widget>[
      Flexible(
        fit: FlexFit.tight,
        child: Center(
          child: Text(barcode.name),
        ),
      ),
      Flexible(
        fit: FlexFit.tight,
        child: Center(
          child: BarcodeWidget(
            barcode: barcode,
            data: data,
            width: width,
            height: height,
            margin: const EdgeInsets.symmetric(vertical: 20),
          ),
        ),
      ),
    ],
  );
}

void main() {
  setUpAll(() {
    // Document.debug = true;
    pdf = Document();
  });

  test('Barcode Widgets', () {
    pdf.addPage(
      MultiPage(
        build: (Context context) => <Widget>[
          barcode(Barcode.code39(), 'CODE 39'),
          barcode(Barcode.code93(), 'CODE 93'),
          barcode(Barcode.code128(), 'Barcode 128'),
          barcode(Barcode.ean13(), '590123412345', width: 150),
          barcode(Barcode.ean8(), '9638507', width: 80),
          barcode(Barcode.isbn(), '978316148410', width: 150),
          barcode(Barcode.upcA(), '98765432109', width: 150),
          barcode(Barcode.upcE(), '06510000432', width: 100),
          barcode(Barcode.ean2(), '44', width: 40),
          barcode(Barcode.ean5(), '30897', width: 60),
          barcode(Barcode.itf14(), '2578639587234'),
          barcode(Barcode.telepen(), 'Telepen'),
          barcode(Barcode.codabar(), '1234-5678'),
          barcode(Barcode.qrCode(), 'QR-Code!', width: 120, height: 120),
          barcode(Barcode.pdf417(), 'PDF147 Demo', height: 35),
          barcode(Barcode.dataMatrix(), 'Data Matrix', width: 120, height: 120),
          barcode(Barcode.aztec(), 'Aztec', width: 120, height: 120),
        ],
      ),
    );
  });

  tearDownAll(() async {
    final file = File('widgets-barcode.pdf');
    await file.writeAsBytes(await pdf.save());
  });
}
