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

import 'exif_test.dart' show jpeg;

void main() {
  group('a four component JPEG', () {
    test('with an Adobe marker is inverted, whatever its transform byte says', () {
      // isCMYKInverted was isCMYK && transform != 0, which keys on the transform
      // byte's value rather than on the marker being there at all - and the field
      // is null when there is no marker, so one field meant both questions.
      // Transform 0 says the components were not transformed, not that they were
      // not inverted: a Photoshop or Pillow CMYK JPEG came out as a negative.
      for (final transform in <int>[0, 1, 2]) {
        final info = PdfJpegInfo(
          jpeg(components: 4, adobeMarker: true, adobeTransform: transform),
        );

        expect(info.isCMYK, isTrue, reason: 'transform $transform');
        expect(info.hasAdobeMarker, isTrue, reason: 'transform $transform');
        expect(info.isCMYKInverted, isTrue, reason: 'transform $transform');
      }
    });

    test('with no Adobe marker is not inverted', () {
      // The other half of the same confusion: a marker-less four-component file
      // was inverted although it is stored straight.
      final info = PdfJpegInfo(jpeg(components: 4));

      expect(info.isCMYK, isTrue);
      expect(info.hasAdobeMarker, isFalse);
      expect(info.isCMYKInverted, isFalse);
    });

    test('with a short Adobe segment is still an Adobe file', () {
      // The marker used to be recognised only when the segment was long enough
      // to hold a transform byte.
      final info = PdfJpegInfo(
        jpeg(components: 4, adobeMarker: true, adobeLength: 9),
      );

      expect(info.hasAdobeMarker, isTrue);
      expect(info.adobeColorTransform, isNull);
      expect(info.isCMYKInverted, isTrue);
    });
  });

  test('a one or three component JPEG is never inverted', () {
    for (final components in <int>[1, 3]) {
      for (final adobe in <bool>[false, true]) {
        final info = PdfJpegInfo(
          jpeg(components: components, adobeMarker: adobe),
        );

        expect(info.isCMYK, isFalse, reason: '$components, adobe $adobe');
        expect(
          info.isCMYKInverted,
          isFalse,
          reason: '$components, adobe $adobe',
        );
      }
    }
  });

  group('PdfImage.jpeg', () {
    test('writes the Decode array for an Adobe transform 0 file', () {
      final image = PdfImage.jpeg(
        PdfDocument(),
        image: jpeg(components: 4, adobeMarker: true, adobeTransform: 0),
      );

      expect(image.params['/ColorSpace'].toString(), '/DeviceCMYK');
      expect(image.params['/Decode'].toString(), '[1 0 1 0 1 0 1 0]');
    });

    test('writes DeviceCMYK but no Decode without an Adobe marker', () {
      final image = PdfImage.jpeg(PdfDocument(), image: jpeg(components: 4));

      expect(image.params['/ColorSpace'].toString(), '/DeviceCMYK');
      expect(image.params.containsKey('/Decode'), isFalse);
    });

    test('takes an override either way round', () {
      final inverted = PdfImage.jpeg(
        PdfDocument(),
        image: jpeg(components: 4),
        cmykInverted: true,
      );
      expect(inverted.params['/Decode'].toString(), '[1 0 1 0 1 0 1 0]');

      final straight = PdfImage.jpeg(
        PdfDocument(),
        image: jpeg(components: 4, adobeMarker: true),
        cmykInverted: false,
      );
      expect(straight.params.containsKey('/Decode'), isFalse);
      expect(straight.params['/ColorSpace'].toString(), '/DeviceCMYK');
    });
  });
}
