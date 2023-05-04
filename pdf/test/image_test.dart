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
import 'package:pdf/src/priv.dart';
import 'package:test/test.dart';

const kRedValue = 110;
const kGreenValue = 120;
const kBlueValue = 130;
const kAlphaValue = 200;

Uint8List createTestImage(int width, int height, {bool withAlpha = true}) {
  final channelCount = withAlpha ? 4 : 3;
  final img = Uint8List(width * height * channelCount);
  for (var pixelIndex = 0; pixelIndex < width * height; pixelIndex++) {
    img[pixelIndex * channelCount] = kRedValue;
    img[pixelIndex * channelCount + 1] = kGreenValue;
    img[pixelIndex * channelCount + 2] = kBlueValue;
    if (channelCount == 4) {
      img[pixelIndex * channelCount + 3] = kAlphaValue;
    }
  }

  return img;
}

void main() {
  test('PdfImage constructor with alpha channel', () async {
    final img = createTestImage(300, 200);

    final pdf = PdfDocument();

    final image = PdfImage(
      pdf,
      image: img.buffer.asUint8List(),
      width: 300,
      height: 200,
    );

    expect(image.params['/Width'], const PdfNum(300));
    expect(image.params['/Height'], const PdfNum(200));
    expect(image.params['/SMask'], isA<PdfIndirect>());

    final buf = image.buf.output();
    for (var pixelIndex = 0; pixelIndex < 300 * 200; pixelIndex++) {
      expect(buf[pixelIndex * 3], kRedValue);
      expect(buf[pixelIndex * 3 + 1], kGreenValue);
      expect(buf[pixelIndex * 3 + 2], kBlueValue);
    }
  });

  test('PdfImage constructor without alpha channel', () async {
    final img = createTestImage(300, 200, withAlpha: false);

    final pdf = PdfDocument();

    final image = PdfImage(
      pdf,
      image: img.buffer.asUint8List(),
      width: 300,
      height: 200,
      alpha: false,
    );

    expect(image.params['/Width'], const PdfNum(300));
    expect(image.params['/Height'], const PdfNum(200));
    expect(image.params['/SMask'], isNull);

    final buf = image.buf.output();
    for (var pixelIndex = 0; pixelIndex < 300 * 200; pixelIndex++) {
      expect(buf[pixelIndex * 3], kRedValue);
      expect(buf[pixelIndex * 3 + 1], kGreenValue);
      expect(buf[pixelIndex * 3 + 2], kBlueValue);
    }
  });
}
