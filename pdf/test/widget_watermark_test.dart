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
PageTheme? pageTheme;

void main() {
  setUpAll(() {
    Document.debug = true;
    RichText.debug = true;
    pdf = Document();

    pageTheme = PageTheme(
      buildBackground: (Context context) => FullPage(
        ignoreMargins: true,
        child: Watermark.text('DRAFT'),
      ),
      buildForeground: (Context context) => Align(
        alignment: Alignment.bottomLeft,
        child: SizedBox(
          width: 100,
          height: 100,
          child: PdfLogo(),
        ),
      ),
    );
  });

  test('Pdf Widgets Watermark Page', () {
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
  });

  test('Pdf Widgets Watermark MultiPage', () {
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
  });

  test('Pdf Widgets Watermark Page Count', () async {
    final pageTheme = PageTheme(
      buildBackground: (Context context) =>
          (context.pageNumber == context.pagesCount)
              ? Align(
                  alignment: Alignment.topRight,
                  child: SizedBox(
                      width: 200,
                      height: 200,
                      child: PdfLogo(color: PdfColors.blue200)),
                )
              : Container(),
    );

    pdf.addPage(
      MultiPage(
        pageTheme: pageTheme,
        build: (Context context) => <Widget>[
          Wrap(
            children: List<Widget>.generate(
              670,
              (_) => Text('Hello World '),
            ),
          ),
        ],
      ),
    );
  });

  tearDownAll(() async {
    final file = File('widgets-watermark.pdf');
    await file.writeAsBytes(await pdf.save());
  });
}
