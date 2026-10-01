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

import 'package:image/image.dart' as im;
import 'package:pdf/pdf.dart';
import 'package:pdf/src/priv.dart';
import 'package:pdf/widgets.dart'
    as pw
    show
        BoxConstraints,
        BoxFit,
        ConstrainedBox,
        Container,
        Document,
        Image,
        Page,
        RawImage,
        SizedBox,
        Widget;
import 'package:pdf/widgets.dart'
    show Context, ImageImage, ImageProvider, MemoryImage;
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

  test('MemoryImage with dpi does not upscale a JPEG image', () async {
    final jpg = im.encodeJpg(im.Image(width: 100, height: 50));

    final pdf = PdfDocument();
    final provider = MemoryImage(jpg);

    // 1 x 0.5 inch at 300 dpi requests 300x150, larger than the 100x50
    // source: the original image must be embedded unchanged.
    final image = provider.resolve(
      Context(document: pdf),
      const PdfPoint(1 * PdfPageFormat.inch, 0.5 * PdfPageFormat.inch),
      dpi: 300,
    );

    expect(image.params['/Width'], const PdfNum(100));
    expect(image.params['/Height'], const PdfNum(50));
    expect(image.params['/Filter'], const PdfName('/DCTDecode'));
  });

  test(
    'MemoryImage with dpi keeps JPEG compression when downsampling',
    () async {
      final jpg = im.encodeJpg(im.Image(width: 400, height: 200));

      final pdf = PdfDocument();
      final provider = MemoryImage(jpg);

      // 1 x 0.5 inch at 300 dpi requests 300x150, smaller than the 400x200
      // source: the image is resampled but must stay DCT (JPEG) encoded.
      final image = provider.resolve(
        Context(document: pdf),
        const PdfPoint(1 * PdfPageFormat.inch, 0.5 * PdfPageFormat.inch),
        dpi: 300,
      );

      expect(image.params['/Width'], const PdfNum(300));
      expect(image.params['/Height'], const PdfNum(150));
      expect(image.params['/Filter'], const PdfName('/DCTDecode'));
    },
  );

  test('MemoryImage keeps downsampling after an at-source resolve', () async {
    final jpg = im.encodeJpg(im.Image(width: 400, height: 200));

    final pdf = PdfDocument();
    final provider = MemoryImage(jpg);

    // 2 x 1 inch at 300 dpi requests 600x300, above the 400x200 source:
    // the original image is embedded.
    final large = provider.resolve(
      Context(document: pdf),
      const PdfPoint(2 * PdfPageFormat.inch, 1 * PdfPageFormat.inch),
      dpi: 300,
    );
    expect(large.params['/Width'], const PdfNum(400));

    // A later, smaller placement of the same provider must still be
    // downsampled: 1 x 0.5 inch at 150 dpi requests 150x75.
    final small = provider.resolve(
      Context(document: pdf),
      const PdfPoint(1 * PdfPageFormat.inch, 0.5 * PdfPageFormat.inch),
      dpi: 150,
    );
    expect(small.params['/Width'], const PdfNum(150));
  });

  test('MemoryImage strips EXIF metadata when downsampling a JPEG', () async {
    final src = im.Image(width: 400, height: 200);
    src.exif.imageIfd['Make'] = 'TestCam';
    final jpg = im.encodeJpg(src);
    expect(im.decodeJpg(jpg)!.exif.isEmpty, isFalse);

    final pdf = PdfDocument();
    final provider = MemoryImage(jpg);

    // 1 x 0.5 inch at 300 dpi requests 300x150, smaller than the 400x200
    // source: the image is re-encoded and must not carry the source EXIF
    // (GPS position, device serial numbers, ...) into the document.
    final image = provider.resolve(
      Context(document: pdf),
      const PdfPoint(1 * PdfPageFormat.inch, 0.5 * PdfPageFormat.inch),
      dpi: 300,
    );

    expect(image.params['/Width'], const PdfNum(300));
    expect(im.decodeJpg(image.buf.output())!.exif.isEmpty, isTrue);
  });

  test('rotated ImageImage is never upscaled past its pixel width', () async {
    final raw = im.Image(width: 50, height: 200);

    final pdf = PdfDocument();
    final provider = ImageImage(raw, orientation: PdfImageOrientation.rightTop);

    // Shown 1 inch wide at 100 dpi the display width targets 100 pixels,
    // which the orientation-swapped metadata (200) would allow, but the
    // raw buffer is only 50 pixels wide: resampling could only upscale,
    // so the original pixels must be embedded.
    final image = provider.resolve(
      Context(document: pdf),
      const PdfPoint(1 * PdfPageFormat.inch, 4 * PdfPageFormat.inch),
      dpi: 100,
    );

    expect(image.params['/Width'], const PdfNum(50));
    expect(image.params['/Height'], const PdfNum(200));
  });

  test('degenerate zero target width keeps the original image', () async {
    final jpg = im.encodeJpg(im.Image(width: 400, height: 200));

    final pdf = PdfDocument();
    final provider = MemoryImage(jpg);

    // A sub-pixel box computes a target width of 0, which must not be
    // resampled — and must not poison the cache slot of the original.
    final tiny = provider.resolve(
      Context(document: pdf),
      const PdfPoint(0.3, 0.3),
      dpi: 72,
    );
    expect(tiny.params['/Width'], const PdfNum(400));

    final original = provider.resolve(Context(document: pdf), PdfPoint.zero);
    expect(original.params['/Width'], const PdfNum(400));
  });

  test('unknown source width requests the original image', () async {
    final pdf = PdfDocument();
    final provider = _UnknownWidthImage();

    // With no source width there is no way to tell whether resampling
    // would upscale: the original image must be requested.
    provider.resolve(
      Context(document: pdf),
      const PdfPoint(8 * PdfPageFormat.inch, 8 * PdfPageFormat.inch),
      dpi: 300,
    );

    expect(provider.lastRequestedWidth, isNull);
  });

  group('an Image widget', () {
    /// A solid [width] x [height] bitmap.
    ImageProvider bitmap(int width, int height) => pw.RawImage(
      bytes: Uint32List(width * height).buffer.asUint8List(),
      width: width,
      height: height,
    );

    /// Lay [child] out on a page and hand back the widget.
    Future<T> layOut<T extends pw.Widget>(T Function() child) async {
      late T widget;
      final document = pw.Document();
      document.addPage(
        pw.Page(
          pageFormat: const PdfPageFormat(400, 300, marginAll: 0),
          build: (Context context) => widget = child(),
        ),
      );
      await document.save();
      return widget;
    }

    test('an explicit width is clamped by a tight parent', () async {
      // An explicit size was used verbatim, so the box could come out bigger than
      // the slot: inside a 100x100 container this measured 200x100.
      final image = await layOut(() => pw.Image(bitmap(100, 50), width: 400));
      expect(image.box!.width, 400, reason: 'unconstrained, it is 400 wide');

      late pw.Image inside;
      await layOut(
        () => pw.Container(
          width: 100,
          height: 100,
          child: inside = pw.Image(bitmap(100, 50), width: 400),
        ),
      );

      expect(inside.box!.width, 100);
      expect(inside.box!.height, 50, reason: 'the aspect ratio is kept');
    });

    test('never exceeds its constraints, for any fit', () async {
      for (final fit in pw.BoxFit.values) {
        for (final entry in <String, pw.BoxConstraints>{
          'tight': const pw.BoxConstraints.tightFor(width: 80, height: 40),
          'loose': const pw.BoxConstraints(maxWidth: 80, maxHeight: 40),
          'unbounded': const pw.BoxConstraints(),
        }.entries) {
          late pw.Image image;
          await layOut(
            () => pw.ConstrainedBox(
              constraints: entry.value,
              child: image = pw.Image(
                bitmap(100, 50),
                fit: fit,
                width: 400,
                height: 400,
              ),
            ),
          );

          final label = '$fit under ${entry.key} constraints';
          expect(
            image.box!.width,
            lessThanOrEqualTo(entry.value.maxWidth),
            reason: label,
          );
          expect(
            image.box!.height,
            lessThanOrEqualTo(entry.value.maxHeight),
            reason: label,
          );
        }
      }
    });

    test('a zero-sized slot draws nothing rather than NaN', () async {
      // applyBoxFit returns a zero-sized source for a degenerate destination and
      // the scale divided by it: save() threw '!value.isNaN' out of PdfNum with
      // asserts on and wrote the token in release.
      final document = pw.Document(compress: false);
      document.addPage(
        pw.Page(
          pageFormat: const PdfPageFormat(400, 300, marginAll: 0),
          build: (Context context) => pw.Container(
            width: 0,
            height: 100,
            child: pw.Image(bitmap(10, 10)),
          ),
        ),
      );

      final pdf = String.fromCharCodes(await document.save());
      expect(pdf, isNot(contains('NaN')));
      expect(pdf, isNot(contains('Infinity')));
    });
  });
  group('an orientation asked of a provider', () {
    /// A 50x200 PNG, so a rotated orientation is visible in the dimensions.
    final png = Uint8List.fromList(
      im.encodePng(im.Image(width: 50, height: 200)),
    );

    /// The same shape as a JPEG, with no EXIF orientation of its own.
    final jpg = Uint8List.fromList(
      im.encodeJpg(im.Image(width: 50, height: 200), quality: 40),
    );

    /// Resolve [provider] in a one-page document and hand back the PdfImage.
    Future<PdfImage> resolve(
      ImageProvider provider, {
      double? dpi,
      double size = 400,
    }) async {
      late PdfImage image;
      final document = pw.Document();
      document.addPage(
        pw.Page(
          pageFormat: const PdfPageFormat(400, 400, marginAll: 0),
          build: (Context context) {
            image = provider.resolve(context, PdfPoint(size, size), dpi: dpi);
            return pw.SizedBox();
          },
        ),
      );
      await document.save();
      return image;
    }

    test('reaches the PdfImage, for every provider and orientation', () async {
      // ImageProvider stores the orientation and swaps the dimensions it
      // reports, but no buildImage forwarded it: six call sites built a PdfImage
      // without it. The image drew unrotated and, because the box had been sized
      // for the rotated one, shrunk inside it.
      for (final orientation in PdfImageOrientation.values) {
        final providers = <String, ImageProvider>{
          'MemoryImage(png)': MemoryImage(png, orientation: orientation),
          'MemoryImage(jpg)': MemoryImage(jpg, orientation: orientation),
          'ImageImage': ImageImage(
            im.Image(width: 50, height: 200),
            orientation: orientation,
          ),
          'RawImage': pw.RawImage(
            bytes: createTestImage(50, 200),
            width: 50,
            height: 200,
            orientation: orientation,
          ),
        };

        for (final entry in providers.entries) {
          final image = await resolve(entry.value);
          final what = '${entry.key}, $orientation';

          expect(image.orientation, orientation, reason: what);
          expect(image.width, entry.value.width, reason: what);
          expect(image.height, entry.value.height, reason: what);
        }
      }
    });

    test('survives the resample path', () async {
      // Forcing a dpi low enough to downsample takes buildImage's other branch.
      for (final orientation in PdfImageOrientation.values) {
        final providers = <String, ImageProvider>{
          'MemoryImage(png)': MemoryImage(png, orientation: orientation),
          'MemoryImage(jpg)': MemoryImage(jpg, orientation: orientation),
          'ImageImage': ImageImage(
            im.Image(width: 50, height: 200),
            orientation: orientation,
          ),
        };

        for (final entry in providers.entries) {
          final image = await resolve(entry.value, dpi: 4);
          final what = '${entry.key}, $orientation, resampled';

          expect(image.orientation, orientation, reason: what);
        }
      }
    });

    test('is the file\'s own when none is given', () async {
      // A null orientation means the file decides, which is how an EXIF
      // orientation has always reached the provider - it just never reached the
      // image.
      final oriented = _jpegWithOrientation(6);

      expect(MemoryImage(oriented).orientation, PdfImageOrientation.rightTop);
      expect(
        (await resolve(MemoryImage(oriented))).orientation,
        PdfImageOrientation.rightTop,
      );
    });

    test('is not applied twice when the pixels already carry it', () async {
      // im.decodeImage bakes a source EXIF orientation into the pixels it
      // returns, so the resampled image must not be rotated again.
      final oriented = _jpegWithOrientation(6);
      final image = await resolve(MemoryImage(oriented), dpi: 4);

      expect(image.orientation, PdfImageOrientation.topLeft);
    });

    test('reaches PdfImage.file for PNG and for JPEG bytes', () {
      // PdfImage.file dropped it entirely for JPEG bytes, delegating to
      // PdfImage.jpeg without the argument.
      for (final bytes in <Uint8List>[png, jpg]) {
        final image = PdfImage.file(
          PdfDocument(),
          bytes: bytes,
          orientation: PdfImageOrientation.rightTop,
        );

        expect(image.orientation, PdfImageOrientation.rightTop);
      }
    });

    test('leaves a JPEG\'s EXIF orientation alone when not given', () {
      final image = PdfImage.file(
        PdfDocument(),
        bytes: _jpegWithOrientation(6),
      );

      expect(image.orientation, PdfImageOrientation.rightTop);
    });

    test('rotates the image over its whole layout box', () async {
      // The box is sized for the rotated image, so the matrix has to fill it.
      final document = pw.Document(compress: false);
      document.addPage(
        pw.Page(
          pageFormat: const PdfPageFormat(400, 400, marginAll: 0),
          build: (Context context) => pw.Image(
            MemoryImage(png, orientation: PdfImageOrientation.rightTop),
          ),
        ),
      );
      final pdf = String.fromCharCodes(await document.save());

      // ignore: avoid_print
      print(
        RegExp(
          r'[-\d.]+ [-\d.]+ [-\d.]+ [-\d.]+ [-\d.]+ [-\d.]+ cm /I\d+ Do',
        ).allMatches(pdf).map((m) => m.group(0)).toList().toString(),
      );
      expect(pdf, contains('0 -100 400 0 0 400 cm'));
    });
  });
}

/// A decodable JPEG carrying [value] as its EXIF Orientation.
Uint8List _jpegWithOrientation(int value) {
  final encoded = im.encodeJpg(im.Image(width: 50, height: 200), quality: 40);

  void u16(List<int> to, int v) => to.addAll(<int>[(v >> 8) & 0xff, v & 0xff]);
  void u32(List<int> to, int v) => to.addAll(<int>[
    (v >> 24) & 0xff,
    (v >> 16) & 0xff,
    (v >> 8) & 0xff,
    v & 0xff,
  ]);

  final tiff = <int>[0x4d, 0x4d, 0x00, 0x2a];
  u32(tiff, 8);

  final ifd = <int>[];
  u16(ifd, 1);
  u16(ifd, 0x0112); // Orientation
  u16(ifd, 3); // SHORT
  u32(ifd, 1);
  ifd.addAll(<int>[0x00, value, 0, 0]);
  u32(ifd, 0);

  final payload = <int>[0x45, 0x78, 0x69, 0x66, 0, 0, ...tiff, ...ifd];
  final segment = <int>[0xff, 0xe1];
  u16(segment, payload.length + 2);

  return Uint8List.fromList(<int>[
    encoded[0],
    encoded[1],
    ...segment,
    ...payload,
    ...encoded.sublist(2),
  ]);
}

class _UnknownWidthImage extends ImageProvider {
  _UnknownWidthImage() : super(null, 200, PdfImageOrientation.topLeft, null);

  int? lastRequestedWidth;

  @override
  PdfImage buildImage(Context context, {int? width, int? height}) {
    lastRequestedWidth = width;
    return PdfImage.fromImage(
      context.document,
      image: im.Image(width: 10, height: 10),
    );
  }
}
