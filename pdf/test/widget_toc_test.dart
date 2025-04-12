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
import 'dart:math';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart';
import 'package:test/test.dart';

late Document pdf;

void main() {
  setUpAll(() {
    Document.debug = true;
    RichText.debug = true;
    pdf = Document();
  });

  test('Pdf Widgets TableOfContent', () {
    pdf.addPage(
      Page(
        build: (context) =>
            Center(child: Text('Document', style: Theme.of(context).header0)),
      ),
    );

    pdf.addPage(
      MultiPage(
        footer: (c) => Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Align(
                alignment: Alignment.centerRight, child: Text(c.pageLabel))),
        build: (context) => [
          ...Iterable<Widget>.generate(40, (index) {
            final level = (sin(index / 5) * 6).abs().toInt();
            return Column(
              children: [
                Header(
                  child: Text('Hello $index level $level'),
                  text: 'Hello $index',
                  level: level,
                ),
                Lorem(length: 60),
              ],
            );
          }),
        ],
      ),
    );

    pdf.addPage(
      MultiPage(
        footer: (c) => Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Align(
                alignment: Alignment.centerRight, child: Text(c.pageLabel))),
        build: (context) => [
          Center(
              child:
                  Text('Table of content', style: Theme.of(context).header0)),
          SizedBox(height: 20),
          TableOfContent(),
        ],
      ),
      index: 1,
    );
  });

  test('page number with footer', () {
    pdf.addPage(
      Page(
        build: (final context) {
          return Column(
            children: [TableOfContent()],
          );
        },
      ),
    );
    pdf.addPage(
      MultiPage(
        footer: (final Context context) {
          return Container(
            margin: const EdgeInsets.only(top: 1.0 * PdfPageFormat.cm),
            child: Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
            ),
          );
        },
        build: (final context) => [
          Header(text: 'a', level: 1),
          Text(LoremText().paragraph(600)),
          Header(text: 'b', level: 1),
        ],
      ),
    );
  });

  tearDownAll(() async {
    final file = File('widgets-toc.pdf');
    await file.writeAsBytes(await pdf.save());
  });
}
