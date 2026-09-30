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
}
