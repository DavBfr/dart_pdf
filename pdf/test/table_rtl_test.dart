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

import 'package:pdf/widgets.dart';
import 'package:test/test.dart';

const _headers = <String>['الاسم', 'الكمية', 'السعر'];
const _data = <List<String>>[
  <String>['قلم', '2', '15'],
  <String>['دفتر', '1', '30'],
];

/// Extract the text of a cell built by [TableHelper.fromTextArray].
String _cellText(Widget cell) {
  if (cell is Container) {
    final child = cell.child;
    return child == null ? '' : _cellText(child);
  }
  if (cell is RichText) {
    final span = cell.text;
    return span is TextSpan ? (span.text ?? '') : '';
  }
  return '';
}

List<String> _rowTexts(TableRow row) => row.children.map(_cellText).toList();

void main() {
  test('LTR tables keep the declared column order', () {
    final table = TableHelper.fromTextArray(
      headers: _headers,
      data: _data,
      tableDirection: TextDirection.ltr,
    );

    expect(_rowTexts(table.children[0]), _headers);
    expect(_rowTexts(table.children[1]), _data[0]);
    expect(_rowTexts(table.children[2]), _data[1]);
  });

  test('LTR tables are the default when no direction is given', () {
    final table = TableHelper.fromTextArray(headers: _headers, data: _data);

    expect(_rowTexts(table.children[0]), _headers);
    expect(_rowTexts(table.children[1]), _data[0]);
  });

  test('RTL tables lay the first logical column out on the right', () {
    final table = TableHelper.fromTextArray(
      headers: _headers,
      data: _data,
      tableDirection: TextDirection.rtl,
    );

    expect(_rowTexts(table.children[0]), _headers.reversed.toList());
    expect(_rowTexts(table.children[1]), _data[0].reversed.toList());
    expect(_rowTexts(table.children[2]), _data[1].reversed.toList());
  });

  test('RTL cells inherit the table text direction', () {
    final table = TableHelper.fromTextArray(
      headers: _headers,
      data: _data,
      tableDirection: TextDirection.rtl,
    );

    final cell = table.children[1].children.first as Container;
    expect((cell.child! as Text).textDirection, TextDirection.rtl);
  });

  test('headerDirection still overrides the table direction', () {
    final table = TableHelper.fromTextArray(
      headers: _headers,
      data: _data,
      tableDirection: TextDirection.rtl,
      headerDirection: TextDirection.ltr,
    );

    final cell = table.children[0].children.first as Container;
    expect((cell.child! as Text).textDirection, TextDirection.ltr);
  });

  test('cell callbacks keep the logical column index in RTL tables', () {
    final indices = <int>[];

    TableHelper.fromTextArray(
      data: <List<String>>[
        <String>['a', 'b', 'c'],
      ],
      headerCount: 0,
      tableDirection: TextDirection.rtl,
      cellBuilder: (index, data, rowNum) {
        indices.add(index);
        return Text(data.toString());
      },
    );

    expect(indices, <int>[0, 1, 2]);
  });

  // Regression test for https://github.com/DavBfr/dart_pdf/issues/1526
  test('issue #1526: the first logical column is the rightmost in RTL', () {
    const rows = <List<String>>[
      <String>['احمد', 'هلاوو اشلونك', 'العنوان'],
      <String>['1993', 'احمد اياد محمد البغدادى', 'Acrobat 1'],
      <String>['1994', 'PDF 1.1', 'Acrobat 2'],
    ];

    final ltr = TableHelper.fromTextArray(data: rows);
    expect(_rowTexts(ltr.children[0]), <String>[
      'احمد',
      'هلاوو اشلونك',
      'العنوان',
    ]);
    expect(_rowTexts(ltr.children[1]), <String>[
      '1993',
      'احمد اياد محمد البغدادى',
      'Acrobat 1',
    ]);

    final rtl = TableHelper.fromTextArray(
      data: rows,
      headerDirection: TextDirection.rtl,
      tableDirection: TextDirection.rtl,
      cellAlignment: Alignment.centerRight,
    );

    // Left to right: the year column ends up on the right.
    final header = _rowTexts(rtl.children[0]);
    expect(header.last, 'احمد');
    expect(header.first, 'العنوان');

    final firstRow = _rowTexts(rtl.children[1]);
    expect(firstRow.last, '1993');
    expect(firstRow.first, 'Acrobat 1');
  });

  test('Table.fromTextArray forwards the table direction', () {
    // ignore: deprecated_member_use_from_same_package
    final table = Table.fromTextArray(
      headers: _headers,
      data: _data,
      tableDirection: TextDirection.rtl,
    );

    expect(_rowTexts(table.children[0]), _headers.reversed.toList());
  });
}
