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

import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:test/test.dart';

class _TrackingImage extends pw.ImageProvider {
  _TrackingImage() : super(300, 200, PdfImageOrientation.topLeft, null);

  final requests = <(int?, int?)>[];

  @override
  PdfImage buildImage(pw.Context context, {int? width, int? height}) {
    requests.add((width, height));
    return PdfImage(
      context.document,
      image: Uint8List.fromList([255, 0, 0, 255]),
      width: 1,
      height: 1,
    );
  }
}

void main() {
  test(
    'an initial full-resolution render does not disable later DPI sizing',
    () {
      final image = _TrackingImage();
      final firstDocument = PdfDocument();
      final context = pw.Context(document: firstDocument);
      const fullPage = PdfPoint(72, 72);
      const halfPage = PdfPoint(72, 36);

      final original = image.resolve(context, fullPage);
      final scaled = image.resolve(context, fullPage, dpi: 72);
      expect(identical(original, scaled), isFalse);
      expect(image.requests, [(null, null), (72, 72)]);

      final cached = image.resolve(context, fullPage, dpi: 72);
      expect(identical(cached, scaled), isTrue);
      expect(image.requests.length, 2);

      // Reuse must also depend on height, not only width.
      image.resolve(context, halfPage, dpi: 72);
      expect(image.requests, [(null, null), (72, 72), (72, 36)]);

      // Cached PDF image objects belong to their original document.
      final other = pw.Context(document: PdfDocument());
      final otherImage = image.resolve(other, fullPage, dpi: 72);
      expect(identical(otherImage, scaled), isFalse);
      expect(image.requests.length, 4);
    },
  );

  test('each document keeps its own images when documents interleave', () {
    final image = _TrackingImage();
    final first = pw.Context(document: PdfDocument());
    final second = pw.Context(document: PdfDocument());
    const size = PdfPoint(72, 72);

    final firstOriginal = image.resolve(first, size);
    final firstScaled = image.resolve(first, size, dpi: 72);
    image.resolve(second, size);
    image.resolve(second, size, dpi: 72);
    expect(image.requests.length, 4);

    for (var page = 0; page < 100; page++) {
      expect(identical(image.resolve(first, size), firstOriginal), isTrue);
      expect(
        identical(image.resolve(first, size, dpi: 72), firstScaled),
        isTrue,
      );
    }
    expect(image.requests.length, 4);
  });
}
