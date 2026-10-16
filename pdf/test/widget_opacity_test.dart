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

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart';
import 'package:test/test.dart';

/// Lay [child] out alone and hand back the whole file.
Future<String> build(Widget child) async {
  final document = Document(compress: false);
  document.addPage(
    Page(
      pageFormat: const PdfPageFormat(100, 100, marginAll: 0),
      build: (Context context) => child,
    ),
  );
  return String.fromCharCodes(await document.save());
}

/// Every constant fill alpha the document declares.
List<String> fillAlphas(String pdf) =>
    RegExp(r'/ca ([\d.]+)').allMatches(pdf).map((m) => m.group(1)!).toList();

void main() {
  test('an Opacity over an opaque child is unchanged', () async {
    final pdf = await build(
      Opacity(
        opacity: 0.5,
        child: Container(width: 10, height: 10, color: PdfColors.red),
      ),
    );

    expect(fillAlphas(pdf), <String>['0.5']);
  });

  test('an Opacity over a translucent child multiplies', () async {
    // The gs operator sets the constant alpha absolutely rather than multiplying
    // it, so the product has to be computed before it is written.
    final pdf = await build(
      Opacity(
        opacity: 0.5,
        child: Container(
          width: 10,
          height: 10,
          color: const PdfColor(1, 0, 0, 0.5),
        ),
      ),
    );

    expect(fillAlphas(pdf), containsAll(<String>['0.5', '0.25']));
  });

  test('nested Opacity composes', () async {
    final pdf = await build(
      Opacity(
        opacity: 0.5,
        child: Opacity(
          opacity: 0.5,
          child: Container(width: 10, height: 10, color: PdfColors.red),
        ),
      ),
    );

    expect(fillAlphas(pdf), containsAll(<String>['0.5', '0.25']));
  });

  test('a translucent colour outside an Opacity is unaffected by it', () async {
    final pdf = await build(
      Column(
        children: <Widget>[
          Opacity(
            opacity: 0.5,
            child: Container(width: 10, height: 10, color: PdfColors.red),
          ),
          Container(width: 10, height: 10, color: const PdfColor(0, 0, 1, 0.5)),
        ],
      ),
    );

    // The Opacity's 0.5 is inside its own q/Q, so the second container's own
    // alpha is 0.5 and not 0.25. (Two states of the same value are declared,
    // one per q level; they are not deduplicated.)
    expect(fillAlphas(pdf), everyElement('0.5'));
    expect(fillAlphas(pdf), hasLength(2));
  });

  test('a translucent border strokes translucent', () async {
    final pdf = await build(
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          border: Border.all(color: const PdfColor(0, 0, 0, 0.25), width: 2),
        ),
      ),
    );

    expect(pdf, contains('/CA 0.25'));
  });

  test('translucent text fills translucent', () async {
    final pdf = await build(
      Text('hello', style: const TextStyle(color: PdfColor(1, 0, 0, 0.5))),
    );

    expect(fillAlphas(pdf), contains('0.5'));
  });
}
