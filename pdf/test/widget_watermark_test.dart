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

void main() {
  test('Pdf Widgets Watermark', () {
    Document.debug = true;
    final Document pdf = Document();

    final PageTheme pageTheme = PageTheme(
      buildBackground: (Context context) => Watermark.text('DRAFT'),
      buildForeground: (Context context) => Align(
        alignment: Alignment.bottomLeft,
        child: SizedBox(
          width: 100,
          height: 100,
          child: PdfLogo(),
        ),
      ),
    );

    pdf.addPage(
      Page(
        pageTheme: pageTheme,
        build: (Context context) => Center(
          child: Text(
            'Hello World',
          ),
        ),
      ),
    );

    pdf.addPage(
      MultiPage(
        pageTheme: pageTheme,
        build: (Context context) => List<Widget>.filled(
          100,
          Text(
            'Hello World',
          ),
        ),
      ),
    );

    final File file = File('widgets-watermark.pdf');
    file.writeAsBytesSync(pdf.save());
  });
}
