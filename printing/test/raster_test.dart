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
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:printing/printing.dart';

void main() {
  setUp(TestWidgetsFlutterBinding.ensureInitialized);

  test('PdfRaster', () async {
    final raster = PdfRaster(
      10,
      10,
      Uint8List.fromList(List<int>.filled(10 * 10 * 4, 0)),
    );
    expect(raster.toString(), 'Image 10x10 400 bytes');
    expect(await raster.toImage(), isA<ui.Image>());
    expect(await raster.toPng(), isA<Uint8List>());
  });

  testWidgets('PdfRasterImage', (WidgetTester tester) async {
    final raster = PdfRaster(
      10,
      10,
      Uint8List.fromList(List<int>.filled(10 * 10 * 4, 0)),
    );

    await tester.pumpWidget(Image(image: PdfRasterImage(raster)));
    await tester.pumpAndSettle();
  });

  test('PngPdfRaster', () async {
    const width = 10;
    const height = 10;
    final rawPixels = Uint8List.fromList(
      List<int>.filled(width * height * 4, 0),
    );
    // Reuse PdfRaster.toPng() to obtain real, valid PNG bytes rather than a
    // hand-crafted fixture.
    final pngBytes = await PdfRaster(width, height, rawPixels).toPng();

    final raster = PngPdfRaster(width, height, pngBytes);

    expect(raster.width, width);
    expect(raster.height, height);

    // No decode/re-encode round trip: the platform-provided bytes are
    // returned as-is.
    expect(await raster.toPng(), same(pngBytes));

    // Raw pixels and the ui.Image are only decoded on demand, when actually
    // requested.
    expect(raster.pixels, hasLength(width * height * 4));
    expect(await raster.toImage(), isA<ui.Image>());
  });
}
