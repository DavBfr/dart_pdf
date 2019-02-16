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

class PdfImage extends PdfXObject {
  /// Creates a new [PdfImage] instance.
  ///
  /// @param image an [Uint8List] value
  /// @param width
  /// @param height
  /// @param alpha if the image is transparent
  /// @param alphaChannel if this is transparency mask
  PdfImage(PdfDocument pdfDocument,
      {@required this.image,
      @required this.width,
      @required this.height,
      this.alpha = true,
      this.alphaChannel = false,
      this.jpeg = false})
      : assert(alphaChannel == false || alpha == true),
        assert(width != null),
        assert(height != null),
        super(pdfDocument, '/Image', isBinary: true) {
    _name = '/Image$objser';
    params['/Width'] = PdfStream.string(width.toString());
    params['/Height'] = PdfStream.string(height.toString());
    params['/BitsPerComponent'] = PdfStream.intNum(8);
    params['/Name'] = PdfStream.string(_name);

    if (alphaChannel == false && alpha) {
      final PdfImage _sMask = PdfImage(pdfDocument,
          image: image,
          width: width,
          height: height,
          alpha: alpha,
          alphaChannel: true);
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

  /// RGBA Image Data
  final Uint8List image;

  /// Image width
  final int width;

  /// Image height
  final int height;

  /// Image has alpha channel
  final bool alpha;

  String _name;

  /// Process alphaChannel only
  final bool alphaChannel;

  /// The image data is a jpeg image
  final bool jpeg;

  /// write the pixels to the stream
  @override
  void _prepare() {
    if (jpeg) {
      buf.putBytes(image);
      params['/Filter'] = PdfStream.string('/DCTDecode');
      super._prepare();
      return;
    }

    final int w = width;
    final int h = height;
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
