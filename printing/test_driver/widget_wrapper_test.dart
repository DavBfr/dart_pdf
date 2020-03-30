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

// The code for the widget displayed in the Scaffold body is taken
// from https://api.flutter.dev/flutter/widgets/Icon-class.html.

import 'dart:io';
import 'package:flutter_driver/flutter_driver.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart';
import 'package:test/test.dart';

import 'package:printing/printing.dart';
import 'widget_wrapper.dart';


void main() {
  group("widgetWrapper integration tests", () {
    FlutterDriver driver;
    Document pdf;

    setUpAll(() async{
      driver = await FlutterDriver.connect();
      Document.debug = true;
      pdf = Document();
    });

    test('renders Text Widget as Image', () async {
      final Image iconsWrapper = await WidgetWrapper.from(pdf.document, key: keyText);
      pdf.addPage(Page(
        pageFormat: const PdfPageFormat(800, 400),
        margin: const EdgeInsets.all(10),
        build: (Context context) => iconsWrapper,
      ));
    });

    test('renders Widget with 3 Icons as Image given only width', () async {
          final Image iconsWrapper =
          await WidgetWrapper.from(pdf.document, key: keyIcons, width: 100);
          pdf.addPage(Page(
            pageFormat: const PdfPageFormat(800, 400),
            margin: const EdgeInsets.all(10),
            build: (Context context) => iconsWrapper,
          ));
        });

    test('renders Widget with 3 Icons as Image given only height', () async {
          final Image iconsWrapper =
          await WidgetWrapper.from(pdf.document, key: keyIcons, height: 100);
          pdf.addPage(Page(
            pageFormat: const PdfPageFormat(800, 400),
            margin: const EdgeInsets.all(10),
            build: (Context context) => iconsWrapper,
          ));
        });

    test('Render Widget with 3 Icons as Image given width and height', () async {
          final Image iconsWrapper = await WidgetWrapper.from(pdf.document,
              key: keyIcons, width: 100, height: 100);
          pdf.addPage(Page(
            pageFormat: const PdfPageFormat(800, 400),
            margin: const EdgeInsets.all(10),
            build: (Context context) => iconsWrapper,
          ));
        });


    tearDownAll(() {
      if(driver != null) {
        driver.close();
      }
      final File file = File('widgets-widget-wrapper.pdf');
      file.writeAsBytesSync(pdf.save());
    });
  });
}
