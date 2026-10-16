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

/// Lay [child] out on an A4 page and return the raw PDF.
Future<String> build(Widget child) async {
  final document = Document(compress: false);
  document.addPage(
    Page(pageFormat: PdfPageFormat.a4, build: (Context context) => child),
  );
  return String.fromCharCodes(await document.save());
}

void main() {
  group('a Stack on an unbounded axis', () {
    test('writes no non-finite operand', () async {
      // constraints.biggest is infinite on an unbounded axis, and a Stack sits on
      // one in ordinary trees. The infinite box reached drawRect for the overflow
      // clip - '0 0 Infinity 728.5 re W n', which a viewer drops along with the
      // whole stack - and Alignment.inscribe subtracted two infinities, handing
      // every child a NaN offset.
      final cases = <String, Widget>{
        'only Positioned children': Row(
          children: <Widget>[
            Stack(
              children: <Widget>[Positioned(left: 0, top: 0, child: Text('x'))],
            ),
          ],
        ),
        'StackFit.expand': Row(
          children: <Widget>[
            Stack(
              fit: StackFit.expand,
              children: <Widget>[
                Container(width: 10, height: 10, color: PdfColors.red),
              ],
            ),
          ],
        ),
        'an empty Stack': Row(
          children: <Widget>[Stack(children: const <Widget>[])],
        ),
        'inside a ListView': ListView(
          children: <Widget>[
            Stack(
              children: <Widget>[Positioned(left: 0, top: 0, child: Text('x'))],
            ),
          ],
        ),
      };

      for (final entry in cases.entries) {
        final pdf = await build(entry.value);
        expect(pdf, isNot(contains('Infinity')), reason: entry.key);
        expect(pdf, isNot(contains('NaN')), reason: entry.key);
      }
    });

    test('keeps a finite, non-negative box', () async {
      // A Row hands a child an unbounded width and a Column an unbounded height,
      // which is how a Stack ends up on an unbounded axis in ordinary trees.
      Widget wrap(String axes, Widget child) {
        switch (axes) {
          case 'width':
            return Row(children: <Widget>[child]);
          case 'height':
            return Column(children: <Widget>[child]);
          case 'both':
            return Row(
              children: <Widget>[
                Column(children: <Widget>[child]),
              ],
            );
        }
        return SizedBox(width: 100, height: 100, child: child);
      }

      for (final fit in StackFit.values) {
        for (final children in <String, List<Widget>>{
          'no children': const <Widget>[],
          'only Positioned': <Widget>[
            Positioned(left: 0, top: 0, child: Text('x')),
          ],
          'a plain child': <Widget>[
            Container(width: 10, height: 10, color: PdfColors.red),
          ],
        }.entries) {
          for (final axes in <String>['none', 'width', 'height', 'both']) {
            late Stack stack;
            final document = Document();
            document.addPage(
              Page(
                pageFormat: PdfPageFormat.a4,
                build: (Context context) => wrap(
                  axes,
                  stack = Stack(fit: fit, children: children.value),
                ),
              ),
            );
            await document.save();

            final label = '$fit with ${children.key}, unbounded $axes';
            final box = stack.box!;
            expect(box.width.isFinite, isTrue, reason: label);
            expect(box.height.isFinite, isTrue, reason: label);
            expect(box.width, greaterThanOrEqualTo(0), reason: label);
            expect(box.height, greaterThanOrEqualTo(0), reason: label);
            expect(box.left.isFinite, isTrue, reason: label);
            expect(box.bottom.isFinite, isTrue, reason: label);
          }
        }
      }
    });

    test('an empty Stack saves', () async {
      await expectLater(
        build(Row(children: <Widget>[Stack(children: const <Widget>[])])),
        completes,
      );
    });

    test('every child of a StackFit.expand keeps a finite offset', () async {
      final pdf = await build(
        Row(
          children: <Widget>[
            Stack(
              fit: StackFit.expand,
              children: <Widget>[Text('x'), Text('y')],
            ),
          ],
        ),
      );

      final operands = RegExp(r'([-\d.]+) ([-\d.]+) Td').allMatches(pdf);
      expect(operands, isNotEmpty);
      for (final operand in operands) {
        expect(double.parse(operand.group(1)!).isFinite, isTrue);
        expect(double.parse(operand.group(2)!).isFinite, isTrue);
      }
    });
  });

  test('a bounded Stack is unchanged', () async {
    final pdf = await build(
      SizedBox(
        width: 100,
        height: 100,
        child: Stack(
          children: <Widget>[
            Container(width: 20, height: 20, color: PdfColors.red),
            Positioned(left: 5, top: 5, child: Text('x')),
          ],
        ),
      ),
    );

    expect(RegExp(r'[-\d.]+ [-\d.]+ 20 20 re').hasMatch(pdf), isTrue);
    expect(pdf, isNot(contains('Infinity')));
  });
}
