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

late Document pdf;

void main() {
  setUpAll(() {
    Document.debug = true;
    RichText.debug = true;
    pdf = Document();
  });

  test('Pdf Widgets GridView empty', () {
    pdf.addPage(MultiPage(
        build: (Context context) => <Widget>[
              GridView(
                crossAxisCount: 1,
                childAspectRatio: 1,
              ),
            ]));
  });

  test('Pdf Widgets GridView Vertical', () {
    pdf.addPage(MultiPage(
        build: (Context context) => <Widget>[
              GridView(
                  crossAxisCount: 3,
                  childAspectRatio: 1,
                  direction: Axis.vertical,
                  children: List<Widget>.generate(
                      20, (int index) => Center(child: Text('$index')))),
            ]));
  });

  test('Pdf Widgets GridView Horizontal', () {
    pdf.addPage(Page(
      build: (Context context) => GridView(
          crossAxisCount: 5,
          direction: Axis.horizontal,
          childAspectRatio: 1,
          children: List<Widget>.generate(
              20, (int index) => Center(child: Text('$index')))),
    ));
  });

  tearDownAll(() async {
    final file = File('widgets-gridview.pdf');
    await file.writeAsBytes(await pdf.save());
  });
}
