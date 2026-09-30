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
import 'dart:math' as math;

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

  group('a pie chart', () {
    /// Lay the datasets out in a 300x300 box and return the raw PDF.
    Future<String> build(
      List<PieDataSet> datasets, {
      double startAngle = 0,
    }) async {
      final document = Document(compress: false);
      document.addPage(
        Page(
          pageFormat: PdfPageFormat.a4,
          build: (Context context) => SizedBox(
            width: 300,
            height: 300,
            child: Chart(
              grid: PieGrid(startAngle: startAngle),
              datasets: datasets,
            ),
          ),
        ),
      );
      return String.fromCharCodes(await document.save());
    }

    /// How many bezier segments the stream draws.
    int beziers(String pdf) => RegExp(r'[\d.] c ').allMatches(pdf).length;

    test('of one slice closes the circle whatever the value', () async {
      // The bearings were accumulated as angle += value * (pi / total * 2), and
      // the two roundings left a single slice one ULP short of a full turn for
      // about one value in twenty. The full-circle test was exact, so those went
      // to the wedge branch, whose two endpoints coincide - the arc returns early
      // and the chart came out blank, with no error and no log.
      for (final value in <double>[
        1,
        7,
        10,
        33,
        37.5,
        75,
        87.5,
        100,
        150,
        350,
        1 / 3,
      ]) {
        final slice = PieDataSet(value: value, color: PdfColors.blue);
        final pdf = await build(<PieDataSet>[slice]);

        expect(
          slice.angleEnd - slice.angleStart,
          closeTo(math.pi * 2, 1e-12),
          reason: 'value $value',
        );
        expect(
          beziers(pdf),
          greaterThanOrEqualTo(4),
          reason: 'value $value draws a full ellipse',
        );
      }
    });

    test('of one donut slice, and of a slice plus an empty one', () async {
      final donut = await build(<PieDataSet>[
        PieDataSet(value: 87.5, color: PdfColors.blue, innerRadius: 40),
      ]);
      expect(beziers(donut), greaterThanOrEqualTo(8));

      final full = PieDataSet(value: 100, color: PdfColors.blue);
      final empty = PieDataSet(value: 0, color: PdfColors.red);
      final pdf = await build(<PieDataSet>[full, empty]);

      expect(full.angleEnd - full.angleStart, closeTo(math.pi * 2, 1e-12));
      expect(empty.angleEnd - empty.angleStart, 0);
      expect(beziers(pdf), greaterThanOrEqualTo(4));
    });

    test('of three slices closes the circle from its start angle', () async {
      final slices = <PieDataSet>[
        for (var i = 0; i < 3; i++)
          PieDataSet(value: 1 / 3, color: PdfColors.blue),
      ];
      await build(slices, startAngle: 1);

      expect(slices.last.angleEnd, closeTo(1 + math.pi * 2, 1e-12));
      expect(slices.first.angleStart, 1);
      for (var i = 1; i < slices.length; i++) {
        expect(
          slices[i].angleStart,
          greaterThanOrEqualTo(slices[i - 1].angleStart),
          reason: 'the boundaries stay in order',
        );
      }
    });

    test('with nothing to show saves instead of throwing', () async {
      // `pi / total * 2` was Infinity for a zero total, so `value * unit` was
      // 0 * Infinity = NaN, every bearing was NaN, and the arc's guards are all
      // false for NaN: the sweep count reached .ceil() and threw 'Unsupported
      // operation: Infinity or NaN toInt' out of save(), losing the document.
      for (final entry in <String, List<double>>{
        'all zero': <double>[0, 0],
        'one zero': <double>[0],
        'cancelling out': <double>[-2, 2],
        'not a number': <double>[double.nan, 1],
        'infinite': <double>[double.infinity, 1],
      }.entries) {
        for (final innerRadius in <double>[0, 30]) {
          final pdf = await build(<PieDataSet>[
            for (final value in entry.value)
              PieDataSet(
                value: value,
                color: PdfColors.blue,
                innerRadius: innerRadius,
              ),
          ]);

          final label = '${entry.key}, innerRadius $innerRadius';
          expect(pdf, isNot(contains('NaN')), reason: label);
          expect(pdf, isNot(contains('Infinity')), reason: label);
        }
      }
    });

    test('draws no slice at all when there is no data', () async {
      final slices = <PieDataSet>[
        PieDataSet(value: 0, color: PdfColors.blue),
        PieDataSet(value: 0, color: PdfColors.red),
      ];
      final pdf = await build(slices);

      expect(beziers(pdf), 0, reason: 'no wedge and no border');

      // The legends are still spread around the circle rather than stacked.
      expect(slices.first.angleStart, isNot(slices.last.angleStart));
      for (final slice in slices) {
        expect(slice.angleStart.isFinite, isTrue);
        expect(slice.angleEnd, slice.angleStart);
      }
    });

    test('slice outlines stay on the circle', () async {
      // Two equal slices are two 180-degree arcs, and a half circle is where the
      // radii ratio rounds to an ULP over 1 and goes down bezierArc's scaling
      // branch. That branch left the centre factor at 1.0 instead of 0, so the
      // centre landed a whole radius away and the outline wandered off the
      // circle - a corner of it 35pt inside a 150pt radius. It depends on how the
      // ratio rounds, so the start angle is varied to catch it.
      for (final startAngle in <double>[0, 0.3, 1, 2.5]) {
        final grid = PieGrid(startAngle: startAngle);
        final document = Document(compress: false);
        document.addPage(
          Page(
            pageFormat: PdfPageFormat.a4,
            build: (Context context) => SizedBox(
              width: 300,
              height: 300,
              child: Chart(
                grid: grid,
                datasets: <PieDataSet>[
                  PieDataSet(value: 1, color: PdfColors.blue),
                  PieDataSet(value: 1, color: PdfColors.red),
                ],
              ),
            ),
          ),
        );
        final pdf = String.fromCharCodes(await document.save());

        // Every bezier end point on a wedge is a point of the arc, so it sits at
        // the radius from the centre the grid was translated to.
        final ends = RegExp(
          r'[-\d.]+ [-\d.]+ [-\d.]+ [-\d.]+ ([-\d.]+) ([-\d.]+) c(?![a-z])',
        ).allMatches(pdf);

        expect(ends.length, greaterThanOrEqualTo(4), reason: '$startAngle');
        for (final end in ends) {
          final x = double.parse(end.group(1)!);
          final y = double.parse(end.group(2)!);
          expect(
            math.sqrt(x * x + y * y),
            closeTo(grid.radius, 1e-4),
            reason: 'start angle $startAngle, point ($x, $y)',
          );
        }
      }
    });
  });

  tearDownAll(() async {
    final file = File('widgets-chart.pdf');
    await file.writeAsBytes(await pdf.save());
  });
}
