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
  ///
  /// @param image an [Uint8List] value
  /// @param width
  /// @param height
  /// @param alpha if the image is transparent
  factory PdfImage(
    PdfDocument pdfDocument, {
    @required Uint8List image,
    @required int width,
    @required int height,
    bool alpha = true,
    PdfImageOrientation orientation = PdfImageOrientation.topLeft,
  }) =>
      PdfImage._(
        pdfDocument,
        image: image,
        width: width,
        height: height,
        alpha: alpha,
        alphaChannel: false,
        jpeg: false,
        orientation: orientation,
      );

  PdfImage._(
    PdfDocument pdfDocument, {
    @required this.image,
    @required int width,
    @required int height,
    @required this.alpha,
    @required this.alphaChannel,
    @required this.jpeg,
    @required this.orientation,
  })  : assert(alphaChannel == false || alpha == true),
        assert(width != null),
        assert(height != null),
        assert(jpeg != null),
        assert(orientation != null),
        _width = width,
        _height = height,
        super(pdfDocument, '/Image', isBinary: true) {
    _name = '/Image$objser';
    params['/Width'] = PdfStream.string(width.toString());
    params['/Height'] = PdfStream.string(height.toString());
    params['/BitsPerComponent'] = PdfStream.intNum(8);
    params['/Name'] = PdfStream.string(_name);

    if (alphaChannel == false && alpha) {
      final PdfImage _sMask = PdfImage._(
        pdfDocument,
        image: image,
        width: width,
        height: height,
        alpha: alpha,
        alphaChannel: true,
        jpeg: jpeg,
        orientation: orientation,
      );
      params['/SMask'] = PdfStream.string('${_sMask.objser} 0 R');
    }

    if (alphaChannel) {
      params['/ColorSpace'] = PdfStream.string('/DeviceGray');
    } else {
      params['/ColorSpace'] = PdfStream.string('/DeviceRGB');
    }

    if (jpeg) {
      params['/Intent'] = PdfStream.string('/RelativeColorimetric');
    }
  }

  factory PdfImage.jpeg(
    PdfDocument pdfDocument, {
    @required Uint8List image,
    PdfImageOrientation orientation,
  }) {
    assert(image != null);
    final PdfJpegInfo info = PdfJpegInfo(image);

    return PdfImage._(
      pdfDocument,
      image: image,
      width: info.width,
      height: info.height,
      jpeg: true,
      alpha: false,
      alphaChannel: false,
      orientation: orientation ?? info.orientation,
    );
  }

  /// RGBA Image Data
  final Uint8List image;

  /// Image width
  final int _width;
  int get width => orientation.index >= 4 ? _height : _width;

  /// Image height
  final int _height;
  int get height => orientation.index < 4 ? _height : _width;

  /// Image has alpha channel
  final bool alpha;

  String _name;

  /// Process alphaChannel only
  final bool alphaChannel;

  /// The image data is a jpeg image
  final bool jpeg;

  /// The internal orientation of the image
  final PdfImageOrientation orientation;

  /// write the pixels to the stream
  @override
  void _prepare() {
    if (jpeg) {
      buf.putBytes(image);
      params['/Filter'] = PdfStream.string('/DCTDecode');
      super._prepare();
      return;
    }

    final int w = _width;
    final int h = _height;
    final int s = w * h;

    final Uint8List out = Uint8List(alphaChannel ? s : s * 3);

    if (alphaChannel) {
      for (int i = 0; i < s; i++) {
        out[i] = image[i * 4 + 3];
      }
    } else {
      for (int i = 0; i < s; i++) {
        out[i * 3] = image[i * 4];
        out[i * 3 + 1] = image[i * 4 + 1];
        out[i * 3 + 2] = image[i * 4 + 2];
      }
    }

    buf.putBytes(out);

    super._prepare();
  }

  /// Get the name
  ///
  /// @return a String value
  String get name => _name;
}
