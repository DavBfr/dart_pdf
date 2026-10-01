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

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart';
import 'package:test/test.dart';

Future<String> save(Document document) async =>
    latin1.decode(await document.save(), allowInvalid: true);

/// Save a low-level document and hand back its bytes as text.
Future<String> saveRaw(PdfDocument document) async =>
    latin1.decode(await document.save(), allowInvalid: true);

/// Everything inside the /Dests name tree's /Names array.
String _destsArray(String pdf) {
  final start = pdf.indexOf('/Dests<</Names[');
  if (start < 0) {
    return '';
  }

  final from = start + '/Dests<</Names['.length;
  final limits = pdf.indexOf('/Limits[', from);
  final end = limits < 0 ? pdf.indexOf(']', from) : limits - 1;
  return pdf.substring(from, end < from ? from : end);
}

/// The names in the /Dests array, in the order they are written.
List<String> destNamesOf(String pdf) => RegExp(
  r'\(([^)]*)\)',
).allMatches(_destsArray(pdf)).map((m) => m.group(1)!).toList();

/// The page reference each destination points at, keyed by name.
Map<String, String> destTargetsOf(String pdf) {
  final result = <String, String>{};

  for (final m in RegExp(
    r'\(([^)]*)\)<</D\[(\d+) 0 R',
  ).allMatches(_destsArray(pdf))) {
    result[m.group(1)!] = m.group(2)!;
  }
  return result;
}

/// Everything inside the /Nums array.
String _numsArray(String pdf) {
  final start = pdf.indexOf('/Nums[');
  if (start < 0) {
    return '';
  }

  final from = start + '/Nums['.length;
  return pdf.substring(from, pdf.indexOf(']', from));
}

/// Every /Count value in [pdf].
List<int> countsOf(String pdf) => RegExp(
  r'/Count (-?\d+)',
).allMatches(pdf).map((m) => int.parse(m.group(1)!)).toList();

void main() {
  group('a Header anchor', () {
    test('is unique per heading, not per text', () async {
      // The name was text.hashCode.toString(), so three headings with the same
      // text registered one destination and the last paint silently won: all
      // three bookmarks and their TOC rows jumped to the last page.
      final document = Document(compress: false);
      for (var i = 0; i < 3; i++) {
        document.addPage(
          Page(
            pageFormat: const PdfPageFormat(200, 200, marginAll: 10),
            build: (Context context) => Header(level: 1, text: 'Summary'),
          ),
        );
      }
      final pdf = await save(document);

      expect(destNamesOf(pdf), hasLength(3));
      expect(destTargetsOf(pdf).values.toSet(), hasLength(3));
    });

    test('is unique for a child-only heading too', () async {
      // null.hashCode is one constant for the whole document.
      final document = Document(compress: false);
      for (var i = 0; i < 2; i++) {
        document.addPage(
          Page(
            pageFormat: const PdfPageFormat(200, 200, marginAll: 10),
            build: (Context context) => Header(
              level: 1,
              title: 'Section $i',
              child: Text('Section $i'),
            ),
          ),
        );
      }
      final pdf = await save(document);

      expect(destNamesOf(pdf), hasLength(2));
      expect(destNamesOf(pdf), isNot(contains('2011')));
      expect(destTargetsOf(pdf).values.toSet(), hasLength(2));
    });

    test('is the name it was given', () async {
      final document = Document(compress: false);
      document.addPage(
        Page(
          pageFormat: const PdfPageFormat(200, 200, marginAll: 10),
          build: (Context context) => Column(
            children: <Widget>[
              Header(level: 1, text: 'Summary', anchorName: 'my-anchor'),
              Link(destination: 'my-anchor', child: Text('go')),
            ],
          ),
        ),
      );
      final pdf = await save(document);

      expect(destNamesOf(pdf), contains('my-anchor'));
    });

    test('is the same on a second save', () async {
      Document build() {
        final document = Document(compress: false);
        document.addPage(
          Page(
            pageFormat: const PdfPageFormat(200, 200, marginAll: 10),
            build: (Context context) => Header(level: 1, text: 'Summary'),
          ),
        );
        return document;
      }

      expect(
        destNamesOf(await save(build())),
        destNamesOf(await save(build())),
      );
    });

    test('is not quietly reused for another page', () {
      final document = PdfDocument();
      final a = PdfPage(document, pageFormat: PdfPageFormat.a4);
      final b = PdfPage(document, pageFormat: PdfPageFormat.a4);

      document.pdfNames.addDest('x', a);

      expect(() => document.pdfNames.addDest('x', b), throwsA(isA<Error>()));
      expect(() => document.pdfNames.addDest('x', a), returnsNormally);
    });
  });

  test('an outline item counts its own children', () async {
    // ISO 32000-1 Table 153: the magnitude of a negative /Count is how many items
    // become visible when this one is reopened, and reopening does not reopen the
    // children - so it is the immediate children, not the whole subtree. The
    // recursive total was written, so an item with two children and one
    // grandchild said -3 while expanding it revealed two rows.
    final document = PdfDocument(compress: false);
    final page = PdfPage(document, pageFormat: PdfPageFormat.a4);
    page.getGraphics()
      ..drawBox(const PdfRect(0, 0, 10, 10))
      ..setFillColor(PdfColors.red)
      ..fillPath();

    final a = PdfOutline(document, title: 'A', dest: page);
    final b = PdfOutline(document, title: 'B', dest: page);
    final c = PdfOutline(document, title: 'C', dest: page);
    final d = PdfOutline(document, title: 'D', dest: page);

    document.outline.add(a);
    a
      ..add(b)
      ..add(d);
    b.add(c);

    final pdf = await saveRaw(document);

    String bodyOf(PdfOutline o) => RegExp(
      '\\n${o.objser} 0 obj(.*?)endobj',
      dotAll: true,
    ).firstMatch(pdf)!.group(1)!;

    expect(bodyOf(a), contains('/Count -2'));
    expect(bodyOf(b), contains('/Count -1'));
    expect(bodyOf(c), isNot(contains('/Count')));
    expect(bodyOf(d), isNot(contains('/Count')));

    // The root is open, so its count is positive.
    expect(countsOf(pdf), contains(1));

    // descendants() keeps its own meaning.
    expect(a.descendants(), 3);
  });

  group('a page label', () {
    test('starts at the number it was given', () {
      // /St defaults to 1 and the style switch adds another 1, so an explicit
      // start double-counted the first page of the range.
      final arabic = PdfPageLabel.arabic(subsequent: 5);
      expect(
        <String>[arabic.asString(0), arabic.asString(1), arabic.asString(2)],
        <String>['5', '6', '7'],
      );

      expect(PdfPageLabel.romanLower(subsequent: 5).asString(0), 'v');
      expect(PdfPageLabel.lettersUpper(subsequent: 5).asString(0), 'E');
      expect(PdfPageLabel.lettersUpper().asString(0), 'A');
    });

    test('with a start of 1 is the same as no start at all', () {
      for (var k = 0; k <= 10; k++) {
        expect(
          PdfPageLabel.arabic(subsequent: 1).asString(k),
          PdfPageLabel.arabic().asString(k),
          reason: 'arabic $k',
        );
        expect(
          PdfPageLabel.romanLower(subsequent: 1).asString(k),
          PdfPageLabel.romanLower().asString(k),
          reason: 'roman $k',
        );
        expect(
          PdfPageLabel.lettersUpper(subsequent: 1).asString(k),
          PdfPageLabel.lettersUpper().asString(k),
          reason: 'letters $k',
        );
      }
    });

    test('refuses a start below 1', () {
      expect(
        () => PdfPageLabel.arabic(subsequent: 0),
        throwsA(isA<AssertionError>()),
      );
    });

    test('writes no comma in a roman numeral', () {
      // The table held 400: 'CD,'.
      expect(PdfPageLabel.romanUpper().asString(399), 'CD');
      expect(PdfPageLabel.romanLower().asString(399), 'cd');
      expect(PdfPageLabel.romanUpper().asString(447), 'CDXLVIII');
      expect(PdfPageLabel.romanUpper().asString(498), 'CDXCIX');

      final roman = PdfPageLabel.romanUpper();
      for (var n = 1; n <= 3999; n++) {
        expect(
          roman.asString(n - 1),
          matches(RegExp(r'^[MDCLXVI]+$')),
          reason: '$n',
        );
      }
    });

    test('reaches 3999 with asserts on', () {
      // The assert read `decimal < 3999` while its message said inclusive.
      expect(PdfPageLabel.romanUpper().asString(3998), 'MMMCMXCIX');
      expect(
        () => PdfPageLabel.romanUpper().asString(3999),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('the page label number tree', () {
    test('is written in ascending order', () async {
      // `labels` is a public insertion-ordered map and /Nums was built by walking
      // it, so writing labels[3] first emitted [3 ... 0 ... 1 ...] and a reader
      // that binary-searches the tree lost a whole range.
      final document = PdfDocument(compress: false);
      for (var i = 0; i < 6; i++) {
        PdfPage(document, pageFormat: PdfPageFormat.a4);
      }

      final labels = document.pageLabels;
      labels.labels[3] = PdfPageLabel.romanLower(prefix: 'appendix ');
      labels.labels[0] = PdfPageLabel('Hello');
      labels.labels[1] = PdfPageLabel.lettersUpper();

      final pdf = await saveRaw(document);
      final nums = _numsArray(pdf);

      expect(
        RegExp(
          r'(?:^|>)\s*(\d+)<<',
        ).allMatches(nums).map((m) => int.parse(m.group(1)!)),
        <int>[0, 1, 3],
      );
    });

    test('starts at page zero', () async {
      final document = PdfDocument(compress: false);
      for (var i = 0; i < 4; i++) {
        PdfPage(document, pageFormat: PdfPageFormat.a4);
      }

      document.pageLabels.labels[2] = PdfPageLabel.romanLower();

      final pdf = await saveRaw(document);
      final nums = _numsArray(pdf);

      expect(nums.trimLeft(), startsWith('0<</S/D>>'));
    });

    test('is the same after a second prepare', () async {
      final document = PdfDocument(compress: false);
      PdfPage(document, pageFormat: PdfPageFormat.a4);
      document.pageLabels.labels[0] = PdfPageLabel.romanLower();

      final first = await saveRaw(document);
      final second = await saveRaw(document);

      expect(_numsArray(second), _numsArray(first));
    });
  });
}
