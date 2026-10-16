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

import 'package:pdf/pdf.dart';
import 'package:test/test.dart';

/// The content stream a page painted by [paint] produces.
Future<String> draw(
  void Function(PdfGraphics canvas) paint, {
  bool verbose = false,
}) async {
  final document = PdfDocument(compress: false, verbose: verbose);
  final page = PdfPage(document, pageFormat: PdfPageFormat.a4);
  paint(page.getGraphics());

  final pdf = String.fromCharCodes(await document.save());
  return RegExp(
    r'stream\n(.*?)endstream',
    dotAll: true,
  ).allMatches(pdf).map((RegExpMatch m) => m.group(1)!).join();
}

void main() {
  group('a null colour', () {
    test('is a no-op rather than a crash', () async {
      // The signatures have always accepted null and the verbose diagnostics
      // already used color?.toHex(), but 'null is PdfColorCmyk' is false, so null
      // fell into the RGB branch and was dereferenced there: 'Null check operator
      // used on a null value' while the document was being built.
      for (final verbose in <bool>[false, true]) {
        final plain = await draw((PdfGraphics canvas) {
          canvas
            ..drawRect(0, 0, 10, 10)
            ..fillPath();
        }, verbose: verbose);

        final withNulls = await draw((PdfGraphics canvas) {
          canvas
            ..setFillColor(null)
            ..setStrokeColor(null)
            ..setColor(null)
            ..drawRect(0, 0, 10, 10)
            ..fillPath();
        }, verbose: verbose);

        expect(plain, isNotEmpty);
        expect(
          withNulls,
          plain,
          reason: 'verbose $verbose: a null colour writes nothing',
        );
      }
    });

    test('leaves the colour that was set', () async {
      final stream = await draw((PdfGraphics canvas) {
        canvas
          ..setFillColor(PdfColors.red)
          ..setFillColor(null)
          ..drawRect(0, 0, 10, 10)
          ..fillPath();
      });

      expect(RegExp(r'\brg\b').allMatches(stream), hasLength(1));
      expect(stream, contains('0.95686 0.26275 0.21176 rg'));
    });
  });

  test('a colour still picks its own operator', () async {
    final rgb = await draw((PdfGraphics canvas) {
      canvas
        ..setFillColor(PdfColors.red)
        ..setStrokeColor(PdfColors.red)
        ..drawRect(0, 0, 10, 10)
        ..fillPath();
    });
    expect(rgb, contains('0.95686 0.26275 0.21176 rg'));
    expect(rgb, contains('0.95686 0.26275 0.21176 RG'));

    final cmyk = await draw((PdfGraphics canvas) {
      canvas
        ..setFillColor(const PdfColorCmyk(0, 0, 0, 1))
        ..setStrokeColor(const PdfColorCmyk(0, 0, 0, 1))
        ..drawRect(0, 0, 10, 10)
        ..fillPath();
    });
    expect(cmyk, contains('0 0 0 1 k'));
    expect(cmyk, contains('0 0 0 1 K'));
  });
}
