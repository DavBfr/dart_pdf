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
import 'package:pdf/widgets.dart' as pw;
import 'package:test/test.dart';

/// One `beginbfchar` section of the emitted ToUnicode stream.
class _Section {
  _Section(this.declared, this.entries);

  /// The count the section declares.
  final int declared;

  /// Its `<src> <dst>` pairs.
  final List<List<String>> entries;
}

List<_Section> _sections(String pdf) {
  final sections = <_Section>[];

  for (final block in RegExp(
    r'(\d+) beginbfchar\n(.*?)endbfchar',
    dotAll: true,
  ).allMatches(pdf)) {
    final entries = <List<String>>[];
    for (final entry in RegExp(
      r'<([0-9A-F]+)> <([0-9A-F]+)>',
    ).allMatches(block.group(2)!)) {
      entries.add(<String>[entry.group(1)!, entry.group(2)!]);
    }
    sections.add(_Section(int.parse(block.group(1)!), entries));
  }

  return sections;
}

/// Build an uncompressed one-page document over [text] and return its bytes as a
/// string, so the ToUnicode stream can be read directly.
Future<String> buildPdf(String text, {bool protect = false}) async {
  // genyomintw covers both the BMP and the astral characters these cases need:
  // U+1F100 and U+20B9F are both in its cmap.
  final font = pw.TtfFont(
    File('genyomintw.ttf').readAsBytesSync().buffer.asByteData(),
    protect: protect,
  );

  final doc = pw.Document(compress: false);
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (_) =>
          pw.Text(text, style: pw.TextStyle(font: font, fontSize: 12)),
    ),
  );

  return String.fromCharCodes(await doc.save(), 0);
}

void main() {
  test('a non-BMP code point is written as a surrogate pair', () async {
    // The destination used to be the code point padded to four digits, so
    // anything above U+FFFF came out as five: <1F100>, which a reader decodes as
    // U+1F10 followed by a NUL. Copy, search and extraction all returned the
    // wrong characters while the glyphs still rendered.
    final pdf = await buildPdf('A\u{1F100}\u{20B9F}');

    expect(pdf, contains('<D83CDD00>'), reason: 'U+1F100');
    expect(pdf, contains('<D842DF9F>'), reason: 'U+20B9F');
    expect(pdf, isNot(contains('<1F100>')));
    expect(pdf, isNot(contains('<20B9F>')));
  });

  test('every destination is four or eight hex digits', () async {
    final pdf = await buildPdf('A\u{1F100}\u{20B9F}中z');

    final sections = _sections(pdf);
    expect(sections, isNotEmpty);

    for (final section in sections) {
      for (final entry in section.entries) {
        expect(
          entry[1].length,
          anyOf(4, 8),
          reason: 'destination ${entry[1]} has an odd number of digits',
        );
      }
    }
  });

  test('a plain character is unchanged', () async {
    final pdf = await buildPdf('A');

    final destinations = <String>[
      for (final section in _sections(pdf))
        for (final entry in section.entries) entry[1],
    ];

    expect(destinations, contains('0041'));
  });

  test('sections hold no more than a hundred entries', () async {
    // 150 distinct characters, which used to be emitted as one section - well
    // past the limit the format sets.
    final text = String.fromCharCodes(
      List<int>.generate(150, (int i) => 0x4E00 + i),
    );
    final pdf = await buildPdf(text);

    final sections = _sections(pdf);
    expect(sections.length, greaterThan(1));

    var total = 0;
    for (final section in sections) {
      expect(section.declared, lessThanOrEqualTo(100));
      expect(
        section.entries,
        hasLength(section.declared),
        reason: 'a section must declare what it contains',
      );
      total += section.declared;
    }

    // One entry per cmap index, and the .notdef at index 0.
    expect(total, greaterThanOrEqualTo(150));
  });

  test('the sources stay in ascending order across sections', () async {
    final text = String.fromCharCodes(
      List<int>.generate(150, (int i) => 0x4E00 + i),
    );
    final pdf = await buildPdf(text);

    final sources = <int>[
      for (final section in _sections(pdf))
        for (final entry in section.entries) int.parse(entry[0], radix: 16),
    ];

    expect(sources, sources.toList()..sort());
    expect(sources.toSet(), hasLength(sources.length), reason: 'one per CID');
  });

  test('protect replaces every destination with a space', () async {
    final pdf = await buildPdf('A\u{1F100}B', protect: true);

    var replaced = 0;
    for (final section in _sections(pdf)) {
      for (final entry in section.entries) {
        if (int.parse(entry[0], radix: 16) == 0) {
          // CID 0 is .notdef and is not a character to hide.
          continue;
        }
        expect(entry[1], '0020');
        replaced++;
      }
    }

    expect(replaced, greaterThan(0));
  });
}
