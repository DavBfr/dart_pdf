/*
 * Copyright (C) 2017, David PHAM-VAN <dev.nfet.net@gmail.com>
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General 
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General  License for more details.
 *
 * You should have received a copy of the GNU Lesser General 
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

part of pdf;

class PDFImage extends PDFXObject {
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

  /// Creates a new <code>PDFImage</code> instance.
  ///
  /// @param img an <code>Image</code> value
  /// @param x an <code>int</code> value
  /// @param y an <code>int</code> value
  /// @param w an <code>int</code> value
  /// @param h an <code>int</code> value
  /// @param obs an <code>ImageObserver</code> value
  PDFImage(PDFDocument pdfDocument,
      {@required this.image,
      @required this.width,
      @required this.height,
      this.alpha = true,
      this.alphaChannel = false})
      : assert(alphaChannel == false || alpha == true),
        assert(width != null),
        assert(height != null),
        super(pdfDocument, "/Image", isBinary: true) {
    _name = "/Image$objser";
    params["/Width"] = PDFStream.string(width.toString());
    params["/Height"] = PDFStream.string(height.toString());
    params["/BitsPerComponent"] = PDFStream.intNum(8);
    params['/Name'] = PDFStream.string(_name);

    if (alphaChannel == false && alpha) {
      var _sMask = new PDFImage(pdfDocument,
          image: image,
          width: width,
          height: height,
          alpha: alpha,
          alphaChannel: true);
      params["/SMask"] = PDFStream.string("${_sMask.objser} 0 R");
    }

    if (alphaChannel) {
      params["/ColorSpace"] = PDFStream.string("/DeviceGray");
    } else {
      params["/ColorSpace"] = PDFStream.string("/DeviceRGB");
    }
  }

  @override
  void prepare() {
    // write the pixels to the stream
    // print("Processing image ${img.width}x${img.height} pixels");

    int w = width;
    int h = height;
    int s = w * h;

    Uint8List out = new Uint8List(alphaChannel ? s : s * 3);

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

    super.prepare();
  }

  /// Get the name
  ///
  /// @return a <code>String</code> value
  String get name => _name;
}
