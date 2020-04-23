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

  group('ScatterChart test', () {
    test('Default ScatterChart', () {
      pdf.addPage(Page(
        build: (Context context) => ScatterChart(
          data: <double>[1, 3, 5],
        ),
      ));
    });

    test('Default ScatterChart without lines connecting points', () {
      pdf.addPage(Page(
        build: (Context context) => ScatterChart(
          data: <double>[1, 3, 5],
          pointLine: false,
        ),
      ));
    });

    test('ScatterChart with custom points and lines', () {
      pdf.addPage(Page(
        build: (Context context) => ScatterChart(
          data: <double>[1, 3, 5, 4],
          pointLineWidth: 4,
          pointLineColor: PdfColors.green,
          pointColor: PdfColors.blue,
          pointSize: 5,
        ),
      ));
    });

    test('ScatterChart with custom yAxis grid', () {
      pdf.addPage(Page(
        build: (Context context) => ScatterChart(
          data: <double>[1, 3, 5, 4],
          yAxis: <double>[0, 3, 6, 9],
        ),
      ));
    });

    test('ScatterChart with custom grid', () {
      pdf.addPage(Page(
        build: (Context context) => ScatterChart(
          data: <double>[1, 3, 5],
          yAxis: <double>[0, 3, 6, 9],
          xAxis: <double>[0, 1, 2, 3, 4, 5, 6],
        ),
      ));
    });

    test('ScatterChart with custom size', () {
      pdf.addPage(Page(
        build: (Context context) => ScatterChart(
          data: <double>[1, 3, 3, 5, 2],
          width: 300,
          height: 200,
        ),
      ));
    });
  });

  tearDownAll(() {
    final File file = File('widgets-chart.pdf');
    file.writeAsBytesSync(pdf.save());
  });
}
