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

import 'package:test/test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart';

Document pdf;

void main() {
  setUpAll(() {
    Document.debug = true;
    pdf = Document();
  });

  group('LineChart test', () {
    test('Default LineChart', () {
      pdf.addPage(Page(
        build: (Context context) => Chart(
          grid: LinearGrid(
            xAxis: <double>[0, 1, 2, 3, 4, 5, 6],
            yAxis: <double>[0, 3, 6, 9],
          ),
          data: <DataSet>[
            LineDataSet(
              data: <double>[1, 3, 7],
            ),
          ],
        ),
      ));
    });

    test('Default LineChart without lines connecting points', () {
      pdf.addPage(Page(
        build: (Context context) => Chart(
          grid: LinearGrid(
            xAxis: <double>[0, 1, 2, 3, 4, 5, 6],
            yAxis: <double>[0, 3, 6, 9],
          ),
          data: <DataSet>[
            LineDataSet(
              data: <double>[1, 3, 7],
              drawLine: false,
            ),
          ],
        ),
      ));
    });

    test('Default ScatterChart without dots', () {
      pdf.addPage(Page(
        build: (Context context) => Chart(
          grid: LinearGrid(
            xAxis: <double>[0, 1, 2, 3, 4, 5, 6],
            yAxis: <double>[0, 3, 6, 9],
          ),
          data: <DataSet>[
            LineDataSet(
              data: <double>[1, 3, 7],
              drawPoints: false,
            ),
          ],
        ),
      ));
    });

    test('ScatterChart with custom points and lines', () {
      pdf.addPage(Page(
        build: (Context context) => Chart(
          grid: LinearGrid(
            xAxis: <double>[0, 1, 2, 3, 4, 5, 6],
            yAxis: <double>[0, 3, 6, 9],
          ),
          data: <DataSet>[
            LineDataSet(
              data: <double>[1, 3, 7],
              drawLine: false,
              pointColor: PdfColors.red,
              pointSize: 4,
              lineColor: PdfColors.purple,
              lineWidth: 4,
            ),
          ],
        ),
      ));
    });

    test('ScatterChart with custom size', () {
      pdf.addPage(Page(
        build: (Context context) => Chart(
          width: 200,
          height: 100,
          grid: LinearGrid(
            xAxis: <double>[0, 1, 2, 3, 4, 5, 6],
            yAxis: <double>[0, 3, 6, 9],
          ),
          data: <DataSet>[
            LineDataSet(
              data: <double>[1, 3, 7],
            ),
          ],
        ),
      ));
    });
  });

  tearDownAll(() {
    final File file = File('widgets-chart.pdf');
    file.writeAsBytesSync(pdf.save());
  });
}
