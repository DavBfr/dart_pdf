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
      tableRow.add(
        Container(
          alignment: Alignment.center,
          margin: const EdgeInsets.all(5),
          child: Text(cell, style: Theme.of(context!).tableHeader),
        ),
      );
    }
    rows.add(TableRow(children: tableRow, repeat: repeatHeader));
  }

  for (var y = 0; y < count; y++) {
    final h = math.sin(y / count) * 365;
    final PdfColor color = PdfColorHsv(h, 1.0, 1.0);
    final tableRow = <Widget>[
      Container(
        margin: const EdgeInsets.all(5),
        child: Text('${h.toInt()}°', style: Theme.of(context!).tableCell),
      ),
      Container(
        margin: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: color,
          borderRadius: const BorderRadius.all(Radius.circular(5)),
        ),
        height: Theme.of(context).tableCell.fontSize,
      ),
      Container(
        margin: const EdgeInsets.all(5),
        child: Text(color.toHex(), style: Theme.of(context).tableCell),
      ),
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
    pdf.addPage(Page(build: (Context context) => Table()));
  });

  test('Table Widget filled', () {
    pdf.addPage(
      Page(
        build: (Context context) => Table(
          children: buildTable(context: context, count: 20),
          border: TableBorder.all(),
          tableWidth: TableWidth.max,
        ),
      ),
    );
  });

  test('Table Widget multi-pages', () {
    pdf.addPage(
      MultiPage(
        build: (Context context) => <Widget>[
          Table(
            children: buildTable(context: context, count: 200),
            border: TableBorder.all(),
            tableWidth: TableWidth.max,
          ),
        ],
      ),
    );
  });

  test('Table Widget multi-pages with header', () {
    pdf.addPage(
      MultiPage(
        build: (Context context) => <Widget>[
          Table(
            children: buildTable(
              context: context,
              count: 200,
              repeatHeader: true,
            ),
            border: TableBorder.all(),
            tableWidth: TableWidth.max,
          ),
        ],
      ),
    );
  });

  test('Table Widget multi-pages short', () {
    pdf.addPage(
      MultiPage(
        build: (Context context) => <Widget>[
          SizedBox(height: 710),
          Table(
            children: buildTable(context: context, count: 4),
            border: TableBorder.all(),
            tableWidth: TableWidth.max,
          ),
        ],
      ),
    );
  });

  test('Table Widget multi-pages short header', () {
    pdf.addPage(
      MultiPage(
        build: (Context context) => <Widget>[
          SizedBox(height: 710),
          Table(
            children: buildTable(
              context: context,
              count: 4,
              repeatHeader: true,
            ),
            border: TableBorder.all(),
            tableWidth: TableWidth.max,
          ),
        ],
      ),
    );
  });

  test('Table Widget Widths', () {
    pdf.addPage(
      Page(
        build: (Context context) => Table(
          children: buildTable(context: context, count: 20),
          border: TableBorder.all(),
          columnWidths: <int, TableColumnWidth>{
            0: const FixedColumnWidth(80),
            1: const FlexColumnWidth(2),
            2: const FractionColumnWidth(.2),
          },
        ),
      ),
    );
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
                      Container(child: Text('Vertical'), color: PdfColors.red),
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
    pdf.addPage(
      Page(
        build: (Context context) => TableHelper.fromTextArray(
          context: context,
          tableWidth: TableWidth.min,
          data: <List<dynamic>>[
            <dynamic>['One', 'Two', 'Three'],
            <dynamic>[1, 2, 3],
            <dynamic>[4, 5, 6],
          ],
        ),
      ),
    );
  });

  test('Table fromTextArray with formatting', () {
    pdf.addPage(
      Page(
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
              bottom: BorderSide(color: PdfColors.indigo, width: .5),
            ),
          ),
          headers: <dynamic>['One', 'Two', 'Three'],
          data: <List<dynamic>>[
            <dynamic>[1, 2, 3],
            <dynamic>[4, 5, 6],
            <dynamic>[7, 8, 9],
          ],
        ),
      ),
    );
  });

  test('Table fromTextArray with directionality', () {
    pdf.addPage(
      Page(
        theme: ThemeData.withFont(base: loadFont('hacen-tunisia.ttf')),
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
      ),
    );
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

  test('a row of empty cells keeps its height', () async {
    // A whitespace-only Text laid out 0 x 0, so the row collapsed to a hairline.
    late Table table;
    final document = Document();
    document.addPage(
      Page(
        pageFormat: const PdfPageFormat(400, 300, marginAll: 0),
        theme: ThemeData.withFont(base: loadFont('open-sans.ttf')),
        build: (Context context) => table = Table(
          children: <TableRow>[
            for (final row in <List<String>>[
              <String>['a', 'b'],
              <String>['', ''],
              <String>['c', 'd'],
            ])
              TableRow(
                children: <Widget>[
                  for (final cell in row)
                    Text(cell, style: const TextStyle(fontSize: 12)),
                ],
              ),
          ],
        ),
      ),
    );
    await document.save();

    expect(table.box!.height, closeTo(3 * 16.341796875, 0.001));
  });

  group('a decorated row', () {
    Future<String> build(List<TableRow> rows) async {
      final document = Document(compress: false);
      document.addPage(
        Page(
          pageFormat: PdfPageFormat.a4,
          build: (Context context) => Table(children: rows),
        ),
      );
      return String.fromCharCodes(await document.save());
    }

    TableRow cells(List<String> texts, {BoxDecoration? decoration}) => TableRow(
      decoration: decoration,
      children: <Widget>[for (final text in texts) Text(text)],
    );

    /// Every `re` rectangle, as 'x,y wxh'.
    List<String> rects(String pdf) =>
        RegExp(r'([-\d.]+) ([-\d.]+) ([-\d.]+) ([-\d.]+) re')
            .allMatches(pdf)
            .map(
              (RegExpMatch m) =>
                  '${m.group(1)},${m.group(2)} ${m.group(3)}x${m.group(4)}',
            )
            .toList();

    const grey = BoxDecoration(color: PdfColors.grey);

    test('with no children paints a zero-height band', () async {
      // Both decoration phases seeded the band as y = infinity, h = 0 and lowered
      // y only inside the children loop, so a row with an empty children list
      // left y infinite: the stream carried '0 Infinity <w> 0 re' and poppler
      // dropped everything drawn after it.
      final pdf = await build(<TableRow>[
        cells(<String>['a', 'b']),
        TableRow(decoration: grey, children: const <Widget>[]),
        cells(<String>['c', 'd']),
      ]);

      expect(pdf, isNot(contains('Infinity')));
      expect(pdf, isNot(contains('NaN')));

      // The band sits where layout put the row, with the height layout gave it.
      expect(rects(pdf), contains('0,13.872 481.88976x0'));

      // And the rows after it are still drawn.
      expect(
        RegExp(
          r'\[\((\w+)\)\]TJ',
        ).allMatches(pdf).map((RegExpMatch m) => m.group(1)).toList(),
        <String>['a', 'b', 'c', 'd'],
      );
    });

    test('with children is unchanged', () async {
      final pdf = await build(<TableRow>[
        cells(<String>['a', 'b'], decoration: grey),
        cells(<String>['c', 'd'], decoration: grey),
      ]);

      // The two decoration bands, which are the only full-width rectangles in
      // the table's own coordinates. The debug paint adds its own boxes.
      expect(
        rects(
          pdf,
        ).where((String r) => r.endsWith(' 481.88976x13.872')).toList(),
        <String>['0,13.872 481.88976x13.872', '0,0 481.88976x13.872'],
      );
    });

    test('an empty row with no decoration is unchanged', () async {
      final pdf = await build(<TableRow>[
        cells(<String>['a', 'b']),
        TableRow(children: const <Widget>[]),
        cells(<String>['c', 'd']),
      ]);

      expect(pdf, isNot(contains('Infinity')));
      expect(
        RegExp(
          r'\[\((\w+)\)\]TJ',
        ).allMatches(pdf).map((RegExpMatch m) => m.group(1)).toList(),
        <String>['a', 'b', 'c', 'd'],
      );
    });
  });

  group('a table whose columns all measure zero', () {
    /// Lay [make] out on an A4 page and hand back the table and the raw PDF.
    Future<List<Object>> build(Table Function() make) async {
      late Table table;
      final document = Document(compress: false);
      document.addPage(
        Page(
          pageFormat: PdfPageFormat.a4,
          build: (Context context) => table = make(),
        ),
      );
      final pdf = String.fromCharCodes(await document.save());
      return <Object>[table, pdf];
    }

    List<TableRow> emptyCells() => <TableRow>[
      TableRow(children: <Widget>[SizedBox(), SizedBox()]),
      TableRow(children: <Widget>[SizedBox(), SizedBox()]),
    ];

    test('fills the available width instead of dividing by zero', () async {
      // The widths were scaled as _widths[n] / maxWidth * maxWidth, and with
      // every column measuring zero that is 0.0/0.0: NaN landed in the widths, in
      // the table box, in every cell box and in drawRect. Release wrote
      // 'q 0 0 NaN 0 re W n'.
      final result = await build(
        () => Table(border: TableBorder.all(), children: emptyCells()),
      );
      final table = result.first as Table;

      expect(result.last, isNot(contains('NaN')));
      expect(table.box!.width, closeTo(PdfPageFormat.a4.availableWidth, 0.001));
      expect(table.box!.height.isFinite, isTrue);
    });

    test('stays zero wide for TableWidth.min', () async {
      final result = await build(
        () => Table(
          tableWidth: TableWidth.min,
          border: TableBorder.all(),
          children: emptyCells(),
        ),
      );

      expect((result.first as Table).box!.width, 0.0);
      expect(result.last, isNot(contains('NaN')));
    });

    test('holds for FixedColumnWidth(0) as well', () async {
      final result = await build(
        () => Table(
          columnWidths: const <int, TableColumnWidth>{
            0: FixedColumnWidth(0),
            1: FixedColumnWidth(0),
          },
          children: <TableRow>[
            TableRow(children: <Widget>[Text('a'), Text('b')]),
          ],
        ),
      );

      expect(result.last, isNot(contains('NaN')));
      expect(
        (result.first as Table).box!.width,
        closeTo(PdfPageFormat.a4.availableWidth, 0.001),
      );
    });

    test('a table with content is unchanged', () async {
      final result = await build(
        () => Table(
          border: TableBorder.all(),
          children: <TableRow>[
            TableRow(children: <Widget>[Text('hello'), Text('world')]),
          ],
        ),
      );

      expect(
        (result.first as Table).box!.width,
        closeTo(PdfPageFormat.a4.availableWidth, 0.001),
      );
      expect(result.last, isNot(contains('NaN')));
    });
  });

  group('the column width solver', () {
    test('never squeezes a column below its longest word', () async {
      // The columns were rescaled by one factor with no per-column floor, so an
      // overflowing table squeezed a short column below the width of one word and
      // the cell hard-split it: 'ATLANTICA' came out as ATLANTI then CA.
      late Table table;
      late double atlantica;

      final document = Document(compress: false);
      document.addPage(
        Page(
          pageFormat: PdfPageFormat.a4,
          build: (Context context) {
            // What one word needs, measured the way the cell measures it.
            final word = Text('ATLANTICA', style: Theme.of(context).tableCell);
            word.layout(
              context.inheritFrom(const MinContentWidth()),
              const BoxConstraints(),
            );
            atlantica = word.box!.width;

            return table = TableHelper.fromTextArray(
              headers: <String>[
                'Codigo',
                'Descricao do Produto ou Servico',
                'Quantidade',
                'Situacao',
              ],
              data: <List<String>>[
                <String>[
                  '1',
                  'Servico de manutencao preventiva de equipamentos ind',
                  '10',
                  'ATLANTICA',
                ],
                <String>[
                  '2',
                  'Outro servico com uma descricao bastante longa tambem',
                  '5',
                  'ATLANTICA',
                ],
              ],
            );
          },
        ),
      );
      final pdf = String.fromCharCodes(await document.save());

      final cells = table.children[1].children;
      expect(
        cells.last.box!.width,
        greaterThanOrEqualTo(atlantica + 10),
        reason: 'the word plus the 5pt padding on each side',
      );

      // And the widths still fill the table exactly.
      expect(
        cells.fold<double>(0, (double sum, Widget c) => sum + c.box!.width),
        closeTo(PdfPageFormat.a4.availableWidth, 0.001),
      );

      final runs = RegExp(
        r'\[\(([^)]*)\)\]TJ',
      ).allMatches(pdf).map((RegExpMatch m) => m.group(1)!).toList();
      expect(runs, contains('ATLANTICA'));
      expect(runs, contains('Situacao'));
      expect(runs, isNot(contains('ATLANTI')));
    });

    test('leaves a table that fits exactly as it was', () async {
      for (final width in <TableWidth>[TableWidth.max, TableWidth.min]) {
        late Table table;
        final document = Document();
        document.addPage(
          Page(
            pageFormat: PdfPageFormat.a4,
            build: (Context context) => table = Table(
              tableWidth: width,
              children: <TableRow>[
                TableRow(children: <Widget>[Text('a'), Text('b')]),
              ],
            ),
          ),
        );
        await document.save();

        final expected = width == TableWidth.max
            ? PdfPageFormat.a4.availableWidth / 2
            : 6.672;
        for (final cell in table.children.first.children) {
          expect(cell.box!.width, closeTo(expected, 1e-9), reason: '$width');
        }
      }
    });

    test('completes when not even the minimums fit', () async {
      late Table table;
      final document = Document(compress: false);
      document.addPage(
        Page(
          pageFormat: const PdfPageFormat(40, 300, marginAll: 0),
          build: (Context context) => table = TableHelper.fromTextArray(
            cellPadding: EdgeInsets.zero,
            headers: <String>['h1', 'h2', 'h3'],
            data: <List<String>>[
              <String>[
                'Pneumonoultramicroscopic silicovolcanoconiosis',
                'Antidisestablishmentarianism opposition',
                'Incomprehensibilities notwithstanding',
              ],
            ],
          ),
        ),
      );
      final pdf = String.fromCharCodes(await document.save());

      final widths = table.children[1].children
          .map((Widget c) => c.box!.width)
          .toList();
      for (final width in widths) {
        expect(width.isFinite, isTrue);
        expect(width, greaterThan(0));
      }
      expect(widths.reduce((double a, double b) => a + b), closeTo(40, 0.001));
      expect(pdf, isNot(contains('NaN')));
    });
  });

  tearDownAll(() async {
    final file = File('widgets-table.pdf');
    await file.writeAsBytes(await pdf.save());
  });
}
