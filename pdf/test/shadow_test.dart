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

import 'package:image/image.dart' as im;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart';
import 'package:test/test.dart';

/// A shadow bitmap, measured.
class Measured {
  Measured(this.image) {
    var minX = image.width;
    var maxX = -1;
    var minY = image.height;
    var maxY = -1;

    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        final a = image.getPixel(x, y).a.round();
        maxAlpha = a > maxAlpha ? a : maxAlpha;

        // The image package's blur kernel loses a count at some radii, so the
        // core of a blurred shape tops out at 254 rather than 255.
        if (a >= 254) {
          core++;
          minX = x < minX ? x : minX;
          maxX = x > maxX ? x : maxX;
          minY = y < minY ? y : minY;
          maxY = y > maxY ? y : maxY;
        } else if (a > 0) {
          soft++;
        } else {
          clear++;
        }
      }
    }

    coreWidth = maxX < 0 ? 0 : maxX - minX + 1;
    coreHeight = maxY < 0 ? 0 : maxY - minY + 1;
  }

  final im.Image image;

  /// Pixels at full alpha, and the box they fill.
  int core = 0;
  int coreWidth = 0;
  int coreHeight = 0;

  /// Pixels part way between transparent and opaque, and fully transparent ones.
  int soft = 0;
  int clear = 0;

  int maxAlpha = 0;
}

void main() {
  group('shadowRect', () {
    test('reserves room for the blur', () {
      // The bitmap was only spreadRadius larger than the box and was filled edge
      // to edge, so with the default spreadRadius of 0 the Gaussian blur had
      // nowhere to bleed and handed back the same opaque rectangle: a
      // BoxShadow(blurRadius: 8) painted a hard box with a 1px hairline.
      final shadow = Measured(
        PdfRasterBase.shadowRect(100, 50, 0, 8, PdfColors.black),
      );

      expect(shadow.image.width, greaterThan(100));
      expect(shadow.image.height, greaterThan(50));
      expect(shadow.soft, greaterThan(0), reason: 'the edge is soft');
      expect(shadow.maxAlpha, 255);

      // The opaque core is the box itself: the shape is drawn inflated by the
      // blur radius so that blurring erodes it back to the box.
      expect(shadow.coreWidth, 100);
      expect(shadow.coreHeight, 50);
      expect(shadow.core, 100 * 50);
    });

    test('decays outward', () {
      final shadow = PdfRasterBase.shadowRect(100, 50, 0, 8, PdfColors.black);
      final row = shadow.height ~/ 2;

      var previous = -1;
      for (var x = 0; x <= shadow.width ~/ 2; x++) {
        final a = shadow.getPixel(x, row).a.round();
        expect(a, greaterThanOrEqualTo(previous), reason: 'at x = $x');
        previous = a;
      }
      expect(previous, 255);
    });

    test('inflates its core by the spread radius', () {
      // Flutter's meaning: spreadRadius grows the shadow's own shape. Here it
      // only padded the bitmap, so the core was never larger than the box.
      for (final blur in <double>[0, 4]) {
        final shadow = Measured(
          PdfRasterBase.shadowRect(100, 50, 10, blur, PdfColors.black),
        );

        expect(shadow.coreWidth, 120, reason: 'blur $blur');
        expect(shadow.coreHeight, 70, reason: 'blur $blur');
      }
    });

    test('is the box itself with no spread and no blur', () {
      final shadow = Measured(
        PdfRasterBase.shadowRect(100, 50, 0, 0, PdfColors.black),
      );

      expect(shadow.image.width, 100);
      expect(shadow.image.height, 50);
      expect(shadow.core, 100 * 50);
      expect(shadow.soft, 0);
    });
  });

  group('shadowEllipse', () {
    test('reserves room for the blur', () {
      final shadow = Measured(
        PdfRasterBase.shadowEllipse(100, 100, 0, 8, PdfColors.black),
      );

      expect(shadow.image.width, greaterThan(100));
      expect(shadow.image.height, greaterThan(100));
      expect(shadow.soft, greaterThan(0));
      expect(shadow.clear, greaterThan(0), reason: 'the corners stay empty');
      expect(shadow.maxAlpha, 255);
    });

    test('has two radii when the box is not square', () {
      // The image package has fillCircle but no fillEllipse, and this used
      // fillCircle with the width as the radius.
      final shadow = Measured(
        PdfRasterBase.shadowEllipse(200, 100, 0, 8, PdfColors.black),
      );

      expect(shadow.coreWidth, greaterThan(shadow.coreHeight));
      expect(shadow.coreWidth, closeTo(198, 2));
      expect(shadow.coreHeight, closeTo(98, 2));
    });
  });

  test('shadowMargin is the spread plus twice the blur', () {
    expect(PdfRasterBase.shadowMargin(0, 0), 0);
    expect(PdfRasterBase.shadowMargin(10, 0), 10);
    expect(PdfRasterBase.shadowMargin(0, 8), 16);
    expect(PdfRasterBase.shadowMargin(10, 8), 26);
  });

  group('a BoxShadow on a page', () {
    /// The /Width of every image XObject in [pdf].
    List<int> imageWidths(String pdf) =>
        RegExp(r'/Subtype\s*/Image').allMatches(pdf).map((m) {
          final body = pdf.substring(
            pdf.lastIndexOf('<<', m.start),
            pdf.indexOf('stream', m.start),
          );
          return int.parse(RegExp(r'/Width (\d+)').firstMatch(body)!.group(1)!);
        }).toList();

    Future<String> build(BoxShape shape, BoxShadow shadow) async {
      final document = Document(compress: false);
      document.addPage(
        Page(
          pageFormat: const PdfPageFormat(300, 300, marginAll: 0),
          build: (Context context) => Center(
            child: Container(
              width: 100,
              height: shape == BoxShape.circle ? 100 : 50,
              decoration: BoxDecoration(
                shape: shape,
                color: PdfColors.white,
                boxShadow: <BoxShadow>[shadow],
              ),
            ),
          ),
        ),
      );
      return String.fromCharCodes(await document.save());
    }

    test('embeds a bitmap wider than the box', () async {
      final pdf = await build(
        BoxShape.rectangle,
        const BoxShadow(color: PdfColors.black, blurRadius: 8),
      );

      // Every shadow registers its bitmap twice and references one of them -
      // a separate, pre-existing waste - so this reads the widths as a set.
      expect(imageWidths(pdf).toSet(), <int>{132});
      // 132 points wide, one point per pixel, placed 16pt left of and below the
      // box: the blur reaches outside it on every side.
      expect(pdf, contains('q 132 0 0 82 -16 -16 cm'));
    });

    test('embeds a bitmap wider than a circle', () async {
      final pdf = await build(
        BoxShape.circle,
        const BoxShadow(color: PdfColors.black, blurRadius: 8),
      );

      expect(imageWidths(pdf).toSet(), <int>{132});
      expect(pdf, contains('q 132 0 0 132 -16 -16 cm'));
    });
  });
}
