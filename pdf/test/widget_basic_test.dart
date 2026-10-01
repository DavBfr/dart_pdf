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
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart';
import 'package:test/test.dart';

late Document pdf;

void main() {
  setUpAll(() {
    Document.debug = true;
    RichText.debug = true;
    pdf = Document();
  });

  test('Basic Widgets Align 1', () {
    pdf.addPage(
      Page(
        build: (Context context) => Align(
          alignment: Alignment.bottomRight,
          child: SizedBox(width: 100, height: 100, child: PdfLogo()),
        ),
      ),
    );
  });

  test('Basic Widgets Align 2', () {
    pdf.addPage(
      Page(
        build: (Context context) => Align(
          alignment: const Alignment(0.8, 0.2),
          child: SizedBox(width: 100, height: 100, child: PdfLogo()),
        ),
      ),
    );
  });

  test('Basic Widgets AspectRatio', () {
    pdf.addPage(
      Page(
        build: (Context context) =>
            AspectRatio(aspectRatio: 1.618, child: Placeholder()),
      ),
    );
  });

  test('Basic Widgets Center', () {
    pdf.addPage(
      Page(
        build: (Context context) =>
            Center(child: SizedBox(width: 100, height: 100, child: PdfLogo())),
      ),
    );
  });

  test('Basic Widgets ConstrainedBox', () {
    pdf.addPage(
      Page(
        build: (Context context) => ConstrainedBox(
          constraints: const BoxConstraints.tightFor(height: 300),
          child: Placeholder(),
        ),
      ),
    );
  });

  test('Basic Widgets CustomPaint', () {
    pdf.addPage(
      Page(
        build: (Context context) => CustomPaint(
          size: const PdfPoint(200, 200),
          painter: (PdfGraphics canvas, PdfPoint size) {
            canvas
              ..drawEllipse(size.x / 2, size.y / 2, size.x / 2, size.y / 2)
              ..setFillColor(PdfColors.blue)
              ..fillPath();
          },
        ),
      ),
    );
    pdf.addPage(
      Page(
        build: (Context context) => CustomPaint(
          size: const PdfPoint(200, 200),
          painter: (PdfGraphics canvas, PdfPoint size) {
            canvas
              ..drawEllipse(size.x / 2, size.y / 2, size.x / 2, size.y / 2)
              ..setFillColor(PdfColors.blue)
              ..fillPath();
          },
          child: PdfLogo(),
        ),
      ),
    );
  });

  test('Basic Widgets FittedBox', () {
    pdf.addPage(
      Page(
        build: (Context context) => Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          mainAxisSize: MainAxisSize.max,
          children: <Widget>[
            SizedBox(
              height: 100,
              width: 100,
              child: FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(width: 100, height: 50, child: Placeholder()),
              ),
            ),
            SizedBox(
              height: 100,
              width: 100,
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(width: 100, height: 50, child: Placeholder()),
              ),
            ),
            SizedBox(
              height: 100,
              width: 100,
              child: FittedBox(
                fit: BoxFit.fill,
                child: SizedBox(width: 100, height: 50, child: Placeholder()),
              ),
            ),
            SizedBox(
              height: 100,
              width: 100,
              child: FittedBox(
                fit: BoxFit.fitWidth,
                child: SizedBox(width: 100, height: 50, child: Placeholder()),
              ),
            ),
            SizedBox(
              height: 100,
              width: 100,
              child: FittedBox(
                fit: BoxFit.fitHeight,
                child: SizedBox(width: 100, height: 50, child: Placeholder()),
              ),
            ),
            SizedBox(
              height: 100,
              width: 100,
              child: FittedBox(
                fit: BoxFit.none,
                child: SizedBox(width: 100, height: 50, child: Placeholder()),
              ),
            ),
            SizedBox(
              height: 100,
              width: 100,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: SizedBox(width: 100, height: 50, child: Placeholder()),
              ),
            ),
          ],
        ),
      ),
    );
  });

  test('Basic Widgets LimitedBox', () {
    pdf.addPage(
      Page(
        build: (Context context) => ListView(
          children: <Widget>[LimitedBox(maxHeight: 40, child: Placeholder())],
        ),
      ),
    );
  });

  test('Basic Widgets Padding', () {
    pdf.addPage(
      Page(
        build: (Context context) => Center(
          child: Padding(padding: const EdgeInsets.all(20), child: PdfLogo()),
        ),
      ),
    );
  });

  test('Basic Widgets SizedBox', () {
    pdf.addPage(
      Page(
        build: (Context context) =>
            SizedBox(width: 200, height: 100, child: Placeholder()),
      ),
    );
  });

  test('Basic Widgets Transform', () {
    pdf.addPage(
      Page(
        build: (Context context) => Transform.scale(
          scale: 0.5,
          child: Transform.rotate(angle: 0.1, child: Placeholder()),
        ),
      ),
    );
  });

  test('Basic Widgets Transform rotateBox', () {
    pdf.addPage(
      Page(
        build: (Context context) => Center(
          child: Transform.rotateBox(angle: 3.1416 / 2, child: Text('Hello')),
        ),
      ),
    );
  });

  group('an AspectRatio', () {
    test('without a child is a spacer, not a crash', () async {
      // The sanity assert on the child's box sat outside the null guard, so this
      // threw 'Null check operator used on a null value' out of layout wherever
      // asserts are on - which is every test run and every debug build.
      final document = Document(compress: false);
      document.addPage(
        Page(
          pageFormat: PdfPageFormat.a4,
          build: (Context context) => Column(
            children: <Widget>[
              AspectRatio(aspectRatio: 16 / 9),
              Text('after'),
            ],
          ),
        ),
      );

      expect(await document.save(), isNotEmpty);
    });

    test('reserves the height its ratio asks for', () async {
      late PdfPoint size;
      final document = Document();
      document.addPage(
        Page(
          pageFormat: PdfPageFormat.a4,
          build: (Context context) {
            size = Widget.measure(
              AspectRatio(aspectRatio: 2),
              context: context,
              constraints: const BoxConstraints(maxWidth: 200),
            );
            return SizedBox();
          },
        ),
      );
      await document.save();

      expect(size.x, 200);
      expect(size.y, 100);
    });

    test('with a child still checks the child was laid out', () async {
      // The assert is moved, not deleted.
      final document = Document(compress: false);
      document.addPage(
        Page(
          pageFormat: PdfPageFormat.a4,
          build: (Context context) => AspectRatio(
            aspectRatio: 2,
            child: Container(color: PdfColors.blue),
          ),
        ),
      );

      expect(await document.save(), isNotEmpty);
    });
  });

  group('a rotateBox', () {
    /// A solid bitmap of the given pixel size.
    ImageProvider bitmap(int width, int height) => RawImage(
      bytes: Uint8List(width * height * 4)
        ..fillRange(0, width * height * 4, 0x80),
      width: width,
      height: height,
    );

    /// Rotate [child] in the space a Column leaves between two 40pt spacers on
    /// A4, and hand back the Transform's own box.
    Future<PdfRect> inColumn(double angle, Widget child) async {
      late Transform transform;
      final document = Document(compress: false);
      document.addPage(
        Page(
          pageFormat: PdfPageFormat.a4,
          build: (Context context) => Column(
            children: <Widget>[
              SizedBox(height: 40),
              Expanded(
                child: Align(
                  child: transform = Transform.rotateBox(
                    angle: angle,
                    child: child,
                  ),
                ),
              ),
              SizedBox(height: 40),
            ],
          ),
        ),
      );
      await document.save();
      return transform.box!;
    }

    test('a quarter turn fills the cross axis', () async {
      // The child was laid out against the constraints the Transform itself
      // received, although it is painted a quarter turn round, so it measured in
      // the wrong frame: a landscape image reached 361.42pt of the 481.89pt it
      // was given.
      final box = await inColumn(math.pi / 2, Image(bitmap(400, 300)));

      expect(box.width, closeTo(PdfPageFormat.a4.availableWidth, 0.01));
      expect(box.width, closeTo(481.8898, 0.01));
    });

    test('never exceeds the constraints it was given', () async {
      // The other way round the same mistake overflowed: a portrait image came
      // out 642.52pt wide in a 481.89pt slot and was painted off the page.
      final box = await inColumn(math.pi / 2, Image(bitmap(300, 400)));

      expect(box.width, lessThanOrEqualTo(481.8898 + 1e-6));
      expect(box.height, lessThanOrEqualTo(PdfPageFormat.a4.availableHeight));
    });

    test('honours the constraints at every angle', () async {
      for (var i = 0; i <= 24; i++) {
        final angle = i * math.pi / 12;
        late Transform transform;
        final document = Document(compress: false);
        document.addPage(
          Page(
            pageFormat: const PdfPageFormat(400, 500, marginAll: 0),
            build: (Context context) => ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 200, maxHeight: 300),
              child: transform = Transform.rotateBox(
                angle: angle,
                child: Image(bitmap(300, 400)),
              ),
            ),
          ),
        );
        await document.save();

        expect(
          transform.box!.width,
          lessThanOrEqualTo(200 + 1e-6),
          reason: 'angle $angle',
        );
        expect(
          transform.box!.height,
          lessThanOrEqualTo(300 + 1e-6),
          reason: 'angle $angle',
        );
      }
    });

    test('leaves an even turn exactly where it was', () async {
      // An unrotated child already measures in the right frame, so its box must
      // not move - neither clamped up to the minimum nor down.
      for (final angle in <double>[0, math.pi]) {
        final landscape = await inColumn(angle, Image(bitmap(400, 300)));
        expect(landscape.width, closeTo(481.8898, 0.01), reason: '$angle');
        expect(landscape.height, closeTo(361.4174, 0.01), reason: '$angle');

        final portrait = await inColumn(angle, Image(bitmap(300, 400)));
        expect(portrait.width, closeTo(481.8898, 0.01), reason: '$angle');
        expect(portrait.height, closeTo(642.5197, 0.01), reason: '$angle');
      }
    });

    test('still runs unclamped when asked to', () async {
      late Transform transform;
      final document = Document(compress: false);
      document.addPage(
        Page(
          pageFormat: const PdfPageFormat(400, 500, marginAll: 0),
          build: (Context context) => ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 200, maxHeight: 300),
            child: transform = Transform.rotateBox(
              angle: math.pi / 2,
              unconstrained: true,
              child: SizedBox(
                width: 600,
                height: 700,
                child: Container(color: PdfColors.blue),
              ),
            ),
          ),
        ),
      );
      await document.save();

      expect(transform.box!.width, greaterThan(200));
    });
  });

  tearDownAll(() async {
    final file = File('widgets-basic.pdf');
    await file.writeAsBytes(await pdf.save());
  });
}
