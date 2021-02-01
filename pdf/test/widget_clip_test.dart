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

  test('Clip Widgets ClipRect', () {
    pdf.addPage(Page(
      build: (Context? context) => ClipRect(
        child: Transform.rotate(
          angle: 0.1,
          child: Container(
            decoration: const BoxDecoration(
              color: PdfColors.blue,
            ),
          ),
        ),
      ),
    ));
  });

  test('Clip Widgets ClipRRect', () {
    pdf.addPage(Page(
      build: (Context? context) => ClipRRect(
        horizontalRadius: 30,
        verticalRadius: 30,
        child: Container(
          decoration: const BoxDecoration(
            color: PdfColors.blue,
          ),
        ),
      ),
    ));
  });

  test('Clip Widgets ClipOval', () {
    pdf.addPage(Page(
      build: (Context? context) => ClipOval(
        child: Container(
          decoration: const BoxDecoration(
            color: PdfColors.blue,
          ),
        ),
      ),
    ));
  });

  tearDownAll(() async {
    final file = File('widgets-clip.pdf');
    await file.writeAsBytes(await pdf.save());
  });
}
