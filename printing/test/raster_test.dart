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
    final image = await raster.toImage();
    expect(image, isA<ui.Image>());
    image.dispose();

    // Encoding the same raster repeatedly must remain valid even though
    // each temporary engine image is disposed after PNG creation.
    for (var i = 0; i < 3; i++) {
      final png = await raster.toPng();
      expect(png, isA<Uint8List>());
      expect(png.take(8).toList(), <int>[
        137, 80, 78, 71, 13, 10, 26, 10,
      ]);
    }
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
}
