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

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart';
import 'package:test/test.dart';

import 'utils.dart';

late Document pdf;

void main() {
  setUpAll(() {
    Document.debug = true;
    RichText.debug = true;
    pdf = Document();
  });

  test('Container Widgets Flat', () {
    pdf.addPage(
      Page(
        build: (Context context) => Container(
          alignment: Alignment.center,
          margin: const EdgeInsets.all(30),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: PdfColors.blue,
            borderRadius: const BorderRadius.all(Radius.circular(20)),
            border: Border.all(color: PdfColors.blue800, width: 2),
          ),
          width: 200,
          height: 400,
          // child: Placeholder(),
        ),
      ),
    );
  });

  test('Container Widgets Image', () {
    final image = generateBitmap(100, 200);

    final widgets = <Widget>[];
    for (final shape in BoxShape.values) {
      for (final fit in BoxFit.values) {
        widgets.add(
          Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: shape,
              borderRadius: const BorderRadius.all(Radius.circular(10)),
              image: DecorationImage(image: image, fit: fit),
            ),
            width: 100,
            height: 100,
            child: Container(
              width: 70,
              color: PdfColors.yellow,
              child: Text(
                '$fit\n$shape',
                textAlign: TextAlign.center,
                textScaleFactor: 0.6,
              ),
            ),
          ),
        );
      }
    }

    pdf.addPage(
      MultiPage(
        build: (Context context) => <Widget>[
          Wrap(spacing: 10, runSpacing: 10, children: widgets),
        ],
      ),
    );
  });

  test('Container Widgets BoxShape Border', () {
    pdf.addPage(
      Page(
        build: (Context context) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              Container(
                height: 200.0,
                width: 200.0,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: PdfColors.blue, width: 3),
                ),
              ),
              Container(
                height: 200.0,
                width: 200.0,
                decoration: BoxDecoration(
                  shape: BoxShape.rectangle,
                  borderRadius: const BorderRadius.all(Radius.circular(40)),
                  border: Border.all(color: PdfColors.blue, width: 3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  });

  test('Container Widgets LinearGradient', () {
    pdf.addPage(
      Page(
        build: (Context context) => Container(
          alignment: Alignment.center,
          margin: const EdgeInsets.all(30),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(Radius.circular(20)),
            gradient: const LinearGradient(
              colors: <PdfColor>[
                PdfColors.blue,
                PdfColors.red,
                PdfColors.yellow,
              ],
              begin: Alignment.bottomLeft,
              end: Alignment.topRight,
              stops: <double>[0, .8, 1.0],
              tileMode: TileMode.clamp,
            ),
            border: Border.all(color: PdfColors.blue800, width: 2),
          ),
          width: 200,
          height: 400,
        ),
      ),
    );
  });

  test('Container Widgets RadialGradient', () {
    pdf.addPage(
      Page(
        build: (Context context) => Container(
          alignment: Alignment.center,
          margin: const EdgeInsets.all(30),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(Radius.circular(20)),
            gradient: const RadialGradient(
              colors: <PdfColor>[
                PdfColors.blue,
                PdfColors.red,
                PdfColors.yellow,
              ],
              stops: <double>[0.0, .2, 1.0],
              center: FractionalOffset(.7, .2),
              focal: FractionalOffset(.7, .45),
              focalRadius: 1,
            ),
            border: Border.all(color: PdfColors.blue800, width: 2),
          ),
          width: 200,
          height: 400,
          // child: Placeholder(),
        ),
      ),
    );
  });

  test('Container Widgets BoxShadow Rectangle', () {
    pdf.addPage(
      Page(
        build: (Context context) => Container(
          margin: const EdgeInsets.all(30),
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            boxShadow: <BoxShadow>[
              BoxShadow(
                blurRadius: 4,
                spreadRadius: 10,
                offset: PdfPoint(2, 2),
              ),
            ],
            color: PdfColors.blue,
          ),
          width: 200,
          height: 400,
        ),
      ),
    );
  });

  test('Container Widgets BoxShadow Ellipse', () {
    pdf.addPage(
      Page(
        build: (Context context) => Container(
          margin: const EdgeInsets.all(30),
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: <BoxShadow>[
              BoxShadow(
                blurRadius: 4,
                spreadRadius: 10,
                offset: PdfPoint(2, 2),
              ),
            ],
            color: PdfColors.blue,
          ),
          width: 200,
          height: 200,
        ),
      ),
    );
  });

  test(
    'a directional alignment places a child where the physical one does',
    () async {
      // AlignmentDirectional's six vertical constants were Flutter's y-down ones,
      // so topStart put its child at the bottom of the box.
      Future<PdfRect> place(AlignmentGeometry alignment) async {
        late Container child;
        final document = Document(compress: false);
        document.addPage(
          Page(
            pageFormat: const PdfPageFormat(200, 200, marginAll: 0),
            build: (Context context) => Container(
              width: 100,
              height: 100,
              alignment: alignment,
              child: child = Container(width: 10, height: 10),
            ),
          ),
        );
        await document.save();
        return child.box!;
      }

      final physical = await place(Alignment.topLeft);
      final directional = await place(AlignmentDirectional.topStart);

      expect(physical.y, 90);
      expect(directional.x, physical.x);
      expect(directional.y, physical.y);

      final bottom = await place(AlignmentDirectional.bottomEnd);
      expect(bottom.x, 90);
      expect(bottom.y, 0);
    },
  );

  group('a gradient', () {
    /// Lay [child] out alone on a small page and return the raw PDF.
    Future<String> build(Widget child) async {
      final document = Document(compress: false);
      document.addPage(
        Page(
          pageFormat: const PdfPageFormat(200, 200),
          build: (Context context) => child,
        ),
      );
      return String.fromCharCodes(await document.save());
    }

    /// The page's content stream.
    String contents(String pdf) {
      for (final m in RegExp(
        r'stream(.*?)endstream',
        dotAll: true,
      ).allMatches(pdf)) {
        if (m.group(1)!.contains('0 Tr')) {
          return m.group(1)!.trim();
        }
      }
      return '(no content stream)';
    }

    test('of one colour does not emit a stray clip', () async {
      // Filling consumes the path, and the branch then fell through to
      // saveContext()..clipPath(), emitting 'W n' with no current path. A clip
      // built from nothing clips nothing, so the shading painted its whole
      // bounding box: a circle came out as a square.
      final pdf = await build(
        Container(
          width: 100,
          height: 100,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: <PdfColor>[PdfColors.red]),
          ),
        ),
      );
      final stream = contents(pdf);

      expect(stream, contains(' c '), reason: 'the circle is still drawn');
      expect(stream, contains(' f '), reason: 'and filled');
      expect(stream, isNot(contains('W n')));
      expect(stream, isNot(contains(' sh ')));
      expect(pdf, isNot(contains('/ShadingType')));
    });

    test('of one colour on a box still fills the box', () async {
      final stream = contents(
        await build(
          Container(
            width: 100,
            height: 50,
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: <PdfColor>[PdfColors.red]),
            ),
          ),
        ),
      );

      expect(stream, contains('0 0 100 50 re'));
      expect(stream, contains('0.95686 0.26275 0.21176 rg f'));
      expect(stream, isNot(contains('W n')));
    });

    test('of no colours at all leaves no dangling path', () async {
      // The path was built and then abandoned, so the next operator ran into an
      // open path-construction run - and because nothing set the page's altered
      // flag, a page with only this on it was written with no /Contents at all.
      final stream = contents(
        await build(
          Column(
            children: <Widget>[
              Container(
                width: 100,
                height: 50,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: <PdfColor>[]),
                ),
              ),
              Container(width: 10, height: 10, color: PdfColors.black),
            ],
          ),
        ),
      );

      expect(stream, contains('0 0 100 50 re n'));
      expect(stream, isNot(contains('re Q')));
      expect(
        stream,
        contains('0 0 10 10 re 0 0 0 rg f'),
        reason: 'the sibling is still painted',
      );
    });

    test('of two colours still clips', () async {
      // Guards an over-broad fix: a real gradient must keep its clip.
      final stream = contents(
        await build(
          Container(
            width: 100,
            height: 50,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: <PdfColor>[PdfColors.red, PdfColors.blue],
              ),
            ),
          ),
        ),
      );

      expect(stream, contains('0 0 100 50 re q W n'));
      expect(stream, contains(' sh '));
    });

    test('never clips without a path, whatever the decoration', () async {
      const gradients = <Gradient>[
        LinearGradient(colors: <PdfColor>[PdfColors.red]),
        LinearGradient(colors: <PdfColor>[PdfColors.red, PdfColors.blue]),
        LinearGradient(
          colors: <PdfColor>[PdfColors.red, PdfColors.green, PdfColors.blue],
          stops: <double>[0, 0.3, 1],
        ),
        RadialGradient(colors: <PdfColor>[PdfColors.red]),
        RadialGradient(colors: <PdfColor>[PdfColors.red, PdfColors.blue]),
      ];

      final children = <Widget>[];
      for (final gradient in gradients) {
        for (final shape in BoxShape.values) {
          for (final radius in <BorderRadius?>[
            null,
            const BorderRadius.all(Radius.circular(8)),
          ]) {
            children.add(
              Container(
                width: 60,
                height: 40,
                decoration: BoxDecoration(
                  shape: shape,
                  borderRadius: shape == BoxShape.circle ? null : radius,
                  gradient: gradient,
                  border: Border.all(),
                ),
              ),
            );
          }
        }
      }

      final stream = contents(await build(Wrap(children: children)));

      // Every clip has to be built from a path, so the operator in front of a W
      // is one of the path-construction ones. saveContext() has always written
      // its q between the two - 're q W n' - so that one is skipped over.
      const construction = <String>{'m', 'l', 'c', 'v', 'y', 're', 'h'};
      final tokens = stream.split(RegExp(r'\s+'));
      var clips = 0;
      for (var i = 0; i < tokens.length; i++) {
        if (tokens[i] != 'W' && tokens[i] != 'W*') {
          continue;
        }
        clips++;

        var j = i - 1;
        while (j >= 0 && tokens[j] == 'q') {
          j--;
        }
        expect(
          construction,
          contains(j < 0 ? '(nothing)' : tokens[j]),
          reason: 'clip $clips follows "${j < 0 ? '(nothing)' : tokens[j]}"',
        );
      }
      expect(clips, greaterThan(0), reason: 'some decoration did clip');
    });
  });

  tearDownAll(() async {
    final file = File('widgets-container.pdf');
    await file.writeAsBytes(await pdf.save());
  });
}
