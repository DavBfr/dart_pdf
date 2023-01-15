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

void main() {
  setUpAll(() {
    Document.debug = true;
    RichText.debug = true;
    pdf = Document();
  });

  group('LineChart test', () {
    test('Default LineChart', () {
      pdf.addPage(Page(
        pageFormat: PdfPageFormat.standard.landscape,
        build: (Context context) => Chart(
          grid: CartesianGrid(
            xAxis: FixedAxis<int>(<int>[0, 1, 2, 3, 4, 5, 6]),
            yAxis: FixedAxis<int>(<int>[0, 3, 6, 9], divisions: true),
          ),
          datasets: <Dataset>[
            LineDataSet(
              data: const <PointChartValue>[
                PointChartValue(1, 1),
                PointChartValue(2, 3),
                PointChartValue(3, 7),
              ],
            ),
          ],
        ),
      ));
    });

    test('Default LineChart without lines connecting points', () {
      pdf.addPage(Page(
        pageFormat: PdfPageFormat.standard.landscape,
        build: (Context context) => Chart(
          grid: CartesianGrid(
            xAxis: FixedAxis<int>(<int>[0, 1, 2, 3, 4, 5, 6]),
            yAxis: FixedAxis<int>(<int>[0, 3, 6, 9], divisions: true),
          ),
          datasets: <Dataset>[
            LineDataSet(
              data: const <PointChartValue>[
                PointChartValue(1, 1),
                PointChartValue(2, 3),
                PointChartValue(3, 7),
              ],
              drawLine: false,
            ),
          ],
        ),
      ));
    });

    test('Default ScatterChart without dots', () {
      pdf.addPage(Page(
        build: (Context context) => Chart(
          grid: CartesianGrid(
            xAxis: FixedAxis<int>(<int>[0, 1, 2, 3, 4, 5, 6]),
            yAxis: FixedAxis<int>(<int>[0, 3, 6, 9], divisions: true),
          ),
          datasets: <Dataset>[
            LineDataSet(
              data: const <PointChartValue>[
                PointChartValue(1, 1),
                PointChartValue(2, 3),
                PointChartValue(3, 7),
              ],
              drawPoints: false,
            ),
          ],
        ),
      ));
    });

    test('ScatterChart with custom points and lines', () {
      pdf.addPage(Page(
        pageFormat: PdfPageFormat.standard.landscape,
        build: (Context context) => Chart(
          grid: CartesianGrid(
            xAxis: FixedAxis<int>(<int>[0, 1, 2, 3, 4, 5, 6]),
            yAxis: FixedAxis<int>(<int>[0, 3, 6, 9], divisions: true),
          ),
          datasets: <Dataset>[
            LineDataSet(
              data: const <PointChartValue>[
                PointChartValue(1, 1),
                PointChartValue(2, 3),
                PointChartValue(3, 7),
              ],
              drawLine: false,
              pointColor: PdfColors.red,
              pointSize: 4,
              color: PdfColors.purple,
              lineWidth: 4,
            ),
          ],
        ),
      ));
    });

    test('ScatterChart with custom size', () {
      pdf.addPage(Page(
        pageFormat: PdfPageFormat.standard.landscape,
        build: (Context context) => SizedBox(
          width: 200,
          height: 100,
          child: Chart(
            grid: CartesianGrid(
              xAxis: FixedAxis<int>(<int>[0, 1, 2, 3, 4, 5, 6]),
              yAxis: FixedAxis<int>(<int>[0, 3, 6, 9], divisions: true),
            ),
            datasets: <Dataset>[
              LineDataSet(
                data: const <PointChartValue>[
                  PointChartValue(1, 1),
                  PointChartValue(2, 3),
                  PointChartValue(3, 7),
                ],
              ),
            ],
          ),
        ),
      ));
    });

    test('LineChart with curved lines', () {
      pdf.addPage(Page(
        pageFormat: PdfPageFormat.standard.landscape,
        build: (Context context) => Chart(
          grid: CartesianGrid(
            xAxis: FixedAxis<int>(<int>[0, 1, 2, 3, 4, 5, 6]),
            yAxis: FixedAxis<int>(<int>[0, 3, 6, 9], divisions: true),
          ),
          datasets: <Dataset>[
            LineDataSet(
              drawPoints: false,
              isCurved: true,
              data: const <PointChartValue>[
                PointChartValue(1, 1),
                PointChartValue(3, 7),
                PointChartValue(5, 3),
              ],
            ),
          ],
        ),
      ));
    });
  });

  group('BarChart test', () {
    test('Default BarChart', () {
      pdf.addPage(Page(
        pageFormat: PdfPageFormat.standard.landscape,
        build: (Context context) => Chart(
          grid: CartesianGrid(
            xAxis: FixedAxis<int>(<int>[0, 1, 2, 3, 4, 5, 6]),
            yAxis: FixedAxis<int>(<int>[0, 3, 6, 9], divisions: true),
          ),
          datasets: <Dataset>[
            BarDataSet(
              data: const <PointChartValue>[
                PointChartValue(1, 1),
                PointChartValue(2, 3),
                PointChartValue(3, 7),
              ],
            ),
          ],
        ),
      ));
    });

    test('Vertical BarChart', () {
      pdf.addPage(Page(
        pageFormat: PdfPageFormat.standard.landscape,
        build: (Context context) => Chart(
          grid: CartesianGrid(
            xAxis: FixedAxis<int>(<int>[0, 1, 2, 3, 4, 5, 6]),
            yAxis: FixedAxis<int>(<int>[0, 3, 6, 9], divisions: true),
          ),
          datasets: <Dataset>[
            BarDataSet(
              axis: Axis.vertical,
              data: const <PointChartValue>[
                PointChartValue(1, 1),
                PointChartValue(2, 3),
                PointChartValue(3, 7),
              ],
            ),
          ],
        ),
      ));
    });
  });

  test('Standard PieChart', () {
    const data = <String, double>{
      'Wind': 8.4,
      'Hydro': 7.4,
      'Solar': 2.4,
      'Biomass': 1.4,
      'Geothermal': 0.4,
      'Nuclear': 20,
      'Coal': 19,
      'Petroleum': 1,
      'Natural gas': 40,
    };
    var color = 0;

    pdf.addPage(
      Page(
        pageFormat: PdfPageFormat.standard.landscape,
        build: (Context context) => Chart(
          title: Text('Sources of U.S. electricity generation, 2020'),
          grid: PieGrid(),
          datasets: [
            for (final item in data.entries)
              PieDataSet(
                legend: item.key,
                value: item.value,
                color: PdfColors
                    .primaries[(color++) * 4 % PdfColors.primaries.length],
                offset: color == 6 ? 30 : 0,
              ),
          ],
        ),
      ),
    );
  });

  test('Donnuts PieChart', () {
    const internalRadius = 150.0;
    const data = <String, int>{
      'Dogs': 5528,
      'Birds': 2211,
      'Rabbits': 3216,
      'Ermine': 740,
      'Cats': 8241,
    };
    var color = 0;
    final total = data.values.fold<int>(0, (v, e) => v + e);

    pdf.addPage(
      Page(
        pageFormat: PdfPageFormat.standard.landscape,
        build: (Context context) => Stack(
          alignment: Alignment.center,
          children: [
            Text(
              'Pets',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 30),
            ),
            Chart(
              grid: PieGrid(startAngle: 1),
              datasets: [
                for (final item in data.entries)
                  PieDataSet(
                    legend: '${item.key} ${item.value * 100 ~/ total}%',
                    value: item.value,
                    color: PdfColors
                        .primaries[(color++) * 2 % PdfColors.primaries.length],
                    innerRadius: internalRadius,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  });

  tearDownAll(() async {
    final file = File('widgets-chart.pdf');
    await file.writeAsBytes(await pdf.save());
  });
}
