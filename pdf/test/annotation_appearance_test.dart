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

/// The /BBox of the appearance stream an annotation over [rect] emits.
Future<String> appearanceBox({PdfRect? boundingBox}) async {
  final document = pw.Document(compress: false).document;
  final page = PdfPage(document, pageFormat: PdfPageFormat.a4);

  final annotation = PdfAnnotSign(
    rect: const PdfRect(50, 500, 200, 100),
    fieldName: 'field',
  );
  PdfAnnot(page, annotation);

  annotation
      .appearance(document, PdfAnnotAppearance.normal, boundingBox: boundingBox)
      .drawRect(0, 0, 10, 10);

  final pdf = String.fromCharCodes(await document.save());
  return RegExp(r'/BBox(\[[^\]]*\])').firstMatch(pdf)!.group(1)!;
}

void main() {
  test('an appearance /BBox is a PDF rectangle', () async {
    // It was emitted as [left bottom width height], the PdfRect field layout, but
    // a form XObject /BBox is [llx lly urx ury]: a caller passing a non-zero
    // origin got an appearance clipped to the wrong rectangle and stretched to
    // fill /Rect, with no error raised.
    expect(
      await appearanceBox(boundingBox: const PdfRect(100, 600, 200, 100)),
      '[100 600 300 700]',
    );
  });

  test('a zero-origin box, and no box at all, are unchanged', () async {
    expect(
      await appearanceBox(boundingBox: const PdfRect(0, 0, 200, 100)),
      '[0 0 200 100]',
    );
    expect(
      await appearanceBox(),
      '[0 0 200 100]',
      reason: 'the default is the annotation rect at the origin',
    );
  });

  test('the corners are never inverted', () async {
    for (final box in <PdfRect>[
      const PdfRect(0, 0, 0, 0),
      const PdfRect(100, 600, 0, 50),
      const PdfRect(-20, -10, 30, 40),
    ]) {
      final numbers = (await appearanceBox(boundingBox: box))
          .replaceAll(RegExp(r'[\[\]]'), '')
          .split(' ')
          .map(double.parse)
          .toList();

      expect(numbers[2], greaterThanOrEqualTo(numbers[0]), reason: '$box');
      expect(numbers[3], greaterThanOrEqualTo(numbers[1]), reason: '$box');
    }
  });

  test(
    'the annotation rect passed as the box gives the same numbers',
    () async {
      const rect = PdfRect(50, 500, 200, 100);
      expect(await appearanceBox(boundingBox: rect), '[50 500 250 600]');

      final document = pw.Document(compress: false).document;
      final page = PdfPage(document, pageFormat: PdfPageFormat.a4);
      final annotation = PdfAnnotSign(rect: rect, fieldName: 'field');
      PdfAnnot(page, annotation);
      final pdf = String.fromCharCodes(await document.save());

      expect(
        RegExp(r'/Rect(\[[^\]]*\])').firstMatch(pdf)!.group(1),
        '[50 500 250 600]',
        reason: '/Rect has always been written this way',
      );
    },
  );
}
