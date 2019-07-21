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

List<Widget> lines = <Widget>[];

void main() {
  setUpAll(() {
    for (int i = 0; i < 200; i++) {
      lines.add(Text('Line $i'));
    }
  });

  test('Pdf Widgets MultiPage', () {
    Document.debug = true;

    final Document pdf = Document();

    pdf.addPage(MultiPage(build: (Context context) => lines));

    final File file = File('widgets-multipage.pdf');
    file.writeAsBytesSync(pdf.save());

    final File file1 = File('widgets-multipage-1.pdf');
    file1.writeAsBytesSync(pdf.save());
  });

  test('Pdf Widgets MonoPage', () {
    Document.debug = true;

    final Document pdf = Document();

    pdf.addPage(Page(build: (Context context) => Column(children: lines)));

    final File file = File('widgets-monopage.pdf');
    file.writeAsBytesSync(pdf.save());

    final File file1 = File('widgets-monopage-1.pdf');
    file1.writeAsBytesSync(pdf.save());
  });
}
