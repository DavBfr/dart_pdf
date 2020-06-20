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

import 'package:pdf/widgets.dart';
import 'package:test/test.dart';

Document pdf;

void main() {
  setUpAll(() {
    Document.debug = true;
    pdf = Document();
  });

  test('Opacity Widgets', () {
    pdf.addPage(
      Page(
        build: (Context context) => Stack(
          alignment: Alignment.center,
          children: <Widget>[
            Text('Background', textScaleFactor: 5),
            Opacity(
              opacity: .5,
              child: PdfLogo(),
            ),
          ],
        ),
      ),
    );
  });

  tearDownAll(() {
    final File file = File('widgets-opacity.pdf');
    file.writeAsBytesSync(pdf.save());
  });
}
