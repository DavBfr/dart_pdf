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

import '../../pdf.dart';
import 'widget.dart';

/// Identifies an image without committing to the precise final asset
abstract class ImageProvider {
  ImageProvider(this._width, this._height, this.orientation, this.dpi);

  final double? dpi;

  final int? _width;

  /// Image width
  int? get width => orientation.index >= 4 ? _height : _width;

  final int _height;

  /// Image height
  int? get height => orientation.index < 4 ? _height : _width;

  /// The internal orientation of the image
  final PdfImageOrientation orientation;

  final _cache = <int, PdfImage>{};

  PdfImage buildImage(Context context, {int? width, int? height});

  /// Resolves this image provider using the given context, returning a PdfImage
  /// The image is automatically added to the document
  PdfImage resolve(Context context, PdfPoint size, {double? dpi}) {
    final effectiveDpi = dpi ?? this.dpi;

    if (effectiveDpi != null) {
      final width = (size.x / PdfPageFormat.inch * effectiveDpi).toInt();
      final height = (size.y / PdfPageFormat.inch * effectiveDpi).toInt();

      // Never resample above the source resolution: upscaling adds no detail
      // but discards the original (possibly better compressed) image data.
      // For rotated orientations the axis buildImage resizes depends on
      // whether decoding bakes the rotation into the pixels, so only an
      // upper bound is checked here; buildImage itself skips the resample
      // when the target is at or above the decoded pixel width. An unknown
      // source width keeps the original: it cannot be proven a downsample.
      final sourceWidth = _width;
      final resampleBound = sourceWidth == null
          ? null
          : orientation.index >= 4
          ? (sourceWidth > _height ? sourceWidth : _height)
          : sourceWidth;

      if (resampleBound != null && width > 0 && width < resampleBound) {
        if (!_cache.containsKey(width)) {
          _cache[width] ??= buildImage(context, width: width, height: height);
        }

        if (_cache[width]!.pdfDocument != context.document) {
          _cache[width] = buildImage(context, width: width, height: height);
        }

        return _cache[width]!;
      }
    }

    _cache[0] ??= buildImage(context);

    if (_cache[0]!.pdfDocument != context.document) {
      _cache[0] = buildImage(context);
    }

    return _cache[0]!;
  }
}

class ImageProxy extends ImageProvider {
  ImageProxy(this._image, {double? dpi})
    : super(_image.width, _image.height, _image.orientation, dpi);

  /// The proxy image
  final PdfImage _image;

  @override
  PdfImage buildImage(Context context, {int? width, int? height}) => _image;
}

class MemoryImage extends ImageProvider {
  factory MemoryImage(
    Uint8List bytes, {
    PdfImageOrientation? orientation,
    double? dpi,
  }) {
    final decoder = im.findDecoderForData(bytes);
    if (decoder == null) {
      throw PdfException(
        'Unable to guess the image type ${bytes.length} bytes',
      );
    }

    if (decoder is im.JpegDecoder) {
      final info = PdfJpegInfo(bytes);

      return MemoryImage._(
        bytes,
        info.width,
        info.height,
        orientation ?? info.orientation,
        dpi,
      );
    }

    final info = decoder.startDecode(bytes);

    if (info == null) {
      throw PdfException('Unable decode the image');
    }

    return MemoryImage._(
      bytes,
      info.width,
      info.height,
      orientation ?? PdfImageOrientation.topLeft,
      dpi,
    );
  }

  MemoryImage._(
    this.bytes,
    int? width,
    int height,
    PdfImageOrientation orientation,
    double? dpi,
  ) : super(width, height, orientation, dpi);

  /// The image data
  final Uint8List bytes;

  @override
  PdfImage buildImage(Context context, {int? width, int? height}) {
    if (width == null) {
      return PdfImage.file(context.document, bytes: bytes);
    }

    final image = im.decodeImage(bytes);

    if (image == null) {
      throw PdfException('Unable decode the image');
    }

    // The decoded (orientation-baked) pixels are the ground truth for the
    // no-upscale rule: for rotated images the metadata bound checked by
    // resolve() cannot know which axis copyResize will scale.
    if (width >= image.width) {
      return PdfImage.file(context.document, bytes: bytes);
    }

    final resized = im.copyResize(image, width: width);

    if (im.JpegDecoder().isValidFile(bytes)) {
      // Do not carry the source metadata over: EXIF can hold sensitive data
      // (GPS position, device serial numbers) and its orientation is already
      // baked into the decoded pixels.
      resized.exif = im.ExifData();

      // Keep DCT (JPEG) encoding for resampled JPEG images: embedding the
      // raw pixels with Flate compression would inflate the file size.
      return PdfImage.jpeg(
        context.document,
        image: im.encodeJpg(resized, quality: 90),
      );
    }

    return PdfImage.fromImage(context.document, image: resized);
  }
}

class ImageImage extends ImageProvider {
  ImageImage(this._image, {double? dpi, PdfImageOrientation? orientation})
    : super(
        _image.width,
        _image.height,
        orientation ?? PdfImageOrientation.topLeft,
        dpi,
      );

  /// The image data
  final im.Image _image;

  @override
  PdfImage buildImage(Context context, {int? width, int? height}) {
    // Resampling at or above the pixel width could only upscale: keep the
    // original pixels (see ImageProvider.resolve).
    if (width == null || width >= _image.width) {
      return PdfImage.fromImage(context.document, image: _image);
    }

    final resized = im.copyResize(_image, width: width);
    return PdfImage.fromImage(context.document, image: resized);
  }
}

class RawImage extends ImageImage {
  RawImage({
    required Uint8List bytes,
    required int width,
    required int height,
    PdfImageOrientation? orientation,
    double? dpi,
  }) : super(
         PdfRasterBase(width, height, true, bytes).asImage(),
         orientation: orientation,
         dpi: dpi,
       );
}
