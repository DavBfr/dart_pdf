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
import 'package:test/test.dart';
import 'package:xml/xml.dart';

/// Save a document carrying [files] as PDF/A attachments.
Future<String> withAttachments(List<PdfaAttachedFile> files) async {
  final document = PdfDocument(compress: false);
  PdfPage(document, pageFormat: PdfPageFormat.a4);
  PdfaAttachedFiles(document, files);

  return latin1.decode(await document.save(), allowInvalid: true);
}

/// Every element of [name] in [document].
Iterable<XmlElement> elements(XmlDocument document, String name) => document
    .descendants
    .whereType<XmlElement>()
    .where((XmlElement e) => e.name.qualified == name);

void main() {
  group('an embedded file', () {
    test('declares its size in bytes', () async {
      // /Size was the UTF-16 code-unit count while the payload is written as
      // UTF-8, so the two agreed only for ASCII: a Factur-X attachment with
      // accents declared 99 for a 106-byte stream, and a consumer that trusts
      // /Size truncated the XML.
      const content = '<facture>Télécommunications & Électricité</facture>';
      final pdf = await withAttachments(<PdfaAttachedFile>[
        PdfaAttachedFile(name: 'facture.xml', data: content),
      ]);

      final size = int.parse(RegExp(r'/Size (\d+)').firstMatch(pdf)!.group(1)!);
      final length = int.parse(
        RegExp(
              r'/Size \d+[^>]*>>[^>]*/Length (\d+)',
            ).firstMatch(pdf)?.group(1) ??
            RegExp(r'/Length (\d+)').allMatches(pdf).last.group(1)!,
      );

      expect(size, utf8.encode(content).length);
      expect(size, greaterThan(content.length));
      expect(length, size, reason: 'the stream is uncompressed');
    });

    test('counts four bytes for a non-BMP character', () async {
      const content = 'a\u{1F600}';
      final pdf = await withAttachments(<PdfaAttachedFile>[
        PdfaAttachedFile(name: 'x.xml', data: content),
      ]);

      expect(int.parse(RegExp(r'/Size (\d+)').firstMatch(pdf)!.group(1)!), 5);
    });

    test('is unchanged for ASCII', () async {
      final pdf = await withAttachments(<PdfaAttachedFile>[
        PdfaAttachedFile(name: 'factur-x.xml', data: '<a/>'),
      ]);

      expect(int.parse(RegExp(r'/Size (\d+)').firstMatch(pdf)!.group(1)!), 4);
    });
  });

  group('the embedded file name tree', () {
    /// The /Names keys of [pdf], in the order they are written.
    List<String> namesOf(String pdf) {
      final array = RegExp(
        r'/Names\[(.*?)\]\s*>>',
        dotAll: true,
      ).firstMatch(pdf)!.group(1)!;
      return RegExp(
        r'\(([^)]*)\)',
      ).allMatches(array).map((m) => m.group(1)!).toList();
    }

    test('is sorted', () async {
      // A name tree's keys have to ascend - ISO 32000-1 7.9.6 - or a consumer's
      // binary search can miss one. They were emitted in caller order.
      final pdf = await withAttachments(<PdfaAttachedFile>[
        PdfaAttachedFile(name: 'zeta.xml', data: '<a/>'),
        PdfaAttachedFile(name: 'mu.xml', data: '<a/>'),
        PdfaAttachedFile(name: 'alpha.xml', data: '<a/>'),
      ]);

      expect(namesOf(pdf), <String>['alpha.xml', 'mu.xml', 'zeta.xml']);
    });

    test('keeps /AF in the caller order', () async {
      final pdf = await withAttachments(<PdfaAttachedFile>[
        PdfaAttachedFile(name: 'zeta.xml', data: '<z/>'),
        PdfaAttachedFile(name: 'alpha.xml', data: '<a/>'),
      ]);

      // The /AF references, and which file each one points at.
      final af = RegExp(r'/AF\[([^\]]*)\]').firstMatch(pdf)!.group(1)!;
      final refs = RegExp(
        r'(\d+) 0 R',
      ).allMatches(af).map((m) => m.group(1)!).toList();

      final first = RegExp(
        '\\n${refs.first} 0 obj(.*?)endobj',
        dotAll: true,
      ).firstMatch(pdf)!.group(1)!;
      expect(first, contains('zeta.xml'), reason: 'caller order, not sorted');
    });

    test('escapes a name that holds a delimiter', () async {
      // The key was written as '($name) ref' straight into the stream, so an
      // unbalanced ')' or a backslash corrupted the object.
      final pdf = await withAttachments(<PdfaAttachedFile>[
        PdfaAttachedFile(name: r'we(ird\.xml', data: '<a/>'),
      ]);

      expect(pdf, contains(r'we\(ird\\.xml'));

      // /F, /UF and the name-tree key all carry the same bytes.
      expect(RegExp(r'we\\\(ird\\\\\.xml').allMatches(pdf), hasLength(3));
    });

    test('writes a non-Latin-1 name as UTF-16BE everywhere', () async {
      // /F and /UF took the raw code units, one byte each, so a name above 0xFF
      // was truncated character by character.
      final pdf = await withAttachments(<PdfaAttachedFile>[
        PdfaAttachedFile(name: 'facture-€.xml', data: '<a/>'),
      ]);

      // The BOM, three times: /F, /UF and the key.
      expect(
        RegExp('\u{00FE}\u{00FF}').allMatches(pdf).length,
        greaterThanOrEqualTo(3),
      );
    });
  });

  group('the XMP packet', () {
    test('never writes the word null', () {
      // Every field is nullable and each was interpolated unconditionally, and
      // Dart interpolation calls toString() - so the package's own README example
      // emitted <pdf:Producer>null</pdf:Producer>.
      final packet = PdfaRdf().create()!.toString();

      expect(packet, isNot(contains('null')));
    });

    test('omits an unset field rather than emitting it empty', () {
      final packet = PdfaRdf().create()!.toString();

      for (final element in <String>[
        'pdf:Producer',
        'pdf:Keywords',
        'xmp:CreatorTool',
        'dc:creator',
        'dc:title',
        'dc:description',
      ]) {
        expect(packet, isNot(contains(element)), reason: element);
      }
    });

    test('always carries the conformance claim', () {
      for (final rdf in <PdfaRdf>[PdfaRdf(), PdfaRdf(title: 'T')]) {
        final document = rdf.create()!;
        final packet = document.toString();

        expect(
          elements(document, 'pdfaid:part').map((e) => e.innerText),
          <String>['3'],
        );
        expect(
          elements(document, 'pdfaid:conformance').map((e) => e.innerText),
          <String>['B'],
        );
        expect(packet, contains('xpacket begin'));
        expect(packet, contains('xpacket end'));
        expect(elements(document, 'xmp:CreateDate'), hasLength(1));
      }
    });

    test('emits only the fields it was given', () {
      final document = PdfaRdf(title: 'T').create()!;

      expect(elements(document, 'dc:title'), hasLength(1));
      expect(elements(document, 'dc:title').first.innerText, 'T');
      expect(elements(document, 'dc:creator'), isEmpty);
      expect(elements(document, 'dc:description'), isEmpty);
    });

    test('takes a value holding markup', () {
      // An unmatched '<' threw XmlParserException out of the build.
      late XmlDocument document;
      expect(
        () => document = PdfaRdf(title: 'Rapport <2026-001>').create()!,
        returnsNormally,
      );

      expect(
        elements(document, 'dc:title').first.innerText,
        'Rapport <2026-001>',
      );
    });

    test('round-trips every field character for character', () {
      const hostile = 'a <b> & "c" \'d\' &amp; e';
      final document = PdfaRdf(
        title: hostile,
        author: hostile,
        creator: hostile,
        subject: hostile,
        keywords: hostile,
        producer: hostile,
      ).create()!;

      for (final element in <String>[
        'dc:title',
        'dc:creator',
        'dc:description',
        'xmp:CreatorTool',
        'pdf:Keywords',
        'pdf:Producer',
      ]) {
        expect(
          elements(document, element).first.innerText,
          hostile,
          reason: element,
        );
      }
    });

    test('cannot be rewritten by a value', () {
      // Balanced markup used to be accepted and injected into the packet,
      // including over the conformance claim.
      final document = PdfaRdf(
        title:
            '</dc:title></rdf:Description><rdf:Description>'
            '<pdfaid:part>1</pdfaid:part>',
      ).create()!;

      expect(
        elements(document, 'pdfaid:part').map((e) => e.innerText),
        <String>['3'],
      );
      expect(
        elements(document, 'dc:title').first.innerText,
        contains('<pdfaid:part>1</pdfaid:part>'),
      );
    });

    test('drops a character XML forbids', () {
      final document = PdfaRdf(title: 'a\u0000b\u0008c').create()!;

      expect(elements(document, 'dc:title').first.innerText, 'abc');
    });

    test('keeps the invoice fragment raw', () {
      final document = PdfaRdf(invoiceRdf: PdfaFacturxRdf().create()).create()!;

      expect(elements(document, 'fx:DocumentFileName'), isNotEmpty);
      expect(elements(document, 'pdfaExtension:schemas'), isNotEmpty);
    });
  });
}
