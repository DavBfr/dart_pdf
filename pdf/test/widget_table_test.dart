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

import 'utils.dart';

late Document pdf;

List<TableRow> buildTable({
  required Context? context,
  int count = 10,
  bool repeatHeader = false,
}) {
  final rows = <TableRow>[];
  {
    final tableRow = <Widget>[];
    for (final cell in <String>['Hue', 'Color', 'RGBA']) {
      tableRow.add(Container(
          alignment: Alignment.center,
          margin: const EdgeInsets.all(5),
          child: Text(cell, style: Theme.of(context!).tableHeader)));
    }
    rows.add(TableRow(children: tableRow, repeat: repeatHeader));
  }

  for (var y = 0; y < count; y++) {
    final h = math.sin(y / count) * 365;
    final PdfColor color = PdfColorHsv(h, 1.0, 1.0);
    final tableRow = <Widget>[
      Container(
          margin: const EdgeInsets.all(5),
          child: Text('${h.toInt()}°', style: Theme.of(context!).tableCell)),
      Container(
          margin: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.all(Radius.circular(5)),
          ),
          height: Theme.of(context).tableCell.fontSize),
      Container(
          margin: const EdgeInsets.all(5),
          child: Text(color.toHex(), style: Theme.of(context).tableCell)),
    ];
    rows.add(TableRow(children: tableRow));
  }

  return rows;
}

void main() {
  setUpAll(() {
    Document.debug = true;
    RichText.debug = true;
    pdf = Document();
  });

  test('Table Widget empty', () {
    pdf.addPage(Page(
      build: (Context context) => Table(),
    ));
  });

  test('Table Widget filled', () {
    pdf.addPage(Page(
      build: (Context context) => Table(
        children: buildTable(context: context, count: 20),
        border: TableBorder.all(),
        tableWidth: TableWidth.max,
      ),
    ));
  });

  test('Table Widget multi-pages', () {
    pdf.addPage(MultiPage(
        build: (Context context) => <Widget>[
              Table(
                children: buildTable(context: context, count: 200),
                border: TableBorder.all(),
                tableWidth: TableWidth.max,
              ),
            ]));
  });

  test('Table Widget multi-pages with header', () {
    pdf.addPage(MultiPage(
        build: (Context context) => <Widget>[
              Table(
                children: buildTable(
                    context: context, count: 200, repeatHeader: true),
                border: TableBorder.all(),
                tableWidth: TableWidth.max,
              ),
            ]));
  });

  test('Table Widget multi-pages short', () {
    pdf.addPage(MultiPage(
        build: (Context context) => <Widget>[
              SizedBox(height: 710),
              Table(
                children: buildTable(context: context, count: 4),
                border: TableBorder.all(),
                tableWidth: TableWidth.max,
              ),
            ]));
  });

  test('Table Widget multi-pages short header', () {
    pdf.addPage(MultiPage(
        build: (Context context) => <Widget>[
              SizedBox(height: 710),
              Table(
                children:
                    buildTable(context: context, count: 4, repeatHeader: true),
                border: TableBorder.all(),
                tableWidth: TableWidth.max,
              ),
            ]));
  });

  test('Table Widget Widths', () {
    pdf.addPage(Page(
      build: (Context context) => Table(
        children: buildTable(context: context, count: 20),
        border: TableBorder.all(),
        columnWidths: <int, TableColumnWidth>{
          0: const FixedColumnWidth(80),
          1: const FlexColumnWidth(2),
          2: const FractionColumnWidth(.2),
        },
      ),
    ));
  });

  test('Table Widget Column Span', () {
    pdf.addPage(Page(
      build: (Context context) => Table(
        children: [
          TableRow(
            columnSpans: const {0: 2, 2: 1},
            children: [
              Container(color: PdfColors.red, height: 20),
              Container(color: PdfColors.green, height: 20),
            ],
          ),
          TableRow(
            columnSpans: const {1: 2},
            children: [
              Container(color: PdfColors.green, height: 20),
              Container(color: PdfColors.blue, height: 20),
            ],
          ),
          TableRow(
            columnSpans: const {0: 3},
            children: [
              Container(color: PdfColors.red, height: 20),
            ],
          ),
          TableRow(
            children: [
              Container(color: PdfColors.red, height: 20),
              Container(color: PdfColors.blue, height: 20),
              Container(color: PdfColors.green, height: 20),
            ],
          ),
        ],
        border: TableBorder.all(),
        columnWidths: <int, TableColumnWidth>{
          0: const FixedColumnWidth(80),
          1: const FlexColumnWidth(2),
          2: const FractionColumnWidth(.2),
        },
      ),
    ));
  });

  test('Table Widget TableCellVerticalAlignment', () {
    pdf.addPage(
      MultiPage(
        build: (Context context) {
          return <Widget>[
            Table(
              defaultColumnWidth: const FixedColumnWidth(20),
              children: List<TableRow>.generate(
                TableCellVerticalAlignment.values.length,
                (int index) {
                  final align = TableCellVerticalAlignment
                      .values[index % TableCellVerticalAlignment.values.length];

                  return TableRow(
                    verticalAlignment: align,
                    children: <Widget>[
                      Container(
                        child: Text('Vertical'),
                        color: PdfColors.red,
                      ),
                      Container(
                        child: Text('alignment $index'),
                        color: PdfColors.yellow,
                        height: 60,
                      ),
                      Container(
                        child: Text(align.toString().substring(27)),
                        color: PdfColors.green,
                      ),
                    ],
                  );
                },
              ),
            ),
          ];
        },
      ),
    );
  });

  test('Table fromTextArray', () {
    pdf.addPage(Page(
      build: (Context context) => TableHelper.fromTextArray(
        context: context,
        tableWidth: TableWidth.min,
        data: <List<dynamic>>[
          <dynamic>['One', 'Two', 'Three'],
          <dynamic>[1, 2, 3],
          <dynamic>[4, 5, 6],
        ],
      ),
    ));
  });

  test('Table fromTextArray with formatting', () {
    pdf.addPage(Page(
      build: (Context context) => TableHelper.fromTextArray(
        border: null,
        cellAlignment: Alignment.center,
        headerDecoration: const BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(2)),
          color: PdfColors.indigo,
        ),
        headerHeight: 25,
        cellHeight: 40,
        headerStyle: TextStyle(
          color: PdfColors.white,
          fontWeight: FontWeight.bold,
        ),
        rowDecoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: PdfColors.indigo,
              width: .5,
            ),
          ),
        ),
        headers: <dynamic>['One', 'Two', 'Three'],
        data: <List<dynamic>>[
          <dynamic>[1, 2, 3],
          <dynamic>[4, 5, 6],
          <dynamic>[7, 8, 9],
        ],
      ),
    ));
  });

  test('Table fromTextArray with directionality', () {
    pdf.addPage(Page(
      theme: ThemeData.withFont(
        base: loadFont('hacen-tunisia.ttf'),
      ),
      build: (Context context) => Directionality(
        textDirection: TextDirection.rtl,
        child: TableHelper.fromTextArray(
          headers: <dynamic>['ثلاثة', 'اثنان', 'واحد'],
          cellAlignment: Alignment.centerRight,
          data: <List<dynamic>>[
            <dynamic>['الكلب', 'قط', 'ذئب'],
            <dynamic>['فأر', 'بقرة', 'طائر'],
          ],
        ),
      ),
    ));
  });

  test('Table fromTextArray with alignment', () {
    pdf.addPage(
      Page(
        build: (Context context) => TableHelper.fromTextArray(
          cellAlignment: Alignment.center,
          data: <List<String>>[
            <String>['line 1', 'Text\n\n\ntext'],
            <String>['line 2', 'Text\n\n\ntext'],
            <String>['line 3', 'Text\n\n\ntext'],
          ],
        ),
      ),
    );
  });

  tearDownAll(() async {
    final file = File('widgets-table.pdf');
    await file.writeAsBytes(await pdf.save());
  });
}
