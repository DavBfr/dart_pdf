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

// ignore_for_file: omit_local_variable_types

import 'dart:io';

import 'package:barcode/barcode.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart';
import 'package:test/test.dart';

Document pdf;

Widget barcode(Barcode barcode, String data, {double width = 200}) {
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
            height: 80,
            margin: const EdgeInsets.symmetric(vertical: 20),
          ),
        ),
      ),
    ],
  );
}

void main() {
  setUpAll(() {
    Document.debug = true;
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
        ],
      ),
    );
  });

  test('QrCode Widgets', () {
    pdf.addPage(
      Page(
        build: (Context context) => QrCodeWidget(
          data: 'HELLO 123',
          size: 200,
          padding: const EdgeInsets.all(20),
          margin: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              borderRadius: 20,
              color: PdfColors.white,
              border: const BoxBorder(
                color: PdfColors.blue,
                top: true,
                bottom: true,
                left: true,
                right: true,
              )),
        ),
      ),
    );
  });

  tearDownAll(() {
    final File file = File('widgets-barcode.pdf');
    file.writeAsBytesSync(pdf.save());
  });
}
