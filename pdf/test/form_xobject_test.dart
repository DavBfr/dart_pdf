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
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/src/pdf/obj/formxobject.dart';
import 'package:pdf/src/pdf/obj/formxobject_extensions.dart';
import 'package:pdf/src/priv.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:test/test.dart';

const _svg = '''
<svg xmlns="http://www.w3.org/2000/svg" width="100" height="50">
  <defs>
    <linearGradient id="g">
      <stop offset="0" stop-color="red"/>
      <stop offset="1" stop-color="blue"/>
    </linearGradient>
  </defs>
  <rect width="100" height="50" fill="url(#g)"/>
  <text x="5" y="30">Hi</text>
</svg>''';

/// A document with one form of [kind] drawn on its only page.
Future<String> build(String kind) async {
  final document = pw.Document(compress: false).document;
  final page = PdfPage(document, pageFormat: PdfPageFormat.a4);

  final PdfFormXObject form;
  switch (kind) {
    case 'plain':
      form = PdfFormXObject(document);
      break;
    case 'svg':
      form = SvgPdfFormXObject(
        document,
        Uint8List.fromList(utf8.encode(_svg)),
        100,
        50,
      );
      break;
    default:
      form = WidgetPdfFormXObject(
        document,
        pw.Opacity(
          opacity: .5,
          child: pw.Container(
            width: 100,
            height: 50,
            decoration: const pw.BoxDecoration(
              gradient: pw.LinearGradient(
                colors: <PdfColor>[PdfColors.red, PdfColors.blue],
              ),
            ),
          ),
        ),
        100,
        50,
      );
  }

  page.getGraphics().drawXObject(form, 10, 10, w: 100, h: 50);
  return String.fromCharCodes(await document.save());
}

/// The dictionary of the form object in [pdf].
String formDict(String pdf) =>
    RegExp(r'\d+ 0 obj\s*(<<.*?>>)\s*stream', dotAll: true)
        .allMatches(pdf)
        .map((RegExpMatch m) => m.group(1)!)
        .firstWhere((String d) => d.contains('/Subtype/Form'));

void main() {
  group('a form XObject resource name', () {
    test('is a name object in the dictionary', () async {
      // PdfXObject.name was the only resource name getter without a leading
      // solidus, so the /XObject key came out as a bare 'X4' - which poppler
      // rejects as a non-name key, dropping the page.
      for (final kind in <String>['plain', 'svg', 'widget']) {
        final pdf = await build(kind);
        expect(pdf, contains('/XObject<</X'), reason: kind);
        expect(
          RegExp(r'/XObject<<[A-Za-z]').hasMatch(pdf),
          isFalse,
          reason: '$kind: the key has to start with a solidus',
        );
      }
    });

    test('carries exactly one solidus before Do', () async {
      // The two form subclasses overrode name with a slash, so their Do operand
      // came out as '//X4'.
      for (final kind in <String>['plain', 'svg', 'widget']) {
        final pdf = await build(kind);
        expect(pdf, isNot(contains('//X')), reason: kind);
        expect(RegExp(r'/X\d+ Do').hasMatch(pdf), isTrue, reason: kind);
      }
    });

    test('equals the key it is registered under', () async {
      for (final kind in <String>['plain', 'svg', 'widget']) {
        final pdf = await build(kind);
        final key = RegExp(r'/XObject<<(/X\d+)').firstMatch(pdf)?.group(1);
        final operand = RegExp(r'(/X\d+) Do').firstMatch(pdf)?.group(1);

        expect(key, isNotNull, reason: kind);
        expect(operand, key, reason: kind);
      }
    });
  });

  group('a form XObject', () {
    test('declares the resources its own stream names', () async {
      // Both subclasses painted onto a page of a second, discarded document.
      // PdfGraphics registers every font, shader and pattern on that page while
      // only the bytes reach the form, so the form had no /Resources at all and
      // its stream named objects nobody ever wrote: it rendered blank.
      final svg = formDict(await build('svg'));
      expect(svg, contains('/Resources'));
      expect(svg, contains('/Font'));
      expect(
        svg.contains('/Pattern') || svg.contains('/Shading'),
        isTrue,
        reason: 'the gradient has to be declared',
      );

      final widget = formDict(await build('widget'));
      expect(widget, contains('/Resources'));
      expect(widget, contains('/Shading'), reason: 'the gradient');
      expect(widget, contains('/ExtGState'), reason: 'the opacity');
    });

    test('names nothing its resources do not declare', () async {
      for (final kind in <String>['svg', 'widget']) {
        final pdf = await build(kind);
        final dict = formDict(pdf);

        // The stream of the form, which is what follows its dictionary.
        final stream = RegExp(
          RegExp.escape(dict) + r'\s*stream\n(.*?)endstream',
          dotAll: true,
        ).firstMatch(pdf)!.group(1)!;

        for (final name in RegExp(
          r'(/[FPSIX]\d+)',
        ).allMatches(stream).map((RegExpMatch m) => m.group(1)!).toSet()) {
          expect(dict, contains(name), reason: '$kind names $name');
        }
      }
    });

    test('leaves no dangling reference in the file', () async {
      for (final kind in <String>['plain', 'svg', 'widget']) {
        final pdf = await build(kind);

        final referenced = RegExp(
          r'(\d+) 0 R',
        ).allMatches(pdf).map((RegExpMatch m) => m.group(1)!).toSet();
        final present = RegExp(
          r'(\d+) 0 obj',
        ).allMatches(pdf).map((RegExpMatch m) => m.group(1)!).toSet();

        expect(referenced.difference(present), isEmpty, reason: kind);
      }
    });

    test('drawn on several pages is written once', () async {
      final document = pw.Document(compress: false).document;
      final form = SvgPdfFormXObject(
        document,
        Uint8List.fromList(utf8.encode(_svg)),
        100,
        50,
      );

      for (var i = 0; i < 3; i++) {
        PdfPage(
          document,
          pageFormat: PdfPageFormat.a4,
        ).getGraphics().drawXObject(form, 10, 10, w: 100, h: 50);
      }

      final pdf = String.fromCharCodes(await document.save());
      expect(
        RegExp(r'/Subtype/Form').allMatches(pdf),
        hasLength(1),
        reason: 'one form object',
      );
      expect(RegExp(r'/X\d+ Do').allMatches(pdf), hasLength(3));
    });
  });
  group('drawing a form XObject', () {
    /// Draw a form with [bbox] and return the `cm` operands it emitted.
    Future<String?> matrix(
      List<num> bbox, {
      double? w,
      double? h,
      double x = 0,
      double y = 0,
    }) async {
      final document = pw.Document(compress: false).document;
      final page = PdfPage(document, pageFormat: PdfPageFormat.a4);
      final form = PdfFormXObject(document)
        ..params['/BBox'] = PdfArray.fromNum(bbox);

      page.getGraphics().drawXObject(form, x, y, w: w, h: h);

      final pdf = String.fromCharCodes(await document.save());
      return RegExp(r'q ([-\d. ]+) cm').firstMatch(pdf)?.group(1);
    }

    test('places the box, whatever its origin', () async {
      // /BBox is [llx lly urx ury], not an origin and a size. The last two were
      // read as the width and the height, so the scale came out as target/urx and
      // the content landed offset by the box's own origin.
      expect(
        await matrix(<num>[0, 0, 100, 50], w: 100, h: 50),
        '1 0 0 1 0 0',
        reason: 'a zero-origin box does not move',
      );

      expect(
        await matrix(<num>[10, 20, 110, 70], w: 100, h: 50),
        '1 0 0 1 -10 -20',
      );
      expect(
        await matrix(<num>[10, 20, 110, 70]),
        '1 0 0 1 -10 -20',
        reason: 'its natural size is 100 x 50, so the scale is 1',
      );
      expect(
        await matrix(<num>[-50, -25, 50, 25], w: 100, h: 50),
        '1 0 0 1 50 25',
        reason: 'scale 1, not 2',
      );
      expect(
        await matrix(<num>[-100, -50, 0, 0], w: 100, h: 50),
        '1 0 0 1 100 50',
        reason: 'a box that ends at the origin is 100 x 50, not empty',
      );
    });

    test('normalises a reversed box', () async {
      expect(
        await matrix(<num>[110, 70, 10, 20], w: 100, h: 50),
        await matrix(<num>[10, 20, 110, 70], w: 100, h: 50),
      );
    });

    test('draws nothing for a box with no area', () async {
      final document = pw.Document(compress: false).document;
      final page = PdfPage(document, pageFormat: PdfPageFormat.a4);
      final form = PdfFormXObject(document)
        ..params['/BBox'] = PdfArray.fromNum(<num>[10, 20, 10, 70]);

      expect(
        () => page.getGraphics().drawXObject(form, 0, 0, w: 100, h: 50),
        returnsNormally,
      );

      final pdf = String.fromCharCodes(await document.save());
      expect(pdf, isNot(contains('Infinity')));
      expect(pdf, isNot(contains('NaN')));
      expect(pdf, isNot(contains(' Do')), reason: 'nothing to draw');
    });

    test('moves with the point it is drawn at', () async {
      final origin = await matrix(<num>[10, 20, 110, 70], w: 100, h: 50);
      final moved = await matrix(
        <num>[10, 20, 110, 70],
        w: 100,
        h: 50,
        x: 200,
        y: 300,
      );

      final from = origin!.split(' ').map(double.parse).toList();
      final to = moved!.split(' ').map(double.parse).toList();
      expect(to[4] - from[4], 200);
      expect(to[5] - from[5], 300);
    });
  });
}
