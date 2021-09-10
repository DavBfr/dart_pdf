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
    pdf = Document();
  });

  test('Wrap Widget Horizontal 1', () {
    final wraps = <Widget>[];
    for (var direction in VerticalDirection.values) {
      wraps.add(Text('$direction'));
      for (var alignment in WrapAlignment.values) {
        wraps.add(Text('$alignment'));
        wraps.add(
          Wrap(
            direction: Axis.horizontal,
            verticalDirection: direction,
            alignment: alignment,
            children: List<Widget>.generate(
              40,
              (int n) => Text('${n + 1}'),
            ),
          ),
        );
      }
    }

    pdf.addPage(
      Page(
        pageFormat: const PdfPageFormat(400, 800),
        margin: const EdgeInsets.all(10),
        build: (Context context) => Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: wraps,
        ),
      ),
    );
  });

  test('Wrap Widget Vertical 1', () {
    final wraps = <Widget>[];
    for (var direction in VerticalDirection.values) {
      wraps.add(Transform.rotateBox(child: Text('$direction'), angle: 1.57));
      for (var alignment in WrapAlignment.values) {
        wraps.add(Transform.rotateBox(child: Text('$alignment'), angle: 1.57));
        wraps.add(
          Wrap(
            direction: Axis.vertical,
            verticalDirection: direction,
            alignment: alignment,
            children: List<Widget>.generate(
              40,
              (int n) => Text('${n + 1}'),
            ),
          ),
        );
      }
    }

    pdf.addPage(
      Page(
        pageFormat: const PdfPageFormat(800, 400),
        margin: const EdgeInsets.all(10),
        build: (Context context) => Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: wraps,
        ),
      ),
    );
  });

  test('Wrap Widget Horizontal 2', () {
    final wraps = <Widget>[];
    for (var alignment in WrapCrossAlignment.values) {
      final rnd = math.Random(42);
      wraps.add(Text('$alignment'));
      wraps.add(
        Wrap(
          direction: Axis.horizontal,
          crossAxisAlignment: alignment,
          runSpacing: 20,
          spacing: 20,
          children: List<Widget>.generate(
              20,
              (int n) => SizedBox(
                    width: rnd.nextDouble() * 100,
                    height: rnd.nextDouble() * 50,
                    child: Placeholder(),
                  )),
        ),
      );
    }

    pdf.addPage(
      Page(
        pageFormat: const PdfPageFormat(400, 800),
        margin: const EdgeInsets.all(10),
        build: (Context context) => Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: wraps,
        ),
      ),
    );
  });

  test('Wrap Widget Vertical 2', () {
    final wraps = <Widget>[];
    for (var alignment in WrapCrossAlignment.values) {
      final rnd = math.Random(42);
      wraps.add(Transform.rotateBox(child: Text('$alignment'), angle: 1.57));
      wraps.add(
        Wrap(
          direction: Axis.vertical,
          crossAxisAlignment: alignment,
          runSpacing: 20,
          spacing: 20,
          children: List<Widget>.generate(
              20,
              (int n) => SizedBox(
                    width: rnd.nextDouble() * 50,
                    height: rnd.nextDouble() * 100,
                    child: Placeholder(),
                  )),
        ),
      );
    }

    pdf.addPage(
      Page(
        pageFormat: const PdfPageFormat(800, 400),
        margin: const EdgeInsets.all(10),
        build: (Context context) => Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: wraps,
        ),
      ),
    );
  });

  test('Wrap Widget Horizontal 3', () {
    final wraps = <Widget>[];
    for (var alignment in WrapAlignment.values) {
      final rnd = math.Random(42);
      wraps.add(Text('$alignment'));
      wraps.add(
        SizedBox(
          height: 110,
          child: Wrap(
            direction: Axis.horizontal,
            runAlignment: alignment,
            spacing: 20,
            children: List<Widget>.generate(
                15,
                (int n) => SizedBox(
                      width: rnd.nextDouble() * 100,
                      height: 20,
                      child: Placeholder(),
                    )),
          ),
        ),
      );
    }

    pdf.addPage(
      Page(
        pageFormat: const PdfPageFormat(400, 800),
        margin: const EdgeInsets.all(10),
        build: (Context context) => Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: wraps,
        ),
      ),
    );
  });

  test('Wrap Widget Vertical 3', () {
    final wraps = <Widget>[];
    for (var alignment in WrapAlignment.values) {
      final rnd = math.Random(42);
      wraps.add(Transform.rotateBox(child: Text('$alignment'), angle: 1.57));
      wraps.add(
        SizedBox(
          width: 110,
          child: Wrap(
            direction: Axis.vertical,
            runAlignment: alignment,
            spacing: 20,
            children: List<Widget>.generate(
                15,
                (int n) => SizedBox(
                      width: 20,
                      height: rnd.nextDouble() * 100,
                      child: Placeholder(),
                    )),
          ),
        ),
      );
    }

    pdf.addPage(
      Page(
        pageFormat: const PdfPageFormat(800, 400),
        margin: const EdgeInsets.all(10),
        build: (Context context) => Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: wraps,
        ),
      ),
    );
  });

  test('Wrap Widget Overlay', () {
    final rnd = math.Random(42);
    pdf.addPage(
      Page(
        pageFormat: const PdfPageFormat(200, 200),
        margin: const EdgeInsets.all(10),
        build: (Context context) => Wrap(
          spacing: 10,
          runSpacing: 10,
          children: List<Widget>.generate(
              15,
              (int n) => SizedBox(
                    width: rnd.nextDouble() * 100,
                    height: rnd.nextDouble() * 100,
                    child: Placeholder(),
                  )),
        ),
      ),
    );
  });

  test('Wrap Widget Multipage', () {
    final rnd = math.Random(42);
    pdf.addPage(
      MultiPage(
        pageFormat: const PdfPageFormat(200, 200),
        margin: const EdgeInsets.all(10),
        build: (Context context) => <Widget>[
          Wrap(
            direction: Axis.vertical,
            verticalDirection: VerticalDirection.up,
            alignment: WrapAlignment.center,
            runAlignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: List<Widget>.generate(
                17,
                (int n) => Container(
                      width: rnd.nextDouble() * 100,
                      height: rnd.nextDouble() * 100,
                      alignment: Alignment.center,
                      color: PdfColors.blue800,
                      child: Text('$n'),
                    )),
          )
        ],
      ),
    );
  });

  test('Wrap Widget Empty', () {
    pdf.addPage(Page(build: (Context context) => Wrap()));
  });

  test('Wrap Widget Columns', () {
    final rnd = math.Random(42);

    pdf.addPage(
      MultiPage(
        pageFormat: PdfPageFormat.standard,
        build: (Context context) => <Widget>[
          Wrap(
            direction: Axis.vertical,
            children: List<Widget>.generate(
              50,
              (int n) => Container(
                width: PdfPageFormat.standard.availableWidth / 3,
                padding: const EdgeInsets.only(left: 10, right: 10, bottom: 5),
                child: Lorem(
                  length: rnd.nextInt(30) + 10,
                  random: rnd,
                  textScaleFactor: .7,
                ),
              ),
            ),
          )
        ],
      ),
    );
  });

  tearDownAll(() async {
    final file = File('widgets-wrap.pdf');
    await file.writeAsBytes(await pdf.save());
  });
}
