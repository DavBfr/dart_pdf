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

  test('Partitions Widget', () {
    pdf.addPage(
      MultiPage(
        build: (Context context) => <Widget>[
          Partitions(
            children: <Partition>[
              Partition(
                flex: 1618,
                child: Column(
                  children: List<Widget>.generate(100, (int i) => Text('$i')),
                ),
              ),
              Partition(
                flex: 1000,
                // width: 100,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List<Widget>.generate(20, (int i) => Text('$i')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  });

  tearDownAll(() async {
    final file = File('widgets-partitions.pdf');
    await file.writeAsBytes(await pdf.save());
  });
}
