// ignore_for_file: omit_local_variable_types

import 'dart:io';
import 'dart:math' as math;

import 'package:test/test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart';

Document pdf;

void main() {
  setUpAll(() {
    Document.debug = true;
    pdf = Document();
  });

  test('Wrap Widget Horizontal 1', () {
    final List<Widget> wraps = <Widget>[];
    for (VerticalDirection direction in VerticalDirection.values) {
      wraps.add(Text('$direction'));
      for (WrapAlignment alignment in WrapAlignment.values) {
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
    final List<Widget> wraps = <Widget>[];
    for (VerticalDirection direction in VerticalDirection.values) {
      wraps.add(Transform.rotateBox(child: Text('$direction'), angle: 1.57));
      for (WrapAlignment alignment in WrapAlignment.values) {
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
    final List<Widget> wraps = <Widget>[];
    for (WrapCrossAlignment alignment in WrapCrossAlignment.values) {
      final math.Random rnd = math.Random(42);
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
    final List<Widget> wraps = <Widget>[];
    for (WrapCrossAlignment alignment in WrapCrossAlignment.values) {
      final math.Random rnd = math.Random(42);
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
    final List<Widget> wraps = <Widget>[];
    for (WrapAlignment alignment in WrapAlignment.values) {
      final math.Random rnd = math.Random(42);
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
    final List<Widget> wraps = <Widget>[];
    for (WrapAlignment alignment in WrapAlignment.values) {
      final math.Random rnd = math.Random(42);
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
    final math.Random rnd = math.Random(42);
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
    final math.Random rnd = math.Random(42);
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

  tearDownAll(() {
    final File file = File('widgets-wrap.pdf');
    file.writeAsBytesSync(pdf.save());
  });
}
