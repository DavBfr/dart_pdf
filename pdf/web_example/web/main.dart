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

import 'dart:async';
import 'dart:html';
import 'dart:js' as js;
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart';

import 'calendar.dart';

Uint8List buildPdf() {
  final Document pdf = Document(title: 'My Document', author: 'David PHAM-VAN');

  pdf.addPage(Page(
    build: (Context ctx) {
      return Container(
        width: double.infinity,
        height: double.infinity,
        child: FittedBox(
          child: Text(
            'Hello!',
            style: TextStyle(color: PdfColors.blueGrey),
          ),
        ),
      );
    },
  ));

  pdf.addPage(Page(
    pageFormat: PdfPageFormat.a4.landscape,
    build: (Context context) => Calendar(),
  ));

  pdf.addPage(Page(
    pageFormat: PdfPageFormat.a4.landscape,
    build: (Context context) => Calendar(
      month: DateTime.now().month + 1,
    ),
  ));

  pdf.addPage(Page(
    build: (Context ctx) {
      return Center(child: PdfLogo());
    },
  ));

  return Uint8List.fromList(pdf.save());
}

void main() {
  js.context['buildPdf'] = buildPdf;
  Timer.run(() {
    js.context.callMethod('ready');
  });
}
