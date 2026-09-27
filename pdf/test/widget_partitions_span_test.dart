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

/// A column of [count] labelled boxes, as a spanning [Wrap] so it reports a
/// real `hasMoreWidgets` instead of hard-coding true.
Wrap _column(int count, String prefix) => Wrap(
  children: List<Widget>.generate(
    count,
    (int i) => SizedBox(
      width: 200,
      height: 20,
      child: Text('$prefix$i', style: const TextStyle(fontSize: 8)),
    ),
  ),
);

void main() {
  test('the longest partition is not truncated by the shortest', () async {
    // 'a' runs out after 3 rows; the widget used to report itself finished at
    // that point and MultiPage dropped the rest of 'b'.
    final document = Document(compress: false);
    document.addPage(
      MultiPage(
        pageFormat: const PdfPageFormat(500, 90, marginAll: 5),
        build: (Context context) => <Widget>[
          Partitions(
            children: <Partition>[
              Partition(child: _column(3, 'a')),
              Partition(child: _column(9, 'b')),
            ],
          ),
        ],
      ),
    );

    final text = latin1.decode(await document.save(), allowInvalid: true);
    for (var i = 0; i < 3; i++) {
      expect('(a$i)'.allMatches(text).length, 1, reason: 'a$i drawn once');
    }
    for (var i = 0; i < 9; i++) {
      expect('(b$i)'.allMatches(text).length, 1, reason: 'b$i drawn once');
    }
  });

  test('a partition wrapping a widget built during layout spans', () async {
    // DefaultTextStyle is a StatelessWidget: it only knows whether it can span
    // once it has been built, so the pre-layout snapshot left its slot null
    // and restoring it dereferenced that null.
    final document = Document(compress: false);
    document.addPage(
      MultiPage(
        pageFormat: const PdfPageFormat(500, 90, marginAll: 5),
        build: (Context context) => <Widget>[
          Partitions(
            children: <Partition>[
              Partition(
                child: DefaultTextStyle(
                  style: const TextStyle(fontSize: 8),
                  child: _column(9, 'c'),
                ),
              ),
              Partition(child: _column(9, 'd')),
            ],
          ),
        ],
      ),
    );

    final text = latin1.decode(await document.save(), allowInvalid: true);
    for (var i = 0; i < 9; i++) {
      expect('(c$i)'.allMatches(text).length, 1, reason: 'c$i drawn once');
      expect('(d$i)'.allMatches(text).length, 1, reason: 'd$i drawn once');
    }
  });
}
