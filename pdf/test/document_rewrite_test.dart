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
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/src/priv.dart';
import 'package:test/test.dart';

/// A one-page document with a TrueType font, a drawn string and an annotation.
PdfDocument fixture() {
  final data = File('open-sans.ttf').readAsBytesSync();
  final document = PdfDocument(compress: false);
  final page = PdfPage(document, pageFormat: PdfPageFormat.a4);
  final font = PdfTtfFont(document, data.buffer.asByteData());

  page.getGraphics()
    ..setFillColor(PdfColors.black)
    ..drawString(font, 20, 'Hello wörld', 50, 700);

  PdfAnnot(
    page,
    PdfAnnotNamedLink(rect: const PdfRect(0, 0, 10, 10), dest: 'target'),
  );

  return document;
}

/// Write [document] and hand back the bytes.
Future<Uint8List> write(PdfDocument document) async {
  final stream = PdfStream();
  await document.write(stream);
  return stream.output();
}

void main() {
  group('writing the same document twice', () {
    test('produces the same bytes', () async {
      // prepare() runs on every write, and five implementations appended to
      // state that survives the call - so a second write embedded the font
      // program again behind a /Length1 that described one copy, gave /ToUnicode
      // two begincmap programs, and listed every width and every annotation
      // twice. The file grew from 7,214 bytes to 12,887.
      final document = fixture();

      final first = await write(document);
      final second = await write(document);
      final third = await write(document);

      expect(second, first);
      expect(third, first);
    });

    test('embeds the font program once', () async {
      final document = fixture();
      await write(document);
      final text = latin1.decode(await write(document), allowInvalid: true);

      expect(RegExp('begincmap').allMatches(text), hasLength(1));
      expect(RegExp('endcmap').allMatches(text), hasLength(1));
    });

    test('declares one /Length1, the same on every write', () async {
      // /Length1 is the uncompressed length of the font program, and the program
      // was appended again while /Length1 was recomputed for one copy - so the
      // two disagreed from the second write on.
      final document = fixture();
      final first = latin1.decode(await write(document), allowInvalid: true);
      final second = latin1.decode(await write(document), allowInvalid: true);

      final lengths = <String>[
        for (final text in <String>[first, second])
          RegExp(r'/Length1 (\d+)').firstMatch(text)!.group(1)!,
      ];

      expect(RegExp(r'/Length1 \d+').allMatches(second), hasLength(1));
      expect(lengths[1], lengths[0]);
    });

    test('lists an annotation once', () async {
      final document = fixture();
      await write(document);
      final text = latin1.decode(await write(document), allowInvalid: true);

      final annots = RegExp(r'/Annots(\[[^\]]*\])').firstMatch(text)!.group(1)!;
      expect(RegExp(r'\d+ 0 R').allMatches(annots), hasLength(1));
    });

    test('keeps a /Contents inherited from a template', () async {
      final document = PdfDocument(compress: false);
      final page = PdfPage(document, pageFormat: PdfPageFormat.a4);
      final imported = PdfObjectStream(document)
        ..buf.putString('1 0 0 1 0 0 cm ');
      page.params['/Contents'] = imported.ref();

      page.getGraphics()
        ..drawBox(const PdfRect(0, 0, 10, 10))
        ..setFillColor(PdfColors.red)
        ..fillPath();

      final first = latin1.decode(await write(document), allowInvalid: true);
      final second = latin1.decode(await write(document), allowInvalid: true);

      final contents = RegExp(r'/Contents(\[[^\]]*\])').firstMatch(second)!;
      expect(
        RegExp('${imported.objser} 0 R').allMatches(contents.group(1)!),
        hasLength(1),
      );
      expect(second, first);
    });
  });

  group('an imported page', () {
    /// A page carrying [imported] as its previous /Contents, plus one appended
    /// graphics stream.
    Future<String> stamp(String imported, {bool protect = true}) async {
      final document = PdfDocument(compress: false);
      final page = PdfPage(
        document,
        pageFormat: PdfPageFormat.a4,
        protectImportedContents: protect,
      );
      final previous = PdfObjectStream(document)..buf.putString(imported);
      page.params['/Contents'] = previous.ref();

      page.getGraphics()
        ..drawBox(const PdfRect(0, 0, 10, 10))
        ..setFillColor(PdfColors.red)
        ..fillPath();

      return latin1.decode(await write(document), allowInvalid: true);
    }

    test('brackets its previous content with q and Q', () async {
      // A /Contents array is concatenated into one stream, so an active
      // '1 0 0 -1 0 842 cm' from the producer was still in force for whatever
      // was stamped on afterwards: the content came out mirrored.
      final text = await stamp('1 0 0 -1 0 842 cm ');

      final contents = RegExp(r'/Contents\[([^\]]*)\]').firstMatch(text)!;
      final refs = RegExp(
        r'(\d+) 0 R',
      ).allMatches(contents.group(1)!).map((m) => m.group(1)!).toList();

      expect(refs, hasLength(4), reason: 'q, imported, Q, appended');

      // The first and third streams are the brackets.
      String streamOf(String objser) => RegExp(
        '\\n$objser 0 obj(.*?)endobj',
        dotAll: true,
      ).firstMatch(text)!.group(1)!;

      expect(streamOf(refs[0]), contains('q'));
      expect(streamOf(refs[2]), contains('Q'));
    });

    test('survives an unbalanced q in the imported content', () async {
      final text = await stamp('q 1 0 0 -1 0 842 cm ');

      expect(
        RegExp(r'/Contents\[([^\]]*)\]')
            .firstMatch(text)!
            .group(1)!
            .let((String s) => RegExp(r'\d+ 0 R').allMatches(s).length),
        4,
      );
    });

    test('is untouched when nothing is stamped on it', () async {
      final document = PdfDocument(compress: false);
      final page = PdfPage(document, pageFormat: PdfPageFormat.a4);
      final previous = PdfObjectStream(document)
        ..buf.putString('1 0 0 1 0 0 cm ');
      page.params['/Contents'] = previous.ref();

      final text = latin1.decode(await write(document), allowInvalid: true);

      expect(text, contains('/Contents ${previous.objser} 0 R'));
      expect(text, isNot(contains('/Contents[')));
    });

    test('keeps its old bytes when protection is turned off', () async {
      final text = await stamp('1 0 0 -1 0 842 cm ', protect: false);

      final refs = RegExp(r'\d+ 0 R').allMatches(
        RegExp(r'/Contents\[([^\]]*)\]').firstMatch(text)!.group(1)!,
      );
      expect(refs, hasLength(2), reason: 'imported and appended, no brackets');
    });

    test('saves without a concurrent modification error', () async {
      expect(await stamp('1 0 0 -1 0 842 cm '), isNotEmpty);
    });
  });

  group('a page origin', () {
    Future<String> boxOf({PdfPoint origin = PdfPoint.zero}) async {
      final document = PdfDocument(compress: false);
      PdfPage(
        document,
        pageFormat: const PdfPageFormat(2448, 1584),
        origin: origin,
      );

      final text = latin1.decode(await write(document), allowInvalid: true);
      return RegExp(r'/MediaBox\[([^\]]*)\]').firstMatch(text)!.group(1)!;
    }

    test('reaches the /MediaBox', () async {
      // /MediaBox was written as [0 0 w h] whatever the page said, so loading a
      // PDF with a negative origin and re-saving pinned the box to 0,0 and the
      // content at negative coordinates fell off it.
      expect(
        await boxOf(origin: const PdfPoint(-1224, -792)),
        '-1224 -792 1224 792',
      );
    });

    test('defaults to zero', () async {
      expect(await boxOf(), '0 0 2448 1584');

      final document = PdfDocument(compress: false);
      PdfPage(document, pageFormat: PdfPageFormat.a4);
      final text = latin1.decode(await write(document), allowInvalid: true);

      expect(text, contains('/MediaBox[0 0 595.27559 841.88976]'));
    });

    test('is re-derived on every write', () async {
      final document = PdfDocument(compress: false);
      final page = PdfPage(
        document,
        pageFormat: const PdfPageFormat(100, 200),
        origin: const PdfPoint(-10, -20),
      );

      final first = latin1.decode(await write(document), allowInvalid: true);
      expect(first, contains('/MediaBox[-10 -20 90 180]'));

      page.origin = const PdfPoint(5, 5);
      final second = latin1.decode(await write(document), allowInvalid: true);
      expect(second, contains('/MediaBox[5 5 105 205]'));
    });

    test('drops a /CropBox that would fall outside it', () async {
      final document = PdfDocument(compress: false);
      final page = PdfPage(
        document,
        pageFormat: const PdfPageFormat(100, 200),
        origin: const PdfPoint(-10, -20),
      );
      page.params['/CropBox'] = PdfArray.fromNum(<double>[0, 0, 100, 200]);

      final text = latin1.decode(await write(document), allowInvalid: true);

      expect(text, isNot(contains('/CropBox')));
    });
  });
}

extension<T> on T {
  R let<R>(R Function(T) body) => body(this);
}
