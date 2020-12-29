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

Document pdf;

final LoremText lorem = LoremText(random: Random(42));

Iterable<Widget> level(int i) sync* {
  final text = lorem.sentence(5);
  var p = 0;
  PdfColor color;
  var style = PdfOutlineStyle.normal;

  if (i >= 3 && i <= 6) {
    p++;
  }

  if (i >= 5 && i <= 6) {
    p++;
  }

  if (i == 15) {
    p = 10;
    color = PdfColors.amber;
    style = PdfOutlineStyle.bold;
  }

  if (i == 17) {
    color = PdfColors.red;
    style = PdfOutlineStyle.italic;
  }

  if (i == 18) {
    color = PdfColors.blue;
    style = PdfOutlineStyle.italicBold;
  }

  yield Outline(
    child: Text(text),
    name: 'anchor$i',
    title: text,
    level: p,
    color: color,
    style: style,
  );

  yield SizedBox(height: 300);
}

void main() {
  setUpAll(() {
    Document.debug = true;
    pdf = Document(pageMode: PdfPageMode.outlines);
  });

  test('Outline Widget', () {
    pdf.addPage(
      MultiPage(
        build: (Context context) => <Widget>[
          for (int i = 0; i < 20; i++) ...level(i),
        ],
      ),
    );
  });

  tearDownAll(() async {
    final file = File('widgets-outline.pdf');
    await file.writeAsBytes(await pdf.save());
  });
}
