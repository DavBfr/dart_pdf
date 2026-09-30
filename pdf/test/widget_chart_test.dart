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
      pdf.addPage(
        Page(
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
        ),
      );
    });

    test('Default LineChart without lines connecting points', () {
      pdf.addPage(
        Page(
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
        ),
      );
    });

    test('Default ScatterChart without dots', () {
      pdf.addPage(
        Page(
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
        ),
      );
    });

    test('ScatterChart with custom points and lines', () {
      pdf.addPage(
        Page(
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
        ),
      );
    });

    test('ScatterChart with custom size', () {
      pdf.addPage(
        Page(
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
        ),
      );
    });

    test('LineChart with curved lines', () {
      pdf.addPage(
        Page(
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
        ),
      );
    });
  });

  group('BarChart test', () {
    test('Default BarChart', () {
      pdf.addPage(
        Page(
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
        ),
      );
    });

    test('Vertical BarChart', () {
      pdf.addPage(
        Page(
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
        ),
      );
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

  group('a degenerate chart axis', () {
    /// Lay [chart] out in a 300x200 box and return the raw PDF.
    Future<String> build(Widget chart) async {
      final document = Document(compress: false);
      document.addPage(
        Page(
          pageFormat: PdfPageFormat.a4,
          build: (Context context) =>
              SizedBox(width: 300, height: 200, child: chart),
        ),
      );
      return String.fromCharCodes(await document.save());
    }

    test('a single category is centred rather than divided by zero', () async {
      // toChart divides by the axis range, which is exactly zero for one value or
      // for values that are all equal, so 0.0/0.0 = NaN reached the bars, the
      // ticks and the labels. PdfNum only asserted, so release wrote the token.
      final single = await build(
        Chart(
          grid: CartesianGrid(
            xAxis: FixedAxis.fromStrings(<String>['Phone']),
            yAxis: FixedAxis<int>(<int>[0, 10]),
          ),
          datasets: <Dataset>[
            BarDataSet(data: <PointChartValue>[PointChartValue(0, 5)]),
          ],
        ),
      );
      expect(single, isNot(contains('NaN')));
      expect(single, isNot(contains('Infinity')));

      for (final values in <List<int>>[
        <int>[5],
        <int>[5, 5, 5],
      ]) {
        for (final dataset in <Dataset>[
          LineDataSet(
            data: <PointChartValue>[
              PointChartValue(0, 5),
              PointChartValue(1, 5),
            ],
          ),
          BarDataSet(data: <PointChartValue>[PointChartValue(0, 5)]),
        ]) {
          final pdf = await build(
            Chart(
              grid: CartesianGrid(
                xAxis: FixedAxis<int>(<int>[0, 1]),
                yAxis: FixedAxis<int>(values),
              ),
              datasets: <Dataset>[dataset],
            ),
          );
          expect(pdf, isNot(contains('NaN')), reason: '$values');
        }
      }
    });

    test('sits in the middle of its band, whatever it is asked', () async {
      late FixedAxis<int> axis;
      await build(
        Chart(
          grid: CartesianGrid(
            xAxis: axis = FixedAxis<int>(<int>[5]),
            yAxis: FixedAxis<int>(<int>[0, 10]),
          ),
          datasets: <Dataset>[],
        ),
      );

      final centre = axis.toChart(5);
      expect(centre.isFinite, isTrue);
      expect(centre, greaterThan(axis.box!.left));
      expect(centre, lessThan(axis.box!.right));

      // The fraction is fixed, so every input lands in the same place.
      expect(axis.toChart(0), centre);
      expect(axis.toChart(100), centre);
    });

    test('a normal axis is untouched', () async {
      late FixedAxis<int> axis;
      await build(
        Chart(
          grid: CartesianGrid(
            xAxis: axis = FixedAxis<int>(<int>[0, 3, 6, 9]),
            yAxis: FixedAxis<int>(<int>[0, 10]),
          ),
          datasets: <Dataset>[
            LineDataSet(
              data: <PointChartValue>[
                PointChartValue(0, 1),
                PointChartValue(9, 9),
              ],
            ),
          ],
        ),
      );

      // Bit-identical to HEAD, checked against it.
      expect(axis.values.map((int v) => axis.toChart(v)).toList(), <double>[
        23.344,
        114.45066666666668,
        205.55733333333333,
        296.664,
      ]);
    });
  });

  group('an empty chart axis', () {
    test('constructs, and an unsorted one still does not', () {
      // The constructor's sort check read list.first, so an empty value list threw
      // 'Bad state: No element' and a data-driven chart whose labels came back
      // empty lost the whole document.
      expect(() => FixedAxis<int>(<int>[]), returnsNormally);
      expect(() => FixedAxis.fromStrings(<String>[]), returnsNormally);
      expect(
        () => FixedAxis<int>(<int>[3, 1, 2]),
        throwsA(isA<AssertionError>()),
      );
    });

    test('lays out and renders', () async {
      late FixedAxis<int> x;
      late FixedAxis<int> y;

      final document = Document(compress: false);
      document.addPage(
        Page(
          pageFormat: PdfPageFormat.a4,
          build: (Context context) => Column(
            children: <Widget>[
              SizedBox(
                width: 300,
                height: 150,
                child: Chart(
                  grid: CartesianGrid(
                    xAxis: x = FixedAxis<int>(<int>[]),
                    yAxis: FixedAxis<int>(<int>[0, 10]),
                  ),
                  datasets: <Dataset>[],
                ),
              ),
              SizedBox(
                width: 300,
                height: 150,
                child: Chart(
                  grid: CartesianGrid(
                    xAxis: FixedAxis<int>(<int>[0, 1]),
                    yAxis: y = FixedAxis<int>(<int>[], divisions: true),
                  ),
                  datasets: <Dataset>[
                    LineDataSet(data: <PointChartValue>[PointChartValue(0, 1)]),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
      final pdf = String.fromCharCodes(await document.save());

      expect(x.box, isNotNull);
      expect(y.box, isNotNull);
      expect(x.axisPosition.isFinite, isTrue);
      expect(y.axisPosition.isFinite, isTrue);
      expect(pdf, isNot(contains('NaN')));
      expect(pdf, isNot(contains('Infinity')));
    });
  });

  tearDownAll(() async {
    final file = File('widgets-chart.pdf');
    await file.writeAsBytes(await pdf.save());
  });
}
