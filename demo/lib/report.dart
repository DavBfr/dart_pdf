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

// ignore_for_file: always_specify_types

import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

Future<Uint8List> generateReport(PdfPageFormat pageFormat) async {
  const tableHeaders = ['Category', 'Budget', 'Expense', 'Result'];

  const dataTable = [
    ['Phone', 80, 95, -15],
    ['Internet', 250, 230, 20],
    ['Electricity', 300, 375, -75],
    ['Movies', 85, 80, 5],
    ['Food', 300, 350, -50],
    ['Fuel', 650, 550, 100],
    ['Insurance', 250, 310, -60],
  ];

  final baseColor = PdfColors.cyan;

  // Create a PDF document.
  final document = pw.Document();

  // Add page to the PDF
  document.addPage(
    pw.Page(
      pageFormat: pageFormat,
      theme: pw.ThemeData.withFont(
        base: pw.Font.ttf(await rootBundle.load('assets/open-sans.ttf')),
        bold: pw.Font.ttf(await rootBundle.load('assets/open-sans-bold.ttf')),
      ),
      build: (context) {
        final chart1 = pw.Chart(
          left: pw.Container(
            alignment: pw.Alignment.topCenter,
            margin: const pw.EdgeInsets.only(right: 5, top: 10),
            child: pw.Transform.rotateBox(
              angle: pi / 2,
              child: pw.Text('Amount'),
            ),
          ),
          overlay: pw.ChartLegend(
            position: const pw.Alignment(-.7, 1),
            decoration: const pw.BoxDecoration(
              color: PdfColors.white,
              border: pw.BoxBorder(
                bottom: true,
                top: true,
                left: true,
                right: true,
                color: PdfColors.black,
                width: .5,
              ),
            ),
          ),
          grid: pw.CartesianGrid(
            xAxis: pw.FixedAxis.fromStrings(
              List<String>.generate(
                  dataTable.length, (index) => dataTable[index][0]),
              marginStart: 30,
              marginEnd: 30,
              ticks: true,
            ),
            yAxis: pw.FixedAxis(
              [0, 100, 200, 300, 400, 500, 600, 700],
              format: (v) => '\$$v',
              divisions: true,
            ),
          ),
          datasets: [
            pw.BarDataSet(
              color: PdfColors.blue100,
              legend: tableHeaders[2],
              width: 15,
              offset: -10,
              borderColor: baseColor,
              data: List<pw.LineChartValue>.generate(
                dataTable.length,
                (i) {
                  final num v = dataTable[i][2];
                  return pw.LineChartValue(i.toDouble(), v.toDouble());
                },
              ),
            ),
            pw.BarDataSet(
              color: PdfColors.amber100,
              legend: tableHeaders[1],
              width: 15,
              offset: 10,
              borderColor: PdfColors.amber,
              data: List<pw.LineChartValue>.generate(
                dataTable.length,
                (i) {
                  final num v = dataTable[i][1];
                  return pw.LineChartValue(i.toDouble(), v.toDouble());
                },
              ),
            ),
          ],
        );

        final chart2 = pw.Chart(
          grid: pw.CartesianGrid(
            xAxis: pw.FixedAxis([0, 1, 2, 3, 4, 5, 6]),
            yAxis: pw.FixedAxis(
              [0, 200, 400, 600],
              divisions: true,
            ),
          ),
          datasets: [
            pw.LineDataSet(
              drawSurface: true,
              isCurved: true,
              drawPoints: false,
              color: baseColor,
              data: List<pw.LineChartValue>.generate(
                dataTable.length,
                (i) {
                  final num v = dataTable[i][2];
                  return pw.LineChartValue(i.toDouble(), v.toDouble());
                },
              ),
            ),
          ],
        );

        final table = pw.Table.fromTextArray(
          border: null,
          headers: tableHeaders,
          data: dataTable,
          headerStyle: pw.TextStyle(
            color: PdfColors.white,
            fontWeight: pw.FontWeight.bold,
          ),
          headerDecoration: pw.BoxDecoration(
            color: baseColor,
          ),
          rowDecoration: pw.BoxDecoration(
            border: pw.BoxBorder(
              bottom: true,
              color: baseColor,
              width: .5,
            ),
          ),
        );

        return pw.Column(
          children: [
            pw.Text('Budget Report',
                style: pw.TextStyle(
                  color: baseColor,
                  fontSize: 40,
                )),
            pw.Divider(thickness: 4),
            pw.Expanded(flex: 3, child: chart1),
            pw.Divider(),
            pw.Expanded(
              flex: 2,
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(child: chart2),
                  pw.SizedBox(width: 10),
                  pw.Expanded(child: table),
                ],
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                    child: pw.Column(children: [
                  pw.Container(
                    alignment: pw.Alignment.centerLeft,
                    padding: const pw.EdgeInsets.only(bottom: 10),
                    child: pw.Text(
                      'Expense By Sub-Categories',
                      style: pw.TextStyle(
                        color: baseColor,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  pw.Text(
                    'Total expenses are broken into different categories for closer look into where the money was spent.',
                    textAlign: pw.TextAlign.justify,
                  )
                ])),
                pw.SizedBox(width: 10),
                pw.Expanded(
                  child: pw.Column(
                    children: [
                      pw.Container(
                        alignment: pw.Alignment.centerLeft,
                        padding: const pw.EdgeInsets.only(bottom: 10),
                        child: pw.Text(
                          'Spent vs. Saved',
                          style: pw.TextStyle(
                            color: baseColor,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      pw.Text(
                        'Budget was originally \$1915. A total of \$1990 was spent on the month os January which exceeded the overall budget by \$75',
                        textAlign: pw.TextAlign.justify,
                      )
                    ],
                  ),
                ),
              ],
            ),
          ],
        );
      },
    ),
  );

  // Return the PDF file content
  return document.save();
}
