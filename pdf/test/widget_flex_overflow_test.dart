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

import 'dart:convert';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart';
import 'package:test/test.dart';

/// The uncompressed bytes of [document], as text, so the drawing operators can
/// be searched for the strings a widget painted.
Future<String> content(Document document) async =>
    latin1.decode(await document.save(), allowInvalid: true);

void main() {
  test('a Column overflowing a fixed height paints every child', () async {
    final document = Document(compress: false);
    document.addPage(
      Page(
        pageFormat: PdfPageFormat.a4,
        build: (Context context) => SizedBox(
          height: 40,
          child: Column(
            children: <Widget>[
              for (var i = 0; i < 5; i++)
                Text('w$i', style: const TextStyle(fontSize: 8)),
            ],
          ),
        ),
      ),
    );

    final text = await content(document);
    for (var i = 0; i < 5; i++) {
      expect(text, contains('(w$i)'), reason: 'child $i must be painted');
    }
  });

  test('a Column whose first child overflows still paints it', () async {
    final document = Document(compress: false);
    document.addPage(
      Page(
        pageFormat: PdfPageFormat.a4,
        build: (Context context) => SizedBox(
          height: 20,
          child: Column(
            children: <Widget>[
              Text('big', style: const TextStyle(fontSize: 30)),
              Text('small', style: const TextStyle(fontSize: 6)),
            ],
          ),
        ),
      ),
    );

    final text = await content(document);
    expect(text, contains('(big)'));
    expect(text, contains('(small)'));
  });

  test('an overflowing Column clips to its box', () async {
    final document = Document(compress: false);
    document.addPage(
      Page(
        pageFormat: PdfPageFormat.a4,
        build: (Context context) => SizedBox(
          height: 20,
          child: Column(
            children: <Widget>[
              Text('big', style: const TextStyle(fontSize: 30)),
              Text('small', style: const TextStyle(fontSize: 6)),
            ],
          ),
        ),
      ),
    );

    expect(await content(document), contains('W n'));
  });

  test('a Row is unaffected', () async {
    final document = Document(compress: false);
    document.addPage(
      Page(
        pageFormat: PdfPageFormat.a4,
        build: (Context context) => SizedBox(
          width: 30,
          child: Row(
            children: <Widget>[
              Text('left', style: const TextStyle(fontSize: 20)),
              Text('right', style: const TextStyle(fontSize: 20)),
            ],
          ),
        ),
      ),
    );

    final text = await content(document);
    expect(text, contains('(left)'));
    expect(text, contains('(right)'));
  });

  test('an overflowing Column keeps its constrained box', () async {
    final column = Column(
      children: <Widget>[
        for (var i = 0; i < 5; i++)
          Text('w$i', style: const TextStyle(fontSize: 8)),
      ],
    );
    final document = Document(compress: false);
    document.addPage(
      Page(
        pageFormat: PdfPageFormat.a4,
        build: (Context context) => SizedBox(height: 40, child: column),
      ),
    );
    await document.save();

    expect(column.box!.height, 40);
  });

  test('a Column nested in a Column still paints both levels', () async {
    final document = Document(compress: false);
    document.addPage(
      Page(
        pageFormat: PdfPageFormat.a4,
        build: (Context context) => Container(
          height: 40,
          child: Column(
            children: <Widget>[
              Column(
                children: <Widget>[
                  for (var i = 0; i < 5; i++)
                    Text('w$i', style: const TextStyle(fontSize: 8)),
                ],
              ),
              Expanded(child: Divider()),
            ],
          ),
        ),
      ),
    );

    final text = await content(document);
    for (var i = 0; i < 5; i++) {
      expect(text, contains('(w$i)'), reason: 'child $i must be painted');
    }
  });
}
