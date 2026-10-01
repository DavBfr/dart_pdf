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

import '../../../pdf.dart' show PdfException;
import '../document.dart';
import '../exif.dart';
import '../format/array.dart';
import '../format/indirect.dart';
import '../format/name.dart';
import '../format/num.dart';
import '../format/stream.dart';
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

/// Writes already encoded image bytes to a PDF output stream.
typedef PdfImageStreamWriter = void Function(PdfStream output);

/// Image object stored in the Pdf document
class PdfImage extends PdfXObject {
  /// Creates a new [PdfImage] instance.
  /// Embed a raw pixel buffer.
  ///
  /// [image] is `width * height` pixels of 8-bit RGB, or RGBA when [alpha] is
  /// set. **The alpha is straight, not premultiplied**: the colour bytes go to a
  /// `/DeviceRGB` stream and the alpha byte to a `/DeviceGray` `/SMask`, and
  /// ISO 32000-1 11.6.5.2 defines that pair as straight alpha. A premultiplied
  /// buffer - which is what `dart:ui` hands back by default - is composited as
  /// `Cs*a^2 + Cb*(1-a)`, so translucent pixels come out too dark.
  ///
  /// [width] and [height] describe [image] itself, not how it is displayed:
  /// `image.length` must be `width * height * (alpha ? 4 : 3)`. A rotated
  /// [orientation] changes where the pixels are drawn, never how they are read.
  factory PdfImage(
    PdfDocument pdfDocument, {
    required Uint8List image,
    required int width,
    required int height,
    bool alpha = true,
    PdfImageOrientation orientation = PdfImageOrientation.topLeft,
  }) {
    final im = PdfImage._(pdfDocument, width, height, orientation);

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
    if (alpha) {
      for (var i = 0; i < s; i++) {
        out[i * 3] = image[i * 4];
        out[i * 3 + 1] = image[i * 4 + 1];
        out[i * 3 + 2] = image[i * 4 + 2];
      }
    } else {
      for (var i = 0; i < s; i++) {
        out[i * 3] = image[i * 3];
        out[i * 3 + 1] = image[i * 3 + 1];
        out[i * 3 + 2] = image[i * 3 + 2];
      }
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
    bool? cmykInverted,
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

    if (info.isCMYK) {
      im.params['/ColorSpace'] = const PdfName('/DeviceCMYK');
      if (cmykInverted ?? info.isCMYKInverted) {
        // A CMYK JPEG written by Adobe stores its samples inverted, whatever its
        // APP14 transform byte says. The /Decode array inverts each component
        // back. cmykInverted is the override for the rare four-component file
        // that carries no Adobe marker but is inverted anyway, or the reverse.
        im.params['/Decode'] = PdfArray.fromNum(<int>[1, 0, 1, 0, 1, 0, 1, 0]);
      }
    } else if (info.isRGB) {
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

  /// Creates a JPEG image whose encoded bytes are supplied only when the PDF
  /// is serialized. This avoids retaining a copy of the JPEG in the document
  /// object graph.
  ///
  /// The supplied bytes must be an RGB JPEG with the stated dimensions. The
  /// callback is synchronous because PDF object serialization is synchronous.
  /// Streamed JPEGs cannot be used with document encryption because encryption
  /// requires the complete stream contents to be available as a byte array.
  factory PdfImage.jpegStream(
    PdfDocument pdfDocument, {
    required int width,
    required int height,
    required int length,
    required PdfImageStreamWriter write,
    PdfImageOrientation orientation = PdfImageOrientation.topLeft,
  }) {
    final image = PdfImage._(
      pdfDocument,
      width,
      height,
      orientation,
      streamLength: length,
      streamWriter: write,
    );
    image.params['/BitsPerComponent'] = const PdfNum(8);
    image.params['/Name'] = PdfName(image.name);
    image.params['/Intent'] = const PdfName('/RelativeColorimetric');
    image.params['/Filter'] = const PdfName('/DCTDecode');
    image.params['/ColorSpace'] = const PdfName('/DeviceRGB');
    return image;
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
  /// Load an image from a file's bytes.
  ///
  /// A null [orientation] means use the orientation the file itself declares -
  /// a JPEG's EXIF tag - and fall back to [PdfImageOrientation.topLeft]. The
  /// orientation used to be dropped entirely for JPEG bytes.
  factory PdfImage.file(
    PdfDocument pdfDocument, {
    required Uint8List bytes,
    PdfImageOrientation? orientation,
  }) {
    if (im.JpegDecoder().isValidFile(bytes)) {
      return PdfImage.jpeg(pdfDocument, image: bytes, orientation: orientation);
    }

    final image = im.decodeImage(bytes);
    if (image == null) {
      throw PdfException('Unable to decode image');
    }
    return PdfImage.fromImage(
      pdfDocument,
      image: image,
      orientation: orientation ?? PdfImageOrientation.topLeft,
    );
  }

  factory PdfImage._alpha(
    PdfDocument pdfDocument,
    Uint8List image,
    int width,
    int height,
    PdfImageOrientation orientation,
  ) {
    final im = PdfImage._(pdfDocument, width, height, orientation);

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
    this.orientation, {
    int? streamLength,
    PdfImageStreamWriter? streamWriter,
  }) : _streamLength = streamLength,
       _streamWriter = streamWriter,
       super(pdfDocument, '/Image', isBinary: true) {
    params['/Width'] = PdfNum(_width);
    params['/Height'] = PdfNum(_height);
    assert(() {
      debugFill('Orientation: $orientation');
      return true;
    }());
  }

  final int _width;

  final int? _streamLength;

  final PdfImageStreamWriter? _streamWriter;

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

  @override
  void writeContent(PdfStream s) {
    final writer = _streamWriter;
    if (writer == null) {
      super.writeContent(s);
      return;
    }
    if (pdfDocument.encryption != null) {
      throw UnsupportedError(
        'PdfImage.jpegStream does not support encrypted documents',
      );
    }

    params['/Length'] = PdfNum(_streamLength!);
    params.output(this, s, settings.verbose ? 0 : null);
    if (settings.verbose) {
      s.putByte(0x0a);
    }
    s.putString('stream\n');
    final start = s.offset;
    writer(s);
    final bytesWritten = s.offset - start;
    if (bytesWritten != _streamLength) {
      throw StateError(
        'JPEG stream wrote $bytesWritten bytes; expected $_streamLength',
      );
    }
    s.putString('\nendstream\n');
  }
}
