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
import 'package:pdf/widgets.dart' as pw;
import 'package:test/test.dart';

/// The /BBox arrays a document with a soft mask over [box] emits.
Future<List<String>> boxes(PdfRect box) async {
  final document = pw.Document(compress: false).document;
  final page = PdfPage(document, pageFormat: PdfPageFormat.a4);
  final canvas = page.getGraphics()
    ..setGraphicState(
      PdfGraphicState(softMask: PdfSoftMask(document, boundingBox: box)),
    )
    ..drawRect(0, 0, 10, 10)
    ..fillPath();

  expect(canvas, isNotNull);
  return RegExp(r'/BBox(\[[^\]]*\])')
      .allMatches(String.fromCharCodes(await document.save()))
      .map((RegExpMatch m) => m.group(1)!)
      .toList();
}

void main() {
  test('a soft mask /BBox is a PDF rectangle', () async {
    // It was emitted as [left bottom width height], the PdfRect field layout, but
    // a form XObject /BBox is [llx lly urx ury]: for a non-zero origin the
    // upper-right corner was short by the origin, and /BBox hard-clips the mask,
    // with alpha 0 outside it. The artwork was silently missing, in a file that
    // stayed structurally valid.
    expect(await boxes(const PdfRect(100, 200, 300, 50)), <String>[
      '[100 200 400 250]',
    ]);

    expect(await boxes(const PdfRect(300, 400, 20, 30)), <String>[
      '[300 400 320 430]',
    ]);
  });

  test('a zero-origin box is unchanged', () async {
    expect(await boxes(const PdfRect(0, 0, 595.27559, 841.88976)), <String>[
      '[0 0 595.27559 841.88976]',
    ]);
  });

  test('the corners are never inverted', () async {
    for (final box in <PdfRect>[
      const PdfRect(0, 0, 0, 0),
      const PdfRect(10, 20, 0, 5),
      const PdfRect(-40, -30, 10, 10),
      const PdfRect(100, 200, 300, 50),
    ]) {
      final numbers = (await boxes(box)).single
          .replaceAll(RegExp(r'[\[\]]'), '')
          .split(' ')
          .map(double.parse)
          .toList();

      expect(numbers, hasLength(4));
      expect(numbers[2], greaterThanOrEqualTo(numbers[0]), reason: '$box');
      expect(numbers[3], greaterThanOrEqualTo(numbers[1]), reason: '$box');
    }
  });
}
