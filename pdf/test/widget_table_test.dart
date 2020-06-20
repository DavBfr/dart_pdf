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
import 'dart:math' as math;

import 'package:meta/meta.dart';
import 'package:test/test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart';

Document pdf;

List<TableRow> buildTable(
    {@required Context context, int count = 10, bool repeatHeader = false}) {
  final List<TableRow> rows = <TableRow>[];
  {
    final List<Widget> tableRow = <Widget>[];
    for (String cell in <String>['Hue', 'Color', 'RGBA']) {
      tableRow.add(Container(
          alignment: Alignment.center,
          margin: const EdgeInsets.all(5),
          child: Text(cell, style: Theme.of(context).tableHeader)));
    }
    rows.add(TableRow(children: tableRow, repeat: repeatHeader));
  }

  for (int y = 0; y < count; y++) {
    final double h = math.sin(y / count) * 365;
    final PdfColor color = PdfColorHsv(h, 1.0, 1.0);
    final List<Widget> tableRow = <Widget>[
      Container(
          margin: const EdgeInsets.all(5),
          child: Text('${h.toInt()}°', style: Theme.of(context).tableCell)),
      Container(
          margin: const EdgeInsets.all(5),
          decoration: BoxDecoration(color: color, borderRadius: 5),
          height: Theme.of(context).tableCell.fontSize),
      Container(
          margin: const EdgeInsets.all(5),
          child: Text('${color.toHex()}', style: Theme.of(context).tableCell)),
    ];
    rows.add(TableRow(children: tableRow));
  }

  return rows;
}

void main() {
  setUpAll(() {
    Document.debug = true;
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
        border: const TableBorder(),
        tableWidth: TableWidth.max,
      ),
    ));
  });

  test('Table Widget multi-pages', () {
    pdf.addPage(MultiPage(
        build: (Context context) => <Widget>[
              Table(
                children: buildTable(context: context, count: 200),
                border: const TableBorder(),
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
                border: const TableBorder(),
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
                border: const TableBorder(),
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
                border: const TableBorder(),
                tableWidth: TableWidth.max,
              ),
            ]));
  });

  test('Table Widget Widths', () {
    pdf.addPage(Page(
      build: (Context context) => Table(
        children: buildTable(context: context, count: 20),
        border: const TableBorder(),
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
                  final TableCellVerticalAlignment align =
                      TableCellVerticalAlignment.values[
                          index % TableCellVerticalAlignment.values.length];

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
      build: (Context context) => Table.fromTextArray(
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
      build: (Context context) => Table.fromTextArray(
        border: null,
        cellAlignment: Alignment.center,
        headerDecoration: const BoxDecoration(
          borderRadius: 2,
          color: PdfColors.indigo,
        ),
        headerHeight: 25,
        cellHeight: 40,
        headerStyle: TextStyle(
          color: PdfColors.white,
          fontWeight: FontWeight.bold,
        ),
        rowDecoration: const BoxDecoration(
          border: BoxBorder(
            bottom: true,
            color: PdfColors.indigo,
            width: .5,
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

  tearDownAll(() {
    final File file = File('widgets-table.pdf');
    file.writeAsBytesSync(pdf.save());
  });
}
