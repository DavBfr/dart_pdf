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
import 'package:meta/meta.dart';

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

  /// One cache per document, held weakly, so the images and the document they
  /// belong to die together.
  ///
  /// This used to be an unbounded map on the provider itself, keyed only by the
  /// pixel width: a long-lived provider kept one PdfImage per distinct layout
  /// width for ever, and a PdfImage holds its PdfDocument, which holds every
  /// page, font and content stream in it. A service reusing one provider leaked
  /// roughly a finished document per width.
  static final _caches = Expando<Map<int, PdfImage>>('PdfImage cache');

  Map<int, PdfImage> _cacheFor(PdfDocument document) =>
      _caches[document] ??= <int, PdfImage>{};

  /// How many images this provider has cached for [document].
  @visibleForTesting
  int debugCacheLength(PdfDocument document) => _caches[document]?.length ?? 0;

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
        final cache = _cacheFor(context.document);
        final image = cache[width] ??= buildImage(
          context,
          width: width,
          height: height,
        );

        assert(
          identical(image.pdfDocument, context.document),
          'buildImage returned an image belonging to another document. A '
          'provider has to build against the context it is given.',
        );
        return image;
      }
    }

    final cache = _cacheFor(context.document);
    final image = cache[0] ??= buildImage(context);

    assert(
      identical(image.pdfDocument, context.document),
      'buildImage returned an image belonging to another document. A provider '
      'has to build against the context it is given.',
    );
    return image;
  }
}

class ImageProxy extends ImageProvider {
  ImageProxy(this._image, {double? dpi})
    : super(_image.width, _image.height, _image.orientation, dpi);

  /// The proxy image
  final PdfImage _image;

  @override
  PdfImage buildImage(Context context, {int? width, int? height}) {
    // An ImageProxy wraps an image that already belongs to a document, and
    // resolve() used to answer a mismatch by calling buildImage again - which
    // hands back the same foreign image. Nothing downstream checks ownership, so
    // document A's object number landed in document B's /XObject dictionary and
    // the viewer drew nothing, or an unrelated object, with no error at all.
    if (!identical(_image.pdfDocument, context.document)) {
      throw PdfException(
        'This PdfImage belongs to another PdfDocument and cannot be drawn in '
        'this one. Build the image against this document, or use MemoryImage '
        'or RawImage, which build one per document.',
      );
    }

    return _image;
  }
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
        requested: orientation,
        exifOriented: info.orientation != PdfImageOrientation.topLeft,
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
      requested: orientation,
    );
  }

  MemoryImage._(
    this.bytes,
    int? width,
    int height,
    PdfImageOrientation orientation,
    double? dpi, {
    PdfImageOrientation? requested,
    bool exifOriented = false,
  }) : _requested = requested,
       _exifOriented = exifOriented,
       super(width, height, orientation, dpi);

  /// The image data
  final Uint8List bytes;

  /// What the caller asked for, as opposed to what the file declares. Null means
  /// the file decides.
  final PdfImageOrientation? _requested;

  /// Whether the source carries an EXIF orientation, which im.decodeImage bakes
  /// into the pixels it returns.
  final bool _exifOriented;

  @override
  PdfImage buildImage(Context context, {int? width, int? height}) {
    if (width == null) {
      // A null orientation means the file decides, which is what the provider
      // reported; a non-null one is the caller overriding it. Neither used to be
      // forwarded at all, so an oriented provider swapped the dimensions it
      // reported and then built an unrotated image to fill them.
      return PdfImage.file(
        context.document,
        bytes: bytes,
        orientation: _requested,
      );
    }

    final image = im.decodeImage(bytes);

    if (image == null) {
      throw PdfException('Unable decode the image');
    }

    // The decoded (orientation-baked) pixels are the ground truth for the
    // no-upscale rule: for rotated images the metadata bound checked by
    // resolve() cannot know which axis copyResize will scale.
    if (width >= image.width) {
      return PdfImage.file(
        context.document,
        bytes: bytes,
        orientation: _requested,
      );
    }

    final resized = im.copyResize(image, width: width);

    // im.decodeImage applies a source EXIF orientation to the pixels it returns -
    // a 16x8 image with orientation 6 comes back 8x16 - so asking the PDF to
    // rotate them again would turn the image twice.
    final remaining = _exifOriented ? null : _requested;

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
        orientation: remaining,
      );
    }

    return PdfImage.fromImage(
      context.document,
      image: resized,
      orientation: remaining ?? PdfImageOrientation.topLeft,
    );
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
      return PdfImage.fromImage(
        context.document,
        image: _image,
        orientation: orientation,
      );
    }

    final resized = im.copyResize(_image, width: width);
    return PdfImage.fromImage(
      context.document,
      image: resized,
      orientation: orientation,
    );
  }
}

/// An image from a raw pixel buffer.
///
/// [bytes] is `width * height` pixels of 8-bit RGBA with **straight, not
/// premultiplied, alpha** - see [PdfImage.new].
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
