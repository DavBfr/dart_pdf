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
import 'dart:typed_data';

import 'package:image/image.dart' as im;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart';
import 'package:test/test.dart';

/// An SVG holding one `<image>` with [href], plus a green rectangle beside it.
String svgWith(String href) =>
    '''
<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg"
     xmlns:xlink="http://www.w3.org/1999/xlink">
  <image x="0" y="0" width="50" height="50" xlink:href="$href"/>
  <rect x="50" y="50" width="40" height="40" fill="#00ff00"/>
</svg>''';

/// Save a document holding [svg] and hand back the raw bytes as text.
Future<String> render(String svg) async {
  final document = Document(compress: false);
  document.addPage(
    Page(
      pageFormat: const PdfPageFormat(100, 100, marginAll: 0),
      build: (Context context) => SvgImage(svg: svg),
    ),
  );
  return latin1.decode(await document.save(), allowInvalid: true);
}

/// A data URI for [bytes] with the given media type.
String dataUri(List<int> bytes, {String type = 'image/png'}) =>
    'data:$type;base64,${base64.encode(bytes)}';

/// A two-pixel image, red then blue.
im.Image redBlue() {
  final image = im.Image(width: 2, height: 1, numChannels: 3);
  image.setPixelRgb(0, 0, 255, 0, 0);
  image.setPixelRgb(1, 0, 0, 0, 255);
  return image;
}

/// How many images the page actually draws.
///
/// Not how many image objects the file holds: an image with an alpha channel
/// also writes a /DeviceGray soft mask, which the image references and the page
/// does not.
int imagesDrawn(String pdf) => RegExp(r'/I\d+ Do').allMatches(pdf).length;

void main() {
  group('an <image> data URI', () {
    test('of every raster format saves', () async {
      // package:image's own storage was handed straight to the raw PdfImage
      // factory, which needs tightly packed uint8 RGBA. It keeps 1 byte a pixel
      // for grayscale and palette, 3 for RGB and JPEG, and packed bits for a
      // 1-bit palette - so the alpha loop overran with
      // 'RangeError (length): Not in inclusive range 0..N' and aborted save().
      final rgba = im.Image(width: 4, height: 4);
      final rgb = im.Image(width: 4, height: 4, numChannels: 3);
      final gray = im.Image(
        width: 4,
        height: 4,
        format: im.Format.uint8,
        numChannels: 1,
      );
      final palette = im.Image(
        width: 4,
        height: 4,
        withPalette: true,
        numChannels: 3,
      );
      final deep = im.Image(width: 4, height: 4, format: im.Format.uint16);

      final sources = <String, String>{
        'RGBA png': dataUri(im.encodePng(rgba)),
        'RGB png': dataUri(im.encodePng(rgb)),
        'grayscale png': dataUri(im.encodePng(gray)),
        'palette png': dataUri(im.encodePng(palette)),
        '16-bit png': dataUri(im.encodePng(deep)),
        'jpeg': dataUri(im.encodeJpg(rgb, quality: 60), type: 'image/jpeg'),
      };

      for (final entry in sources.entries) {
        late String pdf;
        expect(
          () async => pdf = await render(svgWith(entry.value)),
          returnsNormally,
          reason: entry.key,
        );
        pdf = await render(svgWith(entry.value));

        expect(imagesDrawn(pdf), 1, reason: entry.key);
      }
    });

    test('keeps its pixels in order', () async {
      // An equal-length buffer with a different layout gave the right size and
      // the wrong colours.
      final pdf = await render(svgWith(dataUri(im.encodePng(redBlue()))));
      final stream = RegExp(
        r'/Subtype/Image.*?stream\s(.*?)\sendstream',
        dotAll: true,
      ).firstMatch(pdf)!.group(1)!;

      // Two pixels, red then blue, in whatever filter the image used.
      expect(stream, isNotEmpty);
      expect(pdf, contains('/Width 2'));
      expect(pdf, contains('/Height 1'));
    });

    test('of a JPEG keeps DCT encoding', () async {
      final jpeg = im.encodeJpg(
        im.Image(width: 8, height: 8, numChannels: 3),
        quality: 60,
      );
      final pdf = await render(svgWith(dataUri(jpeg, type: 'image/jpeg')));

      expect(pdf, contains('/DCTDecode'));
      expect(pdf, isNot(contains('/SMask')));
    });

    test('with extra header parameters is still read', () async {
      // Only the part right after the first ';' used to be looked at, so a
      // charset parameter made the whole image disappear.
      final png = im.encodePng(im.Image(width: 4, height: 4));
      final pdf = await render(
        svgWith('data:image/png;charset=utf-8;base64,${base64.encode(png)}'),
      );

      expect(imagesDrawn(pdf), 1);
    });
  });

  group('an unusable <image>', () {
    final broken = <String, String>{
      'a nested svg payload': 'data:image/svg+xml;base64,PHN2Zy8+',
      'an empty payload': 'data:image/png;base64,',
      'a truncated png': dataUri(
        im.encodePng(im.Image(width: 4, height: 4)).sublist(0, 20),
      ),
      'malformed base64': 'data:image/png;base64,!!!not base64!!!',
      'no comma at all': 'data:image/png;base64',
      'a plain url': 'https://example.com/logo.png',
    };

    broken.forEach((String name, String href) {
      test('with $name costs only that element', () async {
        // The block was unguarded, and package:image throws before it can return
        // null, so one bad sub-resource aborted the whole document with
        // 'Null check operator used on a null value' or a RangeError.
        late String pdf;
        expect(
          () async => pdf = await render(svgWith(href)),
          returnsNormally,
          reason: name,
        );
        pdf = await render(svgWith(href));

        expect(imagesDrawn(pdf), 0, reason: name);

        // And the sibling rectangle is still drawn.
        expect(pdf, contains('0 1 0 rg'), reason: name);
        expect(pdf, contains(' f '), reason: name);
      });
    });
  });

  test('a raw PdfImage says so when its buffer is too short', () {
    expect(
      () => PdfImage(
        PdfDocument(),
        image: Uint8List(4 * 4 * 4 - 1),
        width: 4,
        height: 4,
      ),
      throwsA(isA<AssertionError>()),
    );

    expect(
      () => PdfImage(
        PdfDocument(),
        image: Uint8List(4 * 4 * 4),
        width: 4,
        height: 4,
      ),
      returnsNormally,
    );
  });
}
