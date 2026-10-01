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
import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:test/test.dart';

/// The /AcroForm /Fields references of [pdf].
List<String> fieldsOf(String pdf) {
  final array = RegExp(r'/Fields\[([^\]]*)\]').firstMatch(pdf);
  if (array != null) {
    return RegExp(
      r'(\d+) 0 R',
    ).allMatches(array.group(1)!).map((m) => m.group(1)!).toList();
  }

  // A single entry is written as a bare reference.
  final single = RegExp(r'/Fields (\d+) 0 R').firstMatch(pdf);
  return single == null ? <String>[] : <String>[single.group(1)!];
}

/// The body of object [objser].
String objectOf(String pdf, String objser) => RegExp(
  '\\n$objser 0 obj(.*?)endobj',
  dotAll: true,
).firstMatch(pdf)!.group(1)!;

/// The /DR /Font keys.
List<String> drFontsOf(String pdf) {
  final dr = RegExp(r'/DR<</Font<<([^>]*)>>').firstMatch(pdf);
  return dr == null
      ? <String>[]
      : RegExp(
          r'(/\w+) \d+ 0 R',
        ).allMatches(dr.group(1)!).map((m) => m.group(1)!).toList();
}

/// Every font name named in a /DA string.
Set<String> daFontsOf(String pdf) => RegExp(r'/DA\(([^)]*)\)')
    .allMatches(pdf)
    .map((m) => RegExp(r'(/\w+) [\d.]+ Tf').firstMatch(m.group(1)!)?.group(1))
    .whereType<String>()
    .toSet();

Future<String> save(pw.Document document) async =>
    latin1.decode(await document.save(), allowInvalid: true);

void main() {
  late pw.Font font;

  setUpAll(() {
    font = pw.Font.ttf(
      File('open-sans.ttf').readAsBytesSync().buffer.asByteData(),
    );
  });

  group('widgets sharing a field name', () {
    Future<String> build({int rows = 30}) async {
      final document = pw.Document(compress: false);
      document.addPage(
        pw.MultiPage(
          pageFormat: const PdfPageFormat(300, 120, marginAll: 10),
          header: (pw.Context context) => pw.SizedBox(
            width: 100,
            height: 20,
            child: pw.TextField(name: 'invoiceNo'),
          ),
          build: (pw.Context context) => <pw.Widget>[
            for (var i = 0; i < rows; i++) pw.Text('row $i'),
          ],
        ),
      );
      return save(document);
    }

    test('become one field with the widgets as its kids', () async {
      // Each widget was its own merged field-and-widget dictionary and each was
      // pushed into /Fields, so a header TextField in a MultiPage gave one root
      // field per page - same /T, different /V. ISO 32000-1 12.7.3.1 allows the
      // merged form only for a single-widget field.
      final pdf = await build();

      expect(fieldsOf(pdf), hasLength(1));
      expect(RegExp(r'/T\(invoiceNo\)').allMatches(pdf), hasLength(1));

      final field = objectOf(pdf, fieldsOf(pdf).single);
      expect(field, contains('/T(invoiceNo)'));
      expect(field, contains('/FT/Tx'));
      expect(field, contains('/Kids['));

      final kids = RegExp(r'/Kids\[([^\]]*)\]').firstMatch(field)!;
      expect(
        RegExp(r'\d+ 0 R').allMatches(kids.group(1)!).length,
        greaterThan(1),
      );
    });

    test('leave the field keys on the field alone', () async {
      final pdf = await build();
      final field = fieldsOf(pdf).single;
      final kids = RegExp(
        r'/Kids\[([^\]]*)\]',
      ).firstMatch(objectOf(pdf, field))!.group(1)!;

      for (final m in RegExp(r'(\d+) 0 R').allMatches(kids)) {
        final kid = objectOf(pdf, m.group(1)!);

        expect(kid, isNot(contains('/T(')), reason: m.group(1));
        expect(kid, contains('/Parent $field 0 R'), reason: m.group(1));
        expect(kid, contains('/Rect['), reason: m.group(1));
        expect(kid, contains('/Subtype/Widget'), reason: m.group(1));
        expect(kid, isNot(contains('/V')), reason: m.group(1));
        expect(kid, isNot(contains('/DV')), reason: m.group(1));
      }
    });
  });

  test('unique field names are left as they were', () async {
    final document = pw.Document(compress: false);
    document.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(300, 300, marginAll: 10),
        build: (pw.Context context) => pw.Column(
          children: <pw.Widget>[
            pw.SizedBox(width: 100, height: 20, child: pw.TextField(name: 'a')),
            pw.SizedBox(width: 100, height: 20, child: pw.TextField(name: 'b')),
          ],
        ),
      ),
    );
    final pdf = await save(document);

    expect(fieldsOf(pdf), hasLength(2));
    expect(RegExp(r'/T\(a\)').allMatches(pdf), hasLength(1));
    expect(RegExp(r'/T\(b\)').allMatches(pdf), hasLength(1));

    // No field object, so no /Kids and no /Parent beyond the page tree's.
    for (final field in fieldsOf(pdf)) {
      final body = objectOf(pdf, field);
      expect(body, contains('/Subtype/Widget'));
      expect(body, isNot(contains('/Kids')));
    }
  });

  group('the /DA font', () {
    test('of a choice field is declared in /DR', () async {
      // The collector only recognised a PdfTextField, and the field's own font
      // registration ran after PdfPage.prepare had frozen /Resources - so a
      // ChoiceField's /DA named a font that appeared nowhere and Acrobat
      // regenerated the appearance with Helvetica.
      final document = pw.Document(compress: false);
      document.addPage(
        pw.Page(
          pageFormat: const PdfPageFormat(300, 300, marginAll: 10),
          build: (pw.Context context) {
            PdfAnnot(
              context.page,
              PdfChoiceField(
                rect: const PdfRect(0, 0, 100, 20),
                fieldName: 'pick',
                font: font.getFont(context),
                fontSize: 10,
                textColor: PdfColors.black,
                items: const <String>['one', 'two'],
              ),
            );
            return pw.SizedBox();
          },
        ),
      );
      final pdf = await save(document);

      expect(drFontsOf(pdf), isNotEmpty);
      expect(daFontsOf(pdf), isNotEmpty);
      expect(drFontsOf(pdf), containsAll(daFontsOf(pdf)));
    });

    test('is declared once when two widgets share it', () async {
      final document = pw.Document(compress: false);
      document.addPage(
        pw.Page(
          pageFormat: const PdfPageFormat(300, 300, marginAll: 10),
          build: (pw.Context context) {
            final pdfFont = font.getFont(context);
            PdfAnnot(
              context.page,
              PdfChoiceField(
                rect: const PdfRect(0, 0, 100, 20),
                fieldName: 'pick',
                font: pdfFont,
                fontSize: 10,
                textColor: PdfColors.black,
                items: const <String>['one', 'two'],
              ),
            );
            PdfAnnot(
              context.page,
              PdfTextField(
                rect: const PdfRect(0, 30, 100, 20),
                fieldName: 'typed',
                font: pdfFont,
                fontSize: 10,
                textColor: PdfColors.black,
              ),
            );
            return pw.SizedBox();
          },
        ),
      );
      final pdf = await save(document);

      expect(drFontsOf(pdf), hasLength(1));
      expect(drFontsOf(pdf), containsAll(daFontsOf(pdf)));
    });

    test('is a real object in the file', () async {
      final document = pw.Document(compress: false);
      document.addPage(
        pw.Page(
          pageFormat: const PdfPageFormat(300, 300, marginAll: 10),
          build: (pw.Context context) => pw.SizedBox(
            width: 100,
            height: 20,
            child: pw.TextField(name: 'a'),
          ),
        ),
      );
      final pdf = await save(document);

      final dr = RegExp(r'/DR<</Font<<([^>]*)>>').firstMatch(pdf)!.group(1)!;
      for (final m in RegExp(r'/\w+ (\d+) 0 R').allMatches(dr)) {
        expect(
          RegExp('\\n${m.group(1)} 0 obj').hasMatch(pdf),
          isTrue,
          reason: 'object ${m.group(1)} is in the file',
        );
      }
    });
  });

  group('an author on a widget', () {
    test('does not become its field name', () async {
      // /T is only defined for a markup annotation, and on a merged
      // field-and-widget dictionary it is the partial field name - so a widget
      // given an author became a form field named after them.
      final document = PdfDocument(compress: false);
      final page = PdfPage(document, pageFormat: PdfPageFormat.a4);
      PdfAnnot(
        page,
        PdfTextField(
          rect: const PdfRect(0, 0, 100, 20),
          font: PdfFont.helvetica(document),
          fontSize: 10,
          textColor: PdfColors.black,
          author: 'Jane Doe',
        ),
      );

      final pdf = latin1.decode(await document.save(), allowInvalid: true);

      expect(pdf, isNot(contains('Jane Doe')));
      expect(pdf, isNot(contains('/T(')));
    });

    test('does not displace a field name either', () async {
      final document = PdfDocument(compress: false);
      final page = PdfPage(document, pageFormat: PdfPageFormat.a4);
      PdfAnnot(
        page,
        PdfTextField(
          rect: const PdfRect(0, 0, 100, 20),
          fieldName: 'customer',
          font: PdfFont.helvetica(document),
          fontSize: 10,
          textColor: PdfColors.black,
          author: 'Jane Doe',
        ),
      );

      final pdf = latin1.decode(await document.save(), allowInvalid: true);

      expect(RegExp(r'/T\(customer\)').allMatches(pdf), hasLength(1));
      expect(pdf, isNot(contains('Jane Doe')));
    });

    test('is still written for a markup annotation', () async {
      final document = PdfDocument(compress: false);
      final page = PdfPage(document, pageFormat: PdfPageFormat.a4);
      PdfAnnot(
        page,
        PdfAnnotSquare(rect: const PdfRect(0, 0, 100, 20), author: 'Jane Doe'),
      );

      final pdf = latin1.decode(await document.save(), allowInvalid: true);

      expect(pdf, contains('/T('));
      expect(pdf, contains('Jane Doe'));
    });
  });
}
