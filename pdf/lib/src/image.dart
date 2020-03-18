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

// ignore_for_file: omit_local_variable_types

part of pdf;

/// Represents the position of the first pixel in the data stream
/// This corresponds to the exif orientations
enum PdfImageOrientation {
  topLeft,
  topRight,
  bottomRight,
  bottomLeft,
  leftTop,
  rightTop,
  rightBottom,
  leftBottom,
}

class PdfImage extends PdfXObject {
  /// Creates a new [PdfImage] instance.
  factory PdfImage(
    PdfDocument pdfDocument, {
    @required Uint8List image,
    @required int width,
    @required int height,
    bool alpha = true,
    PdfImageOrientation orientation = PdfImageOrientation.topLeft,
  }) {
    assert(image != null);

    final PdfImage im = PdfImage._(
      pdfDocument,
      width,
      height,
      orientation,
    );

    im.params['/BitsPerComponent'] = const PdfNum(8);
    im.params['/Name'] = PdfName(im.name);
    im.params['/ColorSpace'] = const PdfName('/DeviceRGB');

    if (alpha) {
      final PdfImage _sMask = PdfImage._alpha(
        pdfDocument,
        image,
        width,
        height,
        orientation,
      );
      im.params['/SMask'] = PdfIndirect(_sMask.objser, 0);
    }

    final int w = width;
    final int h = height;
    final int s = w * h;
    final Uint8List out = Uint8List(s * 3);
    for (int i = 0; i < s; i++) {
      out[i * 3] = image[i * 4];
      out[i * 3 + 1] = image[i * 4 + 1];
      out[i * 3 + 2] = image[i * 4 + 2];
    }

    im.buf.putBytes(out);
    return im;
  }

  factory PdfImage.jpeg(
    PdfDocument pdfDocument, {
    @required Uint8List image,
    PdfImageOrientation orientation,
  }) {
    assert(image != null);

    final PdfJpegInfo info = PdfJpegInfo(image);
    final PdfImage im = PdfImage._(
      pdfDocument,
      info.width,
      info.height,
      orientation ?? info.orientation,
    );

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
    return im;
  }

  factory PdfImage.fromImage(
    PdfDocument pdfDocument, {
    @required im.Image image,
    PdfImageOrientation orientation = PdfImageOrientation.topLeft,
  }) {
    assert(image != null);

    return PdfImage(
      pdfDocument,
      image: image.getBytes(format: im.Format.rgba),
      width: image.width,
      height: image.height,
      alpha: image.channels == im.Channels.rgba,
      orientation: orientation,
    );
  }

  factory PdfImage.file(
    PdfDocument pdfDocument, {
    @required Uint8List bytes,
    PdfImageOrientation orientation = PdfImageOrientation.topLeft,
  }) {
    assert(bytes != null);

    if (im.JpegDecoder().isValidFile(bytes)) {
      return PdfImage.jpeg(pdfDocument, image: bytes);
    }

    final im.Image image = im.decodeImage(bytes);
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
    final PdfImage im = PdfImage._(
      pdfDocument,
      width,
      height,
      orientation,
    );

    im.params['/BitsPerComponent'] = const PdfNum(8);
    im.params['/Name'] = PdfName(im.name);
    im.params['/ColorSpace'] = const PdfName('/DeviceGray');

    final int w = width;
    final int h = height;
    final int s = w * h;

    final Uint8List out = Uint8List(s);

    for (int i = 0; i < s; i++) {
      out[i] = image[i * 4 + 3];
    }

    im.buf.putBytes(out);
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
  }

  /// Image width
  final int _width;
  int get width => orientation.index >= 4 ? _height : _width;

  /// Image height
  final int _height;
  int get height => orientation.index < 4 ? _height : _width;

  /// The internal orientation of the image
  final PdfImageOrientation orientation;

  /// Name of the image
  String get name => '/Image$objser';
}
