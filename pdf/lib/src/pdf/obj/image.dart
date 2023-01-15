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

import '../data_types.dart';
import '../document.dart';
import '../exif.dart';
import '../raster.dart';
import 'xobject.dart';

/// Represents the position of the first pixel in the data stream
/// This corresponds to the exif orientations
enum PdfImageOrientation {
  /// Rotated 0°
  topLeft,

  /// Rotated 90°
  topRight,

  /// Rotated 180°
  bottomRight,

  /// Rotated 270°
  bottomLeft,

  /// Rotated 0° mirror
  leftTop,

  /// Rotated 90° mirror
  rightTop,

  /// Rotated 180° mirror
  rightBottom,

  /// Rotated 270° mirror
  leftBottom,
}

/// Image object stored in the Pdf document
class PdfImage extends PdfXObject {
  /// Creates a new [PdfImage] instance.
  factory PdfImage(
    PdfDocument pdfDocument, {
    required Uint8List image,
    required int width,
    required int height,
    bool alpha = true,
    PdfImageOrientation orientation = PdfImageOrientation.topLeft,
  }) {
    final im = PdfImage._(
      pdfDocument,
      width,
      height,
      orientation,
    );

    assert(() {
      im.startStopwatch();
      im.debugFill('RAW RGB${alpha ? 'A' : ''} Image ${width}x$height');
      return true;
    }());

    im.params['/BitsPerComponent'] = const PdfNum(8);
    im.params['/Name'] = PdfName(im.name);
    im.params['/ColorSpace'] = const PdfName('/DeviceRGB');

    if (alpha) {
      final _sMask = PdfImage._alpha(
        pdfDocument,
        image,
        width,
        height,
        orientation,
      );
      im.params['/SMask'] = PdfIndirect(_sMask.objser, 0);
    }

    final w = width;
    final h = height;
    final s = w * h;
    final out = Uint8List(s * 3);
    for (var i = 0; i < s; i++) {
      out[i * 3] = image[i * 4];
      out[i * 3 + 1] = image[i * 4 + 1];
      out[i * 3 + 2] = image[i * 4 + 2];
    }

    im.buf.putBytes(out);
    assert(() {
      im.stopStopwatch();
      return true;
    }());
    return im;
  }

  /// Create an image from a jpeg file
  factory PdfImage.jpeg(
    PdfDocument pdfDocument, {
    required Uint8List image,
    PdfImageOrientation? orientation,
  }) {
    final info = PdfJpegInfo(image);
    final im = PdfImage._(
      pdfDocument,
      info.width!,
      info.height,
      orientation ?? info.orientation,
    );

    assert(() {
      im.startStopwatch();
      im.debugFill('Jpeg Image ${info.width}x${info.height}');
      return true;
    }());
    im.params['/BitsPerComponent'] = const PdfNum(8);
    im.params['/Name'] = PdfName(im.name);
    im.params['/Intent'] = const PdfName('/RelativeColorimetric');
    im.params['/Filter'] = const PdfName('/DCTDecode');

    if (info.isRGB) {
      im.params['/ColorSpace'] = const PdfName('/DeviceRGB');
    } else {
      im.params['/ColorSpace'] = const PdfName('/DeviceGray');
    }

    im.buf.putBytes(image);
    assert(() {
      im.stopStopwatch();
      return true;
    }());
    return im;
  }

  /// Create an image from an [im.Image] object
  factory PdfImage.fromImage(
    PdfDocument pdfDocument, {
    required im.Image image,
    PdfImageOrientation orientation = PdfImageOrientation.topLeft,
  }) {
    final raster = PdfRasterBase.fromImage(image);
    return PdfImage(
      pdfDocument,
      image: raster.pixels,
      width: raster.width,
      height: raster.height,
      alpha: raster.alpha,
      orientation: orientation,
    );
  }

  /// Create an image from an image file
  factory PdfImage.file(
    PdfDocument pdfDocument, {
    required Uint8List bytes,
    PdfImageOrientation orientation = PdfImageOrientation.topLeft,
  }) {
    if (im.JpegDecoder().isValidFile(bytes)) {
      return PdfImage.jpeg(pdfDocument, image: bytes);
    }

    final image = im.decodeImage(bytes);
    if (image == null) {
      throw 'Unable to decode image';
    }
    return PdfImage.fromImage(
      pdfDocument,
      image: image,
      orientation: orientation,
    );
  }

  factory PdfImage._alpha(
    PdfDocument pdfDocument,
    Uint8List image,
    int width,
    int height,
    PdfImageOrientation orientation,
  ) {
    final im = PdfImage._(
      pdfDocument,
      width,
      height,
      orientation,
    );

    assert(() {
      im.startStopwatch();
      im.debugFill('Image alpha channel ${width}x$height');
      return true;
    }());
    im.params['/BitsPerComponent'] = const PdfNum(8);
    im.params['/Name'] = PdfName(im.name);
    im.params['/ColorSpace'] = const PdfName('/DeviceGray');

    final w = width;
    final h = height;
    final s = w * h;

    final out = Uint8List(s);

    for (var i = 0; i < s; i++) {
      out[i] = image[i * 4 + 3];
    }

    im.buf.putBytes(out);
    assert(() {
      im.stopStopwatch();
      return true;
    }());
    return im;
  }

  PdfImage._(
    PdfDocument pdfDocument,
    this._width,
    this._height,
    this.orientation,
  ) : super(pdfDocument, '/Image', isBinary: true) {
    params['/Width'] = PdfNum(_width);
    params['/Height'] = PdfNum(_height);
    assert(() {
      debugFill('Orientation: $orientation');
      return true;
    }());
  }

  final int _width;

  /// Image width
  int get width => orientation.index >= 4 ? _height : _width;

  final int _height;

  /// Image height
  int get height => orientation.index < 4 ? _height : _width;

  /// The internal orientation of the image
  final PdfImageOrientation orientation;

  /// Name of the image
  @override
  String get name => '/I$objser';
}
